# VK-600 spike: driving the native tab bar's minimize from Flutter scrolling

- **Plane:** VK-600. **Date:** 2026-10-14/15. **Branch:** `VK-600-native-tab-minimize` off `main` at `c531be0`.
- **Question.** UIKit minimizes the iOS 26+ compact tab bar (`UITabBarController.tabBarMinimizeBehavior = .onScrollDown`) by watching a `UIScrollView`. Flutter content has none. Can Flutter scrolling drive the native minimize, with public API only?
- **Answer: yes.** Attach the tab's hidden proxy scroll view's own `panGestureRecognizer` to the Flutter view (`cancelsTouchesInView = false`). The user's real touches then make the proxy "user-tracked", which is what UIKit waits for. Dart still decides how far the proxy moves: the proxy ignores every offset write except Dart's ("locked proxy"). This works on iPhone and on a compact iPad window, on iOS 26.5 and 27.0. The minimize and expand animations are UIKit's own. A proxy moved by code alone never minimizes, whatever it reports.

## 1. Setup

| | |
|---|---|
| Xcode | 27.0 (27A266a), iOS 27.0 SDK, Swift 6.4 (`-swift-version 5` for the probe) |
| Simulators (own, created for this spike and deleted after it) | iPhone 17 Pro on iOS 26.5 (23F77) and on iOS 27.0 (24A434); iPad Pro 11-inch (M5) on iOS 26.5 and on iOS 27.0 |
| Touch driver | `idb ui swipe` / `idb ui tap`: real HID touches, as a finger |
| Probe | One-file UIKit app built with `swiftc` for the simulator, kept outside the repo with its scripts and logs (vankhan `.superpowers/sdd/vk600-probe/`) |
| Example app | `liquid_shell/example` at `c531be0`, unmodified, demo `tabs` (native chrome), built with `flutter build ios --simulator --debug --config-only` plus `xcodebuild -destination id=<sim>` |

### 1.1 The probe

The probe mirrors liquid_shell's native layout (P2 §5.2, "approach C"):

- a container whose view is a pass-through view;
- a "canvas" at the bottom: the FlutterView analog. It is a plain `UIView` with no `UIScrollView`. It scrolls its own content from raw `touchesBegan/Moved/Ended` and runs its own fling;
- on top, a clear `UITabBarController(tabs:)` in `.tabSidebar` mode, as `NativeTabsController`, with `tabBarMinimizeBehavior = .onScrollDown`;
- clear tab hosts. Each host has a full-size proxy `UIScrollView` (clear, `isUserInteractionEnabled = false`, `contentInsetAdjustmentBehavior = .always`, content 100 000 pt tall), registered with `setContentScrollView(_:for: .bottom)` and `.top`.

The canvas reports every offset change to a `Driver`, which writes the selected host's proxy offset, as Dart would over the channel. Launch flags select the variant (§2). A second mode, `-variant real`, puts a real `UIScrollView` in each tab: that is UIKit's own behaviour, the baseline.

### 1.2 How "minimized" was observed

The probe never relies on a private API to *act*. To *observe*, its watcher reads, once per display-link frame:

- the frames of the bar's visible glass platters, from the view tree under `_UIFloatingTabBar` (class names used for reading only);
- the selected host's bottom safe area;
- the bottom accessory's `traitCollection.tabAccessoryEnvironment` (public), when there is one;
- the proxy or scroll view offset, with `isTracking` and `isDecelerating`.

At rest the iPhone bar is the 274 × 62 pill at (64, 791). Minimized it is a 48 × 48 circle at (28, 798), and the ⌕ circle shrinks from 62 to 48 about its centre (326, 798). These numbers match the VK-503 research. `min48`/`pill62` in the logs below count the platters of each size.

For reading only, the probe also listed UIKit's selectors that mention "minimiz". UIKit keeps the state in `-[UITabBar _setMinimized:]` / `_isMinimized` and `_UITabBarVisualProvider_Floating setMinimized:`, all private. **No public API sets or reads the minimized state** in the iOS 26.5 or the iOS 27.0 SDK. Checked: `UITabBarController.h`, `UIBarMinimization.h`, `UIScrollView.h`, `UIViewController.h` and the UIKit swiftinterface. iOS 27 adds `UINavigationItem.navigationBarMinimization` (`UIBarMinimization`), which is for the navigation bar. Its doc says that an *integrated top tab bar* minimizes with that navigation bar. liquid_shell's regular-width top bar is not integrated with a navigation bar, so this does not apply.

