# liquid_shell VK-600: the native tab bar minimizes on scroll

- **Plane:** VK-600
- **Date:** 2026-10-14
- **Status:** draft for the owner. The owner approves this spec and the plan `docs/plans/2026-10-14-native-tab-minimize.md` together. Open choices are in the last section, "Quyết định cần chủ sản phẩm xác nhận". Every row has a recommended default; if the owner says nothing, the default applies.
- **Branch:** `VK-600-native-tab-minimize`, from `main` at `c531be0`. It holds docs only until VK-550 (`VK-550-liquid-segmented-control`) merges. VK-550 also edits `NativeTabsController.swift` (the search scope bar), the Pigeon source and `liquid_shell.dart`. The branch is rebased onto that merge before any code is written (§13).
- **Floor:** Flutter ≥ 3.44.0 / Dart ^3.12.0 (fvm pins 3.44.6), iOS deployment target 15.0. The native chrome stays iOS 26+. `very_good_analysis` 10.3.0, `pigeon` 27.3.0. There are no new runtime dependencies.
- **Owner input (binding),** verbatim:

  > Thanh tab native tự thu nhỏ khi cuộn: thêm tính năng (làm thành việc riêng)

- **Sources:**
  - The spike `docs/qa/vk600/spike.md`, cited as "spike §n". Every number here comes from it. It was run on own simulators: iPhone 17 Pro and iPad Pro 11" (M5), on iOS 26.5 and 27.0.
  - The P2 spec `docs/specs/2026-10-09-p2-native-ios-design.md`: §5 (approach C, hit testing, the frame and safe-area copy) and §14.3 (the first minimize probe, which failed).
  - The P3b spec `docs/specs/2026-10-10-p3b-search-tab-design.md`: §7.7 (the page proxy scroll view) and §9.2 (minimize is suspended while search is selected).
  - The VK-503 spec `docs/specs/2026-10-11-tab-fidelity-design.md`: §10 and its Q7 (the Flutter bar does not expand on a scroll back).
  - The code at `c531be0`: `NativeTabsController.swift`, `ShellNavController.swift`, `NativeShellInstaller.swift`, `pigeons/native_shell.dart`, `lib/src/shell/liquid_shell.dart`, `lib/src/native/*`.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Kết quả thử nghiệm:** làm được, và chỉ dùng API công khai. UIKit chỉ thu nhỏ thanh tab khi chính người dùng kéo một `UIScrollView`. Trước đây P2 đã thử dịch một scroll view ẩn bằng code, và thanh tab không thu nhỏ. Cách làm được là gắn **bộ nhận cử chỉ kéo (pan) của scroll view ẩn đó lên view Flutter**. Ngón tay thật vẫn đi vào Flutter như cũ, đồng thời UIKit thấy "người dùng đang kéo". Độ dời của scroll view ẩn vẫn do Dart quyết định theo đúng nội dung Flutter, nên những cú kéo không làm nội dung cuộn sẽ không làm thanh tab thu nhỏ.
> - **Hiệu ứng:** dùng hoạt ảnh của chính UIKit, không phải vẽ lại. Thời gian thu nhỏ và nở ra đo được giống hệt scroll view thật, trên cả iOS 26.5 lẫn 27, sai lệch dưới 1 khung hình.
> - **Luật của native (đã đo):** thanh tab thu nhỏ sau khoảng 20–40pt kéo xuống. Kéo ngược giữa trang thì thanh **không** nở. Thanh **nở ra khi cú vuốt đưa nội dung về tới đầu trang**, hoặc khi chạm vào hình tròn. iPad màn rộng (thanh tab trên cùng) thì **không bao giờ** thu nhỏ; iPad cửa sổ hẹp thì có, giống iPhone.
> - **Tab Tìm:** thanh không thu nhỏ khi đang ở tab Tìm, giống thanh Flutter hiện nay.
> - **Những chỗ phải tự bổ sung:** UIKit không tự nở thanh khi Flutter cuộn về đầu bằng code (chạm thanh trạng thái, `animateTo(0)`), cũng không tự nở khi app đổi tab bằng code. Cả hai trường hợp đều dùng một cách công khai đã thử được: đổi `tabBarMinimizeBehavior` sang `.never` rồi đặt lại.
> - **Cờ bật/tắt:** dùng lại `minimizeOnScroll` (mặc định bật) cho cả native.
> - **Rủi ro chính:** cách UIKit nhận biết thao tác cuộn không có trong tài liệu, nên iOS mới có thể đổi. Đã có XCUITest vuốt thật để phát hiện sớm. Muốn tắt thì đặt `minimizeOnScroll: false`.
> - 12 câu hỏi kèm đề xuất mặc định ở bảng cuối.

---

## 1. Goal

On iOS 26+, with native chrome engaged at compact width (every iPhone and a narrow iPad window), the native floating tab bar minimizes while the user scrolls the shell's Flutter body down. The look is Apple Music's: the 48 pt circle of the selected tab, the ⌕ shrunk to 48 pt. It comes back as UIKit's own bar does. The animation is UIKit's, so it is the native one by construction.

