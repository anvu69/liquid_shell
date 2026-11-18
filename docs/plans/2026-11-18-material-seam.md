# Material seam and the 3.50 lint infos (VK-1077, VK-1078) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `liquid_shell/lib` and `liquid_shell/test` stop reporting Flutter 3.50's material/cupertino deprecation on every toolchain; two of the four R2 ignores go; `make analyze-stable` tolerates only what cannot change (the examples' R1, two R2 files).

**Architecture:** One internal barrel (`liquid_shell/lib/src/material_sdk.dart`) `export`s the SDK's own `src/material` files, so types stay identical; a test-side barrel does the same for the one cupertino test. A seam gate in `make provenance` keeps the deprecated imports out on the floor. Spec: `docs/specs/2026-11-18-material-seam-design.md`.

**Tech Stack:** fvm (3.44.9, 3.47.9, 3.50.0), `package:test`, bash + `git grep`, GNU make, pana 0.23.19.

## Global Constraints

- No user-visible change: same SDK types, no public API change, no dependency change, no release.
- `analysis_options.yaml` untouched; `make analyze` keeps `--fatal-infos`.
- Switching SDKs: `make … FLUTTER="fvm spawn <v>" DART=~/fvm/versions/<v>/bin/dart`, never `fvm global`; `make get` on 3.47.9 again before the hook.
- `.githooks/pre-commit` by hand before every commit, exit 0; explicit `git add` paths.
- Commit: `<type>(<scope>): <summary> (VK-1077|VK-1078)` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Narrow the analyze-stable allowlist

**Files:** Modify `tool/check_analyze.dart`, `tool/test/check_analyze_test.dart`

- [ ] **Step 1: Red tests.** R1 in `/r/liquid_shell/lib/a.dart` and the cupertino line in `/r/liquid_shell/test/b_test.dart` block; R1 in `/r/liquid_shell/example/lib/x.dart` and `/r/liquid_shell/example_go_router/lib/y.dart` is tolerated; R2 in `/r/liquid_shell/lib/src/chrome/lens_motion.dart` and `/r/liquid_shell/test/widget/shell_chrome_test.dart` blocks; R2 in `/r/liquid_shell_platform_interface/lib/src/native_chrome.dart` and `/r/tool/pigeon/pigeons/native_shell.dart` is tolerated; a lookalike `/r/liquid_shell/example_extra/…` blocks; the reasons read `R1, VK-1077 (examples: README)` and `R2, VK-1078 (floor < Dart 3.14)`.
- [ ] **Step 2:** `fvm dart test tool/test/check_analyze_test.dart`: red on the new cases.
- [ ] **Step 3:** Path conditions in `toleratedBecause` (segment `contains` for R1, `endsWith` for R2); header comment.
- [ ] **Step 4:** Green; pre-commit; commit `ci(ci): narrow analyze-stable R1 to the examples, R2 to two files (VK-1077, VK-1078)`.

### Task 2: Material seam gate

**Files:** Create `tool/check_material_seam.sh`, `tool/test/check_material_seam_test.dart`

- [ ] **Step 1: Red tests** (temp git repo, as `check_glass_seam_test`): `import 'package:flutter/material.dart';` in `liquid_shell/lib/src/x.dart` fails; the same in `liquid_shell/test/x_test.dart` fails; a cupertino import fails; an `export` of material fails; the barrel's `export 'package:flutter/src/material/theme.dart';` passes; `liquid_shell/example/lib/main.dart` importing material passes; a `//` comment and a `///` snippet naming the import pass.
- [ ] **Step 2:** Run: red (no script).
- [ ] **Step 3:** Write the script (directive anchored: `^[[:space:]]*(import|export)[[:space:]]+['"]package:flutter/(material|cupertino)\.dart`). Not wired into `make provenance` yet (the repo is still red).
- [ ] **Step 4:** Green; pre-commit; commit `ci(ci): material seam gate script (VK-1077)`.

### Task 3: The lib barrel

**Files:** Create `liquid_shell/lib/src/material_sdk.dart`; modify the 16 `liquid_shell/lib/src/**` files that import `package:flutter/material.dart`

