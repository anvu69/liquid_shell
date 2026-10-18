#!/usr/bin/env bash
# One XCTest run of the example app on one simulator, for make ios-unit,
# ios-ui and ios-minimize (spec docs/specs/2026-10-16-ci-cold-launch-design.md
# §6, VK-625):
#
#   tool/ios_xctest.sh UDID RESULT SUITE_SECONDS DEFAULT_ALLOWANCE \
#     MAX_ALLOWANCE selection...
#
# 1. `flutter build ios --config-only`, then `xcodebuild build-for-testing`
#    into liquid_shell/example/build/ios-derived, each capped at
#    IOS_BUILD_TIMEOUT seconds (default 900): tool/ios_sim.sh build. A
#    build that failed with VK-627's signature (Flutter skipped the
#    deployment-target raise) runs once more, both steps.
# 2. tool/ios_sim.sh warmup: boot, one launch of the built app, terminate.
#    The first launch after a boot is the one that stalls on CI, so no test
#    gets it. Outside every cap here, and it never fails.
# 3. `xcodebuild test-without-building` with the same selection (for
#    example -only-testing:RunnerUITests), capped at SUITE_SECONDS by
#    tool/with_timeout.sh. A stall (124) is diagnosed before the stop
#    (tool/ios_sim.sh diagnose). A red run prints RESULT's summary: `-quiet`
#    names a failing test but not its failed assertion. A green run that ran
#    0 tests (the selection matched nothing) exits 1.
#
# `-collect-test-diagnostics never`: with xcodebuild's default (on-failure,
# a sysdiagnose-like bundle after a failure) a red run stalled past 7
# minutes; with `never` it exits in seconds. Test timeouts stop a stuck test.
#
# FLUTTER            flutter command (default: flutter)
# IOS_BUILD_TIMEOUT  seconds each build step may take (default 900)
set -euo pipefail
if [ $# -lt 6 ]; then
  echo "usage: $0 UDID RESULT SUITE_SECONDS DEFAULT_ALLOWANCE MAX_ALLOWANCE selection..." >&2
  exit 2
fi
udid=$1 result=$2 suite_secs=$3 allowance=$4 max_allowance=$5
shift 5
tool_dir=$(cd "$(dirname "$0")" && pwd)
example=$(cd "$tool_dir/../liquid_shell/example" && pwd)
derived="$example/build/ios-derived"
cap() { "$tool_dir/with_timeout.sh" "$@"; }

cd "$example"
rm -rf "$result"
"$tool_dir/ios_sim.sh" build "$udid" build-for-testing "$@"
cd ios
"$tool_dir/ios_sim.sh" warmup "$udid" \
  "$derived/Build/Products/Debug-iphonesimulator/Runner.app"
status=0
WITH_TIMEOUT_ON_STALL="$(printf '%q ' "$tool_dir/ios_sim.sh" diagnose "$udid" \
  "$(basename "$result" .xcresult) stall")" \
  cap "$suite_secs" xcodebuild test-without-building -workspace Runner.xcworkspace \
  -scheme Runner -destination "id=$udid" -derivedDataPath "$derived" "$@" \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -test-timeouts-enabled YES -default-test-execution-time-allowance "$allowance" \
  -maximum-test-execution-time-allowance "$max_allowance" \
  -resultBundlePath "$result" -quiet || status=$?
if [ "$status" -ne 0 ]; then
  [ ! -d "$result" ] \
    || xcrun xcresulttool get test-results summary --path "$result" || true
  exit "$status"
fi
# A selection that matches nothing (a renamed or moved test class) makes
# xcodebuild exit 0 having run nothing, and a blocking job would then guard
# nothing. totalTestCount counts passed, failed and skipped tests alike. A
# result that cannot be read is a warning, not a failure.
total=$(xcrun xcresulttool get test-results summary --path "$result" 2> /dev/null \
  | grep -Eo '"totalTestCount"[[:space:]]*:[[:space:]]*[0-9]+' \
  | grep -Eo '[0-9]+$' || true)
if [ -z "$total" ]; then
  echo "::warning::ios_xctest: could not read the test count of $result" >&2
elif [ "$total" -eq 0 ]; then
  echo "✗ ios_xctest: the selection ran 0 tests: $*" >&2
  exit 1
fi