## 2. Scope

### 2.1 In

- The native compact bar follows `LiquidShell.minimizeOnScroll` (default `true`).
- A locked proxy scroll view per non-search tab host. Its pan recognizer sits on the Flutter view while that tab is selected.
- A Dart scroll tracker that turns the body's vertical scrolling into one offset per tab, sent once per frame.
- Expand on a programmatic scroll to the top (Q3) and on a selection change (Q4).
- The Flutter bar adopts UIKit's measured "a fling back to the top expands" rule (Q2).
- `scrollsToTop = false` on every proxy, the search page's existing one included (Q10).
- Tests at every layer, including an XCUITest that swipes the example for real.
- Docs, CHANGELOGs and the version (Q11).

### 2.2 Non-goals

- The regular-width top bar and the sidebar. UIKit never minimizes the top bar (spike §3.3). iOS 27's `UINavigationItem.navigationBarMinimization` concerns navigation bars, and liquid_shell's regular top bar is not integrated with one.
- `bottomAccessory` (a mini player). It is out of P3b's scope too. Its measured behaviour is noted for later in §10 (Q9).
- Minimize while the search tab is selected (Q5).
- Reading the minimized state back in Dart. No public API exposes it (spike §1.2), and nothing in the shell needs it: the Flutter body's insets do not change (§8.6).
- Trackpad, mouse and VoiceOver scrolling as triggers (Q8). They scroll Flutter but do not minimize the native bar.

## 3. What the spike found

Details are in `docs/qa/vk600/spike.md`.

1. **No public setter or getter** for the minimized state exists in the iOS 26.5 or the iOS 27.0 SDK. The state lives in private `UITabBar` methods, which are off-limits.
2. **A proxy moved by code never minimizes** (spike §2 C1–C5). This holds even when it claims `isTracking`, `isDragging` or `isDecelerating`, and even when its `panGestureRecognizer` getter returns a pan whose state the app sets. UIKit reads the scroll view's own drag.
3. **The proxy's own pan on the Flutter view works** (C6–C14). Touches keep going to Flutter unchanged, and UIKit sees a user-tracked scroll. With the proxy locked, so that only Dart's writes move it (C8), the bar follows the content's real movement. It ignores drags that move nothing.
4. **UIKit's rules**, the same on 26.5 and 27.0 (spike §3):

   | Situation | Native bar |
   |---|---|
   | ~20–40 pt of drag down | minimizes |
   | Collapse | ≈ 0.80 s to settle |
   | Reverse drag or flick in mid-content | stays minimized |
   | A fling (deceleration) carries the content to its top edge | expands (≈ 0.73 s) |
   | A drag into the top edge | stays minimized |
   | Tap on the circle | expands |
   | Programmatic scroll to the top | stays minimized |
   | Programmatic tab change | stays minimized |
   | Leaving search | expanded |
   | Behaviour `.never` then `.onScrollDown` | expands, animated; does nothing if already expanded |

5. **iPad:** the regular top bar never minimizes. A compact window behaves exactly like an iPhone.
6. **Latency:** a 33–66 ms round trip (Flutter → native) moves the start of the collapse by the same amount. The rules do not change.

## 4. Behaviour

Compact width, native chrome engaged, `minimizeOnScroll: true`.

