#!/usr/bin/env bash
#
# Script: shutdown-this-machine-one-minute.sh
# Description:
#   Shut down the local machine in one minute.
#
# Usage:
#   sudo ./shutdown-this-machine-one-minute.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Shutdown in 1 minute ——  
sudo shutdown -h +1
