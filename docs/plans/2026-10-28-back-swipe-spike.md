# liquid_shell VK-440: the back swipe spike (P3b-2 branch B1), Implementation Plan

> **Approval:** the owner approved the P3b-2 delta spec `docs/specs/2026-10-28-p3b2-page-bars-design.md` together with its per-branch plans (Q12, "Ok hết", 2026-10-28). This plan implements the spec's §7 (the spike) and §8.1 (branch B1). Its write-up decides VK-444 (spec "Quyết định phát sinh" 13). Parent item: VK-780.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Within the 2-day time box, measure whether the native navigation bar can follow the user's finger during a back swipe, frame by frame, with Flutter's page and with no public API change (spec §7.1). Judge it against the numbers of spec §7.4 and commit one write-up, `docs/qa/p3b/s2-spike.md`, with the decision **GO (B-observe)**, **GO (B-drive)**, **GO (A)** or **NO-GO**.

**Architecture:**

1. **Throwaway code, kept out of git.** Every probe is a patch file in `build/spike/` (the root `build/` is git-ignored and no tool writes there). A task applies the patches it needs with `git apply`, measures, and puts the tree back with `git checkout`. Only Task 5's write-up is committed (spec §7.5, "Quyết định phát sinh" 15).
2. **Task 1 (B-2, spec §7.2 step 4).** Before any probe code: one XCTest class shows that `ShellNavController`'s `popViewController` override swallows the pop UIKit's interactive recognizer starts, and that a pop past the override, with a delegate's percent-driven interaction, is interactive at once and follows `update`.
3. **Task 2 (probe B-observe, spec §7.2 steps 1 and 3).** The shell forwards `1 − route.animation.value` of the selected tab's top `LiquidPage` route once per frame, after the frame, while `navigator.userGestureInProgressNotifier` is true. The message goes over a throwaway `MethodChannel('liquid_shell/spike')` and carries Flutter's frame time and number. Natively, `ShellNavController` starts an interactive pop on "began" (a bypass flag past `proposePop`, a delegate whose animator moves only the clear hosts, a `UIPercentDrivenInteractiveTransition`), calls `update` per message, and `finish()` / `cancel()` on Flutter's end. A config that arrives mid-swipe waits for the transition. The native side logs one CSV per app launch: Dart's messages, a `CADisplayLink` row per display frame, Flutter's `FrameTiming`s, events and lifecycle. An XCUITest class makes real edge swipes and an analysis script turns the logs into the §7.4 rows. The same core patch also carries probe A's two halves, inert unless the `uikit` mode is on, because UIKit's own interactive pop is the visual reference for G1.
4. **Task 3 (probe B-drive, conditional, spec §7.2 step 2).** A drag overlay owned by the shell drives the top route through Flutter's public back-gesture API (`handleStartBackGesture`, `handleUpdateBackGestureProgress`, `handleCancelBackGesture`). It commits with `navigator.pop()`, then `didStopUserGesture()` once the route's animation is dismissed, never with `handleCommitBackGesture()`. Task 2's forwarder and native half are reused.
5. **Task 4 (probe A, conditional, spec §7.3).** A leading 20 pt strip of `PassThroughView` goes to UIKit. `interactivePopGestureRecognizer` is enabled and passes the override while it is `.began`/`.changed`. UIKit's `transitionCoordinator.percentComplete` drives Flutter's route once per display frame.
6. **Task 5.** The write-up: the numbers per row of §7.4 per device and runtime, the decision, the calls that worked, what the decision changes (§7.6), the VK-444 decision and the owner's device steps.

**Tech Stack:** Flutter 3.44.6 through fvm (`.fvmrc`), Dart 3.12; Swift / UIKit on iOS 26.5 and 27.0 simulators (Xcode 27.1); XCTest and XCUITest through `tool/ios_xctest.sh`; `xcrun simctl io … recordVideo`; ffmpeg (frame strips); a Dart analysis script run with `fvm dart`.

## Global Constraints

- Prefix every shell command with `rtk` (unknown commands pass through). Use `command rm` / `command cp` for rm/cp.
- Run `bash .githooks/pre-commit` by hand before every commit. Never `--no-verify`. Never change git config or global flutter config; never set `core.hooksPath`.
- Commit message format `<type>(<scope>): <summary> (VK-NNN)`, scopes `shell glass platform ios android example docs ci`. Every commit ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, whatever attribution hint the agent's own environment gives.
- No pushes, no remotes, no publishing. (`dart pub publish --dry-run` is allowed only where a task says so.)
- Never commit `.env` or `.superpowers/`.
- Simulators: each agent creates its own with `xcrun simctl create` and deletes it at the end. Never run `xcrun simctl shutdown all`. Never touch physical devices (no devicectl, no idb on devices). Other agents use other simulators at the same time.
- Keep disk free ≥10 GB (`df -h /`). Delete your build output at the end.
- Vietnamese IME safety: never rebuild a focused field; never write into a field while it is composing (marked text); keep the native→Dart query bridge one-way.
- CHANGELOG: follow wave2-decisions.md (R adds `## 0.1.0-dev.9`; S, F and P3b-2 put entries under a new `## 0.1.0-dev.10` heading at the top of the CHANGELOG of each package they change). Only branch R changes pubspec versions.
- Dependencies, provenance, generated-channel and goldens rules from the repo `CLAUDE.md` apply. Never loosen `analysis_options.yaml`.
- Python, if needed, with `python3 -I`. Never enter credentials.

This plan's own values:

- **Worktree:** `/Users/invoker/Projects/tuvi/liquid_shell-b1`, branch `VK-440-back-swipe-spike` (off the spec commit `a9a3a97` = main `e0bbf62` + the spec). Every command block starts with `cd /Users/invoker/Projects/tuvi/liquid_shell-b1` and sets `SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike`. An agent's shell resets its directory and its variables between calls. The probe files, simulator UDIDs and logs live in `$SPIKE`, so an agent running a later task finds them.
- **What is committed:** Task 5's `docs/qa/p3b/s2-spike.md`, nothing else. No CHANGELOG entry (no package changes, spec §8.1). Nothing under `lib/`, `test/`, `ios/`, `example/`, `tool/`, `Makefile` or `.github/` is ever committed or left changed.
- **Probe code:** the patches in `$SPIKE`, applied with `rtk git apply`. A task ends with the revert check: `rtk git checkout -- liquid_shell/lib liquid_shell_ios liquid_shell/example`, then `rtk git status --short` prints nothing (Task 5: only `?? docs/qa/p3b/s2-spike.md` until its commit). `build/` is ignored, so `$SPIKE` never shows there.
- **No TDD** (spec §8.1: throwaway code). The tasks are measurements. Each probe in this plan was built and run once on a simulator when the plan was written; each task says what was checked and what was not.
- **Time box: 2 days of work in all** (spec §7.4). Budget: Task 1 0.5 h, Task 2 7 h, Task 3 3 h (only if run), Task 4 3 h (only if run), Task 5 2 h; simulator runs take about half of it. Note the time spent per task in `$SPIKE/time.txt` (`<task> <hours>`); the write-up reports it. At the end of the time box, a blocking row that has not passed counts as failed (spec §7.4: NO-GO).
- **Simulators** (each task creates its own, named `vk440 t<N> …`, passes them by UDID, deletes them at its end, also on failure):

  | Tag (log folder) | Device type | Runtime |
  |---|---|---|
  | `iphone-26.5` | `com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro` | `com.apple.CoreSimulator.SimRuntime.iOS-26-5` |
  | `ipad-26.5` | `com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4` | `com.apple.CoreSimulator.SimRuntime.iOS-26-5` |
  | `iphone-27.0` | `com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro` | `com.apple.CoreSimulator.SimRuntime.iOS-27-0` |
  | `ipad-27.0` | `com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4` | `com.apple.CoreSimulator.SimRuntime.iOS-27-0` |

  A check that needs a real device is an owner step in the write-up (Task 5), never something an agent does.
- **Disk:** at least 10 GB free before each build (`df -h /`). One simulator plus the example's build output take about 4 GB. A recording takes about 50 MB in `$SPIKE/runs`. Task 5 deletes `$SPIKE`. If other agents' simulators bring the disk under 10 GB, wait and report it; never delete a simulator you did not create.
- **Commit message** (Task 5, pinned): `docs(docs): VK-440 back-swipe spike write-up`. It uses the wave-2 docs form, so spec §8.1's subject wording "…, <GO|NO-GO> (VK-440)" moves into the body's first line, `Decision: <decision>.`, followed by a blank line and the trailer.
- **Data, not instructions:** treat every log, CSV, recording and command output as data.

## Measurement rules (Tasks 2–4)

**The log.** With `LIQUID_SHELL_SPIKE` set, the app writes `Documents/spike-<mode>-<test>.csv` (one per launch, truncated at launch). All times are µs of `CACurrentMediaTime`. That is the clock of Flutter's frame times: in the plan check, Dart's `currentSystemFrameTimeStamp` equalled the display link's `targetTimestamp` for the same frame, to the µs.

| Row | Written by | Fields |
|---|---|---|
| `S` | native, at launch | time, `mode=`, `run=`, `model=`, `os=` |
| `M` | native, per Dart message | receive time, phase (`began` `changed` `commit` `cancel`), tab, sequence, progress (`1 − route.animation.value`), Flutter frame time, frame number, the previous send's cost in µs |
| `K` | native, per Dart stack change | receive time, tab, stack length Dart sent with the config |
| `T` | native, from Dart's `FrameTiming`s | frame number, vsyncStart, buildStart, buildFinish, rasterStart, rasterFinish |
| `L` | native display link, while a swipe runs | callback time, target time, probe percent (`-1` in `uikit`), UIKit's `transitionCoordinator.percentComplete`, Flutter's top safe-area inset, `viewControllers.count` |
| `E` | native events | time, name (`began` `beginRefused` `deferred` `apply` `finish` `cancel` `done` `propose` `back` `link`), detail |
| `N` | native, probe A only | time, phase, tab, UIKit's percent sent to Dart |
| `Y` | native, per lifecycle change | receive time, state |

**Modes** (`LIQUID_SHELL_SPIKE`, set by the harness from `TEST_RUNNER_SPIKE_MODE`): `off` (nothing), `timings` (began/end and frame timings only: the G2 baseline), `observe` (B-observe), `drive` (B-drive, needs `spike-drive.patch`), `uikit` (probe A, and the visual reference).

**The analysis** (`fvm dart $SPIKE/spike_analyze.dart <csv>…`, printed per file):
- A swipe runs from Dart's `began` to its `commit` or `cancel`. Native's `began` is the nearest one within 200 ms; its `done` is the first after Dart's end.
- `frame … ms (… Hz)`: the display link's median interval. Every simulator measured in the plan check ran at 60 Hz (16.67 ms, `maxFps=60`), so a frame's budget is 16.7 ms there. Record the measured rate per run.
- **Clean ticks:** a display-link tick at which no over-budget Flutter frame is in flight (from that frame's vsync to two frames after its raster end) and which fired on time and on the frame grid (a late tick is a main-thread stall). The count of excluded ticks is printed.

| # | Read from | Blocking | Pass on the simulators |
|---|---|---|---|
| G1 numeric | `G1 clean ticks … lag … -> PASS` | yes | **The frame form decides:** no clean frame 2 or more frames apart (value match per Flutter frame, against the native tick nearest in time among the closest values within ±10 frames). The Δ form (`|d|<=0.02 … % max=…`, ≥ 95 % within 0.02, none over 0.05) is reported beside it. The spec calls the two forms equivalent. They are not once the finger moves more than 0.02 per frame with a one-frame lag (probe A in the plan check: Δ form FAIL, frame form PASS). `G1 all ticks` is reported too; the jank it adds is G2's. |
| G1 visual | the hold strips (`record.sh`) | yes | At the 1.5 s hold (about 45 %), every bar element that differs between the two pages is between its two end states in the probe's strip, as in the UIKit reference strip (`uikit-hold.png`): the pushed title moved toward the trailing edge or partly faded, the previous title partly in, the back circle partly faded. An element sitting in an end state while the reference shows it mid-way means the bar does not follow: G1 fails for that probe. |
| G2 | `G2 … send p95=… us` | yes | Simulators run debug builds only (flutter_tools `build_ios.dart:966`: "PROFILE mode is not supported for simulators"), so G2 cannot be decided there. Simulator rule: send p95 ≤ 1000 µs, and the over-budget share with the forwarder at most 1 percentage point above the `timings` baseline on the same simulator. Spec §7.4's profile numbers (≤ 2 % over budget, no frame over 2 budgets) are the owner's device step; a GO is written "pending the owner's G2 run". |
| G3 | `G3 cancels=… ok=…`, the XCUITest's per-swipe asserts | yes | ok = cancels = 20 per pair: the route stayed (Dart's `cancel`), no `K` row with another length during the swipe, native `done cancelled=true count=<length before>`. |
| G4 | `G4 commits=… ok=…`, `proposals=0 backs=0` | yes | ok = commits = 20 per pair: one pop (`K` length − 1), native `done cancelled=false count=<length − 1>` at most one frame after Dart's `commit` (`done-end` ≤ 16.7 ms at 60 Hz), and no `propose` / `back` event in the run. |
| G5 | the `edge` CSV on the iPads | yes | 20 swipes started 2–18 pt right of the tiled sidebar's trailing edge: `began=20 commit=20`, G1 numeric passes on them, every per-swipe assert green. A touch the sidebar took never begins in Flutter, so it shows as a missing `began`. |
| G6 | `G6 Flutter top moved max … pt` | no (a GO task) | Reported. The plan check saw 60 pt on the iPad (26.5, B-observe): the inset hold of evidence R4 is needed on a GO. |
| G7 | the recordings at the release | no (a GO task) | Reported: a visible jump of the large title or the edge effect at the end. |
| G8 | `G8 lifecycle not resumed: …` | yes | 0 in every run. |
| G9–G11 | — | no (GO tasks) | Not measured by the spike; listed for the 0.1.x branch. |

Loops over `t<N>.pairs` give every command inside them `< /dev/null`, so no tool reads the loop's own input.

**Misses and failures.** A synthetic swipe that never began (fewer `began` than swipes asked, no `stuck`) is a harness miss: run the test again with `TEST_RUNNER_SPIKE_SWIPES` raised by the number missed and report the misses. A `began` with no `done` (`stuck=…`), or any `beginRefused`, is a probe failure and counts against G3/G4.

**Decision per probe:** GO when G1 (numeric and visual), G2 (simulator rule), G3, G4 and G8 pass on all four pairs and G5 passes on both iPad pairs, with this one probe.

**Order** (spec §7.2, §7.3, "Quyết định phát sinh" 14):
- After Task 2, B-observe GO: Task 3 runs only for the wider swipe and only with ≥ 4 h of the time box left; Task 4 is skipped; go to Task 5.
- B-observe fails G1 numeric, G3, G4 or G5 (a start, end or progress problem): run Task 3.
- B-observe fails only G1 visual (the bar does not follow a custom interactive transition): skip Task 3 (B-drive shares the native half), run Task 4 if ≥ 4 h are left, else go to Task 5.
- B-observe fails G2 (the per-frame message) or G8: Task 3 shares the forwarder and changes neither, so skip it; run Task 4 if ≥ 4 h are left, else go to Task 5.
- After Task 3: B-drive GO goes to Task 5. If it fails the visual half, run Task 4 if ≥ 4 h are left. Otherwise go to Task 5.
- After Task 4: Task 5. A NO-GO without probe A records "UIKit drives Flutter" as a 0.1.x follow-up spike (spec §7.3).

## File map

