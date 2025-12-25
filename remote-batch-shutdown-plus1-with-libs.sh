#!/usr/bin/env bash
#
# Script: remote-batch-shutdown-plus1.sh
# Description:
#   SSH into each host and schedule a poweroff in 1 minute.
#   Logs successes/failures in a summary log; full output in a detail log.
#
# Usage:
#   ./remote-batch-shutdown-plus1.sh
#   ./remote-batch-shutdown-plus1.sh --dry-run
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Imports ——
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-secrets.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-hosts.sh"

SECRETS_FILE="$SCRIPT_DIR/.secrets"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"

# Optional domain (can be set here or in .secrets as HOSTDOMAIN)
HOSTDOMAIN="${HOSTDOMAIN:-}"

DRY_RUN="false"
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN="true"

SUMMARY_LOGFILE="$LOG_DIR/shutdown-summary.log"
DETAIL_LOGFILE="$LOG_DIR/shutdown-detail.log"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

# —— Load secrets ——
load_secrets "$SECRETS_FILE"
require_vars "$SECRETS_FILE" USER_NAME SSH_KEY_PATH
check_ssh_key_file "$SSH_KEY_PATH"

USERNAME="$USER_NAME"
KEY_FILE="$SSH_KEY_PATH"
PASSWORD="${PASSWORD:-}"

# Base SSH options
SSH_OPTS_BASE=(
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

# For normal non-interactive commands (no stdin)
SSH_OPTS_NONINTERACTIVE=(
  -n
  "${SSH_OPTS_BASE[@]}"
)

# For sudo -S fallback (needs stdin/tty)
SSH_OPTS_INTERACTIVE=(
  -tt
  "${SSH_OPTS_BASE[@]}"
)

SUCCESS=()
FAIL=()

REMOTE_MSG="Remote maintenance shutdown (+1 min)"
CMD_NO_PASS="sudo -n shutdown -h +1 \"$REMOTE_MSG\""
CMD_WITH_PASS="sudo -S -p '' shutdown -h +1 \"$REMOTE_MSG\""

while IFS= read -r SERVER; do
  FQDN="$(build_fqdn "$SERVER" "$HOSTDOMAIN")"

  echo "➡️  Scheduling shutdown (+1 min) on $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN: would run on $FQDN: $CMD_NO_PASS" | tee -a "$DETAIL_LOGFILE"
    echo "$(date +'%F %T')  [DRY]  Shutdown would be scheduled on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
    continue
  fi

  # 1) Prefer passwordless sudo
  if ssh "${SSH_OPTS_NONINTERACTIVE[@]}" "$USERNAME@$FQDN" "$CMD_NO_PASS" 2>&1 | tee -a "$DETAIL_LOGFILE"; then
    echo "$(date +'%F %T')  [OK]   Shutdown scheduled on $FQDN (+1 min)" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
    continue
  fi

  # 2) Fallback to sudo -S if PASSWORD provided
  if [[ -n "$PASSWORD" ]]; then
    # Feed password to remote sudo via stdin; -tt helps if sudo insists on a tty.
    if printf '%s\n' "$PASSWORD" | ssh "${SSH_OPTS_INTERACTIVE[@]}" "$USERNAME@$FQDN" "$CMD_WITH_PASS" \
        2>&1 | tee -a "$DETAIL_LOGFILE"; then
      echo "$(date +'%F %T')  [OK]   Shutdown scheduled on $FQDN (+1 min) (sudo -S fallback)" \
        | tee -a "$SUMMARY_LOGFILE"
      SUCCESS+=("$FQDN")
    else
      echo "$(date +'%F %T')  [FAIL] Shutdown scheduling failed on $FQDN (sudo -S fallback)" \
        | tee -a "$SUMMARY_LOGFILE"
      FAIL+=("$FQDN")
    fi
  else
    echo "$(date +'%F %T')  [FAIL] Shutdown scheduling failed on $FQDN (sudo likely requires a password; PASSWORD not set)" \
      | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi

done < <(iter_hosts "$HOSTFILE")

echo
echo "📊 Remote Shutdown (+1 minute) Summary"
echo "====================================="
echo "✅ Succeeded (${#SUCCESS[@]}):"
for host in "${SUCCESS[@]}"; do echo "  - $host"; done
echo
echo "❌ Failed   (${#FAIL[@]}):"
for host in "${FAIL[@]}"; do echo "  - $host"; done
echo
echo "📝 Logs: summary in $SUMMARY_LOGFILE, full output in $DETAIL_LOGFILE"
echo "ℹ️  Cancel on a host (before it powers off): sudo shutdown -c"
