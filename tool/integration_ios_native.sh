#!/usr/bin/env bash
# Native iPadOS 26 shell on simulators (spec P2 §9.4).
#
#   tool/integration_ios_native.sh
#
# IOS_RUNTIME     simctl runtime (default "iOS 26.5"; empty = any).
# NATIVE_DEVICES  ';'-separated "name=expect" pairs; expect is true when the
#                 native shell must install (iPad, iOS >= 26) and false when
#                 it must not (default
#                 "iPad Air 11-inch (M4)=true;iPhone 17 Pro=false").
#                 A 36-character UDID works in place of a name.
# FLUTTER         flutter command (default: flutter).
# IOS_DRIVE_TIMEOUT  seconds one `flutter drive` may run (default 600).
#
# Stall guard, as in tool/integration_ios.sh: a drive that outlives
# IOS_DRIVE_TIMEOUT is stopped (tool/with_timeout.sh), the simulator is
# restarted and the drive is retried once. A test failure is never retried.
#
# Screenshots land in liquid_shell/example/build/integration_screenshots/
# (native_<run>_home.png, native_<run>_sidebar.png): the doc images of the
# native chrome, which goldens cannot draw (spec P2 §9.5).
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
IOS_DRIVE_TIMEOUT=${IOS_DRIVE_TIMEOUT:-600}
IOS_RUNTIME=${IOS_RUNTIME-iOS 26.5}
NATIVE_DEVICES=${NATIVE_DEVICES:-iPad Air 11-inch (M4)=true;iPhone 17 Pro=false}

udid_of() {
  local name=$1
  if [[ $name =~ ^[0-9A-F-]{36}$ ]]; then echo "$name"; return; fi
  xcrun simctl list devices available ${IOS_RUNTIME:+"$IOS_RUNTIME"} \
    | grep -F "    $name (" | head -n1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

boot() {
  xcrun simctl boot "$1" 2>/dev/null || true
  xcrun simctl bootstatus "$1" -b >/dev/null
}

drive() {
  local udid=$1 expect=$2 run=$3
  # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
  "$tool_dir/with_timeout.sh" "$IOS_DRIVE_TIMEOUT" $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/native_shell_test.dart \
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
  boot "$udid"
  status=0
  drive "$udid" "$expect" "$run" || status=$?
  if [ "$status" -eq 124 ]; then
    echo "▸ flutter drive stalled; restarting $name and retrying once" >&2
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    boot "$udid"
    status=0
    drive "$udid" "$expect" "$run" || status=$?
  fi
  [ "$status" -eq 0 ] || exit "$status"
done
echo "✓ native shell integration passed"
