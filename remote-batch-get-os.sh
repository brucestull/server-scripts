#!/usr/bin/env bash
#
# Script: remote-batch-get-os.sh
# Description:
#   SSH into each host, run either lsb_release -a (if available)
#   or cat /etc/os-release, record successes/failures in a summary log,
#   and capture full output in a detailed log.
#
# Usage:
#   ./remote-batch-get-os.sh
#

set -euo pipefail

# —— Directories ——  
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Configuration ——  
USERNAME_FILE="$SCRIPT_DIR/username.txt"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"
HOSTDOMAIN=".lan"
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"

# If lsb_release exists on the remote, use it; otherwise fall back to /etc/os-release
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

# —— Prep ——  
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

# —— Result arrays ——  
SUCCESS=()
FAIL=()

# —— Loop through hosts ——  
while IFS= read -r SERVER; do
  [[ -z "$SERVER" ]] && continue
  FQDN="${SERVER}${HOSTDOMAIN}"

  echo "➡️  Retrieving OS info from $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  if ssh -n -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         "$USERNAME@$FQDN" "$REMOTE_CMD" \
         2>&1 | tee -a "$DETAIL_LOGFILE"; then

    echo "$(date +'%F %T')  [OK]   OS info retrieved from $FQDN" \
      | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] OS info retrieval failed on $FQDN" \
      | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi

done < "$HOSTFILE"

# —— Summary to console ——  
echo
echo "📊 OS Info Retrieval Summary"
echo "============================"
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

