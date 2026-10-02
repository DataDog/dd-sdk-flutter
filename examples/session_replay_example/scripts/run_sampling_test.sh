#!/bin/zsh
#
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.
#
# Launches session_replay_example many times on an iOS simulator to check
# Session Replay sampling end to end, without touching the host mouse or
# keyboard.
#
# Each launch the app taps itself for ~12 seconds (lib/auto_interact.dart),
# then logs its RUM session ID, the replay decision the SDKs should make for it
# at the app's configured sample rates, and whether Session Replay captured.
# Every RUM event carries an `sr_test_run` attribute, so the run can be
# filtered in Datadog with `@sr_test_run:<run id>`.
#
# Usage:
#   scripts/run_sampling_test.sh [-n launches] [-r run-id] [-d device-udid] [-b]
#
#   -n  number of launches (default 100)
#   -r  run ID for the sr_test_run attribute (default sr-<date>-<time>)
#   -d  simulator UDID (default: first booted iPhone, else first available)
#   -b  build and install the app first
#
# Results go to /tmp/sr_sampling/<run id>/ (reports, expected sessions, logs).
# The simulator is booted headless if needed; it doesn't take window focus.

set -u

LAUNCHES=100
RUN_ID="sr-$(date +%m%d-%H%M)"
DEV=""
BUILD=false
BUNDLE=com.datadoghq.sessionReplayExample
SECONDS_PER_LAUNCH=16

while getopts "n:r:d:b" opt; do
  case $opt in
    n) LAUNCHES=$OPTARG ;;
    r) RUN_ID=$OPTARG ;;
    d) DEV=$OPTARG ;;
    b) BUILD=true ;;
    *) sed -n '2,26p' "$0"; exit 1 ;;
  esac
done

APP_DIR=${0:A:h:h}
OUT=/tmp/sr_sampling/$RUN_ID
mkdir -p "$OUT"

if [[ -z $DEV ]]; then
  DEV=$(xcrun simctl list devices booted | grep -m1 -oE 'iPhone.*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')
fi
if [[ -z $DEV ]]; then
  DEV=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone.*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')
fi
if [[ -z $DEV ]]; then
  echo "No iPhone simulator found." >&2
  exit 1
fi

echo "Device:   $DEV"
echo "Run ID:   $RUN_ID"
echo "Launches: $LAUNCHES (~$(( (LAUNCHES * (SECONDS_PER_LAUNCH + 2) + 90 + 59) / 60 )) min)"
echo "Output:   $OUT"

xcrun simctl boot "$DEV" 2>/dev/null
xcrun simctl bootstatus "$DEV" -b >/dev/null 2>&1

if $BUILD; then
  if [[ ! -f "$APP_DIR/.env" ]]; then
    echo "Missing $APP_DIR/.env. Generate it first with generate_env.sh at the repo root." >&2
    exit 1
  fi
  echo "Building and installing..."
  (cd "$APP_DIR" && flutter build ios --simulator --debug >"$OUT/build.log" 2>&1) || {
    echo "Build failed, see $OUT/build.log" >&2
    exit 1
  }
  xcrun simctl install "$DEV" "$APP_DIR/build/ios/iphonesimulator/Runner.app"
fi

CONTAINER=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null) || {
  echo "$BUNDLE is not installed on $DEV. Run again with -b." >&2
  exit 1
}

# The trigger file turns on the app's self-tapping test mode.
mkdir -p "$CONTAINER/Documents"
echo "$RUN_ID" >"$CONTAINER/Documents/sr_test_run"

cleanup() {
  [[ -n ${LOGPID:-} ]] && kill "$LOGPID" 2>/dev/null
  rm -f "$CONTAINER/Documents/sr_test_run"
}
trap cleanup EXIT INT TERM

xcrun simctl spawn "$DEV" log stream --level debug --style compact \
  --predicate 'process == "Runner" AND (eventMessage CONTAINS "SR_TEST" OR eventMessage CONTAINS "Flutter Session Replay")' \
  >"$OUT/os.log" 2>&1 &
LOGPID=$!
sleep 2

: >"$OUT/launches.txt"
for i in $(seq 1 "$LAUNCHES"); do
  pid=$(xcrun simctl launch --terminate-running-process "$DEV" "$BUNDLE" | awk '{print $2}')
  echo "$i $pid $(date +%H:%M:%S)" >>"$OUT/launches.txt"
  printf '\rLaunch %d/%d' "$i" "$LAUNCHES"
  sleep $SECONDS_PER_LAUNCH
  if (( i < LAUNCHES )); then
    xcrun simctl terminate "$DEV" "$BUNDLE"
    sleep 2
  fi
done
echo

echo "Keeping the last launch open for 90 s so its data uploads..."
sleep 90
cleanup
trap - EXIT INT TERM

# Summary
grep -o 'SR_TEST session.*' "$OUT/os.log" >"$OUT/reports.txt"
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
