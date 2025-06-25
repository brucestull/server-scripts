#!/usr/bin/env bash
# Script to rename Bash files to recommended naming scheme

cd ./server-scripts || exit 1

mv "shutdown-this-machine.sh" "local-shutdown-now.sh"
mv "shutdown-this-machine-one-minute.sh" "local-shutdown-delay-1m.sh"
mv "reboot-this-machine.sh" "local-reboot-delay-5m.sh"
mv "shutdown-cancel.sh" "local-cancel-shutdown.sh"
mv "update-system-packages.sh" "local-update-packages.sh"
mv "batch-update-remote-servers.sh" "remote-batch-update.sh"
mv "batch-reboot-remote-servers.sh" "remote-batch-reboot.sh"
mv "batch-cancel-shutdowns.sh" "remote-batch-cancel-shutdown.sh"
mv "batch-shutdown-remote-servers.sh" "remote-batch-shutdown-delay-1m.sh"
mv "batch-rsync-remote-scripts.sh" "remote-batch-sync-scripts.sh"