- [ ] **Step 1: Red:** `tool/check_material_seam.sh` on the repo lists the 16 lib files (and the tests).
- [ ] **Step 2:** The barrel (17 `src/material` exports + `widgets.dart`, `//` comments), the 16 imports, `dart fix --apply --code=directives_ordering liquid_shell/lib`, `dart format`.
- [ ] **Step 3:** `fvm dart analyze liquid_shell/lib` 0 issues on 3.47.9 and 3.44.9; `cd liquid_shell && fvm flutter test --exclude-tags golden,impeller,liquid_golden` green; the gate lists only tests.
- [ ] **Step 4:** Pre-commit; commit `refactor(shell): route SDK Material through one internal barrel (VK-1077)`.

### Task 4: Tests through the barrels; wire the gate

**Files:** Modify the barrel (+5 exports), 47 material test files, `liquid_shell/test/widget/liquid_backdrop_test.dart`, `Makefile` (`provenance`); create `liquid_shell/test/helpers/cupertino_sdk.dart`

- [ ] **Step 1:** Barrel +`bottom_sheet page tab_controller tabs text_button`; the 47 imports; the cupertino test imports the test barrel; `dart fix --code=directives_ordering liquid_shell/test`; format.
- [ ] **Step 2:** The gate exits 0 on the repo; wire it into `provenance`.
- [ ] **Step 3:** analyze 0 on 3.47.9 and 3.44.9; liquid_shell tests green; `make goldens-plain` unchanged.
- [ ] **Step 4:** Pre-commit; commit `test(shell): import SDK Material and Cupertino via barrels; seam gate in make provenance (VK-1077)`.

### Task 5: R2 sites 2 and 3

**Files:** Modify `liquid_shell/lib/src/chrome/lens_motion.dart`, `liquid_shell/lib/src/chrome/glass_tab_bar.dart`, `liquid_shell/test/unit/lens_motion_test.dart`, `liquid_shell/test/widget/shell_chrome_test.dart`

- [ ] **Step 1: Red:** `lens_motion_test.dart` calls `set(minimized: …)`; `flutter test test/unit/lens_motion_test.dart` fails to compile.
- [ ] **Step 2:** `set({required bool minimized, bool delayed = true})`, the `glass_tab_bar.dart` caller, drop the ignore. Green.
- [ ] **Step 3:** `shell_chrome_test.dart`: `final setVisible = <bool>[].add;`, drop the ignore; the test stays green.
- [ ] **Step 4:** analyze 0 on 3.44.9 (the rule still fires there, so no new ignore is needed only because the sites are gone); pre-commit; commit `refactor(shell): named minimized in MinimizeMotion.set, tear-off test double (VK-1078)`.

### Task 6: Docs and comments

**Files:** Modify `.github/workflows/ci.yaml`, `Makefile`, `CONTRIBUTING.md`, `liquid_shell/CHANGELOG.md`, `docs/specs/2026-11-16-ci-stable-3-50-design.md`

- [ ] **Step 1:** Comments naming R1/R2 say what is left (examples; two R2 files) and why; `CONTRIBUTING.md` names the barrel and the gate; CHANGELOG `## 0.1.0-dev.14` line; the VK-1076 spec gets a pointer.
- [ ] **Step 2:** YAML parses; `make public-docs`; `fvm dart test tool/test/release_version_test.dart`; pre-commit; commit `docs(ci): R1/R2 after the Material seam (VK-1077, VK-1078)`.

### Task 7: Verification

- [ ] **Step 1:** 3.44.9: `make get format-check analyze analyze-stable provenance public-docs pigeon-check test`.
- [ ] **Step 2:** 3.47.9: `make verify`.
- [ ] **Step 3:** 3.50.0: `make get format-check analyze-stable test coverage goldens-plain`; pana 0.23.19 on scratch copies of `liquid_shell` and `liquid_shell_platform_interface`, before and after.
- [ ] **Step 4:** `make get` on 3.47.9, `.fvmrc` unchanged, `git status` clean.
