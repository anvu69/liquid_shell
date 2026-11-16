# The root page bar is handed over to native only once native shows it (VK-1064)

Status: approved by the owner on 2026-11-13 (approach A, the unanimated
first engage, the out-of-scope list and the regression guards below).

## 1. Problem

At launch, a root page with actions (VK-443's `Add` on the `pages` demo's
Home) shows **no bar at all** for about 75 ms (493 ms on a cold first
launch), then its rows jump 54 pt. Dart flips its layout to native (drops
its own Flutter page bar) in the build of the same frame whose post-frame
callback sends the first `engaged: true` config. Native cannot show its bar
before that config arrives, so at least one frame has neither bar, then
the 54 pt top inset arrives and the content moves.

The first engaged config already carries Home and its action; sending it
"earlier" only turns the gap into a race (design §4 C). The root cause is
that one predicate, `engaged` (`state.installed`), decides both the config
and the layout.

Evidence: `.superpowers/sdd/vk1064-design.md` in the vankhan ledger dir
(not in this worktree): the code path, a widget probe, and simulator logs.

## 2. Decision

### 2.1 Native confirms the engaged config: `engagedApplied`

- Pigeon `NativeShellState` gets `bool engagedApplied` (required), and
  `LiquidNativeShellState` gets `final bool engagedApplied` (default
  `false`), in `==`, `hashCode` and `toString`. The equality matters: the
  ack must not look like a reconnect to `_search.replay` (an equal state is
  a reconnect, which ends an active search).
- `NativeTabsController.currentState()` sets it from the applied config:
  `config?.engaged ?? false`. Not from `chromeVisible`: that flips with
  `hidden` (dialogs) too, and every state change costs a forced config
  resend in Dart. The installer's not-installed answer says `false`.
- It reaches Dart as the existing `onStateChanged` event (deduplicated by
  `publishState`), at the end of `apply` → `syncFlutter`. Native → Dart
  stays events only.

### 2.2 Dart: two meanings of engaged

`_resolveNative` keeps `engaged` (config-engaged) for what native must
know: the config and its page stacks, `_nativeEngaged`, `_search.native`,
the minimize and the route-covered search end. The ack never drives the
search's `native` setter, whose false branch writes the Flutter field.

A new *layout-engaged* decides what Dart draws: `_nativePageBar`, the
chrome `kind`, the `sizeClass`, the hidden-selection report, the scope's
`nativeChrome` and the window controls. Until it holds, the shell keeps the
pending layout (no Flutter chrome; `LiquidPage` draws its Flutter bar), so
`pending` extends to "engaged, not handed over yet" and the build never
falls through to the Flutter-chrome layout.

The hand-over runs only when the shell sees an installed state that is
not acked while engaged (a launch, the Flutter → native switch, a hot
restart before native has shown anything). A state that is acked at first
sight (a reconnect, a hot restart over a shown chrome) engages the layout
at once, as today. Once done, the hand-over stays done until `engaged`
turns false.

Phases:

| Phase | When | Flutter page bar | Body top |
|---|---|---|---|
| waiting | engaged, not acked | drawn | held at the top seen when the hand-over started (metrics that arrive first do not move the bar) |
| holding | acked, the top has not moved yet, the top page has a Flutter bar | dropped | held at that top + the Flutter bar's height: the content stays where it was, under the native bar now up |
| done | acked and the top moved, or the top page has no Flutter bar, or the timeout | dropped | the real top |

So "Flutter bar present ⇔ not acked" holds on every frame, and the first
row does not move: not before the ack (metrics first), not after it (ack
first). The bar's height comes from one helper in `page_bar.dart`
(`pageBarHeight(mode)`), used by `FlutterPageBar` too; the top page's mode
is `pageTitleModeFor` of its record, with the pending layout's size class.
A new window size ends the hold, as `_holdBarInset` does.

**Fallback timeout: 250 ms**, so a lost update (the ack or the metrics)
never pins either hold. It is armed when the first engaged config's
`updateNativeChrome` completes (native has applied it then), not at the
start of the hand-over: the cold launch spends up to ~500 ms before native
receives the config, which a timer from the start would cut short into
the very gap this fixes. A platform that never acks (an older or
third-party implementation) engages 250 ms after native applied the
config. The timer is cancelled when the hand-over ends, on disengage and
on dispose.

`NativeChromeClaim.update` returns the platform call that delivers the
config (null when nothing listens), so the shell can arm the timer. A
config the host dedups returns the earlier send's call: a rebuild while the
first engaged config is still on its way must not start the clock.

### 2.3 Native: the first engage is not animated

