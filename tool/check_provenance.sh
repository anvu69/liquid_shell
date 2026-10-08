#!/usr/bin/env bash
# Provenance gate (spec §9). Fails if any file outside docs/ names the source
# app, its i18n/DI/theme symbols, or the project whose test helpers must be
# rewritten. go_router is allowed in Markdown only, because
# liquid_shell/doc/router_integration.md teaches that wiring (spec §12.2).
#
# Scans tracked files plus untracked files that .gitignore does not ignore,
# so generated build files with local absolute paths never trip it.
set -euo pipefail
cd "$(dirname "$0")/.."

banned='vankhan|Văn Khấn|calculator_promax|LocaleKeys|easy_localization|AppColors|AppGlassColors|GetIt'
outside_docs=(-- . ':!docs/' ':!tool/check_provenance.sh')
status=0

if git grep --untracked -n -I -i -E "$banned" "${outside_docs[@]}"; then
  status=1
fi
if git grep --untracked -n -I -E 'go_router' "${outside_docs[@]}" ':!*.md'; then
  status=1
fi

if [ "$status" -ne 0 ]; then
  echo "✗ provenance: banned name found (spec §9). Remove it." >&2
  exit 1
fi
echo "✓ provenance clean"
