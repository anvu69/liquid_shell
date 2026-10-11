# CLAUDE.md — liquid_shell

Binding rules for every session in this repo. Details: `CONTRIBUTING.md`,
the spec in `docs/specs/`, and the plan in `docs/plans/`.

## Before typing

1. Is there a Plane work item (VK-…)? No → stop and ask.
2. Is there an approved spec? No → `superpowers:brainstorming`. No code.
3. Is there a plan? No → `superpowers:writing-plans`. No code.

## Hard rules

- **TDD.** No production code without a test that failed first for the
  right reason (`superpowers:test-driven-development`).
- **Evidence.** Never say "done" without running `make verify` (or the
  task's commands) and pasting the output
  (`superpowers:verification-before-completion`).
- **Pre-commit by hand.** `.githooks/pre-commit && git commit`. Never set
  `core.hooksPath`; never change git config. `--no-verify` is not an option.
- **Commits.** `<type>(<scope>): <summary>`, scopes `shell glass platform
  ios android example docs ci`, ending with the Co-Authored-By line.
- **No pushes, no remotes, no publishing** without the owner's explicit
  go-ahead.
- **Provenance.** Re-type ported code in English with new names. Rewrite the
  two integration helpers named in spec §9 from public docs without opening
  the originals. `make provenance` must stay green.
- **Dependencies.** Flutter + our packages + `plugin_platform_interface`,
  plus `meta` in `liquid_shell_ios` (imported by the Pigeon-generated
  channel; pinned by the Flutter SDK). Nothing else at runtime.
  `very_good_analysis` pinned to 10.3.0; `pigeon` pinned to 27.3.0 (dev).
- **Generated channel.** Edit `liquid_shell_ios/pigeons/native_shell.dart`,
  run `make pigeon`, commit the source and both generated files.
- **Never loosen `analysis_options.yaml`** to get code through. Fix the code.
- **Goldens** are regenerated only with `make goldens-update` on macOS +
  Flutter 3.44.6. Never edit images by hand.
- **Clean-room shader.** Never open or copy another glass package's shader or glass code (liquid_glass_renderer, liquid_glass_widgets, liquid_glass_easy, …). Derive from spec 2026-10-10 §4.

## Commands

```bash
make get        # resolve the workspace
make verify     # everything blocking CI runs; green before any PR
make goldens-update
make android-unit
make integration-ios
make integration-ios-native   # native iPadOS shell, iPad + iPhone simulators
make ios-unit IOS_UNIT_DEVICE=<udid>   # XCTest of liquid_shell_ios
make ios-ui IOS_UNIT_DEVICE=<udid>   # XCUITest: real taps on native dialogs
make pigeon                   # regenerate the native channel
make integration-android
make test-impeller   # shader tests under Impeller (macOS)
make compare-images   # native vs Flutter liquid screenshots
```