## 2. Candidates and results

Driven on the iPhone 17 Pro, iOS 26.5, unless the row says otherwise. "Minimizes" means the 48 pt circle appeared.

| # | Variant | How the proxy moves | Minimizes | Notes |
|---|---|---|---|---|
| C1 | Proxy, `setContentScrollView(.bottom)` and `.top` (P2's probe again) | `contentOffset` by code, per frame | **No** | Scripted 0 → 700 → 0 → 400; also with real touches on the canvas |
| C2 | C1, proxy subclass returns `isTracking`/`isDragging` = true while dragging | by code | **No** | UIKit does not ask these getters |
| C3 | C2 plus `isDecelerating` = true during the fling | by code | **No** | |
| C4 | C3 plus `panGestureRecognizer` overridden to return our own pan, whose `state` is `.began/.changed/.ended` | by code | **No** | UIKit reads its own pan, not the getter |
| C5 | `setContentOffset(_:animated: true)` | by code | **No** | Same as C1 (P2 §14.3) |
| **C6** | **The proxy's own `panGestureRecognizer` added to the canvas** (`cancelsTouchesInView = false`); the proxy scrolls itself; the canvas follows the proxy | **the pan** | **Yes** | The canvas still gets every touch (`TOUCH began/ended` logged, never `cancelled`) |
| **C7** | **C6, but the canvas scrolls itself and writes the proxy each frame ("sync")** | the pan, then code | **Yes** | The proxy follows the canvas within a frame |
| **C8** | **C7 with a locked proxy:** its `contentOffset` setter drops every write except the Driver's | **code only**; the pan only makes it "tracked" | **Yes** | **Chosen.** The bar follows the content's real movement |
| C9 | C8, proxy `isUserInteractionEnabled = false` | code only | Yes | The proxy need not be hit-testable |
| C10 | C8, pan attached to the container's root view instead of the canvas | code only | Yes | Rejected anyway: a pan on an ancestor also sees touches on the native bar (§7) |
| C11 | C7, the proxy's own deceleration cancelled (`targetContentOffset = current`) | the pan, then code | Yes | **But a fling back to the top does not expand.** Keep the proxy's deceleration running |
| C12 | C8, Driver writes delayed by 33 ms and by 66 ms (Flutter's round trip) | code only | Yes | Same rules. It starts about one frame later per frame of delay |
| C13 | C8 on iOS 27.0, iPhone | code only | Yes | Identical to 26.5 |
| C14 | C8 on an iPad, compact width (`traitOverrides.horizontalSizeClass = .compact`), 26.5 and 27.0 | code only | Yes | As on iPhone |
| C15 | C8 on an iPad, regular width (top tab bar), 26.5 and 27.0 | code only | No | Neither does a real scroll view (§3.3): the top bar never minimizes |

Why C6–C8 work and C1–C5 do not: UIKit decides from the scroll view's own drag. The `isTracking`, `isDragging`, `isDecelerating` and `panGestureRecognizer` getters are not what it reads (C2–C4). A real pan recognizer on the proxy, fed by the user's real touches wherever they land, is the one public way in. With the pan in place, the offset can come from anyone: the locked proxy (C8) proves that UIKit uses the drag for "is the user scrolling" and the offset deltas for "which way and how far".

The lock held. After the first write, the locked proxy's offset equalled the canvas's within 0.2 pt in every logged frame: 78 frames on 26.5, 81 on 27.0. The one exception is the start. The lock also dropped UIKit's own first inset adjustment, so before Dart's first write the proxy sat 62 pt "scrolled". The real proxy must therefore re-apply Dart's offset whenever its adjusted inset changes (`adjustedContentInsetDidChange`).

The working wiring, reduced:

```swift
final class LockedProxy: UIScrollView {
  private var writing = false
  override var contentOffset: CGPoint {        // UIKit's own writes are dropped
    get { super.contentOffset }
    set { if writing { super.contentOffset = newValue } }
  }
  func setOffset(_ y: CGFloat) {                // Dart's value
    writing = true
    super.contentOffset = CGPoint(x: 0, y: -adjustedContentInset.top + y)
    writing = false
  }
}
// In the host: add the proxy, setContentScrollView(proxy, for: .bottom).
// On the selected tab:
proxy.panGestureRecognizer.cancelsTouchesInView = false
flutterView.addGestureRecognizer(proxy.panGestureRecognizer)
// tabBarController.tabBarMinimizeBehavior = .onScrollDown
```

UIScrollView's pan already has `delaysTouchesEnded = false` (read in the probe), and `delaysTouchesBegan` is false by default. So Flutter gets each touch at the same time as before, and none is cancelled.

## 3. UIKit's own rules (baseline: a real `UIScrollView`)

### 3.1 Minimize and expand, iPhone 17 Pro

The sequence (`seqB`):

1. a swipe up of 300 pt in 0.3 s;
2. a slow reverse drag of 100 pt in 1.0 s;
3. a fast reverse flick of 200 pt in 0.12 s;
4. three fast swipes down to the top;
5. a swipe up again;
6. a status-bar tap.

Times are seconds since launch.

| Event | 26.5 real | 27.0 real | 26.5 locked proxy (C8) | 27.0 locked proxy |
|---|---|---|---|---|
| Drag starts (tracking) | 2.912 | 3.92 | 2.673 (first canvas move) | 2.811 |
| Collapse starts (offset ≈ 20–40 pt) | 2.979 | 3.926 | 2.740 | 2.856 |
| 48 pt circle visible | 3.040 | 3.989 | 2.800 | 2.950 |
| Settled (last outgoing platter < 5 % alpha) | 3.778 (0.80 s) | 4.709 (0.78 s) | 3.539 (0.80 s) | 3.672 (0.82 s) |
| Slow reverse drag 90–100 pt mid-content | stays minimized | stays | stays | stays |
| Fast reverse flick, mid-content, until the fling ends | stays minimized until the top | same | same | same |
| The fling reaches the top edge (offset crosses 0) | **expands** at 10.745 | **expands** at 11.676 | **expands** at 10.522 | **expands** at 10.806 |
| Expand settled | 11.462 (0.72 s) | 12.410 (0.73 s) | 11.256 (0.73 s) | 11.539 (0.73 s) |
| Drags at the top (overscroll) | nothing | nothing | nothing | nothing |
| Swipe up again | minimizes | minimizes | minimizes | minimizes |

So `.onScrollDown`'s "expands when scrolling back up" (header comment) means in practice: **when the content returns to its top edge while decelerating**. A reverse drag or flick in mid-content does not expand. This matches VK-503's research ("a 200 pt scroll back did not expand") and refines it. In one other 26.5 run, a *drag* (finger down) carried the content past the top and did not expand either. Tapping the minimized circle expands it (UIKit; VK-503 research §6).

### 3.2 Other triggers (locked proxy, iPhone, 26.5)

| Trigger | Result |
|---|---|
| Programmatic scroll to the top: Dart-style offsets animated to 0 in 0.35 s, no touch (the Flutter status-bar tap, or `animateTo(0)`) | **Does not expand** |
| UIKit's own status-bar scroll-to-top on a real scroll view (iPad 27.0, compact) | Expands at the start of the scroll |
| `tabBarMinimizeBehavior = .never` then `.onScrollDown`, while minimized | **Expands**, with the normal 0.73 s animation. A public "expand now" |
| The same toggle while expanded | Nothing changes (no frame differs) |
| Programmatic `selectedTab` change while minimized | **Stays minimized** (the circle shows the new tab). The new tab's proxy took the pan; tapping the circle expands |
| Tap the minimized ⌕ (search tab), then scroll in search, then tap the circle | Search selected with the collapsed look (previous tab's circle + ⌕); scrolling there changes nothing; back on Home the **bar is expanded**. Same with a real scroll view |

### 3.3 iPad

| | 26.5 | 27.0 |
|---|---|---|
| Regular width (top tab bar, `.tabSidebar`), real scroll view | never minimizes | never minimizes |
| Regular width, locked proxy | never minimizes | never minimizes |
| Compact width (trait override), real scroll view | minimizes; expands on a fling to the top | same; a status-bar tap (UIKit scroll-to-top) also expands |
| Compact width, locked proxy | minimizes (6.391 → settled 7.190); expands at the top (16.823) | minimizes (9.342 → 10.058); expands at the top (21.558) |

The bottom safe area of a compact iPad window is 82 pt (26.5) or 77 pt (27.0). It does not change while minimized.

### 3.4 Bottom accessory

With `bottomAccessory` set (a label), minimizing puts the accessory inline (`tabAccessoryEnvironment` `.regular` → `.inline`). The host's bottom safe area drops **139 → 83 pt** on minimize and returns to 139 on expand. This is the same with the locked proxy (C8). Without an accessory the safe area stays at 83 pt (iPhone) in both states, so the Flutter view sees no metrics change. liquid_shell has no accessory today (P3b spec, non-goal).

### 3.5 Search tab

With a `UISearchTab`, the minimized bar shrinks the ⌕ circle from 62 to 48 pt about its centre. Selecting search while minimized shows search's own collapsed form. Leaving search shows the full bar. Real and proxy runs are identical (§3.2).

## 4. Interference checks

| Check | Result |
|---|---|
| Flutter's touches with the proxy pan on the Flutter view | Delivered as before, never cancelled |
| A real vertical `UIScrollView` inside the canvas (the analog of a platform view: a web view or a map) | Still scrolls normally; the inner pan wins. Its scrolling never minimizes (locked proxy: no offset change) |
| `gestureRecognizerShouldBegin(_:)` overridden on the proxy (UIScrollView is its pan's delegate) to refuse a pan whose location hit-tests to a subview of the Flutter view | Works ("refused over UIScrollView" logged); the platform view still scrolls |
| Switching tabs | Moving the pan from the old proxy to the new one (remove it from the Flutter view, add it back to its own proxy) works; minimize continues on the new tab |
| Proxies and `scrollsToTop` | Not measured on the example. iOS scrolls to the top only with a single eligible scroll view, so each new proxy must set `scrollsToTop = false` to keep Flutter's own status-bar tap. The search page's existing proxy does not set it (spec §8.4) |

## 5. Animation fidelity and latency

- The collapse and the expand are UIKit's own animations. Real and proxy are equal within a frame: collapse 0.78–0.82 s to settle, expand 0.72–0.73 s, on both OS versions. Nothing to match by hand.
- The trigger point is the same: about 20–40 pt of drag.
- Latency: with the Driver's writes delayed by 33 ms and 66 ms (C12), the collapse began 132 ms and 147 ms after the touch went down. Undelayed it began 67 ms after the first move, and a real scroll view about 34 ms after tracking began. A Flutter app adds one to three frames, the time for a pointer event to reach Dart and the offset to come back. Nobody will see that.

## 6. The example app today

`liquid_shell/example` at `c531be0`, demo `tabs`, native chrome, iPhone 17 Pro iOS 26.5. Two 300 pt swipes on the Flutter list ("Home item 1…24") scroll the list. The native bar stays full in every frame. `NativeTabsController` never sets `tabBarMinimizeBehavior`, and nothing gives UIKit a tracked scroll view. **Native chrome never minimizes**, as `doc/native_chrome.md` says.

The Flutter-side validation (a patched plugin with the locked proxy, driven by real Flutter scroll notifications) was **not run**. This branch stays docs-only: the brief forbids production changes here, and a temporary patch in the worktree was reverted before any build. C12 covers the one Flutter-specific factor, latency. Real Flutter scrolling proves it in the plan's Task 8: an XCUITest that swipes the example.

## 7. Decision and risks

**Decision:** C8, the locked proxy per tab host. The pan of the selected tab's proxy goes on the Flutter view, with `cancelsTouchesInView = false`, `allowedScrollTypesMask = []` and a `gestureRecognizerShouldBegin` gate against platform views. The proxy's own deceleration is left running. `tabBarMinimizeBehavior` is `.onScrollDown` when the shell's `minimizeOnScroll` is on, otherwise `.never`. The spec is `docs/specs/2026-10-14-native-tab-minimize-design.md`.

| Risk | Note |
|---|---|
| UIKit's trigger is undocumented: a real pan on the content scroll view | Public API only, but a new iOS may change how it observes. XCUITest (plan Task 8) on the newest simulator on every Xcode or iOS bump. `minimizeOnScroll: false` turns it off |
| The pan on the Flutter view | It recognizes alongside Flutter's own gesture handling. Direct touches only (`allowedScrollTypesMask = []`), so it never competes with Flutter's trackpad recognizer, whose `allowedTouchTypes` is empty. It never cancels or delays touches |
| C10 rejected | A pan on the container would also see drags on the native bar (UIKit's lens drag) and could block its recognizers |
| A Flutter scroll to the top does not expand (§3.2) | Dart asks native for an explicit expand (the behaviour toggle) |
| An app's tab switch does not expand (§3.2) | The native select toggles the behaviour, as Flutter's Q7 rule wants |

## 8. Clean-up

All four simulators were created for this spike and deleted after it. Two iPads were created a second time for C14/C15 and deleted again; `xcrun simctl list devices | grep vk600` is empty. The example's `build/` (619 MB) was removed. No DerivedData outside it was written. The worktree is clean apart from these docs.
