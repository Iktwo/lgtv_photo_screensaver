#!/bin/sh
# Photo screen saver for rooted LG webOS TVs (written on a C1, webOS 6).
#
# Bind-mounts a folder holding a QML slideshow over LG's screen saver app,
# the way GlassHouse mounts its own screen savers, and keeps links usb0..usb3
# in that folder pointing at a photo folder on each USB drive.
#
#   photo-screensaver.sh install   stage and mount now (until the next reboot)
#   photo-screensaver.sh enable    install, and mount at every boot
#   photo-screensaver.sh disable   unmount and stop mounting at boot
#   photo-screensaver.sh status
#   photo-screensaver.sh           (no argument) what the boot hook runs
#
# On a USB drive, photos go in a folder named LGTV_4K or Screensaver at the
# top of the drive. Log: /tmp/photo-screensaver.log
BASE=/var/lib/photoscreensaver
STAGE=$BASE/stage
APP=/usr/palm/applications/com.webos.app.screensaver
HOOK=/var/lib/webosbrew/init.d/70-photo-screensaver
LOG=/tmp/photo-screensaver.log
USB_FOLDERS="LGTV_4K Screensaver screensaver"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
mounted() { grep -q " $APP " /proc/mounts; }
ours() { [ -f "$APP/.photo-screensaver" ]; }

# LG's manifest, unchanged: on webOS 6 it is already a QML app whose main is
# qml/main.qml, which the mount replaces with ours. LG's files must be visible,
# so this only runs while nothing is mounted over the app.
stage() {
  mkdir -p "$STAGE/qml" "$STAGE/photos"
  [ -f "$STAGE/qml/main.qml" ] || { echo "missing $STAGE/qml/main.qml"; return 1; }
  grep -q '"type": *"qml"' "$APP/appinfo.json" || { echo "LG's screen saver is not QML here; not supported"; return 1; }
  cp "$APP/appinfo.json" "$STAGE/appinfo.json" || return 1
  touch "$STAGE/.photo-screensaver"
}

mount_saver() {
  mounted && { ours && return 0; log "something else is mounted over the screen saver; leaving it"; return 1; }
  [ -f "$STAGE/appinfo.json" ] && [ -f "$STAGE/qml/main.qml" ] || { log "not staged"; return 1; }
  mount --bind "$STAGE" "$APP" && log "mounted"
}

unmount_saver() {
  ours || return 0
  umount "$APP" 2>/dev/null || umount -l "$APP"
  log "unmounted"
}

# A running screen saver app keeps the old files, so it is closed - but only
# while the TV is plainly Active. Closed while it is on screen, tvpowerd is
# never told it went away: it stays in "Screen Saver Ready", ignores every new
# screen saver and answers "power is busy" until a key press or a reboot.
# The app exits when dismissed, so leaving it be just means the new files
# load the next time it starts.
restart_app() {
  pgrep -f "qml-runner.*com.webos.app.screensaver" >/dev/null 2>&1 || return 0
  state=$(luna-send -n 1 -w 15000 luna://com.webos.service.tvpower/power/getPowerState '{}' 2>/dev/null)
  if echo "$state" | grep -q '"state": *"Active"' && ! echo "$state" | grep -q '"processing"'; then
    luna-send -n 1 -w 15000 luna://com.webos.applicationManager/closeByAppId \
      '{"id":"com.webos.app.screensaver"}' >/dev/null 2>&1
  else
    echo "screen saver is showing or the TV is busy: the new version loads the next time it starts"
  fi
}

# Points usb0..usb3 at the photo folders on the USB drives mounted now.
link_usb() {
  found=""
  for mp in $(awk '$2 ~ /\/usb\// {print $2}' /proc/mounts); do
    for name in $USB_FOLDERS; do
      [ -d "$mp/$name" ] && { found="$found $mp/$name"; break; }
    done
  done
  i=0
  for dir in $found; do
    [ $i -gt 3 ] && break
    [ "$(readlink "$STAGE/usb$i")" = "$dir" ] || { ln -sfn "$dir" "$STAGE/usb$i"; log "usb$i -> $dir"; }
    i=$((i + 1))
  done
  while [ $i -le 3 ]; do
    [ -L "$STAGE/usb$i" ] && { rm -f "$STAGE/usb$i"; log "usb$i removed"; }
    i=$((i + 1))
  done
}

# One watcher at a time: a newer start ends the older one.
watch_usb() {
  echo $$ > /tmp/photo-screensaver.watch
  while [ "$(cat /tmp/photo-screensaver.watch 2>/dev/null)" = "$$" ] && [ -f "$STAGE/appinfo.json" ]; do
    link_usb
    sleep 15
  done
}

start_watcher() {
  ( watch_usb ) </dev/null >/dev/null 2>&1 &
}

case "$1" in
  install)
    unmount_saver
    stage || exit 1
    mount_saver || exit 1
    link_usb
    start_watcher
    restart_app
    echo "installed and mounted (until reboot)"
    ;;
  enable)
    sh "$BASE/photo-screensaver.sh" install || exit 1
    ln -sf "$BASE/photo-screensaver.sh" "$HOOK"
    echo "enabled at boot: $HOOK"
    ;;
  disable)
    rm -f "$HOOK" /tmp/photo-screensaver.watch
    unmount_saver
    restart_app
    echo "disabled; LG's screen saver is back"
    ;;
  status)
    if ! mounted; then echo "screen saver: LG's (nothing mounted)"
    elif ours; then echo "screen saver: photo slideshow (mounted)"
    else echo "screen saver: something else is mounted over it"; fi
    [ -L "$HOOK" ] && echo "boot hook: enabled" || echo "boot hook: not enabled"
    echo "built-in photos: $(ls "$STAGE/photos" 2>/dev/null | grep -c -i '\.jpe\?g$')"
    for i in 0 1 2 3; do
      [ -L "$STAGE/usb$i" ] && echo "usb$i: $(readlink "$STAGE/usb$i") ($(ls "$STAGE/usb$i/" 2>/dev/null | grep -v '^\._' | grep -c -i '\.jpe\?g$') photos)"
    done
    ;;
  "")
    # Boot hook: quick, and everything long-running in the background.
    mount_saver
    start_watcher
    ;;
  *)
    echo "usage: $0 [install|enable|disable|status]"; exit 1
    ;;
esac
exit 0