| Trigger | Native bar (after VK-600) | Flutter bar (after VK-600) |
|---|---|---|
| The user scrolls the body down (≈ 20–40 pt) | minimizes (UIKit) | minimizes (unchanged, §5.7 of P1, VK-503 §10) |
| The user drags back up in mid-content | stays minimized | stays minimized (unchanged, VK-503 Q7) |
| A fling reaches the top edge | expands (UIKit, plus Dart's expand request as a backstop, §9.1) | **expands (new, Q2)** |
| A programmatic scroll ends at the top (status-bar tap, `animateTo(0)`) | **expands (new, Q3: Dart asks, native toggles the behaviour)** | **expands (new, Q2/Q3)** |
| Tap on the minimized circle | expands (UIKit) | expands (unchanged) |
| The selected destination changes (a tap, the app, the guard's answer) | **expands (new, Q4: native toggles on select; not into search, Q5)** | expands (unchanged) |
| The search tab is selected | no minimize (Q5) | no minimize (unchanged) |
| Regular width (top bar, sidebar) | never minimizes (UIKit) | not applicable (unchanged) |
| `minimizeOnScroll: false` | never (`.never`) | never (unchanged) |
| A scroll inside a platform view (web view, native map) | no minimize (Q7) | minimizes if the platform view sends no Flutter scroll notifications (unchanged) |
| Reduce Motion | UIKit's own handling | unchanged |

## 5. Public API

- **`LiquidShell.minimizeOnScroll`** keeps its type and its default (`true`). Its doc changes from "Compact bottom bar only" (Flutter bar) to cover both bars:

  ```dart
  /// Compact bottom bar only, Flutter-drawn or native (iOS 26+): shrink to
  /// the selected tab while the body scrolls down. Scrolling back up in
  /// mid-content does not expand it; a fling or a programmatic scroll that
  /// ends at the top does, as do a tap on the minimized circle and a change
  /// of the selected destination. Neither bar minimizes while the search
  /// destination is selected, nor at regular width.
  final bool minimizeOnScroll;
  ```

- No other public member changes. `LiquidShellScopeData` is unchanged: the native bar's minimize changes no inset (§8.6).
- `doc/native_chrome.md` drops "`minimizeOnScroll` applies to the Flutter bar only" and gains a "Minimize on scroll" section (§14).

## 6. Platform interface (`liquid_shell_platform_interface`)

- `LiquidNativeChromeConfig` gains `final bool minimizeOnScroll` (constructor default `false`, so `dormant` stays as it is), part of `==` and `hashCode`.
- `LiquidShellPlatform` gains two methods. Each has a default that does nothing, so adding them is not a breaking change (the class is extended, never implemented):

  ```dart
  /// The selected destination [tab]'s body scroll offset for the native
  /// tab bar's minimize (spec VK-600 §9): positive below the top, zero or
  /// negative at it. Default: does nothing.
  Future<void> setNativeMinimizeScroll({
    required int tab,
    required double offset,
  }) async {}

  /// Expands a minimized native tab bar now (a programmatic scroll reached
  /// the top). Default: does nothing.
  Future<void> expandNativeTabBar() async {}
  ```

## 7. The channel (`liquid_shell_ios/pigeons/native_shell.dart`)

- `NativeChromeConfig` gains `bool minimizeOnScroll;`, declared last, after `interactive`.
- `NativeShellHostApi` gains two methods. They go after VK-550's `setSearchScope` and `dismissSearchKeyboard` (§13):

  ```dart
  /// The body scroll offset of destination [tab] for the tab bar's
  /// minimize (proxy scroll view, spec VK-600 §8).
  void setMinimizeScroll(int tab, double offset);

  /// Expands a minimized tab bar (spec VK-600 §8.5).
  void expandTabBar();
  ```

- `make pigeon` regenerates both ends. The source and the two generated files are committed together.
- `liquid_shell_ios` maps them in `mapping.dart` (`configToNative`: `minimizeOnScroll`) and `platform.dart` (the boundary checks: a non-finite offset never crosses, and a negative tab is dropped).

## 8. Native (`liquid_shell_ios`)

### 8.1 `MinimizeProxy` (new, `MinimizeProxy.swift`)

```swift
/// The invisible scroll view UIKit's tab bar minimize follows (spec
/// VK-600 §8). Locked: only `setOffset` moves it, so the bar follows the
/// Flutter content. Its own pan, attached to the Flutter view, makes it
/// "user-tracked"; that pan never moves it.
@available(iOS 26.0, *)
final class MinimizeProxy: UIScrollView {
  /// Dart's last offset (points below the top; ≤ 0 at the top).
  private(set) var offset: Double = 0
  /// The view whose own subviews are platform views: a pan over one of
  /// them does not begin (spec §8.3).
  weak var contentView: UIView?
  private var writing = false

  override init(frame: CGRect)          // clear, no interaction, no
                                        // indicators, scrollsToTop false,
                                        // .always insets, 1 × 100 000 content,
                                        // hidden from accessibility, pan
                                        // allowedScrollTypesMask = []
  override var contentOffset: CGPoint   // setter applies only while writing
  func setOffset(_ value: Double)       // finite only; y = −adjustedTop + value;
                                        // grows the content first (below)
  override func adjustedContentInsetDidChange()   // re-applies `offset`
  override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool
                                        // own pan: false when its location
                                        // hit-tests to a subview of contentView
}
```

Its deceleration after a release is left running, without overriding `scrollViewWillEndDragging`. The spike (C11) showed that the expand at the top needs it.

**The content grows with the offset** (Task 6 review). Nothing clamps the offset, so past about 99 270 pt (an iPhone, 100 000 pt of content) a long feed would leave the proxy in its bottom overscroll, where UIKit most likely stops minimizing and the bottom scroll-edge effect may flip. `setOffset` therefore grows `contentSize.height` before less than `contentAhead` (50 000 pt) is left below the visible bottom, to the visible bottom plus twice that. A size change is not an offset change, so UIKit sees no scroll. The content only grows, so UIKit never needs to clamp the offset (and the lock would drop that write). Only `setOffset` still moves the proxy. A Dart-side wrap or a relative offset was rejected: a wrap is a jump that UIKit reads as a scroll, and a relative offset only moves the bound into a native accumulator. As built after Task 6.

### 8.2 Hosts

- `TabHostController` (non-search destinations, and the trailing tab's host) owns one `MinimizeProxy`. `viewDidLoad` adds it full-size behind nothing (the host is empty) and calls `setContentScrollView(proxy, for: .bottom)`.
- The search tab's navigation controller and its `PageHostController`s get no minimize proxy (Q5). Their existing proxy stays `.top` only, and gets `scrollsToTop = false` (§8.4).

### 8.3 Pan attachment

`NativeTabsController.updateMinimizePan()` moves exactly one pan onto `flutter.view`. It runs at the end of `apply` (after `select` and `setChromeVisible`, so both are covered) and on a horizontal-size-class change.

- **Attached** when all of these hold:
  - `chromeVisible`, the config is `interactive`, and `isCompact`;
  - `config.minimizeOnScroll`;
  - the selected view controller is a `TabHostController`.
- **Otherwise none is attached.** A detached pan goes back to its own proxy (`proxy.addGestureRecognizer(proxy.panGestureRecognizer)`), as UIKit expects. Leaving compact also resets every proxy to offset 0, so the iPad top bar's scroll-edge effect never sees a stale offset.
- **No pan outlives its proxy on the Flutter view.** UIKit leaves a released scroll view's pan where it is, so a `TabHostController` takes its pan back as it goes (a structure rebuild, the shell's release), and a scene disconnect detaches the old shell's pan at once (`NativeShellInstaller.sceneDisconnected`).
- While attached: `cancelsTouchesInView = false`, `delaysTouchesBegan = false`, `delaysTouchesEnded = false`, `allowedScrollTypesMask = []` (direct touches only). `MinimizeProxy.contentView = flutter.view`, so a pan that starts over a platform view does not begin.
- Hit testing (`PassThroughView`, P2 §5.3) is unchanged. The proxy is not hit-testable, and the pan only *observes* touches that already go to Flutter.

### 8.4 `scrollsToTop` and accessibility

- iOS runs the status-bar scroll-to-top only when one scroll view on screen has `scrollsToTop` set. Flutter's own hidden scroll view needs to be that one, so every proxy has `scrollsToTop = false`. That covers the new `MinimizeProxy` and the search page's existing proxy (`PageHostController.proxy`, which today keeps the default `true`; Q10).
- Proxies are hidden from accessibility: `isAccessibilityElement = false`, `accessibilityElementsHidden = true`.

### 8.5 Behaviour and expand

- `apply` sets `tabBarMinimizeBehavior = new.minimizeOnScroll ? .onScrollDown : .never`, only on change.
- `expandMinimizedBar()`: if the behaviour is `.onScrollDown`, set `.never`, then `.onScrollDown`. Spike §3.2: this expands a minimized bar with the normal animation, and does nothing to an expanded one.
- `select(_:)` calls it whenever it changes the selected tab (Q4), except into the search tab: search keeps UIKit's own form there, as with a real scroll view (Q5, spike §3.2), and the toggle stays out of the VK-550 scope bar's and the keyboard's way. Leaving search expands as any change does.
- The host API `expandTabBar()` calls it (Q3).

### 8.6 Offsets and insets

- `setMinimizeScroll(tab:offset:)`: drop a non-finite offset or an unknown tab. Look up `minimizeHosts[tab]`. The hosts are built with the tabs (§8.2), so an unknown or search index finds nothing. Call `host.minimizeProxy.setOffset(offset)`. No `syncFlutter`: the minimize changes no frame and no safe area. Without an accessory the bottom safe area stays 83 pt (iPhone), 82 pt (iPad 26.5) or 77 pt (iPad 27.0) in both states (spike §3.3–3.4).
- A host that is not shown yet keeps the offset and applies it when its view loads. A structure rebuild makes new hosts at offset 0. Dart sends the selected tab's offset again whenever the selection or the attachment conditions change (§9.2).

### 8.7 Debug snapshot

`NativeDebugSnapshot` gains `minimizeBehavior` (`"never"`, `"onScrollDown"`, `"automatic"`, `"onScrollUp"`) and `minimizePanAttached` (Bool). They are for integration tests. They do not report the minimized state, which no public API exposes.

## 9. Dart (`liquid_shell`)

### 9.1 `MinimizeScrollTracker` (new, `lib/src/native/native_minimize.dart`, pure)

One virtual offset per destination, driven by the body's vertical scroll notifications:

```dart
/// What one scroll notification did to the tracker.
enum MinimizeScrollResult {
  /// Nothing to send.
  none,
  /// The tab's offset changed.
  moved,
  /// The offset changed, and a fling or a programmatic scroll carried the
  /// content up to its top edge: expand the bar.
  expand,
}

final class MinimizeScrollTracker {
  /// The tab's offset: > 0 below the top, ≤ 0 at the top edge.
  double offsetOf(int tab);
  MinimizeScrollResult start({required int tab});
  MinimizeScrollResult update({
    required int tab,
    required double pixels,
    required double minScrollExtent,
    required double delta,
    required bool dragging,
  });
  /// The adapter the shell calls: vertical notifications only.
  MinimizeScrollResult handleNotification(ScrollNotification n, {required int tab});
  void forget(int tab);         // a destination left the list
}

/// The smallest offset while the scrolled view is away from its top.
const double kMinimizeAwayFromTop = 1;
```

Rules. Only `n.metrics.axis == Axis.vertical` counts, at every depth, as for the Flutter bar:

1. `ScrollStartNotification`: a new scroll; it may expand once.
2. `ScrollUpdateNotification`, with `m = n.metrics` and `atTop = m.pixels <= m.minScrollExtent`:
   - The offset becomes `atTop ? m.pixels - m.minScrollExtent : max(offset + (n.scrollDelta ?? 0), kMinimizeAwayFromTop)`.
     - With one scroll view this is exactly its pixels.
     - With several, the offset stays continuous. It never reaches the top while the scrolled view is below its own top, and it snaps to the top when that view reaches its own.
   - The result is `expand` when all of these hold: the movement is not a drag (`dragDetails == null`: a fling, or `animateTo`/`jumpTo`); it moves toward the top (`scrollDelta < 0`); it reaches `atTop`; and this scroll has not expanded yet.
     - A drag into the top never expands, as UIKit's (spike §3.1).
     - The bounce back from an overscroll has `scrollDelta > 0`, so it never expands either.
   - Otherwise the result is `moved` if the offset changed, else `none`.
   - A view **nested** in another vertical scroll view (a small list in a card, a `NestedScrollView`'s inner list) moves the offset like any other, but `atTop` is false for it. So it never snaps the offset to the top and never expands: its own top is not the page's. The adapter finds it from `n.depth` (the viewports passed on the way up). At depth 0, the common case, there is no walk. Otherwise it walks that many enclosing `ScrollableState`s and looks for a vertical one, so a list in a horizontal `PageView` is still the page. As built in Task 6.
3. `ScrollEndNotification` from a view that is not nested: at rest the offset **drops** to that view's own, `m.pixels - m.minScrollExtent`, floored at `kMinimizeAwayFromTop` while below the top. Deltas that the tracker missed then do not outlive one scroll: a view replaced, or pixels corrected without a notification. As built in Task 6, made lower-only by the Task 6 review.
   - **It never rises.** UIKit ignores a move it does not track only while no touch and no deceleration is in flight (spike §2, §3.2). After a flick, UIKit's own deceleration on the locked proxy is still running and reads Dart's writes (C11, which the fling-to-top expand relies on). Flutter's end can land inside that window. A raise there, for example with several lists in one tab (a `TabBarView`) or after `correctPixels`, would read as a scroll down and minimize the bar while the user scrolled up. A drop at rest is safe: it moves toward the top, and an expand needs the top itself, which the snap of rule 2 governs.
   - So: a view at its top gives its own (zero or less, a raise only within the top region, which UIKit ignores). A view below its top keeps the lower of its own and the current offset, and lifts an offset at the top only to `kMinimizeAwayFromTop`.
   - **`NestedScrollView`:** both coordinator positions send a start and an end (`nested_scroll_view.dart`, Flutter 3.44.6). The outer's end is at depth 0; the inner's is nested and ignored. So at rest the offset drops to the **outer** view's pixels (at most the header's extent), not the page's. That is a drop, so it is harmless.
4. Every other notification: `none`.

The `expand` result is the same rule UIKit applies (spike §3.1: the deceleration that reaches the top expands). Dart sends it to native too, for two reasons:

- It covers the programmatic scrolls UIKit cannot see (Q3).
- It is a backstop if the proxy's own deceleration (UIKit's physics) ends before Flutter's fling reaches the top. Toggling an expanded bar does nothing (spike §3.2), so a double expand is harmless.

### 9.2 Sending

- `_onBodyScroll` feeds the tracker with the selected index, in both chrome modes. Only a view on screen counts (`isOnScreenUnder` the body, as for VK-567's navigators): an `IndexedStack` keeps the other tabs' lists, and an app that scrolls one of them must not move or expand the selected tab's bar.
- With native chrome (kind `null`), a `moved` or `expand` result schedules one post-frame send, deduplicated per (tab, offset), like `_scheduleScrollSync`.
- With native chrome, an `expand` also calls `claim.expandTabBar()`.
- **Active** only when all of these hold:
  - the shell owns the chrome and it is engaged;
  - `state.compact`;
  - `widget.minimizeOnScroll`;
  - the search tab is not selected;
  - the chrome is not hidden;
  - the shell's route is current.

  These are the same conditions as the native attachment (§8.3), and `nativeMinimizeActive(...)` in `native_minimize.dart` is the one predicate for them.
- When it becomes active, or the selection changes while active, the selected tab's current offset is sent once, even if unchanged.
- The same forced send follows (§8.6: new native hosts start at offset 0):
  - a config that may rebuild the native tabs (`nativeTabsMayRebuild`: other tabs or another trailing action, a superset of the native structure). It is sent from the config's own post-frame callback, right after the config, never before it;
  - a `LiquidNativeStateChanged`, which follows the host's forced config resend after a scene reconnect.
- A destination that leaves the list (the list shrinks) is `forget`-ed, so a destination that comes back at that index starts at 0.
- `NativeChromeClaim` gains `setMinimizeScroll({tab, offset})` and `expandTabBar()`, sent only while it owns the chrome.

### 9.3 Config

`nativeConfigFor(..., minimizeOnScroll: widget.minimizeOnScroll)` → `LiquidNativeChromeConfig.minimizeOnScroll`.

### 9.4 The Flutter bar (Q2)

The Flutter bar (kind `bottomBar`) uses the same tracker result. With `minimizeOnScroll` on and search not selected, `expand` sets `_minimized` to false. So a fling or a programmatic scroll that reaches the top expands the bar. A drag never does, and `UserScrollNotification.forward` still does nothing (VK-503 Q7). One rule in one place serves both bars.

## 10. Edge cases

| Case | Behaviour |
|---|---|
| Content shorter than the viewport | iOS bounce physics overscrolls at the top: `atTop`, so the offset stays ≤ 0 and nothing minimizes. A bounce past the bottom is a positive offset and can minimize, as with UIKit's own short scroll view |
| Several vertical scroll views (an iPad master/detail in a narrow window) | One continuous virtual offset per tab (§9.1). At rest it only drops, so a flick that stops in another list never minimizes (§9.1 rule 3) |
| A very long feed (past 100 000 pt) | The proxy's content grows ahead of the offset (§8.1), so it never sits in its bottom overscroll |
| A horizontal carousel inside the list | Ignored (axis). The proxy pan's vertical component does not move the locked proxy |
| A vertical slider or a text-selection drag | Flutter's list does not move, so the offset does not change and nothing minimizes |
| A drag that starts over a platform view | The pan does not begin (§8.3). The platform view scrolls as before (spike §4) |
| A drag that starts on the native bar | Not on the Flutter view: the pan never sees it |
| Tab switch while minimized | The bar expands (Q4), except into the search tab (Q5). The new tab's proxy takes the pan and Dart sends its offset |
| A dialog, sheet or pushed page above the shell | The chrome is hidden or inert: pan detached, nothing sent. UIKit keeps its state; when the cover goes, the pan comes back |
| `LiquidHideChrome` | The same as hidden |
| Rotation or size-class change | Regular: pan detached, proxies reset to 0. Back to compact: re-attached; Dart sends the offset |
| Scene reconnect, hot restart | The config is re-sent whole (P2), which re-applies the behaviour. Dart sends the offset again when active (§9.2) |
| A status-bar tap | Flutter scrolls to the top (the proxies no longer compete for it, §8.4). The scroll ends at the top and Dart asks native to expand (Q3) |
| A scroll that ends at the top under `minimizeOnScroll: false` | Nothing (`.never`) |
| A bottom accessory (not used) | Measured for later: inline while minimized, and the host's bottom safe area goes 139 → 83 pt (spike §3.4, Q9) |
| iOS < 26, Android, web | No native chrome; the Flutter bar only |

## 11. Accessibility

- The minimized circle and its expand are UIKit's, with UIKit's VoiceOver labels and actions.
- Proxies are hidden from accessibility (§8.4).
- VoiceOver three-finger scrolling scrolls Flutter as a programmatic scroll. It does not minimize. When it ends at the top it expands the bar (Q3).
- Reduce Motion: UIKit's own handling for the native bar. The Flutter bar keeps VK-503 Q11 (instant).

## 12. Testing

### 12.1 Dart unit (`make test`)

`liquid_shell/test/unit/native_minimize_test.dart` covers:

- the tracker rules of §9.1:
  - one view; several views; the snap to the top; overscroll; a non-zero `minScrollExtent`;
  - horizontal notifications are ignored;
  - a non-drag movement up to the top gives `expand`, once per scroll;
  - a drag to the top does not, and neither does the bounce back from an overscroll;
  - at rest the offset drops to the view's own and never rises to it;
- `nativeMinimizeActive` truth table.

### 12.2 Platform interface and iOS Dart

- `liquid_shell_platform_interface/test/native_chrome_test.dart`: `minimizeOnScroll` default, `==` and `hashCode`.
- `liquid_shell_platform_test.dart`: both new methods do nothing by default.
- `liquid_shell_ios/test/liquid_shell_ios_test.dart`:
  - the config maps `minimizeOnScroll`;
  - `setNativeMinimizeScroll` forwards finite offsets only;
  - `expandNativeTabBar` forwards;
  - a `PlatformException` is logged once, never thrown.

### 12.3 Widget (`make test`, `FakeNativePlatform`)

`liquid_shell/test/widget/native_minimize_test.dart`:

- compact native, a dragged list sends the offset after each frame, deduplicated;
- regular sends none;
- `minimizeOnScroll: false` sends none, and the config carries `false`;
- the search tab selected sends none;
- hidden chrome or a dialog above sends none;
- a selection change sends the new tab's offset;
- `animateTo(0)` after a scroll calls `expandNativeTabBar` once, and so does a fling that reaches the top; a drag back to the top does not.

`minimize_test.dart` (Flutter bar, Q2):

- a fling that ends at the top expands;
- a drag back to the top does not;
- `animateTo(0)` expands;
- with `minimizeOnScroll: false`, or in the search tab, a fling to the top does not clear the kept flag (Task 7 review; as built in `shell_behaviour_test.dart`).

### 12.4 XCTest (`make ios-unit`, RunnerTests)

`MinimizeProxyTests`:

- the lock: UIKit's writes are dropped, `setOffset` maps to `-adjustedContentInset.top + offset`, a non-finite offset is ignored, the offset is re-applied after an inset change;
- a long feed: `setOffset(250_000)` grows the content ahead of the offset (never into the bottom overscroll), the lock holds, and the content never shrinks;
- `scrollsToTop` false; accessibility hidden; `allowedScrollTypesMask` empty;
- the gesture gate over a subview of `contentView`.

`NativeTabsTests` additions:

- behaviour `.onScrollDown`/`.never` from the config;
- the pan on the Flutter view only in compact, visible, interactive, `minimizeOnScroll`, non-search;
- the pan moves with the selection and goes back to its proxy;
- regular resets offsets;
- `select` toggles the behaviour on a change;
- `setMinimizeScroll` reaches the right host;
- the page proxy has `scrollsToTop` false.

### 12.5 XCUITest (`make ios-ui`, RunnerUITests, real touches)

`MinimizeUITests`, demo `tabs`:

1. iPhone (`XCTSkipUnless .phone`):
   - a swipe up on the list minimizes the native bar;
   - a reverse drag in mid-content keeps it minimized;
   - a flick down to the top expands it;
   - a tap on the circle expands it;
   - a tab tap while minimized expands it.
2. iPad regular: a swipe never minimizes.

"Minimized" is read from UIKit's accessibility tree: the unselected tab buttons stop being hittable, and the selected one shrinks to about 48 pt. Task 8 records which of the two UIKit exposes on 26.5 and 27.0 and keeps that signal (spike §1.2: the probe could not read accessibility from inside the app).

### 12.6 Manual (`docs/qa/vk600/manual.md`, owner, device)

- the Apple Music feel on an iPhone with iOS 26 and with iOS 27;
- a narrow iPad window;
- a platform view;
- a status-bar tap;
- VoiceOver;
- Reduce Motion;
- iPhone landscape;
- the bottom scroll-edge effect under the bar, before and after VK-600 (R3).

## 13. Rebase on VK-550, versions

- VK-550 changes these on its side:
  - `NativeTabsController.swift`: the scope bar;
  - `SearchBridge.swift`, `NativeShellInstaller.swift`;
  - `pigeons/native_shell.dart`: `setSearchScope`, `onSearchScopeChanged`, `NativeSearchConfig.scopes`, the snapshot's scope fields;
  - both generated files;
  - `liquid_shell.dart`, `native_chrome.dart`, `liquid_shell_platform.dart`, `platform.dart`, `mapping.dart`;
  - the versions, to `0.1.0-dev.7`.
- Order (plan Task 0): wait for VK-550's merge, then `git rebase origin/main`. Only this branch's docs commits move, so no conflict is expected. Then every code task starts from VK-550's files.
- Pigeon: never merge generated files by hand. Edit the source after VK-550's additions and run `make pigeon`.
- Version: every package `0.1.0-dev.8` with a CHANGELOG entry (Q11). The `minimizeOnScroll` change in behaviour is called out.

## 14. Docs

- `liquid_shell/doc/native_chrome.md`:
  - replace "`minimizeOnScroll` applies to the Flutter bar only";
  - add a "Minimize on scroll" section with the rules of §4;
  - list the limits: no regular top bar, not in search, platform views, trackpad;
  - add a troubleshooting line: "never minimizes: check `minimizeOnScroll`, compact width, not the search tab".
- `liquid_shell/doc/tab_bar.md`: the Flutter bar's new expand rule (Q2).
- `LiquidShell.minimizeOnScroll` dartdoc (§5).
- CHANGELOG ×4 (§13).

## 15. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | UIKit's trigger (a real pan on the content scroll view) is undocumented; a new iOS may observe scrolling differently | XCUITest with real swipes (§12.5) on the newest simulator at every Xcode or iOS bump; `minimizeOnScroll: false` turns it off; the failure mode is today's behaviour (no minimize), never a broken scroll |
| R2 | A UIScrollView pan on the Flutter view interferes with Flutter's gestures | It never cancels or delays touches; direct touches only (Flutter's trackpad pan takes indirect ones only); it does not begin over platform views; the spike saw no change in delivery. Manual check on a device |
| R3 | The bottom scroll-edge effect under the compact bar now follows the proxy instead of having no scroll view | Before/after screenshots in the manual check; if it differs visibly, a new owner question |
| R4 | The lock (a `contentOffset` setter override) relies on UIKit moving the offset through that setter. It also drops UIKit's first inset adjustment (spike §2: +62 pt until Dart's first write) | `adjustedContentInsetDidChange` re-applies Dart's offset. The XCTest pins that every write other than `setOffset` is dropped and that an inset change keeps the offset. The XCUITest proves the whole chain. If a future iOS bypasses the setter, the unlocked proxy (spike C7) still minimizes |
| R5 | Latency: the collapse starts 1–3 frames later than UIKit's own | Measured, invisible (spike §5) |
| R6 | VK-550 lands changes in the same files | Rebase first (Task 0); regenerate Pigeon |

