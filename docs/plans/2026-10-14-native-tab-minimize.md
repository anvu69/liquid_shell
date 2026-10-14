# liquid_shell VK-600: native tab bar minimize on scroll, Implementation Plan

> **Approval:** the owner approves this plan together with the spec `docs/specs/2026-10-14-native-tab-minimize-design.md`. Until the owner answers, this plan implements the recommended defaults of the spec's "Quyết định cần chủ sản phẩm xác nhận" table (Q1–Q12). A different answer changes only the tasks named in "Owner defaults applied".
>
> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On iOS 26+ at compact width, UIKit's native floating tab bar minimizes while the shell's Flutter body scrolls down, the way Apple Music does. It expands back as UIKit's own bar does: when a fling reaches the top, or on a tap on the circle. It also expands on a programmatic scroll to the top and on a change of the selected tab. The Flutter bar gets the same "a fling or a programmatic scroll to the top expands" rule (VK-600).

**Architecture:**

1. Each non-search tab host owns a **locked** `MinimizeProxy` (a `UIScrollView`), registered as its `.bottom` content scroll view. Only Dart's offsets move it.
2. While a tab is selected and the conditions hold, that proxy's own `panGestureRecognizer` is attached to the Flutter view. It never cancels or delays a touch. UIKit then sees a user-tracked scroll and runs `tabBarMinimizeBehavior = .onScrollDown` (spike `docs/qa/vk600/spike.md`, C8).
3. A pure Dart `MinimizeScrollTracker` turns the body's vertical scroll notifications into one offset per tab. The shell sends it once per frame over Pigeon (`setMinimizeScroll`).
4. When a fling or a programmatic scroll reaches the top, the tracker asks for an expand. Native toggles the behaviour (`.never` → `.onScrollDown`), the one public "expand now".

**Tech Stack:** Flutter 3.44.6 / Dart 3.12 (fvm), `flutter_test`, Pigeon 27.3.0, Swift / UIKit (iOS 26 APIs, iOS 27 SDK), XCTest and XCUITest (Xcode 27), simulators on iOS 26.5 and 27.0.

## Global Constraints

- **Floor:** Flutter `>=3.44.0`, Dart `^3.12.0`, iOS deployment target `15.0`. The native chrome code is `@available(iOS 26.0, *)`. fvm pins `3.44.6`.
- **Analysis:** `very_good_analysis` pinned to `10.3.0`. `dart analyze --fatal-infos --fatal-warnings` must be clean. Never loosen `analysis_options.yaml`.
- **Dependencies:** none added, anywhere.
- **Public API only.** No private UIKit selector, class name or KVC key in `lib/` or `ios/`, also not behind `#if DEBUG`. The spike read private names only to observe.
- **Pigeon:** edit `liquid_shell_ios/pigeons/native_shell.dart`, run `make pigeon`, and commit the source with both generated files. Never edit the generated files by hand, and never resolve a merge conflict in them by hand: regenerate.
- **TDD:** no production code without a test that failed first for the right reason. Run the single test, see it red, implement, see it green. Swift follows the same rule with XCTest (`make ios-unit`).
- **Commits:** `<type>(<scope>): <summary> (VK-600)`, with scopes `shell glass platform ios android example docs ci`. The message ends with a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Run `bash .githooks/pre-commit` by hand before every commit.
  - Stage by explicit path.
  - Never use `--no-verify`, never set `core.hooksPath`, never change git or flutter config.
  - No pushes, no new remotes, no publishing.
- **Simulators:** create your own (`xcrun simctl create "vk600 …"`) and delete them at the end. Never run `simctl shutdown all`. Never touch a physical device.
- **Disk:** keep at least 10 GB free (`df -h /`). Build the example with `-derivedDataPath liquid_shell/example/build/…` and remove that folder afterwards.
- **Builds for one simulator:** `flutter build ios --simulator` builds two architectures, which Xcode 27's lipo rejects. Use `fvm flutter build ios --simulator --debug --config-only`, then `xcodebuild … -destination id=<udid>` (as `tool/tab_frames.sh` does), or `make ios-unit` / `make ios-ui`.
- **Environment:** `rm` is aliased here, so use `command rm`.
- **Worktree:** `/Users/invoker/Projects/tuvi/liquid_shell-vk600` only. Never touch `liquid_shell-vk550` or the main checkout.
- **Version:** all four packages go to `0.1.0-dev.8` (Task 9), after VK-550's `dev.7`.

## Owner defaults applied

| Q | Default | Tasks |
|---|---|---|
| Q1 | `minimizeOnScroll` (default true) drives the native bar too | 4, 6, 9 |
| Q2 | The Flutter bar expands when a fling reaches the top | 1, 7 |
| Q3 | A programmatic scroll to the top expands both bars (native: behaviour toggle) | 1, 4, 6, 7 |
| Q4 | A selection change expands the native bar (toggle in `select`) | 5 |
| Q5 | No minimize while the search tab is selected | 1, 5, 6 |
| Q6 | Regular width never minimizes (UIKit); compact iPad does | 5, 8 |
| Q7 | Platform views do not minimize (the pan does not begin over them) | 3 |
| Q8 | Direct touches only (`allowedScrollTypesMask = []`) | 3 |
| Q9 | `bottomAccessory` stays out of scope | none |
| Q10 | `scrollsToTop = false` on the search page proxy too | 5 |
| Q11 | `0.1.0-dev.8` with CHANGELOGs | 9 |
| Q12 | The bottom scroll-edge effect is accepted if before/after screenshots match | 10 |

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `liquid_shell/lib/src/native/native_minimize.dart` (new) | 1 | `MinimizeScrollTracker`, `MinimizeScrollResult`, `kMinimizeAwayFromTop`, `nativeMinimizeActive` |
| `liquid_shell/test/unit/native_minimize_test.dart` (new) | 1 | Tracker and predicate |
| `liquid_shell_platform_interface/lib/src/native_chrome.dart` | 2 | `LiquidNativeChromeConfig.minimizeOnScroll` |
| `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart` | 2 | `setNativeMinimizeScroll`, `expandNativeTabBar` |
| `liquid_shell_platform_interface/test/{native_chrome,liquid_shell_platform}_test.dart` | 2 | Field and defaults |
| `liquid_shell/test/helpers/fake_native_platform.dart` | 2 | Records `minimizeScrolls`, `tabBarExpands` |
| `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/MinimizeProxy.swift` (new) | 3 | The locked proxy |
| `liquid_shell_ios/pigeons/native_shell.dart` + both generated files | 4 | Config field, two host methods, two snapshot fields |
| `liquid_shell_ios/lib/src/{mapping,platform}.dart`, `liquid_shell_ios/test/liquid_shell_ios_test.dart` | 4 | Mapping and boundary checks |
| `…/NativeTabsController.swift` (+ `TabHostController`), `…/NativeShellInstaller.swift` | 4, 5 | Behaviour, hosts, offsets, expand, pan attachment |
| `…/ShellNavController.swift` | 5 | `PageHostController.proxy.scrollsToTop = false` |
| `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` | 3–5 | `MinimizeProxyTests`, `NativeTabsTests` additions, config helpers |
| `liquid_shell/lib/src/native/native_host.dart`, `native_layout.dart`, `lib/src/shell/liquid_shell.dart` | 6, 7 | Claim calls, config, wiring, Flutter-bar rule |
| `liquid_shell/test/widget/native_minimize_test.dart` (new), `native_search_test.dart`, `shell_behaviour_test.dart` | 6, 7 | Widget tests |
| `liquid_shell/example/ios/RunnerUITests/MinimizeUITests.swift` (new), `liquid_shell/example/integration_test/native_shell_test.dart` | 8 | Real swipes; snapshot through the real channel |
| `liquid_shell/doc/native_chrome.md`, `doc/tab_bar.md`, CHANGELOG ×4, pubspecs | 9 | Docs and versions |
| `docs/qa/vk600/manual.md` (new), `docs/qa/vk600/acceptance.md` (new) | 10 | Device checklist, evidence |

---

### Task 0: Rebase onto main once VK-550 has merged

No code and no commit of its own.

