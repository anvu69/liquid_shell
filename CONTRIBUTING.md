# Contributing to liquid_shell

## Toolchain

- Flutter **3.47.9** is the local toolchain and the golden reference
  (`.fvmrc`); the packages' floor is still 3.44.0.
  With [fvm](https://fvm.app) installed, `make` uses it automatically:
  `fvm install 3.47.9`, then `make get`.
- Without fvm, put a Flutter 3.47.9 on `PATH`, or run
  `make verify FLUTTER=/path/to/flutter DART=/path/to/dart`.
- Goldens are only valid on macOS with Flutter 3.47.x (spec Q11). The 3.44
  engine draws the dark liquid glass differently (VK-700), so the liquid
  goldens fail there by design.
- CI guards the floor with `checks (3.44.x)` (analyze and unit tests, no
  goldens) and runs the goldens and every build on 3.47.9. Both block,
  except `ios-ui`, which stays non-blocking as before.
- CI also runs the latest stable Flutter, never blocking. There the plain
  goldens and the shader probes (`make test-impeller`) must pass; the
  liquid goldens only inform, because a newer engine may draw the dark
  glass differently again. When that happens for good, the reference moves
  to that Flutter and the images are regenerated once.
- On that stable leg `checks` runs `make analyze-stable` instead of
  `make analyze`. It fails like `make analyze`, except for two info classes
  that only the newer SDK reports and the 3.44 floor cannot fix, which it
  prints and tolerates (`tool/check_analyze.dart`):
  `deprecated_member_use` of `package:flutter/material.dart` /
  `cupertino.dart` (Flutter 3.50), only in the two example apps, whose
  code the READMEs show; and `unnecessary_ignore` of
  `avoid_positional_boolean_parameters` (Dart 3.14 flags only two or more
  positional bools), only in the Pigeon source. That second entry goes when the floor reaches Flutter
  3.50. `make analyze` and `make verify` keep every info fatal.
- liquid_shell's `lib/` and `test/` import
  `package:liquid_shell/src/material_sdk.dart` (tests: also
  `test/helpers/cupertino_sdk.dart`), never the deprecated
  `material.dart` / `cupertino.dart`. The barrel re-exports the SDK's own
  `src/material` files, so the types are unchanged; add a file to it when
  you need a new symbol. `tool/check_material_seam.sh`
  (`make provenance`) enforces it on every toolchain.
- `pana` blocks on 3.47.9, like the other blocking jobs; `pana (stable)`
  runs the same steps on latest stable and never blocks.
- The Pigeon generator is its own package, `tool/pigeon`, outside the pub
  workspace (`make get` resolves both). Pigeon's analyzer range would
  otherwise clash with the `test` version each Flutter SDK forces through
  `flutter_test` (VK-1076).

## Commands

| Command | What it does |
|---|---|
| `make get` | Resolve the pub workspace (all packages and the example) |
| `make format` | Rewrite formatting in place |
| `make verify` | format-check, analyze, provenance, tests, coverage ≥ 90 %, goldens, README snippets. **Must be green before a PR.** |
| `make goldens-plain` / `make goldens-liquid` | The two halves of the goldens in `make verify`: plain, then the liquid tier under Impeller (CI's stable leg treats the liquid half as information only) |
| `make goldens-update` | Regenerate goldens and `liquid_shell/doc/images`, then recompress them losslessly with `tool/compress_pngs.dart` (macOS + 3.47 only) |
| `make android-unit` | Kotlin JVM tests of the Android plugin |
| `make integration-ios` / `make integration-android` | Signal channel tests on a simulator / emulator |
| `make integration-ios-native` | Native iOS 26 shell on an iPad and an iPhone simulator (both install it); saves screenshots |
| `make ios-unit IOS_UNIT_DEVICE=<udid>` | XCTest of `liquid_shell_ios` (example `RunnerTests`) on one simulator; CI runs it on the newest iPad and iPhone |
| `make ios-ui IOS_UNIT_DEVICE=<udid>` | XCUITest: real taps on native dialogs (example `RunnerUITests`) on one simulator; CI runs it, non-blocking, on the newest iPad and iPhone |
| `make ios-minimize IOS_UNIT_DEVICE=<udid>` | XCUITest: `MinimizeUITests` only (the native tab bar's minimize) on one simulator; CI runs it, blocking, on an iPhone 17 (iOS 26) |
| `make pigeon` / `make pigeon-check` | Regenerate the native channel from `tool/pigeon/pigeons/native_shell.dart` / fail when the generated files drift (part of `verify`) |
| `make analyze-stable` | `make analyze` for CI's latest-stable leg: the known stable-only infos are printed and tolerated, everything else fails |
| `make pana` / `make publish-check` | pub.dev scoring and publish dry-run; the four CI pana steps are blocking on 3.47.9 and need the max score on main (`webp` is installed on the runner for screenshots); `pana (stable)` only informs |
| `make test-impeller` | Shader tests under Impeller (macOS) |
| `make compare-images` | Native vs Flutter liquid screenshots |

## Coverage gate

`make coverage` runs for the packages listed in `COVERED` (Makefile) and is
honest in four ways:

- `flutter test --coverage` only reports files a test loads, so
  `tool/gen_coverage_helper.dart` writes a throwaway
  `test/coverage_all_libs_test.dart` that imports every file under `lib/`;
  the Makefile deletes it after the run (it is also git-ignored). An
  untested file therefore counts as 0 %, not as absent.
- A package with no tests, or whose report instruments no `lib/` line,
  **fails**. It never passes as 100 %.
- Below `COVERAGE_MIN` (90) fails.

- A package whose `lib/` holds more than comments and directives but is
  missing from `COVERED` **fails** (`tool/check_covered.dart`). A package
  joins `COVERED` in the task that gives its `lib/` executable code.

## Pre-commit gate

Run the hook **by hand** before every commit:

```bash
.githooks/pre-commit && git commit
```

Do not install it with `git config core.hooksPath`; nobody changes git
config in this repo.

## Test-driven development (mandatory)

1. Write the test. Run it. **Watch it fail for the right reason.**
2. Write the smallest code that makes it pass. Run it. Green.
3. Refactor, keep it green, commit.

Production code written before a failing test is deleted and rewritten. A
bug fix starts with a test that reproduces the bug.

## Commits and branches

- Branch: `<PLANE-ID>-<short-slug>`, for example `VK-345-p1-foundation`.
- Commit: `<type>(<scope>): <summary>`. Types: `feat fix refactor docs test
  chore perf ci`. Scopes: `shell glass platform ios android example docs ci`.
- Every plan task ends in at least one commit, and every commit is green.
- A PR body links the Plane work item and pastes the `make verify` output.

## Provenance (open source, MIT)

- Only code we wrote goes in. Code ported from our app is **re-typed** into
  the new API with new names and English comments; no app names, ticket
  numbers or Vietnamese comments.
- The two integration-test helpers named in spec §9 are **rewritten from the
  public `integration_test` documentation**, never copied, and the person
  writing them must not open the originals.
- No app assets, screenshots, fonts or brand colours.
- `tool/check_provenance.sh` (run by `make verify`, the hook and CI) rejects
  banned names outside `docs/`.
- Every package `LICENSE` is MIT, `Copyright (c) 2026 lasoai.vn`.
- Third-party code needs a compatible licence and its notice. Fonts used by
  tests ship with their OFL text.

## Dependencies

Runtime dependencies are Flutter, our own federated packages and
`plugin_platform_interface` only, plus `meta` in `liquid_shell_ios`, which
the Pigeon-generated channel imports and the Flutter SDK pins (P2 spec
§6.1). Adding anything else needs a spec change. `pigeon` is pinned
exactly (27.3.0) in `tool/pigeon`, a package outside the workspace, not in
`liquid_shell_ios`.
`very_good_analysis` stays pinned to `10.3.0`.
