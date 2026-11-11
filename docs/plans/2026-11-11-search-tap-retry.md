# Search ⌕ Tap Retry (VK-1063) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `typeAboveTheCaseList` in SearchUITests taps the Flutter ⌕ a second time, recorded, when the first tap opened no search and Home is still selected, so that a dropped tap on a loaded CI runner stops failing the test.

**Architecture:** Test-only Swift in `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`. Spec: `docs/specs/2026-11-11-search-tap-retry-design.md`. Evidence: `.superpowers/sdd/vk1063-investigation.md` (untracked; it is in the vankhan ledger dir, not in this worktree).

**Tech Stack:** XCUITest, Xcode 27.1, iOS 26.5 simulator, `tool/ios_xctest.sh`.

## Global Constraints

- Test file only. No `tapWhenSettled`, no other suites, no `tool/` changes.
- One retry, recorded with `XCTContext.runActivity(named: "VK-1063: retry the ⌕ tap (the first was dropped)")` plus a `print`. The `"a field"` assertion with its 10 s wait stays.
- Simulators: create your own and delete it by UDID. Never touch the protected ones (572B92E2, 383C4573, C428FE39, D3A948FD, B7246683). Never `simctl shutdown all` or `erase all`. No physical devices.
- Run `.githooks/pre-commit` manually and check its exit status before committing; never `--no-verify`. `git add` explicit paths only; no `.superpowers/` in the worktree.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: One recorded retry of the ⌕ tap

**Files:**
- Modify: `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift` (`typeAboveTheCaseList`, ~:296-308)

- [ ] **Step 1: Wait 5 s for the field.** Replace the direct 10 s wait after `tab.tap()` with `either.waitForExistence(timeout: 5)`.

- [ ] **Step 2: Retry.** If that wait fails and `tabButton(app, "Home")` exists and `isSelected`, run the `VK-1063` activity with a `print` and `tab.tap()` once.

- [ ] **Step 3: Keep the assertion.** `XCTAssertTrue(either.waitForExistence(timeout: 10), "a field")` stays after the retry.

- [ ] **Step 4: Local run.** Create an iPhone 17 Pro iOS 26.5 simulator and check that `simctl create` exits 0. Run `SearchUITests` through `tool/ios_xctest.sh` (see the Makefile). Expected: 0 failed. Delete the simulator. Keep disk >= 10 GB free.

- [ ] **Step 5: Hook and commit.** Run `.githooks/pre-commit`, check exit 0. Commit the Swift file, the spec and this plan: `test(ios): retry a dropped ⌕ tap in the Flutter search edge-swipe test (VK-1063)`.