- [ ] **Step 1: Wait for the merge.** The owner or the controller confirms that `VK-550-liquid-segmented-control` is merged into `main` on GitHub.
- [ ] **Step 2: Update and rebase.** `git fetch origin` only reads.

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk600
git status                        # clean, on VK-600-native-tab-minimize
git fetch origin
git rebase origin/main            # only the docs commits move; no conflict expected
git log --oneline -3              # the VK-600 docs commit on top of the VK-550 merge
grep -n "setSearchScope" liquid_shell_ios/pigeons/native_shell.dart   # VK-550 is in
grep -n "^version" liquid_shell/pubspec.yaml                          # 0.1.0-dev.7
```

- [ ] **Step 3: Green baseline.**

```bash
make get && make test
```

Expected: all green. If not, stop and report: the base is red, not VK-600.

---

### Task 1: The minimize scroll tracker (pure Dart)

**Files:**
- Create: `liquid_shell/lib/src/native/native_minimize.dart`
- Test: `liquid_shell/test/unit/native_minimize_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum MinimizeScrollResult { none, moved, expand }`, `const double kMinimizeAwayFromTop = 1`, and `final class MinimizeScrollTracker` with:
  - `double offsetOf(int tab)`;
  - `MinimizeScrollResult start({required int tab})`;
  - `MinimizeScrollResult update({required int tab, required double pixels, required double minScrollExtent, required double delta, required bool dragging})`;
  - `MinimizeScrollResult handleNotification(ScrollNotification n, {required int tab})`;
  - `void forget(int tab)`.

  Also `bool nativeMinimizeActive({required bool owner, required bool engaged, required bool compact, required bool minimizeOnScroll, required bool searchSelected, required bool hidden, required bool routeCurrent})`.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/unit/native_minimize_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/native/native_minimize.dart';

void main() {
  group('MinimizeScrollTracker (spec VK-600 §9.1)', () {
    late MinimizeScrollTracker t;
    setUp(() => t = MinimizeScrollTracker());

    MinimizeScrollResult drag(
      double pixels,
      double delta, {
      int tab = 0,
      double min = 0,
    }) => t.update(
      tab: tab,
      pixels: pixels,
      minScrollExtent: min,
      delta: delta,
      dragging: true,
    );

    MinimizeScrollResult fling(double pixels, double delta, {int tab = 0}) =>
        t.update(
          tab: tab,
          pixels: pixels,
          minScrollExtent: 0,
          delta: delta,
          dragging: false,
        );

    test('one scroll view: the offset is its pixels', () {
      t.start(tab: 0);
      expect(drag(40, 40), MinimizeScrollResult.moved);
      expect(drag(300, 260), MinimizeScrollResult.moved);
      expect(t.offsetOf(0), 300);
      expect(drag(300, 0), MinimizeScrollResult.none);
    });

    test('at and past the top: pixels below minScrollExtent', () {
      t.start(tab: 0);
      drag(100, 100);
      drag(-30, -130);
      expect(t.offsetOf(0), -30);
      t.start(tab: 0);
      drag(-100, 0, min: -100);
      expect(t.offsetOf(0), 0);
    });

    test('several views: continuous, then the snap to the top', () {
      t.start(tab: 0);
      drag(500, 500); // list A
      t.start(tab: 0);
      drag(50, -50); // list B, from 100
      expect(t.offsetOf(0), 450);
      drag(1, -49);
      expect(t.offsetOf(0), 401);
      drag(0, -1);
      expect(t.offsetOf(0), 0);
    });

    test('a view below its own top never reads as the top', () {
      t.start(tab: 1);
      drag(10, 10, tab: 1);
      t.start(tab: 1);
      drag(350, -50, tab: 1);
      expect(t.offsetOf(1), kMinimizeAwayFromTop);
    });

    test('tabs keep their own offsets; forget drops one', () {
      drag(200, 200);
      drag(80, 80, tab: 2);
      expect(t.offsetOf(0), 200);
      expect(t.offsetOf(2), 80);
      t.forget(2);
      expect(t.offsetOf(2), 0);
    });

    test('a fling up to the top expands, once per scroll', () {
      t.start(tab: 0);
      drag(400, 400);
      expect(fling(200, -200), MinimizeScrollResult.moved);
      expect(fling(-12, -212), MinimizeScrollResult.expand);
      expect(fling(-20, -8), MinimizeScrollResult.moved);
      expect(fling(0, 20), MinimizeScrollResult.moved); // the bounce back
      t.start(tab: 0);
      expect(fling(0, 0), MinimizeScrollResult.none);
    });

    test('a drag to the top never expands; nor does a bounce back', () {
      t.start(tab: 0);
      drag(300, 300);
      expect(drag(-40, -340), MinimizeScrollResult.moved);
      expect(fling(-10, 30), MinimizeScrollResult.moved);
      expect(fling(0, 10), MinimizeScrollResult.moved);
    });

    test('a programmatic scroll to the top expands', () {
      t.start(tab: 0);
      drag(600, 600);
      t.start(tab: 0); // animateTo starts its own scroll
      expect(fling(300, -300), MinimizeScrollResult.moved);
      expect(fling(0, -300), MinimizeScrollResult.expand);
    });

    testWidgets('the adapter reads vertical notifications only', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      FixedScrollMetrics metrics(double pixels, AxisDirection direction) =>
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: pixels,
            viewportDimension: 800,
            axisDirection: direction,
            devicePixelRatio: 3,
          );
      final tracker = MinimizeScrollTracker();
      expect(
        tracker.handleNotification(
          ScrollStartNotification(
            metrics: metrics(0, AxisDirection.down),
            context: context,
          ),
          tab: 0,
        ),
        MinimizeScrollResult.none,
      );
      expect(
        tracker.handleNotification(
          ScrollUpdateNotification(
            metrics: metrics(120, AxisDirection.right),
            context: context,
            scrollDelta: 120,
          ),
          tab: 0,
        ),
        MinimizeScrollResult.none,
      );
      expect(
        tracker.handleNotification(
          ScrollUpdateNotification(
            metrics: metrics(120, AxisDirection.down),
            context: context,
            scrollDelta: 120,
            dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
          ),
          tab: 0,
        ),
        MinimizeScrollResult.moved,
      );
      expect(tracker.offsetOf(0), 120);
      expect(
        tracker.handleNotification(
          ScrollUpdateNotification(
            metrics: metrics(0, AxisDirection.down),
            context: context,
            scrollDelta: -120,
          ),
          tab: 0,
        ),
        MinimizeScrollResult.expand,
      );
    });
  });

  group('nativeMinimizeActive (spec VK-600 §9.2)', () {
    bool active({
      bool owner = true,
      bool engaged = true,
      bool compact = true,
      bool minimizeOnScroll = true,
      bool searchSelected = false,
      bool hidden = false,
      bool routeCurrent = true,
    }) => nativeMinimizeActive(
      owner: owner,
      engaged: engaged,
      compact: compact,
      minimizeOnScroll: minimizeOnScroll,
      searchSelected: searchSelected,
      hidden: hidden,
      routeCurrent: routeCurrent,
    );

    test('only when every fact holds', () {
      expect(active(), isTrue);
      expect(active(owner: false), isFalse);
      expect(active(engaged: false), isFalse);
      expect(active(compact: false), isFalse);
      expect(active(minimizeOnScroll: false), isFalse);
      expect(active(searchSelected: true), isFalse);
      expect(active(hidden: true), isFalse);
      expect(active(routeCurrent: false), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify that it fails.**

Run: `cd liquid_shell && fvm flutter test test/unit/native_minimize_test.dart`.

Expected: FAIL. The compilation error is "Target of URI doesn't exist: 'package:liquid_shell/src/native/native_minimize.dart'".

- [ ] **Step 3: Write the minimal implementation**

```dart
// liquid_shell/lib/src/native/native_minimize.dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// What one scroll notification did to a [MinimizeScrollTracker].
enum MinimizeScrollResult {
  /// Nothing to send.
  none,

  /// The tab's offset changed.
  moved,

  /// The offset changed, and a fling or a programmatic scroll carried the
  /// content up to its top edge: expand the tab bar (spec VK-600 §9.1).
  expand,
}

/// The smallest offset while the scrolled view is away from its top: the
/// native bar never sees "at the top" before the content is.
const double kMinimizeAwayFromTop = 1;

/// One virtual scroll offset per destination for the native tab bar's
/// minimize (spec VK-600 §9.1): the pixels of a single scroll view, kept
/// continuous across several, snapped to the top edge when the scrolled
/// view reaches its own.
final class MinimizeScrollTracker {
  final Map<int, double> _offsets = {};
  final Set<int> _expanded = {};

  /// The offset of [tab]: positive below the top, zero or negative at it.
  double offsetOf(int tab) => _offsets[tab] ?? 0;

  /// A new scroll on [tab]: it may expand once.
  MinimizeScrollResult start({required int tab}) {
    _expanded.remove(tab);
    return MinimizeScrollResult.none;
  }

