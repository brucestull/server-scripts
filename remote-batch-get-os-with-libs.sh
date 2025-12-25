#!/usr/bin/env bash
#
# Script: remote-batch-get-os-with-libs.sh
# Description:
#   SSH into each host, run either `lsb_release -a` (if available)
#   or `cat /etc/os-release`, record successes/failures in a summary log,
#   and capture full output in a detailed log.
#
# Usage:
#   ./remote-batch-get-os-with-libs.sh
#
# Set DEBUG=1 for bash xtrace:
#   DEBUG=1 ./remote-batch-get-os-with-libs.sh
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

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
require_vars "$SECRETS_FILE" USER_NAME SSH_KEY_PATH
check_ssh_key_file "$SSH_KEY_PATH"

USERNAME="$USER_NAME"
KEY_FILE="$SSH_KEY_PATH"

# SSH options
SSH_OPTS=(
  -n
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

REMOTE_CMD='
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -a
  else
    echo "=== /etc/os-release ==="
    cat /etc/os-release
  fi
'

SUMMARY_LOGFILE="$LOG_DIR/os-summary.log"
DETAIL_LOGFILE="$LOG_DIR/os-detail.log"

touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

while IFS= read -r SERVER; do
  FQDN="$(build_fqdn "$SERVER" "$HOSTDOMAIN")"

  echo "➡️  Retrieving OS info from $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  if ssh "${SSH_OPTS[@]}" "$USERNAME@$FQDN" "$REMOTE_CMD" 2>&1 | tee -a "$DETAIL_LOGFILE"; then
    echo "$(date +'%F %T')  [OK]   OS info retrieved from $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] OS info retrieval failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < <(iter_hosts "$HOSTFILE")

echo
echo "📊 OS Info Retrieval Summary"
echo "============================"
echo "✅ Succeeded (${#SUCCESS[@]}):"
for host in "${SUCCESS[@]}"; do echo "  - $host"; done
echo
echo "❌ Failed   (${#FAIL[@]}):"
for host in "${FAIL[@]}"; do echo "  - $host"; done
echo
echo "📝 Logs: summary in $SUMMARY_LOGFILE and full output in $DETAIL_LOGFILE"
