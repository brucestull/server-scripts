# ✋ Script: local-cancel-shutdown.sh

## 🧠 What it Does
Cancels any pending shutdown or reboot orders on the local machine.

---

## 🧩 Line-by-Line Breakdown

```bash
#!/usr/bin/env bash
```
- `#!`: Indicates interpreter directive.
- `/usr/bin/env bash`: Dynamically locate Bash.

📌 *Runs this script using Bash.*

---

```bash
set -euo pipefail
```
- `-e`, `-u`, `-o pipefail`: Fail-fast, safe script behavior.

📌 *Enforces strict error checking.*

---

```bash
sudo shutdown -c
```
- `sudo`: Run as superuser.
- `shutdown`: Shutdown utility.
- `-c`: Cancel any scheduled shutdown or reboot.

📌 *Removes any scheduled shutdown/reboot.*

---

## ✅ Script Summary
Use this to abort scheduled system shutdowns or reboots.