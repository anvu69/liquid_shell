# White Launch Relaunch (VK-1081) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A launch whose Flutter UI is never displayed (the white launch behind the `MinimizeUITests.testAPushedPageOnHomeMinimizesTheBar` flake) is logged, recorded and relaunched once by the UI tests, on a positive signal; a launch that stays white still fails.

**Architecture:** Plugin: one `#if DEBUG` `NSLog` in `NativeShellInstaller.install`. Example app: a KVO probe on `FlutterViewController.displayingFlutterUI` drives a hidden window label (`flutterUIProbe`) whenever `LIQUID_SHELL_EXAMPLE_DEMO` is set. UI tests: `tapWhenSettled` reports the real frame; a shared `launchShowingFlutter` waits for the probe after the caller's readiness wait and relaunches once, recorded. Spec: `docs/specs/2026-11-18-white-launch-relaunch-design.md`. Evidence: `.superpowers/sdd/vk1081-design.md` (vankhan ledger dir, untracked, not in this worktree).

**Tech Stack:** Flutter 3.47.9 (fvm), Swift / XCTest / XCUITest, Xcode 27.1, iOS 26.5 simulator.

## Global Constraints

- No product behaviour change: the plugin gains a DEBUG log only; the probe is example-only and never touches `flutter.view`.
- No CHANGELOG line (DEBUG log and test code; the VK-1046 precedent).
- New Swift goes into existing files (the pbxproj uses explicit file references).
- Run `.githooks/pre-commit` by hand before every commit and check exit 0; never `--no-verify`. `git add` explicit paths only.
- Commit: `<type>(<scope>): <summary> (VK-1081)` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Simulators: own ones, deleted by UDID at the end; never the protected ones (572B92E2, 383C4573, C428FE39, D3A948FD, B7246683), never `shutdown all` / `erase all`.
- Out of scope: the product fix (follow-up, D4), VK-1083 (Failed to terminate).

---

### Task 1: `tapWhenSettled` reports the real frame

**Files:**
- Modify: `liquid_shell/example/ios/RunnerUITests/UITestWaits.swift`

- [ ] **Step 1: Red (throwaway, not committed).** A UI test aims `tapWhenSettled` (timeout 2 s) at an element that exists and is never hittable, inside `XCTExpectFailure` whose issue matcher requires `hittable false` and a frame that is not `(inf, inf, 0.0, 0.0)`. Run it: red, the message prints the sentinel.
- [ ] **Step 2: Implement.** Track `lastHittable`; on failure print `frame <element.frame | none>` (read behind `exists`) and `last sample hittable <bool>`. The settle logic is unchanged.
- [ ] **Step 3: Green.** The throwaway test passes; remove it.
- [ ] **Step 4: Commit** `test(ios): tapWhenSettled reports the element's real frame (VK-1081)`.

### Task 2: DEBUG install log

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellInstaller.swift` (`install`)

- [ ] **Step 1:** Before `window.rootViewController = nil`, under `#if DEBUG`: `NSLog("[liquid_shell] install: view loaded %d, in window %d, scene %@", …)` from `isViewLoaded`, `viewIfLoaded?.window != nil` and `window.windowScene?.activationState`. No TDD for a log line; the installer's XCTests stay green (`make ios-unit`).
- [ ] **Step 2: Commit** `chore(ios): DEBUG log of the Flutter view's state at install (VK-1081)`.

### Task 3: The example's Flutter-UI probe

**Files:**
- Modify: `liquid_shell/example/ios/Runner/AppDelegate.swift`
- Modify: `liquid_shell/example/ios/RunnerUITests/PagesUITests.swift` (new test)

- [ ] **Step 1: Red.** `testTheFlutterUIProbeReadsDisplayed`: a `pages` launch, then `app.staticTexts["flutterUIProbe"]` reads `flutterUI: displayed` within 20 s. Run: red, the label does not exist.
- [ ] **Step 2: Implement** `FlutterUIProbe` (spec §2.3): armed in `didFinishLaunching` when `LIQUID_SHELL_EXAMPLE_DEMO` is set; on `UIScene.didActivateNotification` it finds the Flutter controller (root or descendant), KVO with `.initial`, label + `[liquid_shell] example:` log.
- [ ] **Step 3: Green**, then the probe read once on the `tabs`, `minimize` and `search` demos (throwaway) and on the iPad simulator.
- [ ] **Step 4: Commit** `test(example): a Flutter-UI-displayed probe for UI tests (VK-1081)`.

### Task 4: `launchShowingFlutter` and the gated relaunch

**Files:**
- Modify: `liquid_shell/example/ios/RunnerUITests/UITestWaits.swift`
- Modify: `liquid_shell/example/ios/RunnerUITests/MinimizeUITests.swift`, `PagesUITests.swift` (`launch`)

- [ ] **Step 1: Red (scaffolding, not committed).** Force the probe to read "not displayed" on the first launch only: expect one `VK-1081: relaunch` activity, then green. Forced on every launch: one relaunch, then `Flutter UI never displayed (twice)`. Today neither suite relaunches: red.
- [ ] **Step 2: Implement** spec §2.4: `launchShowingFlutter(demo:ready:)` with the 20 s wait after `ready`, a missing label failing at once, one recorded relaunch; `waitRowBelowBar` moved from PagesUITests; both suites' `launch` call the helper (MinimizeUITests' `pages` launch gains the row-below-bar settle).
- [ ] **Step 3: Green** with both scaffoldings (the activity and screenshot in the xcresult), then revert the scaffolding.
- [ ] **Step 4: Commit** `test(ios): relaunch once when Flutter's UI is never displayed (VK-1081)`.

### Task 5: Verify

- [ ] `make verify`; `make ios-unit`, `make ios-ui`, `make ios-minimize` on the own iPhone 17 (iOS 26.5); PagesUITests on the own iPad; no relaunch activity on the green runs; both `[liquid_shell]` lines in the simulator log under the `applog` predicate.
- [ ] Evidence to `.superpowers/sdd/vk1081-report.md` (vankhan ledger dir). No push.