  /// The scrolled view of [tab] moved by [delta] to [pixels].
  MinimizeScrollResult update({
    required int tab,
    required double pixels,
    required double minScrollExtent,
    required double delta,
    required bool dragging,
  }) {
    final before = offsetOf(tab);
    final atTop = pixels <= minScrollExtent;
    final next = atTop
        ? pixels - minScrollExtent
        : math.max(before + delta, kMinimizeAwayFromTop);
    _offsets[tab] = next;
    // UIKit's rule (spike §3.1): a deceleration that reaches the top
    // expands; a drag into it does not, nor does the bounce back.
    if (!dragging && delta < 0 && atTop && _expanded.add(tab)) {
      return MinimizeScrollResult.expand;
    }
    return next == before
        ? MinimizeScrollResult.none
        : MinimizeScrollResult.moved;
  }

  /// The shell's adapter: vertical notifications at any depth.
  MinimizeScrollResult handleNotification(
    ScrollNotification n, {
    required int tab,
  }) {
    final metrics = n.metrics;
    if (metrics.axis != Axis.vertical) return MinimizeScrollResult.none;
    return switch (n) {
      ScrollStartNotification() => start(tab: tab),
      ScrollUpdateNotification(:final scrollDelta, :final dragDetails) =>
        update(
          tab: tab,
          pixels: metrics.pixels,
          minScrollExtent: metrics.minScrollExtent,
          delta: scrollDelta ?? 0,
          dragging: dragDetails != null,
        ),
      _ => MinimizeScrollResult.none,
    };
  }

  /// [tab] left the destinations.
  void forget(int tab) {
    _offsets.remove(tab);
    _expanded.remove(tab);
  }
}

/// Whether the shell drives the native tab bar's minimize (spec VK-600
/// §9.2); the native side attaches its pan under the same facts (§8.3).
bool nativeMinimizeActive({
  required bool owner,
  required bool engaged,
  required bool compact,
  required bool minimizeOnScroll,
  required bool searchSelected,
  required bool hidden,
  required bool routeCurrent,
}) =>
    owner &&
    engaged &&
    compact &&
    minimizeOnScroll &&
    !searchSelected &&
    !hidden &&
    routeCurrent;
```

- [ ] **Step 4: Run the test to verify that it passes.**

Run: `cd liquid_shell && fvm flutter test test/unit/native_minimize_test.dart`. Expected: PASS (10 tests).

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell/lib/src/native/native_minimize.dart liquid_shell/test/unit/native_minimize_test.dart && git commit -m "feat(shell): a virtual scroll offset per tab for the native minimize (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Platform interface: the config field and two calls

**Files:**
- Modify: `liquid_shell_platform_interface/lib/src/native_chrome.dart` (`LiquidNativeChromeConfig`)
- Modify: `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart`
- Modify: `liquid_shell/test/helpers/fake_native_platform.dart`
- Test: `liquid_shell_platform_interface/test/native_chrome_test.dart`, `liquid_shell_platform_interface/test/liquid_shell_platform_test.dart`

**Interfaces:**
- Produces:
  - `LiquidNativeChromeConfig({…, this.minimizeOnScroll = false})` and `final bool minimizeOnScroll`, part of `==`, `hashCode` and `toString`;
  - `Future<void> LiquidShellPlatform.setNativeMinimizeScroll({required int tab, required double offset})`;
  - `Future<void> LiquidShellPlatform.expandNativeTabBar()`.

  Both methods do nothing by default.
- `FakeNativePlatform` gains `final minimizeScrolls = <(int, double)>[]` and `int tabBarExpands = 0`.

- [ ] **Step 1: Write the failing tests**

```dart
// liquid_shell_platform_interface/test/native_chrome_test.dart (add to main)
test('minimizeOnScroll: off by default, part of equality (VK-600)', () {
  const off = LiquidNativeChromeConfig(engaged: true);
  const on = LiquidNativeChromeConfig(engaged: true, minimizeOnScroll: true);
  expect(off.minimizeOnScroll, isFalse);
  expect(LiquidNativeChromeConfig.dormant.minimizeOnScroll, isFalse);
  expect(on, isNot(off));
  expect(on.hashCode, isNot(off.hashCode));
  expect(
    on,
    const LiquidNativeChromeConfig(engaged: true, minimizeOnScroll: true),
  );
  expect(on.toString(), contains('minimizeOnScroll: true'));
});
```

```dart
// liquid_shell_platform_interface/test/liquid_shell_platform_test.dart (add to main)
test('the VK-600 members default to nothing and touch no channel', () async {
  final platform = _ExtendsFake();
  await platform.setNativeMinimizeScroll(tab: 0, offset: 120);
  await platform.expandNativeTabBar();
});
```

- [ ] **Step 2: Run the tests to verify that they fail.**

Run: `cd liquid_shell_platform_interface && fvm flutter test`. Expected: FAIL. The compilation errors are "No named parameter with the name 'minimizeOnScroll'" and "The method 'setNativeMinimizeScroll' isn't defined".

- [ ] **Step 3: Implement**
  - In `LiquidNativeChromeConfig`:
    - add `this.minimizeOnScroll = false` to the constructor;
    - add the field, with this dartdoc: "Whether the compact native tab bar minimizes while the body scrolls down (`LiquidShell.minimizeOnScroll`, spec VK-600)";
    - add `other.minimizeOnScroll == minimizeOnScroll` to `==`, `minimizeOnScroll` to `Object.hash` (12 values) and `minimizeOnScroll: $minimizeOnScroll` to `toString`.
  - In `LiquidShellPlatform`: add the two methods exactly as in spec §6.
  - In `FakeNativePlatform`: add the two records and the overrides.

```dart
  /// Every `setNativeMinimizeScroll`, as (tab, offset).
  final minimizeScrolls = <(int, double)>[];

  /// Number of `expandNativeTabBar` calls.
  int tabBarExpands = 0;

  @override
  Future<void> setNativeMinimizeScroll({
    required int tab,
    required double offset,
  }) async => minimizeScrolls.add((tab, offset));

  @override
  Future<void> expandNativeTabBar() async => tabBarExpands++;
```

- [ ] **Step 4: Run the tests to verify that they pass.**

Run: `cd liquid_shell_platform_interface && fvm flutter test && cd ../liquid_shell && fvm flutter test test/widget/native_chrome_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell_platform_interface/lib/src/native_chrome.dart liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart liquid_shell_platform_interface/test/native_chrome_test.dart liquid_shell_platform_interface/test/liquid_shell_platform_test.dart liquid_shell/test/helpers/fake_native_platform.dart && git commit -m "feat(platform): minimizeOnScroll in the native config, minimize scroll and expand calls (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `MinimizeProxy`, the locked proxy scroll view (Swift)

**Files:**
- Create: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/MinimizeProxy.swift`
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (new `MinimizeProxyTests`)

**Interfaces:**
- Produces: `@available(iOS 26.0, *) final class MinimizeProxy: UIScrollView`, with:
  - `private(set) var offset: Double`;
  - `weak var contentView: UIView?`;
  - `func setOffset(_ value: Double)`;
  - `static func begins(over hit: UIView?, content: UIView?) -> Bool`.

- [ ] **Step 1: Write the failing tests**

```swift
// RunnerTests.swift: a new test case, after PassThroughTests
@available(iOS 26.0, *)
final class MinimizeProxyTests: XCTestCase {
  private func proxy() -> MinimizeProxy {
    let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    let proxy = MinimizeProxy(frame: host.bounds)
    host.addSubview(proxy)
    return proxy
  }

  /// Spike C8: only Dart moves it; UIKit's own writes (its pan, its
  /// deceleration, an inset adjustment) are dropped.
  func testOnlySetOffsetMovesIt() {
    let proxy = proxy()
    proxy.setOffset(120)
    let y = proxy.contentOffset.y
    XCTAssertEqual(y, -proxy.adjustedContentInset.top + 120)
    proxy.contentOffset = CGPoint(x: 0, y: 999)
    proxy.setContentOffset(CGPoint(x: 0, y: 555), animated: false)
    XCTAssertEqual(proxy.contentOffset.y, y)
    XCTAssertEqual(proxy.offset, 120)
  }

  func testANonFiniteOffsetIsIgnored() {
    let proxy = proxy()
    proxy.setOffset(40)
    proxy.setOffset(.nan)
    proxy.setOffset(.infinity)
    XCTAssertEqual(proxy.offset, 40)
  }

  /// Spike §2: the lock also drops UIKit's inset adjustment, so an inset
  /// change re-applies Dart's offset.
  func testAnInsetChangeKeepsDartsOffset() {
    let proxy = proxy()
    proxy.setOffset(50)
    proxy.contentInset.top = 30
    XCTAssertEqual(proxy.contentOffset.y, -proxy.adjustedContentInset.top + 50)
  }