In `apply`, an *engage* is a config with `engaged: true` while the applied
config (`config`, read before it is replaced) was not engaged or absent.
On an engage, `applyPages(new, animated: false)` shows the navigation bar
at once, and `setChromeVisible` skips its 0.2 s alpha fade (the fade is on
the whole chrome view, so the tab bar appears at once too). Shown without
animation, UIKit lays the bar out only on its next pass, after `apply`'s
state has acked (measured: the ack went out with Flutter's top still at
62), so an engage lays the selected tab out (`layoutIfNeeded`) before the
final `syncFlutter`: on the iPhone inline root the ack again goes out with
the 54 pt inset already set. The pass lays out the tab controller's own
view, then the tab. While `apply` runs, `publishState` holds back, and
`apply`'s final `syncFlutter` sends the state once: on a regular iPad a
layout pass inside `apply` ran before the navigation controller had its new
safe area, and the ack went out with a 150 pt top that settled at 86 pt in
the same `apply` (measured). Dart does not rely on that order (§2.2). A show after a
hide (a dialog's `hidden` toggling back) keeps the fade, and later page
changes keep their animation. At launch this is the first engage; a
Flutter → native switch is an engage too, because it also hands over from
a Flutter bar.

### 2.4 What the user sees

The Flutter bar stays until native has applied the config; the native bar
then composites over it at the same place (one round trip, ~25 ms, with
both bars drawn at the same position), and Dart drops its own. There is
always one bar, and the content does not jump. A large-title root still
moves by the difference between the Flutter and the native large title
(under 1 pt on the measured iPhone).

## 3. Out of scope (ticketed)

- **VK-1074**: the disengage mirror (native → Flutter: Dart draws its bar
  at once while native still adds its inset until its disengage config
  lands).
- **VK-1075**: a per-owner ack (for example a config sequence number or the
  owner echoed in the state) for **any owner change or quick re-engage**:
  a pushed shell popping back to its owner (standby → engaged), a shell
  pushed over an engaged one, a root shell replaced (onboarding → main,
  logout → login), and a disengage → re-engage before native's
  `engagedApplied: false` arrives. `engagedApplied` is window-wide: the
  previous owner's engaged config is still applied, so the new shell takes
  the "acked at first sight" path and engages at once, as before this
  change.

## 4. Tests

- **Dart widget** (`liquid_shell/test/widget/native_pages_test.dart`): the
  fake (`FakeNativePlatform`) stamps `engagedApplied: true` on its answers
  by default, so existing tests keep their behaviour; `autoAck = false`
  holds the ack, `ack()` sends it. Asserted on every pump: Flutter bar
  present ⇔ not acked, and the first row's y never changes. Both arrival
  orders (metrics → ack, ack → metrics), a root without actions (done at
  the ack), the 250 ms timeout with no ack and with no metrics, the
  pending → installed path never drawing Flutter chrome, and the first
  `engaged: true` config still carrying Home's action.
- **Platform interface / iOS Dart**: equality and `toString` include
  `engagedApplied`; `stateFromNative` maps it.
- **RunnerTests XCTest** (`RunnerTests.swift`):
  `testActionsOnARootInlinePageShowTheBar` also asserts the Flutter view's
  top ≈ `nav.navigationBar.frame.maxY` (±0.5) with `Add`, and the window's
  top without actions; a "late bar" variant (no actions first, then `Add`);
  the first engage acks with `currentState().engagedApplied`, sends that
  state with the 54 pt inset already set (iPhone), shows the bar with no
  animation on the chrome view or the bar; `hidden` toggles neither change
  `engagedApplied` nor send a state (iPhone); a later show still fades;
  the dormant config reports `false`. The geometry guards may be green
  on arrival: they are characterization tests (the bug is in Dart).
- **XCUITest** `PagesUITests.launch()`: after the `Add` wait, poll up to
  10 s until a settled `Detail 1` row has `minY ≥` Home's bar `maxY`. A
  test of the ~75 ms window itself would need a DEBUG hook holding the ack
  in native *and* one disabling the 250 ms Dart fallback (which caps any
  native hold), so it is not added (owner decision 4c fallback).

## 5. CHANGELOG

`liquid_shell/CHANGELOG.md`: `0.1.0-dev.12` is released (tagged), so a new
`## 0.1.0-dev.13` heading, as VK-938 did for dev.12, with one line: a root
page with actions no longer shows a frame without a bar, nor a 54 pt jump,
when native chrome engages.

## 6. Verification

`fvm flutter test` in `liquid_shell`, `liquid_shell_platform_interface` and
`liquid_shell_ios`; `make pigeon-check`; the `tool/test` suite from the repo
root; RunnerTests (the changed tests, then the whole target) and
PagesUITests on an own iPhone simulator (iOS 26.5); `.githooks/pre-commit`
before every commit.
