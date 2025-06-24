#!/usr/bin/env bash
#
# Script: reboot-this-machine.sh
# Description:
#   Shutdown and immediately reboot the local machine.
#
# Usage:
#   sudo ./reboot-this-machine.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Reboot ——  
sudo shutdown -r +1
