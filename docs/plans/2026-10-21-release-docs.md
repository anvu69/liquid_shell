# VK-701 Release Docs and Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make everything a pub.dev reader sees of the four liquid_shell packages, other than code, ready for the first release (spec `docs/specs/2026-10-21-release-docs-design.md`).

**Architecture:** Docs, packaging and metadata edits; one new gate script (`tool/check_public_docs.sh`) wired like `tool/check_provenance.sh`; one new unpublished workspace app (`liquid_shell/example_go_router/`) whose regions feed `doc/router_integration.md` through the existing `make snippets` check.

**Tech Stack:** Flutter 3.44.x (fvm), Dart workspace, bash + `git grep`, `package:test`, `flutter_test`, `go_router` ^18.1.1.

## Global Constraints

- Branch `VK-701-release-docs`; fetch `origin/main` before every task (`git fetch origin && git rebase origin/main`); PRs #19 and #20 may land meanwhile.
- No `lib/` change other than dartdoc (`///`) text. No publish command other than `dart pub publish --dry-run` (`make publish-check`).
- Commits `<type>(<scope>): <summary> (VK-701)`, message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `bash .githooks/pre-commit` before every commit; never `--no-verify`, never change git config.
- All repo paths are `package:` imports in Dart; the example lints are `very_good_analysis` 10.3.0.
- Internal references forbidden in public docs (§3.5): `§`, `VK-<n>`, `P<n>[a-z][-<n>]`, `(Q<n>)`.
- Simulators: none needed by this plan.

---

### Task 1: Packaging

**Files:**
- Modify: `liquid_shell/.pubignore`
- Modify: `liquid_shell/pubspec.yaml` (add `screenshots:` after `topics:`)

**Interfaces:**
- Produces: the archive rules Task 7 extends with `example_go_router/`.

- [ ] **Step 1: Record the archive before**

Run: `make publish-check > /tmp/vk701-before.txt 2>&1; grep -cE '^\s*\|--|├|└' /tmp/vk701-before.txt; grep -E 'test/|integration_test|hero_iphone|Total compressed' /tmp/vk701-before.txt | head -40`
Expected: listings with `test/` and `example/test/…` entries; 0 warnings per package. Keep the file for the task report.

- [ ] **Step 2: Rewrite `liquid_shell/.pubignore`**

