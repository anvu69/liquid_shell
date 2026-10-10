#!/usr/bin/env bash
# Regenerates every golden and doc image in liquid_shell/doc/images
# (spec §10.4). This is the ONLY way doc images are produced; never edit
# them by hand. Reference toolchain only (Q11): macOS + Flutter 3.44.x.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}

if [ "$(uname)" != Darwin ]; then
  echo "✗ goldens are generated on macOS only (spec Q11)" >&2
  exit 1
fi
version=$($FLUTTER --version --machine | grep -o '"frameworkVersion": *"[^"]*"' | grep -o '[0-9][0-9.]*')
case "$version" in
  3.44.*) ;;
  *)
    echo "✗ Flutter $version; goldens need 3.44.x (spec Q11)" >&2
    exit 1
    ;;
esac

$FLUTTER test --tags golden --update-goldens
# The liquid tier needs Impeller's shader filters (spec 2026-10-10 §10.3).
$FLUTTER test --enable-impeller --tags liquid_golden --update-goldens
# Lossless: the pixels stay identical, only the PNG encoding shrinks.
$DART run ../../tool/compress_pngs.dart ../doc/images
echo "✓ goldens and doc images updated in liquid_shell/doc/images (Flutter $version)"
