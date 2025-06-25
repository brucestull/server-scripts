#!/usr/bin/env bash
#
# Script: local-shutdown-now.sh
# Description:
#   Immediately shut down the local machine.
#
# Usage:
#   sudo ./local-shutdown-now.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Shutdown ——  
sudo shutdown now
