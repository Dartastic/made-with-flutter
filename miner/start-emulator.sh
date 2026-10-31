#!/usr/bin/env bash
# Boots the mwf-miner emulator (Android 15, Google Play, arm64) and waits
# until it is ready. First time only: sign in to the Play Store with the
# miner's own Google account in the emulator window.
#
# Mine against it with:  dart run bin/miner.dart mine --serial emulator-5554
set -euo pipefail
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
SERIAL=emulator-5554

if ! "$ADB" devices | grep -q "^$SERIAL"; then
  "$SDK/emulator/emulator" -avd mwf-miner -port 5554 -no-boot-anim \
    -no-audio >/dev/null 2>&1 &
fi
"$ADB" -s "$SERIAL" wait-for-device
until [ "$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do
  sleep 2
done
# Keep the screen on so the miner can tap the Play Store.
"$ADB" -s "$SERIAL" shell svc power stayon true
"$ADB" -s "$SERIAL" shell settings put system screen_off_timeout 2147483647
echo "mwf-miner ready on $SERIAL"
