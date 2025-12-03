#!/usr/bin/env bash
#
# Script: remote-batch-get-arch-advanced.sh
# Description:
#   Like remote-batch-get-arch.sh, but with small best-practice improvements:
#     - CLI flags to override username, hostfile, key, domain, and log prefix
#     - Simple --help usage
#     - Same logging pattern, easier to re-use for other fleet commands
#
# Usage examples:
#   ./remote-batch-get-arch-advanced.sh
#   ./remote-batch-get-arch-advanced.sh -u pi -H ./my-hosts.txt
#   ./remote-batch-get-arch-advanced.sh -p fleet-arch
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Defaults (can be overridden by flags) ——
USERNAME_FILE_DEFAULT="$SCRIPT_DIR/username.txt"
HOSTFILE_DEFAULT="$SCRIPT_DIR/remote-hosts.txt"
KEY_FILE_DEFAULT="${HOME}/.ssh/id_ed25519_server_fleet"
HOSTDOMAIN_DEFAULT=""
LOG_PREFIX_DEFAULT="arch"

USERNAME_FILE="$USERNAME_FILE_DEFAULT"
HOSTFILE="$HOSTFILE_DEFAULT"
KEY_FILE="$KEY_FILE_DEFAULT"
HOSTDOMAIN="$HOSTDOMAIN_DEFAULT"
LOG_PREFIX="$LOG_PREFIX_DEFAULT"

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -u, --user USER           Override SSH username (default: from username.txt)
  -H, --hostfile FILE       Override host list file (default: remote-hosts.txt)
  -k, --key FILE            Override SSH key file (default: ~/.ssh/id_ed25519_server_fleet)
  -d, --domain SUFFIX       Default domain to append to bare hostnames (e.g. .local)
  -p, --log-prefix PREFIX   Prefix for log filenames (default: "${LOG_PREFIX_DEFAULT}")
  -h, --help                Show this help and exit

Notes:
  - username.txt and remote-hosts.txt are still respected by default.
  - Logs are written to: ../logs/\${PREFIX}-summary.log and \${PREFIX}-detail.log
EOF
}

# —— Argument parsing ——
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)
      shift
      SSH_USER_OVERRIDE="${1:-}"
      ;;
    -H|--hostfile)
      shift
      HOSTFILE="${1:-}"
      ;;
    -k|--key)
      shift
      KEY_FILE="${1:-}"
      ;;
    -d|--domain)
      shift
      HOSTDOMAIN="${1:-}"
      ;;
    -p|--log-prefix)
      shift
      LOG_PREFIX="${1:-}"
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1"
      echo
      print_help
      exit 1
      ;;
  esac
  shift || true
done

# —— Configuration derived from prefix ——
SUMMARY_LOGFILE="$LOG_DIR/${LOG_PREFIX}-summary.log"
DETAIL_LOGFILE="$LOG_DIR/${LOG_PREFIX}-detail.log"

# —— Input validation ——
[[ -f "$HOSTFILE" ]] || { echo "❌ Missing host file: $HOSTFILE"; exit 1; }
[[ -s "$HOSTFILE" ]] || { echo "❌ Host file is empty: $HOSTFILE"; exit 1; }

if [[ -n "${SSH_USER_OVERRIDE:-}" ]]; then
  USERNAME="$SSH_USER_OVERRIDE"
else
  [[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
  read -r USERNAME < "$USERNAME_FILE"
fi

[[ -f "$KEY_FILE" ]] || { echo "❌ Missing SSH key at $KEY_FILE"; exit 1; }

if command -v stat >/dev/null 2>&1; then
  key_perm="$(stat -c '%a' "$KEY_FILE" 2>/dev/null || echo 600)"
  case "$key_perm" in
    600|400) : ;;
    *)
      echo "❌ SSH key permissions too open ($key_perm). Run: chmod 600 '$KEY_FILE'"
      exit 1
      ;;
  esac
fi

SSH_OPTS=(
  -n
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

REMOTE_CMD='
  echo "=== uname -m (machine hardware name) ==="
  uname -m
  echo
  echo "=== uname -srm (kernel + arch) ==="
  uname -srm
'

touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

trim() {
  local s="$1"
  # shellcheck disable=SC2001
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
    echo "$raw"
    return
  fi

  if [[ "$raw" == *.* ]]; then
    echo "$raw"
    return
  fi

  if [[ -n "$HOSTDOMAIN" ]]; then
    echo "${raw}${HOSTDOMAIN}"
  else
    echo "$raw"
  fi
}

while IFS= read -r SERVER || [[ -n "${SERVER:-}" ]]; do
  SERVER="$(trim "$SERVER")"
  [[ -z "$SERVER" || "$SERVER" =~ ^[[:space:]]*# ]] && continue

  FQDN="$(build_fqdn "$SERVER")"

  echo "➡️  Retrieving architecture info from $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  if ssh "${SSH_OPTS[@]}" "$USERNAME@$FQDN" "$REMOTE_CMD" 2>&1 | tee -a "$DETAIL_LOGFILE"; then
    echo "$(date +'%F %T')  [OK]   Arch info retrieved from $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Arch info retrieval failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < "$HOSTFILE"

echo
echo "📊 ${LOG_PREFIX^} Info Retrieval Summary"
echo "================================="
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
