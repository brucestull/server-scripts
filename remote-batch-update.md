# 🌐 Script: remote-batch-update.sh

## 🧠 What it Does
SSH into each host listed in `remote-hosts.txt` and run `local-update-packages.sh` remotely, logging success or failure.

---

## 🛠️ Configuration Variables

```bash
USERNAME_FILE="./username.txt"
```
- Assigns filename for SSH username.
- `"./username.txt"`: Path in current directory.
- Quotes prevent word-splitting/expansion issues.

📌 *Defines where to read the SSH username.*

---

```bash
HOSTFILE="./remote-hosts.txt"
```
- Path to file listing host base names, one per line.

📌 *Lists remote target hosts.*

---

```bash
HOSTDOMAIN=".lan"
```
- Domain suffix appended to each hostname.

📌 *Sets DNS domain suffix.*

---

```bash
KEY_FILE="${HOME}/.ssh/id_ed25519_remote_runner"
```
- SSH private key path, using `$HOME` environment variable.

📌 *Specifies SSH key for authentication.*

---

```bash
REMOTE_CMD="sudo ~/server-scripts/local-update-packages.sh"
```
- Command to run on remote: uses `sudo` for privileges.

📌 *Defines the remote update script invocation.*

---

```bash
LOGFILE="./update-results.log"
```
- File to record timestamped success/failure entries.

📌 *Sets log output location.*

---

## 🔧 Prep Checks

```bash
[[ -f "$USERNAME_FILE" ]] || { echo "❌ Missing $USERNAME_FILE"; exit 1; }
```
- `[[ -f ... ]]`: Test if file exists and is regular.
- `||`: OR operator; runs RHS if LHS fails.
- `{ ...; }`: Grouped commands.
- `exit 1`: Exit script with failure status.

📌 *Ensures username file exists or aborts.*

---

```bash
read -r USERNAME < "$USERNAME_FILE"
```
- `read`: Read a line of input.
- `-r`: Raw mode; backslashes not treated specially.
- `< "$USERNAME_FILE"`: Redirect file contents as input.

📌 *Loads SSH username into variable.*

---

```bash
> "$LOGFILE"
```
- `>`: Redirect operator to truncate or create file.

📌 *Clears or creates the log file.*

---

```bash
SUCCESS=()
FAIL=()
```
- Declares empty arrays for recording host results.

📌 *Initialize result arrays.*

---

## 🔁 Loop Through Hosts

```bash
while IFS= read -r SERVER; do
```
- `IFS=`: Prevent trimming of whitespace.
- `read -r SERVER`: Read each line into `SERVER`.

📌 *Iterate through each host entry.*

---

```bash
  [[ -z "$SERVER" ]] && continue
```
- `-z`: True if string is empty.
- `continue`: Skip to next loop iteration.

📌 *Skip blank lines.*

---

```bash
  FQDN="${SERVER}${HOSTDOMAIN}"
```
- String concatenation; no spaces around `=`.

📌 *Build fully qualified domain name.*

---

```bash
  if ssh -i "$KEY_FILE" -o BatchMode=yes -o ConnectTimeout=5 -t "$USERNAME@$FQDN" < /dev/null "$REMOTE_CMD"; then
```
- `ssh`: Secure shell command.
- `-i`: Specify identity file.
- `-o BatchMode=yes`: Disable password prompt.
- `-o ConnectTimeout=5`: Timeout after 5 seconds.
- `-t`: Allocate TTY, allowing remote sudo to prompt.
- `< /dev/null`: Redirect local stdin to avoid hanging.
- `"$REMOTE_CMD"`: Execute remote command.

📌 *Attempts remote update on target host.*

---

```bash
    echo "$(date +'%F %T')  [OK]   Updated $FQDN" >> "$LOGFILE"
    SUCCESS+=("$FQDN")
```
- `date +'%F %T'`: Formats current date/time as YYYY-MM-DD HH:MM:SS.
- `>>`: Append to file.
- `SUCCESS+=`: Add host to success array.

📌 *Log success and record host.*

---

```bash
  else
    echo "$(date +'%F %T')  [FAIL] Update failed on $FQDN" >> "$LOGFILE"
    FAIL+=("$FQDN")
```
- Logs failure similarly and adds to fail array.

📌 *Log failure and record host.*

---

```bash
done < "$HOSTFILE"
```
- Redirect host list file as input to loop.

📌 *Ends loop.*

---

## 📊 Summary Output

```bash
echo "✅ Succeeded (${#SUCCESS[@]}):"
```
- `${#SUCCESS[@]}`: Number of elements in array.

📌 *Print count of successful hosts.*

... (similar for failures)

---

## ✅ Script Summary
Connects to all remote servers via SSH and runs the update script, providing a consolidated summary and log.