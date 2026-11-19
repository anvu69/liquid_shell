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
#    (tool/ios_sim.sh diagnose). A red run, a stall included, first saves
#    the app's liquid_shell log lines of the whole suite (tool/ios_sim.sh
#    applog, VK-1046: the app's log is not in xcodebuild's output), then
#    prints RESULT's summary: `-quiet` names a failing test but not its
#    failed assertion. A green run that ran 0 tests (the selection matched
#    nothing) exits 1.
# 3b. VK-1083 (spec docs/specs/2026-11-19-terminate-rerun-design.md): on a
#    stalled runner XCTest can fail a test inside launch()'s implicit
#    terminate of the previous test's app, "Failed to terminate
#    vn.lasoai.liquidShellExample:<pid>", and the next test then passes on
#    the same simulator. A red run (not a stall) whose summary parses and
#    lists only that failure, for every failed test (failedTests equals the
#    listed ids) and at most 2 tests, runs once more: only those tests
#    (-only-testing:<target>/<class>/<test>, replacing the selection), into
#    RESULT-rerun.xcresult, capped at MAX_ALLOWANCE x n + 120 s. It is
#    recorded first, all under IOS_DIAG_DIR (a rescued job is green, so
#    only CI's always() upload of that folder keeps it): a ::warning::, the
#    first summary as <UTC>-<label>-terminate-rerun.json, a
#    `tool/ios_sim.sh diagnose` dump and `tool/ios_sim.sh termlog` of the
#    suite's seconds plus a minute (the termination path's log lines).
#    The run's status is then the rerun's, and the 0-test guard reads the
#    rerun's bundle. Anything else, python3 failing included, keeps the
#    first status. Never more than one rerun.
#
# `-collect-test-diagnostics never`: with xcodebuild's default (on-failure,
# a sysdiagnose-like bundle after a failure) a red run stalled past 7
# minutes; with `never` it exits in seconds. Test timeouts stop a stuck test.
#
# FLUTTER            flutter command (default: flutter)
# IOS_BUILD_TIMEOUT  seconds each build step may take (default 900)
# IOS_APP_BUNDLE_ID  the app whose terminate failure is rerun
#                    (default vn.lasoai.liquidShellExample)
# IOS_DIAG_DIR       diagnostics root, as tool/ios_sim.sh
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
bundle=${IOS_APP_BUNDLE_ID:-vn.lasoai.liquidShellExample}
diag_root=${IOS_DIAG_DIR:-$example/build/ios-diagnostics}
cap() { "$tool_dir/with_timeout.sh" "$@"; }
label=$(basename "$result" .xcresult)
rerun_result="${result%.xcresult}-rerun.xcresult"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# One `xcodebuild test-without-building` into <bundle>, capped at <seconds>;
# a stall is diagnosed under "<name> stall".
suite() { # <bundle> <seconds> <name> selection...
  local into=$1 secs=$2 name=$3
  shift 3
  WITH_TIMEOUT_ON_STALL="$(printf '%q ' "$tool_dir/ios_sim.sh" diagnose "$udid" \
    "$name stall")" \
    cap "$secs" xcodebuild test-without-building -workspace Runner.xcworkspace \
    -scheme Runner -destination "id=$udid" -derivedDataPath "$derived" "$@" \
    -parallel-testing-enabled NO -collect-test-diagnostics never \
    -test-timeouts-enabled YES -default-test-execution-time-allowance "$allowance" \
    -maximum-test-execution-time-allowance "$max_allowance" \
    -resultBundlePath "$into" -quiet
}

# A red run of <bundle> (<name>) that started at <started>: its app log,
# then its summary, printed and kept in $tmp/<name>.json. Fails when the
# summary cannot be read.
red() { # <bundle> <name> <started>
  # The suite's seconds plus a minute: the dropped tap can be at its start.
  "$tool_dir/ios_sim.sh" applog "$udid" "$2" "$(($(date +%s) - $3 + 60))" || true
  [ -d "$1" ] || return 1
  xcrun xcresulttool get test-results summary --path "$1" > "$tmp/$2.json" \
    || { cat "$tmp/$2.json"; return 1; }
  cat "$tmp/$2.json"
}

