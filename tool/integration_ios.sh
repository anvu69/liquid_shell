#!/usr/bin/env bash
# Signal channel round-trip on iOS simulators (spec §10.5).
#
#   tool/integration_ios.sh
#
# IOS_RUNTIME   simctl runtime to pick devices from (default "iOS 26.5";
#               empty = any available runtime, used by CI).
# IOS_DEVICES   ';'-separated simulator names
#               (default "iPhone 17 Pro;iPad Pro 11-inch (M5)").
#               "auto" = the first available iPhone (CI).
# FLUTTER       flutter command (default: flutter).
# IOS_DRIVE_TIMEOUT  seconds one `flutter drive` may run (default 600; a
#               normal run takes about 5 minutes including the Xcode build).
#
# Stall guard: on GitHub's macOS runners `flutter drive` has hung after
# "Xcode build done" with a stuck simctl (app install/launch never returned)
# until the 6 h job limit. A drive that outlives IOS_DRIVE_TIMEOUT is killed
# (tool/with_timeout.sh), the simulator is restarted and the drive is retried
# once. A test failure is never retried, only a stall.
#
# Reduce Transparency has no supported simctl switch, so only the default
# value is asserted here; toggling it is the manual check in docs/qa/.
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
IOS_DRIVE_TIMEOUT=${IOS_DRIVE_TIMEOUT:-600}
IOS_RUNTIME=${IOS_RUNTIME-iOS 26.5}
IOS_DEVICES=${IOS_DEVICES:-iPhone 17 Pro;iPad Pro 11-inch (M5)}

udid_of() {
  local name=$1 pattern
  if [ "$name" = auto ]; then pattern='    iPhone'; else pattern="    $name ("; fi
  xcrun simctl list devices available ${IOS_RUNTIME:+"$IOS_RUNTIME"} \
    | grep -F "$pattern" | head -n1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

drive() {
  local udid=$1 name=$2
  # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
  "$tool_dir/with_timeout.sh" "$IOS_DRIVE_TIMEOUT" $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$udid" \
    --dart-define=RUN_NAME="ios_${name//[^A-Za-z0-9]/_}" \
    --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
    --dart-define=EXPECT_POWER_SAVE=false \
    --dart-define=EXPECT_BLUR_DISABLED=false
}

IFS=';' read -r -a names <<< "$IOS_DEVICES"
for name in "${names[@]}"; do
  udid=$(udid_of "$name")
  if [ -z "$udid" ]; then
    echo "✗ no available simulator named '$name' (${IOS_RUNTIME:-any runtime})" >&2
    exit 1
  fi
  echo "▸ $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  status=0
  drive "$udid" "$name" || status=$?
  if [ "$status" -eq 124 ]; then
    echo "▸ flutter drive stalled; restarting $name and retrying once" >&2
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null
    status=0
    drive "$udid" "$name" || status=$?
  fi
  [ "$status" -eq 0 ] || exit "$status"
done
echo "✓ iOS integration passed"
