#!/usr/bin/env bash
#
# Script: local-update-packages.sh
# Description:
#   Update APT package lists and upgrade all installed packages on the local system.
#
# Usage:
#   ./local-update-packages.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Update & Upgrade ——  
sudo apt-get update && sudo apt-get upgrade -y
