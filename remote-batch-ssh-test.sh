#!/usr/bin/env bash
set -euo pipefail

HOSTS_FILE="${1:-remote-hosts.txt}"
SSH_CONFIG="${2:-$HOME/.ssh/config}"
TIMEOUT="${3:-5}"

if [[ ! -f "$HOSTS_FILE" ]]; then
  echo "❌ Hosts file not found: $HOSTS_FILE" >&2
  exit 1
fi

if [[ ! -f "$SSH_CONFIG" ]]; then
  echo "❌ SSH config not found: $SSH_CONFIG" >&2
  exit 1
fi

echo "🔎 Using hosts:     $HOSTS_FILE"
echo "🔧 Using ssh config: $SSH_CONFIG"
echo "⏱️  ConnectTimeout:  ${TIMEOUT}s"
echo

ok=0
fail=0
skipped=0

while IFS= read -r raw || [[ -n "$raw" ]]; do
  host="$(echo "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  if [[ -z "$host" || "$host" == \#* ]]; then
    ((skipped+=1))
    continue
  fi

  echo "===== $host ====="

  ssh -F "$SSH_CONFIG" -G "$host" 2>/dev/null | awk '
    $1 ~ /^(user|hostname|identityfile)$/ { print "  " $1 ": " $2 }
  ' || echo "  (Could not resolve config via: ssh -G $host)"

  # IMPORTANT: -n prevents ssh from consuming the hosts file via stdin.
  if ssh -n -F "$SSH_CONFIG" \
      -o BatchMode=yes \
      -o ConnectTimeout="$TIMEOUT" \
      -o PasswordAuthentication=no \
      -o StrictHostKeyChecking=accept-new \
      "$host" 'echo "  ✅ connected: $(hostname)  user: $(whoami)"' ; then
    echo "✅ PASS: $host"
    ((ok+=1))
  else
    echo "❌ FAIL: $host"
    ((fail+=1))
  fi

  echo
done < "$HOSTS_FILE"

echo "========== SUMMARY =========="
echo "✅ Passed : $ok"
echo "❌ Failed : $fail"
echo "⏭️  Skipped: $skipped (blank/comment lines)"
echo "============================="

[[ "$fail" -eq 0 ]]
