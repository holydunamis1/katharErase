#!/usr/bin/env bash
# Runs inside the emulator: install the debug APK, launch it, wait, and
# collect the app's own startup log so a hang/crash can be diagnosed
# without a phone. Output is split into <4 KB annotations.
APK=app/build/app/outputs/flutter-apk/app-debug.apk
PKG=com.zdmgold.katharerase
adb wait-for-device
adb install -r "$APK" > /tmp/install.txt 2>&1
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 6
PID=$(adb shell pidof "$PKG" | tr -d '\r')
sleep 70
ALIVE=$(adb shell pidof "$PKG" | tr -d '\r')
adb logcat -d -v threadtime > /tmp/full.txt
{
  echo "install: $(tail -1 /tmp/install.txt) | first pid: $PID | pid after 76s: ${ALIVE:-NONE (process gone)}"
  adb shell dumpsys activity activities | grep -E "topResumedActivity" | head -1 | cut -c1-140
  echo "=== BOOT trace + flutter errors (all pids) ==="
  grep -E "BOOT|E flutter|F flutter|Unhandled|Exception|FATAL EXCEPTION|Fatal signal|ANR in $PKG|am_crash|am_proc_died" /tmp/full.txt | grep -v -E "AppOps|PeoplePU|Corpus|MediaScanner|Cronet" | cut -c7-260 | head -n 60
  echo "=== ad/notification related lines from the app process ==="
  grep -E "^[0-9-]+ [0-9:.]+ +[0-9]+ +[0-9]+ [A-Z] (Ads|gads|MobileAds|FlutterLocalNotif|FlutterLocalNotifications|GoogleMobileAds)" /tmp/full.txt | cut -c7-240 | head -n 20
  echo "=== activity lifecycle (our package) ==="
  grep -E "ActivityTaskManager|ActivityManager" /tmp/full.txt | grep -E "$PKG" | grep -E "START|Displayed|Killing|died|restart|relaunch|finish" | cut -c7-220 | head -n 14
} > /tmp/filtered.txt
cat /tmp/filtered.txt
python3 - <<'PY'
import re
t=open('/tmp/filtered.txt').read()
esc=lambda s:s.replace('%','%25').replace('\r','%0D').replace('\n','%0A')
chunks=[];cur=''
for line in t.split('\n'):
    if len(cur)+len(line)+1>3400: chunks.append(cur);cur=''
    cur+=line+'\n'
chunks.append(cur)
for i,c in enumerate(chunks[:9],1):
    print(f"::notice title=EMU LOG {i}/{len(chunks)}::{esc(c)}")
PY
exit 0
