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
# Each run starts from a known baseline (animations at 1x, battery saver
# and the blur switch off), sets one signal with adb, then asserts it
# through integration_test/signals_test.dart (expectations via
# --dart-define). The baseline matters: an emulator started with animations
# off (android-emulator-runner's default) reads as reduce transparency.
# On exit, even after a failure, the animator scale goes back to the value
# found at start and the other settings are reset.
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
echo "▸ animator_duration_scale at start: $orig_scale"

reset_power_and_blur() {
  adb shell settings put global low_power 0 || true
  adb shell cmd battery reset || true
  adb shell settings put global disable_window_blurs 0 || true
}

# Known state before every run: animations on, no battery saver, blurs on.
baseline() {
  adb shell settings put global animator_duration_scale 1
  reset_power_and_blur
}

restore() {
  if [ "$orig_scale" = null ]; then
    adb shell settings delete global animator_duration_scale >/dev/null || true
  else
    adb shell settings put global animator_duration_scale "$orig_scale" || true
  fi
  reset_power_and_blur
  echo "▸ animator_duration_scale restored: $(adb shell settings get global animator_duration_scale | tr -d '\r')"
}
trap restore EXIT
baseline

run() {
  local name=$1
  shift
  echo "▸ run: $name"
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$ANDROID_SERIAL" \
    --dart-define=RUN_NAME="android_$name" \
    --dart-define=EXPECT_LOW_END="$low_end" \
    --dart-define=EXPECT_GLES_ONLY="$gles_only" "$@"
}

power_dump() { adb shell dumpsys power | tr -d '\r'; }

# Dumps are captured first: under pipefail, `grep -q` closing the pipe early
# would fail the check through adb's SIGPIPE.
unplugged() { grep -q 'mIsPowered=false' <<< "$(power_dump)"; }

battery_saver_on() {
  local dump
  dump=$(power_dump)
  if grep -q 'Battery Saver is currently:' <<< "$dump"; then
    grep -q 'Battery Saver is currently: ON' <<< "$dump"
  else # an image without battery saving stats: trust the setting
    [ "$(adb shell settings get global low_power | tr -d '\r')" = 1 ]
  fi
}

# wait_for DESCRIPTION CHECK: polls CHECK for up to 30 s, then fails with
# the power state, so a device that ignores the request is named as such
# instead of surfacing as a test failure.
wait_for() {
  local what=$1 check=$2 i
  for i in $(seq 30); do
    if "$check"; then return 0; fi
    sleep 1
  done
  echo "✗ timed out after 30 s waiting for $what" >&2
  power_dump | grep -E 'mIsPowered=|mSettingBatterySaverEnabled=|Battery Saver is currently' >&2 || true
  adb shell dumpsys battery | tr -d '\r' | grep -E 'powered|level' >&2 || true
  exit 1
}

blur_default=false
if [ "$api" -ge 31 ] &&
  [ "$(adb shell getprop ro.surface_flinger.supports_background_blur | tr -d '\r')" != 1 ]; then
  blur_default=true # no GPU blur on this image: the system reports it disabled
fi

# Device facts behind lowEnd and glesOnly (spec 2026-10-10 §7.1), read the
# way the plugin reads them: MemTotal is ActivityManager's totalMem.
# Without MemTotal the expectation would be a guess (an empty value reads as
# not low end), so the script stops instead.
if ! meminfo=$(adb shell cat /proc/meminfo); then
  echo "✗ could not read /proc/meminfo on $ANDROID_SERIAL" >&2
  exit 1
fi
mem_kb=$(tr -d '\r' <<< "$meminfo" | awk '/^MemTotal:/ {print $2}')
if ! [[ "$mem_kb" =~ ^[0-9]+$ ]]; then
  echo "✗ no MemTotal in /proc/meminfo on $ANDROID_SERIAL; cannot tell whether it is low end" >&2
  exit 1
fi
low_ram=$(adb shell getprop ro.config.low_ram | tr -d '\r')
low_end=false
if [ "$low_ram" = true ] || [ "$mem_kb" -lt 3145728 ]; then low_end=true; fi
gles_only=false
if [ "$api" -ge 29 ] &&
  [ "$(adb shell pm has-feature android.hardware.vulkan.version 4198400 | tr -d '\r')" != true ]; then
  gles_only=true
fi
echo "▸ MemTotal ${mem_kb} kB (low end: $low_end), Vulkan 1.1 missing: $gles_only"

run default \
  --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
  --dart-define=EXPECT_POWER_SAVE=false \
  --dart-define=EXPECT_BLUR_DISABLED=$blur_default

adb shell settings put global animator_duration_scale 0
run reduceTransparency --dart-define=EXPECT_REDUCE_TRANSPARENCY=true
baseline

# The setting alone is not proof: a run once saw powerSave false (and blurs
# on) on CI. Battery saver cannot be on while the device counts as powered,
# and a manual one is dropped when a plugged device is at or above the
# sticky auto-disable threshold (90 %). So the level goes to 50, the script
# waits for the unplug to land before turning saver on, and waits for the
# system to report it on before launching the app.
adb shell cmd battery set level 50
adb shell cmd battery unplug
wait_for "the device to count as unplugged" unplugged
adb shell settings put global low_power 1
wait_for "battery saver to be on" battery_saver_on
# Battery saver also disables window blurs on API 31+, so blurDisabled is
# not asserted in this run.
run powerSave --dart-define=EXPECT_POWER_SAVE=true
baseline

if [ "$api" -ge 31 ]; then
  # `wm disable-blur 1` writes this setting but needs root on API 36
  # google_apis images (SecurityException as the shell user).
  adb shell settings put global disable_window_blurs 1
  run blurDisabled --dart-define=EXPECT_BLUR_DISABLED=true
  baseline
fi
echo "✓ Android integration passed"
