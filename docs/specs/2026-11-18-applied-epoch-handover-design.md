# The hand-over follows the config native has applied, per config (VK-1074, VK-1075, VK-1082)

Status: approved by the owner on 2026-11-18 (option C and every default of
the decision table in §8, plus B6). Implemented on branch
`VK-1075-engaged-ack` (§10 records what changed on the way). Evidence: `.superpowers/sdd/vk1074-1075-design.md`
in the vankhan ledger dir (not in this worktree): the code trace and a
widget probe of every case below.

## 1. Problem

VK-1064 made the *engage* edge follow native's ack (`engagedApplied`). The
same rule was not applied to the other edges, and the ack is window-wide:
it says that *some* engaged config is applied, not *which*. Probe numbers:
an iPhone, native padding top 116 / bottom 83, Home a `LiquidPage(largeTitle:
false, actions: [Add])`, "row" the y of the first row.

| # | Case | What the user sees | Severity |
|---|---|---|---|
| S-1 (VK-1082) | A shell in standby under a pushed shell (push and pop) | its Flutter page bar under the native one, row at 170 instead of 116, for the whole transition (~500 ms), then a jump | medium |
| 1075-c | A root shell replaced in one frame (key change, shell route swap) with a bar mismatch | no bar for one round trip, an animated native bar, a 54 pt jump | medium on iPad, low on iPhone |
| 1075-a/b | A shell pushed over an engaged one, or popping back to it, with a bar mismatch | the same, during a route transition | low–medium |
| 1074 | A mounted owner disengages (mode off, a `chromeBuilder`, a forced glass tier, a destination without `sfSymbol`) | a double page bar and a double tab bar for one round trip, then a 54 pt jump | low |
| 1075-d | A quick disengage → re-engage | the row at 62 with no bar for one round trip | low |

On iPad, a default root (`largeTitle: null`, no actions) has no native bar
at regular width, so a mismatch only needs an action on the incoming root.

**The ticket's stopgap fails on its own.** "Trust the ack only on the first
state after attach": an owner change produces no state, so a new owner
reads the stale ack, enters waiting (its Flutter bar under a visible native
bar), then holding at `top + 54` under a native bar of the same height,
until the 250 ms fallback. That is worse than today on every owner change.
A per-config ack is needed.

## 2. Decision

### 2.1 The epoch

- `LiquidNativeChromeConfig.epoch` (`int`, default `0`) and
  `LiquidNativeShellState.appliedEpoch` (`int`, default `0`). Both take
  part in `==`, `hashCode` and `toString`. Pigeon: `NativeChromeConfig.epoch`
  and `NativeShellState.appliedEpoch`, each added last.
