#!/usr/bin/env bash
#
# Script: remote-batch-get-ram-with-libs.sh
# Description:
#   SSH into each host and retrieve RAM (and swap) info.
#   Writes a one-line-per-host summary log and a full detail log.
#
# Usage:
#   ./remote-batch-get-ram-with-libs.sh
#
# Set DEBUG=1 for bash xtrace:
#   DEBUG=1 ./remote-batch-get-ram-with-libs.sh
#
# Requirements:
#   - lib-secrets.sh and lib-hosts.sh in the same directory as this script
#   - .secrets contains:
#       USER_NAME="youruser"
#       SSH_KEY_PATH="/absolute/path/to/key"
#     Optional:
#       HOSTDOMAIN=".local"
#   - remote-hosts.txt contains hostnames/IPs (comments/blanks allowed)
#

set -euo pipefail
trap 'rc=$?; echo "💥 Error on line $LINENO (exit $rc)"; exit $rc' ERR
[[ "${DEBUG:-0}" = "1" ]] && set -x

# —— Directories ——
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Imports ——
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-secrets.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib-hosts.sh"

# —— Files ——
SECRETS_FILE="$SCRIPT_DIR/.secrets"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"

# Optional default domain appended to bare hostnames (can be set here or in .secrets as HOSTDOMAIN)
HOSTDOMAIN="${HOSTDOMAIN:-}"

# —— Load secrets ——
load_secrets "$SECRETS_FILE"
require_vars "$SECRETS_FILE" USER_NAME SSH_KEY_PATH
check_ssh_key_file "$SSH_KEY_PATH"

USERNAME="$USER_NAME"
KEY_FILE="$SSH_KEY_PATH"

# SSH options
SSH_OPTS=(
  -n
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=5
  -o ConnectionAttempts=1
)

# Remote command:
# Prefer `free` if available, but always fall back to /proc/meminfo.
# Emit machine-parsable key=value lines first, then human-friendly output.
# Build remote command safely (no accidental local expansion)
REMOTE_CMD="$(cat <<'EOF'
set -euo pipefail

echo "remote_hostname=$(hostname 2>/dev/null || echo unknown)"
echo "remote_kernel=$(uname -r 2>/dev/null || echo unknown)"

if command -v free >/dev/null 2>&1; then
  free -b | awk '
    $1=="Mem:" {
      printf "ram_total_bytes=%s\nram_used_bytes=%s\nram_free_bytes=%s\nram_shared_bytes=%s\nram_buff_cache_bytes=%s\nram_available_bytes=%s\n", $2,$3,$4,$5,$6,$7
    }
    $1=="Swap:" {
      printf "swap_total_bytes=%s\nswap_used_bytes=%s\nswap_free_bytes=%s\n", $2,$3,$4
    }
  '
  echo
  echo "=== free -h ==="
  free -h
else
  awk '
    $1=="MemTotal:"{t=$2}
    $1=="MemFree:"{f=$2}
    $1=="MemAvailable:"{a=$2}
    $1=="SwapTotal:"{st=$2}
    $1=="SwapFree:"{sf=$2}
    END{
      printf "ram_total_kb=%s\nram_free_kb=%s\nram_available_kb=%s\nswap_total_kb=%s\nswap_free_kb=%s\n", t,f,a,st,sf
    }
  ' /proc/meminfo

  echo
  echo "=== /proc/meminfo (key lines) ==="
  egrep "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree" /proc/meminfo || true
fi
EOF
)"


SUMMARY_LOGFILE="$LOG_DIR/ram-summary.log"
DETAIL_LOGFILE="$LOG_DIR/ram-detail.log"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"

SUCCESS=()
FAIL=()

bytes_to_gib() {
  local b="${1:-0}"
  awk -v b="$b" 'BEGIN { printf "%.2f", (b / 1024 / 1024 / 1024) }'
}

kb_to_gib() {
  local kb="${1:-0}"
  awk -v kb="$kb" 'BEGIN { printf "%.2f", (kb / 1024 / 1024) }'
}

