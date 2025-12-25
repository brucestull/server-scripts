#!/usr/bin/env bash
#
# Script: remote-batch-get-os-per-host-key.sh
# Description:
#   SSH into each host using a per-host key derived from hostname:
#     HOSTNAME "SPINAL-TAP" -> ~/.ssh/id_ed25519_desk_wsl_to_spinal_tap
#   Run `lsb_release -a` if available, else `cat /etc/os-release`.
#
# Usage:
#   ./remote-batch-get-os-per-host-key.sh
#
# Inputs:
#   - ./username.txt        (single line SSH username)
#   - ./remote-hosts.txt    (one host per line; blank lines/# comments ignored)
#
# Optional:
#   - ./host-keys.override  (per-host override lines: HOSTNAME|/path/to/key)
#
# Notes:
#   - If a host has no matching key file, it will be recorded as FAIL (no SSH attempt).
#   - Set DEBUG=1 for xtrace:
#       DEBUG=1 ./remote-batch-get-os-per-host-key.sh
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
OVERRIDE_FILE="$SCRIPT_DIR/host-keys.override"   # optional

# If you want to automatically append a domain to *bare* hostnames, set HOSTDOMAIN.
HOSTDOMAIN=""

# Base key prefix for derived per-host key paths:
KEY_PREFIX="${HOME}/.ssh/id_ed25519_desk_wsl_to_"

# SSH options (key path will be added per host)
BASE_SSH_OPTS=(
  -n
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

REMOTE_CMD='
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -a
  else
    echo "=== /etc/os-release ==="
    cat /etc/os-release
  fi
'

SUMMARY_LOGFILE="$LOG_DIR/os-summary.log"
DETAIL_LOGFILE="$LOG_DIR/os-detail.log"

# —— Input validation ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
[[ -s "$HOSTFILE"     ]] || { echo "❌ Missing or empty $HOSTFILE"; exit 1; }

read -r USERNAME < "$USERNAME_FILE"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

trim() {
  local s="$1"
  s="$(sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' <<<"$s")"
  printf '%s' "$s"
}

build_fqdn() {
  local raw="$1"

  # per-line domain override: HOST@domain -> HOST.domain
  if [[ "$raw" == *@* ]]; then
    local host_part="${raw%@*}"
    local dom_part="${raw#*@}"
    echo "${host_part}.${dom_part}"
    return
  fi

  # IPv4?
  if [[ "$raw" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$raw"
    return
  fi

  # Already FQDN?
  if [[ "$raw" == *.* ]]; then
    echo "$raw"
    return
  fi

  # Bare hostname
  if [[ -n "$HOSTDOMAIN" ]]; then
    echo "${raw}${HOSTDOMAIN}"
  else
    echo "$raw"
  fi
}

# Convert host token to your key suffix:
#   SPINAL-TAP -> spinal_tap
host_to_key_suffix() {
  local host="$1"
  # Keep only the host part (strip domain if FQDN)
  host="${host%%.*}"
  # Upper -> lower, hyphen -> underscore
  host="$(tr '[:upper:]' '[:lower:]' <<<"$host")"
  host="${host//-/_}"
  printf '%s' "$host"
}

# Load overrides into associative array: OVERRIDE_KEYS["HOSTNAME"]="/path/to/key"
declare -A OVERRIDE_KEYS=()
if [[ -f "$OVERRIDE_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Format: HOSTNAME|/full/path/to/key
    if [[ "$line" == *"|"* ]]; then
      host_part="$(trim "${line%%|*}")"
      key_part="$(trim "${line#*|}")"
      [[ -n "$host_part" && -n "$key_part" ]] && OVERRIDE_KEYS["$host_part"]="$key_part"
    fi
  done < "$OVERRIDE_FILE"
fi

check_key_perms() {
  local key_file="$1"
  [[ -f "$key_file" ]] || return 1

  if command -v stat >/dev/null 2>&1; then
    local key_perm
    key_perm="$(stat -c '%a' "$key_file" 2>/dev/null || echo 600)"
    case "$key_perm" in
      600|400) return 0 ;;
      *)
        echo "❌ Key perms too open for $key_file ($key_perm). Fix: chmod 600 '$key_file'"
        return 2
        ;;
    esac
  fi

  return 0
}

resolve_key_for_host() {
  local server_raw="$1"     # as read from file (might be HOST@domain etc.)
  local fqdn="$2"           # computed target (might be FQDN/IP/bare)
  local host_token          # the "host" name we match overrides on (original bare host if possible)

  # Prefer overrides by the *raw* bare hostname token (strip @domain and strip .domain)
  host_token="${server_raw%@*}"
  host_token="${host_token%%.*}"

  if [[ -n "${OVERRIDE_KEYS[$host_token]:-}" ]]; then
    printf '%s' "${OVERRIDE_KEYS[$host_token]}"
    return 0
  fi

  # Derive from fqdn/ip/bare:
  # - If fqdn is IPv4, we can't derive a meaningful name; try server_raw token instead.
  if [[ "$fqdn" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local suffix
    suffix="$(host_to_key_suffix "$host_token")"
    printf '%s' "${KEY_PREFIX}${suffix}"
    return 0
  fi

  local suffix
  suffix="$(host_to_key_suffix "$fqdn")"
  printf '%s' "${KEY_PREFIX}${suffix}"
}

# —— Loop through hosts ——
while IFS= read -r SERVER || [[ -n "$SERVER" ]]; do
  SERVER="$(trim "$SERVER")"
  [[ -z "$SERVER" || "$SERVER" =~ ^[[:space:]]*# ]] && continue

  FQDN="$(build_fqdn "$SERVER")"
  KEY_FILE="$(resolve_key_for_host "$SERVER" "$FQDN")"

  echo ""
  echo "➡️  Retrieving OS info from $FQDN…"
  printf "\n===== %s - %s =====\nKey: %s\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" "$KEY_FILE" \
    | tee -a "$DETAIL_LOGFILE"

  if [[ ! -f "$KEY_FILE" ]]; then
    echo "$(date +'%F %T')  [FAIL] Missing SSH key for $FQDN: $KEY_FILE" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN (missing key)")
    continue
  fi

  if ! check_key_perms "$KEY_FILE"; then
    echo "$(date +'%F %T')  [FAIL] Bad SSH key permissions for $FQDN: $KEY_FILE" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN (bad key perms)")
    continue
  fi

  if ssh "${BASE_SSH_OPTS[@]}" -i "$KEY_FILE" "$USERNAME@$FQDN" "$REMOTE_CMD" 2>&1 | tee -a "$DETAIL_LOGFILE"; then
    echo "$(date +'%F %T')  [OK]   OS info retrieved from $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] OS info retrieval failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
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
