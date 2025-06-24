#!/usr/bin/env bash
#
# Script: batch-sync-remote-scripts.sh
# Description:
#   Rsync the local ~/server-scripts/ directory to each remote host,
#   record successes and failures in a timestamped log, and print a summary.
#
# Usage:
#   ./batch-sync-remote-scripts.sh
#
# Configuration:
#   USERNAME_FILE  Path to the file containing your SSH username
#   HOSTFILE       Path to the file listing each server base name (one per line)
#   HOSTDOMAIN     Domain suffix for each host (e.g., ".lan")
#   KEY_FILE       Path to your SSH private key
#   SOURCE_DIR     Local directory to sync (trailing slash)
#   DEST_DIR       Destination path on remote (will be expanded)
#   LOGFILE        Path to the log file for recording timestamped results
#

set -euo pipefail

# — Configuration —
USERNAME_FILE="./username.txt"
HOSTFILE="./remote-hosts.txt"
HOSTDOMAIN=".lan"
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"	# Dynamically pick up the directory the script is in
SOURCE_DIR="${SCRIPT_DIR}/"
DEST_DIR="~/server-scripts/"
LOGFILE="./sync-results.log"

[[ -f $USERNAME_FILE ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"

# reset log
echo "=== Sync run at $(date '+%F %T') ===" > "$LOGFILE"

SUCCESS=()
FAIL=()

while IFS= read -r line || [[ -n $line ]]; do
  # strip stray carriage returns and whitespace
  SERVER="${line//$'\r'/}"
  SERVER="${SERVER//[[:space:]]/}"
  [[ -z "$SERVER" ]] && continue

  FQDN="${SERVER}${HOSTDOMAIN}"
  echo "➡️  Syncing to $FQDN…" | tee -a "$LOGFILE"

  if rsync -avz \
	--delete-excluded \
	--exclude='.git/' \
	--exclude='.gitignore' \
	--exclude='sync-results.log' \
	--exclude='update-results.log' \
	--exclude='shutdown-cancel-results.log' \
	--exclude='shutdown-remote-servers-results.log' \
	--exclude='remote-hosts.txt' \
	--exclude='username.txt' \
        -e "ssh -i $KEY_FILE -o BatchMode=yes -o ConnectTimeout=5" \
        "$SOURCE_DIR" \
        "$USERNAME@$FQDN:$DEST_DIR" \
        >>"$LOGFILE" 2>&1; then
    echo "$(date +'%F %T')  [OK]   Synced to $FQDN" >>"$LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Sync failed on $FQDN" >>"$LOGFILE"
    FAIL+=("$FQDN")
  fi
done < "$HOSTFILE"

# — Summary —
{
  echo
  echo "📊 Rsync Summary"
  echo "==============="
  printf "✅ Succeeded (%d):\n" "${#SUCCESS[@]}"
  for h in "${SUCCESS[@]}"; do echo "  - $h"; done

  echo
  printf "❌ Failed   (%d):\n" "${#FAIL[@]}"
  for h in "${FAIL[@]}"; do echo "  - $h"; done

  echo
  echo "📝 Full details in $LOGFILE"
} | tee -a "$LOGFILE"
