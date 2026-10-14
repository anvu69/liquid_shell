#!/usr/bin/env bash
# tool/segment_frames.sh — native vs Flutter liquid segmented control, 60
# fps frame strips in light and dark, and traces (spec VK-550 §14.5).
# Creates its own iOS 26.5 iPhone 17 Pro simulator and deletes it. Needs
# ffmpeg (brew install ffmpeg).
#
# TRACES_ONLY=1  only the Flutter traces (make segment-traces)
# IOS_RUNTIME    simctl runtime (default iOS 26.5)
#
# Native: UIKit's UISegmentedControl on the example's reference screen
# (LIQUID_SHELL_EXAMPLE_DEMO=segments-native, DEBUG builds), driven by
# RunnerUITests/SegmentFidelityUITests. Flutter: the segments case in the
# liquid tier, driven by integration_test/segment_fidelity_test.dart. Both
# run the same sequence on the full-width three-segment control. The
# recording, the simulator and the frame cut are tool/frames_lib.sh's
# (shared with tool/tab_frames.sh); every step is time-boxed.
#
# Output: liquid_shell/example/build/segfid/strips/{light,dark}/frames_<k>.png
# (native left, Flutter right). The frames of an appearance whose onsets
# pair are deleted once its strips are written (the recordings stay).
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tool/frames_lib.sh
. "$tool_dir/frames_lib.sh"
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IOS_RUNTIME=${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}
command -v ffmpeg >/dev/null || [ "${TRACES_ONLY:-}" = 1 ] || {
  echo "✗ segment_frames.sh needs ffmpeg (brew install ffmpeg)" >&2; exit 1; }

start_simulator vk550-segfid

out=build/segfid
command rm -rf "$out"
mkdir -p "$out"
marker='SEGFID start'
end_marker='SEGFID end'

target=integration_test/segment_fidelity_test.dart
# Traces-only runs add sequences the strips cannot pair with native's.
traces_only=false
[ "${TRACES_ONLY:-}" != 1 ] || traces_only=true
# The flick native's flickLanding capture made, from the fixture (its only
# source): seconds down to up, then from the last segment's thumb centre to
# the landing, control-local. The trace compare gates the overshoot on it;
# SegmentFidelityUITests reads the same numbers.
fixture=$tool_dir/../docs/qa/vk550/native_reference.json
fx() { plutil -extract "$1" raw -o - "$fixture"; }
flick="$(fx flickLanding.release_at),$(echo \
  "$(fx geometry.thumbs3.2.0) + $(fx geometry.thumbs3.2.2) / 2" | bc -l),$(fx \
  flickLanding.landing)"
# FLUTTER may be "fvm flutter": split on purpose.
# shellcheck disable=SC2086
flutter_run() { cap 1800 $FLUTTER drive \
  --driver=test_driver/integration_test.dart \
  --target="$target" -d "$udid" \
  --dart-define=SEGFID_TRACES_ONLY="$traces_only" \
  --dart-define=SEGFID_FLICK="$flick"; }

if [ "${TRACES_ONLY:-}" = 1 ]; then
  flutter_run
  echo "✓ traces in liquid_shell/example/build/integration_response_data.json"
  exit 0
fi

# A first, unrecorded drive builds the app (see tab_frames.sh).
flutter_run
# The native test bundle, built once for both appearances.
# shellcheck disable=SC2086
cap 600 $FLUTTER build ios --simulator --debug --config-only
derived=build/segfid-xcode
ui_test=SegmentFidelityUITests
xcode build-for-testing -quiet

# The control band: 50 pt from y 232 at @3x, the full-width
# three-segment control's 44 pt box (234 to 278) with the tap lift's
# 50 pt (the lens centre is at 256).
band="crop=iw:150:0:$((232 * 3))"
unpaired=
for appearance in light dark; do
  cap 60 xcrun simctl ui "$udid" appearance "$appearance"
  record "flutter_$appearance" flutter_run
  record "native_$appearance" xcode test-without-building \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
    -maximum-test-execution-time-allowance 300
  for side in native flutter; do
    cut_frames "${side}_$appearance" "$band"
  done
  # The onset threshold, the mean change per channel over the band: on the
  # first VK-550 run a still band stayed at or under 0.29 (stray single
  # frames 0.46) in all four recordings, and the weakest motion, native's
  # dark programmatic slide, peaked at 1.38.
  # DART may be "fvm dart": split on purpose. A mismatch still writes the
  # pairs it has; the frames stay for a look, and dark still runs.
  # shellcheck disable=SC2086
  if cap 1800 $DART run "$tool_dir/tab_strips.dart" \
    "$out/native_$appearance" "$out/flutter_$appearance" \
    "$out/strips/$appearance" --band 0:150 --every 3 --rows 18 \
    --threshold 0.8; then
    command rm -rf "$out/native_$appearance" "$out/flutter_$appearance"
  else
    unpaired="$unpaired $appearance"
  fi
done
[ -z "$unpaired" ] || {
  echo "✗ onsets did not pair in:$unpaired (frames kept in $out)" >&2; exit 1; }
echo "✓ strips in liquid_shell/example/build/segfid/strips/{light,dark}/"
