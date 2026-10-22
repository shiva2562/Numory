#!/bin/sh
# Exports store/marketing/posters.html as the 4 Google Play phone screenshots
# (1080 x 1920 JPEG) into store/marketing/android/. Captures first:
#   flutter test --dart-define=GENERATE_STORE_SCREENSHOTS=true test/store_screenshots_test.dart
set -e
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT=store/marketing/android
mkdir -p "$OUT"
for n in 1 2 3 4; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=1 --window-size=1080,1920 --virtual-time-budget=4000 \
    --screenshot="$OUT/0$n.png" "file://$PWD/store/marketing/posters.html?slide=$n" >/dev/null 2>&1
  sips -s format jpeg -s formatOptions 92 "$OUT/0$n.png" --out "$OUT/0$n.jpg" >/dev/null
  rm "$OUT/0$n.png"
done
ls -la "$OUT"
