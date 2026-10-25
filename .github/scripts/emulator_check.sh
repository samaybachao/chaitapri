#!/usr/bin/env bash
# Runs inside the Android emulator (started by emulator-test.yml): installs the APK, plays a
# short scripted session (language, taps, tabs, settings), takes screenshots and saves logcat.
#   usage: emulator_check.sh <apk> <prefix>      files go to emulator-out/<prefix>_*
set +e
APK="$1"
P="$2"
PKG=com.chaitapri.app
OUT=emulator-out
mkdir -p "$OUT"
adb uninstall "$PKG" > /dev/null 2>&1

shot() { adb exec-out screencap -p > "$OUT/${P}_$1.png"; }
alive() { echo "$1: pid=$(adb shell pidof $PKG)" | tee -a "$OUT/${P}_pids.txt"; }

# Taps the first on-screen element whose text / content description starts with $1.
tap_text() {
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1
  adb pull /sdcard/ui.xml "$OUT/${P}_ui_$2.xml" > /dev/null 2>&1
  python3 - "$1" "$OUT/${P}_ui_$2.xml" <<'PY'
import re, subprocess, sys
import xml.etree.ElementTree as ET
label, path = sys.argv[1], sys.argv[2]
try:
    tree = ET.parse(path)
except Exception as exc:
    print("no ui dump:", exc); sys.exit(0)
for node in tree.iter("node"):
    for attr in ("text", "content-desc"):
        value = node.get(attr) or ""
        if value == label or value.startswith(label):
            nums = re.findall(r"\d+", node.get("bounds") or "")
            if len(nums) == 4:
                x = (int(nums[0]) + int(nums[2])) // 2
                y = (int(nums[1]) + int(nums[3])) // 2
                subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)])
                print("tapped", repr(label), x, y); sys.exit(0)
print("NOT FOUND", repr(label))
PY
}

{ adb devices -l; adb shell getprop ro.build.version.release; adb shell getprop ro.product.cpu.abi; } > "$OUT/${P}_device.txt" 2>&1
adb install -r "$APK" > "$OUT/${P}_install.txt" 2>&1
cat "$OUT/${P}_install.txt"

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > "$OUT/${P}_launch.txt" 2>&1
sleep 20
shot 1_start; alive "after start"

tap_text "English" lang | tee -a "$OUT/${P}_steps.txt"; sleep 2
shot 2_after_language; alive "after language"

for i in 1 2 3 4 5 6 7 8 9 10 11 12; do adb shell input tap 540 750; sleep 0.3; done
sleep 2
shot 3_after_taps; alive "after taps"

tap_text "Menu" menu | tee -a "$OUT/${P}_steps.txt"; sleep 2
shot 4_menu_tab; alive "menu tab"

tap_text "Daily" daily | tee -a "$OUT/${P}_steps.txt"; sleep 2
shot 5_daily_tab; alive "daily tab"

tap_text "Collect" collect | tee -a "$OUT/${P}_steps.txt"; sleep 3
shot 6_after_collect; alive "after collect"
adb shell input keyevent 4; sleep 1

tap_text "Settings" settings | tee -a "$OUT/${P}_steps.txt"; sleep 3
shot 7_settings; alive "settings"
adb shell input keyevent 4; sleep 2
adb shell input keyevent 3; sleep 3            # Home: app goes to background
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1; sleep 6
shot 8_after_resume; alive "after background + resume"

adb logcat -d > "$OUT/${P}_logcat_full.txt" 2>&1
adb logcat -d -b crash > "$OUT/${P}_logcat_crash.txt" 2>&1
grep -E "FATAL EXCEPTION|AndroidRuntime|flutter|DartVM|Unhandled|Exception caught" "$OUT/${P}_logcat_full.txt" | grep -v "WifiSta\|netd\|Telephony" | head -150 > "$OUT/${P}_logcat_key.txt"
exit 0