Replace the whole file with (if PR #19 landed, its three `segment_*` lines are covered by `test/` and are dropped):

```
# Large doc images stay in the repo; pub.dev resolves README images through
# `repository`. The one screenshot pub.dev shows stays in the archive.
doc/images/*
!doc/images/hero_iphone_light.png
# Tests need files outside the package (tool/, docs/qa/): not shipped.
test/
example/test/
example/integration_test/
```

`doc/images/*` (not `doc/images/`) so the `!` line can re-include a file: a re-include cannot reach into an excluded directory.

- [ ] **Step 3: Add the screenshot to `liquid_shell/pubspec.yaml`**

After the `topics:` line:

```yaml
screenshots:
  - description: The glass tab bar on an iPhone, light mode.
    path: doc/images/hero_iphone_light.png
```

- [ ] **Step 4: Check the archive after**

Run: `make publish-check > /tmp/vk701-after.txt 2>&1; grep -E 'test/|integration_test|hero_iphone|warning' /tmp/vk701-after.txt`
Expected: no `test/` or `integration_test` line under `liquid_shell`; `doc/images/hero_iphone_light.png` listed; "Package has 0 warnings." for all four. If the screenshot is missing, use the fallback: `mkdir -p liquid_shell/screenshots && cp liquid_shell/doc/images/hero_iphone_light.png liquid_shell/screenshots/`, drop the `!` line, point `path:` at `screenshots/hero_iphone_light.png`, rerun, and say so in the report.

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/.pubignore liquid_shell/pubspec.yaml
git commit -m "chore(shell): the archive ships no tests and one screenshot (VK-701)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Metadata and the SwiftPM sentence (I5)

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios.podspec:11`
- Modify: `liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj` (lines 578, 778, 802)
- Modify: `liquid_shell/example/pubspec.yaml`
- Modify: `liquid_shell_ios/README.md:13`
- Modify: `liquid_shell_ios/CHANGELOG.md` (top section `## 0.1.0-dev.8`)
- Modify: `docs/specs/2026-10-08-p1-foundation-design.md` (after the "P6 release checklist, Swift Package Manager" paragraph, line 1059)

- [ ] **Step 1: Podspec author**

In `liquid_shell_ios/ios/liquid_shell_ios.podspec` replace
`  s.author           = { 'lasoai.vn' => 'lasotuviai@gmail.com' }`
with
`  s.author           = { 'lasoai.vn' => 'https://lasoai.vn' }`

- [ ] **Step 2: Remove the development team**

Run: `sed -i '' '/DEVELOPMENT_TEAM = W4VK38D72T;/d' liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj && grep -c DEVELOPMENT_TEAM liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj`
Expected: `0`.

- [ ] **Step 3: Example constraints**

In `liquid_shell/example/pubspec.yaml` change the three `^0.1.0-dev.7` constraints (`liquid_shell`, `liquid_shell_ios`, `liquid_shell_platform_interface`) to `^0.1.0-dev.8`. Run `make get`; expected: resolves.

- [ ] **Step 4: The iOS README sentence**

In `liquid_shell_ios/README.md` replace the line
`CocoaPods is the tested path; a Swift Package manifest is included but unverified until Flutter's SwiftPM build works on Xcode 27.`
with
`Ships for CocoaPods and Swift Package Manager; CI builds the example with Swift Package Manager.`

- [ ] **Step 5: CHANGELOG line**

In `liquid_shell_ios/CHANGELOG.md`, first bullet under `## 0.1.0-dev.8`:

```md
- Swift Package Manager: CI builds the example with it (Flutter 3.44 on
  Xcode 27), so the README no longer calls it unverified.
```

- [ ] **Step 6: Close the P1 gate**

In `docs/specs/2026-10-08-p1-foundation-design.md`, a new paragraph right after the one that starts `**P6 release checklist, Swift Package Manager`:

```md
**Closed 2026-10-21 (VK-701).** CI builds the example with Swift Package Manager: run 39095489319 (main, `cd6504c`), job integration-ios-native (iPhone, iOS 26), logs "Adding Swift Package Manager integration…" and "All plugins found for ios are Swift Packages". `Package.swift` needed no change. The README sentence is replaced as above.
```

- [ ] **Step 7: Check and commit**

Run: `make analyze && make publish-check 2>&1 | grep -E 'warning'`
Expected: analyze "No issues found!"; "Package has 0 warnings." ×4.

```bash
bash .githooks/pre-commit
git add liquid_shell_ios/ios/liquid_shell_ios.podspec liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj liquid_shell/example/pubspec.yaml liquid_shell_ios/README.md liquid_shell_ios/CHANGELOG.md docs/specs/2026-10-08-p1-foundation-design.md
git commit -m "docs(ios): Swift Package Manager is built on CI; metadata for release (VK-701)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The `liquid_shell` README: install, platforms, roadmap, known issues

**Files:**
- Modify: `liquid_shell/README.md` (Install `:64-70`, platform table `:58-63`, Limitations `:1399-1400`, Roadmap `:1475-1490`, new Known issues before `## More`)
- Modify: `liquid_shell/CHANGELOG.md` (top section)

- [ ] **Step 1: Install**

Replace the body of `## Install` (from the `sh` block to "Requires Flutter 3.44 or later.") with:

````md
```sh
flutter pub add liquid_shell
```

- Flutter 3.44 or later.
- iOS 15.0 or later: `platform :ios, '15.0'` in `ios/Podfile`, and
  `IPHONEOS_DEPLOYMENT_TARGET = 15.0` for the Runner target.
- Android minSdk 24.
- Native iOS 26 chrome is opt-in: add `LiquidShellNativeChrome` to
  `Info.plist` (see [Native iOS chrome](#native-ios-chrome)).
````

- [ ] **Step 2: Platforms**

Right above the line `| Platform | Look | Signals |` insert:

```md
iOS and Android are supported and tested on CI. macOS, web, Windows and
Linux are not tested: the shell has no native code there and draws the
glass shown below.

```

and change the two rows' first cells: `| macOS |` → `| macOS (not tested) |`, `| Web, Windows, Linux |` → `| Web, Windows, Linux (not tested) |`.

- [ ] **Step 3: Limitations line**

Replace `- **Native navigation bars are on the search tab only** (P3b-2 brings them` / `  to every tab).` with `- **Native navigation bars are on the search tab only** (planned for` / `  every tab, see [Roadmap](#roadmap)).` and keep the rest of that bullet.

- [ ] **Step 4: Known issues**

Insert before `## More`:

```md
## Known issues

- **The first status-bar tap may not scroll to the top** while the iOS
  accessibility bridge is on (VoiceOver, Switch Control, Speak Screen;
  always in the simulator): Flutter's accessibility scroll view takes the
  tap. Tap again. Upstream:
  [flutter/flutter#191565](https://github.com/flutter/flutter/issues/191565).
- **A tab revealed a few frames after it is selected** (a custom
  `navigatorContainerBuilder` that animates the switch): system back may
  not find that tab's navigator.
- **Native navigation bars are on the search tab only** (see
  [Limitations](#limitations)).
```

If PR #20 (landscape keyboard inset) is not merged when this task runs, add a fourth bullet: `- **iPhone in landscape with the keyboard up and native chrome:** the bottom inset is 0, so the search field covers the first result.`

- [ ] **Step 5: Roadmap**

Replace everything between `## Roadmap` and `## License` with:

```md
## Roadmap

0.1.0 is the first release on pub.dev: the adaptive shell, the liquid,
frosted and solid tiers, opt-in native iOS 26 chrome, native alerts and
action sheets, the search tab with scopes, and `LiquidSegmentedControl`.

Planned:

- Native navigation bars on every tab (today: the search tab only).
- Share sheet, haptics, date picker and text fields in native alerts.
- A go_router adapter (a `StatefulShellRoute` builder, route-driven hide
  chrome). Until then, see
  [doc/router_integration.md](doc/router_integration.md).

```

- [ ] **Step 6: CHANGELOG**

In `liquid_shell/CHANGELOG.md`, first bullet under the top section:

```md
- The package archive no longer includes tests (they read files outside
  the package). The README states the supported platforms (iOS and
  Android), the install requirements and the known issues.
```

- [ ] **Step 7: Check and commit**

Run: `make snippets && grep -nE 'P3b|VK-|\*\*P[0-9]' liquid_shell/README.md`
Expected: snippets "✓"; no hit between `## Limitations` and `## License` (hits elsewhere are Task 5's).

```bash
bash .githooks/pre-commit
git add liquid_shell/README.md liquid_shell/CHANGELOG.md
git commit -m "docs(shell): README install, platforms, roadmap and known issues (VK-701)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The public docs gate (script and test, not yet wired)

**Files:**
- Create: `tool/test/check_public_docs_test.dart`
- Create: `tool/check_public_docs.sh` (mode 755)

**Interfaces:**
- Produces: `tool/check_public_docs.sh`, exit 0 clean / 1 with `file:line` hits on stdout and a `✗` line on stderr. Task 5 wires it into `make public-docs`.

- [ ] **Step 1: Write the failing test**

`tool/test/check_public_docs_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory repo;
  final script = File('tool/check_public_docs.sh').absolute;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('public_docs_');
    Directory('${repo.path}/tool').createSync();
    script.copySync('${repo.path}/tool/check_public_docs.sh');
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  int run(String path, String content) {
    File('${repo.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return Process.runSync(
      'bash',
      ['tool/check_public_docs.sh'],
      workingDirectory: repo.path,
    ).exitCode;
  }

  const lib = 'liquid_shell/lib/src/probe.dart';

  test('a clean dartdoc passes', () {
    expect(run(lib, '/// Shows the tab bar.\nvoid f() {}\n'), 0);
  });

  for (final ref in ['(spec §7.4)', 'VK-572', 'P3b-2', 'P2', '(Q9)']) {
    test('a dartdoc with "$ref" fails', () {
      expect(run(lib, '/// The rule $ref.\nvoid f() {}\n'), 1);
    });
  }

  test('a plain // comment may keep a reference', () {
    expect(run(lib, '// VK-572: why.\nvoid f() {}\n'), 0);
  });

  test('p90, iPhone 17 Pro, API 31 and PNG pass', () {
    expect(
      run('liquid_shell/README.md', 'raster p90, iPhone 17 Pro, API 31+, PNG\n'),
      0,
    );
  });

  test('a README reference fails, in any package', () {
    expect(run('liquid_shell_ios/README.md', 'See P3b.\n'), 1);
  });

  test('a doc page reference fails', () {
    expect(run('liquid_shell/doc/search.md', 'As spec §7 says.\n'), 1);
  });

  test('a CHANGELOG may keep references', () {
    expect(run('liquid_shell/CHANGELOG.md', '- Fix (VK-572).\n'), 0);
  });

  test('generated code is skipped', () {
    expect(run('liquid_shell_ios/lib/src/api.g.dart', '/// VK-1\n'), 0);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `fvm dart test tool/test/check_public_docs_test.dart`
Expected: FAIL; `PathNotFoundException` on `tool/check_public_docs.sh` (copySync).

- [ ] **Step 3: Write the script**

`tool/check_public_docs.sh`, then `chmod 755 tool/check_public_docs.sh`:

```bash
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
  docs+=("$p/README.md" "$p/doc/*.md")
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `fvm dart test tool/test/check_public_docs_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 5: The red on main (evidence)**

Run: `tool/check_public_docs.sh | wc -l; tool/check_public_docs.sh | cut -d: -f1 | sort | uniq -c | sort -rn | head -15`
Expected: exit 1; about 285 lines (spec §3.5: 263 dartdoc + 22 markdown, less what Task 3 removed). Paste the count and the per-file top 15 into the task report.

- [ ] **Step 6: Commit (not wired: the tree is still red for the gate)**

```bash
bash .githooks/pre-commit
git add tool/check_public_docs.sh tool/test/check_public_docs_test.dart
git commit -m "test(tool): a gate for internal references in public docs (VK-701)

Not wired yet: the next commit cleans the docs and adds it to verify.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Clean the public docs and wire the gate

**Files:**
- Modify: the files `tool/check_public_docs.sh` lists (dartdoc in `liquid_shell/lib/**`, `liquid_shell_ios/lib/**`, `liquid_shell_platform_interface/lib/**`; `liquid_shell/README.md`, `liquid_shell/doc/*.md`)
- Modify: `Makefile` (`.PHONY`, new `public-docs` target after `provenance`, `verify`)
- Modify: `.githooks/pre-commit` (target loop)
- Modify: `.github/workflows/ci.yaml` (after the `make provenance` step, line 52-53)

**Interfaces:**
- Consumes: `tool/check_public_docs.sh` (Task 4).

- [ ] **Step 1: Clean, one package at a time, comment text only**

Rule: remove the reference or say what it stands for; never replace a code with another code. Examples:
- `/// The one-way rule (spec §7.4): …` → `/// The one-way rule: …`
- `/// … (spec VK-550 §11).` → `/// ….` (drop the parenthesis)
- `/// Q2: the kept query …` / `(Q2)` → drop the tag, keep the sentence.
- `/// P3b-2 brings native navigation bars …` → `/// A later release brings native navigation bars …`
- A sentence that only makes sense with the reference (`/// See spec §14.`) is deleted.

Work order: `liquid_shell_platform_interface` (3), `liquid_shell_ios` (6), then `liquid_shell/lib` by directory, then `liquid_shell/README.md` and `liquid_shell/doc/*.md`. After each directory: `tool/check_public_docs.sh | grep <dir> | wc -l` must reach 0.

- [ ] **Step 2: Prove no code changed**

Run:

```bash
git diff -U0 -- '*.dart' | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-][[:space:]]*///' | wc -l
```

Expected: `0` (every changed Dart line is a `///` line; a deleted whole `///` line counts as one too). `make format-check analyze` green (a dartdoc reflow may need `make format`).

- [ ] **Step 3: The gate is green**

Run: `tool/check_public_docs.sh`
Expected: `✓ public docs clean`, exit 0.

- [ ] **Step 4: Wire it**

`Makefile`: add `public-docs` to the `.PHONY` list after `provenance`; after the `provenance` target add

```make
public-docs: ## Fail on internal references (§, VK-, phase codes) in dartdoc, READMEs and doc/
	tool/check_public_docs.sh
```

and change the `verify` line to

```make
verify: format-check analyze provenance public-docs pigeon-check test test-impeller coverage goldens snippets ## Everything CI's blocking jobs run
```

`.githooks/pre-commit`: `for target in format-check analyze provenance test; do` → `for target in format-check analyze provenance public-docs test; do`.

`.github/workflows/ci.yaml`, after the two `make provenance` lines:

```yaml
      - run: make public-docs
        if: ${{ success() || (failure() && matrix.experimental) }}
```

- [ ] **Step 5: Snippets and tests still green**

Run: `make snippets test`
Expected: snippets ✓ (README snippets come from `#docregion`s in `example/lib`, whose `///` lines may have changed: if `make snippets` reports a drift, run `fvm dart run tool/check_readme_snippets.dart --fix` and include the README change); tests green.

- [ ] **Step 6: Commit**

```bash
bash .githooks/pre-commit
git add -A liquid_shell liquid_shell_ios liquid_shell_platform_interface Makefile .githooks/pre-commit .github/workflows/ci.yaml
git commit -m "docs(shell): no internal references in public docs; make public-docs gates it (VK-701)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

The hook now runs `public-docs`: it must pass on this commit.

---

### Task 6: `liquid_shell/example/README.md`

**Files:**
- Create: `liquid_shell/example/README.md`

- [ ] **Step 1: Write it**

````md
# liquid_shell example

One screen per case of the
[liquid_shell README](https://github.com/anvu69/liquid_shell/blob/main/liquid_shell/README.md#cases).
Each case is a small file under `lib/cases/`; the README's code is copied
from those files and checked against them on CI.

## Run

```sh
cd liquid_shell/example
flutter run
```

- The liquid tier needs Impeller: the default on iOS and Android 10+.
- Native iOS 26 chrome needs an iOS 26 device or simulator; elsewhere the
  same cases draw the Flutter chrome.

## Cases

| Case | Shows |
|---|---|
| Basic 3 tabs | The smallest `LiquidShell` |
| Badges | `count(3)`, `count(120)` → 99+, `dot()` |
| Sidebar-only destinations | Hidden on phones, with a fallback |
| Sidebar header and footer | App title and profile; natively, the profile only |
| Trailing action | Compose: opens a page above the shell |
| Search tab | Field, scopes, recents, live results |
| Segmented control | `LiquidSegmentedControl` at the native frames |
| "Discard changes?" guard | `beforeDestinationChange` |
| Alerts and action sheets | Native on iOS 26, Flutter glass elsewhere |
| Hide the chrome | `LiquidHideChrome` on a page inside the branch |
| Custom chrome | Wrap the bar, replace the sidebar |
| Custom theme | `LiquidGlassTheme` extension, light and dark |
| Forced tier | liquid / frosted / solid |
| Form factors | iPhone, iPad portrait and landscape, Android |
| Narrow width | 5 tabs + trailing in a 320pt shell |
| Standalone widgets | `LiquidTabBar` and `LiquidSidebar` in your own `Scaffold` |
| Native chrome | Native footer, sidebar-only tab and guard on iOS 26 |

## go_router

[`../example_go_router`](https://github.com/anvu69/liquid_shell/tree/main/liquid_shell/example_go_router)
wires the shell to go_router's `StatefulShellRoute`; it is the code of
[doc/router_integration.md](https://github.com/anvu69/liquid_shell/blob/main/liquid_shell/doc/router_integration.md#go_router).
````

- [ ] **Step 2: Check and commit**

Run: `tool/check_public_docs.sh && make publish-check 2>&1 | grep -E 'example/README|warning'`
Expected: gate clean; `example/README.md` listed in the `liquid_shell` archive; 0 warnings.

```bash
bash .githooks/pre-commit
git add liquid_shell/example/README.md
git commit -m "docs(example): a README for the Example tab on pub.dev (VK-701)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The go_router example app and the router doc

**Files:**
- Create: `liquid_shell/example_go_router/pubspec.yaml`
- Create: `liquid_shell/example_go_router/analysis_options.yaml`
- Create: `liquid_shell/example_go_router/lib/main.dart`
- Create: `liquid_shell/example_go_router/lib/go_router_app.dart`
- Create: `liquid_shell/example_go_router/test/router_test.dart`
- Modify: `pubspec.yaml` (root `workspace:`)
- Modify: `Makefile` (`EXAMPLE` users: `analyze`, `test`)
- Modify: `tool/check_readme_snippets.dart:226`
- Modify: `tool/check_provenance.sh` (the `go_router` rule)
- Modify: `liquid_shell/.pubignore`
- Modify: `liquid_shell/doc/router_integration.md` (section `## go_router (until the adapter ships)`)
- Modify: `docs/specs/2026-10-08-p1-foundation-design.md` (§9 provenance, §12.2)

**Interfaces:**
- Produces: `class GoRouterApp extends StatefulWidget` (`const GoRouterApp({super.key})`) in `package:liquid_shell_example_go_router/go_router_app.dart`; regions `shell`, `branches`, `above` in `go_router_app.dart`.

- [ ] **Step 1: The package**

`liquid_shell/example_go_router/pubspec.yaml`:

```yaml
name: liquid_shell_example_go_router
description: liquid_shell under go_router's StatefulShellRoute; the code of doc/router_integration.md.
publish_to: none
version: 1.0.0+1
resolution: workspace

environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  go_router: ^18.1.1
  liquid_shell: ^0.1.0-dev.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.3.0

flutter:
  uses-material-design: true
```

`liquid_shell/example_go_router/analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

Root `pubspec.yaml`, `workspace:` gains `  - liquid_shell/example_go_router` after `  - liquid_shell/example`.

`liquid_shell/.pubignore` gains:

```
# The go_router example is a workspace app, not part of the package.
example_go_router/
```

Run: `make get`
Expected: resolves. If `go_router ^18.1.1` needs a newer SDK than 3.44.6, take the newest `go_router` that resolves (`fvm flutter pub add go_router -C liquid_shell/example_go_router` shows it), use it in the pubspec and the spec, and record it in the report.

- [ ] **Step 2: A stub and the failing tests**

`liquid_shell/example_go_router/lib/go_router_app.dart` (stub):

```dart
import 'package:flutter/material.dart';

/// liquid_shell under go_router (stub).
class GoRouterApp extends StatelessWidget {
  /// Creates the app.
  const GoRouterApp({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

`liquid_shell/example_go_router/test/router_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example_go_router/go_router_app.dart';

/// An iPhone-sized window: the shell shows its tab bar.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1179, 2556)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GoRouterApp());
  await tester.pumpAndSettle();
}

/// The tab bar draws each label twice (plain and tinted).
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a branch keeps its state across tab switches', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Count: 0'));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Explore');
    expect(find.text('Explore page'), findsOneWidget);
    await tapTab(tester, 'Home');
    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('a full-frame page inside the branch hides the chrome; back '
      'shows it again', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LiquidTabBar), findsOneWidget);
    await tester.tap(find.text('Open the detail page'));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    expect(find.byType(LiquidTabBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsNothing);
    expect(find.byType(LiquidTabBar), findsOneWidget);
  });

  testWidgets('a page above the shell closes with back; the shell stays', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    expect(find.text('Compose page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Compose page'), findsNothing);
    expect(find.byType(LiquidTabBar), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `cd liquid_shell/example_go_router && fvm flutter test`
Expected: 3 FAIL, `Expected: exactly one matching candidate … Found 0 widgets with text "Count: 0"` (and `LiquidTabBar` for the second).

- [ ] **Step 4: The app**

`liquid_shell/example_go_router/lib/go_router_app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// liquid_shell under go_router: three branches in a
/// `StatefulShellRoute.indexedStack`, a full-frame page inside a branch,
/// and a page above the shell.
class GoRouterApp extends StatefulWidget {
  /// Creates the app.
  const GoRouterApp({super.key});

  @override
  State<GoRouterApp> createState() => _GoRouterAppState();
}

class _GoRouterAppState extends State<GoRouterApp> {
  final _rootKey = GlobalKey<NavigatorState>();
  final _search = LiquidSearchController();
  late final GoRouter _router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    routes: [_shell(), _above()],
  );

  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    ),
    LiquidDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Explore',
      sfSymbol: 'map',
    ),
    LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
    ),
  ];

  // #docregion shell
  RouteBase _shell() => StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => LiquidShell(
      destinations: _destinations,
      selectedIndex: shell.currentIndex,
      // Reselecting a tab goes back to its first page.
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      search: LiquidSearch(controller: _search),
      // The indexed stack keeps every branch alive and hides the others
      // with Offstage and TickerMode, which the shell reads as off screen.
      body: shell,
    ),
    branches: _branches(),
  );
  // #enddocregion shell

  // #docregion branches
  List<StatefulShellBranch> _branches() => [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const _HomePage(),
          routes: [
            // Inside the branch, under the shell: LiquidHideChrome hides
            // the chrome while the page is on screen.
            GoRoute(
              path: 'detail',
              builder: (context, state) => const LiquidHideChrome(
                child: _Page(title: 'Detail page'),
              ),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/explore',
          builder: (context, state) => const _Page(title: 'Explore page'),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => const _Page(title: 'Search page'),
        ),
      ],
    ),
  ];
  // #enddocregion branches

  // #docregion above
  // Above the shell, on the root navigator: the page covers the chrome,
  // and LiquidNoChrome makes its insets ignore it.
  RouteBase _above() => GoRoute(
    path: '/compose',
    parentNavigatorKey: _rootKey,
    builder: (context, state) =>
        const LiquidNoChrome(child: _Page(title: 'Compose page')),
  );
  // #enddocregion above

  @override
  void dispose() {
    _router.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: _router);
}

/// Home: a counter (branch state) and the two ways to open a page.
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Home page',
    children: [
      ListTile(
        title: Text('Count: $_count'),
        onTap: () => setState(() => _count++),
      ),
      ListTile(
        title: const Text('Open the detail page'),
        onTap: () => context.go('/home/detail'),
      ),
      ListTile(
        title: const Text('Compose'),
        onTap: () => context.push('/compose'),
      ),
    ],
  );
}

