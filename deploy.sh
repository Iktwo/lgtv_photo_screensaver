#!/bin/sh
# Copies the photo screen saver to the TV and runs a step there.
#
#   ./deploy.sh [TV_ADDRESS] [install|enable]     (default: 192.168.1.121 install)
#
# "install" mounts it until the next reboot, to try it out; "enable" also
# mounts it at every boot. Built-in photos are the .jpg files in photos/.
set -e
TV=${1:-192.168.1.121}
STEP=${2:-install}
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=/var/lib/photoscreensaver

mkdir -p "$HERE/photos"
# Copied fresh each time. COPYFILE_DISABLE and --no-xattrs keep macOS "._"
# files and extended attributes out of the archive.
( cd "$HERE" && COPYFILE_DISABLE=1 tar --no-xattrs -cf - qml photos photo-screensaver.sh ) |
  ssh "root@$TV" "mkdir -p $BASE/stage && cd $BASE && rm -rf stage/qml stage/photos &&
    tar -xf - && mv qml stage/qml && mv photos stage/photos &&
    chmod 755 photo-screensaver.sh && sh photo-screensaver.sh $STEP && sh photo-screensaver.sh status"
