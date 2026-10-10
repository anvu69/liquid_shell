#!/usr/bin/env bash
# Native vs Flutter liquid screenshots on iOS 26 simulators, then side by
# side (spec 2026-10-10 §11). Creates its own simulators and deletes them.
#
# IOS_RUNTIME  simctl runtime id (default com.apple.CoreSimulator.SimRuntime.iOS-26-5)
# FLUTTER      flutter command (default: flutter)
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IOS_RUNTIME=${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}
created=()
cleanup() { for u in "${created[@]}"; do xcrun simctl delete "$u" || true; done; }
trap cleanup EXIT

shots=build/integration_screenshots
mkdir -p build/compare
for pair in "iphone=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro" \
            "ipad=com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4"; do
  device=${pair%%=*}
  udid=$(xcrun simctl create "vk348-compare-$device" "${pair#*=}" "$IOS_RUNTIME")
  created+=("$udid")
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
  "$tool_dir/with_timeout.sh" 1800 $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/liquid_compare_test.dart -d "$udid" \
    --dart-define=COMPARE_PLATFORM=ios --dart-define=COMPARE_DEVICE="$device" \
    --dart-define=EXPECT_NATIVE=true
  for native in "$shots"/ios_"$device"_*_native.png; do
    liquid=${native%_native.png}_flutterLiquid.png
    name=$(basename "${native%_native.png}")
    # shellcheck disable=SC2086 # DART may be "fvm dart"
    $DART run "$tool_dir/side_by_side.dart" "$native" "$liquid" "build/compare/$name.png"
  done
done
echo "✓ iOS comparisons in liquid_shell/example/build/compare/"
