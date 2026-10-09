# liquid_shell P2: native iPadOS chrome design

- **Plane:** VK-346 (parent VK-343)
- **Date:** 2026-10-09
- **Status:** draft for the owner. The owner approves this spec and the plan `docs/plans/2026-10-09-p2-native-ios.md` together. Open choices are in §13, each with a recommended default; if the owner says nothing, the default applies.
- **Branch:** `VK-346-p2-native-ios`, from `main` at `8f437df` (P1 merged, VK-388 floor raise merged).
- **Floor:** Flutter 3.44.6 / Dart 3.12 (VK-388), iOS 15.0, `very_good_analysis` 10.3.0.
- **Sources:**
  - P1 spec `docs/specs/2026-10-08-p1-foundation-design.md` (API, Q1–Q18, style).
  - vankhan VK-242 on vankhan `main` (`a91a707`): spec `docs/superpowers/specs/2026-10-07-sidebar-ipad-goc-design.md`, ADR 0012, `packages/vankhan_shell` (Swift + Pigeon), and the final whole-branch review `vk242-final-review.md`.
  - vankhan VK-342 spec `2026-10-08-dinh-man-cua-so-design.md` (approved with Q1–Q7) and its research `vk342-research.md`.
  - The "liquid_shell P1" section of vankhan `.superpowers/sdd/progress.md` (P1 deferred items).
  - The dry run of the plan, `docs/plans/2026-10-09-p2-native-ios.md` §"Dry-run notes": every Dart test, an XCTest run and a native integration run on an iPad simulator, with measured numbers quoted below.

> **Tóm tắt (cho chủ sản phẩm).** P2 đưa khung iPad gốc của Văn Khấn (VK-242) vào `liquid_shell_ios`, đổi tên hết, và nối nó với `LiquidShell` của P1. Trên iPad iPadOS 26 ở khổ rộng, khi app bật khoá `LiquidShellNativeChrome` trong Info.plist và mọi đích có `sfSymbol`, khung là `UITabBarController(.tabSidebar)` thật của hệ thống: viên tab, nút sidebar, sidebar (dọc thì phủ, ngang thì nằm cạnh), nút phụ ⌕ ghim cuối viên, và footer native. Mọi nơi khác (iPhone, Android, iPad < 26, cửa sổ iPad hẹp) vẫn là khung Flutter của P1. Cách lắp giữ "cách C": FlutterView nằm dưới cùng, không bao giờ đổi cha; `UITabBarController` trong suốt phủ lên; chạm vào nền rơi xuống Flutter. Chạm tab native chỉ là *đề nghị*: Dart chạy `beforeDestinationChange` rồi mới chọn, nên lỗi mất dữ liệu I1 của VK-242 không thể lặp lại. Trang đẩy lên trên shell thì khung native ẩn; dialog thì khung native không nhận chạm. P2 cũng đọc cụm nút cửa sổ iPadOS 26 (`{leading, top}`), đưa vào `LiquidShellScope`, đẩy hàng đỉnh của khung Flutter và tiêu đề lớn qua cụm đó; ô tìm, tab tìm và nút quay lại để P3. Kênh dùng Pigeon (đã giải thích ở §6). Bản chạy thử đã xanh: 409 test Dart, 12 XCTest, 6/6 integration trên simulator iPad iOS 26.5. Các lựa chọn còn mở nằm ở bảng §13.

---

## 1. Goal

VK-343 asked for one library that owns the app's navigation chrome on every platform. P1 drew it in Flutter everywhere. P2 makes the iPad chrome the system's own on iPadOS 26, the way Apple's Music app does, without giving up P1's router-agnostic API:

1. **Native chrome.** On iPad with iPadOS 26 at regular width, `LiquidShell` hands its chrome to a real `UITabBarController` in `.tabSidebar` mode. Flutter draws only the body. The port is vankhan's VK-242 shell ("cách C", ADR 0012), renamed and generalised.
2. **One API.** The same `LiquidShell` call draws native chrome where it can and P1's Flutter chrome everywhere else. Apps add an SF Symbol per destination and one Info.plist key.
3. **Window controls (VK-342, window part).** Read the iPadOS 26 corner-adaptation region, expose `{leading, top}` through `LiquidShellScope`, and move P1's top row, the Flutter sidebar header and page large titles past the cluster. P3 consumes the same value for the back button and the search field.

## 2. Scope

### 2.1 In P2

| # | Item | Notes |
|---|---|---|
| S1 | Native shell in `liquid_shell_ios` | Container root, pass-through hit test, transparent `UITabBarController(.tabSidebar)`, tab hosts, safe-area copy, overlay `heldTop`, footer view (§5) |
| S2 | Install rules and lifecycle | Scene connect install, opt-in key, Mac and late-registration guards, scene disconnect/reconnect, hot restart, engine detach (§5.1, §5.7) |
| S3 | Pigeon channel | Host API (`attach`, `update`, `setSidebarVisible`, `windowControls`, `debugTap`) and Flutter API (taps, state, window controls) (§6) |
| S4 | `LiquidShell(nativeChrome:)` | Engagement rule, ownership, pending state, routes above the shell, hide chrome, selection through the guard, tiled body width (§7) |
| S5 | Native data on the public types | `LiquidDestination.sfSymbol`, `LiquidTabAction.sfSymbol`, `LiquidNativeSidebarFooter` (§4) |
| S6 | Window controls | Native reader, process-wide Dart source, `LiquidShellScopeData.windowControls`, `LiquidWindowControlsClearance`, P1 chrome shifts (§8) |
| S7 | Tests | Dart unit and widget, Swift XCTest, integration on iPad and iPhone simulators, simulator screenshots for the docs (§9) |
| S8 | Example, README, CI | `NativeChromeCase`, opt-in in the example's Info.plist, README sections, new make targets and CI jobs (§10) |

### 2.2 Non-goals

- **P3:** the glass back button and title bar, the search field, a selectable search tab (`UISearchTab`), and the sidebar search row. P2 exposes only the window-controls inset P3 needs.
- **The native liquid renderer for iOS 26.** P1 §2.3 listed it under P2; the approved P2 decomposition does not. It moves to P4 with the other liquid renderer (Q11).
- Native chrome on iPhone, on iPadOS before 26, or on Android. They keep the Flutter chrome (the same as P1).
- Multiple scenes and Stage Manager multi-window (`UIApplicationSupportsMultipleScenes = true`). An app with multiple scenes gets the Flutter chrome in every scene except the first one that connects.
- "Designed for iPad" on Apple-silicon Macs. These apps never install the native shell.
- A native sidebar header. `sidebarHeader` is a Flutter widget and appears only in the Flutter sidebar.
- `tabBarMinimizeBehavior`, keyboard shortcuts for tabs, sidebar groups, and the "Edit" button in the sidebar (every tab is `.fixed`, so it never appears).
- Swift Package Manager verification. This stays the P6 gate from P1 O2.
- Any change to Văn Khấn. P5 migrates it.

## 3. What P2 carries over

### 3.1 From vankhan VK-242 (Swift sources are SAFE: written in VK-242)