# VK-1083: whether a red run's summary (stdin) is only XCTest's failure to
# terminate the previous test's app inside launch() (a stalled runner, not
# the tests). Prints one Target/Class/test per failed test when every
# listed failure is "Failed to terminate <bundle id>:<pid>", the summary's
# failedTests is their number (the list is exhaustive) and there are at
# most 2; otherwise says why not on stderr and fails.
gate_py='
import json, re, sys

def no(why):
    sys.exit("ios_xctest: no terminate rerun: " + why)

try:
    summary = json.load(sys.stdin)
except ValueError:
    no("the summary is not JSON")
failures = summary.get("testFailures") if isinstance(summary, dict) else None
if not isinstance(failures, list) or not failures:
    no("the summary lists no failure")
signal = re.compile(r"Failed to terminate " + re.escape(sys.argv[1]) + r":[0-9]+")
ids = []
for failure in failures:
    if not isinstance(failure, dict):
        no("a failure entry is not an object")
    text = failure.get("failureText")
    if not isinstance(text, str) or not signal.match(text):
        no("a failure is not a terminate failure: %r" % (text,))
    test_id = "%s/%s" % (failure.get("targetName"), failure.get("testIdentifierString"))
    if test_id.endswith("()"):
        test_id = test_id[:-2]
    if not re.fullmatch(r"\w+/\w+/\w+", test_id, re.ASCII):
        no("unexpected test id %r" % (test_id,))
    if test_id not in ids:
        ids.append(test_id)
failed = summary.get("failedTests")
if type(failed) is not int or failed != len(ids):
    no("failedTests is %r, %d terminate failures are listed" % (failed, len(ids)))
if len(ids) > 2:
    no("%d tests failed to terminate, more than 2" % len(ids))
print("\n".join(ids))
'

cd "$example"
rm -rf "$result" "$rerun_result"
"$tool_dir/ios_sim.sh" build "$udid" build-for-testing "$@"
cd ios
"$tool_dir/ios_sim.sh" warmup "$udid" \
  "$derived/Build/Products/Debug-iphonesimulator/Runner.app"
status=0
started=$(date +%s)
suite "$result" "$suite_secs" "$label" "$@" || status=$?
if [ "$status" -ne 0 ]; then
  red "$result" "$label" "$started" || true
  ids=
  [ "$status" -eq 124 ] \
    || ids=$(python3 -I -c "$gate_py" "$bundle" < "$tmp/$label.json") || ids=
  [ -n "$ids" ] || exit "$status"
  selection=()
  while IFS= read -r id; do
    selection+=("-only-testing:$id")
  done <<< "$ids"
  echo "::warning::ios_xctest: XCTest failed to terminate the previous app before $(echo "$ids" | paste -sd , - | sed 's/,/, /g') (VK-1083); rerunning only those, once" >&2
  mkdir -p "$diag_root"
  cp "$tmp/$label.json" \
    "$diag_root/$(date -u +%Y%m%dT%H%M%SZ)-$label-terminate-rerun.json" || true
  "$tool_dir/ios_sim.sh" diagnose "$udid" "$label terminate" || true
  "$tool_dir/ios_sim.sh" termlog "$udid" "$label" \
    "$(($(date +%s) - started + 60))" || true
  rerun_secs=$((max_allowance * ${#selection[@]} + 120))
  echo "ios_xctest: the rerun is capped at $rerun_secs s" >&2
  # From here on, the run is the rerun: its bundle, its selection.
  result=$rerun_result
  set -- "${selection[@]}"
  status=0
  started=$(date +%s)
  suite "$result" "$rerun_secs" "$label-rerun" "$@" || status=$?
  if [ "$status" -ne 0 ]; then
    red "$result" "$label-rerun" "$started" || true
    exit "$status"
  fi
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
