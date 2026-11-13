# Root Bar Hand-over (VK-1064) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When native chrome engages, a root page with actions always shows one bar (Flutter's, then native's) and its content never jumps: Dart drops its own page bar only once native confirms it applied the engaged config.

**Architecture:** Pigeon `NativeShellState.engagedApplied` ← `NativeTabsController.currentState()` (`config?.engaged`). Dart `_resolveNative` splits config-engaged (unchanged) from layout-engaged (a waiting → holding → done hand-over with a top hold and a 250 ms fallback). Native skips the bar animation and the chrome fade on an engage. Spec: `docs/specs/2026-11-13-root-bar-handover-design.md`. Evidence: `.superpowers/sdd/vk1064-design.md` (vankhan ledger dir, untracked, not in this worktree).

**Tech Stack:** Flutter 3.47.9 (fvm), flutter_test, Pigeon 27.3.0, Swift / XCTest / XCUITest, iOS 26.5 simulator.

## Global Constraints

- IME safety: the ack is a state event only; it never drives `_search.native`; no field is rebuilt or written by it.
- Run `.githooks/pre-commit` by hand before every commit and check exit 0; never `--no-verify`. `git add` explicit paths only.
- Commit: `<type>(<scope>): <summary> (VK-1064)` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Simulators: an own one, deleted by UDID at the end; never the protected ones (572B92E2, 383C4573, C428FE39, D3A948FD, B7246683), never `shutdown all` / `erase all`.
- Out of scope: VK-1074 (disengage mirror), VK-1075 (per-owner ack).

---

### Task 1: `engagedApplied` on the channel

**Files:**
- Modify: `liquid_shell_platform_interface/lib/src/native_chrome.dart` (`LiquidNativeShellState`)
- Modify: `liquid_shell_platform_interface/test/native_chrome_test.dart`
- Modify: `liquid_shell_ios/pigeons/native_shell.dart`; regenerated `liquid_shell_ios/lib/src/native_shell_api.g.dart`, `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift`
- Modify: `liquid_shell_ios/lib/src/mapping.dart`, `liquid_shell_ios/test/liquid_shell_ios_test.dart`
- Modify: `NativeShellInstaller.swift` (not-installed answer), `NativeTabsController.swift` (`currentState`)

- [ ] **Step 1: Red.** Interface test: two states differing only in `engagedApplied` are unequal (and the hash differs), the default is `false`, `toString` names it. iOS test: `stateFromNative` maps `engagedApplied: true`.
- [ ] **Step 2: Run** `fvm flutter test` in both packages: red (no such parameter).
- [ ] **Step 3: Implement.** The field (default `false`, in `==`/`hashCode`/`toString`); Pigeon field (required) + `make pigeon`; mapping; Swift call sites (`engagedApplied: false` in the installer, `config?.engaged ?? false` in `currentState`). Existing iOS Dart tests pass the new required Pigeon argument.
- [ ] **Step 4: Green**: both packages' tests, `make pigeon-check`, `fvm flutter analyze`.
- [ ] **Step 5: Commit** `feat(platform): native reports whether it applied an engaged config (VK-1064)`.

### Task 2: The fake models the ack

**Files:**
- Modify: `liquid_shell/test/helpers/fake_native_platform.dart`

- [ ] **Step 1:** `autoAck` (default true) stamps `engagedApplied: true` on an installed attach answer and on `pushState`; `ack()` pushes the current state acked. No production change: run the whole `liquid_shell` suite, it must be unchanged (green).
- [ ] **Step 2:** Folded into Task 3's commit (test helper only).

### Task 3: Dart hand-over

