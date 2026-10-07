#!/bin/bash
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

# Collects diagnostics for iOS integration tests that hang on CI.
#
# Usage:
#   ios_test_watchdog.sh watch <parent_pid> <log_dir> <output_dir>
#     Runs until <parent_pid> exits. Records the desktop on startup, and captures
#     a snapshot whenever no file in <log_dir> has changed for STALL_SECONDS.
#   ios_test_watchdog.sh snapshot <label> <output_dir>
#     Captures a single snapshot, including the simulator's unified log.

set -u

HEARTBEAT_SECONDS=${HEARTBEAT_SECONDS:-60}
STALL_SECONDS=${STALL_SECONDS:-600}
VIDEO_SECONDS=${VIDEO_SECONDS:-60}
MAX_SNAPSHOTS=${MAX_SNAPSHOTS:-3}
RECORD_DESKTOP=${RECORD_DESKTOP:-1}

OUTPUT_DIR=""
VIDEO_DISABLED=$((RECORD_DESKTOP == 0))

message() {
  local text
  text="$(date -u '+%Y-%m-%d %H:%M:%S UTC') $*"
  echo "$text" >> "$OUTPUT_DIR/watchdog.log"
  echo "[ios-watchdog] $text" >&2
}

# Runs a command with output redirected to a file, killing it after a timeout.
bounded() {
  local seconds=$1 output=$2
  shift 2
  "$@" > "$output" 2>&1 &
  local pid=$!
  ( sleep "$seconds"; kill -INT "$pid" 2>/dev/null; sleep 5; kill -KILL "$pid" 2>/dev/null ) &
  local guard=$!
  wait "$pid"
  local status=$?
  kill "$guard" 2>/dev/null
  wait "$guard" 2>/dev/null
  if [ "$status" -ne 0 ]; then
    echo "Diagnostic command exited with $status" >> "$output"
  fi
  return "$status"
}

# Records the desktop, which needs Screen Recording permission on the runner.
# Disables further recordings if the first one fails.
record_desktop() {
  local label=$1
  if [ "$VIDEO_DISABLED" -ne 0 ]; then
    return
  fi
  local video="$OUTPUT_DIR/desktop-$label.mov"
  message "Recording desktop for ${VIDEO_SECONDS}s: $video"
  bounded $((VIDEO_SECONDS + 15)) "$OUTPUT_DIR/desktop-$label.log" \
    /usr/sbin/screencapture -x -v -V "$VIDEO_SECONDS" -D1 "$video"
  if [ ! -s "$video" ]; then
    VIDEO_DISABLED=1
    message "Desktop recording unavailable; see desktop-$label.log"
  fi
}

snapshot() {
  local label=$1
  local dir="$OUTPUT_DIR/$label"
  mkdir -p "$dir"
  message "Capturing snapshot: $dir"

  # Executable names only, so command-line arguments and environments aren't uploaded.
  bounded 15 "$dir/processes.log" /bin/ps -axo pid=,ppid=,%cpu=,rss=,etime=,stat=,comm=
  bounded 30 "$dir/simctl-list.log" xcrun simctl list devices
  bounded 30 "$dir/simulator-screenshot.log" xcrun simctl io booted screenshot "$dir/simulator.png"

  local pids
  pids=$(awk '$7 ~ /(simctl|CoreSimulatorService|launchd_sim|SpringBoard|Runner)$/ { print $1 }' \
    "$dir/processes.log" | head -n 8)
  for pid in $pids; do
    bounded 30 "$dir/sample-$pid-command.log" \
      /usr/bin/sample "$pid" 5 10 -mayDie -file "$dir/sample-$pid.log"
  done

  record_desktop "$label"
}

newest_log_mtime() {
  local newest=0 mtime
  for file in "$1"/*; do
    [ -f "$file" ] || continue
    mtime=$(/usr/bin/stat -f %m "$file")
    if [ "$mtime" -gt "$newest" ]; then
      newest=$mtime
    fi
  done
  echo "$newest"
}

watch() {
  local parent_pid=$1 log_dir=$2
  local started now last_output last_capture next_heartbeat mtime count=0
  started=$(date +%s)
  last_output=$started
  last_capture=$started
  next_heartbeat=$((started + HEARTBEAT_SECONDS))

  message "Watching $log_dir for parent PID $parent_pid; stall threshold ${STALL_SECONDS}s"
  record_desktop startup

  while kill -0 "$parent_pid" 2>/dev/null; do
    sleep 5
    now=$(date +%s)
    mtime=$(newest_log_mtime "$log_dir")
    if [ "$mtime" -gt "$last_output" ]; then
      last_output=$mtime
    fi

    if [ "$now" -ge "$next_heartbeat" ]; then
      message "Elapsed $((now - started))s; no log output for $((now - last_output))s"
      next_heartbeat=$((now + HEARTBEAT_SECONDS))
    fi

    if [ "$count" -lt "$MAX_SNAPSHOTS" ] \
        && [ $((now - last_output)) -ge "$STALL_SECONDS" ] \
        && [ $((now - last_capture)) -ge "$STALL_SECONDS" ]; then
      count=$((count + 1))
      snapshot "stall-$(printf '%02d' "$count")"
      last_capture=$(date +%s)
    fi
  done
  message "Parent PID $parent_pid exited; stopping"
}

case "${1:-}" in
  watch)
    [ $# -eq 4 ] || { echo "usage: $0 watch <parent_pid> <log_dir> <output_dir>" >&2; exit 2; }
    OUTPUT_DIR=$4
    mkdir -p "$OUTPUT_DIR" "$3"
    watch "$2" "$3"
    ;;
  snapshot)
    [ $# -eq 3 ] || { echo "usage: $0 snapshot <label> <output_dir>" >&2; exit 2; }
    OUTPUT_DIR=$3
    mkdir -p "$OUTPUT_DIR"
    snapshot "$2"
    bounded 60 "$OUTPUT_DIR/$2/simulator.log" \
      xcrun simctl spawn booted log show --last 15m --style compact
    gzip -f "$OUTPUT_DIR/$2/simulator.log"
    ;;
  *)
    echo "usage: $0 {watch|snapshot} ..." >&2
    exit 2
    ;;
esac
