#!/usr/bin/env bash
# tool/tab_frames.sh — native vs Flutter liquid tab bar, 60 fps frame
# strips and traces (spec VK-503 §17.4). Creates its own iOS 26.5 iPhone
# 17 Pro simulator and deletes it. Needs ffmpeg (brew install ffmpeg).
#
# TRACES_ONLY=1  only the Flutter traces (make tab-traces)
# IOS_RUNTIME    simctl runtime (default iOS 26.5)
#
# Every step is time-boxed (tool/with_timeout.sh), so a lost simulator or a
# stuck build fails the run instead of hanging it. macOS only: it reads
# simctl's "Recording started" line and uses the system perl and bc. Both apps are built
# before their recording starts, so a recording holds the run itself, not
# the build.
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IOS_RUNTIME=${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}
command -v ffmpeg >/dev/null || [ "${TRACES_ONLY:-}" = 1 ] || {
  echo "✗ tab_frames.sh needs ffmpeg (brew install ffmpeg)" >&2; exit 1; }
cap() { "$tool_dir/with_timeout.sh" "$@"; }

udid=$(cap 120 xcrun simctl create "vk503-tabfid" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$IOS_RUNTIME")
ticker=
cleanup() {
  [ -z "$ticker" ] || kill "$ticker" 2>/dev/null || true
  cap 120 xcrun simctl delete "$udid" || true
}
trap cleanup EXIT
cap 300 xcrun simctl boot "$udid"
cap 300 xcrun simctl bootstatus "$udid" -b >/dev/null
cap 60 xcrun simctl ui "$udid" appearance light

out=build/tabfid
command rm -rf "$out"
mkdir -p "$out"/native "$out"/flutter

stamp() { # prefixes each line with the host time in seconds
  perl -MTime::HiRes=time -ne 'BEGIN { $| = 1 } printf "%.3f %s", time, $_'
}

# The recorder drops frames while the screen is still and then loses whole
# seconds of idle time (two taps 3 s apart came out 0.25 s apart). A status
# bar clock that flips every 0.1 s, outside the bar band, keeps it honest.
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

# Records the screen while <command> runs. Both drivers print "TABFID
# start" with the bar at rest, at least 2 s before the first sequence; the
# frames are cut from that moment (<name>.offset), so the app launch and
# install never reach the strips.
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
  mark=$(grep -m1 'TABFID start' "$out/$name.log" | cut -d' ' -f1)
  [ -n "$t0" ] && [ -n "$mark" ] || {
    echo "✗ $name: no recording start or no TABFID start marker" >&2; return 1; }
  echo "$mark - $t0" | bc > "$out/$name.offset"
}

target=integration_test/tab_fidelity_test.dart
# shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
flutter_run() { cap 1800 $FLUTTER drive \
  --driver=test_driver/integration_test.dart \
  --target="$target" -d "$udid"; }

if [ "${TRACES_ONLY:-}" = 1 ]; then
  flutter_run
  echo "✓ traces in liquid_shell/example/build/integration_response_data.json"
  exit 0
fi

# A first, unrecorded drive builds the app: `flutter build ios --simulator`
# builds both simulator architectures, which Xcode 27's lipo rejects.
flutter_run
record flutter flutter_run

# The native run: the example's RunnerUITests on the same simulator.
# shellcheck disable=SC2086
cap 600 $FLUTTER build ios --simulator --debug --config-only
derived=build/tabfid-xcode
xcode() { # <action> [args...]
  local action=$1; shift
  cap 1200 xcodebuild "$action" -workspace ios/Runner.xcworkspace \
    -scheme Runner -destination "id=$udid" -derivedDataPath "$derived" \
    -only-testing:RunnerUITests/TabFidelityUITests \
    -parallel-testing-enabled NO -collect-test-diagnostics never "$@"
}
xcode build-for-testing -quiet
record native xcode test-without-building \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 300

# The bar band: the bottom 160 pt at @3x, cropped here so the frames stay
# small on disk.
band="crop=iw:$((160 * 3)):0:$(((874 - 160) * 3))"
for mode in native flutter; do
  # The cut is a frame index on the 60 fps grid: `-ss` lands seconds off
  # in these variable frame rate files.
  skip=$(printf '%.0f' "$(echo "$(cat "$out/$mode.offset") * 60" | bc)")
  cap 900 ffmpeg -loglevel error -i "$out/$mode.mp4" \
    -vf "fps=60,trim=start_frame=$skip,$band" "$out/$mode/%05d.png"
done
# shellcheck disable=SC2086 # DART may be "fvm dart"
cap 1800 $DART run "$tool_dir/tab_strips.dart" "$out/native" "$out/flutter" \
  "$out/strips" --band 0:$((160 * 3)) --every 3 --rows 18 --threshold 0.5
echo "✓ strips in liquid_shell/example/build/tabfid/strips/"