## 16. Process

- Plane VK-600: Backlog → spec and plan for approval (this commit) → Todo with `spec:approved` after the owner's answer → one sub-issue per plan task.
- After VK-550 merges: rebase, then `superpowers:subagent-driven-development`, task by task (TDD red → green → commit), then `superpowers:requesting-code-review`, `make verify`, the iOS suites, the owner's device check, and the PR.

## Quyết định cần chủ sản phẩm xác nhận

Mỗi dòng có đề xuất mặc định. Nếu chủ sản phẩm trả lời "Ok hết" thì áp dụng toàn bộ đề xuất.

| Q# | Câu hỏi | Đề xuất |
|---|---|---|
| Q1 | Bật tính năng bằng cờ nào? | **Dùng lại `minimizeOnScroll` (mặc định bật) cho cả thanh native.** Không thêm cờ mới. CHANGELOG ghi rõ đây là thay đổi hành vi: app đang dùng native chrome sẽ tự có thanh thu nhỏ sau khi nâng cấp |
| Q2 | Thanh Flutter có nở ra khi cú vuốt đưa nội dung về đầu trang, giống native vừa đo được, không? | **Có.** Luật Q7 của VK-503 chỉ đo cú kéo ngược 200pt nên chưa thấy. Nay đã rõ native nở ra khi cú vuốt chạm đầu trang. Kéo tay về đầu trang thì vẫn không nở. Việc nhỏ (Task 7), tách riêng được nếu muốn |
| Q3 | Cuộn về đầu trang bằng code (chạm thanh trạng thái, `animateTo(0)`, VoiceOver) có làm thanh nở ra không? | **Có, cho cả hai thanh.** UIKit tự nở khi chính nó cuộn về đầu. Với nội dung Flutter thì Dart báo, native đổi `tabBarMinimizeBehavior` sang `.never` rồi đặt lại (cách công khai, đã thử) |
| Q4 | Đổi tab (chạm tab, app đổi bằng code, sau hộp thoại chặn) khi thanh đang thu nhỏ? | **Thanh nở ra**, giữ đúng luật hiện có của thanh Flutter. UIKit tự nó thì giữ nguyên dạng thu nhỏ khi app đổi tab bằng code, nên native cũng đổi behaviour như Q3 |
| Q5 | Có thu nhỏ khi đang ở tab Tìm không? | **Không**, giống thanh Flutter và P3b §9.2. Ở iPhone, tab Tìm đã có dạng thu gọn riêng (hình tròn tab trước + ô tìm) |
| Q6 | iPad màn rộng (thanh tab trên cùng)? | **Không thu nhỏ**: UIKit không hỗ trợ, đã đo trên 26.5 và 27. iPad cửa sổ hẹp thì thu nhỏ như iPhone |
| Q7 | Cuộn bên trong platform view (web view, bản đồ native nhúng trong Flutter)? | **Chấp nhận không thu nhỏ.** Cử chỉ của platform view được giữ nguyên, không bị tranh chấp |
| Q8 | Cuộn bằng trackpad/chuột trên iPad cửa sổ hẹp? | **Chấp nhận không thu nhỏ.** Bộ nhận cử chỉ chỉ nhận chạm trực tiếp, để không tranh với bộ cuộn trackpad của Flutter |
| Q9 | `bottomAccessory` (thanh mini player như Apple Music)? | **Ngoài phạm vi VK-600.** Đã ghi lại hành vi để làm sau: khi thu nhỏ, accessory nằm cùng hàng với hình tròn, và safe area dưới đổi 139 → 83pt nên nội dung sẽ dịch |
| Q10 | Đặt `scrollsToTop = false` luôn cho proxy cũ của trang Tìm (hiện để mặc định true) trong cùng nhánh? | **Có.** Thay đổi một dòng, có XCTest kèm theo. Mục đích là để chạm thanh trạng thái luôn đến được Flutter |
| Q11 | Phiên bản? | **`0.1.0-dev.8`** cho cả 4 gói, nối tiếp dev.7 của VK-550, kèm CHANGELOG |
| Q12 | Hiệu ứng mờ mép dưới của UIKit (scroll edge effect) nay chạy theo proxy. Nếu khác trước thì sao? | **Chấp nhận nếu ảnh chụp trước/sau trông như nhau** (kiểm ở bước kiểm tay). Nếu khác rõ thì mở câu hỏi mới trước khi merge |
