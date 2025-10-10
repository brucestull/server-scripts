#!/usr/bin/env bash
#
# Script: remote-batch-sync-scripts.sh
# Description:
#   Rsync the local server-scripts directory to each remote host,
#   record successes/failures in a timestamped log, and print a summary.
#
# Usage:
#   ./remote-batch-sync-scripts.sh
#
# Notes:
#   - Put SSH username in ./username.txt (single line).
#   - Put hosts in ./remote-hosts.txt (one per line). Lines may be:
#       * bare hostnames (e.g., SPINAL-TAP)            -> appends HOSTDOMAIN if set
#       * FQDNs (e.g., spinal-tap.local)               -> used as-is
#       * IPv4 addresses (e.g., 192.168.1.10)          -> used as-is
#       * comments starting with # and blank lines are ignored
#       * per-line domain override: HOST@domain        -> becomes HOST.domain
#
#   - Set DEBUG=1 for bash xtrace
#   - Set DRY_RUN=1 to pass --dry-run to rsync
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

# —— Directories ——
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Configuration ——
USERNAME_FILE="$SCRIPT_DIR/username.txt"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"

# Append to bare hostnames only; leave empty ("") to use bare names as-is.
HOSTDOMAIN=""

# SSH key
KEY_FILE="${HOME}/.ssh/id_ed25519_server_fleet"

# Source (local) and destination (remote)
# Trailing slash on SOURCE_DIR ensures "contents of dir" are synced into DEST_DIR.
SOURCE_DIR="${SCRIPT_DIR}/"
DEST_DIR="~/server-scripts/"

# Logging
LOGFILE="$LOG_DIR/sync-results.log"

# Rsync extra flags
RSYNC_FLAGS=(
  -avz
  --delete-excluded
  --exclude='.git/'
  --exclude='.gitignore'
  --exclude='sync-results.log'
  --exclude='update-results.log'
  --exclude='shutdown-cancel-results.log'
  --exclude='shutdown-remote-servers-results.log'
  --exclude='reboot-remote-servers-results.log'
  --exclude='remote-hosts.txt'
  --exclude='username.txt'
)

# Optional dry run
if [[ "${DRY_RUN:-0}" = "1" ]]; then
  RSYNC_FLAGS+=(--dry-run)
fi

# SSH options
SSH_OPTS=(
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

# Build the rsync -e command safely
RSYNC_SSH_CMD=$(printf ' %q' ssh "${SSH_OPTS[@]}")

# —— Validation ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
[[ -s "$HOSTFILE"     ]] || { echo "❌ Missing or empty $HOSTFILE"; exit 1; }
[[ -d "$SCRIPT_DIR"   ]] || { echo "❌ SCRIPT_DIR not found: $SCRIPT_DIR"; exit 1; }
[[ -d "$LOG_DIR"      ]] || { echo "❌ LOG_DIR not found: $LOG_DIR"; exit 1; }
[[ -f "$KEY_FILE"     ]] || { echo "❌ Missing SSH key at $KEY_FILE"; exit 1; }

# Enforce tight key perms (OpenSSH rejects world-writable)
if command -v stat >/dev/null 2>&1; then
  key_perm="$(stat -c '%a' "$KEY_FILE" 2>/dev/null || echo 600)"
  case "$key_perm" in
    600|400) : ;;
    *) echo "❌ SSH key permissions too open ($key_perm). Run: chmod 600 '$KEY_FILE'"; exit 1 ;;
  esac
fi

read -r USERNAME < "$USERNAME_FILE"

# Reset log header
{
  echo "=== Sync run at $(date '+%F %T') ==="
  [[ "${DRY_RUN:-0}" = "1" ]] && echo "(dry run)"
} > "$LOGFILE"

# —— Helpers ——
trim() {
  local s="$1"
  s="$(sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' <<<"$s")"
  printf '%s' "$s"
}

build_fqdn() {
  local raw="$1"
  if [[ "$raw" == *@* ]]; then
    local host_part="${raw%@*}"
    local dom_part="${raw#*@}"
    echo "${host_part}.${dom_part}"
    return
  fi
  if [[ "$raw" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$raw"; return
  fi
  if [[ "$raw" == *.* ]]; then
    echo "$raw"; return
  fi
  if [[ -n "$HOSTDOMAIN" ]]; then
    echo "${raw}${HOSTDOMAIN}"
  else
    echo "$raw"
  fi
}

# —— Main ——
SUCCESS=()
FAIL=()

while IFS= read -r LINE || [[ -n "$LINE" ]]; do
  SERVER="$(trim "${LINE//$'\r'/}")"
  [[ -z "$SERVER" || "$SERVER" =~ ^[[:space:]]*# ]] && continue

  FQDN="$(build_fqdn "$SERVER")"
  echo "➡️  Syncing to $FQDN…" | tee -a "$LOGFILE"

  if rsync "${RSYNC_FLAGS[@]}" \
           -e "$RSYNC_SSH_CMD" \
           "$SOURCE_DIR" \
           "${USERNAME}@${FQDN}:$DEST_DIR" >>"$LOGFILE" 2>&1; then
    echo "$(date +'%F %T')  [OK]   Synced to $FQDN"   | tee -a "$LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Sync failed on $FQDN" | tee -a "$LOGFILE"
    FAIL+=("$FQDN")
  fi
done < "$HOSTFILE"

# —— Summary ——
{
  echo
  echo "📊 Rsync Summary"
  echo "================"
  printf "✅ Succeeded (%d):\n" "${#SUCCESS[@]}"
  for h in "${SUCCESS[@]}"; do echo "  - $h"; done

  echo
  printf "❌ Failed   (%d):\n" "${#FAIL[@]}"
  for h in "${FAIL[@]}"; do echo "  - $h"; done

  echo
  echo "📝 Full details in $LOGFILE"
} | tee -a "$LOGFILE"
