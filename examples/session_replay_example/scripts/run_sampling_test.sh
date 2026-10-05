#!/bin/zsh
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.
#
# Launches session_replay_example many times on an iOS simulator or an Android
# emulator to check Session Replay sampling end to end, without touching the
# host mouse or keyboard.
#
# Each launch the app taps itself for ~12 seconds (lib/auto_interact.dart),
# then logs its RUM session ID, the replay decision the SDKs should make for it
# at the app's configured sample rates, and whether Session Replay captured.
# Every RUM event carries an `sr_test_run` attribute, so the run can be
# filtered in Datadog with `@sr_test_run:<run id>`.
#
# Usage:
#   scripts/run_sampling_test.sh [-p ios|android] [-n launches] [-r run-id] [-d device] [-b]
#
#   -p  platform: ios (default) or android
#   -n  number of launches (default 100)
#   -r  run ID for the sr_test_run attribute (default sr-<date>-<time>)
#   -d  iOS: simulator UDID (default: first booted iPhone, else first available)
#       Android: adb serial (default: first running device, else the first AVD)
#   -b  build and install the app first
#
# Results go to /tmp/sr_sampling/<run id>/ (reports, expected sessions, logs).
# A simulator or emulator that isn't running is started headless, so it
# doesn't take window focus. An emulator started by the script is shut down at
# the end.

set -u

PLATFORM=ios
LAUNCHES=100
RUN_ID="sr-$(date +%m%d-%H%M)"
DEV=""
BUILD=false
SECONDS_PER_LAUNCH=16   # typical launch; used for the time estimate
REPORT_TIMEOUT=60       # max seconds to wait for a launch's report

while getopts "p:n:r:d:b" opt; do
  case $opt in
    p) PLATFORM=$OPTARG ;;
    n) LAUNCHES=$OPTARG ;;
    r) RUN_ID=$OPTARG ;;
    d) DEV=$OPTARG ;;
    b) BUILD=true ;;
    *) sed -n '2,30p' "$0"; exit 1 ;;
  esac
done

APP_DIR=${0:A:h:h}
OUT=/tmp/sr_sampling/$RUN_ID
mkdir -p "$OUT"

# --- iOS (simctl) ---

IOS_BUNDLE=com.datadoghq.sessionReplayExample

ios_select_device() {
  if [[ -z $DEV ]]; then
    DEV=$(xcrun simctl list devices booted | grep -m1 -oE 'iPhone.*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')
  fi
  if [[ -z $DEV ]]; then
    DEV=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone.*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')
  fi
  [[ -n $DEV ]] || { echo "No iPhone simulator found." >&2; exit 1; }
  xcrun simctl boot "$DEV" 2>/dev/null
  xcrun simctl bootstatus "$DEV" -b >/dev/null 2>&1
}

ios_build_and_install() {
  (cd "$APP_DIR" && flutter build ios --simulator --debug >"$OUT/build.log" 2>&1) || return 1
  xcrun simctl install "$DEV" "$APP_DIR/build/ios/iphonesimulator/Runner.app"
}

ios_check_installed() {
  CONTAINER=$(xcrun simctl get_app_container "$DEV" "$IOS_BUNDLE" data 2>/dev/null)
}

ios_write_trigger() {
  mkdir -p "$CONTAINER/Documents"
  echo "$RUN_ID" >"$CONTAINER/Documents/sr_test_run"
}

ios_remove_trigger() {
  [[ -n ${CONTAINER:-} ]] && rm -f "$CONTAINER/Documents/sr_test_run"
}

ios_start_logs() {
  xcrun simctl spawn "$DEV" log stream --level debug --style compact \
    --predicate 'process == "Runner" AND (eventMessage CONTAINS "SR_TEST" OR eventMessage CONTAINS "Flutter Session Replay")' \
    >"$OUT/device.log" 2>&1 &
  LOGPID=$!
}

ios_launch() {
  xcrun simctl launch --terminate-running-process "$DEV" "$IOS_BUNDLE" | awk '{print $2}'
}

ios_stop() {
  xcrun simctl terminate "$DEV" "$IOS_BUNDLE"
}

ios_shutdown() { :; }

# --- Android (adb) ---

ANDROID_PACKAGE=com.datadoghq.session_replay_example
ANDROID_SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
ADB=$ANDROID_SDK/platform-tools/adb
EMULATOR=$ANDROID_SDK/emulator/emulator
STARTED_EMULATOR=false

adb_dev() { "$ADB" -s "$DEV" "$@"; }

