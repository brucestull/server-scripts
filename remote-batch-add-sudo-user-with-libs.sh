#!/usr/bin/env bash
#
# Script: remote-batch-add-sudo-user-with-libs.sh
# Description:
#   Uses passwordless SSH (current user + SSH_KEY_PATH from .secrets) to connect
#   to each host and create/update a NEW_USER_NAME with NEW_USER_PASSWORD,
#   and make that NEW_USER_NAME a sudoer (by adding to the sudo/wheel group).
#
# Requirements (in .secrets):
#   USER_NAME=catfish0765
#   SSH_KEY_PATH=/path/to/key
#   NEW_USER_NAME=flynntknapp
#   NEW_USER_PASSWORD=some-password
#   (optional) HOSTDOMAIN=.local
#
# Usage:
#   chmod +x remote-batch-add-sudo-user-with-libs.sh
#   ./remote-batch-add-sudo-user-with-libs.sh
#
# Notes:
#   - This script assumes the current USER_NAME can run sudo NON-interactively
#     (i.e., `sudo -n true` works) on the remote hosts.
#   - Don't run with DEBUG=1 for this script (xtrace risks leaking secrets).
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR

# —— Directories ——
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Imports ——
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-secrets.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-hosts.sh"

# —— Files ——
SECRETS_FILE="$SCRIPT_DIR/.secrets"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"

# Optional default domain appended to bare hostnames (can be set here or in .secrets as HOSTDOMAIN)
HOSTDOMAIN="${HOSTDOMAIN:-}"

# —— Load secrets ——
load_secrets "$SECRETS_FILE"
require_vars "$SECRETS_FILE" USER_NAME SSH_KEY_PATH NEW_USER_NAME NEW_USER_PASSWORD
check_ssh_key_file "$SSH_KEY_PATH"

CURRENT_USER="$USER_NAME"
KEY_FILE="$SSH_KEY_PATH"
TARGET_USER="$NEW_USER_NAME"
TARGET_PASS="$NEW_USER_PASSWORD"

# SSH options (batchy + safe)
SSH_OPTS=(
  -n
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

SUMMARY_LOGFILE="$LOG_DIR/add-sudo-user-summary.log"
DETAIL_LOGFILE="$LOG_DIR/add-sudo-user-detail.log"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

while IFS= read -r SERVER; do
  FQDN="$(build_fqdn "$SERVER" "$HOSTDOMAIN")"

  echo "➡️  Adding sudo user '$TARGET_USER' on $FQDN…"
  printf "\n===== %s =====\n\n" "$FQDN" | tee -a "$DETAIL_LOGFILE"

  # Prevent accidental xtrace leaks if caller exported DEBUG=1 elsewhere.
  set +x 2>/dev/null || true

  if ssh "${SSH_OPTS[@]}" "$CURRENT_USER@$FQDN" "bash -s" 2>&1 | tee -a "$DETAIL_LOGFILE" <<EOF
set -euo pipefail

NEW_USER="${TARGET_USER}"
NEW_PASS="${TARGET_PASS}"

need_cmd() { command -v "\$1" >/dev/null 2>&1 || { echo "❌ Missing required command: \$1"; exit 20; }; }

need_cmd sudo
need_cmd id
need_cmd useradd
need_cmd usermod
need_cmd chpasswd
need_cmd getent

# Require non-interactive sudo so this can run in batch mode
if ! sudo -n true >/dev/null 2>&1; then
  echo "❌ sudo is not available non-interactively for the connecting user on this host (needs NOPASSWD or equivalent)"
  exit 21
fi

# Decide which admin group to use (Ubuntu/Debian commonly use 'sudo')
ADMIN_GROUP=""
if getent group sudo >/dev/null 2>&1; then
  ADMIN_GROUP="sudo"
elif getent group wheel >/dev/null 2>&1; then
  ADMIN_GROUP="wheel"
else
  echo "❌ Neither 'sudo' nor 'wheel' group exists on this host; can't grant sudoer via group membership."
  exit 22
fi

if id "\$NEW_USER" >/dev/null 2>&1; then
  echo "ℹ️  User exists: \$NEW_USER"
else
  echo "🧑‍💻 Creating user: \$NEW_USER"
  sudo useradd -m -s /bin/bash "\$NEW_USER"
fi

echo "🔐 Setting password for: \$NEW_USER"
echo "\$NEW_USER:\$NEW_PASS" | sudo chpasswd

echo "🛡️  Granting sudo rights via group '\$ADMIN_GROUP' to: \$NEW_USER"
sudo usermod -aG "\$ADMIN_GROUP" "\$NEW_USER"

echo "✅ Verified groups for \$NEW_USER: \$(id -nG "\$NEW_USER" | tr ' ' ',')"
echo "✅ Done on \$(hostname -f 2>/dev/null || hostname)"
EOF
  then
    echo "$(date +'%F %T')  [OK]   Added/updated sudo user '$TARGET_USER' on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Sudo user add/update failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < <(iter_hosts "$HOSTFILE")

echo
echo "📊 Add Sudo User Summary"
echo "========================"
echo "✅ Succeeded (${#SUCCESS[@]}):"
for host in "${SUCCESS[@]}"; do echo "  - $host"; done
echo
echo "❌ Failed   (${#FAIL[@]}):"
for host in "${FAIL[@]}"; do echo "  - $host"; done
echo
echo "📝 Logs: summary in $SUMMARY_LOGFILE and full output in $DETAIL_LOGFILE"
echo
echo "🔎 Manual verbose SSH reminder:"
echo "    ssh -vvv -i \"$KEY_FILE\" -o IdentitiesOnly=yes \"$CURRENT_USER@<host>\""
