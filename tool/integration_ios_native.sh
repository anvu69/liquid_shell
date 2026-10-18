#!/usr/bin/env bash
# Native iOS 26 shell, native dialogs and the search tab on simulators
# (specs P2 §9.4, P3a §9.4, P3b §12.5).
#
#   tool/integration_ios_native.sh
#
# IOS_RUNTIME     simctl runtime (default "iOS 26.5"; empty = any).
# NATIVE_DEVICES  ';'-separated "name=expect" pairs; expect is true when the
#                 native shell must install (iPhone or iPad, iOS >= 26) and
#                 false when it must not (default
#                 "iPad Air 11-inch (M4)=true;iPhone 17 Pro=true").
#                 A 36-character UDID works in place of a name.
# NATIVE_TARGETS  space-separated integration tests to drive on each device
#                 (default "native_shell_test.dart native_dialogs_test.dart
#                 native_search_test.dart").
# FLUTTER         flutter command (default: flutter).
# IOS_DRIVE_TIMEOUT  seconds one `flutter drive` may run (default 1200).
#
# Warm-up and stall guard, as in tool/integration_ios.sh (VK-625, VK-627):
# each simulator is booted, and the example built and launched once, before
# its first drive (tool/ios_sim.sh warmup --build). A drive (one target on
# one device) that outlives IOS_DRIVE_TIMEOUT is diagnosed and stopped, the
# app is terminated, and that drive is retried once on the same booted
# simulator (tool/ios_sim.sh guard). A drive whose build failed with
# VK-627's signature is retried once too; a drive runs at most twice, and a
# test failure is never retried.
#
# Screenshots land in liquid_shell/example/build/integration_screenshots/:
# native_<run>_*.png (home, sidebar, guard, cases), dialogs_<run>_*.png
# (alert, sheet, alert_flutter) and search_<run>_*.png (one per phase of the
# search tab). They are the doc images of the native chrome and dialogs,
# which goldens cannot draw (spec P2 §9.5).
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
export FLUTTER=${FLUTTER:-flutter}
IOS_DRIVE_TIMEOUT=${IOS_DRIVE_TIMEOUT:-1200}
IOS_RUNTIME=${IOS_RUNTIME-iOS 26.5}
NATIVE_DEVICES=${NATIVE_DEVICES:-iPad Air 11-inch (M4)=true;iPhone 17 Pro=true}
NATIVE_TARGETS=${NATIVE_TARGETS:-native_shell_test.dart native_dialogs_test.dart native_search_test.dart}

udid_of() {
  local name=$1
  if [[ $name =~ ^[0-9A-F-]{36}$ ]]; then echo "$name"; return; fi
  xcrun simctl list devices available ${IOS_RUNTIME:+"$IOS_RUNTIME"} \
    | grep -F "    $name (" | head -n1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

drive() {
  local udid=$1 expect=$2 run=$3 target=$4
  # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
  "$tool_dir/ios_sim.sh" guard "$udid" "$target on $run" \
    "$IOS_DRIVE_TIMEOUT" $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target="integration_test/$target" \
    -d "$udid" \
    --dart-define=EXPECT_NATIVE="$expect" \
    --dart-define=RUN_NAME="$run"
}

IFS=';' read -r -a pairs <<< "$NATIVE_DEVICES"
for pair in "${pairs[@]}"; do
  name=${pair%=*}
  expect=${pair##*=}
  udid=$(udid_of "$name")
  if [ -z "$udid" ]; then
    echo "✗ no available simulator named '$name' (${IOS_RUNTIME:-any runtime})" >&2
    exit 1
  fi
  run=${name//[^A-Za-z0-9]/_}
  echo "▸ $name ($udid), native expected: $expect"
  "$tool_dir/ios_sim.sh" warmup "$udid" --build
  for target in $NATIVE_TARGETS; do
    echo "▸ $name: $target"
    drive "$udid" "$expect" "$run" "$target" || exit $?
  done
done
echo "✓ native shell integration passed"