android_select_device() {
  [[ -x $ADB ]] || { echo "adb not found in $ANDROID_SDK. Set ANDROID_HOME." >&2; exit 1; }
  if [[ -z $DEV ]]; then
    DEV=$("$ADB" devices | awk 'NR > 1 && $2 == "device" {print $1; exit}')
  fi
  if [[ -z $DEV ]]; then
    local avd
    avd=$("$EMULATOR" -list-avds 2>/dev/null | head -1)
    [[ -n $avd ]] || { echo "No Android device or AVD found." >&2; exit 1; }
    echo "Starting emulator $avd headless..."
    "$EMULATOR" -avd "$avd" -no-window -no-audio -no-boot-anim >"$OUT/emulator.log" 2>&1 &
    STARTED_EMULATOR=true
    "$ADB" wait-for-device
    DEV=$("$ADB" devices | awk 'NR > 1 && $2 == "device" {print $1; exit}')
  fi
  until [[ $(adb_dev shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; do
    sleep 2
  done
}

android_build_and_install() {
  (cd "$APP_DIR" && flutter build apk --debug >"$OUT/build.log" 2>&1) || return 1
  local apk=$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk
  # Replacing in place needs room for both copies; on an emulator low on
  # storage, uninstall the old copy and install fresh instead.
  adb_dev install -r "$apk" >>"$OUT/build.log" 2>&1 || {
    adb_dev uninstall "$ANDROID_PACKAGE" >>"$OUT/build.log" 2>&1
    adb_dev install "$apk" >>"$OUT/build.log" 2>&1
  }
}

android_check_installed() {
  adb_dev shell pm path "$ANDROID_PACKAGE" 2>/dev/null | grep -q package:
}

# run-as works because the app is a debug build. Its working directory is the
# app's data folder, the parent of the temp folder the app reads from.
android_write_trigger() {
  adb_dev shell run-as "$ANDROID_PACKAGE" sh -c \
    "'mkdir -p Documents && echo $RUN_ID > Documents/sr_test_run'"
}

android_remove_trigger() {
  adb_dev shell run-as "$ANDROID_PACKAGE" rm -f Documents/sr_test_run 2>/dev/null
}

android_start_logs() {
  adb_dev logcat -c
  adb_dev logcat -v brief -s flutter:I >"$OUT/device.log" 2>&1 &
  LOGPID=$!
}

android_launch() {
  # -W waits until the app has started, so its process ID exists.
  adb_dev shell am start -W -S -n "$ANDROID_PACKAGE/.MainActivity" >/dev/null
  adb_dev shell pidof "$ANDROID_PACKAGE" | tr -d '\r'
}

android_stop() {
  adb_dev shell am force-stop "$ANDROID_PACKAGE"
}

android_shutdown() {
  if $STARTED_EMULATOR; then
    echo "Shutting down the emulator started by this script..."
    adb_dev emu kill >/dev/null 2>&1
  fi
}

# --- Run ---

case $PLATFORM in
  ios | android) ;;
  *) echo "Unknown platform '$PLATFORM'. Use ios or android." >&2; exit 1 ;;
esac

${PLATFORM}_select_device

# Registered right away so a failed build or install still shuts down an
# emulator this script started.
cleanup() {
  [[ -n ${LOGPID:-} ]] && kill "$LOGPID" 2>/dev/null
  ${PLATFORM}_remove_trigger
  ${PLATFORM}_shutdown
}
trap cleanup EXIT INT TERM

echo "Platform: $PLATFORM"
echo "Device:   $DEV"
echo "Run ID:   $RUN_ID"
echo "Launches: $LAUNCHES (~$(( (LAUNCHES * (SECONDS_PER_LAUNCH + 2) + 90 + 59) / 60 )) min)"
echo "Output:   $OUT"

if $BUILD; then
  if [[ ! -f "$APP_DIR/.env" ]]; then
    echo "Missing $APP_DIR/.env. Generate it first with generate_env.sh at the repo root." >&2
    exit 1
  fi
  echo "Building and installing..."
  ${PLATFORM}_build_and_install || {
    echo "Build or install failed, see $OUT/build.log" >&2
    exit 1
  }
fi

${PLATFORM}_check_installed || {
  echo "The app is not installed on $DEV. Run again with -b." >&2
  exit 1
}

# The trigger file turns on the app's self-tapping test mode.
${PLATFORM}_write_trigger
${PLATFORM}_start_logs
sleep 2

: >"$OUT/launches.txt"
for i in $(seq 1 "$LAUNCHES"); do
  reports_before=$(grep -c 'SR_TEST session' "$OUT/device.log")
  pid=$(${PLATFORM}_launch)
  echo "$i $pid $(date +%H:%M:%S)" >>"$OUT/launches.txt"
  printf '\rLaunch %d/%d' "$i" "$LAUNCHES"
  # Wait for this launch's report rather than a fixed time: the first launch
  # after an install can be much slower than the rest.
  waited=0
  until (( $(grep -c 'SR_TEST session' "$OUT/device.log") > reports_before )) ||
    (( waited >= REPORT_TIMEOUT )); do
    sleep 1
    (( waited++ ))
  done
  (( waited >= REPORT_TIMEOUT )) && printf '\nLaunch %d did not report within %d s\n' "$i" "$REPORT_TIMEOUT"
  if (( i < LAUNCHES )); then
    ${PLATFORM}_stop
    sleep 2
  fi
done
echo

echo "Keeping the last launch open for 90 s so its data uploads..."
sleep 90
cleanup
trap - EXIT INT TERM

# Summary
grep -o 'SR_TEST session.*' "$OUT/device.log" | tr -d '\r' >"$OUT/reports.txt"
grep 'expectedReplay=true' "$OUT/reports.txt" |
  sed -E 's/SR_TEST session=([^ ]+).*/\1/' >"$OUT/expected_replay_sessions.txt"
grep 'expectedReplay=false' "$OUT/reports.txt" | grep -v 'session=null' |
  sed -E 's/SR_TEST session=([^ ]+).*/\1/' >"$OUT/rum_only_sessions.txt"
mismatches=$(awk '{split($3,e,"="); split($4,c,"="); if (e[2] != c[2]) n++} END {print n+0}' "$OUT/reports.txt")

echo
echo "Reports:                     $(wc -l <"$OUT/reports.txt" | tr -d ' ') / $LAUNCHES"
echo "RUM sessions:                $(grep -vc 'session=null' "$OUT/reports.txt")"
echo "Expected replays:            $(wc -l <"$OUT/expected_replay_sessions.txt" | tr -d ' ')"
echo "Captured:                    $(grep -c 'capturing=true' "$OUT/reports.txt")"
echo "Expected vs captured differ: $mismatches"
echo
echo "In Datadog, filter on @sr_test_run:$RUN_ID"
echo "Sessions that should have a replay: $OUT/expected_replay_sessions.txt"
