# 🚫 Script: local-shutdown-now.sh

## 🧠 What it Does
Immediately shuts down the local machine using `shutdown now`.

---

## 🧩 Line-by-Line Breakdown

```bash
#!/usr/bin/env bash
```
- `#!` (shebang): Instructs the OS to run the script with the specified interpreter.
- `/usr/bin/env bash`: Uses the `env` command to locate `bash` in `$PATH` for portability.

📌 *Tells the system to execute this script with Bash.*

---

```bash
set -euo pipefail
```
- `-e`: Exit immediately if any command exits with a non-zero status.
- `-u`: Treat unset variables as an error and exit immediately.
- `-o pipefail`: Causes pipelines to return the exit status of the last command in the pipe that failed.

📌 *Makes the script fail-fast and safer on errors.*

---

```bash
sudo shutdown now
```
- `sudo`: Run command with superuser privileges.
- `shutdown`: Utility to halt, power-off, or reboot the machine.
- `now`: Execute the shutdown immediately.

📌 *Immediately powers off the local machine.*

---

## ✅ Script Summary
This script instantly powers off the machine. It uses `sudo` and is intended for safe local shutdowns on Raspberry Pi OS or Ubuntu.