| vankhan (`packages/vankhan_shell/ios/...`) | liquid_shell_ios (`Sources/liquid_shell_ios/`) | Changes |
|---|---|---|
| `VankhanShellPlugin.swift` | `LiquidShellPlugin.swift` (P1 file, extended) | One plugin class registers the signals channel and the shell. It removes its observers on `detachFromEngine` (P1 T3 minor) |
| `ShellInstaller.swift` | `NativeShellInstaller.swift` + `InstallPolicy.swift` | The pure `InstallPolicy.decide`. Opt-in key, Mac guard, late-registration guard, disconnect handling, ignoring other engines' scenes. `LaunchTiming` is dropped: it took the FVC's only render callback in release builds (VK-242 review M9) |
| `ShellRootController.swift` | `ShellContainerController.swift` | Also forwards edge-gesture deferral. Re-syncs Flutter's frame on its own layout while the chrome is hidden |
| `PassThroughRootView.swift` | `PassThroughView.swift` | `isBackground` is a static function, so it can be unit-tested |
| `NativeShellController.swift` | `NativeTabsController.swift` + `ShellMath.swift` | Whole-config `apply` in a fixed order. Propose-accept selection. Dormant and hidden states. Pinned trailing tab, sidebar-only tabs, badges, appearance, RTL. The math is pure and unit-tested |
| `SidebarFooterView.swift` | `SidebarFooterView.swift` | Renamed fields only |
| `shell_api.dart` (Pigeon) | `liquid_shell_ios/pigeons/native_shell.dart` | New message set (§6.2) |
| (VK-342 design) | `WindowControlsReader.swift`, `ShellMath.windowControls` | New. Ported from the approved VK-342 design, not from code |

All comments are in English, all names are new, and there are no VK or B references (P1 §9). `make provenance` stays green.

### 3.2 Lessons the design must carry

| Lesson (source) | Where it lands |
|---|---|
| **I1 dirty-guard data loss** (VK-242 review I1): landscape sidebar taps and footer taps changed branches without asking the form's `PopScope`, so a half-filled form was lost | Native taps only *propose* a selection. Dart runs the shell's single `_select` path, including `beforeDestinationChange` and reselect, then answers (§7.3). Pages pushed above the shell hide the native chrome while they cover it, so no native control is tappable beside them (§7.4). The footer is an app callback, like P1's trailing action, and its doc says to guard it (Q5) |
| **`_afterRootPages`** walk (vankhan `adaptive_shell.dart`) | Generalised into P1's `beforeDestinationChange`, which now also guards native taps. A router-specific root-pages walk stays in P5's go_router adapter |
| **Configure-then-select** ordering (VK-242 review, strengths) | Structural. One `update(config)` carries tabs, selection, footer, tint, appearance and visibility. Native applies them in a fixed order: tabs, selection, footer, style, interaction, visibility (§5.5). A selection can never land on tabs that do not exist yet. The first `update` after `attach` (start-up, hot restart) is forced |
| **Send-failure logging** (both directions) | Native → Dart: every send logs with `NSLog`, and a failed state or window-controls send forgets its dedupe value so the next layout pass re-sends it. Dart → native: `PlatformException` is caught at the iOS package boundary and logged once per method in debug. A failed `attach` reports `channelError` → Flutter chrome (§11) |
| **Scene reconnect not reinstalling** (review M1) | The scene observers stay armed for the installer's life. `didDisconnect` of our scene releases the controller. `attach` reports "not installed" for a controller whose window is gone. The next `willConnect` installs again (§5.7) |
| **"Designed for iPad" on Mac installs the shell** (review M2) | `isiOSAppOnMac \|\| isMacCatalystApp` → `iPadAppOnMac`, no install |
| **Double-chrome precedence** (review M3) | The native install is the only ground truth. Dart never parses OS versions: it engages only on `attach().installed`. When it disengages, it sends `engaged: false` in the same post-frame that it starts drawing Flutter chrome (§7.1) |
| **Diagnostics in release** (review M9) | Install timing and "not installed" logs are `#if DEBUG` |
| **Error route leaves native chrome inert** (review M5) | Ownership: when the last shell unmounts, the host sends the dormant config and the native chrome hides (§7.2) |
| **Overlay-open `PopScope`** (P1 deferred, progress.md T10) | Native mode keeps P1's rule: `canPop: false` only while the native overlay sidebar is shown, and back closes it. The README limitation (an app `PopScope` still sees `didPop: false`) is unchanged. A router-specific ordering waits for P5 |
| **iOS signals observer not removed on engine detach** (P1 T3 minor) | `detachFromEngine` removes it, and the installer's observers too |
| **SwiftPM unverified** (P1 O2) | Unchanged. P2 adds sources under the same `Sources/liquid_shell_ios`; P6 runs the SwiftPM gate |

## 4. Public API changes

All Dart names are exported from `package:liquid_shell/liquid_shell.dart` unless noted. Every change is additive (`0.1.0-dev.2`, Q12).

### 4.1 `LiquidShell`

```dart
class LiquidShell extends StatefulWidget {
  const LiquidShell({
    // … every P1 parameter, unchanged …
    this.nativeChrome = LiquidNativeChrome.auto,
    this.nativeSidebarFooter,
    super.key,
  });

  /// Whether the platform may draw the chrome (§7.1).
  final LiquidNativeChrome nativeChrome;

  /// The native sidebar's footer. The Flutter sidebar uses sidebarFooter.
  final LiquidNativeSidebarFooter? nativeSidebarFooter;
}

enum LiquidNativeChrome {
  /// Native wherever the platform offers it and the shell can describe
  /// itself natively; Flutter chrome everywhere else.
  auto,
  /// Always Flutter chrome.
  off,
}

@immutable
class LiquidNativeSidebarFooter {
  const LiquidNativeSidebarFooter({
    required this.title,          // first line, e.g. a profile name
    required this.subtitle,       // second line
    required this.sfSymbol,       // e.g. 'person.crop.circle'
    required this.semanticLabel,  // VoiceOver label of the whole footer
    required this.onPressed,      // after the native side closed an overlay sidebar
  });
  // == field by field; onPressed by identity.
}
```

### 4.2 Destinations and the trailing action

```dart
const LiquidDestination({ …, this.sfSymbol });   // String?, e.g. 'house'
const LiquidTabAction({ …, this.sfSymbol });     // String?, e.g. 'magnifyingglass'
```

Both join `==`/`hashCode`. Native chrome engages only when every destination has one, and so does the trailing action if there is one. Badges map to UIKit: count `n` → `"n"` (or `"max+"`), dot → `""`, which UIKit draws as a dot, and hidden → `nil`.

### 4.3 `LiquidShellScopeData`

```dart
const LiquidShellScopeData({
  required … ,                                   // the five P1 fields
  this.nativeChrome = false,                     // the platform draws the chrome
  this.windowControls = LiquidWindowControls.zero,
});
factory LiquidShellScopeData.none({LiquidWindowControls windowControls = LiquidWindowControls.zero});
```

`==` and `hashCode` include both new fields. `none()` keeps its P1 meaning, and window controls pass through it because they belong to the window, not the shell. `LiquidNoChrome` becomes a `StatefulWidget`, with the same const constructor, and publishes `none(windowControls: <current>)`.

### 4.4 Window controls

