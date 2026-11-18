# A white launch is recorded and relaunched once (VK-1081)

Status: approved by the owner on 2026-11-18 (every default of the decision
table: D1 (b) instrument plus a gated relaunch, no product fix; D2 (a) the
example's `displayingFlutterUI` probe; D3 one recorded relaunch; D4 the
product question is a follow-up triggered by evidence; D5 the probe lives in
the example only; D6 on whenever `LIQUID_SHELL_EXAMPLE_DEMO` is set; D7 one
`#if DEBUG` install log in the plugin; D8 `tapWhenSettled` reports the real
frame; D9 "Failed to terminate" is VK-1083; D10 no
`-retry-tests-on-failure`).

## 1. Problem

`MinimizeUITests.testAPushedPageOnHomeMinimizesTheBar` fails on CI about once
per 26 launches with `Home's Detail 1 row: not settled after 10.0 s (exists
true, hittable false, frame (inf, inf, 0.0, 0.0))`. The recording of the
failing run shows UIKit's chrome (status bar, Home's bar with `+`, the tab
bar) over a blank white screen for the whole test: not one Flutter pixel.
Dart ran (it built Home's semantics and sent the engaged config), but the
Flutter UI was never displayed, most likely because the launch storyboard's
splash over the Flutter view was never removed. The row exists in the
semantics tree and is never hittable; no tap is ever sent.

- `(inf, inf, 0.0, 0.0)` is `CGRect.null`, the helper's "last sample was not
  hittable" sentinel, not the row's frame.
- Why no first frame was displayed is not known: the engine's first frame on
  the simulator (A) or the plugin's re-parenting at install (B). The app log
  has no line for the launch, so the artifacts cannot tell them apart.
- The same "Detail 1 not hittable" symptom predates VK-1064; it is not the
  VK-1069 dropped tap; it is not a loaded runner.

Evidence: `.superpowers/sdd/vk1081-design.md` in the vankhan ledger dir (not
in this worktree): the activity log, the recording, the frequency scan.

## 2. Decision

Instrument the launch, and relaunch once on a positive "Flutter UI not
displayed" signal, recorded. No product change.

### 2.1 `tapWhenSettled` reports the truth (D8)

The failure message gives the element's real frame (`element.frame` when it
exists, `none` otherwise; `frame` on a missing element records a failure, so
it is read only behind `exists`) and whether the last sample was hittable.
The settle logic (two equal hittable frames 200 ms apart, the one last
sample) is unchanged.

### 2.2 Install log in the plugin (D7)

`NativeShellInstaller.install` logs one `#if DEBUG` line before the detach:

```
[liquid_shell] install: view loaded <0|1>, in window <0|1>, scene <activationState>
```

It reads `isViewLoaded` and `viewIfLoaded?.window` only, never `view`, so it
cannot load the view or change the install it observes. Release builds log
nothing. The prefix matches `tool/ios_sim.sh applog`'s predicate
(`eventMessage CONTAINS "liquid_shell"`), so a red CI run keeps it. No
CHANGELOG line (the VK-1046 precedent for DEBUG logs).

### 2.3 The example's Flutter-UI probe (D2, D5, D6)

In `example/ios/Runner/AppDelegate.swift`, enabled whenever
`LIQUID_SHELL_EXAMPLE_DEMO` is set (every UI-test launch):

- On `UIScene.didActivateNotification` (after the plugin's synchronous
  install in `willConnect`, so the probe never runs inside it), it finds the
  `FlutterViewController` in the scene's key window: the root, or a
  descendant of the root's `children` (the plugin's container is internal).
  No Flutter controller (the `segments-native` demo's reference screen, a
  later scene): nothing, and no label.
- KVO on `displayingFlutterUI` with `.initial`, the token kept for the
  controller's life, so a registration after the first frame still reports
  "displayed". Not `setFlutterViewDidRenderCallback`: it is single-slot, and
  claiming it would take it from the app.
- Each value sets a hidden window label (the `AnimatedStackTrace` pattern,
  identifier `flutterUIProbe`) to `flutterUI: displayed` or `flutterUI: not
  displayed`, and logs `[liquid_shell] example: Flutter UI displayed <bool>
  after <ms> ms` (since `didFinishLaunching`).
- The probe never touches `flutter.view`.

### 2.4 `launchShowingFlutter` and the gated relaunch (D1, D3, D10)

A shared helper in `RunnerUITests/UITestWaits.swift`:

1. Launch the app with the demo.
2. Run the caller's readiness wait (the existing 90 s waits: the tab bar,
   Home's bar with `Add`, the VK-1064 row-below-bar settle). It is the
   evidence that Dart ran; a launch that never gets there fails plainly, as
   today.
3. Then wait up to 20 s for the probe to read `flutterUI: displayed`. The
   clock starts after step 2, never at `launch()`, so a slow runner's cold
   launch is not judged by it.
4. Relaunch only when the probe label **exists and reads `flutterUI: not
   displayed`**. A missing probe label is a different failure (the probe
   broke): it fails at once with `the Flutter UI probe is missing`.
5. The relaunch is recorded: an activity `VK-1081: relaunch, Flutter UI never
   displayed`, a `print`, a screenshot and `app.debugDescription` attached
   (lifetime `keepAlways`); then `terminate()` and steps 1 to 3 once more.
6. Still not displayed: `XCTFail("Flutter UI never displayed (twice)")`.

One relaunch, never two. No `-retry-tests-on-failure`: it retries every
failure without a signal.

`MinimizeUITests.launch` and `PagesUITests.launch` use it. The VK-1064
row-below-bar settle moves into `UITestWaits.swift` (its second copy: the
`pages` launch in MinimizeUITests gets it too).

## 3. Follow-ups (Plane, not in this PR)

- The product question (mechanism B), triggered by the first instrumented
  occurrence: if the install line shows the Flutter view already in a window,
  fix `NativeShellInstaller.install`; if it shows a normal install and a late
  or missing first frame, close it as engine or simulator.
- VK-1083: "Failed to terminate" on stalled runners.

## 4. Verification

- Task 1: a throwaway UI test (`XCTExpectFailure` with an issue matcher on
  the message) is red today (`frame (inf, inf, 0.0, 0.0)`) and green after.
- Task 3: a committed UI test asserts a normal `pages` launch reaches
  `flutterUI: displayed`; red before the probe exists. The probe is checked
  on the `tabs`, `pages`, `minimize` and `search` demos, on an iPhone and an
  iPad simulator, before the helper is built on it.
- Task 4: uncommitted scaffolding forces "not displayed" (first launch only:
  one recorded relaunch, then green; every launch: one relaunch, then the
  explicit failure), confirmed in the xcresult (activity, screenshot).
  Reverted before the final runs.
- Final, on the committed tree: `make verify`; `make ios-unit`; `make ios-ui`
  and `make ios-minimize` on an own iPhone 17 (iOS 26.5) simulator, with no
  relaunch activity on a green run; PagesUITests on an own iPad; both
  `[liquid_shell]` lines read from the simulator log with the `applog`
  predicate.