**Files:**
- Modify: `liquid_shell/test/widget/native_pages_test.dart` (new group `VK-1064: the root bar hand-over`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (`_resolveNative`, `_scheduleNativeSend`, dispose), `liquid_shell/lib/src/native/native_host.dart` (`update` returns the send's future), `liquid_shell/lib/src/pages/page_bar.dart` (`pageBarHeight`)

- [ ] **Step 1: Red tests**, with `autoAck = false` and `attachGate` (pending first), Home a root with `Add`, padding top 62. A `check()` after every pump: the Flutter bar (`find.byType(FlutterPageBar)`) is present ⇔ the fake has not acked (or timed out), no `FlutterTabBar`, and the first row's global y is unchanged.
  - metrics first: attach → pump → padding 116 → pump → `ack()` → pump.
  - ack first: attach → pump → `ack()` → pump → padding 116 → pump.
  - a root without actions: the Flutter bar is never drawn, the layout engages at the ack (scope `nativePageBar` true right after `ack()`).
  - timeout, no ack: after 250 ms the layout engages; timeout, ack but no metrics: the hold ends after 250 ms.
  - the first `engaged: true` config carries `Home` with one action.
- [ ] **Step 2: Run, see red** (`fvm flutter test test/widget/native_pages_test.dart`): the Flutter bar is gone before the ack (today's flip).
- [ ] **Step 3: Implement** (spec §2.2): `pageBarHeight`; layout-engaged with the waiting/holding/done phases and the top hold; `pending` extended; the timer armed on the engaged config's delivery (`update` future), cancelled on end / disengage / dispose.
- [ ] **Step 4: Green**: the file, the whole package suite, `fvm flutter analyze`.
- [ ] **Step 5: Commit** `fix(shell): hand the root bar to native only once native applied the engaged config (VK-1064)`.

### Task 4: Native unanimated engage + XCTest guards

**Files:**
- Modify: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (`RecordingEvents` records states; tests near `testActionsOnARootInlinePageShowTheBar`)
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift` (`apply`, `setChromeVisible`)

- [ ] **Step 1: Red tests.** A dormant-first shell (`config(engaged: false)`, `dartAttached`), then `Add` with no settle: `engagedApplied`, the recorded state acked with the inset already set (iPhone), the bar shown, and no animation keys on `tabs.view.layer` or the navigation bar's layer (the red part). `hidden` toggles: `engagedApplied` stays, no state sent (iPhone); a later show keeps the fade. Characterization (may be green): Flutter top ≈ bar `maxY` with `Add`, the window top without; the late-bar variant.
- [ ] **Step 2: Run, see red** on the own iPhone simulator: `FLUTTER="fvm flutter" tool/ios_xctest.sh <udid> <xcresult> … -only-testing:RunnerTests/NativeTabsTests/<test>`.
- [ ] **Step 3: Implement** (spec §2.3): `engaging` read before `config = new`; `applyPages(new, animated: !engaging)`; `setChromeVisible(..., animated: !engaging)`.
- [ ] **Step 4: Green**: the new tests, then the whole RunnerTests target.
- [ ] **Step 5: Commit** `fix(ios): the first engage shows the native bar without animation (VK-1064)`.

### Task 5: XCUITest geometry guard

**Files:**
- Modify: `liquid_shell/example/ios/RunnerUITests/PagesUITests.swift` (`launch()`)

- [ ] **Step 1:** After the `Add` wait, poll up to 10 s for a settled `Detail 1` row with `minY ≥ navigationBars["Home"].frame.maxY`; fail with both values.
- [ ] **Step 2: Run** PagesUITests on the own simulator (`make ios-ui`-style `-only-testing:RunnerUITests/PagesUITests`).
- [ ] **Step 3: Commit** `test(ios): PagesUITests checks Home's rows sit below its bar at launch (VK-1064)`.

### Task 6: CHANGELOG and wrap-up

**Files:**
- Modify: `liquid_shell/CHANGELOG.md` (`## 0.1.0-dev.13`, one line)

- [ ] **Step 1:** The line; `fvm dart test tool/test` from the repo root (release-version test).
- [ ] **Step 2: Commit** `docs(shell): CHANGELOG line for the root bar hand-over (VK-1064)`.
- [ ] **Step 3:** All packages' tests, `make pigeon-check`, the whole RunnerTests, PagesUITests; delete the simulator by UDID; `git status` clean.