```dart
// Re-exported from liquid_shell_platform_interface, like LiquidPlatformSignals.
@immutable
class LiquidWindowControls {
  const LiquidWindowControls({this.leading = 0, this.top = 0});
  factory LiquidWindowControls.sanitized({required double leading, required double top}); // <0, NaN, ∞ → 0
  static const zero;
  final double leading;   // a top row must start this far from the safe-area start edge
  final double top;       // content below the cluster starts this far below the safe-area top
  bool get isZero;
  double indentFor({required double rowTop}) => rowTop < top ? leading : 0;
}

/// Start padding of indentFor(rowTop:) around a top row that is under the
/// cluster, animated over 200ms (none under reduce motion). Under means
/// rowTop < top and the row's start edge, measured after layout while the
/// enclosing route is at rest (a transition's transform would make a row
/// under the cluster look past it mid-push), is less than `leading` from
/// the WINDOW's safe-area start edge: a page beside a tiled sidebar never
/// moves, and a new row in a tiled shell counts as past the cluster from
/// its first frame. Works inside or outside a shell.
class LiquidWindowControlsClearance extends StatefulWidget {
  const LiquidWindowControlsClearance({required this.child, this.rowTop = 0, super.key});
  final double rowTop;    // the row's top edge below MediaQuery.paddingOf(context).top
}
```

Test-only: `debugResetLiquidNative()` (exported, `@visibleForTesting`) forgets the process-wide native link and window-controls source. Its pattern is the same as P1's `debugResetLiquidGlassSignals()`.

### 4.5 Platform interface (`liquid_shell_platform_interface`)

```dart
abstract class LiquidShellPlatform extends PlatformInterface {
  Stream<LiquidPlatformSignals> watchSignals();                         // P1
  bool get supportsNativeChrome => false;                                // sync: may this platform ever install native chrome?
  Future<LiquidNativeShellState> attachNativeChrome() async => LiquidNativeShellState.unavailable;
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) async {}
  Future<void> setNativeSidebarVisible({required bool visible}) async {}
  Future<LiquidWindowControls> readWindowControls() async => LiquidWindowControls.zero;
  Stream<LiquidNativeEvent> get nativeEvents => const Stream.empty();   // broadcast
}
```

Every new member has a default, so Android, web and tests are unchanged, and an implementation that `extends` keeps compiling. The value types are:

- `LiquidNativeShellState` with `installed`, `compact`, `sidebar` (`hidden` / `overlay` / `tiled`) and `unavailableReason`.
- `LiquidNativeUnavailableReason` with the values `unsupportedPlatform`, `notIPad`, `osTooOld`, `iPadAppOnMac`, `notEnabled`, `disabledByEnvironment`, `rootNotFlutter`, `registeredLate` and `channelError`.
- `LiquidNativeTab`, `LiquidNativeAction`, `LiquidNativeFooter`.
- `LiquidNativeChromeConfig`: `engaged`, `tabs`, `selectedIndex`, `trailing`, `footer`, `tintArgb`, `dark`, `rtl`, `hidden`, `interactive`, and `visible = engaged && !hidden`. It also has `dormant`.
- The sealed `LiquidNativeEvent`: `LiquidNativeDestinationTapped(index)`, `LiquidNativeTrailingTapped`, `LiquidNativeFooterTapped`, `LiquidNativeStateChanged(state)` and `LiquidWindowControlsChanged(controls)`.

### 4.6 `liquid_shell_ios`

`LiquidShellIOS extends EventChannelLiquidShellPlatform implements NativeShellFlutterApi` replaces the bare `EventChannelLiquidShellPlatform` in `registerWith()`. It keeps P1's signals unchanged, implements the members in §4.5 over Pigeon, and maps the types at the boundary. It exports `NativeTapTarget` and a `@visibleForTesting debugTap(target, [index])` for integration tests. It touches no channel in its constructor, because `registerWith` runs before `main`, when no binding exists yet.

Native, in `Info.plist`:

```xml
<key>LiquidShellNativeChrome</key>   <!-- opt-in, Q2 -->
<true/>
```

To keep the Flutter chrome for one diagnostic launch, set the environment variable `LIQUID_SHELL_NATIVE_OFF=1`. It is not a feature.

## 5. Native architecture (`liquid_shell_ios`)

### 5.1 Install rule

The plugin's `register(with:)` arms a `UIScene.willConnectNotification` observer, with `queue: nil`. This is the same timing as VK-242: the storyboard creates the `FlutterViewController`, the implicit engine registers the plugins, and only then does the notification fire. In the observer, synchronously (an async install leaves the splash screen up for good, as the VK-242 spike found), `InstallPolicy.decide` checks these facts in order. The first one that fails names the reason:

| # | Fact | Reason when false |
|---|---|---|
| 1 | `UIDevice.current.userInterfaceIdiom == .pad` | `notIPad` |
| 2 | `#available(iOS 26.0, *)` | `osTooOld` |
| 3 | not `isiOSAppOnMac` / `isMacCatalystApp` | `iPadAppOnMac` |
| 4 | `Info.plist` `LiquidShellNativeChrome == true` (Q2) | `notEnabled` |
| 5 | env `LIQUID_SHELL_NATIVE_OFF != "1"` | `disabledByEnvironment` |
| 6 | the plugin registered before any Flutter view of this app was in a window | `registeredLate` |
| 7 | the scene window's root is a `FlutterViewController` of this engine: its engine published this plugin instance (`LiquidShellPlugin.owns`, `valuePublished(byPlugin:)`). `registrar.viewController` cannot decide it: it is still nil at `willConnect` (measured on iOS 26.5) | `rootNotFlutter` |

The install step detaches the FVC from the root role, then sets `window.rootViewController = ShellContainerController(tabs:flutter:)`. Doing it in this order avoids `UIViewControllerHierarchyInconsistency`. A scene whose root FVC belongs to another engine is ignored, so a second engine that registers the plugin (headless background work, add-to-app) never claims the app's scene; a simulator probe with a headless engine registered before the scene confirmed it. For fact 6, a Flutter view inside an installed `ShellContainerController` counts as on screen, like one that is the root.

**The width rule.** "Install" puts the container in the window on every qualifying iPad. That is the only time it can happen. Whether the native chrome is *used* is decided on every frame by Dart (§7.1). It needs the platform's horizontal size class to be regular **and** the shell's own width to be at least `breakpoints.regular`. Below either, the container is **dormant**: the tab bar controller's view is hidden, the Flutter view fills the window with no added safe area, and every touch falls through. P1's Flutter chrome draws as on any other device (Q3).

### 5.2 Approach C (unchanged from ADR 0012)

```
UIWindow
└─ ShellContainerController (root; view = PassThroughView)
   ├─ FlutterViewController   ← child 1: view at the bottom, never reparented, never leaves the window
   └─ NativeTabsController : UITabBarController(.tabSidebar), clear background ← child 2, covers all
      ├─ UITab(.pinned) "trailing"  → TabHostController (empty, clear)   [only with a trailing action]
      ├─ UITab(.fixed | .sidebarOnly) × destinations → TabHostController
      └─ sidebar.bottomBarView = SidebarFooterView                         [only with a footer]
```

The Flutter view never moves, so switching tabs never sends `inactive`/`hidden`/`paused` to Flutter. Approaches A and B of the VK-242 spike froze frames for exactly that reason. Status bar, home indicator, edge gestures and supported orientations are forwarded to the FVC.

### 5.3 Hit testing

`PassThroughView.hitTest` asks the tab bar controller's view first. Some results count as background, and the touch then goes to `flutterView.hitTest`, where platform views inside Flutter are found as usual:

- `nil` (chrome hidden, `isUserInteractionEnabled == false`, or alpha 0);
- the tab bar controller's own view;
- the selected host view or any of its ancestors up to that view.

Anything else, such as the tab bar, the sidebar, the overlay's dimming view or the footer, stays with UIKit. This hit test is **tracked debt** (ADR 0012): it relies on the public but unspecified view tree, so `make integration-ios-native` runs on every Xcode/iOS bump (§12).

### 5.4 Frame and safe-area copy

On every host layout, safe-area change, appearance, sidebar-transition completion, trait change and container layout, `syncFlutter()` does the following:

- **Chrome visible.** The Flutter view's frame is the selected host's frame. The host's safe area that Flutter lacks goes into `flutter.additionalSafeAreaInsets` (`ShellMath.additionalInsets`), and it is assigned only on change. The result: the native tab bar row (portrait and landscape: 24 status + 72 = **96pt** top, measured in the dry run) is Flutter's `MediaQuery.padding.top`, and a tiled sidebar is Flutter's start padding.
- **Portrait overlay.** UIKit hides the tab bar when the sidebar opens, and the host's top drops. `heldTop` keeps the closed value, so Flutter sees no metrics change and nothing under the dimming view jumps (VK-242 spike bug).
- **Chrome hidden or dormant.** The Flutter view fills the container, with zero added insets.

After each sync, the native side publishes `NativeShellState` (dedupe; a failed send forgets the value) and the window controls (§8.1).

### 5.5 Applying a config

`update(config)` → `NativeTabsController.apply`, always in this order:

1. **Tabs.** Rebuild only when the structure changes. The structure is the list of `sidebarOnly` flags plus "has trailing". A rebuild uses `setTabs` under `applyingFromDart`. Destinations become `UITab`s with `.fixed` (or `.sidebarOnly`), so there is no sidebar "Edit". The trailing action becomes a `UITab` with `.pinned` at index 0, so it is the trailing end of the tab bar and the first sidebar row. Titles, SF Symbol images and badges are updated on every apply.
2. **Selection.** `selectedTab = destinationTabs[selectedIndex]` under `applyingFromDart`, when it differs.
3. **Footer.** `sidebar.bottomBarView` = footer view, or `nil`.
4. **Style.** `view.tintColor` = `tintArgb` (the shell sends `colorScheme.primary`). `traitOverrides.userInterfaceStyle` follows the app's theme brightness, not the device's (VK-250 lesson). `traitOverrides.layoutDirection` follows the shell's `Directionality`.
5. **Interaction.** `view.isUserInteractionEnabled = interactive`, `view.accessibilityElementsHidden = !interactive` and the footer's own `interactive` flag: under a Flutter dialog (Q8) the chrome is inert for touch and for VoiceOver alike, and VoiceOver cannot activate the footer. A non-interactive config also closes an overlay sidebar: the dialog is drawn in the Flutter view, below the sidebar and its dimming view (final review I1).
6. **Visibility.** `visible = engaged && !hidden`. Hiding closes an overlay sidebar, because it is transient. A tiled sidebar keeps its state for when the chrome returns. Showing fades in over 0.2 s, and does not fade under Reduce Motion. The view starts hidden: before the first `update` nothing native is visible, so the splash screen never shows an empty tab bar.

### 5.6 Selection: propose, then accept

`tabBarController(_:shouldSelectTab:)` returns **false** for every destination tab and sends `onDestinationTapped(index)`. Dart runs the guard and selects (§7.3), then answers with an `update` whose `selectedIndex` UIKit applies. For the trailing tab it closes an overlay sidebar, sends `onTrailingTapped`, and returns false. `didSelectTab` is a safety net for selections that UIKit makes without asking, such as a keyboard shortcut. Outside `applyingFromDart` it reports the index the same way, and Dart's answer re-syncs the selection.

This differs from VK-242, which let UIKit select and resynced only on refusal (Q4). The native selection never shows a tab that the guard has not accepted, and a refused tap leaves the sidebar row on the current tab. The dry run confirmed the round trip through `debugTap` on the iPad simulator. Task 1 also checks the visual result of a refused row tap by hand (§12).

### 5.7 Lifecycle

| Event | Behaviour |
|---|---|
| Scene connects, rule passes | Install synchronously (§5.1); the chrome stays hidden until the first `update` |
| Scene connects, rule fails | No install; the reason is kept for `attach` and logged in debug |
| Plugin registered after the scene connected | `registeredLate`; never installs into a visible window |
| Scene disconnects (ours) | Release the controller and the FVC reference; observers stay armed; `attach` reports not installed. The installer keeps Dart's last config, including any `update` that arrives while nothing is installed |
| Scene reconnects | The armed observer installs again in the new window (if the rule passes), and the installer applies Dart's last config to the fresh controller at once, so a surviving engine gets its chrome back before any Dart round trip (XCTest `testAReinstallAfterASceneReconnectAppliesTheLastConfig`). Dart also answers every state report, including the fresh controller's first, by forgetting its dedupe value and sending the owner's config whole, with `force` (tabs, then the selection, in one apply); the two agree, and the second apply is idempotent. On the iOS 26.5 simulator a destroyed and reconnected scene of the example (storyboard + `FlutterSceneDelegate`) came back with a new view controller and implicit engine, so a new installer and a new Dart attach; the native chrome was back |
| Dart hot restart | The native chrome survives. Dart's new host calls `attach`, and the first config is sent with `force` (configure-then-select, §3.2) |
| Engine detach | The installer's observers and the Pigeon handlers are removed; the P1 signals observer is removed |
| Last shell unmounts | Dart sends `dormant`; the container hides its chrome and gives Flutter the whole window |

### 5.8 Swift tests (where feasible)

The pure parts have no UIKit dependency and are unit-tested with XCTest in the example's `RunnerTests` target (`@testable import liquid_shell_ios`, `make ios-unit`): `ShellMath` (window controls including the rounded-corner rule, additional insets, tiled detection, half-point change) and `InstallPolicy` (every reason, in order). The hit-test background rule is tested on plain `UIView` trees. The UIKit parts (`apply`, delegate callbacks, safe-area copy) are covered by the integration test on a simulator (§9.4). The dry run proved this XCTest route works on Xcode 27 with CocoaPods (12/12 passed).

## 6. The channel

### 6.1 Pigeon, not another hand-written channel (Q1)

P1 used one `EventChannel` with no Pigeon, because its only job was one stream of three booleans. P2 is different. It has five host calls and five native events. It carries nested data (a list of tabs, an optional footer and action, an enum state) in both directions. It has two Swift entry points that a typo would silently disconnect, which is vankhan B59's failure. Pigeon generates both ends from one source file, and `make pigeon-check` fails when they drift. vankhan's VK-242 already used Pigeon for the same surface, so the ported Swift keeps its shape.

What it costs, and how the cost is contained:

- **`pigeon: 27.3.0` dev dependency of `liquid_shell_ios` only.** Pinned exactly: the generated header embeds the version. 27.3.0 is the newest version whose analyzer (`<13`) resolves beside the workspace's `test` on the Flutter 3.44 SDK pins. 29.x needs analyzer 13, and the dry run's `pub get` failed with it.
- **`meta: ^1.10.0` runtime dependency of `liquid_shell_ios`.** The generated Dart imports it, as every flutter/packages plugin that uses Pigeon does. The Flutter SDK pins it (1.18.0 on 3.44.6), so no new code reaches an app. The repo rule "Flutter + our packages + `plugin_platform_interface`" gains this one exception (Q1).
- **Generated code excluded from the coverage gate.** `tool/check_coverage.dart` ignores `*.g.dart` records. The generated Dart carries `// ignore_for_file: type=lint`, so no analyzer exclude is needed and no rule is loosened.
- **P1's signals channel is unchanged.** The two channels live side by side: the EventChannel is still shared with Android in the interface package, and Pigeon is iOS-only in `liquid_shell_ios`.

### 6.2 Messages (`liquid_shell_ios/pigeons/native_shell.dart`)

| Direction | Message | Payload / result |
|---|---|---|
| Dart → native | `attach()` | `NativeShellState { installed, compact, sidebar: hidden\|overlay\|tiled, unavailableReason? }` |
| Dart → native | `update(NativeChromeConfig)` | `{ engaged, tabs: [NativeTab{title, sfSymbol, badge?, sidebarOnly}], selectedIndex, trailing?: NativeAction{title, sfSymbol}, footer?: NativeFooter{title, subtitle, sfSymbol, semanticLabel}, tintArgb, dark, rtl, hidden, interactive }` |
| Dart → native | `setSidebarVisible(bool)` | ignored when hidden, dormant or compact |
| Dart → native | `windowControls()` | `NativeWindowControls { leading, top }` (works without an install) |
| Dart → native | `debugTap(NativeTapTarget, int)` | debug builds run the tap path; release builds ignore it |
| native → Dart | `onDestinationTapped(int)` | proposal (§5.6) |
| native → Dart | `onTrailingTapped()`, `onFooterTapped()` | — |
| native → Dart | `onStateChanged(NativeShellState)` | end value after layout and transitions |
| native → Dart | `onWindowControlsChanged(NativeWindowControls)` | only on a change of ≥ 0.5pt |

Boundary checks (CLAUDE.md, P1 §7): Dart drops a destination index outside `0..destinations.length-1`, and sanitises window controls (negative, NaN, ∞ → 0) in `LiquidShellIOS` and again in `ShellMath`.

## 7. Dart behaviour (`liquid_shell`)

### 7.1 Engagement

`nativeChromeEngaged(...)` is a pure function, tested over every input:

```
engaged = nativeChrome == auto
       && this shell owns the window's native chrome (§7.2)
       && state != null && state.installed
       && !state.compact                         // UIKit size class
       && presentationFor(size) != compact       // the shell's own width ≥ breakpoints.regular
       && chromeBuilder == null                  // Q6
       && every destination (and the trailing action) has an sfSymbol   // Q7
```

When the shell is engaged, its build keeps P1's body chain exactly: `PopScope → ShellScopeMarker → BackdropGroup → Stack → [PositionedDirectional → MediaQuery → KeyedSubtree(GlobalObjectKey) → NotificationListener → body]`. It adds no chrome children. Switching between native and Flutter chrome therefore never moves the body (§5.6 of P1), and the widget test proves that a counter survives native → Flutter → native. The engaged layout:

| Native state | `chromeKind` | `chromeInsets` | Body |
|---|---|---|---|
| sidebar hidden | `topBar` | `top = MediaQuery.padding.top` (the native row is in the safe area) | full frame |
| sidebar overlay | `sidebarOverlay` | `top = padding.top` (held, §5.4) | full frame |
| sidebar tiled | `sidebarTiled` | zero | starts at the start padding (the sidebar's width), which is removed from its `MediaQuery`; width reduced to match |
| any `LiquidHideChrome` | `hidden` | zero | full frame |

`sizeClass` is `regular`, `sidebarVisible` mirrors the native state, and `nativeChrome` is `true`. `LiquidShellScope.contentPaddingOf` keeps working unchanged: chrome insets and system padding are combined per side with `max`.

**Pending.** On iOS, `supportsNativeChrome` is true, and for a frame or two before `attach` answers the shell does not know which chrome to draw. If every condition Dart knows without the platform holds (`auto`, owner, shell width ≥ `breakpoints.regular`, no `chromeBuilder`, every `sfSymbol`: `nativeChromePossible`; and a screen whose short side is at least 744pt, the iPad mini's: `nativeChromeScreenPossible` on `View.display`, which the iOS embedder fills before the first frame), it draws **no** chrome (`hidden`, `sizeClass: regular`), rather than flash the Flutter chrome before the native one appears. Otherwise the answer is already Flutter chrome, and the shell draws it from its first frame with its real size class: every iPhone, in portrait and in landscape (every iPhone screen is under 500pt on its short side), and every app without `sfSymbol`s or with a `chromeBuilder` (P1 apps). Whether the app opted in (Info.plist) is known only natively, so an iPad app with every `sfSymbol` but no opt-in still waits one frame or two. On every other platform the answer is synchronous (`unavailable`), so P1 behaviour is untouched: all 242 P1 widget tests pass unchanged.

**Not engaged but owner.** The shell still sends its config with `engaged: false`, so the platform hides its chrome while the shell draws the Flutter one (compact width, missing symbols). This is the double-chrome guard.

A debug log fires once per process when the device supports native chrome but the app has not opted in (`notEnabled`), and once per process when native chrome is installed but a symbol is missing on a shell that asked for it (`auto`, no `chromeBuilder`).

### 7.2 Ownership

A window has one native chrome, and an app can have several shells. In the example every case pushes its own shell. A process-wide `NativeChromeHost`:

- calls `attach` once and listens to `nativeEvents`;
- keeps a stack of claims. Each `LiquidShell` in `auto` claims on `initState` and releases on `dispose`, or when it switches to `off`. **The newest claim owns** the native chrome, and only its config is sent, deduplicated by `==`. When the owner releases, the previous claim's last config is sent. With no claim left, `LiquidNativeChromeConfig.dormant` is sent;
- routes tap events to the owner only (a shell that is not the owner, but would otherwise engage, draws no chrome: no Flutter chrome beside the owner's native one while its route slides in or out);
- sends nothing while the state is not installed.

**Nested shells.** A shell inside another shell's body (sub-tabs) claims after the outer one, so it owns the native chrome, and the outer shell goes into standby: while the inner shell is mounted, the outer shell's navigation is gone (and with the inner shell in an offstage branch, no chrome shows at all). This is documented, not solved: the dartdoc of `nativeChrome` and the README Limitations tell apps to give a nested shell `nativeChrome: off`. Handing ownership to the newest claim whose `TickerMode` is enabled would fix only the offstage case; it is an owner decision for a later phase.

`debugResetLiquidNative()` replaces the host and the window-controls source between tests.

### 7.3 Selection and the guard

Native destination taps (index range-checked) call the shell's one `_select(i)` path from P1 §5.5:

- **single flight:** a tap while a guard is pending is dropped;
- **guard:** `beforeDestinationChange(i)` runs, and a throw is reported and treated as a refusal. While it runs, the config is `interactive: false`, so an overlay sidebar closes natively (§5.5 step 5) before the guard's dialog shows;
- **accepted:** `onDestinationSelected(i)` runs. If the native sidebar is an overlay, the shell then asks the platform to close it. The app's new `selectedIndex` reaches the platform in the next config;
- **after every native destination tap**, whatever came of it (accepted, refused, dropped by single flight or because the destination vanished while the guard ran, or accepted but ignored by the app): the next frame's config is sent with `force`, even when it equals the last one. With propose-accept nothing changed natively, but the `didSelectTab` safety-net path may have changed it, and the forced send puts it back;
- **reselect** (`i == selectedIndex`) runs the same path, so apps pop the branch to its root;
- **trailing** → `tabBarTrailing.onPressed`; **footer** → `nativeSidebarFooter.onPressed`. Neither runs the guard (Q5).

`LiquidShellScopeData.setSidebarVisible` goes to the platform while the shell is engaged. It applies after the frame when called during a build, as in P1 I3.

### 7.4 Routes above the shell

The shell reads its own `ModalRoute`:

| Situation | Signal | Native config |
|---|---|---|
| A page route pushed above the shell (opaque, a `PageRoute`) | the shell route's `secondaryAnimation` is `forward` or `completed` | `hidden: true` from the first frame of the push. `hidden: false` when the pop starts (`reverse`) or after it |
| An opaque route that does not drive `secondaryAnimation`: a `fullscreenDialog` page, a `PageRouteBuilder`, a router's custom-transition or no-transition page (`canTransitionTo` is false for them) | the shell's `TickerMode` is off: the Overlay turns it off for entries below a settled opaque route, as for P1's `LiquidHideChrome` | `hidden: true` once the push settles (the chrome stays visible, non-interactive, during the push animation). `hidden: false` when the pop starts: the route is no longer opaque while it animates |
| A dialog, popup or sheet above the shell (not a `PageRoute`: it does not drive `secondaryAnimation`) | `!ModalRoute.isCurrent` | `interactive: false`. Touches on the chrome area fall through to Flutter's barrier |
| Nothing above | — | `hidden` as hide-chrome requests say; `interactive: true` |

This is router-agnostic, because go_router's pages are `PageRoute`s too, and it closes VK-242's I1 structurally (Q8). A root page cannot sit beside a tappable native sidebar, because the native chrome is gone while the page covers the shell. While hidden, Flutter has the whole window. A page above therefore sees the true safe area: in the dry run, the pushed page's top padding dropped below the shell's 96pt. Modals inside a branch's own navigator do not make the shell's route non-current. Apps show them on the root navigator (the default for `showDialog`), or wrap the page in `LiquidHideChrome`. The README says so.

### 7.5 Things that stay Flutter-only

`sidebarHeader` and `sidebarFooter` (widgets), `chromeBuilder`, `minimizeOnScroll` (compact only, so never native), `LiquidShellStrings` for the toggle and the barrier (UIKit draws its own, in the device language: §12).

## 8. Window controls (VK-342, window part)

### 8.1 Reading

`WindowControlsReader.read(view)` (iOS 26+; zero before) computes

```
leading = max(0, directionalEdgeInsets(for: .safeArea(cornerAdaptation: .horizontal)).leading − safeArea.leading)
top     = max(0, directionalEdgeInsets(for: .safeArea(cornerAdaptation: .vertical)).top − safeArea.top)
```

on the Flutter view, using the leading side for its layout direction. **While the native chrome is visible the value is `{0, 0}` without a read** (final review I4): UIKit's bar and sidebar make room for the cluster, as its navigation bar does, and Flutter content starts below the bar row or beside the sidebar. A read there would be wrong: Flutter's safe top is the bar row (96), below the cluster (75), so the vertical delta is 0, and a 66pt leading delta alone would hit the fallback below and indent every title. Dart agrees on its side: an engaged shell's scope and every `LiquidWindowControlsClearance` inside it use zero. Rules in `ShellMath.windowControls`, which therefore applies to the Flutter-chrome path only (no shell installed, chrome hidden under a page, or dormant):

- a non-finite or negative value becomes 0;
- **rounded corner, not a cluster:** when `top` reads 0 and `leading < 24` → `{0, 0}`. The dry run measured **leading 9.5, top 0** on a *full-screen* iPad Air 11" (M4), iOS 26.5, with and without native chrome: the display's rounded corner, not window controls. VK-342's pass bar for full screen is `{0, 0}`;
- **missing vertical adaptation:** `top` reads 0 and `leading ≥ 24` → `top = 44` (`fallbackClusterTop`). This is VK-342 Q-mở 4's fallback; Task 1 measures the real cluster and confirms or replaces both constants (Q10).

Values reach Dart three ways:

- **Pushed.** Native chrome pushes `onWindowControlsChanged` after every `syncFlutter`, and once more on the next run-loop turn, because the region can lag one layout pass. Only a change of ≥ 0.5pt is sent.
- **Read.** Dart reads `windowControls()` once on start and after every `didChangeMetrics` (post-frame). This is the only route when native chrome is not installed, and it still works then, because the installer keeps a weak FVC reference, or falls back to `registrar.viewController` (VK-342 Q-mở 1).
- **Elsewhere zero.** On iPhone, Android, iPadOS before 26 and in tests the value is zero.

### 8.2 Dart source

`WindowControlsSource` is internal and process-wide, like P1's signals controller. It is reference-counted: the first `acquire` subscribes to `nativeEvents`, adds a `WidgetsBindingObserver` and reads once, and the last `release` stops it. It never subscribes when `supportsNativeChrome` is false. `LiquidShell`, `LiquidNoChrome` and `LiquidWindowControlsClearance` acquire it.

### 8.3 Where it applies in P2

| Place | Rule |
|---|---|
| P1 top bar row (`topBar`, `sidebarOverlay` underlay) | `indent = controls.indentFor(rowTop: kTopBarGap)`. The toggle moves to `start: 20 + indent`, and the pill's horizontal reserve grows by `indent` **on both sides**, so it stays centred (VK-342 §3.5 (c)) |
| Flutter sidebar header row (`LiquidSidebar`, also standalone) | Wrapped in `LiquidWindowControlsClearance(rowTop: 24)` (24 = the sidebar's top padding) |
| P1 bottom bar | Unaffected: it is at the bottom |
| Page large titles | Apps wrap the title row in `LiquidWindowControlsClearance(rowTop: contentPaddingOf(context).top − paddingOf(context).top)`. The example's `DemoPage` does, so every case shows it. Rows below the band never move (Music's look), and neither do rows that start past the cluster horizontally: beside a tiled sidebar (Flutter or native) the page starts at the sidebar's edge, so its title stays put. The check uses the row's position in the window, not in the page, read only while the page's route is at rest (no push, pop or route above it moving), so a title does not slide during a transition. Until it is first read, a row counts as under the cluster, except in a shell with a tiled sidebar |
| Native chrome | UIKit adapts its own bar and sidebar; the value is published as 0 while the native chrome is visible (§8.1), and an engaged shell's scope and clearance widgets use 0 |
| P3 (later) | The back button / title bar and the search page read `LiquidShellScope.of(context).windowControls` or use the clearance widget. Nothing else is needed from P2 |

When there is no cluster, every P1 position is unchanged; widget tests pin this for the toggle, the pill and the sidebar header.

## 9. Testing

TDD per task (red → green → commit), a review per task, and a review of the whole branch at the end, as in P1.

### 9.1 Dart unit (`liquid_shell/test/unit`, interface `test/`, `liquid_shell_ios/test`, `tool/test`)

- Interface: `LiquidWindowControls` (`sanitized`, `indentFor` at 0/16/24 with `{78, 24}`, `==`); every native value class's `==` over each field; `LiquidNativeChromeConfig.visible`; the default platform's members touch no channel; `implements` is still rejected.
- `native_layout`: `nativeChromeEngaged` true case and each false case; `nativeDescribable`; `nativeBadgeText` (null, 0, 7, 120 → `99+`, max 9 → `9+`, dot → `''`); `nativeChromeKind`; `nativeChromeInsets` for every kind; `nativeConfigFor` for every field.
- `LiquidShellIOS`: `registerWith`; `attach` mapping, including every reason and sidebar name; `channelError` on failure; `update` carries every field; failed sends swallowed; `readWindowControls` sanitises, and reads zero on failure; native calls through the real Pigeon channel names arrive as events.
- `check_coverage`: `*.g.dart` is excluded.

### 9.2 Widget (`liquid_shell/test/widget/native_chrome_test.dart`, `window_controls_test.dart`, with `FakeNativePlatform`)

- **Engagement:** native only (no `LiquidTabBar`/`LiquidSidebar`/Flutter barrier; the exact tabs, badges and selection sent); compact width → Flutter bottom bar + `engaged: false`; platform compact → Flutter; missing symbol (destination or trailing) → Flutter; `chromeBuilder` → Flutter; `off` → no claim, nothing sent; not installed → nothing sent; pending → no chrome, then native; state flip compact ↔ regular keeps body state.
- **Layout:** tiled (body at x = 300, width − 300, padding 0); overlay + system back → `setNativeSidebarVisible(false)`; scope setter → platform; `LiquidHideChrome` → `hidden`.
- **Selection:** guard + select + overlay close; refusal → forced re-send; reselect; out-of-range dropped; trailing and footer callbacks; footer data sent.
- **Routes:** page push hides it from the first animation frame and shows it again from the first pop frame; a dialog → `interactive: false` then true; a second shell owns and hands back; the last shell leaving → `dormant`.
- **Window controls:** no support → 0; a row in the band → 66; below the band → 0; pushed values animate, reduce motion → `Padding`; a metrics change re-reads; scope and `LiquidNoChrome` publish; the top bar toggle at 20 + 66 with the pill centred; sidebar header at 16 + 66; no cluster → P1 positions.

### 9.3 Swift (XCTest, `make ios-unit`)

`ShellMathTests` (7), `InstallPolicyTests` (3), `PassThroughTests` (1) and the rounded-corner case (1). They run in the example's `RunnerTests` with `-parallel-testing-enabled NO`, so Xcode does not clone the simulator. Later tasks added the UIKit shell in a window of the test host (`NativeTabsTests`: overlay closing, inert chrome under a dialog, attach and the reconnect replay), the installer's reasons (`InstallerReasonTests`) and real engines (`InstallerEngineTests`: only the plugin an engine published owns its view controller; a headless engine's installer leaves another engine's scene alone; a Flutter view inside the container is on screen). The overlay tests give their window an explicit portrait frame: a simulator keeps its last orientation, and iPadOS 26 refuses to rotate it from a unit test (`requestGeometryUpdate` is refused in the current windowing mode, `XCUIDevice` is for UI tests only). CI runs them in the `ios-unit` job (§9.6).

### 9.4 Integration (`liquid_shell/example/integration_test/native_shell_test.dart`, `make integration-ios-native`)

On an **iPad Air 11-inch (M4), iOS 26.5** with `EXPECT_NATIVE=true` it checks:

- the install state;
- native chrome, not both chromes, and a lifecycle that never paused;
- full screen → zero window controls;
- the tab bar row in the top safe area (> 40pt);
- `debugTap` destination → Inbox selected; trailing → callback;
- the sidebar opens from Dart and reports back; footer → callback;
- a page above hides the chrome (its top padding drops), and the chrome returns after the pop.

On an **iPhone 17 Pro** with `EXPECT_NATIVE=false` it checks `notIPad` and the Flutter chrome. P1's `signals_test.dart` now pumps a shell with `nativeChrome: off`, because the example opts in. A `.ignore()`/`unawaited` push style follows VK-388's analyzer fix.

**Manual (owner / Task 1 and Task 6 QA, with screenshots in `docs/qa/p2/`):**

- a floating window (cluster values, the top row and the title clear the `•••`);
- a portrait overlay (content does not jump);
- landscape tiled (the content narrows);
- refused-guard row taps (the highlight stays put);
- VoiceOver on the tab bar, the sidebar and the footer;
- Split View ⅓ (Flutter bottom bar, **one** bar);
- iOS 27.0 runtime;
- hot restart.

The dry run could not make a floating window headlessly: `SBChamoisWindowingEnabled` plus a reboot left the app full screen.

### 9.5 Images

Native chrome cannot be drawn by `flutter test`, so it has no goldens. The integration run's `takeScreenshot` captures the window **including** the native chrome. The dry run's `native_*_home.png` showed the native pill `[⊟ | Home | Inbox ③ | Settings | ⌕]`, and `native_*_sidebar.png` showed the sidebar with Search, the four rows and the "Ann Lee" footer. `tool/integration_ios_native.sh` writes them to `example/build/integration_screenshots/`. Task 6 copies the iPad portrait home, the sidebar and one landscape-tiled shot into `liquid_shell/doc/images/native_*.png`, after `tool/compress_pngs.dart`. They are documented as simulator captures, and regenerated by hand with the script, never edited by hand. P1's 26 goldens are unchanged and pass on 3.44.6.

### 9.6 CI

These jobs are added to `.github/workflows/ci.yaml`:

- `checks` gains `make pigeon-check`.
- `ios-unit` (macos-latest): the newest iPad simulator, `make ios-unit`.
- `integration-ios-native` (macos-latest, 3.44.x): `IOS_RUNTIME=""` with `NATIVE_DEVICES` set to the first iPad with iOS ≥ 26 =true and the first iPhone =false. It has `tool/with_timeout.sh` and a job timeout, as in P1's iOS job. It is non-blocking on stable.

## 10. Example and documentation

- **Case `lib/cases/native_chrome.dart` (`NativeChromeCase`):**
  - 4 destinations with symbols (one `sidebarOnly`, one with a count badge);
  - a trailing search action that counts taps;
  - a native footer that jumps to Settings;
  - one `// #docregion readme`.
  - It is in `kCases` and in `cases_smoke_test` (phone and tablet).
- **`DemoPage`:** the title row is wrapped in `LiquidWindowControlsClearance`.
- **`example/ios/Runner/Info.plist`:** `LiquidShellNativeChrome = true`.
- **README:**
  - features: native chrome, window controls, the dependency note;
  - the platform table;
  - new sections "Native iPadOS chrome" (opt-in, the snippet, behaviour list, simulator images) and "Window controls" (scope value, clearance snippet);
  - Limitations: native is iPad-only and opt-in; system strings follow the device language; the hit test follows UIKit's view tree;
  - the roadmap.
- **New `doc/native_chrome.md`:** install rules table (§5.1), lifecycle (§5.7), routes above the shell (§7.4), ownership (§7.2), troubleshooting by `unavailableReason`, and the third-party-plugin caveat (§12).
- **`doc/router_integration.md`:** native mode with `IndexedStack` and go_router by hand. Modals must go on the root navigator.
- **CHANGELOGs:** all four packages get `0.1.0-dev.2` (Q12).
- **`CLAUDE.md` / `CONTRIBUTING.md`:**
  - the dependency rule names `meta` (Pigeon output) and `pigeon` (dev);
  - commands `make pigeon`, `make pigeon-check`, `make ios-unit`, `make integration-ios-native`.

## 11. Error handling

| Case | Debug | Release |
|---|---|---|
| Not iPad / iPadOS < 26 / Mac / not opted in / env off / late / root not FVC | native: `NSLog` reason; Dart: one log for `notEnabled` | Flutter chrome; window controls still read where possible |
| `attach` throws (`PlatformException`) | `debugPrint` once | `channelError` → Flutter chrome |
| `update` / `setSidebarVisible` / `windowControls` throws | `debugPrint` once per method | ignored; window controls zero |
| Native → Dart send fails | `NSLog` | dedupe value cleared, re-sent on the next sync |
| Destination index out of range from native | — | dropped |
| Window controls negative / NaN / ∞ | — | 0 (both sides) |
| A destination or the trailing action has no `sfSymbol` | `debugPrint` once | Flutter chrome, `engaged: false` sent |
| `chromeBuilder` set | — | Flutter chrome |
| Guard throws on a native tap | `FlutterError.reportError` (P1) | refused, current selection re-sent |
| Shell unmounted while the guard runs | — | result dropped (P1) |
| Last shell gone (error route, case list) | — | `dormant` sent, the chrome hides |
| Scene disconnected | — | not installed until a reconnect installs again |
| Multiple scenes | — | the first connected scene's window only; others keep Flutter chrome |
| `debugTap` in release | — | ignored |

## 12. Risks

| Risk | Mitigation |
|---|---|
| **Hit-test debt.** The pass-through depends on the `UITabBarController` view tree; a new iOS can route touches wrongly | Tracked in `doc/native_chrome.md` and the README; `make integration-ios-native` on every Xcode/iOS bump; CI job; a manual 27.0 run in Task 6; `LIQUID_SHELL_NATIVE_OFF=1` diagnosis |
| **Third-party plugins that cast `window.rootViewController` to `FlutterViewController`** break under the container | Opt-in only (Q2); listed in `doc/native_chrome.md` with the workaround (`nativeChrome: off` and no plist key) |
| **Floating-window values unmeasured.** The simulator could not be windowed headlessly; the 24pt corner threshold and 44pt fallback come from one full-screen measurement and VK-342's research | Task 1 spike by hand on the simulator (pass bars in the plan); constants in one place (`ShellMath`), XCTest-pinned; stop and ask the owner if the bars fail (VK-342 §3.11) |
| **Propose-accept visuals.** A denied `shouldSelectTab` may flash a row highlight | Task 1 checks it; fallback: allow and re-sync (VK-242 model, Q4 B) behind the same Dart path |
| **Covered/uncovered beat.** Hiding the chrome changes Flutter's safe area; the shell below re-lays out, and the exiting page may shift one beat at pop start | Accepted (VK-242 Q16 had the same beat); show on `reverse` so the revealed shell is right; owner checks in Task 6 |
| **Landscape sidebar animation.** UIKit animates; Flutter gets metrics step by step | Accepted as in ADR 0012; owner checks on device |
| **System strings in the device language** (the sidebar button's VoiceOver label) | Documented (ADR 0012 consequence) |
| **Pigeon pin.** 27.3.0 is tied to the analyzer that the 3.44 SDK's `test` allows | Exact pin plus `pigeon-check`; bump with the next floor raise |
| **`meta` runtime dependency** | SDK-pinned; same as flutter/packages; Q1 |
| **Pending frames.** No chrome for one or two frames at start on iOS | Only while `attach` is in flight, only on an iPad screen, and only for a shell that could use native chrome (§7.1); the native chrome fades in over 0.2 s. An iPad app with every `sfSymbol` but no Info.plist opt-in still waits (README Limitations) |
| **Universal simulator build fails.** `flutter build ios --simulator` failed on Xcode 27 (Flutter.framework lipo arch check) | Scripts build per device (`flutter drive -d`, `xcodebuild -destination id=`); `ios-unit` uses `--config-only` |
| **Scene lifecycle under the container root** (Flutter auto-registers scene events when the FVC is the root) | Single scene: the Flutter header says that registration also happens once the FVC's view is in the hierarchy; the integration test checks the engine never pauses |

## 13. Owner decisions

> **Owner approved every recommended default, Q1–Q13 (2026-10-09: "Duyệt").**

Each row has a recommended default; silence means the default.

| Q | Question | Recommended default |
|---|---|---|
| Q1 | Channel for the native shell: Pigeon or the P1 hand-written channel pattern? | **Pigeon 27.3.0**, iOS package only: five host calls, five events and nested types in both directions, generated both ends, with a drift gate. Costs a dev dependency and the SDK-pinned `meta` runtime dependency; the CLAUDE.md dependency rule names it. P1's signals EventChannel is unchanged |
| Q2 | Install by default on every qualifying iPad, or opt-in? | **Opt-in** with `LiquidShellNativeChrome = true` in Info.plist. A public package must not swap every iPad app's root view controller just because it depends on liquid_shell; plugins that cast the root to `FlutterViewController` would break. Debug log when the device supports it but the key is missing |
| Q3 | iPad at compact width (Split View, small window): UIKit's own bottom tab bar, or P1's Flutter bottom bar? | **P1's Flutter bottom bar** (container dormant), as decomposed: one look for every compact layout. Native needs both UIKit-regular and shell width ≥ `breakpoints.regular` |
| Q4 | Selection model for native taps | **Propose, then accept.** Native never selects until Dart's guard accepts; `didSelectTab` is the safety net. Fallback if Task 1 sees a glitch: let UIKit select and re-sync on refusal (VK-242 model) |
| Q5 | Should a native footer tap run `beforeDestinationChange`? | **No.** It is an app callback, like P1's trailing action and Flutter `sidebarFooter`; the dartdoc says to guard it. The guard's signature is per destination index |
| Q6 | Engage native chrome when the app passes `chromeBuilder`? | **No.** The app asked for custom Flutter chrome; native would silently drop it |
| Q7 | A destination without `sfSymbol` | **Flutter chrome** plus one debug log; no placeholder symbol |
| Q8 | A page pushed above the shell | **Hide the native chrome** while the shell's route is covered (`secondaryAnimation`); a dialog only makes it non-interactive. Closes I1 structurally. (VK-242 kept a tiled sidebar usable beside root pages) |
| Q9 | Native form of `tabBarTrailing` | **`UITab` with `.pinned`** (end of the bar, first sidebar row) in P2; a real `UISearchTab` comes with the search tab in P3 |
| Q10 | Window-controls constants before the spike | **Ignore a leading delta under 24pt when top reads 0** (rounded corner, measured 9.5pt full screen); **top = 44** when only the horizontal adaptation reads. Task 1 re-measures and may change both |
| Q11 | The native liquid glass renderer P1 listed under P2 | **Move it to P4**, beside the other liquid renderer; not in the approved P2 decomposition |
| Q12 | Version | **`0.1.0-dev.2`** for all four packages, CHANGELOG entries; no publishing (P6) |
| Q13 | Swift tests | **XCTest in the example's `RunnerTests`** for the pure parts plus the hit-test rule, a macOS CI job, and UIKit behaviour through the simulator integration test |
