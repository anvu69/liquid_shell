# The mirror hold keeps the window's bottom safe area (VK-1086)

Status: approved by the owner on 2026-11-19 (option A and every default of
the decision table in §6). Branch `VK-1086-mirror-bottom`, from
`0.1.0-dev.14`. Evidence: `.superpowers/sdd/vk1086-design.md` in the
vankhan ledger dir (not in this worktree): the code trace and a widget
probe of every case below.

## 1. Problem

The follow-up to VK-1074 (spec 2026-11-18 §10, "Residual") said that in the
ack-first disengage the Flutter tab bar sits 49 pt too high for one round
trip. On an iOS device it does not. The skipped test's 761 came from the
test harness: the VK-1074 group runs on the default test platform
(Android), where `bottomGapFor` (VK-702) is `max(21, viewPadding.bottom +
8)`. On iOS the gap is a constant 21 and the tab bar is at the same place
in the mirror frame, after the metrics drop and settled.

What is real on iOS: in the mirror frame the body's
`MediaQuery.padding.bottom` and `viewPadding.bottom` are still native's 83
(the window's 34 + the 49 pt native bar) instead of the window's 34. App
content that reads the raw safe area (`SafeArea(bottom:)`, a `ListView`
with no `padding`, a footer) jumps 49 pt for a few ms. The package's own
`LiquidShellScope.contentPaddingOf` does not change (83 on iOS either way).

Probe (iPhone 393×852, window 62/34, native 116/83, Home with Add):

| Platform | Order | Frame | tab bar | body pad / viewPad | content |
|---|---|---|---|---|---|
| Android (harness default) | ack first | mirror | 699–761 | 83 / 83 | 153 |
| iOS | ack first | mirror | 769–831 | **83 / 83** | 83 |
| iOS | ack first | metrics dropped | 769–831 | 34 / 34 | 83 |
| iOS | metrics first | released | 769–831 | 34 / 34 | 83 |
| iOS, keyboard (viewInsets 336) | ack first | mirror | 769–831 | 0 / **83** | 83 |
| iOS, keyboard | ack first | metrics dropped | 769–831 | 0 / 34 | 83 |

Only `liquid_shell_ios` reports `engagedApplied`, so the mirror only ever
runs on an iOS device.

## 2. Decision (option A)

Hold the body's bottom during the mirror at the window bottom last seen at
this size.

- **What is saved.** `_windowBottom` (`double?`) and `_windowBottomSize`
  (`Size?`): the raw `viewPadding.bottom` and the size of the Flutter
  layout's own metrics. Recorded
  1. in `_buildLayout` on every Flutter-layout frame in phase `none`, from
     the raw `MediaQuery.of(context)`, and
  2. in `_handOver` on the `none → waiting` restart (a cold-launch engage
     happens before any Flutter frame; the metrics are still the window's).

  Never from a takeover, a waiting start out of `mirror` or `releasing`, or
  native layout: those already carry native's 83.
- **The hold.** `_holdMirrorTop` becomes `_holdMirror`. In `mirror`, with
  `media.size == _handoverSize == _windowBottomSize`:
  - `viewPadding.bottom = min(media.viewPadding.bottom, _windowBottom)`
    (it only ever lowers);
  - `padding.bottom = max(0, that − media.viewInsets.bottom)`, the rule of
    `_holdBarInset`;
  - `viewInsets` as they are.
  The top hold is unchanged.
- **No saved value, or another size** (rotated while engaged, a takeover or
  hot-restart start that never saw the window): no bottom hold, today's
  behaviour.
- **End.** The hold ends with the mirror (top moved, size changed, 250 ms).
- Dart only: no Pigeon, interface or iOS change.

## 3. Out of scope

- The row shift seen on iPad and phone-landscape probes with invented
  insets (decision 8): not measured, a separate ticket if wanted.
- Moving the rest of the VK-1074 group to `iosDevice` (decision 6).
- A native `windowSafeArea` field (option C).

## 4. IME

The change is `MediaQuery`-only; the tree shape is unchanged. An
`iosDevice` run of the IME hand-over test asserts the same
`EditableTextState`, focus and composing range in the mirror frame (with
the bottom held) and after the metrics drop, and no `setClient`,
`clearClient` or `setEditingState` from the shell.

## 5. Tests (`liquid_shell/test/widget/native_handover_test.dart`)

- The skipped known gap becomes `ack first on an iPhone: the mirror frame's
  body sees the window's bottom safe area, and the tab bar does not move`
  (`iosDevice`): body padding and view padding bottom 34, the tab bar rect
  equal to the settled one (bottom 831), `contentPaddingOf` unchanged. Red:
  `Expected: <34.0> Actual: <83.0>`.
- `ack first with the keyboard up: the mirror holds viewPadding.bottom at
  the window's, padding stays 0, viewInsets kept` (`iosDevice`).
- Guards, green before and after: `rotated between the engage and the
  disengage: the mirror holds no bottom`, `a takeover start never saw the
  window: the mirror holds no bottom`.
- `mode off, metrics first: …` also asserts body bottom 34 at `released`.

## 6. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Scope | A: hold the body's bottom safe area in the mirror |
| 2 | Source of the window bottom | the last Flutter-layout frame (phase `none`) or the `none → waiting` start, keyed by size |
| 3 | No saved value, or another size | no bottom hold |
| 4 | Hold shape | `viewPadding.bottom = min(real, saved)`, `padding.bottom = max(0, that − viewInsets.bottom)`, `viewInsets` untouched |
| 5 | Red test | the skipped known gap rewritten under `iosDevice` |
| 6 | The VK-1074 group's platform | left on the default; new tests use `iosDevice` |
| 7 | Release | no version bump; a "Fixed" line under `## Unreleased` in `liquid_shell/CHANGELOG.md` |
| 8 | iPad / landscape top movement | out of scope |

## 7. CHANGELOG

Decision 7's line, for `liquid_shell/CHANGELOG.md`:

> - Fixed: with native chrome, a shell leaving it no longer gives its pages
>   native's tab bar inset (83 pt on an iPhone) as their bottom safe area
>   for the moment before Flutter's metrics follow; `SafeArea` and
>   `MediaQuery.paddingOf` keep the window's bottom. The tab bar itself
>   never moved.

As built: not added. `tool/test/release_version_test.dart` ("each
CHANGELOG has a heading for the version, nothing older above") accepts only
a newer `-dev.N` heading above the current version, so `## Unreleased`
turns `make test` red. Left for the owner (§8).

## 8. As built

- The CHANGELOG line (§7) is pending an owner call: a `## 0.1.0-dev.15`
  heading (the shape the test allows) or a test change.
- Spec 2026-11-18 §2.3 and §10 are corrected: the bottom is held by this
  rule, not by `_holdBarInset`, and the residual's 761 was the Android test
  platform.
- The hold lowers only (`window < real`); otherwise the bottom passes
  through untouched. A takeover start that recorded native's 83 would hold
  83, the same as no hold, so the takeover guard checks the outcome (83).
  The rotation guard fails without the size check (measured: 34 instead of
  70).
- Rotation and keyboard tests flip the mode through a `ValueNotifier`, not
  `pumpShell`, which would reset the view's size and padding.

## 9. Verification

`fvm flutter test` in `liquid_shell`, `make analyze`, `make analyze-stable`,
`make format-check`, `make public-docs`, `make provenance`,
`.githooks/pre-commit`. No Swift change, so no RunnerTests.
