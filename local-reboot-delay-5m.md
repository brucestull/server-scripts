# 🔄 Script: local-reboot-delay-5m.sh

## 🧠 What it Does
Schedules a reboot of the local machine to occur five minutes from now.

---

## 🧩 Line-by-Line Breakdown

```bash
#!/usr/bin/env bash
```
- `#!`: Shebang for interpreter selection.
- `/usr/bin/env bash`: Portable Bash path resolution.

📌 *Executes script with Bash.*

---

```bash
set -euo pipefail
```
- `-e`, `-u`, `-o pipefail`: Ensures safety and fail-fast behavior.

📌 *Enables strict error handling.*

---

```bash
sudo shutdown -r +5
```
- `sudo`: Elevated privileges.
- `shutdown`: System halt/reboot command.
- `-r`: Reboot after shutdown.
- `+5`: Delay reboot by 5 minutes.

📌 *Schedules a reboot in five minutes.*

---

## ✅ Script Summary
Allows for graceful shutdown procedures to complete before automatically rebooting five minutes later.