/// A page padded clear of the chrome.
class _Page extends StatelessWidget {
  const _Page({required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: LiquidShellScope.contentPaddingOf(context),
      children: [
        ListTile(title: Text(title)),
        ...children,
      ],
    ),
  );
}
```

`liquid_shell/example_go_router/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell_example_go_router/go_router_app.dart';

void main() => runApp(const GoRouterApp());
```

`LiquidShellScope.contentPaddingOf` works above the shell too: without a scope it falls back to the system padding (`liquid_shell/lib/src/shell/shell_scope.dart:197-206`), so the compose page uses the same `_Page`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd liquid_shell/example_go_router && fvm flutter test`
Expected: 3 PASS. If a case fails because of the shell's behaviour under go_router (not the app), keep the test as the actual behaviour with a comment, add the gap to the README's Known issues, and do not touch `lib/` (spec §3.7).

- [ ] **Step 6: Wire the app into the checks**

`Makefile`: after `EXAMPLE := liquid_shell/example` add `EXAMPLE_GO_ROUTER := liquid_shell/example_go_router`; in `analyze` use `$(PACKAGES) $(EXAMPLE) $(EXAMPLE_GO_ROUTER) tool`; in `test` loop over `$(PACKAGES) $(EXAMPLE) $(EXAMPLE_GO_ROUTER)`.

