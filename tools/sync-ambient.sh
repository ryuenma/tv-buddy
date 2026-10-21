#!/bin/sh
# Mirror Google TV's ambient artwork into the launcher's wallpaper collection.
#
#   sh tools/sync-ambient.sh 192.168.31.35
#   ADB=/path/to/adb sh tools/sync-ambient.sh 192.168.31.35 --now
#
# The ambient screensaver (dreamx) downloads its pictures into its own external data directory and
# rotates that set on Google's own schedule. Another app cannot read that directory — the launcher was
# measured at canRead=false with a null listing even holding MANAGE_EXTERNAL_STORAGE — but adb shell can,
# because it runs in the sdcard_rw group. So the copy has to happen here, on the host, and the launcher
# simply watches its own collection for the result.
#
# The copy itself runs on the TV (`shell sh -s`), so no picture crosses the network. Running it twice in a
# row costs one directory listing and nothing else.
#
# --now  restart Home afterwards so the change is visible immediately, instead of on the next rotation.
set -e
[ -n "$1" ] || { echo "Usage: sh tools/sync-ambient.sh <TV_IP> [--now]" >&2; exit 1; }

ADB=${ADB:-adb}
TV=$1
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
NOW=no
[ "$2" = "--now" ] && NOW=yes

"$ADB" connect "$TV" >/dev/null 2>&1 || true
[ "$("$ADB" -s "$TV" get-state 2>/dev/null)" = device ] || { echo "Can't reach $TV." >&2; exit 1; }

"$ADB" -s "$TV" shell sh -s <<'ON_DEVICE'
CACHE=/sdcard/Android/data/com.google.android.apps.tv.dreamx/files/Pictures/cache
DEST=/sdcard/Android/data/com.gathin.tvhome/files/wallpapers
PRESENT=/data/local/tmp/ambient-present

mkdir -p "$DEST" 2>/dev/null
if [ ! -d "$CACHE" ]; then
  echo "no ambient cache on this set (has the screensaver run yet?)"
  exit 0
fi

: > "$PRESENT"
added=0
same=0
for f in "$CACHE"/*.0; do
  [ -f "$f" ] || continue
  # DiskLruCache may hold things that are not pictures; only take real WEBP.
  [ "$(head -c 12 "$f" 2>/dev/null | tail -c 4)" = "WEBP" ] || continue
  key=$(basename "$f" .0)
  echo "$key" >> "$PRESENT"
  dst="$DEST/ambient-$key.webp"
  if [ -f "$dst" ] && [ "$(wc -c < "$dst")" = "$(wc -c < "$f")" ]; then
    same=$((same + 1))
    continue
  fi
  if cp "$f" "$dst" 2>/dev/null; then added=$((added + 1)); fi
done

# Follow the screensaver's evictions: a picture Google has dropped should stop appearing on Home.
removed=0
for d in "$DEST"/ambient-*.webp; do
  [ -f "$d" ] || continue
  key=$(basename "$d" .webp)
  key=${key#ambient-}
  if ! grep -qx "$key" "$PRESENT" 2>/dev/null; then
    rm -f "$d" && removed=$((removed + 1))
  fi
done
rm -f "$PRESENT"

total=$(ls "$DEST"/ambient-*.webp 2>/dev/null | wc -l)
echo "ambient artwork: $added added, $removed retired, $same unchanged, $total mirrored"
ON_DEVICE

if [ "$NOW" = yes ]; then
  "$ADB" -s "$TV" shell am force-stop com.gathin.tvhome >/dev/null 2>&1 || true
  "$ADB" -s "$TV" shell am start -n com.gathin.tvhome/.MainActivity >/dev/null 2>&1 || true
  echo "Home restarted."
else
  echo "Home picks these up on its next rotation (add --now to restart it here)."
fi