  /// Spec §8.4, Q8: never the status-bar target, invisible to VoiceOver,
  /// direct touches only.
  func testItLeavesTheStatusBarAccessibilityAndTrackpadAlone() {
    let proxy = proxy()
    XCTAssertFalse(proxy.scrollsToTop)
    XCTAssertFalse(proxy.isUserInteractionEnabled)
    XCTAssertFalse(proxy.isAccessibilityElement)
    XCTAssertTrue(proxy.accessibilityElementsHidden)
    XCTAssertEqual(proxy.panGestureRecognizer.allowedScrollTypesMask, [])
    XCTAssertGreaterThan(proxy.contentSize.height, 10_000)
  }

  /// Q7: a pan that starts over a platform view (a subview of the Flutter
  /// view) does not begin.
  func testThePanBeginsOnlyOverTheContentItself() {
    let content = UIView()
    let platformView = UIView()
    content.addSubview(platformView)
    XCTAssertTrue(MinimizeProxy.begins(over: content, content: content))
    XCTAssertFalse(MinimizeProxy.begins(over: platformView, content: content))
    XCTAssertTrue(MinimizeProxy.begins(over: platformView, content: nil))
  }
}
```

- [ ] **Step 2: Run the tests to verify that they fail.**

```bash
U=$(xcrun simctl create "vk600 iPhone 26.5" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5)
make ios-unit IOS_UNIT_DEVICE=$U
```

Expected: the build FAILS with "cannot find 'MinimizeProxy' in scope".

- [ ] **Step 3: Implement**

```swift
// MinimizeProxy.swift
import UIKit

/// The invisible scroll view UIKit's tab bar minimize follows (spec
/// VK-600 §8.1). Locked: only `setOffset` moves it, so the bar follows the
/// Flutter content, never a drag that moves nothing. Its own pan, attached
/// to the Flutter view, makes it "user-tracked" (spike C8); its own
/// deceleration is left running, which the expand at the top needs (C11).
@available(iOS 26.0, *)
final class MinimizeProxy: UIScrollView {
  /// Dart's last offset: points below the top, zero or negative at it.
  private(set) var offset: Double = 0
  /// The Flutter view: a pan that starts over one of its subviews (a
  /// platform view) does not begin.
  weak var contentView: UIView?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    scrollsToTop = false
    contentInsetAdjustmentBehavior = .always
    contentSize = CGSize(width: 1, height: 100_000)
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    panGestureRecognizer.allowedScrollTypesMask = []
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// UIKit's writes are dropped; `apply` writes through `super`.
  override var contentOffset: CGPoint {
    get { super.contentOffset }
    set {}
  }

  func setOffset(_ value: Double) {
    guard value.isFinite else { return }
    offset = value
    apply()
  }

  private func apply() {
    super.contentOffset = CGPoint(x: 0, y: -adjustedContentInset.top + CGFloat(offset))
  }

  override func adjustedContentInsetDidChange() {
    super.adjustedContentInsetDidChange()
    apply()
  }

  /// Whether the pan may begin over [hit], the content's hit view.
  static func begins(over hit: UIView?, content: UIView?) -> Bool {
    guard let content, let hit else { return true }
    return hit === content
  }

  override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
    if recognizer === panGestureRecognizer, let content = contentView {
      let hit = content.hitTest(recognizer.location(in: content), with: nil)
      if !Self.begins(over: hit, content: content) { return false }
    }
    return super.gestureRecognizerShouldBegin(recognizer)
  }
}
```

- [ ] **Step 4: Run the tests to verify that they pass.**

Run: `make ios-unit IOS_UNIT_DEVICE=$U`. Expected: `MinimizeProxyTests` PASS (5 tests), and every existing test still passes.

  If `testOnlySetOffsetMovesIt` fails on `setContentOffset(_:animated: false)`, UIKit wrote around the setter. Add `override func setContentOffset(_ offset: CGPoint, animated: Bool) {}` and run again. Never weaken the assertion.

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/MinimizeProxy.swift liquid_shell/example/ios/RunnerTests/RunnerTests.swift && git commit -m "feat(ios): a locked proxy scroll view for the tab bar minimize (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The channel, the behaviour, the hosts and the offsets

**Files:**
- Modify: `liquid_shell_ios/pigeons/native_shell.dart`, then run `make pigeon`, which rewrites `liquid_shell_ios/lib/src/native_shell_api.g.dart` and `…/NativeShellApi.g.swift`
- Modify: `liquid_shell_ios/lib/src/mapping.dart`, `liquid_shell_ios/lib/src/platform.dart`
- Modify: `…/NativeTabsController.swift` (and its `TabHostController`), `…/NativeShellInstaller.swift`
- Test: `liquid_shell_ios/test/liquid_shell_ios_test.dart`, `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Pigeon:
  - `NativeChromeConfig.minimizeOnScroll` (bool, declared last);
  - `NativeDebugSnapshot.minimizeBehavior` (String) and `.minimizePanAttached` (bool), declared last;
  - `NativeShellHostApi.setMinimizeScroll(int tab, double offset)` and `expandTabBar()`, after VK-550's methods.
- Dart: `LiquidShellIOS.setNativeMinimizeScroll` drops a non-finite offset or a negative tab; `expandNativeTabBar` forwards.
- Swift (`NativeTabsController`):
  - `func setMinimizeScroll(tab: Int, offset: Double)`;
  - `func expandMinimizedBar()`;
  - `func minimizeHost(_ index: Int) -> TabHostController?`;
  - `private(set) var minimizeExpands: Int` (a test seam: the number of toggles).
- Swift (`TabHostController`): `let minimizeProxy = MinimizeProxy()`.

- [ ] **Step 1: Write the failing Dart test**

```dart
// liquid_shell_ios/test/liquid_shell_ios_test.dart
// In _FakeHost, add:
  @override
  Future<void> setMinimizeScroll(int tab, double offset) async {
    calls.add('setMinimizeScroll($tab, $offset)');
  }

  @override
  Future<void> expandTabBar() async {
    calls.add('expandTabBar');
  }

// New tests:
test('minimize scroll and expand reach the host (VK-600)', () async {
  final host = _FakeHost();
  final platform = liquidShellIOSWithHost(host);
  await platform.setNativeMinimizeScroll(tab: 1, offset: 240.5);
  await platform.setNativeMinimizeScroll(tab: 0, offset: double.nan);
  await platform.setNativeMinimizeScroll(tab: -1, offset: 10);
  await platform.expandNativeTabBar();
  expect(host.calls, ['setMinimizeScroll(1, 240.5)', 'expandTabBar']);
});

test('the config carries minimizeOnScroll (VK-600)', () async {
  final host = _FakeHost();
  final platform = liquidShellIOSWithHost(host);
  await platform.updateNativeChrome(
    const LiquidNativeChromeConfig(engaged: true, minimizeOnScroll: true),
  );
  expect(host.lastConfig!.minimizeOnScroll, isTrue);
});
```

Check how `_FakeHost` records `update`. If it has no `lastConfig`, add `NativeChromeConfig? lastConfig;` and set it in `update`. Also add `minimizeBehavior: 'onScrollDown', minimizePanAttached: true` to its `NativeDebugSnapshot`.

- [ ] **Step 2: Run the Dart test to verify that it fails.**

Run: `cd liquid_shell_ios && fvm flutter test`. Expected: FAIL. The compilation error is "'setMinimizeScroll' isn't a member of NativeShellHostApi" (`@override` on nothing).

- [ ] **Step 3: Pigeon and the Dart side**

```dart
// pigeons/native_shell.dart
// class NativeChromeConfig: constructor `required this.minimizeOnScroll,`; field, declared last:
  /// The compact tab bar minimizes while the body scrolls down (VK-600).
  bool minimizeOnScroll;
// class NativeDebugSnapshot: constructor `required this.minimizeBehavior, required this.minimizePanAttached,`; fields, declared last:
  /// `tabBarMinimizeBehavior`: "automatic", "never", "onScrollDown" or "onScrollUp".
  String minimizeBehavior;
  /// Whether a tab's minimize proxy pan is on the Flutter view.
  bool minimizePanAttached;
// NativeShellHostApi, after VK-550's methods:
  /// The body scroll offset of destination [tab] for the tab bar's
  /// minimize (proxy scroll view, spec VK-600 §8).
  void setMinimizeScroll(int tab, double offset);

  /// Expands a minimized tab bar (spec VK-600 §8.5).
  void expandTabBar();
```

```bash
make pigeon
```

`mapping.dart` (`configToNative`): add `minimizeOnScroll: config.minimizeOnScroll,`.

`platform.dart`:

```dart
  @override
  Future<void> setNativeMinimizeScroll({
    required int tab,
    required double offset,
  }) async {
    // Checked at the boundary: nothing non-finite or negative crosses.
    if (!offset.isFinite || tab < 0) return;
    await _send('setMinimizeScroll', () => _host.setMinimizeScroll(tab, offset));
  }

  @override
  Future<void> expandNativeTabBar() => _send('expandTabBar', _host.expandTabBar);
```

