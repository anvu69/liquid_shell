# CI resolves and stays green on Flutter stable 3.50 (VK-1076)

Status: approved by the owner on 2026-11-16 (Option A + S1, every
recommended default of the decision table in §7).

Addendum 2026-11-18: R1 and R2 were narrowed, not removed, by VK-1077 and
VK-1078; see `docs/specs/2026-11-18-material-seam-design.md`.

## 1. Problem

On 2026-11-11 Flutter 3.50.0 (Dart 3.14.0) became `stable`. CI's stable legs
and `pana` went red at `make get` (first red main run 43175004484):

```
So, because liquid_shell_ios depends on pigeon 27.3.0 and
liquid_shell_workspace depends on test ^1.26.0, version solving failed.
```

`flutter_test` pins `test_api` and `matcher`, so each SDK fixes the root's
`test` version, and `test` fixes the `analyzer` range. `pigeon` (an exact dev
dependency of `liquid_shell_ios`) fixes it too:

| SDK | flutter_test pins | forced `test` | analyzer allowed | pigeon 27.3.0 (analyzer <13) | pigeon 27.3.1 (analyzer >=13 <15) |
|---|---|---|---|---|---|
| 3.44.9 | test_api 0.7.11, matcher 0.12.19 | 1.31.0 | <13 | resolves (12.1.0) | fails |
| 3.47.9 | test_api 0.7.12 | 1.31.1 | <14 | resolves (12.1.0) | resolves (13.3.0) |
| 3.50.0 | test_api 0.7.14, matcher 0.12.20 | >=1.31.2 | >=13 | **fails** (CI's error) | resolves (14.7.0) |

No single exact pigeon pin resolves on both the 3.44 floor and 3.50. Pigeon
30.x resolves on 3.50 but regenerates the Swift protocol as `async throws`
(a host rewrite).

Everything else in the red log is a side effect of the missing
`package_config.json`: the 93 "unformatted" files (the formatter falls back
to the newest language version) and the 28080 analyzer issues (unresolved
imports). With the workspace resolved, format-check changes 0 files on
3.44.9, 3.47.9 and 3.50.0, and analyze on 3.50.0 has 0 errors, 0 warnings
and 115 infos of two classes:

- **R1** `deprecated_member_use` ×112: Flutter 3.50 deprecates
  `package:flutter/material.dart` (→ `material_ui`) and
  `package:flutter/cupertino.dart` (→ `cupertino_ui`).
- **R2** `unnecessary_ignore` ×3 (×4 with the Pigeon source): the 3.50 linter
  no longer reports `avoid_positional_boolean_parameters` where 3.44 and 3.47
  still do. Neither removing the ignore nor ignoring `unnecessary_ignore`
  works on all three SDKs.

Evidence: `.superpowers/sdd/vk1076-design.md` in the vankhan ledger dir (not
in this worktree).

## 2. Goals

- `make get` resolves on 3.44.x, 3.47.9 and stable (3.50.0).
- `checks (stable)` and `goldens (stable)` are green.
- `pana` is no longer broken by an SDK release. Its full green on main also
  needs `0.1.0-dev.13` on pub.dev (§6).
- The generated channel code is byte-identical (`make pigeon-check`: 0
  drift).
- The floor (`flutter: ">=3.44.0"`) and every pubspec constraint of the four
  published packages are unchanged.

## 3. Non-goals

- R1, the `material_ui` / `cupertino_ui` migration: **VK-1077**.
- R2, a named bool in `LiquidNativeSearchActiveChanged` and the internal
  `set(bool)`: **VK-1078**.
- A pigeon upgrade (stays 27.3.0).
- Releasing `0.1.0-dev.13`: **VK-1079**.

## 4. Design

### 4.1 `tool/pigeon`: the generator gets a package of its own

- New package `tool/pigeon/` (`publish_to: none`, **no**
  `resolution: workspace`), `environment.sdk: ^3.12.0`,
  `dev_dependencies: pigeon: 27.3.0, very_good_analysis: 10.3.0`, and an
  `analysis_options.yaml` that includes `very_good_analysis`.
- `liquid_shell_ios/pigeons/native_shell.dart` moves to
  `tool/pigeon/pigeons/native_shell.dart` (`git mv`). `dartOut` / `swiftOut`
  become `../../liquid_shell_ios/...`; `dartPackageName: 'liquid_shell_ios'`
  stays explicit. Its header names the new paths.
- `pigeon` leaves `liquid_shell_ios`'s `dev_dependencies`. Pigeon's analyzer
  can then never constrain the workspace's `test` or a published package.
- Its `.dart_tool/` and `pubspec.lock` are already ignored by the root
  `.gitignore` patterns (`.dart_tool/`, `pubspec.lock`).
- The root `analyze` still passes `tool`; the analyzer gives `tool/pigeon`
  its own context from its own `package_config.json`, so the moved source
  stays analyzed.

### 4.2 Makefile

- `get`: `$(FLUTTER) pub get`, then `cd tool/pigeon && $(DART) pub get`.
- `pigeon`: `cd tool/pigeon && $(DART) run pigeon --input
  pigeons/native_shell.dart`, then the existing `dart format` of the
  generated Dart file.
- `pigeon-check`: unchanged logic, its messages name the new source path.

### 4.3 `tool/check_analyze.dart` and `make analyze-stable`

`make analyze-stable` runs `tool/check_analyze.dart` with the same paths as
`make analyze`. The tool runs `dart analyze --format=machine` (the SDK of
`Platform.resolvedExecutable`, so `FLUTTER=`/`DART=` overrides hold), parses
every issue and:

- fails on any error or warning;
- fails on any info outside the allowlist;
- tolerates exactly two infos:
  - `deprecated_member_use` whose message names
    `package:flutter/material.dart` or `package:flutter/cupertino.dart` (R1);
  - `unnecessary_ignore` whose message names
    `avoid_positional_boolean_parameters` (R2);
- fails on `deprecated_member_use` of anything else;
- prints each tolerated issue (one summary line each, plus a count), never
  silently;
- fails when the analyzer exits non-zero without reporting a blocking issue,
  or prints a line it cannot parse (so a crash never reads as green).

`make analyze` (and so `make verify` and the pre-commit hook) keeps
`--fatal-infos --fatal-warnings`. `analysis_options.yaml` is untouched. The
allowlist is removed when VK-1077 (R1) and VK-1078 (R2) land.

### 4.4 CI wiring

- `checks`: the stable leg runs `make analyze-stable`, the 3.44.x leg
  `make analyze` (both gated on `matrix.experimental`). Every other step
  is unchanged, `pigeon-check` included.
- `goldens`: no change.
- `ci.yaml` header and step comments say why.

### 4.5 pana (D7)

- The blocking `pana` job pins `flutter-version: 3.47.9`, like every other
  blocking job, so a new release cannot move it.
- A new job `pana (stable)` runs the same four steps on latest stable with
  `continue-on-error: true` and `--exit-code-threshold` only informing.
- Both jobs install `webp` with a retry (3 attempts), for the
  `Temporary failure resolving 'azure.archive.ubuntu.com'` failures of
  2026-11-11.

### 4.6 Docs

`CONTRIBUTING.md` (Toolchain, Commands, Dependencies), `CLAUDE.md` (the
Generated channel and Dependencies lines), `liquid_shell_ios/pubspec.yaml`'s
comment and the Makefile comments name `tool/pigeon`, the stable-only
allowlist and its exit tickets. Historic specs, plans and CHANGELOG entries
are not edited.

## 5. Verification

| | 3.44.9 | 3.47.9 | 3.50.0 |
|---|---|---|---|
| `make get` | ✓ | ✓ | ✓ |
| `make format-check` | ✓ | ✓ | ✓ |
| `make analyze` | ✓ | ✓ | (R1/R2, expected red) |
| `make analyze-stable` | ✓ | ✓ | ✓ |
| `make pigeon-check` (0 drift) | ✓ | ✓ | ✓ |
| `make test`, `make coverage` | ✓ | ✓ | ✓ |
| `make goldens-plain`, `make test-impeller` | | ✓ (`make verify`) | ✓ |
| pana, four packages | | ✓ | record |

`fvm dart test tool/test/check_analyze_test.dart` red first, then green.
`.githooks/pre-commit` exit 0 before every commit. Acceptance: on the pushed
branch, `checks (stable)`, `goldens (stable)` and `pana` are green next to
the 3.44.x and 3.47.9 jobs.

## 6. Risks and known follow-ups

- **pana on main stays red until dev.13 is published (VK-1079).** `main`
  already uses `LiquidNativeShellState.engagedApplied` (VK-1064), which
  pub.dev's `0.1.0-dev.12` siblings do not have, so pana scores
  `liquid_shell` and `liquid_shell_ios` 70/160 on any SDK. A green VK-1076
  does not fix that by itself.
- On 3.50, R1 alone costs `liquid_shell` 10 pana points; pub.dev scores with
  its own current SDK, so it costs the published score too (VK-1077).
- A nested package under `tool/` must be tolerated by every script that
  walks `tool/` (`check_provenance`, `check_public_docs`, `check_covered`,
  `check_readme_snippets`, `dart format .`).
- A future SDK may drop analyzer 12 support for pigeon 27.3.0; the bump is
  then a one-line, isolated change inside `tool/pigeon`.
- Allowlist rot: its exits are VK-1077 and VK-1078.
- pana reports `liquid_shell_platform_interface`'s
  `lib/src/native_chrome.dart` as not matching the formatter (150/160, both
  SDKs) although `dart format` passes; investigated in Task 5, timeboxed to
  30 minutes.

## 7. Decisions (owner, 2026-11-16)

| # | Decision |
|---|---|
| D1 | A: isolate pigeon in `tool/pigeon` |
| D2 | keep pigeon 27.3.0 |
| D3 | the source moves to `tool/pigeon/pigeons/native_shell.dart` |
| D4 | S1: `tool/check_analyze.dart` allowlist + `make analyze-stable` on the stable leg |
| D5 / D6 | R1 and R2 are not in scope (VK-1077, VK-1078) |
| D7 | the blocking `pana` job pinned to Flutter 3.47.9, plus an informational `pana (stable)` job; `apt-get` with retry |
| D8 | `CONTRIBUTING.md` updated |
| D9 | dev.13 is VK-1079; VK-1076 only documents it |
| D10 | pana's formatter complaint: 30-minute investigation, findings reported |
