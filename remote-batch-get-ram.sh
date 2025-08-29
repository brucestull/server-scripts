#!/usr/bin/env bash
#
# Script: remote-batch-get-ram.sh
# Description:
#   SSH into each host, detect total physical RAM, record successes/failures
#   in a summary log, capture full output in a detailed log, and write a
#   machine-readable TSV of host → RAM bytes/GiB.
#
# Usage:
#   ./remote-batch-get-ram.sh
#

set -euo pipefail

# —— Directories ——
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# —— Configuration ——
USERNAME_FILE="$SCRIPT_DIR/username.txt"
HOSTFILE="$SCRIPT_DIR/remote-hosts.txt"
HOSTDOMAIN=".lan"
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"

# Try Linux (/proc/meminfo), or macOS/BSD (sysctl) — print both human + machine-readable lines.
REMOTE_CMD='
# Determine total RAM in bytes; print friendly lines AND machine-readable keys.
if [ -r /proc/meminfo ]; then
  kb=$(grep -i "^MemTotal:" /proc/meminfo | awk "{print \$2}")
  bytes=$((kb * 1024))
elif command -v sysctl >/dev/null 2>&1; then
  for key in hw.memsize hw.physmem64 hw.physmem; do
    if sysctl "$key" >/dev/null 2>&1; then
      bytes=$(sysctl -n "$key")
      break
    fi
  done
fi

if [ -z "${bytes:-}" ]; then
  echo "Unable to determine RAM size"
  exit 2
fi

if command -v bc >/dev/null 2>&1; then
  gib=$(echo "$bytes/1073741824" | bc -l)
  printf "Total RAM: %s bytes (%.2f GiB)\n" "$bytes" "$gib"
  printf "RAM_BYTES=%s\n" "$bytes"
  printf "RAM_GIB=%.2f\n" "$gib"
else
  gib=$(( bytes / 1073741824 ))
  rem=$(( (bytes % 1073741824) * 100 / 1073741824 ))
  mib=$(( bytes / 1048576 ))
  printf "Total RAM: %s bytes (~%d.%02d GiB, %d MiB)\n" "$bytes" "$gib" "$rem" "$mib"
  printf "RAM_BYTES=%s\n" "$bytes"
  printf "RAM_GIB=%d.%02d\n" "$gib" "$rem"
fi
'

SUMMARY_LOGFILE="$LOG_DIR/ram-summary.log"
DETAIL_LOGFILE="$LOG_DIR/ram-detail.log"
RAM_TSV="$LOG_DIR/ram-by-host.tsv"

# —— Prep ——
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"
touch "$SUMMARY_LOGFILE" "$DETAIL_LOGFILE"
printf "host\tbytes\tGiB\n" > "$RAM_TSV"

# —— Result arrays ——
SUCCESS=()
FAIL=()

# —— Loop through hosts ——
while IFS= read -r SERVER; do
  [[ -z "$SERVER" ]] && continue
  FQDN="${SERVER}${HOSTDOMAIN}"

  echo "➡️  Retrieving RAM info from $FQDN…"
  printf "\n===== %s - %s =====\n\n" "$FQDN" "$(date '+%Y-%m-%d %H:%M:%S')" \
    | tee -a "$DETAIL_LOGFILE"

  # temp capture for parsing while still tee-ing to detail log
  TMP_OUT="$(mktemp)"
  if ssh -n -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         "$USERNAME@$FQDN" "$REMOTE_CMD" \
         2>&1 | tee -a "$DETAIL_LOGFILE" | tee "$TMP_OUT" >/dev/null; then

    # Parse machine-readable lines from the remote output
    BYTES="$(grep -E '^RAM_BYTES=' "$TMP_OUT" | tail -n1 | cut -d= -f2 || true)"
    GIB="$(grep -E '^RAM_GIB=' "$TMP_OUT"   | tail -n1 | cut -d= -f2 || true)"

    if [[ -n "${BYTES}" && -n "${GIB}" ]]; then
      printf "%s\t%s\t%s\n" "$FQDN" "$BYTES" "$GIB" >> "$RAM_TSV"
      echo "$(date +'%F %T')  [OK]   RAM info retrieved from $FQDN  (${GIB} GiB)" \
        | tee -a "$SUMMARY_LOGFILE"
      SUCCESS+=("$FQDN")
    else
      echo "$(date +'%F %T')  [FAIL] RAM parsing failed on $FQDN" \
        | tee -a "$SUMMARY_LOGFILE"
      FAIL+=("$FQDN")
    fi
  else
    echo "$(date +'%F %T')  [FAIL] RAM info retrieval failed on $FQDN" \
      | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
  rm -f "$TMP_OUT"

done < "$HOSTFILE"

# —— Summary to console ——
echo
echo "📊 RAM Info Retrieval Summary"
echo "============================="
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
echo "📝 Logs: summary in $SUMMARY_LOGFILE, full output in $DETAIL_LOGFILE"
echo "📄 TSV:  $RAM_TSV  (columns: host, bytes, GiB)"
