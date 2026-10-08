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
#
# Reduce Transparency has no supported simctl switch, so only the default
# value is asserted here; toggling it is the manual check in docs/qa/.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
IOS_RUNTIME=${IOS_RUNTIME-iOS 26.5}
IOS_DEVICES=${IOS_DEVICES:-iPhone 17 Pro;iPad Pro 11-inch (M5)}

udid_of() {
  local name=$1 pattern
  if [ "$name" = auto ]; then pattern='    iPhone'; else pattern="    $name ("; fi
  xcrun simctl list devices available ${IOS_RUNTIME:+"$IOS_RUNTIME"} \
    | grep -F "$pattern" | head -n1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
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
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$udid" \
    --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
    --dart-define=EXPECT_POWER_SAVE=false \
    --dart-define=EXPECT_BLUR_DISABLED=false
done
echo "✓ iOS integration passed"
