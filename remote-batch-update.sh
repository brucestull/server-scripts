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

set -euo pipefail

# —— Configuration ——
USERNAME_FILE="./username.txt"                         # file with your SSH username
HOSTFILE="./remote-hosts.txt"                          # file listing each server base-name
HOSTDOMAIN=".lan"                                      # domain suffix (e.g. "SERVER.lan")
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"       # SSH private key
REMOTE_CMD="~/server-scripts/local-update-packages.sh" # remote script path (no sudo)
SUMMARY_LOGFILE="./update-summary.log"                 # summary of successes/failures
DETAIL_LOGFILE="./update-detail.log"                   # full stdout/stderr output

# —— Prep ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"
> "$SUMMARY_LOGFILE"    # clear/create summary log
> "$DETAIL_LOGFILE"     # clear/create detailed log

# —— Result arrays ——
SUCCESS=()
FAIL=()

# —— Loop through hosts ——
while IFS= read -r SERVER; do
  [[ -z "$SERVER" ]] && continue  # skip blank lines
  FQDN="${SERVER}${HOSTDOMAIN}"

  echo "➡️  Updating $FQDN…"

  # Run SSH, capture all output to detailed log
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
