#!/usr/bin/env bash
# Flutter liquid on an Android emulator, placed next to the iPhone native
# shots of tool/compare_ios.sh (spec 2026-10-10 §11).
#
# ANDROID_SERIAL  an emulator-* serial you started (never a physical device)
# FLUTTER, DART   commands (default: flutter, dart)
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
: "${ANDROID_SERIAL:?start an emulator and set ANDROID_SERIAL=emulator-NNNN}"
if [[ "$ANDROID_SERIAL" != emulator-* ]]; then
  echo "✗ $ANDROID_SERIAL is not an emulator" >&2
  exit 1
fi
shots=build/integration_screenshots
# Keep the iOS native shots (the left half of every pair); drop stale
# Android ones and earlier Android pairs.
rm -f "$shots"/android_* build/compare/android_*
mkdir -p build/compare
# shellcheck disable=SC2086
$FLUTTER drive --driver=test_driver/integration_test.dart \
  --target=integration_test/liquid_compare_test.dart -d "$ANDROID_SERIAL" \
  --dart-define=COMPARE_PLATFORM=android --dart-define=COMPARE_DEVICE=phone \
  --dart-define=COMPARE_MODES=flutterLiquid
for liquid in "$shots"/android_phone_*_flutterLiquid.png; do
  id=${liquid#"$shots"/android_phone_}
  id=${id%_flutterLiquid.png}
  native="$shots/ios_iphone_${id}_native.png"
  if [ -f "$native" ]; then
    # shellcheck disable=SC2086
    $DART run "$tool_dir/side_by_side.dart" "$native" "$liquid" "build/compare/android_$id.png"
  else
    echo "▸ no $native yet (run tool/compare_ios.sh first); kept $liquid alone"
  fi
done
echo "✓ Android comparisons in liquid_shell/example/build/compare/"
