#!/usr/bin/env bash
#
# Script: remote-batch-update.sh
# Description:
#   SSH into each host to invoke the remote update script non-interactively,
#   record successes/failures in a summary log, and capture full output in a detailed log.
#
# Usage:
#   ./remote-batch-update.sh
#
# Notes:
#   - Put SSH username in ./username.txt (single line).
#   - Put hosts in ./remote-hosts.txt (one per line). Lines may be:
#       * bare hostnames (e.g., SPINAL-TAP)            -> appends HOSTDOMAIN if set
#       * FQDNs (e.g., spinal-tap.local)               -> used as-is
#       * IPv4 addresses (e.g., 192.168.1.10)          -> used as-is
#       * comments starting with # and blank lines are ignored
#       * per-line domain override: HOST@domain        -> becomes HOST.domain
#
#   - Set DEBUG=1 for bash xtrace
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

# —— Directories ——
# Portable script dir (avoids readlink -f portability issues)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Configuration ——
USERNAME_FILE="$SCRIPT_DIR/username.txt"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"

# Append to *bare* hostnames only. Recommend leaving empty unless your LAN DNS is reliable.
HOSTDOMAIN=""

# SSH key
KEY_FILE="${HOME}/.ssh/id_ed25519_server_fleet"

# Remote command to run (no sudo in the path; sudo is applied below)
REMOTE_CMD="~/server-scripts/local-update-packages.sh"

# Logs
SUMMARY_LOGFILE="$LOG_DIR/update-summary.log"
DETAIL_LOGFILE="$LOG_DIR/update-detail.log"

# SSH options
SSH_OPTS=(
  -n
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

# The remote wrapper: non-interactive apt settings, preserve env into sudo, then run script.
REMOTE_WRAPPER=$'bash -lc '\''
export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none;
sudo --preserve-env=DEBIAN_FRONTEND,APT_LISTCHANGES_FRONTEND '"$REMOTE_CMD"$'\''

# —— Validation ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
[[ -s "$HOSTFILE"     ]] || { echo "❌ Missing or empty $HOSTFILE"; exit 1; }
[[ -f "$KEY_FILE"     ]] || { echo "❌ Missing SSH key at $KEY_FILE"; exit 1; }

# Enforce tight key perms (OpenSSH rejects world-writable)
if command -v stat >/dev/null 2>&1; then
  key_perm="$(stat -c '%a' "$KEY_FILE" 2>/dev/null || echo 600)"
  case "$key_perm" in
    600|400) : ;;
    *) echo "❌ SSH key permissions too open ($key_perm). Run: chmod 600 '$KEY_FILE'"; exit 1 ;;
  esac
fi

read -r USERNAME < "$USERNAME_FILE"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

# —— Helpers ——
trim() {
  local s="$1"
  s="$(sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' <<<"$s")"
  printf '%s' "$s"
}

build_fqdn() {
  local raw="$1"
  # Allow "HOST@domain" → "HOST.domain"
  if [[ "$raw" == *@* ]]; then
    local host_part="${raw%@*}"
    local dom_part="${raw#*@}"
    echo "${host_part}.${dom_part}"
    return
  fi
  # IPv4?
  if [[ "$raw" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$raw"; return
  fi
  # Already an FQDN?
  if [[ "$raw" == *.* ]]; then
    echo "$raw"; return
  fi
  # Bare hostname
  if [[ -n "$HOSTDOMAIN" ]]; then
    echo "${raw}${HOSTDOMAIN}"
  else
    echo "$raw"
  fi
}

# —— Results ——
SUCCESS=()
FAIL=()

# —— Loop through hosts ——
while IFS= read -r LINE || [[ -n "$LINE" ]]; do
  SERVER="$(trim "${LINE//$'\r'/}")"
  [[ -z "$SERVER" || "$SERVER" =~ ^[[:space:]]*# ]] && continue

  FQDN="$(build_fqdn "$SERVER")"

  echo "➡️  Updating $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$DETAIL_LOGFILE"

  if ssh "${SSH_OPTS[@]}" "$USERNAME@$FQDN" "$REMOTE_WRAPPER" 2>&1 | tee -a "$DETAIL_LOGFILE"; then
    echo "$(date +'%F %T')  [OK]   Updated $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Update failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < "$HOSTFILE"

# —— Summary ——
echo
echo "📊 Update Summary"
echo "================="
echo "✅ Succeeded (${#SUCCESS[@]}):"
for host in "${SUCCESS[@]}"; do
  echo "  - $host"
done

echo
echo "❌ Failed   (${#FAIL[@]}):"
for host in "${FAIL[@]}"; do
  echo "  - $host"
done

echo
echo "📝 Logs: summary in $SUMMARY_LOGFILE and full output in $DETAIL_LOGFILE"
