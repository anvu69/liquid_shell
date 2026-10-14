# shellcheck shell=bash
# tool/frames_lib.sh — the recording half of the native vs Flutter 60 fps
# frame strips, sourced by tool/tab_frames.sh (spec VK-503 §17.4) and
# tool/segment_frames.sh (spec VK-550 §14.5). macOS only: it reads
# simctl's "Recording started" line and uses the system perl and bc.
#
# The sourcing script sets `tool_dir` (this folder) before sourcing, and
# before calling the functions below:
#   IOS_RUNTIME  the simctl runtime of the simulator
#   out          the output folder: <name>.mp4, .rec, .log, .offset and
#                <name>/ (the frames)
#   marker       the line both drivers print with the control at rest, at
#                least 2 s before their first sequence ("TABFID start")
#   end_marker   optional: the line both drivers print after their last
#                sequence, at least 2 s before they finish; the frames end
#                there, so the app's teardown is never a motion onset
#   derived      xcode's DerivedData folder
#   ui_test      the RunnerUITests class xcode runs
# Every step is time-boxed (tool/with_timeout.sh), so a lost simulator or a
# stuck build fails the run instead of hanging it.
# shellcheck disable=SC2154 # the variables above are the sourcing script's

cap() { "$tool_dir/with_timeout.sh" "$@"; }

# The status bar ticker's pid while a recording runs (cleanup kills it).
ticker=

# Creates an iPhone 17 Pro simulator named <name> on IOS_RUNTIME (its id in
# `udid`), deletes it when the script exits, boots it, light appearance.
start_simulator() { # <name>
  udid=$(cap 120 xcrun simctl create "$1" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$IOS_RUNTIME")
  trap cleanup EXIT
  cap 300 xcrun simctl boot "$udid"
  cap 300 xcrun simctl bootstatus "$udid" -b >/dev/null
  cap 60 xcrun simctl ui "$udid" appearance light
}

cleanup() {
  [ -z "$ticker" ] || kill "$ticker" 2>/dev/null || true
  cap 120 xcrun simctl delete "$udid" || true
}

stamp() { # prefixes each line with the host time in seconds
  perl -MTime::HiRes=time -ne 'BEGIN { $| = 1 } printf "%.3f %s", time, $_'
}

# The recorder drops frames while the screen is still and then loses whole
# seconds of idle time (two taps 3 s apart came out 0.25 s apart). A status
# bar clock that flips every 0.1 s, outside the recorded band, keeps it
# honest.
tick() {
  local i=0
  while :; do
    i=$((1 - i))
    cap 10 xcrun simctl status_bar "$udid" override --time "9:4$i" \
      >/dev/null 2>&1 || true
    sleep 0.1
  done
}

# Stops `simctl io recordVideo`: SIGINT makes it write the file; a
# recorder that has not exited after 30 s (a lost simulator) is killed.
stop_recorder() {
  local pid=$1 i
  kill -INT "$pid" 2>/dev/null || true
  for i in $(seq 60); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
  done
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

# Records the screen while <command> runs. Both drivers print the marker
# with the control at rest, at least 2 s before the first sequence; the
# frames are cut from that moment (<name>.offset), so the app launch and
# install never reach the strips, and with an end_marker end at it
# (<name>.end).
record() { # <name> <command...>
  local name=$1 i status=0; shift
  tick &
  ticker=$!
  xcrun simctl io "$udid" recordVideo --codec=h264 --force "$out/$name.mp4" \
    > >(stamp > "$out/$name.rec") 2>&1 &
  local rec=$!
  for i in $(seq 60); do
    grep -q 'Recording started' "$out/$name.rec" 2>/dev/null && break
    sleep 0.5
  done
  set +e
  "$@" 2>&1 | stamp | tee "$out/$name.log"
  status=${PIPESTATUS[0]}
  set -e
  sleep 1
  stop_recorder "$rec"
  kill "$ticker"; wait "$ticker" 2>/dev/null || true
  ticker=
  cap 60 xcrun simctl status_bar "$udid" clear
  [ "$status" = 0 ] || return "$status"
  local t0 mark
  t0=$(grep -m1 'Recording started' "$out/$name.rec" | cut -d' ' -f1)
  mark=$(grep -m1 "$marker" "$out/$name.log" | cut -d' ' -f1)
  [ -n "$t0" ] && [ -n "$mark" ] || {
    echo "✗ $name: no recording start or no $marker marker" >&2; return 1; }
  echo "$mark - $t0" | bc > "$out/$name.offset"
  [ -n "${end_marker:-}" ] || return 0
  mark=$(grep -m1 "$end_marker" "$out/$name.log" | cut -d' ' -f1)
  [ -n "$mark" ] || {
    echo "✗ $name: no $end_marker marker" >&2; return 1; }
  echo "$mark - $t0" | bc > "$out/$name.end"
}

# xcodebuild <action> [args...] on the example's Runner, only
# RunnerUITests/<ui_test>, on the simulator.
xcode() { # <action> [args...]
  local action=$1; shift
  cap 1200 xcodebuild "$action" -workspace ios/Runner.xcworkspace \
    -scheme Runner -destination "id=$udid" -derivedDataPath "$derived" \
    -only-testing:"RunnerUITests/$ui_test" \
    -parallel-testing-enabled NO -collect-test-diagnostics never "$@"
}

# The 60 fps PNG frames of recording <name> from its marker (to its end
# marker, when it has one), through the ffmpeg <filter> (the band's crop,
# so the frames stay small on disk), in <out>/<name>/.
cut_frames() { # <name> <filter>
  local name=$1 filter=$2 trim
  mkdir -p "$out/$name"
  # The cut is a frame index on the 60 fps grid: `-ss` lands seconds off
  # in these variable frame rate files.
  trim="start_frame=$(frame_of "$out/$name.offset")"
  [ ! -f "$out/$name.end" ] || trim="$trim:end_frame=$(frame_of "$out/$name.end")"
  cap 900 ffmpeg -loglevel error -i "$out/$name.mp4" \
    -vf "fps=60,trim=$trim,$filter" "$out/$name/%05d.png"
}

frame_of() { # <file holding seconds>: the 60 fps frame index
  printf '%.0f' "$(echo "$(cat "$1") * 60" | bc)"
}
