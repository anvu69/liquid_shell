# Mirror bottom hold (VK-1086) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** during the ack-first disengage mirror, the body's bottom safe area is the window's (34 pt on an iPhone), not native's 83, so raw `MediaQuery.padding/viewPadding.bottom` readers do not jump 49 pt.

**Architecture:** spec `docs/specs/2026-11-19-mirror-bottom-hold-design.md`. Dart only: two fields and a widened mirror hold in `liquid_shell/lib/src/shell/liquid_shell.dart`.

**Tech Stack:** fvm (3.44.9 floor, 3.47.9 pinned), `flutter_test`, GNU make.

## Global Constraints

- Branch `VK-1086-mirror-bottom`. No push, no tag, no publish, no version bump.
- TDD: each red test shown failing for the right reason before the code.
- `analysis_options.yaml` untouched.
- `.githooks/pre-commit` by hand before every commit, exit 0; explicit `git add` paths.
- Commit: `<type>(shell|docs): <summary> (VK-1086)` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Guards (green before and after)

**Files:** Modify `liquid_shell/test/widget/native_handover_test.dart` (group `VK-1074: …`)

- [ ] **Step 1:** `rotated between the engage and the disengage: the mirror holds no bottom` (`iosDevice`): engage at `kPhone`, rotate to `kPhoneLandscape` with native insets, disengage through a notifier (no `pumpShell` reset), ack first: the body bottom equals the metrics' own.
- [ ] **Step 2:** `a takeover start never saw the window: the mirror holds no bottom` (`iosDevice`): the hot-restart attach of the VK-1075 group, mine applied, then off and ack first: body bottom 83.
- [ ] **Step 3:** `mode off, metrics first: …` also asserts body bottom 34 at `released`.
- [ ] **Step 4:** Run, green. Pre-commit; commit `test(shell): guards for the mirror's bottom (VK-1086)`.

### Task 2: Red tests

**Files:** Modify `liquid_shell/test/widget/native_handover_test.dart`

- [ ] **Step 1:** Replace the skipped known gap with `ack first on an iPhone: the mirror frame's body sees the window's bottom safe area, and the tab bar does not move` (`iosDevice`): body padding / view padding bottom 34 in the mirror frame, the `LiquidTabBar` rect equal to the settled one (bottom 831), `contentPaddingOf(...).bottom` unchanged.
- [ ] **Step 2:** `ack first with the keyboard up: the mirror holds viewPadding.bottom at the window's, padding stays 0, viewInsets kept` (`iosDevice`), the view set directly.
- [ ] **Step 3:** An `iosDevice` IME test: `a composing field keeps its state, focus and composing range through a mirror hold with the bottom held (iOS)`; asserts body bottom 34 in the mirror frame.
- [ ] **Step 4:** Run `fvm flutter test test/widget/native_handover_test.dart`; expect `Expected: <34.0> Actual: <83.0>`.

### Task 3: The hold

**Files:** Modify `liquid_shell/lib/src/shell/liquid_shell.dart`

- [ ] **Step 1:** Fields `_windowBottom` (`double?`), `_windowBottomSize` (`Size?`) beside `_handoverBottom`.
- [ ] **Step 2:** Record in `_buildLayout` when `_handover == NativeHandover.none` (raw `MediaQuery.of(context)`), and in `_handOver` when `previous == none` and the restart is to `waiting`.
- [ ] **Step 3:** `_holdMirrorTop` → `_holdMirror` with the bottom rule, guarded by `_handoverSize` and `_windowBottomSize`.
- [ ] **Step 4:** Run the file, then the whole package: green, one skip left (the hot-restart hidden-config gap).

### Task 4: Docs

**Files:** Modify `docs/specs/2026-11-18-applied-epoch-handover-design.md`; `liquid_shell/CHANGELOG.md` (see below)

- [ ] **Step 1:** §2.3: the bottom sentence names the mirror's bottom hold, not `_holdBarInset`.
- [ ] **Step 2:** §10: the "Residual" bullet becomes the as-built rule and the iOS note.
- [ ] **Step 3:** CHANGELOG `## Unreleased` "Fixed" line, if `tool/test/release_version_test.dart` accepts the heading; otherwise stop and report (it does not: spec §7).
- [ ] **Step 4:** Pre-commit; commit `fix(shell): the mirror hold keeps the window's bottom safe area (VK-1086)` with Tasks 2–4.

### Verification

`fvm flutter test` in `liquid_shell`; `make analyze`; `make analyze-stable`; `make format-check`; `make public-docs`; `make provenance`; `.githooks/pre-commit`.
