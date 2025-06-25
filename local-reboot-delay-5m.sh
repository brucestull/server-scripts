#!/usr/bin/env bash
#
# Script: local-reboot-delay-5m.sh
# Description:
#   Shutdown and immediately reboot the local machine.
#
# Usage:
#   sudo ./local-reboot-delay-5m.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Reboot ——  
sudo shutdown -r +5
