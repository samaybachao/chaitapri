#!/usr/bin/env bash
# Runs inside the Android emulator (started by emulator-test.yml): installs an APK,
# starts the game, takes screenshots and saves logcat so a startup crash can be diagnosed.
#   usage: emulator_check.sh <apk> <prefix>      files go to emulator-out/<prefix>_*
set +e
APK="$1"
P="$2"
PKG=com.chaitapri.app
OUT=emulator-out
mkdir -p "$OUT"
adb uninstall "$PKG" > /dev/null 2>&1

{ adb devices -l; adb shell getprop ro.build.version.release; adb shell getprop ro.product.cpu.abi; } > "$OUT/${P}_device.txt" 2>&1
adb install -r "$APK" > "$OUT/${P}_install.txt" 2>&1
cat "$OUT/${P}_install.txt"

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > "$OUT/${P}_launch.txt" 2>&1
sleep 20
adb exec-out screencap -p > "$OUT/${P}_screen1.png"
echo "pid after 20 s: $(adb shell pidof $PKG)" | tee "$OUT/${P}_pids.txt"

# A few taps on the stall, then another look.
for i in 1 2 3 4 5 6; do adb shell input tap 540 760; sleep 0.4; done
sleep 3
adb exec-out screencap -p > "$OUT/${P}_screen2.png"
echo "pid after taps: $(adb shell pidof $PKG)" | tee -a "$OUT/${P}_pids.txt"

# Open Settings (gear, top right) and look at it.
adb shell input tap 1000 150
sleep 3
adb exec-out screencap -p > "$OUT/${P}_screen3.png"
echo "pid after settings: $(adb shell pidof $PKG)" | tee -a "$OUT/${P}_pids.txt"

adb logcat -d > "$OUT/${P}_logcat_full.txt" 2>&1
adb logcat -d -b crash > "$OUT/${P}_logcat_crash.txt" 2>&1
grep -E "FATAL EXCEPTION|AndroidRuntime|flutter|DartVM|Exception|Error" "$OUT/${P}_logcat_full.txt" | head -150 > "$OUT/${P}_logcat_key.txt"
exit 0
