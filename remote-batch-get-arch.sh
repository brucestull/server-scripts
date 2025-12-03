#!/usr/bin/env bash
#
# Script: remote-batch-get-arch.sh
# Description:
#   SSH into each host, run `uname -m` (and related uname info),
#   record successes/failures in a summary log, and capture full
#   output in a detailed log.
#
# Usage:
#   ./remote-batch-get-arch.sh
#
# Notes:
#   - Put the SSH username in ./username.txt (single line).
#   - Put hosts in ./remote-hosts.txt (one per line). Lines may be:
#       * bare hostnames (e.g., SPINAL-TAP)            -> will append HOSTDOMAIN if set
#       * FQDNs (e.g., spinal-tap.local)               -> used as-is
#       * IPv4 addresses (e.g., 192.168.1.10)          -> used as-is
#       * Comments starting with # and blank lines are ignored
#   - Optional per-line domain override: HOST@domain   -> becomes HOST.domain
#
#   Set DEBUG=1 for bash xtrace, e.g.:
#     DEBUG=1 ./remote-batch-get-arch.sh
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

# —— Directories ——
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Configuration ——
USERNAME_FILE="$SCRIPT_DIR/username.txt"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"

# If you want to automatically append a domain to *bare* hostnames, set HOSTDOMAIN.
# Leave empty ("") to use bare names as-is.
HOSTDOMAIN=""

# SSH key to use
KEY_FILE="${HOME}/.ssh/id_ed25519_server_fleet"

# Consolidate SSH options
SSH_OPTS=(
  -n
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

# Remote command: architecture + a bit of context
REMOTE_CMD='
  echo "=== uname -m (machine hardware name) ==="
  uname -m
  echo
  echo "=== uname -srm (kernel + arch) ==="
  uname -srm
'

SUMMARY_LOGFILE="$LOG_DIR/arch-summary.log"
DETAIL_LOGFILE="$LOG_DIR/arch-detail.log"

# —— Input validation ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
[[ -s "$HOSTFILE"     ]] || { echo "❌ Missing or empty $HOSTFILE"; exit 1; }
[[ -f "$KEY_FILE"     ]] || { echo "❌ Missing SSH key at $KEY_FILE"; exit 1; }

# Warn/stop on permissive key perms (OpenSSH refuses world-writable keys)
if command -v stat >/dev/null 2>&1; then
  key_perm="$(stat -c '%a' "$KEY_FILE" 2>/dev/null || echo 600)"
  case "$key_perm" in
    600|400) : ;;
    *)
      echo "❌ SSH key permissions too open ($key_perm). Run: chmod 600 '$KEY_FILE'"
      exit 1
      ;;
  esac
fi

# —— Prep ——
read -r USERNAME < "$USERNAME_FILE"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

trim() {
  local s="$1"
  # shellcheck disable=SC2001
  s="$(sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' <<<"$s")"
  printf '%s' "$s"
}

build_fqdn() {
  local raw="$1"

  # per-line domain override: HOST@domain -> HOST.domain
  if [[ "$raw" == *@* ]]; then
    local host_part="${raw%@*}"
    local dom_part="${raw#*@}"
    echo "${host_part}.${dom_part}"
    return
  fi

  # IPv4?
  if [[ "$raw" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$raw"
    return
  fi

  # Already an FQDN?
  if [[ "$raw" == *.* ]]; then
    echo "$raw"
    return
  fi

  # Bare hostname
  if [[ -n "$HOSTDOMAIN" ]]; then
    echo "${raw}${HOSTDOMAIN}"
  else
    echo "$raw"
  fi
}

# —— Loop through hosts ——
while IFS= read -r SERVER || [[ -n "${SERVER:-}" ]]; do
  SERVER="$(trim "$SERVER")"
  # Skip blank lines and comments
  [[ -z "$SERVER" || "$SERVER" =~ ^[[:space:]]*# ]] && continue

  FQDN="$(build_fqdn "$SERVER")"

  echo "➡️  Retrieving architecture info from $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  if ssh "${SSH_OPTS[@]}" "$USERNAME@$FQDN" "$REMOTE_CMD" 2>&1 | tee -a "$DETAIL_LOGFILE"; then
    echo "$(date +'%F %T')  [OK]   Arch info retrieved from $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Arch info retrieval failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < "$HOSTFILE"

# —— Summary to console ——
echo
echo "📊 Arch Info Retrieval Summary"
echo "=============================="
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
