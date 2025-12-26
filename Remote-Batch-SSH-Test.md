# SSH Config and Script

- [SSH Config and Script - ChatGPT - Private](https://chatgpt.com/c/694e7344-1438-8333-ab5d-edb39f0eb524)

Your `~/.ssh/config` is **cromulent++**. ✅ It’s a clean, standard pattern:

* **Specific host blocks** (GitHub, each Pi, react-nodes)
* A **shared “Pi Fleet” settings block** that applies `User`, `IdentityFile`, `IdentitiesOnly`
* A **catch-all `Host *`** at the very end for sane defaults (good placement)

### What’s especially good here

* `IdentitiesOnly yes` + `IdentityFile ...` for the fleet: prevents “too many keys tried” / wrong-key weirdness.
* Per-host `HostName <IP>` keeps your command simple: `ssh SPINAL-TAP`.
* `HostKeyAlias <NAME>` is a nice trick so your known_hosts entries track the **stable alias**, not the IP.

### Tiny nits / gotchas (not “wrong”, just worth knowing)

1. **Your test script and new hosts**

   * Your config has `StrictHostKeyChecking ask`.
   * If a host key is *new/unseen*, `ssh` may prompt interactively.
   * In a non-interactive test script, that can look like a “failure” even though it’s fine.
   * Fix: in the script, override with `StrictHostKeyChecking=accept-new` (safe-ish for first contact on a trusted LAN).

2. **remote-hosts.txt must match your `Host` aliases**

   * If `remote-hosts.txt` contains raw IPs or FQDNs that aren’t defined in the config, they’ll fall under `Host *` and won’t inherit the fleet `User`/`IdentityFile`.
   * If your file contains the aliases (e.g., `SPINAL-TAP`), you’re perfect.

3. (Optional hygiene) Make sure permissions are tight:

   * `chmod 600 ~/.ssh/config`
   * `chmod 600 ~/.ssh/id_ed25519_*`

---

## Bash script: test SSH connectivity using your config

Save as: `remote-batch-ssh-test.sh` (next to `remote-hosts.txt`), then `chmod +x remote-batch-ssh-test.sh`.

```bash
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
  # Strip leading/trailing whitespace
  host="$(echo "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  # Skip blanks and comments
  if [[ -z "$host" || "$host" == \#* ]]; then
    ((skipped+=1))
    continue
  fi

  echo "===== $host ====="

  # Show what SSH thinks it will use (user/identityfile/hostname), helpful for debugging.
  # ssh -G exits nonzero if host is invalid in some way; don’t fail the whole script.
  ssh -F "$SSH_CONFIG" -G "$host" 2>/dev/null | awk '
    $1 ~ /^(user|hostname|identityfile)$/ { print "  " $1 ": " $2 }
  ' || echo "  (Could not resolve config via: ssh -G $host)"

  # Test connection (non-interactive).
  # accept-new avoids prompts on first contact; BatchMode prevents password prompts.
  if ssh -F "$SSH_CONFIG" \
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

# Exit nonzero if any failed (useful for CI / scripting)
[[ "$fail" -eq 0 ]]
```

### Quick usage

* Default (uses `remote-hosts.txt` and `~/.ssh/config`):

  ```bash
  ./remote-batch-ssh-test.sh
  ```
* Custom timeout (e.g., 2 seconds):

  ```bash
  ./remote-batch-ssh-test.sh remote-hosts.txt ~/.ssh/config 2
  ```

If you paste 2–3 example lines from your `remote-hosts.txt`, I can sanity-check that the values will actually match your config patterns (aliases vs IPs) and tweak the script accordingly.

---

Ahhh yep — classic gotcha: **`ssh` is stealing your while-loop’s stdin**.

Because your loop is doing `done < remote-hosts.txt`, *stdin for the whole loop is the file*. Then your first `ssh ... "$host" 'echo ...'` reads from stdin (even if it doesn’t “need” to), and it can consume the rest of the file. Result: you only get the first host.

## Fix

Tell `ssh` **not to read stdin** by adding **one** of these:

* `ssh -n ...`  ✅ simplest
* or `ssh ... </dev/null`
* or `-o StdinNull=yes`

I’ll give you an updated script using `-n`.

---

## Also: your hosts file last line needs a newline

This bit:

```
WAITS-STACKflynntknapp@DELL-DESK:~/Programming/server-scripts$
```

means `remote-hosts.txt` likely **doesn’t end with a newline**, so your prompt got printed on the same line when you ran `cat`.

Quick fix:

```bash
printf '\n' >> remote-hosts.txt
```

(And optionally open it and delete anything accidentally appended after `WAITS-STACK`.)

---

## Updated script (fixed stdin issue)

Save over your existing `remote-batch-ssh-test.sh`:

```bash
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
```

Run:

```bash
./remote-batch-ssh-test.sh
```

If you still see only one host after this, paste the output of:

```bash
tail -n 3 -A remote-hosts.txt
```

That will reveal any hidden characters (CRLF, weird prompt text, etc.) without guessing.
