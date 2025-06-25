# 🌐 Script: remote-batch-update.sh

## 🧠 What it Does
SSH into each host listed in `remote-hosts.txt`, run `local-update-packages.sh` remotely in a non-interactive environment, and log:
- A **summary** of success/failure per host  
- A **detailed** capture of every SSH session’s full stdout/stderr, with separators for each host

---

## 🛠️ Configuration Variables

```bash
USERNAME_FILE="./username.txt"
```

* Path to file containing your SSH username (one line, no extra whitespace).
* Script will abort if this file is missing.

---

```bash
HOSTFILE="./remote-hosts.txt"
```

* Path to file listing server base names (one per line).
* Blank lines are skipped.

---

```bash
HOSTDOMAIN=".lan"
```

* Domain suffix appended to each hostname to build its FQDN.

---

```bash
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"
```

* SSH private key for password-less, batch-mode SSH.

---

```bash
REMOTE_CMD="~/server-scripts/local-update-packages.sh"
```

* Path to the remote update script on each server (no `sudo` prefix here; `sudo` is handled in the invocation).

---

```bash
SUMMARY_LOGFILE="./update-summary.log"
```

* File where each host’s timestamped `[OK]` or `[FAIL]` line is appended.

---

```bash
DETAIL_LOGFILE="./update-detail.log"
```

* File capturing the full combined output (stdout+stderr) of each SSH session, prefaced by

  ```
  ===== HOSTNAME =====
  ```

---

## 🔧 Prep Checks

```bash
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
read -r USERNAME < "$USERNAME_FILE"
> "$SUMMARY_LOGFILE"
> "$DETAIL_LOGFILE"
```

* `[[ -f ... ]]`: ensures the username file exists.
* `read -r`: loads the username into `$USERNAME`.
* `> file`: truncates or creates the summary and detailed logs before each run.

---

## 🔢 Result Arrays

```bash
SUCCESS=()
FAIL=()
```

* Two Bash arrays to collect FQDNs of hosts that succeeded or failed.

---

## 🔁 Loop Through Hosts

```bash
while IFS= read -r SERVER; do
  [[ -z "$SERVER" ]] && continue
  FQDN="${SERVER}${HOSTDOMAIN}"
  echo "➡️  Updating $FQDN…"

  # Separator in the detailed log
  echo -e "\\n===== $FQDN =====\\n" | tee -a "$DETAIL_LOGFILE"

  # Non-interactive SSH invocation
  if ssh -n -i "$KEY_FILE" \
         -o BatchMode=yes \
         -o ConnectTimeout=5 \
         "$USERNAME@$FQDN" bash -lc \
         "export DEBIAN_FRONTEND=noninteractive \
          APT_LISTCHANGES_FRONTEND=none && \
          sudo --preserve-env=DEBIAN_FRONTEND,APT_LISTCHANGES_FRONTEND \
               $REMOTE_CMD" \
         2>&1 | tee -a "$DETAIL_LOGFILE"
  then
    echo "$(date +'%F %T')  [OK]   Updated $FQDN" | tee -a "$SUMMARY_LOGFILE"
    SUCCESS+=("$FQDN")
  else
    echo "$(date +'%F %T')  [FAIL] Update failed on $FQDN" | tee -a "$SUMMARY_LOGFILE"
    FAIL+=("$FQDN")
  fi
done < "$HOSTFILE"
```

* `IFS= read -r SERVER`: reads each line exactly.
* `-n`: prevents SSH from consuming the loop’s stdin.
* `BatchMode=yes`: disables password prompts.
* `ConnectTimeout=5`: fails fast if host is unreachable.
* `bash -lc`: runs a login shell so user’s shell init files are sourced.
* `export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none`: disables all package-install prompts.
* `sudo --preserve-env=…`: keeps those env vars when elevating.
* `2>&1 | tee -a`: captures both stdout and stderr into the detailed log.

---

## 📊 Summary Output

```bash
echo
echo "📊 Update Summary"
echo "================="
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
```

* Outputs a console summary of how many hosts succeeded or failed.
* Points you to the two log files for the full run details.

---

## ✅ Script Summary

This script automates running a local APT-upgrade helper on multiple servers, capturing both a concise success/failure summary and a complete, host-segmented log of every SSH session.
