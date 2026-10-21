#!/bin/sh
# Push theme/ (config.json + wallpapers) to the launcher's theme directory on the TV,
# then restart the launcher so it re-reads it.
#
#   sh tools/push-theme.sh 192.168.31.35
#   ADB=/path/to/adb sh tools/push-theme.sh 192.168.31.35
#
# The whole `shell` command is one quoted argument, so Git Bash on Windows does not
# rewrite the device path into a Windows one.
set -e
[ -n "$1" ] || { echo "Usage: sh tools/push-theme.sh <TV_IP>" >&2; exit 1; }

ADB=${ADB:-adb}
TV=$1
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
DIR=/sdcard/Android/data/com.gathin.tvhome/files
PKG=com.gathin.tvhome

cd "$(dirname "$0")/.."

"$ADB" connect "$TV" >/dev/null 2>&1 || true
[ "$("$ADB" -s "$TV" get-state 2>/dev/null)" = device ] || { echo "Can't reach $TV." >&2; exit 1; }

"$ADB" -s "$TV" shell "mkdir -p $DIR/wallpapers"
"$ADB" -s "$TV" push theme/config.json "$DIR/config.json" >/dev/null
for f in theme/wallpapers/*.jpg; do
  "$ADB" -s "$TV" push "$f" "$DIR/wallpapers/" >/dev/null
  echo "pushed $(basename "$f")"
done

"$ADB" -s "$TV" shell "am force-stop $PKG"
"$ADB" -s "$TV" shell "am start -n $PKG/.MainActivity" >/dev/null
echo "theme pushed; launcher restarted"
