#!/usr/bin/env bash
#
# Script: shutdown-this-machine.sh
# Description:
#   Immediately shut down the local machine.
#
# Usage:
#   sudo ./shutdown-this-machine.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Shutdown ——  
sudo shutdown now
