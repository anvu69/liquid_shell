#!/usr/bin/env bash
# Stall guard: run a command, and stop it with its whole process group if it
# is still running after a deadline.
#
#   tool/with_timeout.sh SECONDS command [args...]
#
# Exit status: the command's own, 124 when the deadline stopped it, or
# 128 + the signal number when SIGINT or SIGTERM stopped the wrapper.
# macOS has no `timeout`, and killing only flutter would leave its simctl or
# xcodebuild children behind, so the command runs in its own process group.
# That group gets no terminal or CI signal of its own: SIGINT (Ctrl-C, a CI
# cancel) and SIGTERM to the wrapper are passed on to it.
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 SECONDS command [args...]" >&2
  exit 2
fi
secs=$1
shift

set -m # background jobs get their own process group
"$@" &
pid=$!
set +m

# Stops the whole group: SIGNAL first, SIGKILL after a 5 s grace, then
# exits with CODE.
stop() {
  local signal=$1 code=$2 i
  trap - INT TERM
  kill "-$signal" -- "-$pid" 2>/dev/null
  for i in 1 2 3 4 5; do
    kill -0 -- "-$pid" 2>/dev/null || break
    sleep 1
  done
  kill -KILL -- "-$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  exit "$code"
}
trap 'stop INT 130' INT
trap 'stop TERM 143' TERM

deadline=$((SECONDS + secs))
while kill -0 "$pid" 2>/dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "✗ stalled: still running after ${secs}s: $*" >&2
    stop TERM 124
  fi
  sleep 1
done
wait "$pid"
