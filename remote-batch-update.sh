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

# —— Configuration ——
USERNAME_FILE="./username.txt"                         # file containing SSH username
HOSTFILE="./remote-hosts.txt"                          # file listing server base names
HOSTDOMAIN=".lan"                                      # domain suffix for FQDN
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"       # path to SSH private key
REMOTE_CMD="~/server-scripts/local-update-packages.sh" # remote update script (no sudo)
SUMMARY_LOGFILE="./update-summary.log"                 # summary of OK/FAIL per host
DETAIL_LOGFILE="./update-detail.log"                   # detailed stdout/stderr log

# —— Prep ——
[[ -f "$USERNAME_FILE" ]] || { 
  echo "❌ Missing $USERNAME_FILE"  # fail if username file doesn't exist
  exit 1
}
read -r USERNAME < "$USERNAME_FILE"  # load SSH username into variable
> "$SUMMARY_LOGFILE"                 # truncate or create summary log
> "$DETAIL_LOGFILE"                  # truncate or create detailed log

# —— Result arrays ——
SUCCESS=()  # will hold hosts that updated successfully
FAIL=()     # will hold hosts that failed

# —— Loop through hosts ——
while IFS= read -r SERVER; do            # read each line from HOSTFILE
  [[ -z "$SERVER" ]] && continue      # skip empty lines
  FQDN="${SERVER}${HOSTDOMAIN}"        # build fully-qualified domain name

  echo "➡️  Updating $FQDN…"          # print progress to console

  # Insert separator header into detailed log for clarity
  echo -e "\n===== $FQDN =====\n" | tee -a "$DETAIL_LOGFILE"

  # Run remote update command, capturing all output
  if ssh -n -i "$KEY_FILE" \          # -n prevents ssh from consuming stdin
         -o BatchMode=yes \             # disable password prompts
         -o ConnectTimeout=5 \          # timeout if host unreachable
         "$USERNAME@$FQDN" bash -lc \  # run login shell to source profiles
         "export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none && \
          sudo --preserve-env=DEBIAN_FRONTEND,APT_LISTCHANGES_FRONTEND $REMOTE_CMD" \  # preserve env for sudo
         2>&1 | tee -a "$DETAIL_LOGFILE"; then  # log both stdout and stderr
    # On success, record timestamped OK message in summary log
    echo "$(date +'%F %T')  [OK]   Updated $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")  # add to success list
  else
    # On failure, record timestamped FAIL message in summary log
    echo "$(date +'%F %T')  [FAIL] Update failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")  # add to fail list
  fi

done < "$HOSTFILE"                 # end of host loop

# —— Summary to console ——
echo                                  # blank line for readability
 echo "📊 Update Summary"            # header
 echo "================="
 echo "✅ Succeeded (${#SUCCESS[@]}):"
 for host in "${SUCCESS[@]}"; do      # list each successful host
   echo "  - $host"
done

echo                                  # blank line
 echo "❌ Failed   (${#FAIL[@]}):"
 for host in "${FAIL[@]}"; do         # list each failed host
   echo "  - $host"
done

echo                                  # blank line
 echo "📝 Logs: summary in $SUMMARY_LOGFILE and full output in $DETAIL_LOGFILE"