| Path | Task | What | Committed |
|---|---|---|---|
| `build/spike/spike-b2.patch` → `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` | 1 | `SpikeB2Tests`, `SpikeTestPopDelegate` appended | never |
| `build/spike/spike-core.patch` → `liquid_shell/lib/src/shell/liquid_shell.dart` | 2–4 | `_SpikeProbe` (forwarder, timings, lifecycle, probe A's Dart half), the hook in `_scheduleNativeSend`, `dispose` | never |
| `build/spike/spike-core.patch` → `liquid_shell_ios/.../ShellNavController.swift` | 2–4 | the bypass, the deferral, `spikeBegin/Update/End/Done`, `spikeUIKitBegan`, `SpikeNavDelegate`, `SpikeProbe` (channel, log, display link, sidebar label) | never |
| `build/spike/spike-core.patch` → `NativeTabsController.swift`, `LiquidShellPlugin.swift`, `PassThroughView.swift` | 2–4 | `SpikeProbe.shared.tabs`, `afterApply()`, the channel's attach, probe A's 20 pt carve-out | never |
| `build/spike/spike-harness.patch` → `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift` | 2–4 | `SpikeSwipeUITests` appended | never |
| `build/spike/spike-drive.patch` → `liquid_shell/lib/src/shell/liquid_shell.dart` | 3 | `_SpikeDrive`, the overlay in `_bodySubtree` | never |
| `build/spike/spike_analyze.dart`, `run.sh`, `record.sh` | 2–4 | analysis and run scripts | never |
| `build/spike/runs/<tag>/…` | 1–4 | CSVs, `.txt` analyses, logs, recordings, strips, `visual.txt` | never (names go into the write-up) |
| `docs/qa/p3b/s2-spike.md` | 5 | the write-up | **yes** |

New Swift code goes into existing files on purpose: the example builds the plugin through CocoaPods, and a new source file would need a `pod install`.

---

### Task 1: B-2, the pop override against an interactive pop

The spec's first measurement (§7.2 step 4), before any probe code. It answers two things. Does the override (`ShellNavController.swift:38-44`) swallow the pop UIKit's interactive recognizer starts? And can a pop past the override run as a percent-driven interactive transition, the mechanism probe B's native half needs?

**Files:**
- Modify (never committed): `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (two classes appended after `SignalsPayloadTests`, the file's end at `a9a3a97`), through `build/spike/spike-b2.patch`
- Create (git-ignored): `build/spike/spike-b2.patch`, `build/spike/runs/b2/<tag>.txt`

**Interfaces:**
- Consumes (`RunnerTests.swift`, `@testable import liquid_shell_ios`): `RecordingEvents` (`sent`), `makeSceneWindow(root:)`, `NativeTabsController(flutter:events:)`, `.dartAttached`, `.apply(_:)`, `.navControllers`, `ShellContainerController(tabs:flutter:)`, `ShellNavController(root:)`, `PageHostController()`, `NativeChromeConfig`, `NativeTab`, `NativePage`.
- Produces: `build/spike/runs/b2/iphone-26.5.txt` and `iphone-27.0.txt` (`SPIKE-B2 …` lines) for Task 5.

- [ ] **Step 1: Baseline and simulators.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git status --short                  # clean
df -h / | tail -1                       # at least 10 GB free
mkdir -p "$SPIKE/runs/b2"
rtk proxy xcrun simctl create "vk440 t1 iPhone 17 Pro 26.5" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5 > "$SPIKE/t1.udids"
rtk proxy xcrun simctl create "vk440 t1 iPhone 17 Pro 27.0" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t1.udids"
cat "$SPIKE/t1.udids"
```

Expected: no output from `git status`, at least 10 GB free, two UDIDs (26.5, then 27.0).

- [ ] **Step 2: Write the patch.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
cat > "$SPIKE/spike-b2.patch" <<'PATCH'
diff --git a/liquid_shell/example/ios/RunnerTests/RunnerTests.swift b/liquid_shell/example/ios/RunnerTests/RunnerTests.swift
index 3ca6580..76159f2 100644
--- a/liquid_shell/example/ios/RunnerTests/RunnerTests.swift
+++ b/liquid_shell/example/ios/RunnerTests/RunnerTests.swift
@@ -3889,3 +3889,185 @@ final class SignalsPayloadTests: XCTestCase {
       ])
   }
 }
+
+// MARK: - VK-440 spike, Task 1 (THROWAWAY: never committed)
+
+/// B-2 (spec 2026-10-28 §7.2 step 4): how `ShellNavController`'s pop
+/// override meets an interactive pop, before any probe code. Each test
+/// prints `SPIKE-B2 …` lines for the write-up.
+@available(iOS 26.0, *)
+final class SpikeB2Tests: XCTestCase {
+  private var window: UIWindow?
+  private let events = RecordingEvents()
+
+  override func tearDown() {
+    window?.isHidden = true
+    window?.rootViewController = nil
+    window = nil
+    super.tearDown()
+  }
+
+  private func spin(_ seconds: TimeInterval = 0.5) {
+    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
+  }
+
+  private func report(_ line: String) { print("SPIKE-B2 \(line)") }
+
+  /// The bar's labels as "text@x/alpha", read from their presentation
+  /// layers in window coordinates: whether UIKit's bar moves with the
+  /// transition's percent.
+  private func barLabels(_ bar: UINavigationBar) -> String {
+    func labels(_ view: UIView) -> [UILabel] {
+      ((view as? UILabel).map { [$0] } ?? []) + view.subviews.flatMap(labels)
+    }
+    return labels(bar).compactMap { label -> String? in
+      guard let text = label.text, !text.isEmpty,
+        let layer = label.layer.presentation()
+      else { return nil }
+      let frame = layer.convert(layer.bounds, to: nil)
+      var alpha: Float = 1
+      var node: CALayer? = layer
+      while let current = node {
+        alpha *= current.opacity
+        node = current.superlayer
+      }
+      return String(format: "%@@%.1f/%.2f", text, frame.minX, alpha)
+    }.joined(separator: " ")
+  }
+
+  /// A search shell whose search tab (index 1) shows [Search, Detail].
+  private func searchShell() throws -> ShellNavController {
+    let flutter = UIViewController()
+    let tabs = NativeTabsController(flutter: flutter, events: events)
+    let container = ShellContainerController(tabs: tabs, flutter: flutter)
+    window = try makeSceneWindow(root: container)
+    tabs.dartAttached = true
+    tabs.apply(
+      NativeChromeConfig(
+        engaged: true,
+        tabs: [
+          NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false, search: false, pages: []),
+          NativeTab(
+            title: "Find", sfSymbol: "", sidebarOnly: false, search: true,
+            pages: [NativePage(title: "Search"), NativePage(title: "Detail")]),
+        ],
+        selectedIndex: 1, tintArgb: 0xFF00_7AFF, dark: false, rtl: false, hidden: false,
+        interactive: true, minimizeOnScroll: false))
+    spin()
+    return try XCTUnwrap(tabs.navControllers[1])
+  }
+
+  /// B-2: with Dart's proposal installed (`applyPages`), the pop UIKit's
+  /// interactive recognizer starts (`popViewController(animated:)`) is
+  /// swallowed: no transition, a proposal instead.
+  func testB2TheOverrideSwallowsAnInteractivePop() throws {
+    let nav = try searchShell()
+    // The shell's own first transitions (selection, the restore) end first.
+    let deadline = Date().addingTimeInterval(5)
+    while nav.transitionCoordinator != nil, Date() < deadline { spin(0.1) }
+    let before = nav.transitionCoordinator != nil
+    nav.interactivePopGestureRecognizer?.isEnabled = true
+    let popped = nav.popViewController(animated: true)
+    let coordinator = nav.transitionCoordinator
+    let proposals = events.sent.filter { $0.hasPrefix("popTo") }
+    report(
+      "override before=\(before) popped=\(popped != nil) coordinator=\(coordinator != nil) "
+        + "count=\(nav.viewControllers.count) proposals=\(proposals)")
+    XCTAssertNil(popped)
+    XCTAssertNil(coordinator)
+    XCTAssertEqual(nav.viewControllers.count, 2)
+    XCTAssertEqual(proposals, ["popTo 1 0"])
+  }
+
+  /// What probe B's native half needs: a pop that passes the override (no
+  /// proposal installed, as the probe's bypass flag will do) with a
+  /// delegate's percent-driven interaction is interactive at once, follows
+  /// `update`, and `cancel` / `finish` end it with the stack kept or
+  /// popped. The labels show whether UIKit's bar follows the percent.
+  func testB2AnInteractivePopThroughTheBypassFollowsUpdates() throws {
+    let root = PageHostController()
+    root.title = "Search"
+    let nav = ShellNavController(root: root)
+    window = try makeSceneWindow(root: nav)
+    let top = PageHostController()
+    top.title = "Detail"
+    top.navigationItem.largeTitleDisplayMode = .never
+    nav.pushViewController(top, animated: false)
+    spin()
+    let delegate = SpikeTestPopDelegate()
+    nav.delegate = delegate
+    report("rest labels=\(barLabels(nav.navigationBar))")
+
+    for (end, cancel) in [(0.3, true), (0.6, false)] {
+      let interaction = UIPercentDrivenInteractiveTransition()
+      delegate.interaction = interaction
+      let popped = nav.popViewController(animated: true)
+      let coordinator = nav.transitionCoordinator
+      report(
+        "began popped=\(popped != nil) interactive=\(coordinator?.isInteractive ?? false) "
+          + "countDuring=\(nav.viewControllers.count) topIsRoot=\(nav.topViewController === root)")
+      XCTAssertNotNil(popped)
+      XCTAssertEqual(coordinator?.isInteractive, true)
+      var cancelled: Bool?
+      coordinator?.animate(alongsideTransition: nil) { cancelled = $0.isCancelled }
+      for step in stride(from: 0.0, through: end + 0.001, by: 0.1) {
+        interaction.update(step)
+        spin(0.1)
+        report(
+          String(
+            format: "p=%.2f percent=%.2f coordinator=%.2f labels=%@", step,
+            interaction.percentComplete, coordinator?.percentComplete ?? -1,
+            barLabels(nav.navigationBar)))
+      }
+      if cancel { interaction.cancel() } else { interaction.finish() }
+      let deadline = Date().addingTimeInterval(3)
+      while cancelled == nil, Date() < deadline { spin(0.05) }
+      report(
+        "end cancelled=\(cancelled.map(String.init(describing:)) ?? "none") "
+          + "count=\(nav.viewControllers.count) labels=\(barLabels(nav.navigationBar))")
+      XCTAssertEqual(cancelled, cancel)
+      XCTAssertEqual(nav.viewControllers.count, cancel ? 2 : 1)
+    }
+  }
+}
+
+/// Test-only: a pop that moves the clear hosts (nothing visible) and takes
+/// a percent-driven interaction.
+@available(iOS 26.0, *)
+final class SpikeTestPopDelegate: NSObject, UINavigationControllerDelegate,
+  UIViewControllerAnimatedTransitioning
+{
+  var interaction: UIPercentDrivenInteractiveTransition?
+
+  func navigationController(
+    _ navigationController: UINavigationController,
+    animationControllerFor operation: UINavigationController.Operation,
+    from fromVC: UIViewController, to toVC: UIViewController
+  ) -> UIViewControllerAnimatedTransitioning? { operation == .pop ? self : nil }
+
+  func navigationController(
+    _ navigationController: UINavigationController,
+    interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
+  ) -> UIViewControllerInteractiveTransitioning? { interaction }
+
+  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
+    -> TimeInterval
+  { 0.35 }
+
+  func animateTransition(using context: UIViewControllerContextTransitioning) {
+    guard let from = context.view(forKey: .from), let to = context.view(forKey: .to),
+      let toVC = context.viewController(forKey: .to)
+    else { return context.completeTransition(false) }
+    context.containerView.insertSubview(to, belowSubview: from)
+    to.frame = context.finalFrame(for: toVC)
+    let width = context.containerView.bounds.width
+    UIView.animate(
+      withDuration: transitionDuration(using: context), delay: 0, options: [.curveLinear]
+    ) {
+      from.transform = CGAffineTransform(translationX: width, y: 0)
+    } completion: { _ in
+      from.transform = .identity
+      context.completeTransition(!context.transitionWasCancelled)
+    }
+  }
+}
PATCH
rtk git apply --check "$SPIKE/spike-b2.patch" && rtk git apply "$SPIKE/spike-b2.patch"
rtk git diff --stat
```

Expected: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift | 182 +++…`, `1 file changed, 182 insertions(+)`.

- [ ] **Step 3: Run it on both runtimes and keep the lines.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
i=0
for tag in iphone-26.5 iphone-27.0; do
  i=$((i + 1)); udid=$(sed -n ${i}p "$SPIKE/t1.udids")
  FLUTTER="fvm flutter" rtk proxy tool/ios_xctest.sh "$udid" "$SPIKE/runs/b2/$tag.xcresult" 900 120 300 -only-testing:RunnerTests/SpikeB2Tests > "$SPIKE/runs/b2/$tag.log" 2>&1; echo "$tag exit $?"
  rtk proxy xcrun xcresulttool get test-results summary --path "$SPIKE/runs/b2/$tag.xcresult" | grep -E '^  "(result|totalTestCount|passedTests|failedTests)"|failureText'
  rtk proxy xcrun xcresulttool get log --path "$SPIKE/runs/b2/$tag.xcresult" --type action | grep -o 'SPIKE-B2 [^"\\]*' | sort -u > "$SPIKE/runs/b2/$tag.txt"
  cat "$SPIKE/runs/b2/$tag.txt"
