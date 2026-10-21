#!/usr/bin/env bash
# Provenance gate (spec §9). Fails if any file outside docs/ names the source
# app, its i18n/DI/theme symbols, or the project whose test helpers must be
# rewritten. go_router is allowed in Markdown only, because
# liquid_shell/doc/router_integration.md teaches that wiring (spec §12.2).
# go_router is also allowed in liquid_shell/example_go_router, the app the
# router doc is built from (VK-701). Files that only name that app as
# example_go_router (the workspace list, the Makefile) pass, because the
# pattern does not match go_router after an underscore.
#
# Scans tracked files plus untracked files that .gitignore does not ignore,
# so generated build files with local absolute paths never trip it.
set -euo pipefail
cd "$(dirname "$0")/.."

banned='vankhan|Văn Khấn|calculator_promax|LocaleKeys|easy_localization|AppColors|AppGlassColors'
# GetIt is matched case-sensitively as a whole word, so widgetItem and
# budgetItems do not trip it.
banned_word='GetIt'
outside_docs=(-- . ':!docs/' ':!tool/check_provenance.sh' ':!tool/test/check_provenance_test.dart')
status=0

if git grep --untracked -n -I -i -E "$banned" "${outside_docs[@]}"; then
  status=1
fi
if git grep --untracked -n -I -w "$banned_word" "${outside_docs[@]}"; then
  status=1
fi
if git grep --untracked -n -I -E '(^|[^_])go_router' "${outside_docs[@]}" ':!*.md' ':!liquid_shell/example_go_router/'; then
  status=1
fi

if [ "$status" -ne 0 ]; then
  echo "✗ provenance: banned name found (spec §9). Remove it." >&2
  exit 1
fi
echo "✓ provenance clean"
