#!/usr/bin/env bash
#
# Script: remote-batch-update.sh
# Description:
#   SSH into each host to invoke the local-update-packages.sh script non-interactively,
#   record successes and failures in a summary log, and capture full output in a detailed log.
#
# Usage:
#   ./remote-batch-update.sh
#
# Configuration:
#   USERNAME_FILE   Path to the file containing your SSH username
#   HOSTFILE        Path to the file listing each server base name (one per line)
#   HOSTDOMAIN      Domain suffix for each host (e.g., ".lan")
#   KEY_FILE        Path to your SSH private key
#   REMOTE_CMD      Path to the remote update script (no sudo prefix)
#   SUMMARY_LOGFILE Path to the summary log file (timestamps + OK/FAIL per host)
#   DETAIL_LOGFILE  Path to the detailed log file (full output of remote runs)

set -euo pipefail  # abort on error, undefined var, or pipeline failure

# —— Directories ——  
# Resolve this script’s directory, and put logs in a sibling "logs/" folder
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Configuration ——  
USERNAME_FILE="$SCRIPT_DIR/username.txt"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"
HOSTDOMAIN=".lan"
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"
REMOTE_CMD="~/server-scripts/local-update-packages.sh"

# We keep static names here; logrotate will append timestamps when rotating
SUMMARY_LOGFILE="$LOG_DIR/update-summary.log"
DETAIL_LOGFILE="$LOG_DIR/update-detail.log"

# —— Prep ——  
[[ -f "$USERNAME_FILE" ]] || {
  echo "❌ Missing $USERNAME_FILE"
  exit 1
}
read -r USERNAME < "$USERNAME_FILE"

# Create log files if missing (but don’t clear them)
mkdir -p "$LOG_DIR"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"


# Truncate (or create) fresh logs
#: > "$SUMMARY_LOGFILE"
#: > "$DETAIL_LOGFILE"

# —— Result arrays ——  
SUCCESS=()  # hosts that updated successfully
FAIL=()     # hosts that failed

# —— Loop through hosts ——  
while IFS= read -r SERVER; do
  [[ -z "$SERVER" ]] && continue
  FQDN="${SERVER}${HOSTDOMAIN}"

  echo "➡️  Updating $FQDN…"
  echo -e "\n===== $FQDN - $(date '+%Y-%m-%d %H:%M:%S') =====\n" | tee -a "$DETAIL_LOGFILE"

  if ssh -n -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         "$USERNAME@$FQDN" bash -lc \
         "export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none && \
          sudo --preserve-env=DEBIAN_FRONTEND,APT_LISTCHANGES_FRONTEND $REMOTE_CMD" \
         2>&1 | tee -a "$DETAIL_LOGFILE"; then

    echo "$(date +'%F %T')  [OK]   Updated $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Update failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi

done < "$HOSTFILE"

# —— Summary to console ——  
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