- `NativeChromeHost` keeps `int _epoch`, starting at **1**: 0 is reserved for
  "not echoed" (§2.3). Every config goes out stamped with the current epoch.
  The epoch is bumped only when a hand-over starts:
  - the owner changes (a claim, or the owner's release);
  - the owner's config flips `engaged`;
  - the dormant config is sent.
- **The forced resend keeps the epoch.** Each state event forces a resend;
  a bump there would cause a state, and so a loop. One state per hand-over.
- **Attach seeds the counter**: `_epoch = max(_epoch, state.appliedEpoch + 1)`
  on the attach answer, so a hot restart (Dart at 1, native still at 7)
  never matches a stale native epoch.
- Deduplication compares the stamped config, epoch included.
- The host keeps the configs it sent by epoch (the last of each), so a shell
  can read the config native applied (`appliedConfig`), for `hidden` and
  for the bar it shows (§2.3).
- A claim exposes `epoch` (the epoch of the config it last sent, null when
  never sent) and `releaseEpoch` (the epoch of the config that replaced its
  engaged one: the dormant one, the next owner's, or its own disengaged
  config; null until that config is sent).

### 2.2 Native

- `NativeTabsController.currentState().appliedEpoch = config?.epoch ?? 0`;
  the installer's not-installed answer reports 0.
- A **takeover** is `new.engaged && (config?.engaged ?? false) && new.epoch !=
  config!.epoch`. `engaging || takeover` → `applyPages(animated: false)`,
  no chrome fade in `setChromeVisible` (the outgoing config may be `hidden`,
  a route covering the old owner), and the pre-ack `layoutIfNeeded` pass.
  Flutter's route transition is the animation (D5).
- A disengage already hides, resets the insets and publishes in one pass
  (Task 0 measured it, §2.6). A scene reconnect re-applies `lastConfig`
  with the same epoch: the state is equal, and the reconnect detection
  through `==` keeps working.
- Android: nothing (no native chrome, no generated Kotlin API).

### 2.3 Dart: signals and phases

Signals, per shell:

- `mine`: `state.engagedApplied && state.appliedEpoch == claim.epoch`.
- `nativeUp`: `state.engagedApplied` and the applied config is not `hidden`
  (`engagedApplied` ignores `hidden`; nothing is on screen under a route
  that covers the old owner).
- `released`: `!state.engagedApplied`, or `releaseEpoch != null &&
  state.appliedEpoch >= releaseEpoch`. An unknown release epoch is not
  released.
- **Epoch 0 in the state** (a platform that does not echo it): `mine =
  engagedApplied` and `released = !engagedApplied`, the dev.13 rule.

Phases (`_Handover`), decided by a pure function (`handoverStep` in
`native_layout.dart`) so they are unit tested apart from the widget:

| Phase | Enter when | Draws | Leaves when |
|---|---|---|---|
| waiting (VK-1064) | engaged, `!nativeUp`, or `nativeUp` with a bar mismatch (D3) | pending layout, Flutter page bar, top held | `mine` → holding/done; 250 ms after delivery |
| holding (VK-1064) | `mine`, top not moved, a Flutter bar | native layout, top = start + Flutter bar | top moves, size changes, 250 ms |
| takeover (new) | engaged, `nativeUp && !mine` | native layout (no Flutter bar), top held at the start | `mine`, size change, 250 ms after delivery |
| done | `mine` | native layout, real insets | disengage |
| releasing (new, VK-1074) | was holding/takeover/done, now config-disengaged, `!released` | native layout kept, top and bottom held | `released` → Flutter layout with the mirror hold; 250 ms after the disengage delivery |

- **Takeover latches**: a state with `!engagedApplied` in between (native
  applied a disengage, then the engage) does not drop it to waiting.
- **A re-engage while releasing goes to takeover**, never waiting: the
  shell never drew Flutter chrome, so it does not start.
- **The attach shortcut goes away.** "Acked at first sight" (hot restart,
  reconnect) is a takeover now, with its top hold; a reconnect's ack with
  my own epoch is `mine` at once (done).
- **Bar mismatch (D3).** From the applied config (`appliedConfig`), its
  selected tab's top page and `state.compact`, `pageTitleModeFor` tells
  whether native shows a bar there. None there and one in mine: waiting
  (the Flutter bar, the VK-1064 path) instead of takeover. With native's
  unanimated takeover the swap is one unanimated round trip.
- **Mirror hold after release.** Flutter layout with `top = start −
  flutterBar` (`pageBarHeight` of the top page) until the metrics move, the
  size changes, or 250 ms pass. Bottom: `_holdBarInset` already holds the
  compact bar's bottom.
- One shared fallback, `kNativeHandoverTimeout` = 250 ms (D7), armed at
  delivery, with the generation guard of VK-1064.

### 2.4 Standby keeps the native page layout (S-1, VK-1082)

A shell in standby (`possible`, not the owner, installed) whose route is
**covered by another route** draws no Flutter page bar (`_nativePageBar =
true`) and keeps its top. Covered: its route's `secondaryAnimation` is not
dismissed. That holds through a pop as well; `_routeCurrent` turns true at
the pop's start and `_coveredByPush` is false during `reverse`. A
same-route nested shell on `auto` (a documented limitation) is not
covered, so its outer pages keep their Flutter bars and back buttons.

### 2.5 What the user sees

| Case | Before | After |
|---|---|---|
| S-1 push/pop | a second bar and a 54 pt jump under the other shell | one bar; the row does not move |
| A shell pushed or replaced, bar on both | the content under the old bar, an animated page swap | the content held; native swaps pages unanimated |
| Bar mismatch at takeover | no bar for one round trip, then an animated bar and a jump | the Flutter bar until mine is applied, one unanimated swap |
| Mounted owner disengages | a double bar and tab bar for one round trip, a jump | native's layout until native hid, then the Flutter bars at the same place |
| Quick off → auto | row at 62, no bar | native's layout kept, row held |

### 2.6 Task 0: the native disengage, measured

GO for D6 (§9): native hides, resets Flutter's frame and insets, then
publishes the disengaged state, in one `apply`.

### 2.7 B6: `LiquidNativeSearchActiveChanged(active: …)`

**Breaking.** The event's positional bool becomes `required bool active`
(`LiquidNativeSearchActiveChanged(active: true)`), and its
`avoid_positional_boolean_parameters` ignore goes. `toString` reads
`LiquidNativeSearchActiveChanged(active: true)`. Every call site moves.
`tool/check_analyze.dart`'s R2 list keeps only the Pigeon DSL file, so on
Flutter stable (3.50) pana scores the platform interface 160/160.

## 3. Out of scope

- A shell disposed with no shell left (logout → a login page without a
  shell): the login page gets native's insets for one round trip; no shell
  is left to hold anything.
- Android: no native chrome.
- A new native animation for the takeover: Flutter's route transition is
  the animation.

## 4. IME and search

- `_search.native` stays config-engaged: false at the disengage edge, true
  at the engage edge, never at an ack. In releasing and takeover only the
  layout differs.
- In standby (S-1) the page bar choice changes a `LiquidPage`'s wrapper; the
  child keeps its `GlobalKey`, so a focused or composing field is never
  rebuilt.
- The forced resend after an epoch's state event does not send search text
  over a composition: `replay(reconnect: false)` returns early on user
  text, and native's `setSearchText` waits out a composition. A widget test
  proves that a composing field gets no `setClient`, `clearClient` or
  `setEditingState` across a takeover, a release and a standby push → pop.
- A takeover's state event is not a reconnect (its state differs), so it
  does not end an active native search.

## 5. Tests

- **Interface / iOS Dart**: the new fields default to 0 and take part in
  `==`, `hashCode`, `toString`; `configToNative` maps `epoch`,
  `stateFromNative` maps `appliedEpoch`; B6's named constructor.
- **Host** (`native_host_test.dart`): every bump and non-bump of §2.1, the
  dedup, the attach seed, `claim.epoch` and `releaseEpoch`. The fake
  (`FakeNativePlatform`) gets a native model: applying a config pushes a
  state with `engagedApplied` and `appliedEpoch` from it, deduplicated like
  `publishState`.
- **Phase function** (`native_layout_test.dart`): the phase table.
- **Widget** (`native_pages_test.dart`, invariant after every pump: Flutter
  bar ⇔ phase, row y): push, pop, root replaced, quick off → auto, hot
  restart, the takeover latch, D3, takeover over `hidden`, epoch 0, the
  fallback, the generation guard; S-1 push/pop and its gate; releasing in
  both arrival orders, its fallback, a destinations flap, re-engage while
  releasing; IME across takeover, release and standby.
- **RunnerTests**: `appliedEpoch` follows the applied config; a takeover
  applies pages unanimated and acks with the inset set (iPhone); the same
  epoch keeps the animation; a takeover from `hidden` shows the chrome with
  no fade; `hidden` toggles send no state; a reconnect re-applies
  `lastConfig` with an equal state; Task 0's disengage order.

## 6. CHANGELOG and versions

`0.1.0-dev.14` for all four packages (podspec and example pubspecs
follow). `liquid_shell`: "Fixed" lines (S-1, takeover, disengage).
`liquid_shell_platform_interface`: "Changed (breaking)" for B6, and the new
fields with the reserved epoch 0 for implementers. `liquid_shell_ios`:
"Changed": the channel's new fields, the unanimated takeover. Android: the
version bump. `liquid_shell` requires the dev.14 interface.

## 7. Verification

`fvm flutter test` in `liquid_shell`, `liquid_shell_platform_interface`,
`liquid_shell_ios`; `fvm dart test tool/test`; `make pigeon-check`; `make
analyze` on 3.44.9 and 3.47.9 and `make analyze-stable` on 3.50.0; `make
provenance`; `make public-docs`; RunnerTests on an own iPhone 17 Pro and
iPad simulator (iOS 26.5), deleted afterwards; `.githooks/pre-commit`
before every commit; pana on 3.50.0 for the interface.

## 8. Decisions

| # | Question | Chosen |
|---|---|---|
| D1 | One change or two | one (closes VK-1074, VK-1075, VK-1082) |
| D2 | Primitive | config `epoch` + state `appliedEpoch` |
| D3 | Bar mismatch at takeover handled in Dart | yes |
| D4 | S-1 | in this change, sub-issue VK-1082 |
| D5 | Native takeover | unanimated |
| D6 | Disengage hold | yes if Task 0 confirms |
| D7 | Fallback | 250 ms, shared |
| D8 | Release | `0.1.0-dev.14`, all four |
| D9 | Epoch 0 | reserved for "not echoed" |
| B6 | `LiquidNativeSearchActiveChanged` | named `required bool active`, breaking |

## 9. Task 0 measurement

`RunnerTests/NativeTabsTests/testTheDisengageHidesAndResetsFlutterBeforeItsState`
(own simulators, iOS 26.5): engage Home with `Add`, settle, apply the
dormant config, and read the controller inside `onStateChanged` for the
first state with `engagedApplied == false`.

| Device | `additionalSafeAreaInsets` at the state | Flutter frame | chrome hidden | Flutter safe top at the state / window / settled |
|---|---|---|---|---|
| iPhone 17 Pro | `.zero` | root bounds | yes | 62.0 / 62.0 / 62.0 |
| iPad Air 11-inch (M4) | `.zero` | root bounds | yes | 32.0 / 32.0 / 32.0 |

**Verdict: GO.** Everything native changes for a disengage is set before
the state that says so is sent, and UIKit has already recomputed the safe
area by then. Flutter's metrics still reach Dart on the engine's own path
(the next layout pass), so either order can arrive in Dart: the releasing
phase handles both.

**Round trip, end to end** (the example's `pages` demo on the iPhone 17 Pro
simulator, iOS 26.5, debug build; a temporary, uncommitted `debugPrint` in
the host at each send and each state; the app flipped to a forced glass
tier after 4 s, the claim kept, and back after 3 s). Every config's epoch
came back as `appliedEpoch`:

| Config | Epoch | Send → state |
|---|---|---|
| pending (not engaged), cold launch | 2 | 159.5 ms |
| first engage, cold launch | 3 | 53.1 ms |
| disengage (forced tier, claim kept) | 4 | 2.5 ms |
| re-engage | 5 | 8.4 ms |

Warm, the disengage round trip is a few milliseconds: well inside the
250 ms fallback, which stays a fallback.

## 10. As built

- **D3, as a takeover with the Flutter bar.** Where the engaged config
  native shows has no page bar there, the new owner still takes over
  (native's layout: chrome kind, size class, a tiled sidebar's body offset
  all unchanged) and only lets LiquidPage draw its own bar, latched for the
  takeover; mine applied, it hands the bar over through holding (top =
  start + bar until the metrics move). "And mine has one" is not asked: the
  incoming shell's page registers after its first build, and a page
  without a bar draws none anyway. Waiting (the pending layout) stays for
  "nothing engaged on screen" (none, or a hidden config). A first cut sent
  the mismatch to waiting, which moved an iPad tiled body by the sidebar's
  width for a bar-less to bar-less owner change (caught by review, tested).
- **S-1 rule.** A covered standby shell drops its Flutter bar only while
  native shows a page bar there (and its config is not hidden); over a
  shell whose root has no bar it keeps its own, so its page is never
  without one. The cover is latched until the shell owns the chrome
  again: a popped route is dismissed a frame or more before its shell is
  disposed and gives the chrome back.
- **Epoch 0 and release.** With epoch 0 (not echoed) a release is taken
  as done at once and no mirror hold follows (the dev.13 rule: the Flutter
  layout at the real top), so a platform that does not echo never waits
  250 ms on a disengage.
- **Tests** live in `liquid_shell/test/widget/native_handover_test.dart`
  (widget), `test/unit/native_handover_test.dart` (the phase step) and
  `test/unit/native_host_test.dart` (the host), beside the VK-1064 tests
  in `native_pages_test.dart`, which are unchanged.
- **Residual.** The mirror hold is for the top only. In the ack-first
  order the Flutter tab bar sits above the home indicator by the native
  bar's height for the round trip until Flutter's metrics drop: Dart does
  not know the window's own bottom inset then. Native is already hidden,
  so there is no double tab bar.
- **Example.** The `pages` case's Settings opens "A shell over this one",
  a full-screen route with its own shell.

