#!/usr/bin/env bash
# Stall guard: run a command, and stop it with its whole process group if it
# is still running after a deadline.
#
#   tool/with_timeout.sh SECONDS command [args...]
#
# Exit status: the command's own, or 124 when the deadline stopped it.
# macOS has no `timeout`, and killing only flutter would leave its simctl or
# xcodebuild children behind, so the command runs in its own process group.
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

deadline=$((SECONDS + secs))
while kill -0 "$pid" 2>/dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "✗ stalled: still running after ${secs}s: $*" >&2
    kill -TERM -- "-$pid" 2>/dev/null
    sleep 5
    kill -KILL -- "-$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    exit 124
  fi
  sleep 1
done
wait "$pid"
