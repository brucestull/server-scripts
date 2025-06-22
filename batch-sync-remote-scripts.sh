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

# —— Configuration ——
USERNAME_FILE="./username.txt"                   # file with your SSH username
HOSTFILE="./remote-hosts.txt"                    # file listing each server base-name
HOSTDOMAIN=".lan"                                # domain suffix (e.g. "SERVER.lan")
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner" # SSH private key
SOURCE_DIR="${HOME}/server-scripts/"             # local directory to sync (trailing slash)
DEST_DIR="~/server-scripts/"                     # destination path on remote (will be expanded)
LOGFILE="./sync-results.log"                     # where to record timestamped OK/FAIL

# —— Prep ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"              # load SSH user
> "$LOGFILE"                                     # clear/create log

# —— Result arrays ——
SUCCESS=()
FAIL=()

# —— Loop through hosts ——
while IFS= read -r SERVER; do                    # read raw lines
  [[ -z "$SERVER" ]] && continue                 # skip blank lines
  FQDN="${SERVER}${HOSTDOMAIN}"                  # build fully-qualified host

  echo "➡️  Syncing to $FQDN…"

  # Rsync with SSH key, verbose, archive mode, compress
  if rsync -avz \
           -e "ssh -i $KEY_FILE -o BatchMode=yes -o ConnectTimeout=5" \
           "$SOURCE_DIR" \
           "$USERNAME@$FQDN:$DEST_DIR" &>/dev/null; then
    echo "$(date +'%F %T')  [OK]   Synced to $FQDN"  >> "$LOGFILE"
    SUCCESS+=("$FQDN")                           # record success
  else
    echo "$(date +'%F %T')  [FAIL] Sync failed on $FQDN" >> "$LOGFILE"
    FAIL+=("$FQDN")                              # record failure
  fi
done < "$HOSTFILE"

# —— Summary ——
echo
echo "📊 Rsync Summary"
echo "================"
echo "✅ Succeeded (${#SUCCESS[@]}):"
for h in "${SUCCESS[@]}"; do
  echo "  - $h"
done

echo
echo "❌ Failed   (${#FAIL[@]}):"
for h in "${FAIL[@]}"; do
  echo "  - $h"
done

echo
echo "📝 Full details in $LOGFILE"

