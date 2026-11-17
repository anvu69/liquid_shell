#!/usr/bin/env bash
# Material seam gate (spec docs/specs/2026-11-18-material-seam-design.md):
# Flutter 3.50 deprecates package:flutter/material.dart and cupertino.dart,
# so liquid_shell's lib/ and test/ reach the SDK's Material types through
# lib/src/material_sdk.dart (tests: test/helpers/cupertino_sdk.dart for
# Cupertino). Only import and export directives count; comments and dartdoc
# snippets may name the library. The example apps keep the real import.
# `make provenance` runs this, so it blocks on the 3.44 floor.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern="^[[:space:]]*(import|export)[[:space:]]+['\"]package:flutter/(material|cupertino)\\.dart['\"]"
if git grep --untracked -n -I -E "$pattern" -- 'liquid_shell/lib' 'liquid_shell/test'; then
  echo "✗ material seam: import package:liquid_shell/src/material_sdk.dart instead" >&2
  exit 1
fi
echo "✓ material seam clean"
