#!/usr/bin/env bash
#
# Script: local-shutdown-delay-1m.sh
# Description:
#   Shut down the local machine in one minute.
#
# Usage:
#   sudo ./local-shutdown-delay-1m.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Shutdown in 1 minute ——  
sudo shutdown -h +1
