#!/usr/bin/env bash
# Runs inside the emulator: install the debug APK, launch it, wait, and
# collect the startup log so a hang can be diagnosed without a phone.
APK=app/build/app/outputs/flutter-apk/app-debug.apk
PKG=com.zdmgold.katharerase
adb wait-for-device
INSTALL=$(adb install -r "$APK" 2>&1 | tail -3)
PKGLIST=$(adb shell pm list packages | grep -i katharerase)
RESOLVE=$(adb shell cmd package resolve-activity --brief "$PKG" 2>&1 | tail -3)
adb logcat -c
START=$(adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 2>&1 | tail -3)
sleep 80
adb logcat -d > /tmp/full.txt
{
  echo "--- install: $INSTALL"
  echo "--- package present: $PKGLIST"
  echo "--- launcher activity: $RESOLVE"
  echo "--- start: $START"
  echo "--- pid after 80s: $(adb shell pidof $PKG)"
  adb shell dumpsys activity activities | grep -E "topResumedActivity" | head -1
  echo "--- app lines (BOOT / flutter / crash / our package):"
  grep -E "BOOT|I flutter|E flutter|F flutter|FATAL|AndroidRuntime|Fatal signal|ANR in|Unhandled|katharerase|Process .* has died" /tmp/full.txt | grep -v "PeoplePU\|CorpusConfig\|AppOps\|ModernMediaScanner" | tail -n 90
} > /tmp/filtered.txt
cat /tmp/filtered.txt
msg=$(head -c 30000 /tmp/filtered.txt | python3 -c "import sys; t=sys.stdin.read(); print(t.replace('%','%25').replace('\r','%0D').replace('\n','%0A'),end='')")
echo "::notice title=EMULATOR STARTUP LOG::$msg"
exit 0
