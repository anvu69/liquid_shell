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
#   tool/ios_sim.sh build UDID ACTION [xcodebuild args...]
#
# warmup    Boots UDID and waits for it (simctl boot, bootstatus -b),
#           installs APP when given, launches the example once and waits
#           until it logs "The Dart VM service is listening on" (at most
#           IOS_WARMUP_TIMEOUT seconds), then terminates it. --build first
#           builds the example for UDID (`build UDID build`, below) and
#           installs that. It never fails: a timeout is diagnosed, any
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
#           stalled 13 times in 38). A run whose build failed with VK-627's
#           signature (below) also runs once more. The command runs at most
#           twice, whatever the reason. Any other status is the command's
#           own and is never retried: a test failure never is.
# build     Builds the example for UDID: `flutter build ios --config-only
#           --simulator --debug`, then `xcodebuild ACTION` (build or
#           build-for-testing) of Runner.xcworkspace into
#           liquid_shell/example/build/ios-derived, each step capped at
#           IOS_BUILD_TIMEOUT. A build that failed with VK-627's signature
#           runs once more, both steps. Its output goes to stderr.
#
# VK-627 (spec docs/specs/2026-10-17-ios-build-retry-design.md): Flutter
# writes its generated FlutterGeneratedPluginSwiftPackage at .iOS("13.0") on
# every iOS build, and raises it to the app's 15.0 only when `xcodebuild
# -showBuildSettings` answers within 60 s (one retry). Two timeouts skip the
# raise without a word, and Xcode 26's Target Integrity check then fails the
# build: "... requires minimum platform version 15.0 for the iOS platform,
# but this target supports 13.0". A failed run whose output has that phrase
# runs once more, in a fresh flutter process.
#
# IOS_APP_BUNDLE_ID   the app (default vn.lasoai.liquidShellExample)
# IOS_WARMUP_TIMEOUT  seconds the warm-up waits for the VM service line
#                     (default 180; passing first launches after a boot
#                     logged their first line within 85 s on CI)
# IOS_WARMUP_READY_TIMEOUT
#                     seconds the warm-up waits for its log reader to
#                     attach before it launches (default 30)
# IOS_BUILD_TIMEOUT   seconds each step of build (and --build) may take
#                     (default 900)
# IOS_DIAG_DIR        diagnostics root
#                     (default liquid_shell/example/build/ios-diagnostics)
# FLUTTER             flutter command for build (default: flutter)
set -uo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
example=$(cd "$tool_dir/../liquid_shell/example" && pwd)
derived="$example/build/ios-derived"
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
# VK-627: the phrase of Xcode's Target Integrity error, as xcodebuild and
# flutter print it, and the note that names the retry.
vk627_signature='requires minimum platform version'
vk627_note='VK-627: Flutter skipped the deployment-target raise (xcodebuild -showBuildSettings timed out)'
# Seconds the output copy may take to drain once its command has ended.
copy_drain=10

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
       tool/ios_sim.sh build UDID ACTION [xcodebuild args...]
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

# Runs a command with its stdout and stderr shown on stdout and copied to
# <log> (emptied first); returns the command's status. The copy reads a
# FIFO in the background rather than a pipe the script waits for: a
# process that outlives the command and still holds its output (the
# runners end iOS jobs with orphaned adb, ibtoold and DTServiceHub) must
# not hold the script. Once the command has ended, the copy gets
# copy_drain seconds to finish, then it is stopped.
logged() { # <log> command [args...]
  local log=$1 fifo="$1.fifo" copier status=0
  shift
  : > "$log"
  rm -f "$fifo"
  mkfifo "$fifo" || {
    "$@"
    return
  }
  tee -a "$log" < "$fifo" &
  copier=$!
  "$@" > "$fifo" 2>&1 || status=$?
  for _ in $(seq "$copy_drain"); do
    kill -0 "$copier" 2> /dev/null || break
    sleep 1
  done
  kill "$copier" 2> /dev/null
  wait "$copier" 2> /dev/null
  rm -f "$fifo"
  return "$status"
}

# Whether attempt <attempt> of <label>, which ended with <status> and
# wrote <log>, is VK-627's build failure and gets one more run. Only a
# failed run (not 0, not a stall's 124) whose output has the signature
# counts, so a test failure is never retried.
build_again() { # <label> <attempt> <status> <log>
  [ "$3" -ne 0 ] && [ "$3" -ne 124 ] && grep -qF "$vk627_signature" "$4" \
    || return 1
  if [ "$2" -eq 1 ]; then
    warn "$vk627_note: $1 (attempt 1 of 2); building again once"
    return 0
  fi
  warn "$vk627_note: $1 (attempt 2 of 2); giving up"
  return 1
}

# One run of build's two steps.
build_once() { # <udid> <action> [xcodebuild args...]
  local udid=$1 action=$2
  shift 2
  (
    cd "$example" || exit 1
    # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
    cap "$build_timeout" ${FLUTTER:-flutter} build ios --config-only --simulator --debug \
      && cd ios \
      && cap "$build_timeout" xcodebuild "$action" -workspace Runner.xcworkspace \
        -scheme Runner -destination "id=$udid" -derivedDataPath "$derived" \
        "$@" -quiet
  )
}

build() { # <udid> <action> [xcodebuild args...]
  local label="$2 on $1" attempt status tmp
  tmp=$(mktemp -d)
  for attempt in 1 2; do
    status=0
    logged "$tmp/output" build_once "$@" >&2 || status=$?
    build_again "$label" "$attempt" "$status" "$tmp/output" || break
  done
  rm -rf "$tmp"
  return "$status"
}

# Builds the example for <udid>; prints the app's path.
build_app() { # <udid>
  build "$1" build -configuration Debug || return 1
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
  local udid=$1 label=$2 secs=$3 attempt status window tmp
  shift 3
  # The log window covers the whole attempt: a 1200 s drive launched its
  # app about 19 minutes before the dump.
  window=$(((secs + 59) / 60 + 5))
  [ "$window" -ge 15 ] || window=15
  tmp=$(mktemp -d)
  # One retry in all: a stall's or VK-627's, so the job caps (two drive
  # caps per drive) still hold.
  for attempt in 1 2; do
    status=0
    logged "$tmp/output" env WITH_TIMEOUT_ON_STALL="$(printf '%q ' \
      "$tool_dir/ios_sim.sh" diagnose "$udid" "$label stall $attempt" \
      "${window}m")" "$tool_dir/with_timeout.sh" "$secs" "$@" || status=$?
    if [ "$status" -ne 124 ]; then
      build_again "$label" "$attempt" "$status" "$tmp/output" || break
      continue
    fi
    if [ "$attempt" -eq 1 ]; then
      warn "stall guard fired: $label (attempt 1 of 2); terminating the app and retrying on the same simulator"
    else
      warn "stall guard fired: $label (attempt 2 of 2); giving up"
    fi
    cap 60 xcrun simctl terminate "$udid" "$bundle" > /dev/null 2>&1
  done
  rm -rf "$tmp"
  return "$status"
}

command=${1:-}
[ $# -eq 0 ] || shift
case "$command" in
  warmup) [ $# -ge 1 ] && [ $# -le 2 ] || usage; warmup "$@" ;;
  diagnose) [ $# -ge 2 ] && [ $# -le 3 ] || usage; diagnose "$@" ;;
  guard) [ $# -ge 4 ] || usage; guard "$@" ;;
  build) [ $# -ge 2 ] || usage; build "$@" ;;
  *) usage ;;
esac
