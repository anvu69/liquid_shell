#!/usr/bin/env bash
# The first app launch after an iOS simulator boots is the one that stalls
# on CI (spec docs/specs/2026-10-16-ci-cold-launch-design.md, VK-625): 30 of
# 127 first `flutter drive` launches after `simctl boot` + `bootstatus -b`
# stalled, against 8 of 197 later ones. These helpers keep that launch away
# from every suite and record what the simulator knows when one stalls.
#
#   tool/ios_sim.sh warmup UDID [APP | --build]
#   tool/ios_sim.sh diagnose UDID LABEL [WINDOW]
#   tool/ios_sim.sh guard UDID LABEL SECONDS command [args...]
#
# warmup    Boots UDID and waits for it (simctl boot, bootstatus -b),
#           installs APP when given, launches the example once and waits
#           until it logs "The Dart VM service is listening on" (at most
#           IOS_WARMUP_TIMEOUT seconds), then terminates it. --build first
#           builds the example for UDID (flutter build ios --config-only,
#           xcodebuild build into liquid_shell/example/build/ios-derived)
#           and installs that. It never fails: a timeout is diagnosed, any
#           other problem is reported, and it exits 0. Its log reader is
#           stopped on every path, also when the script is terminated. A
#           timeout dump adds warm-up-reader.log (what the reader saw) and
#           `launched:` and `reader ready:` to meta.txt.
# diagnose  Writes IOS_DIAG_DIR/<UTC time>-<LABEL>/: meta.txt (timestamps,
#           load, the app's pid), vm-service.log (`log show --last WINDOW`,
#           default 15m, of the app's VM service line), launchctl.txt (the app in the
#           simulator's launchd) and sample.txt (`sample` of the app for
#           5 s when it is alive). Every step is capped; it exits 0.
# guard     The stall guard. Runs the command under tool/with_timeout.sh for
#           at most SECONDS. A stall (124) is diagnosed before the stop; then
#           the app is terminated and the command runs once more on the same
#           booted simulator, never a rebooted one (a retry after a reboot
#           stalled 13 times in 38). Any other status is the command's own
#           and is never retried.
#
# IOS_APP_BUNDLE_ID   the app (default vn.lasoai.liquidShellExample)
# IOS_WARMUP_TIMEOUT  seconds the warm-up waits for the VM service line
#                     (default 180; passing first launches after a boot
#                     logged their first line within 85 s on CI)
# IOS_WARMUP_READY_TIMEOUT
#                     seconds the warm-up waits for its log reader to
#                     attach before it launches (default 30)
# IOS_BUILD_TIMEOUT   seconds each step of --build may take (default 900)
# IOS_DIAG_DIR        diagnostics root
#                     (default liquid_shell/example/build/ios-diagnostics)
# FLUTTER             flutter command for --build (default: flutter)
set -uo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
example=$(cd "$tool_dir/../liquid_shell/example" && pwd)
bundle=${IOS_APP_BUNDLE_ID:-vn.lasoai.liquidShellExample}
warmup_timeout=${IOS_WARMUP_TIMEOUT:-180}
build_timeout=${IOS_BUILD_TIMEOUT:-900}
ready_timeout=${IOS_WARMUP_READY_TIMEOUT:-30}
# A non-numeric value would spin the poll loops until the job cap.
# $1 variable name, $2 value, $3 default; prints the number to use.
number_or_default() {
  case "$2" in
    '' | *[!0-9]*)
      echo "ios_sim: $1=$2 is not a number, using $3" >&2
      echo "$3"
      ;;
    *) echo "$2" ;;
  esac
}
warmup_timeout=$(number_or_default IOS_WARMUP_TIMEOUT "$warmup_timeout" 180)
ready_timeout=$(number_or_default IOS_WARMUP_READY_TIMEOUT "$ready_timeout" 30)
last_dump=
diag_root=${IOS_DIAG_DIR:-$example/build/ios-diagnostics}
# The line flutter_tools waits for after `simctl launch` (simulators.dart),
# from the app's own process. The predicate leaves out the trailing " on",
# so `log stream`'s "Filtering the log data using …" header never matches
# vm_line.
vm_predicate='process == "Runner" AND eventMessage CONTAINS "Dart VM service is listening"'
vm_line='Dart VM service is listening on'