Run: `cd liquid_shell_ios && fvm flutter test`. Expected: PASS.

- [ ] **Step 4: Write the failing XCTests**

First update every `NativeChromeConfig(` in `RunnerTests.swift` (five at `c531be0`, plus any VK-550 added). Give the `config(...)` helper a `minimize: Bool = false` parameter and pass `minimizeOnScroll: minimize`. The other literal configs pass `minimizeOnScroll: false`. Then add to `NativeTabsTests`:

```swift
  /// Spec VK-600 §8.5: the shell's minimizeOnScroll picks the behaviour.
  func testTheConfigSetsTheMinimizeBehaviour() throws {
    let tabs = try installedShell()
    tabs.apply(config(minimize: true))
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .onScrollDown)
    tabs.apply(config(minimize: false))
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .never)
  }

  /// §8.2, §8.6: each destination's host has a proxy for the bottom edge,
  /// and Dart's offset reaches that tab's proxy only.
  func testAMinimizeOffsetReachesItsTabsProxy() throws {
    let tabs = try installedShell()
    let home = try XCTUnwrap(tabs.minimizeHost(0))
    let inbox = try XCTUnwrap(tabs.minimizeHost(1))
    home.loadViewIfNeeded()
    XCTAssertTrue(home.contentScrollView(for: .bottom) === home.minimizeProxy)
    tabs.setMinimizeScroll(tab: 1, offset: 240)
    tabs.setMinimizeScroll(tab: 0, offset: .nan)
    tabs.setMinimizeScroll(tab: 9, offset: 50)
    XCTAssertEqual(inbox.minimizeProxy.offset, 240)
    XCTAssertEqual(home.minimizeProxy.offset, 0)
  }

  /// §8.5, spike §3.2: the toggle is the public "expand now"; it does
  /// nothing while minimize is off.
  func testExpandTogglesOnlyWhileMinimizeIsOn() throws {
    let tabs = try installedShell()
    tabs.apply(config(minimize: true))
    tabs.expandMinimizedBar()
    XCTAssertEqual(tabs.minimizeExpands, 1)
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .onScrollDown)
    tabs.apply(config(minimize: false))
    tabs.expandMinimizedBar()
    XCTAssertEqual(tabs.minimizeExpands, 1)
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .never)
  }

  /// The channel: the installer forwards both calls to the shell.
  func testTheInstallerForwardsMinimizeCalls() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    var minimizing = config(minimize: true)
    minimizing.selectedIndex = 0
    try installer.update(config: minimizing)
    settle()
    let shell = try tabs(in: window)
    try installer.setMinimizeScroll(tab: 0, offset: 77)
    try installer.expandTabBar()
    XCTAssertEqual(shell.minimizeHost(0)?.minimizeProxy.offset, 77)
    XCTAssertEqual(shell.minimizeExpands, 1)
  }
```

If `installedByInstaller()` / `tabs(in:)` are private to another test case after the rebase, move this test there.

- [ ] **Step 5: Run the XCTests to verify that they fail.** Run: `make ios-unit IOS_UNIT_DEVICE=$U`. Expected: the build FAILS. `NativeShellInstaller` does not conform to `NativeShellHostApi` (missing `setMinimizeScroll`, `expandTabBar`), and `minimizeHost` / `minimizeExpands` are missing.

- [ ] **Step 6: Implement (Swift)**

`TabHostController`:

```swift
  /// The proxy UIKit's tab bar minimize follows (spec VK-600 §8.2).
  let minimizeProxy = MinimizeProxy()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    minimizeProxy.frame = view.bounds
    minimizeProxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(minimizeProxy)
    setContentScrollView(minimizeProxy, for: .bottom)
  }
```

`NativeTabsController`:

- `private var minimizeHosts: [Int: TabHostController] = [:]`. In `rebuildTabsIfNeeded`, clear it, then for each non-search destination create the host eagerly:

  ```swift
  let host = TabHostController()
  minimizeHosts[index] = host
  let tab = UITab(title: "", image: nil, identifier: "destination\(index)") { _ in host }
  ```

  The provider runs once per tab, and a new structure builds new tabs and hosts as before.
- In `apply`, after `setFooter(new.footer)`:

  ```swift
  let behavior: UITabBarController.MinimizeBehavior = new.minimizeOnScroll ? .onScrollDown : .never
  if tabBarMinimizeBehavior != behavior { tabBarMinimizeBehavior = behavior }
  ```

- New:

  ```swift
  // MARK: - Minimize on scroll (spec VK-600 §8)

  /// Number of expand toggles (tests).
  private(set) var minimizeExpands = 0

  func minimizeHost(_ index: Int) -> TabHostController? { minimizeHosts[index] }

  /// Dart's body offset for destination [tab] (spec §8.6).
  func setMinimizeScroll(tab: Int, offset: Double) {
    guard offset.isFinite, let host = minimizeHosts[tab] else { return }
    host.minimizeProxy.setOffset(offset)
  }

  /// Expands a minimized bar: `.never` then `.onScrollDown` (spike §3.2;
  /// nothing changes on an expanded bar). Only while minimize is on.
  func expandMinimizedBar() {
    guard tabBarMinimizeBehavior == .onScrollDown else { return }
    minimizeExpands += 1
    tabBarMinimizeBehavior = .never
    tabBarMinimizeBehavior = .onScrollDown
  }
  ```

- In `debugSnapshot()`, set `minimizeBehavior` from `tabBarMinimizeBehavior` (`.automatic` → "automatic", and so on) and `minimizePanAttached: false`. Task 5 makes that real. In `NativeDebugSnapshot.empty`, use `minimizeBehavior: ""` and `minimizePanAttached: false`.

`NativeShellInstaller`:

```swift
  func setMinimizeScroll(tab: Int64, offset: Double) throws {
    if #available(iOS 26.0, *) { tabs?.setMinimizeScroll(tab: Int(tab), offset: offset) }
  }

  func expandTabBar() throws {
    if #available(iOS 26.0, *) { tabs?.expandMinimizedBar() }
  }
```

- [ ] **Step 7: Run all the tests.** Run: `make ios-unit IOS_UNIT_DEVICE=$U && cd liquid_shell_ios && fvm flutter test && cd .. && make pigeon-check`. Expected: PASS, and "✓ pigeon output matches its source" once committed.

- [ ] **Step 8: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell_ios/pigeons/native_shell.dart liquid_shell_ios/lib/src/native_shell_api.g.dart liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift liquid_shell_ios/lib/src/mapping.dart liquid_shell_ios/lib/src/platform.dart liquid_shell_ios/test/liquid_shell_ios_test.dart liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellInstaller.swift liquid_shell/example/ios/RunnerTests/RunnerTests.swift && git commit -m "feat(ios): minimize behaviour, per-tab proxies and the minimize channel (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Pan attachment, expand on selection, `scrollsToTop`

**Files:**
- Modify: `…/NativeTabsController.swift`, `…/ShellNavController.swift`
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Produces:
  - `NativeTabsController.updateMinimizePan()`;
  - `private(set) weak var attachedMinimizeProxy: MinimizeProxy?`;
  - `debugSnapshot().minimizePanAttached`.
- Consumes: Task 3's `MinimizeProxy.contentView` and Task 4's hosts.

- [ ] **Step 1: Write the failing XCTests** (in `NativeTabsTests`)