`tool/check_readme_snippets.dart:226`: replace

```dart
    final regions = regionsUnder(Directory('$package/example/lib'));
```

with

```dart
    final regions = regionsUnder(Directory('$package/example/lib'));
    for (final MapEntry(:key, :value) in regionsUnder(
      Directory('$package/example_go_router/lib'),
    ).entries) {
      if (regions.containsKey(key)) {
        throw FormatException('two files with regions are named $key');
      }
      regions[key] = value;
    }
```

and in the file's header comment, `liquid_shell/example/lib` → `liquid_shell/example/lib and liquid_shell/example_go_router/lib`.

`tool/check_provenance.sh`: the go_router line becomes

```bash
if git grep --untracked -n -I -E 'go_router' "${outside_docs[@]}" ':!*.md' ':!liquid_shell/example_go_router/' ':!pubspec.yaml'; then
```

(the root `pubspec.yaml` names the workspace member `liquid_shell/example_go_router`), and its header comment adds: "go_router is also allowed in liquid_shell/example_go_router, the app the router doc is built from (VK-701)." Add a test to `tool/test/check_provenance_test.dart`:

```dart
  test('go_router is allowed in the go_router example only', () {
    expect(run('import "package:go_router/go_router.dart";'), 1);
    Directory('${repo.path}/liquid_shell/example_go_router/lib')
        .createSync(recursive: true);
    File('${repo.path}/probe.dart').deleteSync();
    File('${repo.path}/liquid_shell/example_go_router/lib/app.dart')
        .writeAsStringSync('import "package:go_router/go_router.dart";');
    expect(
      Process.runSync(
        'bash',
        ['tool/check_provenance.sh'],
        workingDirectory: repo.path,
      ).exitCode,
      0,
    );
  });
```

