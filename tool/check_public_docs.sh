#!/usr/bin/env bash
# Public docs gate (spec docs/specs/2026-10-21-release-docs-design.md §3.5).
# Fails on this project's internal references where a pub.dev reader sees
# them: spec sections, Plane ids, phase codes (P2, P3b, P3b-2) and
# brainstorm questions in the dartdoc of the four packages, their READMEs
# and liquid_shell/doc. CHANGELOGs, plain // comments and native sources
# may keep them.
#
# Scans tracked files plus untracked files that .gitignore does not ignore.
# POSIX ERE only (no \b), so BSD and GNU git grep agree.
set -euo pipefail
cd "$(dirname "$0")/.."

w='[^A-Za-z0-9_]'
refs="§|(^|$w)VK-[0-9]+|(^|$w)P[0-9]+[a-z]?(-[0-9]+)?($w|\$)|\(Q[0-9]+\)"
packages=(liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android)
dart=()
docs=()
for p in "${packages[@]}"; do
  dart+=("$p/lib/*.dart")
  docs+=("$p/README.md" "$p/doc/*.md" "$p/example/README.md")
done
status=0

if git grep --untracked -n -I -E "^[[:space:]]*///.*($refs)" -- "${dart[@]}" ':!*.g.dart'; then
  status=1
fi
if git grep --untracked -n -I -E "$refs" -- "${docs[@]}"; then
  status=1
fi

if [ "$status" -ne 0 ]; then
  echo "✗ public docs: an internal reference (§, VK-, P<n>, (Q<n>)) is visible on pub.dev. Say what it means instead." >&2
  exit 1
fi
echo "✓ public docs clean"
