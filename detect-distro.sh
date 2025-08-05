#!/usr/bin/env bash

# Load the os-release variables
. /etc/os-release

case "$ID" in
  ubuntu)
    echo "Detected: Ubuntu ($VERSION_ID – $VERSION_CODENAME)"
    ;;
  raspbian|pi|raspberrypi)
    # Some Pi OS variants use ID_LIKE or different IDs
    echo "Detected: Raspberry Pi OS ($VERSION_ID – $VERSION_CODENAME)"
    ;;
  debian)
    echo "Detected: Debian ($VERSION_ID – $VERSION_CODENAME)"
    ;;
  *)
    echo "Detected: Other Debian-based distro ($NAME)"
    ;;
esac
