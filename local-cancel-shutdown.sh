#!/usr/bin/env bash
#
# Script: local-cancel-shutdown.sh
# Description:
#   Cancel previous shutdown order of this local machine.
#
# Usage:
#   sudo ./local-cancel-shutdown.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Cancel shutdown ——  
sudo shutdown -c