cap() { "$tool_dir/with_timeout.sh" "$@"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
note() { echo "ios_sim: $*" >&2; }
# A line the measurement counts (spec §11); an annotation on GitHub Actions.
warn() {
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::warning::ios_sim: $*"
  else
    echo "ios_sim: $*" >&2
  fi
}

usage() {
  cat >&2 <<'EOF'
usage: tool/ios_sim.sh warmup UDID [APP | --build]
       tool/ios_sim.sh diagnose UDID LABEL [WINDOW]
       tool/ios_sim.sh guard UDID LABEL SECONDS command [args...]
EOF
  exit 2
}

# The app's pid from `launchctl list` lines ("PID STATUS LABEL"), or nothing.
app_pid() { # <file>
  awk -v id="UIKitApplication:$bundle[" \
    'index($3, id) == 1 && $1 ~ /^[0-9]+$/ { print $1; exit }' "$1"
}

diagnose() { # <udid> <label> [window]
  local udid=$1 label=$2 window=${3:-15m} dir pid
  dir="$diag_root/$(date -u +%Y%m%dT%H%M%SZ)-${label//[^A-Za-z0-9._-]/_}"
  mkdir -p "$dir"
  last_dump=$dir
  {
    echo "label: $label"
    echo "udid: $udid"
    echo "bundle: $bundle"
    echo "dump started: $(now)"
    echo "load: $(uptime)"
  } > "$dir/meta.txt"
  cap 120 xcrun simctl spawn "$udid" log show --last "$window" --info --debug \
    --style compact --predicate "$vm_predicate" > "$dir/vm-service.log" 2>&1
  cap 30 xcrun simctl spawn "$udid" launchctl list 2>&1 \
    | grep -F "$bundle" > "$dir/launchctl.txt"
  [ -s "$dir/launchctl.txt" ] \
    || echo "no $bundle in the simulator's launchctl list" > "$dir/launchctl.txt"
  pid=$(app_pid "$dir/launchctl.txt")
  echo "app pid: ${pid:-none}" >> "$dir/meta.txt"
  if [ -n "$pid" ]; then
    cap 60 sample "$pid" 5 -file "$dir/sample.txt" > /dev/null 2>&1 \
      || echo "sample $pid failed" >> "$dir/sample.txt"
  else
    echo "$bundle is not running: no sample" > "$dir/sample.txt"
  fi
  echo "dump finished: $(now)" >> "$dir/meta.txt"
  note "diagnostics in $dir"
}

# Builds the example for <udid>; prints the app's path.
build_app() { # <udid>
  local derived="$example/build/ios-derived"
  (
    cd "$example" || exit 1
    # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
    cap "$build_timeout" ${FLUTTER:-flutter} build ios --config-only --simulator --debug \
      && cd ios \
      && cap "$build_timeout" xcodebuild build -workspace Runner.xcworkspace \
        -scheme Runner -configuration Debug -destination "id=$1" \
        -derivedDataPath "$derived" -quiet
  ) >&2 || return 1
  echo "$derived/Build/Products/Debug-iphonesimulator/Runner.app"
}

# Stops warmup's log reader (its with_timeout.sh wrapper) and waits for it.
stop_reader() {
  [ -z "${stream:-}" ] || kill -TERM "$stream" 2> /dev/null
  [ -z "${stream:-}" ] || wait "$stream" 2> /dev/null
  stream=
}

warmup() { # <udid> [app | --build]
  local udid=$1 app=${2:-} build_failed= tmp stream= launched waited ready
  local launched_at
  if [ "$app" = --build ]; then
    app=$(build_app "$udid") || build_failed=1
  fi
  cap 600 xcrun simctl boot "$udid" > /dev/null 2>&1
  if ! cap 600 xcrun simctl bootstatus "$udid" -b > /dev/null; then
    warn "warm-up skipped: $udid did not finish booting"
    return 0
  fi
  if [ -n "$build_failed" ]; then
    warn "warm-up skipped: the build failed"
    return 0
  fi
  if [ -n "$app" ] && ! cap 300 xcrun simctl install "$udid" "$app"; then
    warn "warm-up skipped: could not install $app"
    return 0
  fi
  tmp=$(mktemp -d)
  # The reader is stopped on every path, also when the script is killed.
  # shellcheck disable=SC2064 # $tmp is fixed here
  trap "stop_reader; rm -rf '$tmp'" EXIT
  trap 'exit 143' TERM
  trap 'exit 130' INT
  # The reader starts before the launch, so it cannot miss the line. It is
  # started without `cap` (a function, so $! would be a subshell): $! is the
  # with_timeout.sh process, whose TERM trap stops the reader's group.
  "$tool_dir/with_timeout.sh" $((warmup_timeout + 120)) \
    xcrun simctl spawn "$udid" log stream \
    --style compact --predicate "$vm_predicate" > "$tmp/stream" 2>&1 &
  stream=$!
  for _ in $(seq "$ready_timeout"); do
    [ ! -s "$tmp/stream" ] || break
    sleep 1
  done
  # Whether the reader had attached before the launch, and when the launch
  # was (UTC, and the local time `log show` prints), for reading a timeout
  # dump (spec §10.2).
  if [ -s "$tmp/stream" ]; then ready=yes; else ready=no; fi
  launched_at="$(now) (local $(date '+%Y-%m-%d %H:%M:%S%z'))"
  note "launching $bundle at $launched_at; reader ready: $ready"
  launched=$SECONDS
  if ! cap 120 xcrun simctl launch "$udid" "$bundle" > /dev/null; then
    stop_reader
    trap - EXIT TERM INT
    rm -rf "$tmp"
    warn "warm-up skipped: could not launch $bundle"
    return 0
  fi
  while ! grep -q "$vm_line" "$tmp/stream"; do
    if [ $((SECONDS - launched)) -ge "$warmup_timeout" ]; then break; fi
    sleep 1
  done
  waited=$((SECONDS - launched))
  stop_reader
  if grep -q "$vm_line" "$tmp/stream"; then
    note "warm-up ok after ${waited}s on $udid"
  else
    warn "warm-up timeout after ${warmup_timeout}s on $udid"
    diagnose "$udid" "warm-up"
    cp "$tmp/stream" "$last_dump/warm-up-reader.log"
    {
      echo "launched: $launched_at"
      echo "reader ready: $ready"
    } >> "$last_dump/meta.txt"
  fi
  trap - EXIT TERM INT
  rm -rf "$tmp"
  cap 60 xcrun simctl terminate "$udid" "$bundle" > /dev/null 2>&1
  return 0
}

guard() { # <udid> <label> <seconds> command [args...]
  local udid=$1 label=$2 secs=$3 attempt status window
  shift 3
  # The log window covers the whole attempt: a 1200 s drive launched its
  # app about 19 minutes before the dump.
  window=$(((secs + 59) / 60 + 5))
  [ "$window" -ge 15 ] || window=15
  for attempt in 1 2; do
    status=0
    WITH_TIMEOUT_ON_STALL="$(printf '%q ' "$tool_dir/ios_sim.sh" diagnose \
      "$udid" "$label stall $attempt" "${window}m")" \
      "$tool_dir/with_timeout.sh" "$secs" "$@" || status=$?
    [ "$status" -eq 124 ] || return "$status"
    if [ "$attempt" -eq 1 ]; then
      warn "stall guard fired: $label (attempt 1 of 2); terminating the app and retrying on the same simulator"
    else
      warn "stall guard fired: $label (attempt 2 of 2); giving up"
    fi
    cap 60 xcrun simctl terminate "$udid" "$bundle" > /dev/null 2>&1
  done
  return 124
}

command=${1:-}
[ $# -eq 0 ] || shift
case "$command" in
  warmup) [ $# -ge 1 ] && [ $# -le 2 ] || usage; warmup "$@" ;;
  diagnose) [ $# -ge 2 ] && [ $# -le 3 ] || usage; diagnose "$@" ;;
  guard) [ $# -ge 4 ] || usage; guard "$@" ;;
  *) usage ;;
esac
