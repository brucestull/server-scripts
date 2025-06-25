#!/usr/bin/env bash
#
# Script: remote-batch-shutdown-delay-1m.sh
# Description:
#   SSH into each hose and run cancel shutdown script.
#
# Usage:
#   ./remote-batch-shutdown-delay-1m.sh
#
# Configuration:
#   USERNAME_FILE  Path to the file containing your SSH username
#   HOSTFILE       Path to the file listing each server base name (one per line)
#   HOSTDOMAIN     Domain suffix for each host (e.g., ".lan")
#   KEY_FILE       Path to your SSH private key
#   REMOTE_CMD     Command to run on the remote server (e.g., sudo ~/scripts/update-the-stuff.sh)
#   LOGFILE        Path to the log file for recording timestamped results
#

# —— Configuration ——  
USERNAME_FILE="./username.txt"           # file with your SSH username  
HOSTFILE="./remote-hosts.txt"            # file listing each server base-name  
HOSTDOMAIN=".lan"                        # domain suffix (e.g. "SERVER.lan")  
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"  # SSH private key  
REMOTE_CMD="sudo ~/server-scripts/local-shutdown-delay-1m.sh"   # remote command to run  
LOGFILE="./shutdown-remote-servers-results.log"           # where to record timestamped OK/FAIL

# —— Prep ——  
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"      # load SSH user  
> "$LOGFILE"                              # clear/create log

# —— Result arrays ——  
SUCCESS=()
FAIL=()

# —— Loop through hosts ——  
while IFS= read -r SERVER; do           # raw read per line
  [[ -z "$SERVER" ]] && continue        # skip blank lines
  FQDN="${SERVER}${HOSTDOMAIN}"         # build fully-qualified host

  echo "➡️  Shutting down $FQDN…"  

  # SSH with TTY allocation (-t) so sudo can prompt if needed; redirect ssh stdin
  if ssh -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         -t "$USERNAME@$FQDN" < /dev/null \
         "$REMOTE_CMD"
  then
    echo "$(date +'%F %T')  [OK]   Shutdown $FQDN" >> "$LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Shutdown failed on $FQDN" >> "$LOGFILE"
    FAIL+=("$FQDN")
  fi

done < "$HOSTFILE"

# —— Summary ——  
echo
echo "📊 Update Summary"
echo "================="
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
