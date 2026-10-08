#!/usr/bin/env bash
# Signal channel + every Android signal on an emulator (spec §10.5).
#
#   tool/integration_android.sh
#
# ANDROID_SERIAL  adb serial (default: the first running emulator-*). The
#                 script changes system settings, so it refuses a physical
#                 device unless ALLOW_PHYSICAL_DEVICE=1.
# FLUTTER         flutter command (default: flutter).
#
# Each run sets one signal with adb, then asserts it through
# integration_test/signals_test.dart (expectations via --dart-define).
# Every setting is restored on exit, even after a failure.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}

if [ -z "${ANDROID_SERIAL:-}" ]; then
  ANDROID_SERIAL=$(adb devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ {print $1; exit}')
fi
if [ -z "$ANDROID_SERIAL" ]; then
  echo "✗ no running emulator. Start one, e.g. emulator -avd tuvi_test" >&2
  exit 1
fi
if [[ "$ANDROID_SERIAL" != emulator-* && "${ALLOW_PHYSICAL_DEVICE:-0}" != 1 ]]; then
  echo "✗ $ANDROID_SERIAL is not an emulator; set ALLOW_PHYSICAL_DEVICE=1 to proceed" >&2
  exit 1
fi
export ANDROID_SERIAL
api=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
echo "▸ device $ANDROID_SERIAL, API $api"

orig_scale=$(adb shell settings get global animator_duration_scale | tr -d '\r')
restore() {
  if [ "$orig_scale" = null ]; then
    adb shell settings delete global animator_duration_scale >/dev/null || true
  else
    adb shell settings put global animator_duration_scale "$orig_scale" || true
  fi
  adb shell settings put global low_power 0 || true
  adb shell cmd battery reset || true
  adb shell settings put global disable_window_blurs 0 || true
}
trap restore EXIT
restore

run() {
  local name=$1
  shift
  echo "▸ run: $name"
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$ANDROID_SERIAL" "$@"
}

blur_default=false
if [ "$api" -ge 31 ] &&
  [ "$(adb shell getprop ro.surface_flinger.supports_background_blur | tr -d '\r')" != 1 ]; then
  blur_default=true # no GPU blur on this image: the system reports it disabled
fi

run default \
  --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
  --dart-define=EXPECT_POWER_SAVE=false \
  --dart-define=EXPECT_BLUR_DISABLED=$blur_default

adb shell settings put global animator_duration_scale 0
run reduceTransparency --dart-define=EXPECT_REDUCE_TRANSPARENCY=true
restore

adb shell cmd battery unplug
adb shell settings put global low_power 1
# Battery saver also disables window blurs on API 31+, so blurDisabled is
# not asserted in this run.
run powerSave --dart-define=EXPECT_POWER_SAVE=true
restore

if [ "$api" -ge 31 ]; then
  # `wm disable-blur 1` writes this setting but needs root on API 36
  # google_apis images (SecurityException as the shell user).
  adb shell settings put global disable_window_blurs 1
  run blurDisabled --dart-define=EXPECT_BLUR_DISABLED=true
  restore
fi
echo "✓ Android integration passed"
