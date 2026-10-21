#!/bin/sh
# Extract Google TV's ambient artwork from the dreamx package already installed on the TV
# and drop it into theme/wallpapers/, ready for tools/push-theme.sh.
#
#   sh tools/pull-ambient-art.sh 192.168.31.35
#   ADB=/path/to/adb sh tools/pull-ambient-art.sh 192.168.31.35
#
# The artwork is Google's, shipped on the set to drive its own screensaver. It is pulled
# from the device that already owns it and is deliberately NOT committed to this repo.
set -e
[ -n "$1" ] || { echo "Usage: sh tools/pull-ambient-art.sh <TV_IP>" >&2; exit 1; }

ADB=${ADB:-adb}
TV=$1
case "$TV" in *:*) ;; *) TV="$TV:5555" ;; esac
DREAMX=com.google.android.apps.tv.dreamx

cd "$(dirname "$0")/.."

"$ADB" connect "$TV" >/dev/null 2>&1 || true
[ "$("$ADB" -s "$TV" get-state 2>/dev/null)" = device ] || { echo "Can't reach $TV." >&2; exit 1; }

APK=$("$ADB" -s "$TV" shell "pm path $DREAMX" 2>/dev/null | tr -d '\r' | sed -n 's/^package://p' | head -1)
[ -n "$APK" ] || { echo "$DREAMX is not installed on $TV." >&2; exit 1; }

TMP=.debloat/dreamx.apk
mkdir -p .debloat theme/wallpapers
"$ADB" -s "$TV" pull "$APK" "$TMP" >/dev/null
echo "pulled $DREAMX"

python - "$TMP" <<'PY'
import pathlib, sys, zipfile
apk = sys.argv[1]
out = pathlib.Path("theme/wallpapers")
z = zipfile.ZipFile(apk)
names = sorted(n for n in z.namelist()
               if n.startswith("assets/background") and n.endswith("_1080p.webp"))
for old in out.glob("background*.webp"):
    old.unlink()
for n in names:
    (out / pathlib.Path(n).name).write_bytes(z.read(n))
print(f"extracted {len(names)} ambient images into {out}")
PY

rm -f "$TMP"
echo "done. Next: sh tools/push-theme.sh $1"
