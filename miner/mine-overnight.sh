#!/usr/bin/env bash
# Overnight mining run on a USB-connected phone. Unlock the phone, plug it in,
# then:  ./mine-overnight.sh [serial]   (default: the only phone connected)
#
# Keeps the screen on while plugged in for the run, mines every remaining app
# in out/ranked.json, restores the screen settings, and prints the Flutter
# table. The miner stops by itself if the phone gets unhealthy (5 failed
# installs in a row, signed out, unplugged); rerun to resume.
set -uo pipefail
cd "$(dirname "$0")"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

SERIAL="${1:-$("$ADB" devices | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {print $1}' | head -1)}"
if [ -z "$SERIAL" ]; then echo "no phone connected" >&2; exit 1; fi
a() { "$ADB" -s "$SERIAL" "$@"; }

old_timeout=$(a shell settings get system screen_off_timeout | tr -d '\r')
restore() {
  a shell svc power stayon false >/dev/null 2>&1
  a shell settings put system screen_off_timeout "$old_timeout" >/dev/null 2>&1
}
trap restore EXIT

a shell svc power stayon usb
a shell settings put system screen_off_timeout 2147483647
a shell input keyevent KEYCODE_WAKEUP

log="out/overnight-$(date +%Y%m%d-%H%M).log"
echo "mining on $SERIAL; log: $log"
dart run bin/miner.dart mine --serial "$SERIAL" 2>&1 | tee "$log"

echo
./print-flutter-table.sh