```swift
  private func panIsOnFlutter(_ tabs: NativeTabsController, host index: Int) -> Bool {
    guard let pan = tabs.minimizeHost(index)?.minimizeProxy.panGestureRecognizer else { return false }
    return tabs.flutter.view.gestureRecognizers?.contains(pan) ?? false
  }

  /// Spec VK-600 §8.3: compact, shown, interactive, minimize on, a
  /// non-search tab → the selected tab's pan is on the Flutter view and
  /// never cancels or delays a touch.
  func testTheSelectedTabsPanSitsOnTheFlutterViewInCompact() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0))
    let pan = try XCTUnwrap(tabs.minimizeHost(0)?.minimizeProxy.panGestureRecognizer)
    XCTAssertFalse(pan.cancelsTouchesInView)
    XCTAssertFalse(pan.delaysTouchesBegan)
    XCTAssertFalse(pan.delaysTouchesEnded)
    XCTAssertTrue(tabs.minimizeHost(0)?.minimizeProxy.contentView === tabs.flutter.view)
    XCTAssertTrue(tabs.debugSnapshot().minimizePanAttached)
  }

  /// An iPhone is always compact (`isCompact`), so regular needs an iPad.
  func testNoPanAtRegularWidthAndTheProxiesGoBackToTheTop() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "regular needs an iPad")
    let tabs = try installedShell(sizeClass: .regular)
    tabs.apply(config(minimize: true))
    tabs.setMinimizeScroll(tab: 0, offset: 300)
    tabs.apply(config(minimize: true, selected: 1))
    settle()
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 1))
    XCTAssertEqual(tabs.minimizeHost(0)?.minimizeProxy.offset, 0)
  }

  func testNoPanWhenMinimizeIsOffHiddenOrInert() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: false))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    tabs.apply(config(hidden: true, minimize: true))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    tabs.apply(config(interactive: false, minimize: true))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    tabs.apply(config(minimize: true))
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0))
  }

  /// The pan follows the selection; the old one goes back to its proxy.
  func testThePanFollowsTheSelection() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    tabs.apply(config(minimize: true, selected: 1))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 1))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    let home = try XCTUnwrap(tabs.minimizeHost(0)?.minimizeProxy)
    XCTAssertTrue(home.gestureRecognizers?.contains(home.panGestureRecognizer) ?? false)
  }

  /// Q4: a selection change expands; re-applying the same one does not.
  func testASelectionChangeExpandsTheBar() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    let before = tabs.minimizeExpands
    tabs.apply(config(minimize: true))
    XCTAssertEqual(tabs.minimizeExpands, before)
    tabs.apply(config(minimize: true, selected: 1))
    XCTAssertEqual(tabs.minimizeExpands, before + 1)
  }

  /// Q10: no proxy competes with Flutter for the status-bar tap.
  func testThePageProxyLeavesTheStatusBarTapToFlutter() {
    let page = PageHostController()
    page.loadViewIfNeeded()
    XCTAssertFalse(page.proxy.scrollsToTop)
    XCTAssertTrue(page.proxy.accessibilityElementsHidden)
  }
```

Also a search-tab case, using the existing search fixture (`searchConfig(selected:)`): with the search destination selected, no pan is on the Flutter view. Give `searchConfig` a `minimize:` parameter as for `config`.

- [ ] **Step 2: Run them to verify that they fail.** Run: `make ios-unit IOS_UNIT_DEVICE=$U`. Expected: FAIL. There is no pan on the Flutter view, `minimizeExpands` does not move on select, and `page.proxy.scrollsToTop` is true.

- [ ] **Step 3: Implement**

```swift
  /// The proxy whose pan is on the Flutter view, if any (spec §8.3).
  private(set) weak var attachedMinimizeProxy: MinimizeProxy?

  /// Puts the selected tab's proxy pan on the Flutter view when the native
  /// bar may minimize, and takes it back otherwise. Leaving compact resets
  /// every proxy, so the top bar's edge effect never sees an old offset.
  func updateMinimizePan() {
    var want: MinimizeProxy?
    if let config, chromeVisible, config.interactive, config.minimizeOnScroll, isCompact,
      let host = selectedViewController as? TabHostController, let content = flutter.viewIfLoaded
    {
      host.minimizeProxy.contentView = content
      want = host.minimizeProxy
    }
    if !isCompact { for host in minimizeHosts.values { host.minimizeProxy.setOffset(0) } }
    guard want !== attachedMinimizeProxy else { return }
    // A recognizer has one view: adding it elsewhere moves it.
    if let old = attachedMinimizeProxy { old.addGestureRecognizer(old.panGestureRecognizer) }
    attachedMinimizeProxy = want
    guard let proxy = want, let content = flutter.viewIfLoaded else { return }
    let pan = proxy.panGestureRecognizer
    pan.cancelsTouchesInView = false
    pan.delaysTouchesBegan = false
    pan.delaysTouchesEnded = false
    content.addGestureRecognizer(pan)
  }
```

- Call `updateMinimizePan()` at the end of `apply` (after `syncFlutter()`) and in the horizontal-size-class trait handler (after `select`).
- In `select(_:)`, right after `selectedTab = tab` (inside the `applyingFromDart` window), call `expandMinimizedBar()`. The guard above it already returns when the tab is unchanged.
- In `debugSnapshot()`: `minimizePanAttached: attachedMinimizeProxy != nil`.
- In `PageHostController.viewDidLoad` (`ShellNavController.swift`): `proxy.scrollsToTop = false`, `proxy.isAccessibilityElement = false`, `proxy.accessibilityElementsHidden = true`.

- [ ] **Step 4: Run them to verify that they pass.** Run: `make ios-unit IOS_UNIT_DEVICE=$U`. Expected: PASS. Then run on an iPad too, so the compact override and regular tests run on both idioms:

```bash
A=$(xcrun simctl create "vk600 iPad 27" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-0)
make ios-unit IOS_UNIT_DEVICE=$A
```

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift liquid_shell/example/ios/RunnerTests/RunnerTests.swift && git commit -m "feat(ios): the minimize pan on the Flutter view; a selection change expands (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The shell drives the native minimize

**Files:**
- Modify: `liquid_shell/lib/src/native/native_host.dart` (`NativeChromeClaim`)
- Modify: `liquid_shell/lib/src/native/native_layout.dart` (`nativeConfigFor`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart`
- Test: `liquid_shell/test/widget/native_minimize_test.dart` (new), `liquid_shell/test/widget/native_search_test.dart`

**Interfaces:**
- Produces:
  - `NativeChromeClaim.setMinimizeScroll({required int tab, required double offset})`;
  - `NativeChromeClaim.expandTabBar()`;
  - `nativeConfigFor(…, required bool minimizeOnScroll)`.

  The claim methods send only while the claim owns the chrome.
- Consumes: Task 1 (tracker, `nativeMinimizeActive`) and Task 2 (platform calls).

- [ ] **Step 1: Write the failing widget tests**

```dart
// liquid_shell/test/widget/native_minimize_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

Future<FakeNativePlatform> _pump(
  WidgetTester tester, {
  LiquidNativeShellState state = _compact,
  bool minimizeOnScroll = true,
  Size size = kPhone,
}) async {
  final native = installFakeNative(state: state);
  await pumpShell(
    tester,
    TestShell(destinations: kNative, minimizeOnScroll: minimizeOnScroll),
    size: size,
    padding: _compactPadding,
  );
  return native;
}

ScrollPosition _position(WidgetTester tester, String label) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(ValueKey('list-$label')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  group('native minimize (spec VK-600 §9)', () {
    testWidgets('compact: the dragged offset reaches native, once per value', (
      tester,
    ) async {
      final native = await _pump(tester);
      expect(native.last.minimizeOnScroll, isTrue);
      await tester.drag(find.byKey(const ValueKey('list-Home')), const Offset(0, -300));
      await tester.pumpAndSettle();
      final pixels = _position(tester, 'Home').pixels;
      expect(native.minimizeScrolls.last, (0, pixels));
      final sent = native.minimizeScrolls.length;
      await tester.pump(const Duration(seconds: 1));
      expect(native.minimizeScrolls.length, sent, reason: 'deduplicated');
    });

    testWidgets('regular width sends nothing', (tester) async {
      final native = await _pump(
        tester,
        state: kInstalled,
        size: kTabletLandscape,
      );
      await tester.drag(find.byKey(const ValueKey('list-Home')), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls, isEmpty);
    });

    testWidgets('minimizeOnScroll: false sends nothing and says so', (
      tester,
    ) async {
      final native = await _pump(tester, minimizeOnScroll: false);
      await tester.drag(find.byKey(const ValueKey('list-Home')), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls, isEmpty);
      expect(native.last.minimizeOnScroll, isFalse);
    });

    testWidgets('a dialog above the shell stops the sends', (tester) async {
      final native = await _pump(tester);
      final context = tester.element(find.byKey(const ValueKey('list-Home')));
      unawaited(
        showDialog<void>(context: context, builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      final sent = native.minimizeScrolls.length;
      // The body still scrolls (the app's code), but the shell's route is
      // not current: nothing may reach the hidden native bar.
      _position(tester, 'Home').jumpTo(400);
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls.length, sent);
    });

    testWidgets('a selection change sends the new tab its offset', (
      tester,
    ) async {
      final native = await _pump(tester);
      tester.state<TestShellState>(find.byType(TestShell)).select(1);
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls.last.$1, 1);
    });

    testWidgets('animateTo(0) and a fling to the top expand; a drag does not', (
      tester,
    ) async {
      final native = await _pump(tester);
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, 900)); // drag to the top
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 0);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      await _position(tester, 'Home').animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 1);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.fling(list, const Offset(0, 500), 4000);
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 2);
    });
  });
}
```

In `native_search_test.dart`, add to the relevant group:

```dart
testWidgets('no minimize offsets while the search tab is selected (VK-600 Q5)', (
  tester,
) async {
  final (native, _, _) = await _pump(tester); // initialIndex 2: search
  await tester.drag(find.byKey(const ValueKey('list-Search')), const Offset(0, -300));
  await tester.pumpAndSettle();
  expect(native.minimizeScrolls, isEmpty);
});
```

The `select` method and `kTabletLandscape` live in `shell_harness.dart`. If `TestShellState.select` has a different name after the rebase, use the harness's selection method.

- [ ] **Step 2: Run them to verify that they fail.** Run: `cd liquid_shell && fvm flutter test test/widget/native_minimize_test.dart test/widget/native_search_test.dart`. Expected: FAIL. `native.last.minimizeOnScroll` is false, and `minimizeScrolls` and `tabBarExpands` stay empty or zero.

- [ ] **Step 3: Implement**

`NativeChromeClaim`:

```dart
  /// Sends [tab]'s body scroll offset for the native minimize, when this
  /// claim owns the chrome (spec VK-600 §9.2).
  void setMinimizeScroll({required int tab, required double offset}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativeMinimizeScroll(
        tab: tab,
        offset: offset,
      ),
    );
  }

  /// Expands the minimized native bar, when this claim owns the chrome.
  void expandTabBar() {
    if (!isOwner) return;
    unawaited(LiquidShellPlatform.instance.expandNativeTabBar());
  }
