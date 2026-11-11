# Page Action Drop Log (VK-1046) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native page-action tap that is dropped says which guard dropped it, in debug builds, on both sides of the channel, and a red XCTest run on CI saves the app's log lines so the next flake of `PagesUITests` can be read.

**Architecture:** Dart: `_onNativePageAction` (`liquid_shell/lib/src/shell/liquid_shell.dart`) prints one `kDebugMode` `debugPrint` line per dropped tap, through a local helper; the combined route check splits in three. Swift: `#if DEBUG` `NSLog` at the two silent guards (`ShellNavController.swift`). Tool: `tool/ios_sim.sh applog` saves the app's `liquid_shell` log lines; `tool/ios_xctest.sh` calls it on a red suite. Spec: `docs/specs/2026-11-11-page-action-drop-log-design.md`. Evidence: `.superpowers/sdd/vk1046-investigation.md` (untracked; it is in the vankhan ledger dir, not in this worktree).

**Tech Stack:** Flutter 3.44.9 (fvm), flutter_test, package:test (tool/), Swift / XCTest, Xcode, iOS 26.5 simulator, bash.

## Global Constraints

- No behaviour change: every dropped tap still drops; a tap that runs logs nothing; release builds print nothing.
- Log every time, never once. Dart prefix `liquid_shell:`, native prefix `[liquid_shell]`.
- No CHANGELOG line (spec §2.4). No workflow change (spec §2.3).
- The tool steps never fail the script; bounded at 120 s and 2 MB.
- Simulators: create your own and delete it by UDID. Never touch the protected ones (572B92E2, 383C4573, C428FE39, D3A948FD, B7246683). Never `simctl shutdown all` or `erase all`. No physical devices.
- Run `.githooks/pre-commit` manually and check its exit status before committing; never `--no-verify`. `git add` explicit paths only (`.superpowers/` must not sit in the worktree).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Dart drop log

**Files:**
- Modify: `liquid_shell/test/widget/native_pages_test.dart` (group `VK-443: page actions on the native bar`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (`_onNativePageAction`)

- [ ] **Step 1: Red tests.** In the page-actions group add a `dropLogs(body)` helper that swaps `debugPrint` for a collector around `body`, restores it in `finally`, and keeps the lines that contain `native page action tap dropped`. One test per reachable guard of spec §2.1, each asserting the exact line(s); `bad index` and `symbol differs` emit the same drop twice and expect two lines. One test asserts a tap that runs (`taps == ['Favourite']`) logs nothing. `shell covered`: the shell under a `ValueListenableBuilder` → `TickerMode(enabled: false)`.
- [ ] **Step 2: Run, see red for the right reason** (`fvm flutter test test/widget/native_pages_test.dart`): every new log test fails on an empty list; the success test passes.
- [ ] **Step 3: Implement.** A local `dropped(guard, [state])` that prints under `kDebugMode`; one call before each `return`; the route check split in three in the same order; `no onPressed` when `onPressed == null`.
- [ ] **Step 4: Green.** The file, then the package suite (`fvm flutter test`), `fvm flutter analyze`.
- [ ] **Step 5: Commit** `feat(shell): a dropped native page-action tap logs its guard in debug (VK-1046)`.

### Task 2: Swift drop log

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift` (`tapAction(at:)`, the `setActions` closure)

- [ ] **Step 1:** Split `tapAction`'s guard: `bad index` and `disabled`, each with an `#if DEBUG` `NSLog`. Log the closure guard as `no host or bad index`.
- [ ] **Step 2: Verify** on the own simulator: `FLUTTER="fvm flutter" tool/ios_xctest.sh <udid> liquid_shell/example/build/vk1046-unit.xcresult 900 60 120 -only-testing:RunnerTests/NativeTabsTests/testAPageActionTapSendsAnEventAndDoesNotPop` exits 0 (run in the background; the build is long).
- [ ] **Step 3: Commit** `feat(ios): a dropped native page-action tap logs its guard in debug (VK-1046)`.

### Task 3: A red XCTest run saves the app's log

**Files:**
- Modify: `tool/test/fake_sim.dart` (`log show` answers per `FAKE_LOG_SHOW`)
- Modify: `tool/test/ios_sim_test.dart`, `tool/test/ios_xctest_test.dart`
- Modify: `tool/ios_sim.sh` (`applog`), `tool/ios_xctest.sh` (call it on a red suite)

- [ ] **Step 1: Red tests.** `ios_sim.sh applog`: writes `<diag>/<time>-<label>-app.log` with the fake's line, its `log show` call has `--last <n>s`, `--style compact` and the `process == "Runner" AND eventMessage CONTAINS "liquid_shell"` predicate; a failing `log show` still exits 0 with a note. `ios_xctest.sh`: a red suite and a stall each write one `-app.log` and keep their status; a green run writes none.
- [ ] **Step 2: Red** (`dart test tool/test/ios_sim_test.dart tool/test/ios_xctest_test.dart`).
- [ ] **Step 3: Implement**, header comments included.
- [ ] **Step 4: Green**, then the local check: on the own simulator, launch the example, then `tool/ios_sim.sh applog <udid> local 600` shows a `liquid_shell` `debugPrint` line.
- [ ] **Step 5: Commit** `chore(tool): a red XCTest run saves the app's liquid_shell log (VK-1046)`.

### Task 4: Wrap-up

- [ ] Package suite, `fvm flutter analyze`, `tool/` tests green; delete the simulator by UDID; `git status` clean.
