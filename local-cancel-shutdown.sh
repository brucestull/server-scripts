#!/usr/bin/env bash
#
# Script: shutdown-cancel.sh
# Description:
#   Cancel previous shutdown order of this local machine.
#
# Usage:
#   sudo ./shutdown-cancel.sh
#
# Configuration:
#   None
#

set -euo pipefail

# —— Cancel shutdown ——  
sudo shutdown -c
