#!/usr/bin/env bash
# Collects everything needed to diagnose a crash of Ljod on a physical device.
#
#   ./scripts/collect-android-crash.sh            # writes android-crash-<time>.txt
#   ./scripts/collect-android-crash.sh --clear    # clears logcat first, then you reproduce
#
# Requires the phone connected over USB with debugging authorised. Nothing is
# uploaded; the report stays in this directory.

set -euo pipefail

APP_ID="dev.vz.ljod"
OUT="android-crash-$(date +%Y%m%d-%H%M%S).txt"

command -v adb >/dev/null || { echo "adb not found on PATH" >&2; exit 1; }

if ! adb get-state >/dev/null 2>&1; then
  echo "No device: connect the phone, enable USB debugging and authorise this computer." >&2
  exit 1
fi

if [ "${1:-}" = "--clear" ]; then
  adb logcat -c
  echo "logcat cleared. Launch Ljod now, let it crash, then re-run without --clear."
  exit 0
fi

{
  echo "# Ljod device crash report"
  echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## device"
  adb shell getprop ro.product.model 2>/dev/null || true
  adb shell getprop ro.build.version.release 2>/dev/null || true
  adb shell getprop ro.build.version.sdk 2>/dev/null || true
  adb shell getprop ro.product.cpu.abi 2>/dev/null || true
  echo
  echo "## installed package"
  adb shell dumpsys package "$APP_ID" 2>/dev/null | grep -E 'versionName|versionCode|firstInstallTime|lastUpdateTime|signatures' || echo "not installed"
  echo
  echo "## crash buffer (AndroidRuntime / FATAL / ljod)"
  adb logcat -d -b crash -v threadtime 2>/dev/null | tail -n 200 || true
  echo
  echo "## main log filtered"
  adb logcat -d -v threadtime 2>/dev/null \
    | grep -iE "ljod|flutter|AndroidRuntime|FATAL|ActivityManager.*$APP_ID|audio_service|just_audio|sqflite" \
    | tail -n 600 || true
  echo
  echo "## app-private logs (debug builds only)"
  for f in diagnostics.log ljod-crash.log; do
    echo "--- $f ---"
    adb shell run-as "$APP_ID" cat "files/$f" 2>/dev/null \
      || adb shell run-as "$APP_ID" cat "app_flutter/$f" 2>/dev/null \
      || adb shell run-as "$APP_ID" cat "$f" 2>/dev/null \
      || echo "(not readable: release build, or file absent)"
  done
} > "$OUT" 2>&1

echo "wrote $OUT ($(wc -l < "$OUT") lines)"
echo "review it, then paste the 'crash buffer' and 'main log filtered' sections."
