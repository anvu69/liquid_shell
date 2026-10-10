# Contributing to liquid_shell

## Toolchain

- Flutter **3.44.6** is the floor and the golden reference (`.fvmrc`).
  With [fvm](https://fvm.app) installed, `make` uses it automatically:
  `fvm install 3.44.6`, then `make get`.
- Without fvm, put a Flutter 3.44.x on `PATH`, or run
  `make verify FLUTTER=/path/to/flutter DART=/path/to/dart`.
- Goldens are only valid on macOS with Flutter 3.44.x (spec Q11).

## Commands

| Command | What it does |
|---|---|
| `make get` | Resolve the pub workspace (all packages and the example) |
| `make format` | Rewrite formatting in place |
| `make verify` | format-check, analyze, provenance, tests, coverage ≥ 90 %, goldens, README snippets. **Must be green before a PR.** |
| `make goldens-update` | Regenerate goldens and `liquid_shell/doc/images`, then recompress them losslessly with `tool/compress_pngs.dart` (macOS + 3.44 only) |
| `make android-unit` | Kotlin JVM tests of the Android plugin |
| `make integration-ios` / `make integration-android` | Signal channel tests on a simulator / emulator |
| `make integration-ios-native` | Native iOS 26 shell on an iPad and an iPhone simulator (both install it); saves screenshots |
| `make ios-unit IOS_UNIT_DEVICE=<udid>` | XCTest of `liquid_shell_ios` (example `RunnerTests`) on one simulator; CI runs it on the newest iPad and iPhone |
| `make ios-ui IOS_UNIT_DEVICE=<udid>` | XCUITest: real taps on native dialogs (example `RunnerUITests`) on one simulator; CI runs it, non-blocking, on the newest iPad and iPhone |
| `make pigeon` / `make pigeon-check` | Regenerate the native channel / fail when the generated files drift (part of `verify`) |
| `make pana` / `make publish-check` | pub.dev scoring and publish dry-run |

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
§6.1). Adding anything else needs a spec change. `pigeon` is a dev
dependency of `liquid_shell_ios`, pinned exactly.
`very_good_analysis` stays pinned to `10.3.0`.