get_kv() {
  # Usage: get_kv "key" "$text"
  local key="$1"
  local text="$2"
  grep -m1 "^${key}=" <<<"$text" | cut -d= -f2- || true
}

while IFS= read -r SERVER; do
  FQDN="$(build_fqdn "$SERVER" "$HOSTDOMAIN")"

  echo "➡️  Retrieving RAM info from $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  if OUT="$(ssh "${SSH_OPTS[@]}" "$USERNAME@$FQDN" "$REMOTE_CMD" 2>&1 | tee -a "$DETAIL_LOGFILE")"; then
    # Prefer bytes-based values (from `free -b`)
    ram_total_bytes="$(get_kv "ram_total_bytes" "$OUT")"
    ram_used_bytes="$(get_kv "ram_used_bytes" "$OUT")"
    ram_avail_bytes="$(get_kv "ram_available_bytes" "$OUT")"
    swap_total_bytes="$(get_kv "swap_total_bytes" "$OUT")"
    swap_used_bytes="$(get_kv "swap_used_bytes" "$OUT")"

    # Fallback to kB-based values (from /proc/meminfo parsing)
    ram_total_kb="$(get_kv "ram_total_kb" "$OUT")"
    ram_avail_kb="$(get_kv "ram_available_kb" "$OUT")"
    swap_total_kb="$(get_kv "swap_total_kb" "$OUT")"
    swap_free_kb="$(get_kv "swap_free_kb" "$OUT")"

    if [[ -n "$ram_total_bytes" && -n "$ram_avail_bytes" ]]; then
      total_gib="$(bytes_to_gib "$ram_total_bytes")"
      used_gib="$(bytes_to_gib "${ram_used_bytes:-0}")"
      avail_gib="$(bytes_to_gib "$ram_avail_bytes")"
      if [[ -n "$swap_total_bytes" ]]; then
        swap_total_gib="$(bytes_to_gib "$swap_total_bytes")"
        swap_used_gib="$(bytes_to_gib "${swap_used_bytes:-0}")"
      else
        swap_total_gib="0.00"
        swap_used_gib="0.00"
      fi
    else
      # /proc/meminfo path (kB)
      total_gib="$(kb_to_gib "${ram_total_kb:-0}")"
      avail_gib="$(kb_to_gib "${ram_avail_kb:-0}")"
      # best-effort used: total - available (approx)
      used_gib="$(awk -v t="${ram_total_kb:-0}" -v a="${ram_avail_kb:-0}" 'BEGIN{ printf "%.2f", ((t-a)/1024/1024) }')"

      if [[ -n "$swap_total_kb" && -n "$swap_free_kb" ]]; then
        swap_total_gib="$(kb_to_gib "$swap_total_kb")"
        swap_used_gib="$(awk -v st="$swap_total_kb" -v sf="$swap_free_kb" 'BEGIN{ printf "%.2f", ((st-sf)/1024/1024) }')"
      else
        swap_total_gib="0.00"
        swap_used_gib="0.00"
      fi
    fi

    echo "$(date +'%F %T')  [OK]   $FQDN  RAM(total=${total_gib}GiB used=${used_gib}GiB avail=${avail_gib}GiB)  SWAP(total=${swap_total_gib}GiB used=${swap_used_gib}GiB)" \
      | tee -a "$SUMMARY_LOGFILE"

    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] $FQDN  RAM info retrieval failed" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < <(iter_hosts "$HOSTFILE")

echo
echo "📊 RAM Retrieval Summary"
echo "========================"
echo "✅ Succeeded (${#SUCCESS[@]}):"
for host in "${SUCCESS[@]}"; do echo "  - $host"; done
echo
echo "❌ Failed   (${#FAIL[@]}):"
for host in "${FAIL[@]}"; do echo "  - $host"; done
echo
echo "📝 Logs: summary in $SUMMARY_LOGFILE and full output in $DETAIL_LOGFILE"
