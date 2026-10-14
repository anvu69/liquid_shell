#!/usr/bin/env bash
# tool/tab_frames.sh — native vs Flutter liquid tab bar, 60 fps frame
# strips and traces (spec VK-503 §17.4). Creates its own iOS 26.5 iPhone
# 17 Pro simulator and deletes it. Needs ffmpeg (brew install ffmpeg).
#
# TRACES_ONLY=1  only the Flutter traces (make tab-traces)
# IOS_RUNTIME    simctl runtime (default iOS 26.5)
#
# The recording, the simulator and the frame cut are tool/frames_lib.sh's
# (shared with tool/segment_frames.sh). Every step is time-boxed
# (tool/with_timeout.sh). Both apps are built before their recording
# starts, so a recording holds the run itself, not the build.
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tool/frames_lib.sh
. "$tool_dir/frames_lib.sh"
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IOS_RUNTIME=${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}
command -v ffmpeg >/dev/null || [ "${TRACES_ONLY:-}" = 1 ] || {
  echo "✗ tab_frames.sh needs ffmpeg (brew install ffmpeg)" >&2; exit 1; }

start_simulator vk503-tabfid

out=build/tabfid
command rm -rf "$out"
mkdir -p "$out"/native "$out"/flutter
marker='TABFID start'

target=integration_test/tab_fidelity_test.dart
# Traces-only runs add sequences the strips cannot pair with native's.
traces_only=false
[ "${TRACES_ONLY:-}" != 1 ] || traces_only=true
# FLUTTER may be "fvm flutter": split on purpose.
# shellcheck disable=SC2086
flutter_run() { cap 1800 $FLUTTER drive \
  --driver=test_driver/integration_test.dart \
  --target="$target" -d "$udid" \
  --dart-define=TABFID_TRACES_ONLY="$traces_only"; }

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
ui_test=TabFidelityUITests
xcode build-for-testing -quiet
record native xcode test-without-building \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 300

# The bar band: the bottom 160 pt at @3x, cropped here so the frames stay
# small on disk.
band="crop=iw:$((160 * 3)):0:$(((874 - 160) * 3))"
for mode in native flutter; do
  cut_frames "$mode" "$band"
done
# shellcheck disable=SC2086 # DART may be "fvm dart"
cap 1800 $DART run "$tool_dir/tab_strips.dart" "$out/native" "$out/flutter" \
  "$out/strips" --band 0:$((160 * 3)) --every 3 --rows 18 --threshold 0.5
echo "✓ strips in liquid_shell/example/build/tabfid/strips/"