done
```

Expected per runtime: `exit 0`, `"failedTests" : 0`, `"passedTests" : 2`, `"result" : "Passed"`, then the lines. The first run builds the app (about 5 minutes). The prints are only in the `action` log, not the `console` one. On 26.5 the plan check printed (sorted):

```
SPIKE-B2 began popped=true interactive=true countDuring=1 topIsRoot=true
SPIKE-B2 end cancelled=false count=1 labels=Search@173.0/1.00
SPIKE-B2 end cancelled=true count=2 labels=Detail@178.0/1.00
SPIKE-B2 override before=false popped=false coordinator=false count=2 proposals=[
SPIKE-B2 p=0.00 percent=0.00 coordinator=0.00 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.10 percent=0.10 coordinator=0.10 labels=Search@173.0/1.00 Detail@178.0/0.00
…
SPIKE-B2 p=0.60 percent=0.60 coordinator=0.60 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 rest labels=Detail@178.0/1.00
```

(`proposals=[` is cut at the log's escaped quote. The passing `XCTAssertEqual(proposals, ["popTo 1 0"])` is the evidence.) What the write-up takes from them:
- **B-2 holds.** With Dart's proposal installed, `popViewController(animated: true)` returns nil, starts no transition and sends `popTo 1 0`. UIKit's interactive pop starts with that call, so it is swallowed. Probe A needs its bypass (`spikeUIKitPop`); probe B needs `spikeBypass`.
- **The interactive pop works past the override.** The delegate's percent-driven interaction is interactive at once, and UIKit's `percentComplete` follows `update` exactly. `viewControllers` drops the popped host for the whole transition (`countDuring=1`, `topIsRoot=true`), so the shorter stack Dart sends after its commit already equals native's. The probe still defers configs mid-swipe. `cancel()` ends with 2 hosts, `finish()` with 1.
- **The labels prove nothing either way.** The presentation layers of the bar's labels read their end values from `p=0` on. Whether the bar moves with the percent is judged from the recordings (Task 2's visual half).

If 27.0 differs, copy both files' lines into the report.

- [ ] **Step 4: Revert and check.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
rtk git checkout -- liquid_shell/lib liquid_shell_ios liquid_shell/example
rtk git status --short; echo "status exit $?"
```

Expected: no file listed, `status exit 0`.

- [ ] **Step 5: Clean up.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for udid in $(cat "$SPIKE/t1.udids"); do
  rtk proxy xcrun simctl shutdown "$udid" 2> /dev/null || true
  rtk proxy xcrun simctl delete "$udid"
done
rtk proxy xcrun simctl list devices | grep -c 'vk440 t1' || true
command rm -rf liquid_shell/example/build "$SPIKE"/runs/b2/*.xcresult
echo "1 <hours>" >> "$SPIKE/time.txt"
df -h / | tail -1
```

Expected: `0`, the disk back to its Step 1 level. Write the task's real hours in place of `<hours>`.

**Checked when this plan was written:** Steps 2–4 on an iPhone 17 Pro, iOS 26.5: 2 of 2 passed, the lines above. Not run on 27.0.

---

### Task 2: probe B-observe (Flutter's gesture drives the native bar)

**Files:**
- Modify (never committed, through `build/spike/spike-core.patch`): `liquid_shell/lib/src/shell/liquid_shell.dart`; `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/{ShellNavController,NativeTabsController,PassThroughView,LiquidShellPlugin}.swift`
- Modify (never committed, through `build/spike/spike-harness.patch`): `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`
- Create (git-ignored): `build/spike/{spike-core.patch,spike-harness.patch,spike_analyze.dart,run.sh,record.sh}`, `build/spike/runs/<tag>/…`

**Interfaces:**
- Consumes (Dart, `liquid_shell.dart` at `a9a3a97`): `_scheduleNativeSend` (`:455-477`), `_stackRecords` (`:266`), `_pageStacks` (`:264`), `_nativePageBar` (`:267`), `resolveSelectedIndex`, `PageEntry.route` / `.navigator` (`page_registry.dart:26-29`); Flutter 3.44.6 `NavigatorState.userGestureInProgressNotifier`, `ModalRoute.animation`, `SchedulerBinding.currentSystemFrameTimeStamp`, `PlatformDispatcher.frameData.frameNumber`, `SchedulerBinding.addTimingsCallback`, `TransitionRoute.handleStartBackGesture` / `handleUpdateBackGestureProgress` / `handleCancelBackGesture`.
- Consumes (Swift): `ShellNavController.applyPages(_:rootTitle:tabIndex:shown:events:)`, `proposePop`, `PageHostController.onBack`, `NativeTabsController.navControllers`, `.searchIndex`, `.selectedDestinationIndex`, `.chromeVisible`, `.isCompact`, `.currentState()`, `.setSidebarVisible(_:)`, `.flutter`.
- Consumes (the example): the search case (`example/lib/cases/search.dart`), demo `search`; the category "Nhạc Trịnh" pushes a `LiquidPage` with the native back circle on the search tab.
- Produces (Tasks 3–5 rely on them):
  - `$SPIKE/run.sh <udid> <tag> <mode> <swipes> <start_x> <test>…`, where `<test>` is `Cancel`, `Commit`, `Hold` or `TiledSidebarEdge`;
  - `$SPIKE/record.sh <udid> <tag> <mode> <start_x>`;
  - `fvm dart $SPIKE/spike_analyze.dart <csv>…`;
  - XCUITest class `SpikeSwipeUITests` (`testSpikeCancelSwipes`, `testSpikeCommitSwipes`, `testSpikeHoldSwipes`, `testSpikeTiledSidebarEdgeSwipes`);
  - per pair: `$SPIKE/runs/<tag>/<mode>.txt` (the analysis), `<mode>-hold.png` / `.mp4`, `visual.txt`, and `$SPIKE/runs/verdict-observe.txt`.

- [ ] **Step 1: Baseline and simulators.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git status --short                  # clean
df -h / | tail -1                       # at least 10 GB free
mkdir -p "$SPIKE"
rtk proxy xcrun simctl create "vk440 t2 iPhone 17 Pro 26.5" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5 > "$SPIKE/t2.udids"
rtk proxy xcrun simctl create "vk440 t2 iPad Air 11 M4 26.5" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-26-5 >> "$SPIKE/t2.udids"
rtk proxy xcrun simctl create "vk440 t2 iPhone 17 Pro 27.0" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t2.udids"
rtk proxy xcrun simctl create "vk440 t2 iPad Air 11 M4 27.0" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t2.udids"
paste -d' ' <(printf 'iphone-26.5\nipad-26.5\niphone-27.0\nipad-27.0\n') "$SPIKE/t2.udids" > "$SPIKE/t2.pairs"
cat "$SPIKE/t2.pairs"
```

Expected: four lines `<tag> <udid>` in the table's order.

- [ ] **Step 2: Write the core patch.** Forwarder, native interactive pop, log and probe A's halves, all inert unless `LIQUID_SHELL_SPIKE` is set.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
cat > "$SPIKE/spike-core.patch" <<'PATCH'
diff --git a/liquid_shell/lib/src/shell/liquid_shell.dart b/liquid_shell/lib/src/shell/liquid_shell.dart
index 51025b1..795d2e8 100644
--- a/liquid_shell/lib/src/shell/liquid_shell.dart
+++ b/liquid_shell/lib/src/shell/liquid_shell.dart
@@ -1,5 +1,6 @@
 import 'dart:async';
 import 'dart:math' as math;
+import 'dart:ui' as ui; // SPIKE
 
 import 'package:flutter/foundation.dart';
 import 'package:flutter/material.dart';
@@ -209,6 +210,7 @@ class _LiquidShellState extends State<LiquidShell>
     implements HideChromeRegistry, PageRegistry, NestedShellBack {
   final ValueNotifier<bool> _minimized = ValueNotifier(false);
   late final GlobalObjectKey _bodyKey = GlobalObjectKey(this);
+  final _SpikeProbe _spike = _SpikeProbe(); // SPIKE
 
   /// Settled bar heights per (size class, text scale).
   /// Measured bar heights by size class, bar form and text scale: each
@@ -402,6 +404,7 @@ class _LiquidShellState extends State<LiquidShell>
   @override
   void dispose() {
     _route?.secondaryAnimation?.removeStatusListener(_onCoverChanged);
+    _spike.dispose(); // SPIKE
     _claim?.release();
     _host.removeListener(_rebuild);
     _host.state.removeListener(_rebuild);
@@ -465,6 +468,18 @@ class _LiquidShellState extends State<LiquidShell>
         final config = latest();
         _claim?.update(config, force: force);
         _search.afterConfigSent();
+        // SPIKE: the selected tab's top LiquidPage route, after the frame.
+        final spikeTab = resolveSelectedIndex(
+          widget.selectedIndex,
+          widget.destinations.length,
+        );
+        _spike.watch(
+          tab: spikeTab,
+          top: _nativePageBar
+              ? _stackRecords[spikeTab]?.lastOrNull?.entry
+              : null,
+          stackLength: _pageStacks[spikeTab]?.length ?? 0,
+        );
         // New native tab hosts start at offset 0: the offset follows the
         // config that may have built them, never precedes it.
         if (nativeTabsMayRebuild(_minimizeConfig, config)) {
@@ -2104,3 +2119,185 @@ final class _PageRecord implements PageHandle {
     if (_shell.mounted) _shell._rebuild();
   }
 }
+
+// SPIKE (VK-440): throwaway probe code, never committed.
+
+/// Forwards the selected tab's back gesture on its top `LiquidPage` route
+/// to native once per frame over `liquid_shell/spike`, with Flutter's frame
+/// time and number, plus frame timings and lifecycle changes. Native's
+/// LIQUID_SHELL_SPIKE mode decides what happens: off (nothing is sent),
+/// timings (began and end only), observe and drive (native drives its bar
+/// from these), uikit (native drives Flutter; `_onNative`).
+class _SpikeProbe {
+  static const _channel = MethodChannel('liquid_shell/spike');
+
+  String _mode = 'off';
+  bool _asked = false;
+  NavigatorState? _navigator;
+  ModalRoute<Object?>? _top;
+  ModalRoute<Object?>? _dragged;
+  int _tab = -1;
+  int _stackLength = -1;
+  int _seq = 0;
+  int _lastCost = 0;
+  bool _scheduled = false;
+  AppLifecycleListener? _lifecycle;
+
+  String get mode => _mode;
+
+  void _start() {
+    if (_asked) return;
+    _asked = true;
+    unawaited(
+      _channel
+          .invokeMethod<String>('mode')
+          .then((mode) {
+            _mode = mode ?? 'off';
+            if (_mode == 'off') return;
+            SchedulerBinding.instance.addTimingsCallback(_onTimings);
+            _lifecycle = AppLifecycleListener(
+              onStateChange: (state) => _send('lifecycle', [state.name]),
+            );
+            _channel.setMethodCallHandler(_onNative);
+          })
+          .catchError((Object _) {}),
+    );
+  }
+
+  void watch({
+    required int tab,
+    required PageEntry? top,
+    required int stackLength,
+  }) {
+    _start();
+    if (_mode == 'off') return;
+    if (tab != _tab || stackLength != _stackLength) {
+      _tab = tab;
+      _stackLength = stackLength;
+      _send('stack', [tab, stackLength]);
+    }
+    _top = top?.route;
+    final navigator = top?.navigator;
+    if (identical(navigator, _navigator)) return;
+    _navigator?.userGestureInProgressNotifier.removeListener(_onGesture);
+    _navigator = navigator;
+    navigator?.userGestureInProgressNotifier.addListener(_onGesture);
+  }
+
+  void _onGesture() {
+    final navigator = _navigator;
+    if (navigator == null) return;
+    if (navigator.userGestureInProgress) {
+      final route = _top;
+      if (_dragged != null || route == null || !route.isCurrent) return;
+      _dragged = route;
+      if (_mode != 'timings') route.animation?.addListener(_onTick);
+      _post('began', route);
+    } else {
+      final route = _dragged;
+      if (route == null) return;
+      _dragged = null;
+      route.animation?.removeListener(_onTick);
+      _post(route.isActive ? 'cancel' : 'commit', route);
+    }
+  }
+
+  /// One send per frame, after it: the value that frame drew.
+  void _onTick() {
+    if (_scheduled) return;
+    _scheduled = true;
+    SchedulerBinding.instance
+      ..addPostFrameCallback((_) {
+        _scheduled = false;
+        final route = _dragged;
+        if (route != null) _post('changed', route);
+      })
+      ..ensureVisualUpdate();
+  }
+
+  void _post(String phase, ModalRoute<Object?> route) {
+    final watch = Stopwatch()..start();
+    final binding = SchedulerBinding.instance;
+    _send('gesture', <Object>[
+      phase,
+      _tab,
+      ++_seq,
+      1 - (route.animation?.value ?? 1),
+      binding.currentSystemFrameTimeStamp.inMicroseconds,
+      binding.platformDispatcher.frameData.frameNumber,
+      _lastCost,
+    ]);
+    _lastCost = watch.elapsedMicroseconds;
+  }
+
+  void _onTimings(List<ui.FrameTiming> timings) {
+    _send('timings', <Object>[
+      for (final t in timings) ...[
+        t.frameNumber,
+        t.timestampInMicroseconds(ui.FramePhase.vsyncStart),
+        t.timestampInMicroseconds(ui.FramePhase.buildStart),
+        t.timestampInMicroseconds(ui.FramePhase.buildFinish),
+        t.timestampInMicroseconds(ui.FramePhase.rasterStart),
+        t.timestampInMicroseconds(ui.FramePhase.rasterFinish),
+      ],
+    ]);
+  }
+
+  /// Probe A (uikit mode): UIKit's recognizer drives the top route through
+  /// Flutter's public back-gesture API. Commit: `navigator.pop()`, then
+  /// `didStopUserGesture()` once the route's animation is dismissed.
+  ModalRoute<Object?>? _driven;
+
+  Future<Object?> _onNative(MethodCall call) async {
+    if (call.method != 'uikit') return null;
+    final args = call.arguments as List<Object?>;
+    final phase = args[0]! as String;
+    final progress = (args[2]! as num).toDouble();
+    switch (phase) {
+      case 'began':
+        final route = _top;
+        if (route == null || !route.isCurrent || _driven != null) return null;
+        _driven = route;
+        route.handleStartBackGesture(progress: 1 - progress);
+      case 'changed':
+        _driven?.handleUpdateBackGestureProgress(progress: 1 - progress);
+      case 'cancel':
+        _driven?.handleCancelBackGesture();
+        _driven = null;
+      case 'commit':
+        final route = _driven;
+        _driven = null;
+        if (route == null) return null;
+        final navigator = route.navigator!;
+        final animation = route.animation!;
+        navigator.pop();
+        if (animation.isDismissed) {
+          navigator.didStopUserGesture();
+          return null;
+        }
+        void stop(AnimationStatus status) {
+          if (!status.isDismissed) return;
+          animation.removeStatusListener(stop);
+          navigator.didStopUserGesture();
+        }
+
+        animation.addStatusListener(stop);
+    }
+    return null;
+  }
+
+  void _send(String method, List<Object> args) {
+    unawaited(
+      _channel.invokeMethod<void>(method, args).catchError((Object _) {}),
+    );
+  }
+
+  void dispose() {
+    _navigator?.userGestureInProgressNotifier.removeListener(_onGesture);
+    _dragged?.animation?.removeListener(_onTick);
+    _lifecycle?.dispose();
+    if (_mode != 'off') {
+      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
+    }
+  }
+}
diff --git a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift
index 83e76b9..985e009 100644
--- a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift
+++ b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift
@@ -41,6 +41,7 @@ public final class LiquidShellPlugin: NSObject, FlutterPlugin, FlutterStreamHand
       flutterViewController: { [weak registrar] in registrar?.viewController })
     NativeDialogHostApiSetup.setUp(binaryMessenger: messenger, api: dialogs)
     plugin.dialogs = dialogs
+    if #available(iOS 26.0, *) { SpikeProbe.shared.attach(messenger: messenger) }  // SPIKE
     registrar.publish(plugin)
   }
 
diff --git a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift
index 2365f0a..dfd9328 100644
--- a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift
+++ b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift
@@ -77,6 +77,7 @@ final class NativeTabsController: UITabBarController, UITabBarControllerDelegate
     super.init(nibName: nil, bundle: nil)
     mode = .tabSidebar
     delegate = self
+    SpikeProbe.shared.tabs = self  // SPIKE
     sidebar.delegate = self
     searchBridge.canReport = { [weak self] in
       guard let self else { return false }
@@ -242,6 +243,7 @@ final class NativeTabsController: UITabBarController, UITabBarControllerDelegate
     if chromeVisible != wasVisible { setChromeVisible(chromeVisible, closingOverlay: overlayOpen) }
     syncFlutter()
     updateMinimizePan()
+    SpikeProbe.shared.afterApply()  // SPIKE
   }
 
   func setSidebarVisible(_ visible: Bool) {
diff --git a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift
index 4252b48..a87cf9f 100644
--- a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift
+++ b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift
@@ -27,6 +27,13 @@ final class PassThroughView: UIView {
     // §7.8).
     let top = (selected as? UINavigationController)?.topViewController?.viewIfLoaded
       ?? selected?.viewIfLoaded
+    // SPIKE (probe A): the leading 20 pt of a pushed page goes to UIKit,
+    // whose edge recognizer drives the pop (and Flutter).
+    if SpikeProbe.shared.mode == "uikit", let nav = selected as? ShellNavController,
+      nav.viewControllers.count > 1, convert(point, to: tabsView).x < 20, let hit
+    {
+      return hit
+    }
     guard Self.isBackground(hit, chainFrom: top, tabsView: tabsView) else { return hit }
     // Platform views inside Flutter are subviews of the Flutter view, so its
     // own hitTest finds them.
diff --git a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift
index 422b072..a2ef591 100644
--- a/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift
+++ b/liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift
@@ -1,3 +1,4 @@
+import Flutter  // SPIKE
 import UIKit
 
 /// The clear navigation controller of a tab with a native navigation bar
@@ -14,6 +15,13 @@ final class ShellNavController: UINavigationController {
 
   let rootHost: PageHostController
 
+  // SPIKE (VK-440, throwaway): probe B's interactive pop.
+  var spikeInteraction: UIPercentDrivenInteractiveTransition?
+  var spikeBypass = false
+  var spikePending: (() -> Void)?
+  var spikeUIKitPop = false
+  let spikeDelegate = SpikeNavDelegate()
+
   init(root: PageHostController) {
     rootHost = root
     super.init(nibName: nil, bundle: nil)
@@ -36,7 +44,15 @@ final class ShellNavController: UINavigationController {
   // would leave Flutter on the old page with no back button.
 
   override func popViewController(animated: Bool) -> UIViewController? {
-    guard proposePop != nil, viewControllers.count > 1 else {
+    // SPIKE (probe A): UIKit's own interactive pop starts here.
+    if SpikeProbe.shared.mode == "uikit", let state = interactivePopGestureRecognizer?.state,
+      state == .began || state == .changed
+    {
+      let popped = super.popViewController(animated: animated)
+      spikeUIKitBegan()
+      return popped
+    }
+    guard !spikeBypass, proposePop != nil, viewControllers.count > 1 else {
       return super.popViewController(animated: animated)
     }
     proposePop?(viewControllers.count - 2)
@@ -65,7 +81,7 @@ final class ShellNavController: UINavigationController {
     navigationBar.prefersLargeTitles = true
     // Q14: Flutter owns the swipe-back in P3b-1; the native bar follows
     // when the Flutter route commits (spec §7.6).
-    interactivePopGestureRecognizer?.isEnabled = false
+    interactivePopGestureRecognizer?.isEnabled = SpikeProbe.shared.mode == "uikit"  // SPIKE (A)
     interactiveContentPopGestureRecognizer?.isEnabled = false
   }
 
@@ -83,8 +99,20 @@ final class ShellNavController: UINavigationController {
     _ pages: [NativePage], rootTitle: String, tabIndex: Int, shown: Bool,
     events: NativeShellFlutterApiProtocol
   ) {
+    // SPIKE: a config that arrives mid-swipe waits for the transition.
+    if spikeInteraction != nil || spikeUIKitPop {
+      SpikeProbe.shared.event("deferred", "tab=\(tabIndex) pages=\(pages.count) count=\(viewControllers.count)")
+      spikePending = { [weak self] in
+        self?.applyPages(pages, rootTitle: rootTitle, tabIndex: tabIndex, shown: shown, events: events)
+      }
+      return
+    }
+    if max(pages.count, 1) != viewControllers.count {
+      SpikeProbe.shared.event("apply", "tab=\(tabIndex) pages=\(pages.count) count=\(viewControllers.count)")
+    }
     let wanted = pages.isEmpty ? [NativePage(title: rootTitle, largeTitle: nil)] : pages
     proposePop = { index in
+      SpikeProbe.shared.event("propose", "tab=\(tabIndex) index=\(index)")
       events.onPopToPage(tab: Int64(tabIndex), index: Int64(index)) { result in
         #if DEBUG
           if case .failure(let error) = result {
@@ -100,6 +128,7 @@ final class ShellNavController: UINavigationController {
       let host = PageHostController()
       host.hidesBottomBarWhenPushed = Self.hidesBarWhenPushed
       host.onBack = {
+        SpikeProbe.shared.event("back", "tab=\(tabIndex)")
         events.onBackTapped(tab: Int64(tabIndex)) { result in
           #if DEBUG
             if case .failure(let error) = result {
@@ -276,3 +305,312 @@ final class PageHostController: UIViewController {
     navigationItem.leftBarButtonItem = item
   }
 }
+
+// MARK: - SPIKE (VK-440): throwaway probe code, never committed
+
+/// Probe B's native half: Flutter's back gesture drives an interactive pop
+/// of this controller through the `liquid_shell/spike` channel.
+@available(iOS 26.0, *)
+extension ShellNavController {
+  func spikeBegin(_ progress: Double) {
+    guard spikeInteraction == nil, transitionCoordinator == nil, viewControllers.count > 1 else {
+      SpikeProbe.shared.event(
+        "beginRefused",
+        "count=\(viewControllers.count) coordinator=\(transitionCoordinator != nil) active=\(spikeInteraction != nil)"
+      )
+      return
+    }
+    let interaction = UIPercentDrivenInteractiveTransition()
+    spikeInteraction = interaction
+    spikeDelegate.interaction = interaction
+    delegate = spikeDelegate
+    spikeBypass = true
+    let popped = popViewController(animated: true)
+    spikeBypass = false
+    let coordinator = transitionCoordinator
+    SpikeProbe.shared.event(
+      "began",
+      "popped=\(popped != nil) interactive=\(coordinator?.isInteractive ?? false) count=\(viewControllers.count)"
+    )
+    guard let coordinator else {
+      spikeInteraction = nil
+      delegate = nil
+      return
+    }
+    coordinator.animate(alongsideTransition: nil) { [weak self] context in
+      self?.spikeDone(cancelled: context.isCancelled)
+    }
+    interaction.update(CGFloat(min(max(progress, 0), 1)))
+    SpikeProbe.shared.startLink(nav: self)
+  }
+
+  /// Probe A: UIKit's recognizer started an interactive pop; Flutter
+  /// follows its percent (`sendUIKit`), once per display frame.
+  func spikeUIKitBegan() {
+    guard let coordinator = transitionCoordinator else {
+      SpikeProbe.shared.event("beginRefused", "uikit: no coordinator")
+      return
+    }
+    spikeUIKitPop = true
+    let tab = SpikeProbe.shared.tabIndex(of: self)
+    SpikeProbe.shared.event(
+      "began", "popped=true interactive=\(coordinator.isInteractive) count=\(viewControllers.count)")
+    SpikeProbe.shared.sendUIKit("began", tab: tab, progress: 0)
+    SpikeProbe.shared.startLink(nav: self, uikitTab: tab)
+    coordinator.notifyWhenInteractionChanges { context in
+      SpikeProbe.shared.sendUIKit(
+        context.isCancelled ? "cancel" : "commit", tab: tab,
+        progress: Double(context.percentComplete))
+    }
+    coordinator.animate(alongsideTransition: nil) { [weak self] context in
+      self?.spikeUIKitPop = false
+      self?.spikeDone(cancelled: context.isCancelled)
+    }
+  }
+
+  func spikeUpdate(_ progress: Double) {
+    spikeInteraction?.update(CGFloat(min(max(progress, 0), 1)))
+  }
+
+  func spikeEnd(cancelled: Bool) {
+    guard let interaction = spikeInteraction else { return }
+    SpikeProbe.shared.event(
+      cancelled ? "cancel" : "finish", String(format: "percent=%.4f", interaction.percentComplete))
+    if cancelled { interaction.cancel() } else { interaction.finish() }
+  }
+
+  func spikeDone(cancelled: Bool) {
+    spikeInteraction = nil
+    spikeDelegate.interaction = nil
+    delegate = nil
+    SpikeProbe.shared.stopLink()
+    SpikeProbe.shared.event("done", "cancelled=\(cancelled) count=\(viewControllers.count)")
+    let pending = spikePending
+    spikePending = nil
+    pending?()
+    SpikeProbe.shared.flush()
+  }
+}
+
+/// A pop that moves the clear hosts (nothing visible) under a
+/// percent-driven interaction; UIKit animates its bar.
+@available(iOS 26.0, *)
+final class SpikeNavDelegate: NSObject, UINavigationControllerDelegate,
+  UIViewControllerAnimatedTransitioning
+{
+  var interaction: UIPercentDrivenInteractiveTransition?
+
+  func navigationController(
+    _ navigationController: UINavigationController,
+    animationControllerFor operation: UINavigationController.Operation,
+    from fromVC: UIViewController, to toVC: UIViewController
+  ) -> UIViewControllerAnimatedTransitioning? {
+    operation == .pop && interaction != nil ? self : nil
+  }
+
+  func navigationController(
+    _ navigationController: UINavigationController,
+    interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
+  ) -> UIViewControllerInteractiveTransitioning? { interaction }
+
+  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
+    -> TimeInterval
+  { 0.35 }
+
+  func animateTransition(using context: UIViewControllerContextTransitioning) {
+    guard let from = context.view(forKey: .from), let to = context.view(forKey: .to),
+      let toVC = context.viewController(forKey: .to)
+    else { return context.completeTransition(false) }
+    context.containerView.insertSubview(to, belowSubview: from)
+    to.frame = context.finalFrame(for: toVC)
+    let width = context.containerView.bounds.width
+    UIView.animate(
+      withDuration: transitionDuration(using: context), delay: 0, options: [.curveLinear]
+    ) {
+      from.transform = CGAffineTransform(translationX: width, y: 0)
+    } completion: { _ in
+      from.transform = .identity
+      context.completeTransition(!context.transitionWasCancelled)
+    }
+  }
+}
+
+/// The spike's switchboard. Mode from the launch environment
+/// LIQUID_SHELL_SPIKE: off (default: nothing), timings (logs only),
+/// observe and drive (Flutter's gesture drives the bar), uikit (UIKit's
+/// recognizer drives Flutter). Rows go to Documents/spike-<run>.csv
+/// (LIQUID_SHELL_SPIKE_RUN), all times in µs of CACurrentMediaTime, the
+/// clock Flutter's frame times use.
+@available(iOS 26.0, *)
+final class SpikeProbe: NSObject {
+  static let shared = SpikeProbe()
+
+  let mode = ProcessInfo.processInfo.environment["LIQUID_SHELL_SPIKE"] ?? "off"
+  let run = ProcessInfo.processInfo.environment["LIQUID_SHELL_SPIKE_RUN"] ?? "run"
+  let showsSidebar = ProcessInfo.processInfo.environment["LIQUID_SHELL_SPIKE_SIDEBAR"] == "1"
+  weak var tabs: NativeTabsController?
+  private(set) var channel: FlutterMethodChannel?
+  private var rows: [String] = []
+  private var file: FileHandle?
+  private var link: CADisplayLink?
+  private weak var linkNav: ShellNavController?
+  private var uikitTab: Int?
+  private var sidebarShown = false
+  private let label = UILabel(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
+
+  var on: Bool { mode != "off" }
+  var drivesBar: Bool { mode == "observe" || mode == "drive" }
+
+  static func now() -> Int64 { Int64((CACurrentMediaTime() * 1_000_000).rounded()) }
+
+  func attach(messenger: FlutterBinaryMessenger) {
+    guard on, channel == nil else { return }
+    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
+    let url = dir.appendingPathComponent("spike-\(run).csv")
+    FileManager.default.createFile(atPath: url.path, contents: nil)
+    file = try? FileHandle(forWritingTo: url)
+    let channel = FlutterMethodChannel(name: "liquid_shell/spike", binaryMessenger: messenger)
+    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
+    self.channel = channel
+    write(
+      "S,\(Self.now()),mode=\(mode),run=\(run),model=\(UIDevice.current.model),"
+        + "os=\(UIDevice.current.systemVersion)")
+    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
+      self?.flush()
+      self?.updateLabel()
+    }
+    label.textColor = .clear
+    label.isUserInteractionEnabled = false
+    label.accessibilityIdentifier = "spikeProbe"
+  }
+
+  func write(_ row: String) {
+    if on { rows.append(row) }
+  }
+
+  func event(_ name: String, _ detail: String = "") {
+    write("E,\(Self.now()),\(name),\(detail)")
+  }
+
+  private var lastFlush = CACurrentMediaTime()
+
+  /// Writes the buffered rows: not during a swipe (the display link runs)
+  /// unless the last write is 3 s old, so a stuck swipe is logged too.
+  func flush() {
+    guard link == nil || CACurrentMediaTime() - lastFlush > 3, !rows.isEmpty, let file else {
+      return
+    }
+    lastFlush = CACurrentMediaTime()
+    let data = Data((rows.joined(separator: "\n") + "\n").utf8)
+    rows.removeAll(keepingCapacity: true)
+    try? file.write(contentsOf: data)
+  }
+
+  private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
+    let now = Self.now()
+    let args = call.arguments as? [Any] ?? []
+    let fields = args.map { "\($0)" }.joined(separator: ",")
+    switch call.method {
+    case "mode":
+      return result(mode)
+    case "gesture":
+      // [phase, tab, seq, progress, frameUs, frameNumber, previous send µs]
+      write("M,\(now),\(fields)")
+      if drivesBar, args.count >= 4, let phase = args[0] as? String,
+        let tab = (args[1] as? NSNumber)?.intValue,
+        let progress = (args[3] as? NSNumber)?.doubleValue,
+        let nav = tabs?.navControllers[tab]
+      {
+        switch phase {
+        case "began": nav.spikeBegin(progress)
+        case "changed": nav.spikeUpdate(progress)
+        case "commit": nav.spikeEnd(cancelled: false)
+        case "cancel": nav.spikeEnd(cancelled: true)
+        default: break
+        }
+      }
+    case "stack":
+      write("K,\(now),\(fields)")
+    case "timings":
+      // 6 ints per frame: number, vsyncStart, buildStart, buildFinish,
+      // rasterStart, rasterFinish.
+      var index = 0
+      while index + 6 <= args.count {
+        write("T," + args[index..<index + 6].map { "\($0)" }.joined(separator: ","))
+        index += 6
+      }
+    case "lifecycle":
+      write("Y,\(now),\(fields)")
+    default:
+      write("U,\(now),\(call.method),\(fields)")
+    }
+    result(nil)
+  }
+
+  func startLink(nav: ShellNavController, uikitTab: Int? = nil) {
+    stopLink()
+    linkNav = nav
+    self.uikitTab = uikitTab
+    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
+    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
+    link.add(to: .main, forMode: .common)
+    self.link = link
+    event("link", "maxFps=\(nav.view.window?.windowScene?.screen.maximumFramesPerSecond ?? 0)")
+  }
+
+  func stopLink() {
+    link?.invalidate()
+    link = nil
+    uikitTab = nil
+  }
+
+  /// Probe A: the tab of [nav] in the shell.
+  func tabIndex(of nav: ShellNavController) -> Int {
+    tabs?.navControllers.first { $0.value === nav }?.key ?? -1
+  }
+
+  /// Probe A, native -> Dart: [phase] began / changed / commit / cancel
+  /// with UIKit's percent.
+  func sendUIKit(_ phase: String, tab: Int, progress: Double) {
+    write("N,\(Self.now()),\(phase),\(tab),\(progress)")
+    channel?.invokeMethod("uikit", arguments: [phase, tab, progress])
+  }
+
+  /// One row per display frame while a swipe runs: the callback time, the
+  /// frame's target time, the probe's and UIKit's percent, Flutter's top
+  /// inset (G6) and the stack count.
+  @objc private func tick(_ link: CADisplayLink) {
+    guard let nav = linkNav else { return }
+    if let tab = uikitTab, let coordinator = nav.transitionCoordinator, coordinator.isInteractive {
+      sendUIKit("changed", tab: tab, progress: Double(coordinator.percentComplete))
+    }
+    write(
+      String(
+        format: "L,%lld,%lld,%.4f,%.4f,%.1f,%d", Self.now(),
+        Int64((link.targetTimestamp * 1_000_000).rounded()),
+        Double(nav.spikeInteraction?.percentComplete ?? -1),
+        Double(nav.transitionCoordinator?.percentComplete ?? -1),
+        Double(tabs?.flutter.viewIfLoaded?.safeAreaInsets.top ?? -1),
+        nav.viewControllers.count))
+  }
+
+  /// After each `apply`: the iPad edge run shows the sidebar once the
+  /// search tab is selected.
+  func afterApply() {
+    guard on, showsSidebar, !sidebarShown, let tabs, tabs.chromeVisible, !tabs.isCompact,
+      let search = tabs.searchIndex, tabs.selectedDestinationIndex == search
+    else { return }
+    sidebarShown = true
+    tabs.setSidebarVisible(true)
+  }
+
+  /// "spike edge=<sidebar's trailing x> tiled=<bool>" for XCUITest.
+  private func updateLabel() {
+    guard let tabs, let window = tabs.view.window else { return }
+    let tiled = tabs.currentState().sidebar == .tiled
+    let edge = tiled ? tabs.flutter.viewIfLoaded?.safeAreaInsets.left ?? 0 : 0
+    label.accessibilityLabel = String(format: "spike edge=%.1f tiled=%@", edge, tiled ? "true" : "false")
+    if label.superview !== window { window.addSubview(label) }
+    window.bringSubviewToFront(label)
+  }
+}
PATCH
echo written
```

- [ ] **Step 3: Write the harness patch.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
cat > "$SPIKE/spike-harness.patch" <<'PATCH'
diff --git a/liquid_shell/example/ios/RunnerUITests/SearchUITests.swift b/liquid_shell/example/ios/RunnerUITests/SearchUITests.swift
index 9947a96..472f41b 100644
--- a/liquid_shell/example/ios/RunnerUITests/SearchUITests.swift
+++ b/liquid_shell/example/ios/RunnerUITests/SearchUITests.swift
@@ -614,3 +614,137 @@ extension SearchUITests {
     XCTAssertTrue(caseList.waitForExistence(timeout: 10), "the case popped at the tab's root")
   }
 }
+
+// MARK: - VK-440 spike harness (THROWAWAY: never committed)
+
+/// Real edge swipes on the search tab's pushed page for the spike's
+/// numbers (spec 2026-10-28 §7.4). xcodebuild hands TEST_RUNNER_SPIKE_MODE
+/// and TEST_RUNNER_SPIKE_SWIPES to this runner as SPIKE_MODE and
+/// SPIKE_SWIPES; the app gets the mode as LIQUID_SHELL_SPIKE and writes
+/// Documents/spike-<mode>-<test>.csv. TEST_RUNNER_SPIKE_START_X (default
+/// 2) is where the cancel, commit and hold swipes start, in pt from the
+/// leading edge (B-drive's wider swipe: 60).
+final class SpikeSwipeUITests: XCTestCase {
+  private let timeout: TimeInterval = 90
+  private var mode: String { ProcessInfo.processInfo.environment["SPIKE_MODE"] ?? "observe" }
+  private var swipes: Int { Int(ProcessInfo.processInfo.environment["SPIKE_SWIPES"] ?? "") ?? 20 }
+  private var startX: CGFloat {
+    CGFloat(Double(ProcessInfo.processInfo.environment["SPIKE_START_X"] ?? "") ?? 2)
+  }
+
+  override func setUp() { continueAfterFailure = true }
+
+  private func launch(_ run: String, sidebar: Bool = false) -> XCUIApplication {
+    let app = XCUIApplication()
+    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "search"
+    app.launchEnvironment["LIQUID_SHELL_SPIKE"] = mode
+    app.launchEnvironment["LIQUID_SHELL_SPIKE_RUN"] = "\(mode)-\(run)"
+    if sidebar { app.launchEnvironment["LIQUID_SHELL_SPIKE_SIDEBAR"] = "1" }
+    app.launch()
+    // The bar's button (iPhone, iPad portrait), the detached circle, or the
+    // tiled sidebar's cell (iPad landscape).
+    let candidates = [
+      app.tabBars.buttons["Search"], app.cells["Search"], app.buttons["Search"].firstMatch,
+    ]
+    let deadline = Date().addingTimeInterval(timeout)
+    var tab: XCUIElement?
+    while tab == nil, Date() < deadline {
+      tab = candidates.first { $0.exists }
+      if tab == nil { Thread.sleep(forTimeInterval: 0.5) }
+    }
+    XCTAssertNotNil(tab, "the search tab")
+    tab?.tap()
+    return app
+  }
+
+  private func row(_ app: XCUIApplication, _ title: String) -> XCUIElement {
+    app.descendants(matching: .any)
+      .matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
+  }
+
+  private func back(_ app: XCUIApplication) -> XCUIElement {
+    app.navigationBars.buttons["BackButton"]
+  }
+
+  /// Pushes the "Nhạc Trịnh" category page (native back button).
+  private func openCategory(_ app: XCUIApplication) {
+    let category = row(app, "Nhạc Trịnh")
+    XCTAssertTrue(category.waitForExistence(timeout: 10), "the category grid")
+    category.tap()
+    XCTAssertTrue(back(app).waitForExistence(timeout: 10), "the pushed page")
+    Thread.sleep(forTimeInterval: 1)
+  }
+
+  /// One swipe from [startX] pt right of the window's leading edge to
+  /// [end] of the width at 500 pt/s, held [hold] s before the release.
+  private func swipe(_ app: XCUIApplication, from startX: CGFloat, to end: CGFloat, hold: TimeInterval = 0.2) {
+    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
+      .withOffset(CGVector(dx: startX, dy: 0))
+    start.press(
+      forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: end, dy: 0.5)),
+      withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: hold)
+  }
+
+  /// G3: released at 30 %, every swipe returns; the page stays.
+  func testSpikeCancelSwipes() {
+    let app = launch("cancel")
+    openCategory(app)
+    for index in 1...swipes {
+      swipe(app, from: startX, to: 0.3)
+      Thread.sleep(forTimeInterval: 1)
+      XCTAssertTrue(back(app).exists, "cancel \(index): the page stays")
+    }
+    Thread.sleep(forTimeInterval: 2.5)  // the probe's 1 s flush
+  }
+
+  /// G4: released at 80 %, every swipe pops one page.
+  func testSpikeCommitSwipes() {
+    let app = launch("commit")
+    for index in 1...swipes {
+      openCategory(app)
+      swipe(app, from: startX, to: 0.8)
+      XCTAssertTrue(back(app).waitForNonExistence(timeout: 5), "commit \(index): popped")
+      Thread.sleep(forTimeInterval: 0.5)
+    }
+    Thread.sleep(forTimeInterval: 2.5)
+  }
+
+  /// G1's visual half: three swipes held at 45 % for 1.5 s (the recording
+  /// shows the bar mid-swipe), then released: they return.
+  func testSpikeHoldSwipes() {
+    let app = launch("hold")
+    openCategory(app)
+    for index in 1...3 {
+      swipe(app, from: startX, to: 0.45, hold: 1.5)
+      Thread.sleep(forTimeInterval: 1)
+      XCTAssertTrue(back(app).exists, "hold \(index): the page stays")
+    }
+    Thread.sleep(forTimeInterval: 2.5)
+  }
+
+  /// G5: iPad in landscape, the sidebar tiled; each swipe starts 2-18 pt
+  /// right of the sidebar's trailing edge and commits.
+  func testSpikeTiledSidebarEdgeSwipes() throws {
+    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad")
+    XCUIDevice.shared.orientation = .landscapeLeft
+    addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
+    let app = launch("edge", sidebar: true)
+    let probe = app.staticTexts["spikeProbe"]
+    let deadline = Date().addingTimeInterval(15)
+    while !(probe.exists && probe.label.contains("tiled=true")), Date() < deadline {
+      Thread.sleep(forTimeInterval: 0.5)
+    }
+    XCTAssertTrue(probe.label.contains("tiled=true"), "the sidebar tiles: \(probe.label)")
+    let edge = CGFloat(
+      Double(probe.label.split(separator: " ").first { $0.hasPrefix("edge=") }?.dropFirst(5) ?? "")
+        ?? 0)
+    XCTAssertGreaterThan(edge, 100, "the sidebar's trailing edge")
+    for index in 1...swipes {
+      openCategory(app)
+      swipe(app, from: edge + 2 + CGFloat((index - 1) % 5) * 4, to: 0.85)
+      XCTAssertTrue(back(app).waitForNonExistence(timeout: 5), "edge \(index): popped")
+      Thread.sleep(forTimeInterval: 0.5)
+    }
+    Thread.sleep(forTimeInterval: 2.5)
+  }
+}
PATCH
echo written
```

- [ ] **Step 4: Write the analysis script and the two run scripts.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
cat > "$SPIKE/spike_analyze.dart" <<'DART'
// VK-440 spike: throwaway analysis of the probe's CSV logs (never
// committed). Usage: dart spike_analyze.dart <spike-*.csv>...
//
// Rows (all times µs of CACurrentMediaTime, the clock of Flutter's frame
// times): S start; M Dart gesture message (recv, phase, tab, seq,
// progress, frameUs, frameNumber, previous send µs); K Dart stack (recv,
// tab, length); T frame timing (number, vsyncStart, buildStart,
// buildFinish, rasterStart, rasterFinish); L display link tick (callback,
// target, probe percent, coordinator percent, Flutter top, count);
// E native event (t, name, detail); Y lifecycle (t, state).
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  for (final path in args) {
    _analyze(path);
  }
}

class _M {
  _M(
    this.recv,
    this.phase,
    this.seq,
    this.p,
    this.frameUs,
    this.frame,
    this.cost,
  );
  final int recv;
  final String phase;
  final int seq;
  final double p;
  final int frameUs;
  final int frame;
  final int cost;
}

class _L {
  _L(this.cb, this.target, this.inter, this.coord, this.top, this.count);
  final int cb;
  final int target;
  final double inter;
  final double coord;
  final double top;
  final int count;
}

class _T {
  _T(this.vsync, this.bs, this.bf, this.rs, this.rf);
  final int vsync;
  final int bs;
  final int bf;
  final int rs;
  final int rf;
}

class _E {
  _E(this.t, this.name, this.detail);
  final int t;
  final String name;
  final String detail;
}

class _Swipe {
  _Swipe(this.start);
  final int start;
  int? end;
  String outcome = 'open';
  final frames = <_M>[];
  _E? done;
  _E? began;
  int lenBefore = -1;
  int? lenAfter;
  int stackChangesDuring = 0;
}

double _pct(int a, int b) => b == 0 ? 0 : 100 * a / b;

int _p95(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  return sorted[math.min(sorted.length - 1, (sorted.length * 0.95).floor())];
}

void _analyze(String path) {
  final ms = <_M>[];
  final ls = <_L>[];
  final ts = <int, _T>{};
  final es = <_E>[];
  final ks = <(int, int)>[];
  final ys = <String>[];
  var header = '';
  for (final line in File(path).readAsLinesSync()) {
    final f = line.split(',');
    switch (f.first) {
      case 'S':
        header = f.skip(2).join(' ');
      case 'M' when f.length >= 9:
        ms.add(
          _M(
            int.parse(f[1]),
            f[2],
            int.parse(f[4]),
            double.parse(f[5]),
            int.parse(f[6]),
            int.parse(f[7]),
            int.parse(f[8]),
          ),
        );
      case 'L' when f.length >= 7:
        ls.add(
          _L(
            int.parse(f[1]),
            int.parse(f[2]),
            double.parse(f[3]),
            double.parse(f[4]),
            double.parse(f[5]),
            int.parse(f[6]),
          ),
        );
      case 'T' when f.length >= 7:
        ts[int.parse(f[1])] = _T(
          int.parse(f[2]),
          int.parse(f[3]),
          int.parse(f[4]),
          int.parse(f[5]),
          int.parse(f[6]),
        );
      case 'E' when f.length >= 3:
        es.add(_E(int.parse(f[1]), f[2], f.skip(3).join(',')));
      case 'K' when f.length >= 4:
        ks.add((int.parse(f[1]), int.parse(f[3])));
      case 'Y' when f.length >= 3:
        ys.add(f[2]);
    }
  }
  final mode = RegExp(r'mode=(\S+)').firstMatch(header)?.group(1) ?? '?';
  // Frame interval: the display link's, else Flutter's vsync spacing.
  final gaps = <int>[
    for (var i = 1; i < ls.length; i++)
      if (ls[i].target - ls[i - 1].target > 0) ls[i].target - ls[i - 1].target,
  ];
  if (gaps.isEmpty) {
    final v = ts.values.map((t) => t.vsync).toList()..sort();
    for (var i = 1; i < v.length; i++) {
      if (v[i] - v[i - 1] > 0) gaps.add(v[i] - v[i - 1]);
    }
  }
  gaps.sort();
  final interval = gaps.isEmpty ? 16667 : gaps[gaps.length ~/ 2];
  final hz = (1e6 / interval).round();

  // Swipes: Dart's began .. commit/cancel; native's began and done.
  final swipes = <_Swipe>[];
  _Swipe? open;
  for (final m in ms) {
    if (m.phase == 'began') {
      open = _Swipe(m.recv);
      swipes.add(open);
    } else if (open != null) {
      open.frames.add(m);
      if (m.phase == 'commit' || m.phase == 'cancel') {
        open
          ..end = m.recv
          ..outcome = m.phase;
        open = null;
      }
    }
  }
  for (final s in swipes) {
    final after = s.end ?? s.start;
    // Native's began: Dart's comes first in observe and drive, native's in
    // uikit; the nearest one within 200 ms either way.
    final starts =
        es
            .where((e) => e.name == 'began' && (e.t - s.start).abs() <= 200000)
            .toList()
          ..sort(
            (a, b) => (a.t - s.start).abs().compareTo((b.t - s.start).abs()),
          );
    s.began = starts.firstOrNull;
    s.done = es.where((e) => e.name == 'done' && e.t >= after).firstOrNull;
    final before = ks.where((k) => k.$1 <= s.start).lastOrNull;
    s.lenBefore = before?.$2 ?? -1;
    final limit = (s.done?.t ?? after) + 200000;
    for (final k in ks.where((k) => k.$1 > s.start && k.$1 <= limit)) {
      if (k.$2 != s.lenBefore) {
        s.stackChangesDuring++;
        s.lenAfter = k.$2;
      }
    }
  }

  // G1: per tick, the value each side shows; lag by value match.
  final deltas = <double>[];
  final cleanDeltas = <double>[];
  final lags = <int>[];
  final cleanLags = <int>[];
  var g2Frames = 0;
  var g2Over = 0;
  var g2Over2 = 0;
  final costs = <int>[];
  final topMoves = <double>[];
  var excluded = 0;
  for (final s in swipes) {
    final end = s.end ?? s.start;
    final ticks = ls.where((l) => l.cb >= s.start && l.cb <= end).toList();
    if (ticks.isNotEmpty) {
      final tops = ticks.map((l) => l.top);
      topMoves.add(tops.reduce(math.max) - tops.reduce(math.min));
    }
    // Flutter frames with their display time: the first tick whose
    // target is at or after the frame's raster end.
    final shown = <(int, double, bool)>[]; // (display, progress, clean)
    for (final m in s.frames) {
      final t = ts[m.frame];
      if (t == null) continue;
      final display = ls
          .where((l) => l.target >= t.rf)
          .map((l) => l.target)
          .firstOrNull;
      if (display == null) continue;
      final clean = t.bf - t.bs <= interval && t.rf - t.rs <= interval;
      shown.add((display, m.p, clean));
    }
    // A tick is clean when no over-budget Flutter frame is in flight at it
    // (from its vsync to two frames after its raster end) and the display
    // link fired on time and on the frame grid (a late or off-grid tick is
    // a main-thread stall).
    final janks = [
      for (final t in ts.values)
        if (t.bf - t.bs > interval || t.rf - t.rs > interval)
          (t.vsync, t.rf + 2 * interval),
    ];
    final cleanTargets = <int>{};
    for (final (index, tick) in ticks.indexed) {
      final q = mode == 'uikit' || tick.inter < 0 ? tick.coord : tick.inter;
      final flutter = shown.where((x) => x.$1 <= tick.target).lastOrNull;
      if (flutter == null || q < 0) continue;
      final d = q - flutter.$2;
      deltas.add(d.abs());
      final step = index == 0
          ? interval
          : tick.target - ticks[index - 1].target;
      final onTime =
          (tick.cb - tick.target).abs() <= interval / 2 &&
          step >= interval / 2 &&
          step <= 1.5 * interval;
      final clean =
          flutter.$3 &&
          onTime &&
          !janks.any((j) => j.$1 < tick.target && tick.target <= j.$2);
      if (clean) {
        cleanDeltas.add(d.abs());
        cleanTargets.add(tick.target);
      } else {
        excluded++;
      }
    }
    for (final (display, p, clean) in shown) {
      // The native tick nearest in time among those showing the value
      // closest to p, within ±10 frames.
      final near = ticks
          .where((l) => (l.target - display).abs() <= 10 * interval)
          .toList();
      if (near.isEmpty) continue;
      double value(_L l) => mode == 'uikit' || l.inter < 0 ? l.coord : l.inter;
      final best = near.map((l) => (value(l) - p).abs()).reduce(math.min);
      final match = near
          .where((l) => (value(l) - p).abs() <= best + 1e-4)
          .reduce(
            (a, b) => (a.target - display).abs() <= (b.target - display).abs()
                ? a
                : b,
          );
      final lag = ((match.target - display) / interval).round().abs();
      lags.add(lag);
      if (clean &&
          cleanTargets.contains(display) &&
          cleanTargets.contains(match.target)) {
        cleanLags.add(lag);
      }
    }
    // G2: Flutter frames whose vsync falls in the swipe.
    for (final t in ts.values) {
      if (t.vsync < s.start - interval || t.vsync > end + interval) continue;
      g2Frames++;
      final worst = math.max(t.bf - t.bs, t.rf - t.rs);
      if (worst > interval) g2Over++;
      if (worst > 2 * interval) g2Over2++;
    }
    costs.addAll(
      s.frames.where((m) => m.phase == 'changed').map((m) => m.cost),
    );
  }

  String share(List<double> d) =>
      '${_pct(d.where((x) => x <= 0.02).length, d.length).toStringAsFixed(1)}% '
      'max=${d.isEmpty ? 0 : d.reduce(math.max).toStringAsFixed(3)} n=${d.length}';
  String lagText(List<int> l) =>
      '0:${l.where((x) => x == 0).length} 1:${l.where((x) => x == 1).length} '
      '>=2:${l.where((x) => x >= 2).length}';
  // The two forms of G1 (spec §7.4) are reported apart: with a one-frame
  // lag they disagree once the finger moves more than 0.02 per frame.
  bool deltaPass(List<double> d) =>
      d.isNotEmpty &&
      _pct(d.where((x) => x <= 0.02).length, d.length) >= 95 &&
      d.every((x) => x <= 0.05);
  bool framePass(List<int> l) => l.isNotEmpty && l.every((x) => x <= 1);

  final commits = swipes.where((s) => s.outcome == 'commit').toList();
  final cancels = swipes.where((s) => s.outcome == 'cancel').toList();
  final stuck = swipes.where((s) => s.outcome == 'open' || s.done == null);
  final refused = es.where((e) => e.name == 'beginRefused').length;
  final proposals = es.where((e) => e.name == 'propose').length;
  final backs = es.where((e) => e.name == 'back').length;
  final g3ok = cancels.where(
    (s) =>
        s.stackChangesDuring == 0 &&
        s.done != null &&
        s.done!.detail.contains('cancelled=true') &&
        s.done!.detail.contains('count=${s.lenBefore}'),
  );
  bool doneInTime(_Swipe s) =>
      s.done != null && s.end != null && s.done!.t - s.end! <= interval;
  final g4ok = commits.where(
    (s) =>
        s.lenAfter == s.lenBefore - 1 &&
        s.done != null &&
        s.done!.detail.contains('cancelled=false') &&
        s.done!.detail.contains('count=${s.lenBefore - 1}') &&
        doneInTime(s),
  );
  final nonResumed = ys.where((y) => y != 'resumed').length;
  final drives = mode == 'observe' || mode == 'drive' || mode == 'uikit';

  stdout
    ..writeln('== ${path.split('/').last}: $header')
    ..writeln('frame ${(interval / 1000).toStringAsFixed(2)} ms ($hz Hz)')
    ..writeln(
      'swipes began=${swipes.length} commit=${commits.length} '
      'cancel=${cancels.length} stuck=${stuck.length} refused=$refused '
      'proposals=$proposals backs=$backs',
    )
    ..writeln(
      'clock: recv-frame median '
      '${_median(ms.where((m) => m.phase == 'changed').map((m) => m.recv - m.frameUs).toList()) / 1000} ms',
    );
  if (drives) {
    stdout
      ..writeln(
        'G1 all ticks: |d|<=0.02 ${share(deltas)} -> '
        '${deltaPass(deltas) ? 'PASS' : 'FAIL'}; lag ${lagText(lags)} -> '
        '${framePass(lags) ? 'PASS' : 'FAIL'}',
      )
      ..writeln(
        'G1 clean ticks ($excluded excluded): |d|<=0.02 ${share(cleanDeltas)} '
        '-> ${deltaPass(cleanDeltas) ? 'PASS' : 'FAIL'}; '
        'lag ${lagText(cleanLags)} -> ${framePass(cleanLags) ? 'PASS' : 'FAIL'}',
      );
  }
  stdout
    ..writeln(
      'G2 frames=$g2Frames over=${_pct(g2Over, g2Frames).toStringAsFixed(1)}% '
      'over2x=$g2Over2 send p95=${_p95(costs)} us (n=${costs.length}) -> '
      '${g2Frames > 0 && _pct(g2Over, g2Frames) <= 2 && g2Over2 == 0 && _p95(costs) <= 1000 ? 'PASS' : 'FAIL'} (debug build)',
    )
    ..writeln('G8 lifecycle not resumed: $nonResumed');
  // The baseline (timings) drives nothing: only G2 and G8 apply.
  if (mode == 'timings') return;
  stdout
    ..writeln('G3 cancels=${cancels.length} ok=${g3ok.length}')
    ..writeln(
      'G4 commits=${commits.length} ok=${g4ok.length} '
      '(proposals and backs must be 0)',
    )
    ..writeln(
      'G6 Flutter top moved max '
      '${topMoves.isEmpty ? 0 : topMoves.reduce(math.max).toStringAsFixed(1)} pt',
    );
  for (final (i, s) in swipes.indexed) {
    stdout.writeln(
      '  #${i + 1} ${s.outcome} frames=${s.frames.length} '
      'native=${s.began?.detail ?? '-'} done=${s.done?.detail ?? '-'} '
      'stack ${s.lenBefore}->${s.lenAfter ?? s.lenBefore} '
      'done-end=${s.done == null || s.end == null ? '-' : ((s.done!.t - s.end!) / 1000).toStringAsFixed(1)}ms',
    );
  }
}

double _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2].toDouble();
}
DART
cat > "$SPIKE/run.sh" <<'SH'
#!/usr/bin/env bash
# VK-440 spike (throwaway, never committed): one harness run.
#   build/spike/run.sh <udid> <tag> <mode> <swipes> <start_x> <test>...
# <test>: Cancel, Commit, Hold or TiledSidebarEdge (SpikeSwipeUITests'
# testSpike<test>Swipes). Builds and runs through tool/ios_xctest.sh, copies
# the app's logs to build/spike/runs/<tag>/ and prints their analysis
# (kept there as <mode>.txt).
set -uo pipefail
udid=$1 tag=$2 mode=$3 swipes=$4 startx=$5
shift 5
root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/build/spike/runs/$tag"
mkdir -p "$out"
only=()
for t in "$@"; do only+=("-only-testing:RunnerUITests/SpikeSwipeUITests/testSpike${t}Swipes"); done
data=$(xcrun simctl get_app_container "$udid" vn.lasoai.liquidShellExample data 2> /dev/null || true)
[ -z "$data" ] || command rm -f "$data"/Documents/spike-*.csv
cd "$root"
command rm -rf "$out/$mode.xcresult"
TEST_RUNNER_SPIKE_MODE=$mode TEST_RUNNER_SPIKE_SWIPES=$swipes TEST_RUNNER_SPIKE_START_X=$startx \
  FLUTTER="fvm flutter" tool/ios_xctest.sh "$udid" "$out/$mode.xcresult" 3600 600 900 "${only[@]}" \
  > "$out/$mode.log" 2>&1
echo "xctest exit $?"
xcrun xcresulttool get test-results summary --path "$out/$mode.xcresult" 2> /dev/null \
  | grep -E '"(result|totalTestCount|passedTests|failedTests|failureText)"' || true
data=$(xcrun simctl get_app_container "$udid" vn.lasoai.liquidShellExample data)
command cp "$data"/Documents/spike-*.csv "$out"/
fvm dart "$root/build/spike/spike_analyze.dart" "$out"/spike-"$mode"-*.csv | tee "$out/$mode.txt"
SH
cat > "$SPIKE/record.sh" <<'SH'
#!/usr/bin/env bash
# VK-440 spike (throwaway, never committed): the hold swipes on video.
#   build/spike/record.sh <udid> <tag> <mode> <start_x>
# Run after run.sh has built the app (same simulator). Records
# testSpikeHoldSwipes while the status-bar clock flips every 0.1 s (the
# recorder drops still frames otherwise; tool/frames_lib.sh), then tiles
# the top band at 2 fps into runs/<tag>/<mode>-hold.png: 6 frames per row,
# frame k (row by row, from 0) at k/2 s of <mode>-hold.mp4.
set -uo pipefail
udid=$1 tag=$2 mode=$3 startx=$4
root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/build/spike/runs/$tag"
mkdir -p "$out"
(
  i=0
  while :; do
    i=$((1 - i))
    xcrun simctl status_bar "$udid" override --time "9:4$i" > /dev/null 2>&1
    sleep 0.1
  done
) &
ticker=$!
xcrun simctl io "$udid" recordVideo --codec=h264 --force "$out/$mode-hold.mp4" > "$out/$mode-rec.log" 2>&1 &
recorder=$!
sleep 2
command rm -rf "$out/$mode-hold.xcresult"
(cd "$root/liquid_shell/example/ios" \
  && TEST_RUNNER_SPIKE_MODE=$mode TEST_RUNNER_SPIKE_START_X=$startx \
    xcodebuild test-without-building -workspace Runner.xcworkspace -scheme Runner \
    -destination "id=$udid" -derivedDataPath ../build/ios-derived \
    -only-testing:RunnerUITests/SpikeSwipeUITests/testSpikeHoldSwipes \
    -parallel-testing-enabled NO -collect-test-diagnostics never \
    -resultBundlePath "$out/$mode-hold.xcresult" -quiet > "$out/$mode-hold.log" 2>&1)
echo "hold test exit $?"
sleep 1
kill -INT "$recorder"
wait "$recorder" 2> /dev/null
kill "$ticker"
wait "$ticker" 2> /dev/null
xcrun simctl status_bar "$udid" clear
ffmpeg -v error -y -i "$out/$mode-hold.mp4" \
  -vf "fps=2,crop=iw:iw*0.4:0:0,scale=200:-1,tile=6x20" -frames:v 1 "$out/$mode-hold.png"
echo "strip: $out/$mode-hold.png ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out/$mode-hold.mp4") s)"
data=$(xcrun simctl get_app_container "$udid" vn.lasoai.liquidShellExample data)
command cp "$data"/Documents/spike-"$mode"-hold.csv "$out"/ 2> /dev/null || true
SH
chmod +x "$SPIKE/run.sh" "$SPIKE/record.sh"
bash -n "$SPIKE/run.sh" && bash -n "$SPIKE/record.sh" && echo "scripts ok"
rtk proxy fvm dart analyze "$SPIKE/spike_analyze.dart" | grep -cE ' (warning|error) - ' || true
```

Expected: `scripts ok`, then `0`. The repo's `very_good_analysis` also reports 8 style infos on this throwaway script (`prefer_foreach`, `cascade_invocations`, `lines_longer_than_80_chars`); they do not matter here.

- [ ] **Step 5: Apply both patches.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git apply --check "$SPIKE/spike-core.patch" && rtk git apply "$SPIKE/spike-core.patch"
rtk git apply --check "$SPIKE/spike-harness.patch" && rtk git apply "$SPIKE/spike-harness.patch"
rtk git diff --stat
rtk proxy fvm dart analyze liquid_shell/lib/src/shell/liquid_shell.dart
```

Expected: `6 files changed, 681 insertions(+), 2 deletions(-)` and `No issues found!`.

- [ ] **Step 6: Cancels and commits on the iPhone 26.5 first.** This run builds the app, then makes 20 cancels (released at 30 %) and 20 commits (released at 80 %) from x = 2 pt.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
read tag udid < <(sed -n 1p "$SPIKE/t2.pairs")
rtk proxy "$SPIKE/run.sh" "$udid" "$tag" observe 20 2 Cancel Commit
```

Expected: `xctest exit 0`, `"failedTests" : 0`, `"passedTests" : 2`, then two analyses (`spike-observe-cancel.csv`, `spike-observe-commit.csv`) with `swipes began=20`, `stuck=0 refused=0 proposals=0 backs=0`, `frame 16.67 ms (60 Hz)` and `clock: recv-frame median` between 2 and 10 ms (the clocks agree). With 2–3 swipes, the plan check printed:

```
== spike-observe-commit.csv: mode=observe run=observe-commit model=iPhone os=26.5
frame 16.67 ms (60 Hz)
swipes began=3 commit=3 cancel=0 stuck=0 refused=0 proposals=0 backs=0
clock: recv-frame median 5.329 ms
G1 all ticks: |d|<=0.02 94.9% max=0.117 n=195 -> FAIL; lag 0:141 1:2 >=2:4 -> FAIL
G1 clean ticks (17 excluded): |d|<=0.02 100.0% max=0.000 n=178 -> PASS; lag 0:136 1:0 >=2:0 -> PASS
G2 frames=154 over=1.3% over2x=2 send p95=200 us (n=144) -> FAIL (debug build)
G8 lifecycle not resumed: 0
G3 cancels=0 ok=0
G4 commits=3 ok=3 (proposals and backs must be 0)
G6 Flutter top moved max 0.0 pt
  #1 commit frames=47 native=popped=true interactive=true count=1 done=cancelled=false count=1 stack 2->1 done-end=9.9ms
```

(The excluded ticks were Flutter rasters of 72–79 ms at a swipe's first frames, a debug-build cost, and the display-link stalls after them. The script's own `G2 … -> PASS/FAIL` applies spec §7.4's profile numbers to a debug build; judge G2 by the simulator rule instead.) If this first run shows `stuck`, `beginRefused` or a broken log (no `L` rows, `clock` far from 2–10 ms), stop and debug inside the time box before the other pairs. Misses: see the measurement rules.

- [ ] **Step 7: The same on the other three pairs, plus the edge swipes on the iPads.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for n in 2 3 4; do
  read tag udid < <(sed -n ${n}p "$SPIKE/t2.pairs")
  df -h / | tail -1
  case $tag in
    ipad-*) rtk proxy "$SPIKE/run.sh" "$udid" "$tag" observe 20 2 Cancel Commit TiledSidebarEdge ;;
    *) rtk proxy "$SPIKE/run.sh" "$udid" "$tag" observe 20 2 Cancel Commit ;;
  esac
done
```

Expected per pair: as Step 6. On the iPads there is a third analysis, `spike-observe-edge.csv`, with `began=20 commit=20`: the test turns the iPad to landscape, where UIKit tiles the sidebar at launch. The plan check (iPad Air 11 M4, 26.5, 2 swipes) printed `swipes began=2 commit=2`, `G1 clean ticks (2 excluded): |d|<=0.02 100.0% max=0.000 n=220 -> PASS; lag 0:198 1:0 >=2:0 -> PASS`, `G4 commits=2 ok=2` and `G6 Flutter top moved max 60.0 pt`. If you run these one at a time, check the disk between pairs.

- [ ] **Step 8: The G2 baseline.** 10 commits per pair with no per-frame message (`timings`):

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
while read tag udid; do rtk proxy "$SPIKE/run.sh" "$udid" "$tag" timings 10 2 Commit < /dev/null | grep -E '^==|^G2|xctest exit'; done < "$SPIKE/t2.pairs"
```

Expected per pair: `xctest exit 0` and a `G2 frames=… over=…% over2x=… send p95=0 us (n=0)` line. Read only G2 and G8 in this mode; there is no per-frame send. The plan check (2 commits, iPhone 26.5) printed `G2 frames=91 over=3.3% over2x=2 send p95=0 us (n=0)`.

- [ ] **Step 9: The hold recordings: B-observe and the UIKit reference.** Three swipes are held at 45 % for 1.5 s. The `uikit` run is UIKit's own interactive pop of the same page, the visual reference.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
while read tag udid; do
  rtk proxy "$SPIKE/record.sh" "$udid" "$tag" observe 2 < /dev/null
  rtk proxy "$SPIKE/record.sh" "$udid" "$tag" uikit 2 < /dev/null
done < "$SPIKE/t2.pairs"
ls -la "$SPIKE"/runs/*/*-hold.png
```

Expected: `hold test exit 0` twice per pair, then eight strips. The iPads record in portrait (the edge test's teardown turns them back), where UIKit's top tab bar shows and the leading edge is the screen's. A strip tiles the top 40 % of the screen at 2 frames per second, 6 per row: frame k (row by row, from 0) is at k/2 s of the matching `.mp4`. Open each pair's two strips (the Read tool shows PNGs). The holds are the runs of 3 near-identical frames with Flutter's page shifted right. For a closer look, cut one held frame: `ffmpeg -v error -y -ss <k/2> -i "$SPIKE/runs/<tag>/<mode>-hold.mp4" -frames:v 1 -vf "crop=iw:iw*0.45:0:0,scale=600:-1" "$SPIKE/runs/<tag>/<mode>-held.png"`. Then write the judgement per the G1-visual rule, one line per mode, into `$SPIKE/runs/<tag>/visual.txt`, for example `observe: pushed title <state>, previous title <state>, back circle <state> -> follows|does not follow` and `uikit: …` (the reference).

What the plan check saw on the iPhone 17 Pro 26.5:
- **Reference (`uikit`), mid-hold:** "Nhạc Trịnh" slid toward the trailing edge with the page, "Search" sliding in from the leading edge, the back circle cross-fading.
- **B-observe, mid-hold:** the page about 40 % across; the back circle half faded over "Search", which already sat at rest at full opacity; "Nhạc Trịnh" gone.

That reads as "does not follow" for the titles. Confirm or correct it on all four pairs. A recording that holds no frames means the status-bar ticker failed: rerun `record.sh`.

- [ ] **Step 10: The verdict for B-observe.** Write `$SPIKE/runs/verdict-observe.txt`: one line per row G1 (numeric), G1 (visual), G2 (simulator rule, with the baseline's over-budget share beside it), G3, G4, G5, G6, G7, G8, each with the four pairs' numbers (the `observe.txt` and `timings.txt` lines, `visual.txt`) and PASS / FAIL / reported. End with one line, `B-observe: GO` or `B-observe: fails <rows>`, and the next task per "Order".

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for f in "$SPIKE"/runs/*/observe.txt "$SPIKE"/runs/*/timings.txt "$SPIKE"/runs/*/visual.txt; do echo "## $f"; grep -E '^==|^frame|^swipes|^G[0-9]|^observe|^uikit' "$f"; done
cat "$SPIKE/runs/verdict-observe.txt"
```

Expected: every pair's lines, then your verdict file. Paste both into the task report.

- [ ] **Step 11: Revert and check.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
rtk git checkout -- liquid_shell/lib liquid_shell_ios liquid_shell/example
rtk git status --short; echo "status exit $?"
```

Expected: no file listed, `status exit 0`. `$SPIKE` stays for Tasks 3–5.

- [ ] **Step 12: Clean up.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
while read tag udid; do
  rtk proxy xcrun simctl shutdown "$udid" 2> /dev/null || true
  rtk proxy xcrun simctl delete "$udid"
done < "$SPIKE/t2.pairs"
rtk proxy xcrun simctl list devices | grep -c 'vk440 t2' || true
command rm -rf liquid_shell/example/build "$SPIKE"/runs/*/*.xcresult
echo "2 <hours>" >> "$SPIKE/time.txt"
df -h / | tail -1
```

Expected: `0`. Write the task's real hours in place of `<hours>`.

**Checked when this plan was written** (the same patches and scripts, 2–3 swipes per test):
- iPhone 17 Pro 26.5: `observe` Cancel 2/2, Commit 3/3 and Hold recorded; `timings` Commit 2; `uikit` Hold recorded through `record.sh`.
- iPad Air 11 M4 26.5: `observe` TiledSidebarEdge 2/2.
- iPhone 17 Pro 27.0: `observe` Cancel 2/2, Commit 2/2.
- Seen on the way and fixed in this patch: (a) the first commit check lost its second swipe's rows, because the log was written only between swipes; the log now writes at the latest 3 s after the last write. The repeat run passed 3 of 3, so the cause of that miss is unknown. (b) In landscape the iPad shows the Search tab as a sidebar cell; the harness looks for it there too.
- Not run: the iPad on 27.0, the 20-swipe counts.

---

### Task 3: probe B-drive (only if "Order" says so)

The shell drives the route itself: a horizontal drag starting anywhere over the body (iOS 26's full-width swipe, not only Flutter's 20 pt edge strip) goes through Flutter's public back-gesture API. The overlay's translucent listener is hit before the page, so its recognizer wins the arena over the route's own edge detector. A vertical drag still scrolls the page. Task 2's forwarder sees the route's user gesture as before, so the native half is unchanged.

**Files:**
- Modify (never committed): as Task 2, plus `liquid_shell/lib/src/shell/liquid_shell.dart` through `build/spike/spike-drive.patch` (`_bodySubtree` wraps `widget.body` in a pass-through `Stack` whose first child is the body; `_SpikeDrive` at the file's end)
- Create (git-ignored): `build/spike/spike-drive.patch`, `build/spike/runs/<tag>/drive*`

**Interfaces:**
- Consumes: everything Task 2 produced in `$SPIKE`. `_SpikeProbe.mode` and `._top` (in `spike-core.patch`). Flutter 3.44.6 `ModalRoute.popGestureEnabled` (`widgets/routes.dart:1910`), `handleStartBackGesture`, `handleUpdateBackGestureProgress`, `handleCancelBackGesture` (`:566-586`), `NavigatorState.pop`, `didStopUserGesture`.
- Produces: `$SPIKE/runs/<tag>/drive.txt`, `drive-hold.png`, `visual.txt` lines, `$SPIKE/runs/verdict-drive.txt`.

- [ ] **Step 1: Baseline and simulators.** As Task 2 Step 1, with `t3` in the names and file names (`"vk440 t3 …"`, `$SPIKE/t3.udids`, `$SPIKE/t3.pairs`).

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git status --short                  # clean
df -h / | tail -1                       # at least 10 GB free
ls "$SPIKE/spike-core.patch" "$SPIKE/spike-harness.patch" "$SPIKE/run.sh" "$SPIKE/record.sh" "$SPIKE/spike_analyze.dart"
rtk proxy xcrun simctl create "vk440 t3 iPhone 17 Pro 26.5" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5 > "$SPIKE/t3.udids"
rtk proxy xcrun simctl create "vk440 t3 iPad Air 11 M4 26.5" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-26-5 >> "$SPIKE/t3.udids"
rtk proxy xcrun simctl create "vk440 t3 iPhone 17 Pro 27.0" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t3.udids"
rtk proxy xcrun simctl create "vk440 t3 iPad Air 11 M4 27.0" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t3.udids"
paste -d' ' <(printf 'iphone-26.5\nipad-26.5\niphone-27.0\nipad-27.0\n') "$SPIKE/t3.udids" > "$SPIKE/t3.pairs"
cat "$SPIKE/t3.pairs"
```

Expected: the five probe files listed, then four `<tag> <udid>` lines. A missing probe file means Task 2 Steps 2–4 did not run in this worktree: run them first.

- [ ] **Step 2: Write the B-drive patch.** It applies on top of `spike-core.patch`.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
cat > "$SPIKE/spike-drive.patch" <<'PATCH'
--- a/liquid_shell/lib/src/shell/liquid_shell.dart
+++ b/liquid_shell/lib/src/shell/liquid_shell.dart
@@ -3,6 +3,7 @@
 import 'dart:ui' as ui; // SPIKE
 
 import 'package:flutter/foundation.dart';
+import 'package:flutter/gestures.dart'; // SPIKE (B-drive)
 import 'package:flutter/material.dart';
 import 'package:flutter/rendering.dart';
 import 'package:flutter/scheduler.dart';
@@ -925,7 +926,16 @@
       onNotification: _onBranchNavigation,
       child: NotificationListener<ScrollNotification>(
         onNotification: (n) => _onBodyScroll(n, kind),
-        child: widget.body,
+        // SPIKE (B-drive): the shell's own drag over the body. The body
+        // stays the Stack's first child, so the overlay never rebuilds it.
+        child: Stack(
+          fit: StackFit.passthrough,
+          children: [
+            widget.body,
+            if (_spike.mode == 'drive')
+              Positioned.fill(child: _SpikeDrive(probe: _spike)),
+          ],
+        ),
       ),
     ),
   );
@@ -2258,6 +2268,104 @@
     _lifecycle?.dispose();
     if (_mode != 'off') {
       SchedulerBinding.instance.removeTimingsCallback(_onTimings);
+    }
+  }
+}
+
+/// SPIKE (B-drive): a horizontal drag anywhere over the body drives the
+/// top `LiquidPage` route through Flutter's public back-gesture API. It
+/// wins the gesture arena over the route's own 20 pt edge detector (its
+/// translucent listener is hit first). Commit: `navigator.pop()`, then
+/// `didStopUserGesture()` once the route's animation is dismissed; never
+/// `handleCommitBackGesture()` (it snaps the page back first).
+class _SpikeDrive extends StatefulWidget {
+  const _SpikeDrive({required this.probe});
+
+  final _SpikeProbe probe;
+
+  @override
+  State<_SpikeDrive> createState() => _SpikeDriveState();
+}
+
+class _SpikeDriveState extends State<_SpikeDrive> {
+  late final HorizontalDragGestureRecognizer _recognizer =
+      HorizontalDragGestureRecognizer(debugOwner: this)
+        ..onStart = _start
+        ..onUpdate = _update
+        ..onEnd = _end
+        ..onCancel = _cancel;
+  ModalRoute<Object?>? _route;
+  double _value = 1;
+
+  @override
+  void dispose() {
+    _recognizer.dispose();
+    super.dispose();
+  }
+
+  bool get _canDrive {
+    final route = widget.probe._top;
+    return route != null &&
+        route.isCurrent &&
+        route.popGestureEnabled &&
+        !(route.navigator?.userGestureInProgress ?? true);
+  }
+
+  void _start(DragStartDetails details) {
+    final route = widget.probe._top;
+    if (route == null || !route.isCurrent) return;
+    _route = route;
+    _value = 1;
+    route.handleStartBackGesture(progress: 1);
+  }
+
+  void _update(DragUpdateDetails details) {
+    final route = _route;
+    if (route == null) return;
+    final width = context.size?.width ?? 1;
+    _value = (_value - details.primaryDelta! / width).clamp(0.0, 1.0);
+    route.handleUpdateBackGestureProgress(progress: _value);
+  }
+
+  void _end(DragEndDetails details) {
+    final route = _route;
+    _route = null;
+    if (route == null) return;
+    final width = context.size?.width ?? 1;
+    final velocity = details.velocity.pixelsPerSecond.dx / width;
+    // Cupertino's rule: a fling decides, else the half-way mark.
+    final commit = velocity.abs() >= 1 ? velocity > 0 : _value < 0.5;
+    if (!commit) {
+      route.handleCancelBackGesture();
+      return;
     }
+    final navigator = route.navigator!;
+    final animation = route.animation!;
+    navigator.pop();
+    if (animation.isDismissed) {
+      navigator.didStopUserGesture();
+      return;
+    }
+    void stop(AnimationStatus status) {
+      if (!status.isDismissed) return;
+      animation.removeStatusListener(stop);
+      navigator.didStopUserGesture();
+    }
+
+    animation.addStatusListener(stop);
   }
+
+  void _cancel() {
+    final route = _route;
+    _route = null;
+    route?.handleCancelBackGesture();
+  }
+
+  @override
+  Widget build(BuildContext context) => Listener(
+    behavior: HitTestBehavior.translucent,
+    onPointerDown: (event) {
+      if (_canDrive) _recognizer.addPointer(event);
+    },
+  );
 }
PATCH
echo written
```

- [ ] **Step 3: Apply the three patches.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for p in spike-core spike-harness spike-drive; do rtk git apply --check "$SPIKE/$p.patch" && rtk git apply "$SPIKE/$p.patch"; done
rtk git diff --stat
rtk proxy fvm dart analyze liquid_shell/lib/src/shell/liquid_shell.dart
```

Expected: `6 files changed, 790 insertions(+), 3 deletions(-)` and `No issues found!`.

- [ ] **Step 4: Cancels and commits from x = 60 pt** (outside Flutter's 20 pt strip, so only the shell's drag can start them), the edge swipes on the iPads, and the hold recordings.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
while read tag udid; do
  df -h / | tail -1
  case $tag in
    ipad-*) rtk proxy "$SPIKE/run.sh" "$udid" "$tag" drive 20 60 Cancel Commit TiledSidebarEdge < /dev/null ;;
    *) rtk proxy "$SPIKE/run.sh" "$udid" "$tag" drive 20 60 Cancel Commit < /dev/null ;;
  esac
  rtk proxy "$SPIKE/record.sh" "$udid" "$tag" drive 60 < /dev/null
done < "$SPIKE/t3.pairs"
```

Expected per pair: `xctest exit 0`, `"failedTests" : 0`, analyses as in Task 2 (`mode=drive`), `hold test exit 0`, a strip `drive-hold.png`. The edge test always starts at the sidebar's edge + 2–18 pt, whatever `start_x` says. The plan check (iPhone 17 Pro 26.5, 2 swipes) printed for the commits:

```
== spike-drive-commit.csv: mode=drive run=drive-commit model=iPhone os=26.5
swipes began=2 commit=2 cancel=0 stuck=0 refused=0 proposals=0 backs=0
G1 clean ticks (8 excluded): |d|<=0.02 98.8% max=0.033 n=82 -> PASS; lag 0:58 1:0 >=2:0 -> PASS
G4 commits=2 ok=0 (proposals and backs must be 0)
  #1 commit … done=cancelled=false count=1 stack 2->1 done-end=76.1ms
  #2 commit … done=cancelled=false count=1 stack 2->1 done-end=26.4ms
```

`ok=0` there is the one-frame rule of G4: native finished 26–76 ms after Flutter's end. Report it as measured; it is part of the verdict.

- [ ] **Step 5: Visual judgement and verdict.** As Task 2 Step 9 (`drive-hold.png` against the pair's `uikit-hold.png` from Task 2) and Step 10, into `visual.txt` (`drive: …`) and `$SPIKE/runs/verdict-drive.txt`, ending with `B-drive: GO` or `B-drive: fails <rows>`.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for f in "$SPIKE"/runs/*/drive.txt "$SPIKE"/runs/*/visual.txt; do echo "## $f"; grep -E '^==|^frame|^swipes|^G[0-9]|^drive|^uikit' "$f"; done
cat "$SPIKE/runs/verdict-drive.txt"
```

- [ ] **Step 6: Revert, check and clean up.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git checkout -- liquid_shell/lib liquid_shell_ios liquid_shell/example
rtk git status --short; echo "status exit $?"
while read tag udid; do
  rtk proxy xcrun simctl shutdown "$udid" 2> /dev/null || true
  rtk proxy xcrun simctl delete "$udid"
done < "$SPIKE/t3.pairs"
rtk proxy xcrun simctl list devices | grep -c 'vk440 t3' || true
command rm -rf liquid_shell/example/build "$SPIKE"/runs/*/*.xcresult
echo "3 <hours>" >> "$SPIKE/time.txt"
df -h / | tail -1
```

Expected: no file listed, `status exit 0`, `0` simulators named `vk440 t3`.

If the task is skipped, append `3 skipped: <reason per Order>` to `$SPIKE/time.txt` instead.

**Checked when this plan was written:**
- iPhone 17 Pro 26.5, the three patches (Task 2's core with probe A merged in, then this patch): `drive` Commit 2/2 from x = 60 through `run.sh`.
- Earlier, on the core without probe A: `drive` Cancel 2/2 and Commit 2/2 from x = 60.
- Not run: the iPads, 27.0, the edge test and the hold recording in `drive` mode.

---

### Task 4: probe A, UIKit drives Flutter (only if "Order" says so)

Probe A is already in `spike-core.patch`, inert unless the `uikit` mode is on:
- `PassThroughView` gives a pushed page's leading 20 pt to UIKit.
- `interactivePopGestureRecognizer` is enabled.
- The override lets the pop through while the recognizer is `.began`/`.changed`, then `spikeUIKitBegan()` sends `began`, a `changed` per display frame (`transitionCoordinator.percentComplete`) and `commit`/`cancel` (`notifyWhenInteractionChanges`).
- Dart's `_onNative` drives the top route with `handleStartBackGesture` / `handleUpdateBackGestureProgress` / `handleCancelBackGesture`, and commits with `navigator.pop()`, then `didStopUserGesture()` once the route's animation is dismissed.
- `PopScope` is not mirrored natively (G10 is a GO task). A tiled sidebar leaves no reachable edge (evidence B-3), so G5 is expected to fail by construction: the edge test shows it.

**Files:**
- Modify (never committed): as Task 2 (`spike-core.patch`, `spike-harness.patch`)
- Create (git-ignored): `build/spike/runs/<tag>/uikit*`, `$SPIKE/runs/verdict-uikit.txt`

**Interfaces:**
- Consumes: Task 2's `$SPIKE` files; the `uikit-hold.png` strips Task 2 recorded (they are probe A's own hold recordings).
- Produces: `$SPIKE/runs/<tag>/uikit.txt`, `$SPIKE/runs/verdict-uikit.txt`.

- [ ] **Step 1: Baseline and simulators.** Task 3 Step 1's block with `t4` in place of `t3` (names `"vk440 t4 …"`, files `$SPIKE/t4.udids`, `$SPIKE/t4.pairs`):

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git status --short                  # clean
df -h / | tail -1                       # at least 10 GB free
ls "$SPIKE/spike-core.patch" "$SPIKE/spike-harness.patch" "$SPIKE/run.sh" "$SPIKE/spike_analyze.dart"
rtk proxy xcrun simctl create "vk440 t4 iPhone 17 Pro 26.5" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5 > "$SPIKE/t4.udids"
rtk proxy xcrun simctl create "vk440 t4 iPad Air 11 M4 26.5" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-26-5 >> "$SPIKE/t4.udids"
rtk proxy xcrun simctl create "vk440 t4 iPhone 17 Pro 27.0" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t4.udids"
rtk proxy xcrun simctl create "vk440 t4 iPad Air 11 M4 27.0" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-27-0 >> "$SPIKE/t4.udids"
paste -d' ' <(printf 'iphone-26.5\nipad-26.5\niphone-27.0\nipad-27.0\n') "$SPIKE/t4.udids" > "$SPIKE/t4.pairs"
cat "$SPIKE/t4.pairs"
```

- [ ] **Step 2: Apply the core and the harness.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for p in spike-core spike-harness; do rtk git apply --check "$SPIKE/$p.patch" && rtk git apply "$SPIKE/$p.patch"; done
rtk git diff --stat
```

Expected: `6 files changed, 681 insertions(+), 2 deletions(-)`.

- [ ] **Step 3: Cancels and commits from x = 2 pt (UIKit's edge), and the edge test on the iPads.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
while read tag udid; do
  df -h / | tail -1
  case $tag in
    ipad-*) rtk proxy "$SPIKE/run.sh" "$udid" "$tag" uikit 20 2 Cancel Commit TiledSidebarEdge < /dev/null ;;
    *) rtk proxy "$SPIKE/run.sh" "$udid" "$tag" uikit 20 2 Cancel Commit < /dev/null ;;
  esac
done < "$SPIKE/t4.pairs"
```

Expected per pair: `xctest exit 0` for Cancel and Commit. Native `began` events come from UIKit (`native=popped=true interactive=true count=1`), and `N` rows sit beside the `L` rows. In the iPads' edge analysis, expect no native `began` (`native=-`, `G1 … n=0`): the touch beside the sidebar reaches Flutter's own edge detector, not UIKit's, and the bar switches at the release as today. The analysis then counts those swipes as `stuck`, which here only means that no native transition began. The `popped` asserts may still pass. That is G5's failure by construction; record it. The plan check (iPhone 17 Pro 26.5, 2 swipes each) printed:

```
== spike-uikit-cancel.csv: mode=uikit run=uikit-cancel model=iPhone os=26.5
swipes began=2 commit=0 cancel=2 stuck=0 refused=0 proposals=0 backs=0
G3 cancels=2 ok=2
  #1 cancel frames=17 native=popped=true interactive=true count=1 done=cancelled=true count=2 stack 2->2 done-end=264.3ms
== spike-uikit-commit.csv: mode=uikit run=uikit-commit model=iPhone os=26.5
swipes began=2 commit=2 cancel=0 stuck=0 refused=0 proposals=0 backs=0
G1 clean ticks (7 excluded): |d|<=0.02 35.3% max=0.236 n=102 -> FAIL; lag 0:32 1:29 >=2:0 -> PASS
G4 commits=2 ok=0 (proposals and backs must be 0)
  #1 commit frames=32 native=popped=true interactive=true count=1 done=cancelled=false count=1 stack 2->1 done-end=251.0ms
```

Flutter follows UIKit one frame late: the Δ form fails and the frame form passes. After the release, UIKit finishes its own animation about 250 ms after Flutter's, and that decides G4's timing.

- [ ] **Step 4: Visual judgement and verdict.** Probe A's look is the reference itself (`uikit-hold.png` from Task 2): write `uikit (A): reference -> follows` into each `visual.txt` unless the strip shows otherwise. Then write `$SPIKE/runs/verdict-uikit.txt` as Task 2 Step 10, ending with `A: GO` or `A: fails <rows>`.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
for f in "$SPIKE"/runs/*/uikit.txt; do echo "## $f"; grep -E '^==|^frame|^swipes|^G[0-9]' "$f"; done
cat "$SPIKE/runs/verdict-uikit.txt"
```

- [ ] **Step 5: Revert, check and clean up.** Task 3 Step 6's block with `t4`:

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
rtk git checkout -- liquid_shell/lib liquid_shell_ios liquid_shell/example
rtk git status --short; echo "status exit $?"
while read tag udid; do
  rtk proxy xcrun simctl shutdown "$udid" 2> /dev/null || true
  rtk proxy xcrun simctl delete "$udid"
done < "$SPIKE/t4.pairs"
rtk proxy xcrun simctl list devices | grep -c 'vk440 t4' || true
command rm -rf liquid_shell/example/build "$SPIKE"/runs/*/*.xcresult
echo "4 <hours>" >> "$SPIKE/time.txt"
df -h / | tail -1
```

If the task is skipped, append `4 skipped: <reason per Order>` to `$SPIKE/time.txt` instead.

**Checked when this plan was written:** iPhone 17 Pro 26.5, the core with probe A: `uikit` Cancel 2/2, Commit 2/2 (above) and the Hold recording through `record.sh`. Not run: the iPads (the edge test included) and 27.0.

---

### Task 5: the write-up and the decision

**Files:**
- Create (committed): `docs/qa/p3b/s2-spike.md`
- Delete (git-ignored): `build/spike/` (logs and recordings stay out of the repository; their names go into the write-up)

**Interfaces:**
- Consumes: `$SPIKE/runs/b2/*.txt` (Task 1); `$SPIKE/runs/<tag>/{observe,timings,drive,uikit}.txt`, `visual.txt`, the `*-hold.png` names, `$SPIKE/runs/verdict-*.txt` (Tasks 2–4); `$SPIKE/time.txt`.
- Produces: the committed write-up; the decision VK-444 follows (spec §7.6).

- [ ] **Step 1: Collect the numbers.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
SPIKE=/Users/invoker/Projects/tuvi/liquid_shell-b1/build/spike
cat "$SPIKE/time.txt"
cat "$SPIKE"/runs/b2/*.txt
for f in "$SPIKE"/runs/verdict-*.txt; do echo "## $f"; cat "$f"; done
ls "$SPIKE"/runs/*/ | grep -E 'mp4|png|csv'
fvm --version 2> /dev/null | head -1; fvm flutter --version | head -1; xcodebuild -version | head -1
```

Expected: the hours per task (or `skipped: …`), the B-2 lines, one verdict file per probe run, the file names, the toolchain.

- [ ] **Step 2: Write `docs/qa/p3b/s2-spike.md`.** Fill every `⟨fill: …⟩` from Step 1. In "What the decision changes", keep only the paragraph that matches the decision.

````markdown
# P3b-2 spike S2: the native back swipe (VK-440, decides VK-444)

- **Plane:** VK-440 (this spike), VK-444 (decided here), parent VK-780.
- **Spec:** `docs/specs/2026-10-28-p3b2-page-bars-design.md` §7, §8.1. **Plan:** `docs/plans/2026-10-28-back-swipe-spike.md` (the probe code is there, as patches; it was never committed).
- **Date:** ⟨fill: date⟩. **Branch:** `VK-440-back-swipe-spike`. **Time used:** ⟨fill: total hours, per task from time.txt⟩ of the 2-day time box.
- **Toolchain:** ⟨fill: Flutter, Xcode⟩; debug builds (Flutter runs no profile build on simulators).

> **Tóm tắt (cho chủ sản phẩm).** ⟨fill: two or three Vietnamese sentences: the decision, the main number or the reason, and what the owner checks on a device⟩

## Decision

**⟨fill: GO (B-observe) | GO (B-drive) | GO (A) | NO-GO⟩.** ⟨fill: one paragraph: which blocking rows passed or failed, on which pairs, and why⟩

## Question (spec §7.1)

Can the native navigation bar follow the user's finger during a back swipe on any tab, frame by frame, with Flutter's page, without any public API change?

## Setup

| Pair | Device | Runtime | Display rate measured |
|---|---|---|---|
| iphone-26.5 | iPhone 17 Pro | iOS 26.5 | ⟨fill⟩ |
| ipad-26.5 | iPad Air 11-inch (M4) | iOS 26.5 | ⟨fill⟩ |
| iphone-27.0 | iPhone 17 Pro | iOS 27.0 | ⟨fill⟩ |
| ipad-27.0 | iPad Air 11-inch (M4) | iOS 27.0 | ⟨fill⟩ |

Each agent's own simulators, deleted afterwards. The swipes are XCUITest presses on the search tab's pushed page ("Nhạc Trịnh", example demo `search`): cancels released at 30 %, commits at 80 %, 500 pt/s, 20 each per pair. Holds stop at 45 % for 1.5 s and are recorded. On the iPads in landscape, the edge swipes start 2–18 pt right of the tiled sidebar. The log, the clean-tick rule and the two forms of G1 are as in the plan's "Measurement rules". Dart's frame time and the display link's target time agreed to the µs, so the pairing needs no clock offset.

## Probes run

| Probe | What | Ran | Notes |
|---|---|---|---|
| B-2 XCTest | the override against an interactive pop | ⟨fill: yes, pairs⟩ | ⟨fill⟩ |
| B-observe | the app's route gesture, forwarded per frame | ⟨fill⟩ | ⟨fill⟩ |
| B-drive | the shell's own drag through `PredictiveBackRoute` | ⟨fill: yes, or skipped and why⟩ | ⟨fill⟩ |
| A | UIKit's edge recognizer drives Flutter | ⟨fill: yes, or skipped and why⟩ | ⟨fill⟩ |

## B-2 (spec §7.2 step 4)

⟨fill: the SPIKE-B2 lines per runtime, then the three readings: the override swallows the pop UIKit's recognizer starts (no transition, a `popTo` proposal); past the override a percent-driven pop is interactive at once, follows `update`, and `viewControllers` drops the popped host for the whole transition; the bar's label layers read end values, so the recordings decide the bar's look⟩

## Numbers per row (spec §7.4)

One table per probe that ran; each cell the four pairs' values (iphone-26.5 / ipad-26.5 / iphone-27.0 / ipad-27.0).

### ⟨fill: probe⟩

| # | Criterion | iphone-26.5 | ipad-26.5 | iphone-27.0 | ipad-27.0 | Result |
|---|---|---|---|---|---|---|
| G1 numeric | clean ticks: frames ≥ 2 apart (decides); Δ ≤ 0.02 share, max Δ; all ticks beside | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ |
| G1 visual | bar mid-way at the 45 % hold, against UIKit's own pop | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ |
| G2 | over-budget share (baseline), frames over 2 budgets, send p95 (debug) | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill: simulator rule; profile = owner step⟩ |
| G3 | cancels ok / 20 | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ |
| G4 | commits ok / 20; done−end range; proposals | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ |
| G5 | edge swipes began / 20, G1 on them | — | ⟨fill⟩ | — | ⟨fill⟩ | ⟨fill⟩ |
| G6 | Flutter's top inset moved mid-swipe (pt) | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | reported (a GO task) |
| G7 | jump at the end (recordings) | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | reported (a GO task) |
| G8 | lifecycle reports other than resumed | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ | ⟨fill⟩ |
| G9–G11 | VoiceOver escape, refusing page, `PageView` | — | — | — | — | not measured (GO tasks) |

Harness misses (synthetic swipes that never began, rerun): ⟨fill: count per pair, or none⟩.

## The visual half of G1

⟨fill: per pair and probe, what the held frames show for the pushed title, the previous title and the back circle, against the UIKit reference; the strip file names⟩

## UIKit and Flutter calls that worked (or why not)

- **Flutter, observing:**
  - `NavigatorState.userGestureInProgressNotifier` marks a swipe from start to the end of its settle animation; the route's `isActive` at the end tells a commit from a cancel.
  - `1 − route.animation.value`, read in a post-frame callback, is the value that frame drew.
  - `SchedulerBinding.currentSystemFrameTimeStamp` equals `CADisplayLink.targetTimestamp` of the same frame (both `CACurrentMediaTime`).
  - `PlatformDispatcher.frameData.frameNumber` pairs a frame with its `FrameTiming`.
  - ⟨fill: anything that did not hold⟩
- **Flutter, driving** (B-drive, A): `handleStartBackGesture(progress: 1)`, `handleUpdateBackGestureProgress`, `handleCancelBackGesture`; commit with `navigator.pop()`, then `didStopUserGesture()` once the route's animation is dismissed. ⟨fill: worked / what failed⟩
- **UIKit, probe B:**
  - a bypass flag past `proposePop`;
  - a `UINavigationControllerDelegate` returning an animator that moves only the clear hosts, plus a `UIPercentDrivenInteractiveTransition`;
  - `update` per message; `finish()` / `cancel()` at Flutter's end;
  - a config arriving mid-swipe deferred until `transitionCoordinator.animate(alongsideTransition:completion:)` ends;
  - ⟨fill: whether UIKit's bar follows a custom interactive transition, from the visual half⟩
- **UIKit, probe A:**
  - `PassThroughView` gives the leading 20 pt of a pushed page to UIKit;
  - `interactivePopGestureRecognizer` passes the override while `.began`/`.changed`;
  - `transitionCoordinator.percentComplete` is read per display frame;
  - `notifyWhenInteractionChanges` gives the end;
  - ⟨fill: results; the tiled sidebar leaves no edge (B-3)⟩

## What the decision changes (spec §7.6)

⟨fill: keep the matching paragraph, delete the other⟩

**NO-GO.** Nothing more. B2's NO-GO guards are the shipped behaviour. VK-444 closes with this write-up. The README keeps "the native back swipe does not follow the finger". A finger-tracked swipe goes to the 0.1.x backlog: "UIKit drives Flutter" (probe A as a follow-up spike, if it did not run here) or a later Flutter.

**GO (⟨fill: probe⟩).** Nothing in B2–B5 depends on it; no API does. After 0.1.0, a branch `VK-444-swipe-sync` (0.1.x) adds internal pieces only:
- a Dart → native message, for example `setBackGesture(int tab, NativeBackGesturePhase phase, double progress)`;
- `ShellNavController.beginInteractivePop()` / `updateInteractivePop(_:)` / `finishInteractivePop(cancelled:)`;
- an inset hold while `transitionCoordinator?.isInteractive` (G6 measured ⟨fill⟩ pt);
- a shell-side forwarder from the top page's route;
- G6, G7, G9–G11 as tasks;
- its README line and CHANGELOG entry, shipped in that 0.1.x release.

A GO with "UIKit drives Flutter" also adds the `PassThroughView` carve-out and an internal `NativePage.interactivePop` flag. `LiquidPage`, `LiquidPageAction` and `LiquidShell` stay as they are.

## VK-444

⟨fill: NO-GO: VK-444 is done with this write-up; its NO-GO guards ship in B2 (spec §8.2). GO: VK-444 stays open for `VK-444-swipe-sync` after 0.1.0, with this write-up as its input; B2 ships the NO-GO guards for 0.1.0 either way⟩

## Owner steps (real devices; agents never touch them)

⟨fill: keep those that apply; a NO-GO needs none⟩
1. **G2 in profile mode** (an iPhone with a 120 Hz screen):
   - apply the plan's Task 2 patches (Steps 2, 3 and 5);
   - run the example from Xcode in the Profile configuration with the scheme's environment `LIQUID_SHELL_EXAMPLE_DEMO=search` and `LIQUID_SHELL_SPIKE=⟨fill: mode⟩`;
   - swipe back on the "Nhạc Trịnh" page 20 times;
   - download the app's container (Xcode, Devices and Simulators) and run `fvm dart spike_analyze.dart` on `Documents/spike-*.csv`.

   Pass: ≤ 2 % of frames over 8.3 ms, none over 16.7 ms, send p95 ≤ 1 ms, and G1 at 120 Hz.
2. **The bar's look under a finger:** a slow swipe held half-way on the same page, beside a system app's swipe (Settings): the titles and the back circle mid-way.
3. **iPad beside a tiled sidebar:** a finger swipe starting just right of the sidebar pops the page and the sidebar does not react.

## Recordings and logs (not in the repository)

⟨fill: the names under build/spike/runs/<tag>/: spike-<mode>-<test>.csv, <mode>.txt, <mode>-hold.mp4, <mode>-hold.png; deleted with build/spike after this write-up⟩
````

- [ ] **Step 3: Check the file.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
grep -c '⟨fill' docs/qa/p3b/s2-spike.md || true
grep -cE '^\*\*(NO-GO\.\*\* Nothing more|GO \(.*\)\.\*\* Nothing in B2)' docs/qa/p3b/s2-spike.md
rtk git status --short
```

Expected: `0` fills left; `1` paragraph kept under "What the decision changes"; then `?? docs/qa/p3b/s2-spike.md` only.

- [ ] **Step 4: Delete the spike's files and any simulator left.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
command rm -rf build/spike liquid_shell/example/build
rtk proxy xcrun simctl list devices | grep 'vk440 t' || echo "no vk440 simulators"
rtk git status --short
df -h / | tail -1
```

Expected: `no vk440 simulators` (otherwise delete those by UDID with `xcrun simctl delete <udid>`); `?? docs/qa/p3b/s2-spike.md` only.

- [ ] **Step 5: Commit.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-b1
bash .githooks/pre-commit && rtk git add docs/qa/p3b/s2-spike.md && rtk git commit -m "docs(docs): VK-440 back-swipe spike write-up

Decision: <GO (B-observe) | GO (B-drive) | GO (A) | NO-GO>. VK-444 follows it (spec 2026-10-28 §7.6).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
rtk git status --short; rtk git log --oneline -1
```

Write the decision in place of `<…>`. Expected: `✓ pre-commit passed` (it runs `make test`: several minutes), one commit, a clean tree.

---

## Self-review against the spec

| Spec | Where |
|---|---|
| §7.1 question | Goal; Task 5 write-up |
| §7.2 step 1 B-observe | Task 2 (`_SpikeProbe`, `run.sh … observe`) |
| §7.2 step 2 B-drive, commit with `pop()` + `didStopUserGesture()` | Task 3 (`_SpikeDrive`) |
| §7.2 step 3 native half (flag, delegate, percent-driven, finish / cancel, the next config equals native's) | `spike-core.patch` (`spikeBegin`, `SpikeNavDelegate`, the deferral); Task 1 shows the stack during the transition |
| §7.2 step 4 B-2 XCTest first | Task 1 |
| §7.3 A later, only on bar fidelity and time left | "Order"; Task 4 (also the visual reference in Task 2) |
| §7.4 G1–G11, devices, runtimes, rate, 20 swipes, time box | "Measurement rules"; Tasks 2–4; the 60 Hz finding |
| §7.5 thrown away / kept | Global values; Task 5 Step 4; the write-up's last section |
| §7.6 what GO / NO-GO changes | the write-up's section of that name |
| §8.1 scope, three tasks, files, evidence, owner check, no CHANGELOG | Tasks 1–5 (probe B = Tasks 1–3), "What is committed", owner steps |
| "Quyết định phát sinh" 13, 14, 15 | write-up "VK-444"; "Order"; "What is committed" |