```

`nativeConfigFor`: add `required bool minimizeOnScroll` and pass it to `LiquidNativeChromeConfig`. Update the callers in `liquid_shell.dart` and in `test/unit/native_layout_test.dart`.

`_LiquidShellState`:

```dart
  final MinimizeScrollTracker _minimizeScroll = MinimizeScrollTracker();
  bool _minimizeActive = false;
  bool _minimizeSendScheduled = false;
  bool _minimizeForce = false;
  (int, double)? _minimizeSent;
```

- In `_resolveNative`, compute `hidden` before `if (owner)`; its expression is unchanged. Then:

  ```dart
  _setMinimizeActive(
    nativeMinimizeActive(
      owner: owner,
      engaged: engaged,
      compact: state?.compact ?? false,
      minimizeOnScroll: widget.minimizeOnScroll,
      searchSelected: _search.selected,
      hidden: hidden,
      routeCurrent: _routeCurrent,
    ),
  );
  ```

  `_setMinimizeActive(bool active)`: on false → true, set `_minimizeForce` and schedule a send. Store the value.
- Pass `minimizeOnScroll: widget.minimizeOnScroll` into `nativeConfigFor`.
- In `didUpdateWidget`, where `selectedIndex` changes: set `_minimizeForce = true` and schedule a send.
- In `_onBodyScroll`, before the Flutter-bar branch:

  ```dart
  final tab = resolveSelectedIndex(widget.selectedIndex, widget.destinations.length);
  final result = _minimizeScroll.handleNotification(notification, tab: tab);
  if (kind == null && _minimizeActive && result != MinimizeScrollResult.none) {
    _scheduleMinimizeSend();
    if (result == MinimizeScrollResult.expand) _claim?.expandTabBar();
  }
  ```

- `_scheduleMinimizeSend()`: a post-frame callback, like `_scheduleScrollSync`. It sends `(tab, _minimizeScroll.offsetOf(tab))` for the selected tab when `_minimizeActive` and (`_minimizeForce` or the pair differs from `_minimizeSent`). Then it clears `_minimizeForce`.

- [ ] **Step 4: Run them to verify that they pass.** Run: `cd liquid_shell && fvm flutter test`. Expected: PASS, including every existing native and minimize test.

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell/lib/src/native/native_host.dart liquid_shell/lib/src/native/native_layout.dart liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/test/widget/native_minimize_test.dart liquid_shell/test/widget/native_search_test.dart liquid_shell/test/unit/native_layout_test.dart && git commit -m "feat(shell): the body scroll drives the native tab bar minimize (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The Flutter bar expands when a fling or a programmatic scroll reaches the top (Q2, Q3)

**Files:**
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (`_onBodyScroll`, `_onScroll`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (the `minimizeOnScroll` dartdoc, spec §5)
- Test: `liquid_shell/test/widget/shell_behaviour_test.dart`, group "minimise on scroll"

**Interfaces:**
- Consumes: Task 1's `MinimizeScrollResult.expand`.
- Produces: no new API.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a fling that reaches the top expands (VK-600 Q2)', (tester) async {
  await pumpShell(tester, const TestShell());
  final list = find.byKey(const ValueKey('list-Home'));
  await tester.drag(list, const Offset(0, -600));
  await tester.pumpAndSettle();
  expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
  await tester.fling(list, const Offset(0, 500), 4000);
  await tester.pumpAndSettle();
  expect(tester.getSize(find.byKey(kTabPillKey)).height, 62);
});

testWidgets('a drag back to the top keeps it minimized (VK-600, as UIKit)', (
  tester,
) async {
  await pumpShell(tester, const TestShell());
  final list = find.byKey(const ValueKey('list-Home'));
  await tester.drag(list, const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.drag(list, const Offset(0, 900));
  await tester.pumpAndSettle();
  expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
});

testWidgets('a programmatic scroll to the top expands (VK-600 Q3)', (
  tester,
) async {
  await pumpShell(tester, const TestShell());
  final list = find.byKey(const ValueKey('list-Home'));
  await tester.drag(list, const Offset(0, -600));
  await tester.pumpAndSettle();
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      )
      .position;
  await position.animateTo(
    0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
  await tester.pumpAndSettle();
  expect(tester.getSize(find.byKey(kTabPillKey)).height, 62);
});
```

Rename the existing "reverse minimises; forward does not expand; a tap does" test only if it now fails: its forward drag does not fling, so it should still pass.

- [ ] **Step 2: Run them to verify that they fail.** Run: `cd liquid_shell && fvm flutter test test/widget/shell_behaviour_test.dart`. Expected: the fling and the `animateTo` tests FAIL (the bar stays 48 × 48), and the drag test PASSES.

- [ ] **Step 3: Implement.** In `_onBodyScroll`, after the tracker call of Task 6:

```dart
if (kind == LiquidChromeKind.bottomBar &&
    widget.minimizeOnScroll &&
    !_search.selected &&
    result == MinimizeScrollResult.expand) {
  _expand();
}
```

Update the `minimizeOnScroll` dartdoc to the text in spec §5.

- [ ] **Step 4: Run them to verify that they pass.** Run: `cd liquid_shell && fvm flutter test`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/test/widget/shell_behaviour_test.dart && git commit -m "feat(shell): a fling or a programmatic scroll to the top expands the Flutter bar (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Real swipes on the example (XCUITest) and the real channel (integration)

**Files:**
- Create: `liquid_shell/example/ios/RunnerUITests/MinimizeUITests.swift`. Add it to the RunnerUITests target in `Runner.xcodeproj/project.pbxproj`, the same way `TabFidelityUITests.swift` is wired.
- Modify: `liquid_shell/example/integration_test/native_shell_test.dart`
- Modify: `Makefile` (`IOS_UI_TIMEOUT` note) only if the suite's measured time needs it

**Interfaces:**
- Consumes: the example's `tabs` demo (`LIQUID_SHELL_EXAMPLE_DEMO=tabs`, `BasicTabsCase` in native mode, destinations Home / Explore / Settings) and Task 5's `debugSnapshot`.

- [ ] **Step 1: Find the minimized signal.**
  1. Add a temporary test that launches `tabs` and prints `app.tabBars.firstMatch.debugDescription` at rest and after `app.swipeUp()`. Run it on the iPhone 26.5 simulator with `make ios-ui IOS_UNIT_DEVICE=$U`.
  2. Note which signal flips once minimized: the "Explore" tab button stops being hittable, or the "Home" button frame shrinks to about 48 pt wide.
  3. Repeat on an iPhone 27.0 simulator.
  4. Keep the signal that flips on both in `isMinimized` below, delete the temporary test, and write the two dumps into `docs/qa/vk600/acceptance.md`.

- [ ] **Step 2: Write the failing XCUITests**

