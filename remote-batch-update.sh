#!/usr/bin/env bash
#
# Script: remote-batch-update.sh
# Description:
#   SSH into each host to invoke the local-update-packages.sh script non-interactively,
#   record successes and failures in a timestamped log, and print a summary.
#
# Usage:
#   ./remote-batch-update.sh
#
# Configuration:
#   USERNAME_FILE  Path to the file containing your SSH username
#   HOSTFILE       Path to the file listing each server base name (one per line)
#   HOSTDOMAIN     Domain suffix for each host (e.g., ".lan")
#   KEY_FILE       Path to your SSH private key
#   REMOTE_CMD     Path to the remote update script (no sudo prefix)
#   LOGFILE        Path to the log file for recording timestamped results

set -euo pipefail

# —— Configuration ——
USERNAME_FILE="./username.txt"                         # file with your SSH username
HOSTFILE="./remote-hosts.txt"                          # file listing each server base-name
HOSTDOMAIN=".lan"                                      # domain suffix (e.g. "SERVER.lan")
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"       # SSH private key
REMOTE_CMD="~/server-scripts/local-update-packages.sh" # remote script path (no sudo)
LOGFILE="./update-results.log"                         # where to record timestamped OK/FAIL

# —— Prep ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"                   # load SSH user
touch "$LOGFILE" && > "$LOGFILE"                   # clear/create log

# —— Result arrays ——
SUCCESS=()
FAIL=()

# —— Loop through hosts ——
while IFS= read -r SERVER; do                           # raw read per line
  [[ -z "$SERVER" ]] && continue                      # skip blank lines
  FQDN="${SERVER}${HOSTDOMAIN}"                       # build fully-qualified host

  echo "➡️  Updating $FQDN…"

  # SSH with no stdin (-n) so the loop's input isn't consumed
  if ssh -n -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         "$USERNAME@$FQDN" bash -lc \
         "export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none && \
          sudo --preserve-env=DEBIAN_FRONTEND,APT_LISTCHANGES_FRONTEND $REMOTE_CMD"
  then
    echo "$(date +'%F %T')  [OK]   Updated $FQDN" >> "$LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Update failed on $FQDN" >> "$LOGFILE"
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
echo "📝 Full details in $LOGFILE"
