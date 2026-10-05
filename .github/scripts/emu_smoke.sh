#!/usr/bin/env bash
# Runs inside the emulator: install the debug APK, launch it, wait, and
# collect the startup log so a hang can be diagnosed without a phone.
APK=app/build/app/outputs/flutter-apk/app-debug.apk
PKG=com.zdmgold.katharerase
adb wait-for-device
adb install -r "$APK" 2>&1 | tail -2
adb logcat -c
adb shell am start -n "$PKG/.MainActivity" 2>&1 | tail -2
sleep 75
adb logcat -d > /tmp/full.txt
{
  echo "--- pid: $(adb shell pidof $PKG)"
  adb shell dumpsys activity activities | grep -E "topResumedActivity|mResumedActivity" | head -2
  echo "--- BOOT / flutter / crash lines:"
  grep -E "BOOT|I flutter|E flutter|F flutter|FATAL|AndroidRuntime|ANR in|Unhandled|Exception" /tmp/full.txt | tail -n 120
} > /tmp/filtered.txt
cat /tmp/filtered.txt
msg=$(head -c 30000 /tmp/filtered.txt | python3 -c "import sys; t=sys.stdin.read(); print(t.replace('%','%25').replace('\r','%0D').replace('\n','%0A'),end='')")
echo "::notice title=EMULATOR STARTUP LOG::$msg"
exit 0
