#!/usr/bin/env bash
# Glass seam gate (spec 2026-10-10 §8, owner decision L3): every glass
# surface goes through LiquidGlass, so no backdrop filter or image filter
# may appear in liquid_shell/lib outside lib/src/glass/. BackdropGroup
# reads nothing and is allowed. `make provenance` runs this.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern='BackdropFilter|ImageFilter\.(blur|shader|compose)'
if git grep --untracked -n -I -E "$pattern" -- 'liquid_shell/lib' ':!liquid_shell/lib/src/glass/'; then
  echo "✗ glass seam: draw glass through LiquidGlass (spec 2026-10-10 §8)" >&2
  exit 1
fi
echo "✓ glass seam clean"