Run it first without the script change: expected FAIL (exit 1 for the example file); then with it: PASS.

- [ ] **Step 7: The doc**

In `liquid_shell/doc/router_integration.md` replace the section from `## go_router (until the adapter ships)` up to (not including) `## Pages and the chrome` with:

````md
## go_router

`StatefulShellRoute.indexedStack` gives each tab its own `Navigator` and
keeps the others alive; the shell sits in its `builder`. The complete app
is [`example_go_router`](../example_go_router/lib/go_router_app.dart),
tested on CI.

<?code-excerpt "go_router_app.dart (shell)"?>
```dart
```

Each destination is a `StatefulShellBranch`, the search destination too.
A page that hides the chrome is a route inside its branch:

<?code-excerpt "go_router_app.dart (branches)"?>
```dart
```

A page above the shell (compose, a sheet) goes on the root navigator, with
`LiquidNoChrome`:

<?code-excerpt "go_router_app.dart (above)"?>
```dart
```

System back and the iOS edge swipe pop the branch's page first, as in
[Back pops the tab first](#back-pops-the-tab-first). A go_router adapter
with route-driven hide chrome is planned.

````

Then fill the three empty blocks: `fvm dart run tool/check_readme_snippets.dart --fix`, and check: `make snippets` → ✓.

- [ ] **Step 8: The snippet lock bites (temporary mutation)**

Change one line inside the `shell` block of `doc/router_integration.md` by hand, run `make snippets`: expected FAIL naming `doc/router_integration.md` and `go_router_app.dart (shell)`. Revert (`git checkout -- liquid_shell/doc/router_integration.md` is not allowed mid-task if it holds this task's edits: undo the one line by hand), rerun: ✓. Paste both outputs in the report.

- [ ] **Step 9: Record the provenance change in the P1 spec**

In `docs/specs/2026-10-08-p1-foundation-design.md`, at the end of the §9 provenance paragraph and of §12.2, one sentence each:

```md
**Amended 2026-10-21 (VK-701):** `go_router` may also appear in `liquid_shell/example_go_router`, the unpublished app `doc/router_integration.md` is built from.
```

- [ ] **Step 10: Check and commit**

Run: `make analyze test snippets provenance public-docs coverage && make publish-check 2>&1 | grep -E 'example_go_router|warning'`
Expected: all green (`tool/check_covered.dart` checks `COVERED` packages only, so the app needs no coverage entry; if it complains, read it before changing anything); no `example_go_router` in any archive; 0 warnings ×4.

```bash
bash .githooks/pre-commit
git add liquid_shell/example_go_router pubspec.yaml Makefile tool/check_readme_snippets.dart tool/check_provenance.sh tool/test/check_provenance_test.dart liquid_shell/.pubignore liquid_shell/doc/router_integration.md docs/specs/2026-10-08-p1-foundation-design.md
git commit -m "docs(shell): a go_router example app, and the router doc built from it (VK-701)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Branch verification

**Files:** none (evidence only).

- [ ] **Step 1: Rebase on main**

Run: `git fetch origin && git rebase origin/main`
Expected: clean, or the `.pubignore` conflict with PR #19's C8 lines resolved by keeping `test/` (Task 1 Step 2).

- [ ] **Step 2: Full verify**

Run: `make verify 2>&1 | tail -20`
Expected: `✓ verify passed`. (Goldens run on 3.44.x via fvm; do not run two `make verify` at once on this machine.)

- [ ] **Step 3: pana and the archive**

Run: `make pana 2>&1 | grep -E '^▸|Points:' ; make publish-check 2>&1 | grep -E '^▸|warning|Total'`
Expected: `liquid_shell_platform_interface` ≥ 150/160 (the formatting point is VK-702's); 0 warnings ×4. Paste into the task report and the PR body.

- [ ] **Step 4: Spec coverage list for the PR body**

One line per spec section (§3.1–§3.7) with its commit SHA.
