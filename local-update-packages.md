# 📦 Script: local-update-packages.sh

## 🧠 What it Does
Updates local APT package lists and upgrades all installed packages.

---

## 🧩 Line-by-Line Breakdown

```bash
#!/usr/bin/env bash
```
- `#!`: Shebang for interpreter.
- `/usr/bin/env bash`: Find Bash via `env`.

📌 *Executes script with Bash.*

---

```bash
set -euo pipefail
```
- Enables exit-on-error, unset-variable checks, and pipeline failure detection.

📌 *Provides robust error handling.*

---

```bash
sudo apt-get update && sudo apt-get upgrade -y
```
- `sudo`: Superuser privileges.
- `apt-get update`: Refreshes package lists.
- `&&`: Logical AND operator; only run next command if previous succeeded.
- `apt-get upgrade`: Installs newest versions of packages.
- `-y`: Automatically answer "yes" to prompts.

📌 *Refreshes package database and installs upgrades without prompts.*

---

## ✅ Script Summary
Ensures your system’s packages are up to date in one command.