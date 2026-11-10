# Landscape Wait (VK-815) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The VK-550 scope-bar rotation test waits, with deadlines, for landscape and for the keyboard, and retries the rotation request, instead of checking once after a fixed wait.

**Architecture:** Test-only edits in `liquid_shell/example/integration_test/native_search_test.dart`: a `_pumpUntil` helper and a `_rotateToLandscape` helper. Spec: `docs/specs/2026-11-10-landscape-wait-design.md`. Evidence: `.superpowers/sdd/vk815-investigation.md` (untracked).

**Tech Stack:** integration_test / flutter_test, Flutter 3.44.9 (`fvm flutter`), iOS 26.5 simulator.

## Global Constraints

- Test file only. No package code changes and no CHANGELOG line. No changes to `tool/integration_ios_native.sh`.
- Never refocus the search field in the test.
- The deadlines: the rotation retry fires after 3 s of portrait, with at most 2 retries; each overall wait gives up after 10 s.
- Every deadline failure message includes the orientation, `viewInsets.bottom`, the field frame and `firstResponderIsSearch`.
- Simulators: create your own and delete them by UDID. Never touch the protected ones (lba144-duo 572B92E2, iPhone Duo 383C4573, iPhone 17 Pro C428FE39, D3A948FD, B7246683). Never `simctl shutdown all` or `erase all`. No physical devices.
- Run `.githooks/pre-commit` manually and check its exit status before committing; never `--no-verify`. `git add` explicit paths only (`.superpowers/` is not ignored).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Wait for landscape and the keyboard

**Files:**
- Modify: `liquid_shell/example/integration_test/native_search_test.dart` (`_settle` at ~:21; the rotation block at ~:302-345)

- [ ] **Step 1: Check the engine.** In the Flutter 3.44.9 engine source, find out whether `setPreferredOrientations` with an unchanged mask is skipped on iOS. Look at `FlutterViewController.mm`, `onPreferredOrientationsNotification` and `performOrientationUpdate:`. Use the engine source on GitHub through `gh api` (for example `repos/flutter/flutter/contents/engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterViewController.mm?ref=3.44.9`), or a local copy if one exists. Record the lines in the report. This decides whether a retry toggles the mask first (spec §2.2).

- [ ] **Step 2: Add the helpers** near `_settle`:

```dart
/// Pumps 100 ms at a time until [condition] holds; fails with [describe]
/// after [timeout]. Returns how long it waited.
Future<Duration> _pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  required String Function() describe,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed >= timeout) {
      fail('timed out after ${watch.elapsed}: ${describe()}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return watch.elapsed;
}
```

  Also add `_rotateToLandscape(tester)`. It requests `[landscapeLeft]` and waits up to 3 s for `MediaQueryData.fromView(tester.view).orientation == Orientation.landscape`. If the orientation is still portrait, it retries, at most twice. A retry toggles the mask first (`[landscapeLeft, landscapeRight]`, a pump, then `[landscapeLeft]`) when Step 1 showed that repeats are skipped. The final deadline is 10 s overall. It returns the retry count and the time waited. The failure message is built from the latest snapshot (`await _ios.debugSnapshot()`, read just before failing) and includes orientation, `viewInsets.bottom`, `fieldFrame` and `firstResponderIsSearch`. Since `describe` is synchronous, keep the latest snapshot in a local that the loop refreshes.

- [ ] **Step 3: Use them.** In the rotation block, replace `setPreferredOrientations` + `_settle` + the orientation `expect` with `_rotateToLandscape`. Then `await _settle(tester)` once for layout. Before reading `landscape` / `raised`, wait with `_pumpUntil` until `MediaQueryData.fromView(tester.view).viewInsets.bottom > 0` and the snapshot's `fieldFrame` differs from the resting frame. Record the resting frame from a snapshot taken right after the rotation lands, before the keyboard returns, or compare against the portrait frame if that is the clearer signal. Explain the choice in a `//` comment. Extend the `liquid_shell VK-594 landscape:` debugPrint with the retries and waits. Keep every existing `expect` that follows. Apply the same wait to any later portrait return that the test checks.

- [ ] **Step 4: Static checks.** Run `cd liquid_shell/example && fvm flutter analyze integration_test/native_search_test.dart` (no issues), then `.githooks/pre-commit` (exit 0).

- [ ] **Step 5: Local runs.** Create your own iPhone 17 Pro iOS 26.5 simulator and check that `simctl create` exits 0. Read `tool/integration_ios_native.sh` for its arguments, then run `native_search_test.dart` alone through it (`NATIVE_TARGETS=native_search_test.dart` or as the script expects), three times. Expected: each passes; quote the `VK-594 landscape:` line of each run. Delete the simulator. Keep disk ≥10 GB free.

- [ ] **Step 6: Commit** the test file plus the spec and this plan: `test(ios): the scope bar rotation test waits for landscape and the keyboard (VK-815)`.
