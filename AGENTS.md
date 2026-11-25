# AGENTS.md — liquid_shell

Rules for coding agents (Codex, OMP) working in this repo. They restate
`CLAUDE.md` and `CONTRIBUTING.md`; when in doubt, those files win.

## What this is

A Flutter plugin monorepo (pub workspace) for an app shell with Liquid Glass
chrome: native iOS 26 tab bar / sidebar through Pigeon, and a Flutter shader
"liquid" tier elsewhere.

- `liquid_shell/` — the app-facing package (`lib/src/shell/liquid_shell.dart`
  is the shell; tests in `test/widget/`, goldens in `test/goldens/`).
- `liquid_shell_platform_interface/`, `liquid_shell_ios/` (Swift),
  `liquid_shell_android/` (Kotlin) — the federated plugin.
- `tool/` — check scripts, `tool/pigeon` (the channel generator).

## Toolchain

Flutter **3.47.9** via fvm (`.fvmrc`); `make` picks fvm up automatically.
Run single test files with `fvm flutter test <file>` from the package
directory (for example `cd liquid_shell && fvm flutter test
test/widget/native_chrome_test.dart`).

## Commands

```bash
make get        # resolve the workspace
make format     # rewrite formatting
make analyze    # static analysis, every info is fatal
make test       # unit and widget tests
make verify     # everything blocking CI runs: must be green before you report done
```

Do not run the simulator targets (`make ios-unit`, `make ios-ui`,
`make integration-*`) unless your task says so; if it does, create your own
simulator, address it by UDID, and delete it afterwards.

## How to work

- **TDD.** Write the test first, run it, and see it fail for the right
  reason. Paste that red output in your report. Only then write production
  code. A bug fix starts with a test that reproduces the bug.
- Change only the files your task lists. Keep the existing style and the
  English doc comments.
- **Commit** with the hook run by hand: `.githooks/pre-commit && git commit`.
  Message `<type>(<scope>): <summary>`, types `feat fix refactor docs test
  chore perf ci`, scopes `shell glass platform ios android example docs ci`,
  ending with a `Co-Authored-By:` line naming you. Every commit is green.
- `CHANGELOG.md` entries go under the newest `## 0.1.0-dev.N` heading, never
  `## Unreleased` (a test checks it).

## Forbidden

- `git push`, adding or changing remotes, creating tags, opening PRs.
- `dart pub publish` / `flutter pub publish` in any form, with or without
  `--dry-run` or `--force`.
- Changing git config, `core.hooksPath`, or committing with `--no-verify`.
- Loosening `analysis_options.yaml`, or lowering coverage thresholds.
- Editing golden images by hand; they come only from `make goldens-update`.
- Opening or copying another glass package's shader or glass code
  (liquid_glass_renderer, liquid_glass_widgets, liquid_glass_easy, …).
- Adding runtime dependencies.
- Touching simulators, emulators or devices you did not create.
- Touching anything outside your worktree.

## Report

When done (or blocked), report: files changed, a short summary, the red
test output from before the fix, the green output after, the `make verify`
result, and anything you are unsure about.