```swift
// MinimizeUITests.swift
import XCTest

/// Spec VK-600 §12.5: real swipes on Flutter content minimize the native
/// tab bar; UIKit's rules bring it back.
final class MinimizeUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() { continueAfterFailure = false }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "tabs"
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: timeout))
    return app
  }

  /// The signal Step 1 recorded (keep the one that flips on 26.5 and 27).
  private func isMinimized(_ app: XCUIApplication) -> Bool {
    let explore = app.tabBars.buttons["Explore"]
    if !explore.exists || !explore.isHittable { return true }
    return app.tabBars.buttons["Home"].frame.width < 60
  }

  private func waitMinimized(_ app: XCUIApplication, _ want: Bool, _ why: String) {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline, isMinimized(app) != want { usleep(100_000) }
    XCTAssertEqual(isMinimized(app), want, why)
  }

  /// A drag on the list over [seconds]: [dy] < 0 scrolls the content down.
  /// The hold at the end stops a fling, so a slow reverse stays mid-content.
  private func drag(_ app: XCUIApplication, dy: CGFloat, seconds: CGFloat = 0.3) {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dy < 0 ? 0.7 : 0.3))
    start.press(
      forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)),
      withVelocity: XCUIGestureVelocity(abs(dy) / seconds), thenHoldForDuration: 0.2)
  }

  func testAScrollMinimizesAndAFlingToTheTopExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch()
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes")
    drag(app, dy: 100, seconds: 1.0)
    waitMinimized(app, true, "a slow reverse drag in mid-content keeps it")
    app.swipeDown(velocity: .fast)
    app.swipeDown(velocity: .fast)
    waitMinimized(app, false, "a fling that reaches the top expands")
  }

  func testATapOnTheCircleExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch()
    drag(app, dy: -300)
    waitMinimized(app, true, "minimized")
    app.tabBars.buttons["Home"].tap()
    waitMinimized(app, false, "the circle expands")
  }

  func testTheRegularTopBarNeverMinimizes() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad")
    let app = launch()
    drag(app, dy: -300)
    sleep(2)
    XCTAssertTrue(app.tabBars.buttons["Explore"].isHittable)
  }
}
```

- [ ] **Step 3: Run them to verify.** Run: `make ios-ui IOS_UNIT_DEVICE=$U`.

  Expected:
  - before Tasks 3–6 are in the build (check this once on `main` at the rebase base, if time allows), `testAScrollMinimizesAndAFlingToTheTopExpands` FAILS on "a swipe up minimizes";
  - with them, all three PASS on the iPhone 26.5;
  - then all three PASS on an iPhone 27.0 and on the iPad 27 (`$A`), where the iPhone tests skip.

- [ ] **Step 4: Integration through the real channel.** Add to `native_shell_test.dart`:

```dart
testWidgets('minimize on scroll is set; its pan only in compact (VK-600)', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(debugShowCheckedModeBanner: false, home: BasicTabsCase()),
  );
  await _settle(tester);
  if (!_expectNative) return;
  final platform = LiquidShellPlatform.instance as LiquidShellIOS;
  final shot = await platform.debugSnapshot();
  final compact = _scope(tester).sizeClass == LiquidSizeClass.compact;
  debugPrint('liquid_shell native: minimize ${shot.minimizeBehavior} '
      'pan ${shot.minimizePanAttached} compact $compact');
  expect(shot.minimizeBehavior, 'onScrollDown');
  expect(shot.minimizePanAttached, compact);
});
```

Run: `make integration-ios-native`. Expected: PASS on the iPad and iPhone simulators it creates.

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell/example/ios/RunnerUITests/MinimizeUITests.swift liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj liquid_shell/example/integration_test/native_shell_test.dart docs/qa/vk600/acceptance.md && git commit -m "test(example): real swipes minimize the native tab bar; the channel reports it (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Docs, CHANGELOGs, version

**Files:**
- Modify: `liquid_shell/doc/native_chrome.md`, `liquid_shell/doc/tab_bar.md`
- Modify: `liquid_shell/CHANGELOG.md`, `liquid_shell_platform_interface/CHANGELOG.md`, `liquid_shell_ios/CHANGELOG.md`, `liquid_shell_android/CHANGELOG.md`
- Modify: the four `pubspec.yaml` files (version, plus the inter-package constraints), and `liquid_shell_ios/ios/liquid_shell_ios.podspec` (version)

- [ ] **Step 1: Docs**
  - `native_chrome.md`:
    - in "How it behaves → Compact", replace "`minimizeOnScroll` applies to the Flutter bar only." with "The compact bar minimizes on scroll (see *Minimize on scroll*).";
    - add a section "Minimize on scroll" after "How it behaves" with:
      - the rules table of spec §4;
      - how it works, in two sentences: a hidden scroll view per tab follows your body's scrolling, and UIKit animates the bar;
      - the limits: not at regular width, not in the search tab, not from platform views, trackpads or VoiceOver scrolling;
      - "`minimizeOnScroll: false` turns it off";
    - add a troubleshooting line: "**The native bar never minimizes**: `minimizeOnScroll` is false, the width is regular, or the search tab is selected."
  - `tab_bar.md`: the Flutter bar now also expands when a fling or a programmatic scroll reaches the top; a drag back never does.
- [ ] **Step 2: Versions.** Set `0.1.0-dev.8` everywhere `0.1.0-dev.7` appears for the four packages: versions and the `^0.1.0-dev.x` constraints between them. Check with `make get` and `make test`. The `sdk_floor_test` and `public_api_test` must stay green.
- [ ] **Step 3: CHANGELOGs.** Under `## 0.1.0-dev.8`:
  - `liquid_shell`:
    - **Behaviour change:** with native chrome on iOS 26+, `minimizeOnScroll` (default `true`) now also minimizes UIKit's compact tab bar; set it to `false` to keep the old behaviour;
    - both bars expand when a fling or a programmatic scroll reaches the top.
  - Platform interface: `LiquidNativeChromeConfig.minimizeOnScroll`, `setNativeMinimizeScroll`, `expandNativeTabBar`.
  - iOS: the minimize proxy, the pan on the Flutter view, the expand toggle, `scrollsToTop = false` on the page proxy.
  - Android: version only.
- [ ] **Step 4: Verify.** Run: `make verify`. Expected: "✓ verify passed". Paste the tail into the PR body later.
- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && git add liquid_shell/doc/native_chrome.md liquid_shell/doc/tab_bar.md liquid_shell/CHANGELOG.md liquid_shell_platform_interface/CHANGELOG.md liquid_shell_ios/CHANGELOG.md liquid_shell_android/CHANGELOG.md liquid_shell/pubspec.yaml liquid_shell_platform_interface/pubspec.yaml liquid_shell_ios/pubspec.yaml liquid_shell_android/pubspec.yaml liquid_shell_ios/ios/liquid_shell_ios.podspec && git commit -m "docs(docs): native minimize on scroll, CHANGELOGs and version 0.1.0-dev.8 (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Verification, the manual check and evidence

**Files:**
- Create: `docs/qa/vk600/manual.md`
- Modify: `docs/qa/vk600/acceptance.md`

- [ ] **Step 1: Every suite.** Paste each output into `acceptance.md`.

```bash
make verify
make ios-unit IOS_UNIT_DEVICE=$U      # iPhone 17 Pro, iOS 26.5
make ios-unit IOS_UNIT_DEVICE=$A      # iPad Pro 11, iOS 27.0
make ios-ui IOS_UNIT_DEVICE=$U
make ios-ui IOS_UNIT_DEVICE=$A
make integration-ios-native
```

Also run `make ios-ui` on an iPhone 17 Pro with iOS 27.0, a simulator of your own.

- [ ] **Step 2: Before/after screenshots (Q12).** On the iPhone 26.5 simulator, take a screenshot of the `tabs` demo at rest and scrolled 300 pt with minimize off, then with it on. Use `minimizeOnScroll: false` through a scratch run, or `main` at the rebase base. Compare the band under the bar, which shows UIKit's bottom scroll-edge effect. If it differs visibly, stop and ask the owner (a new Q).
- [ ] **Step 3: The manual checklist** (`manual.md`, for the owner on devices). Each item is a checkbox with the expected result from spec §4 and §10:
  - the iPhone feel against Apple Music (iOS 26 and iOS 27): minimize, a slow reverse, a fling to the top, a tap on the circle, a tab change while minimized;
  - the search tab does not minimize;
  - a status-bar tap scrolls Flutter to the top and expands the bar;
  - a web view or a map in the body scrolls normally and does not minimize;
  - VoiceOver: the circle reads and expands, and a three-finger scroll to the top expands;
  - Reduce Motion;
  - iPhone landscape;
  - an iPad in a narrow window (minimizes) and in full screen (does not);
  - Stage Manager resize while minimized.
- [ ] **Step 4: Clean up.** Delete your simulators (`xcrun simctl delete <udid>` for each one you created). Remove `liquid_shell/example/build`. Run `df -h /`.
- [ ] **Step 5: Commit, then review.**

```bash
bash .githooks/pre-commit && git add docs/qa/vk600/manual.md docs/qa/vk600/acceptance.md && git commit -m "docs(docs): VK-600 acceptance evidence and device checklist (VK-600)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then run `superpowers:requesting-code-review`, `superpowers:verification-before-completion` and `superpowers:finishing-a-development-branch`. The PR body links Plane VK-600 and pastes the `make verify` tail. No push without the owner's go-ahead.
