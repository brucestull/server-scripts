#!/usr/bin/env bash
#
# Script: remote-batch-get-os.sh
# Description:
#   SSH into each host, run lsb_release -a to retrieve OS information,
#   record successes and failures in a summary log, and capture full output in a detailed log.
#
# Usage:
#   ./remote-batch-get-os.sh
#
# Configuration:
#   USERNAME_FILE   Path to the file containing your SSH username
#   HOSTFILE        Path to the file listing each server base name (one per line)
#   HOSTDOMAIN      Domain suffix for each host (e.g., ".lan")
#   KEY_FILE        Path to your SSH private key
#   REMOTE_CMD      Command to run on the remote host
#   SUMMARY_LOGFILE Path to the summary log file (timestamps + OK/FAIL per host)
#   DETAIL_LOGFILE  Path to the detailed log file (full output of remote runs)

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
REMOTE_CMD="lsb_release -a"

SUMMARY_LOGFILE="$LOG_DIR/os-summary.log"
DETAIL_LOGFILE="$LOG_DIR/os-detail.log"

# —— Prep ——  
[[ -f "$USERNAME_FILE" ]] || {
  echo "❌ Missing $USERNAME_FILE"
  exit 1
}
read -r USERNAME < "$USERNAME_FILE"

# Ensure log files exist (don’t clear existing history)
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

# —— Result arrays ——  
SUCCESS=()
FAIL=()

# —— Loop through hosts ——  
while IFS= read -r SERVER; do
  [[ -z "$SERVER" ]] && continue
  FQDN="${SERVER}${HOSTDOMAIN}"

  echo "➡️  Retrieving OS info from $FQDN…"
  echo -e "\n===== $FQDN - $(date '+%Y-%m-%d %H:%M:%S') =====\n" \
    | tee -a "$DETAIL_LOGFILE"

  if ssh -n -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         "$USERNAME@$FQDN" bash -lc "$REMOTE_CMD" \
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

