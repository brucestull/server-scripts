# 🕐 Script: local-shutdown-delay-1m.sh

## 🧠 What it Does
Schedules a shutdown of the local machine to occur one minute from now.

---

## 🧩 Line-by-Line Breakdown

```bash
#!/usr/bin/env bash
```
- `#!` (shebang): Specifies script interpreter.
- `/usr/bin/env bash`: Finds Bash via `env`.

📌 *Runs this script under Bash.*

---

```bash
set -euo pipefail
```
- `-e`: Exit on any command failure.
- `-u`: Error on unset variables.
- `-o pipefail`: Fail pipelines on any failed command.

📌 *Makes the script robust and fail-fast.*

---

```bash
sudo shutdown -h +1
```
- `sudo`: Run with elevated privileges.
- `shutdown`: Halts or reboots the system.
- `-h`: Halt (power off) after shutdown.
- `+1`: Delay the shutdown by 1 minute.

📌 *Schedules a power-off in one minute.*

---

## ✅ Script Summary
This script allows processes to complete before shutting down by delaying the shutdown by one minute.