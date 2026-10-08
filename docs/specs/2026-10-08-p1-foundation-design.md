# liquid_shell P1: foundation design

- **Plane:** VK-345 (parent VK-343)
- **Date:** 2026-10-08
- **Status:** design approved by the owner on 2026-10-08. This spec writes that design out in full. Items in §15 are open until the owner confirms them; each has a recommended default.
- **Repo:** local only, `/Users/invoker/Projects/tuvi/liquid_shell` (`main`). Future public home: `github.com/anvu69/liquid_shell`. Nobody creates or pushes that remote without asking the owner first.
- **Publisher:** pub.dev, verified publisher `lasoai.vn`. The owner runs `dart pub publish` (P6).
- **Sources:** `vk345-design-decisions.md` (approved design), `vk345-inventory.md` (app inventory, provenance, behaviour; line refs are to vankhan `origin/main` 7319398), `vk343-android-glass-research.md`, `vk342-research.md`.

> **Tóm tắt (cho chủ sản phẩm).** P1 dựng nền cho thư viện `liquid_shell` (MIT, công khai, federated): bốn gói `liquid_shell`, `liquid_shell_platform_interface`, `liquid_shell_ios`, `liquid_shell_android` cùng app `example/`. Khung điều hướng không phụ thuộc router. Dưới 700pt có viên kính nổi ở đáy, nút phụ (⌕) nằm bên phải. Từ 700pt trở lên có sidebar kính: máy dọc thì sidebar phủ lên nội dung, máy ngang (≥ 1024) thì nằm cạnh nội dung, kèm nút ẩn/hiện. iOS và Android giống hệt nhau. Thư viện có badge, mục chỉ hiện trong sidebar, slot đầu/cuối sidebar, nút phụ của thanh tab, hỏi trước khi đổi tab ("bỏ thay đổi?") và giữ nguyên state từng tab. Kính đi qua một seam `LiquidGlassRenderer` với ba tầng liquid / frosted / solid. P1 làm frosted và solid. Máy bật giảm trong suốt, tiết kiệm pin, hoặc hệ thống tắt blur thì kính chuyển sang nền đặc. Khi tín hiệu hỏng, thư viện coi như tín hiệu tắt, không bao giờ crash. Chỉ chép mã của mình (29 file SAFE). Hai helper test chép từ `calculator_promax` phải viết lại. Test gồm unit, widget, golden (golden cũng sinh ảnh cho README), integration trên simulator iOS và emulator Android, CI chạy Flutter 3.38 và stable, `pana` phải đạt điểm tối đa. P1 không sửa gì ở Văn Khấn. Câu hỏi còn mở và đề xuất mặc định nằm ở §15.

---

## 1. Goal

Owner's request (VK-343): pull the tab bar and adaptive shell out of Văn Khấn into a separate library that also works on Android. The library must cover Liquid Glass for the tab bar, the tablet sidebar, the back button and the search field. It must be as flexible as possible and ship full guidance, with code and images, plus an example for every case.

P1 builds the foundation that every later part sits on:

1. A **router-agnostic** `LiquidShell` that draws the navigation chrome in Flutter, with the same look on iOS and Android: a glass pill at the bottom in compact widths, and a glass sidebar plus a top pill in regular widths.
2. A **glass seam** (`LiquidGlass` → `LiquidGlassRenderer`, three tiers, chosen by `LiquidGlassPolicy`, coloured by `LiquidGlassTheme`). Later parts plug their renderers into it.
3. The **federated plugin skeleton**, with one real job in P1: reading the accessibility and power signals that force the solid tier.
4. The **test, golden, example and CI machinery**, so that P2–P6 only add features.

## 2. Scope

### 2.1 In P1

| # | Item | Notes |
|---|---|---|
| S1 | Repo with four packages and `liquid_shell/example` (§3) | Pub workspace, MIT, Flutter ≥ 3.38 / Dart ≥ 3.10 |
| S2 | `LiquidShell` with compact and regular layouts (§5) | Same on iOS and Android. `chromeBuilder` is the escape hatch |
| S3 | Owner-selected features **1, 3, 4, 5, 6** | badges · `sidebarOnly` destinations · sidebar header/footer slots · tab bar trailing action · per-tab state kept alive |
| S4 | `beforeDestinationChange` async guard | Accept, refuse, or throw (treated as refuse) |
| S5 | `LiquidShellScope`: insets, chrome kind, sidebar visibility, hide-chrome | Replaces the app's `tabBarInsetFor`, `NoTabBarInset`, `glassContentPadding`, `GlassContentInset` and `TabSearchScope` |
| S6 | Glass seam with **frosted** and **solid** renderers | The **liquid** tier is only a registration point in P1 |
| S7 | Platform signals: iOS reduce transparency; Android reduce transparency, battery saver and blur-disabled (§6) | Off on every other platform |
| S8 | `LiquidShellStrings`: every user-visible string, with English defaults | No i18n package dependency |
| S9 | Unit, widget, golden and integration tests; CI matrix; `pana` at max score (§10) | |
| S10 | Example app, one screen per case (§11); README and `doc/` (§12) | Images come from the goldens and regenerate with one command |

### 2.2 Non-goals for P1

- Native iOS chrome of any kind, such as `UITabBarController`, `.tabSidebar`, native tab bar or window controls. That is P2.
- Back button, search field, search tab, title bar (`GlassAppBar`). That is P3.
- A working **liquid** tier on any platform. That is P4 (Android, via `liquid_shell_liquid_glass`). The native iOS glass adapter comes with P2/P4.
- go_router integration and the root-pages walk (`_afterRootPages`). That is P5.
- Any change to Văn Khấn. P5 migrates it.
- Publishing to pub.dev, creating the GitHub repo. That is P6, and only with the owner's go-ahead.
- Material `NavigationBar` / `NavigationRail` chrome. The owner's answer A: Android looks the same as iOS. `chromeBuilder` is the way out.
- Collapsible sidebar groups. The owner did not select feature 2.
- The glass UI kit (`GlassScaffold`, `GlassSurface` for pages, `ScrollEdgeEffect`, floating save button, sheet `opaque` tint). It becomes a separate package after this series.
- Layout helpers that are not chrome: `ListDetailLayout`, `ReadableColumn`, `balancedColumns`.
- Sidebar slide animation, drag-to-open, keyboard shortcuts for switching tabs.
- Tooling that is not needed to build, test and document P1. Examples: melos, Pigeon (the channel is a single stream, §6), and an automatic changelog.

### 2.3 Future parts

| Part | Content |
|---|---|
| **P2** iOS native | Move `vankhan_shell` (`UITabBarController(.tabSidebar)`, pass-through hit test, native footer) into `liquid_shell_ios`. Add the iPadOS 26 window controls (VK-342). Add the native liquid renderer for iOS 26. Uses the P1 seams `chromeBuilder`, `beforeDestinationChange` and `LiquidGlassRenderer` |
| **P3** Back button and search | Glass back button / title bar, search field, search tab (VK-342 search tab). Sidebar search field replaces the P1 trailing-action row (§5.4) |
| **P4** Android liquid tier | `liquid_shell_liquid_glass` adapter on `liquid_glass_widgets`. Registers a `LiquidGlassRenderer` for `LiquidGlassTier.liquid` |
| **P5** go_router and Văn Khấn | `liquid_shell_go_router` adapter (`StatefulShellRoute` builder, `RootRouteObserver`, route-derived hide-chrome, root-pages walk via `beforeDestinationChange`). Migrate Văn Khấn; this finishes VK-342 |
| **P6** Docs and 0.1.0 | Final docs pass, public repo (with the owner's consent), `0.1.0` on pub.dev under `lasoai.vn` |

## 3. Repository and packages

### 3.1 Layout

```
liquid_shell/                               repo root (not a package)
├─ pubspec.yaml                             workspace root: name liquid_shell_workspace, publish_to: none
├─ analysis_options.yaml                    for tool/ only; each package has its own (pana analyses a package alone)
├─ LICENSE                                  MIT
├─ README.md                                short; links to liquid_shell/README.md
├─ .github/workflows/ci.yaml                §10.6
├─ tool/
│  ├─ update_goldens.sh                     regenerates every golden and doc image (§10.4)
│  ├─ integration_ios.sh                    §10.5
│  ├─ integration_android.sh                §10.5
│  ├─ check_provenance.sh                   §9
│  └─ check_readme_snippets.dart            §12.3 (subject to Q13)
├─ docs/specs/  docs/plans/                 design + plans (not shipped)
├─ liquid_shell/                            app-facing package
│  ├─ pubspec.yaml  LICENSE  README.md  CHANGELOG.md  analysis_options.yaml  .pubignore
│  ├─ lib/liquid_shell.dart                 the only public library (exports, §4.9)
│  ├─ lib/src/
│  │  ├─ shell/liquid_shell.dart            LiquidShell + State (stack, selection, guard)
│  │  ├─ shell/shell_layout.dart            pure: size class, presentation, chrome kind, insets
│  │  ├─ shell/shell_scope.dart             LiquidShellScope, LiquidShellScopeData, LiquidHideChrome,
│  │  │                                     LiquidNoChrome, LiquidContentInset
│  │  ├─ shell/chrome_builder.dart          LiquidChromeBuilder, LiquidChromeDetails, LiquidChromeSlot
│  │  ├─ shell/bar_measure.dart             internal height reporter (stable for 2 frames)
│  │  ├─ shell/breakpoints.dart             LiquidShellBreakpoints, LiquidSizeClass
│  │  ├─ shell/strings.dart                 LiquidShellStrings
│  │  ├─ destinations/destination.dart      LiquidDestination, LiquidPlacement
│  │  ├─ destinations/badge.dart            LiquidBadge (+ internal badge widget)
│  │  ├─ destinations/tab_action.dart       LiquidTabAction
│  │  ├─ chrome/tab_bar.dart                internal pill bar (bottom and top variants, minimise)
│  │  ├─ chrome/sidebar.dart                internal glass sidebar
│  │  ├─ chrome/sidebar_toggle.dart         internal 48pt glass toggle
│  │  ├─ chrome/large_content_viewer.dart   internal (AX long-press label)
│  │  ├─ chrome/text_scale.dart             internal (AX threshold 1.6, icon cap 36)
│  │  ├─ glass/liquid_glass.dart            LiquidGlass
│  │  ├─ glass/tier.dart                    LiquidGlassTier
│  │  ├─ glass/renderer.dart                LiquidGlassRenderer, LiquidGlassSpec
│  │  ├─ glass/frosted_renderer.dart        internal
│  │  ├─ glass/solid_renderer.dart          internal
│  │  ├─ glass/policy.dart                  LiquidGlassPolicy, LiquidGlassSignals
│  │  ├─ glass/glass_scope.dart             LiquidGlassScope
│  │  ├─ glass/glass_theme.dart             LiquidGlassTheme
│  │  └─ glass/signals_controller.dart      internal process-wide signal listenable
│  ├─ test/ …                               unit + widget (§10.2–10.3)
│  ├─ doc/ theming.md  tiers.md  router_integration.md  images/*.png
│  └─ example/                              §11 (pana needs it inside the package)
│     ├─ pubspec.yaml  lib/  test/goldens/  integration_test/  ios/  android/
├─ liquid_shell_platform_interface/
│  ├─ pubspec.yaml  LICENSE  README.md  CHANGELOG.md  example/example.md
│  ├─ lib/liquid_shell_platform_interface.dart
│  ├─ lib/src/liquid_shell_platform.dart    LiquidShellPlatform (+ default no-signal impl)
│  ├─ lib/src/platform_signals.dart         LiquidPlatformSignals
│  ├─ lib/src/event_channel_platform.dart   EventChannelLiquidShellPlatform
│  └─ test/
├─ liquid_shell_ios/
│  ├─ pubspec.yaml  LICENSE  README.md  CHANGELOG.md  example/example.md
│  ├─ lib/liquid_shell_ios.dart             LiquidShellIOS.registerWith()
│  ├─ ios/liquid_shell_ios.podspec          CocoaPods
│  ├─ ios/liquid_shell_ios/Package.swift    Swift Package Manager
│  ├─ ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift
│  ├─ ios/liquid_shell_ios/Sources/liquid_shell_ios/PrivacyInfo.xcprivacy
│  └─ test/
└─ liquid_shell_android/
   ├─ pubspec.yaml  LICENSE  README.md  CHANGELOG.md  example/example.md
   ├─ lib/liquid_shell_android.dart         LiquidShellAndroid.registerWith()
   ├─ android/ (Gradle files from the Flutter 3.38 plugin template, namespace vn.lasoai.liquid_shell)
   ├─ android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt
   ├─ android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt
   ├─ android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt   JVM unit tests
   └─ test/
```

The approved design lists `example/` beside the packages. It lives at `liquid_shell/example/` because pana only credits an example inside the package. The three platform packages each carry a short `example/example.md` that points to it.

### 3.2 pubspec constraints

Every package uses this environment block:

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"
```

The floor is set by `SemanticsService.sendAnnouncement` (Flutter 3.38), which the minimised tab bar uses (§5.7). Owner's answer C.

All four packages start at version `0.1.0-dev.1`. P6 sets `0.1.0`. Shared fields: `homepage`/`repository: https://github.com/anvu69/liquid_shell/tree/main/<package>`, `issue_tracker: https://github.com/anvu69/liquid_shell/issues`, `topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]`, `resolution: workspace`.

**`liquid_shell/pubspec.yaml`** (app-facing):

```yaml
name: liquid_shell
description: Adaptive navigation shell with a Liquid Glass look for iOS and Android. A floating tab bar on phones and a glass sidebar on tablets, with no router dependency.
dependencies:
  flutter: { sdk: flutter }
  liquid_shell_platform_interface: ^0.1.0-dev.1
  liquid_shell_ios: ^0.1.0-dev.1        # endorsed
  liquid_shell_android: ^0.1.0-dev.1    # endorsed
dev_dependencies:
  flutter_test: { sdk: flutter }
  very_good_analysis: 10.1.0
flutter:
  plugin:
    platforms:
      ios:
        default_package: liquid_shell_ios
      android:
        default_package: liquid_shell_android
```

**`liquid_shell_platform_interface/pubspec.yaml`**: depends on `flutter` and `plugin_platform_interface: ^2.1.8`. It has no `flutter.plugin` section.

**`liquid_shell_ios/pubspec.yaml`**:

```yaml
dependencies:
  flutter: { sdk: flutter }
  liquid_shell_platform_interface: ^0.1.0-dev.1
flutter:
  plugin:
    implements: liquid_shell
    platforms:
      ios:
        pluginClass: LiquidShellPlugin
        dartPluginClass: LiquidShellIOS
```

**`liquid_shell_android/pubspec.yaml`**:

```yaml
dependencies:
  flutter: { sdk: flutter }
  liquid_shell_platform_interface: ^0.1.0-dev.1
flutter:
  plugin:
    implements: liquid_shell
    platforms:
      android:
        package: vn.lasoai.liquid_shell
        pluginClass: LiquidShellPlugin
        dartPluginClass: LiquidShellAndroid
```

**`liquid_shell/example/pubspec.yaml`**: `publish_to: none`. Depends on `liquid_shell`. Dev-depends on `flutter_test`, `integration_test` and `very_good_analysis: 10.1.0`.

Rules:
- **Runtime dependencies are Flutter only**, plus our own federated packages and `plugin_platform_interface` (BSD-3, from the Flutter team). There is no third-party UI, i18n, router, logger or equality package.
- Every package's `analysis_options.yaml` includes `package:very_good_analysis/analysis_options.yaml` directly, never a file outside the package.
- `very_good_analysis` is pinned to **10.1.0**. It is the last release whose SDK constraint (`^3.10.0`) resolves on Dart 3.10. Releases 10.2 and later need Dart 3.11 or 3.12. Pinning the exact version keeps the lint set the same on the 3.38 and stable CI jobs.
- Native floors: iOS 15.0 (Xcode 27 rejects lower deployment targets); Android `minSdk` = `flutter.minSdkVersion` and `compileSdk` 36 (Q16).
- `liquid_shell/.pubignore` excludes `doc/images/` and `test/goldens/failures/`. README images resolve through `repository` on pub.dev (§12.1).

### 3.3 Federated wiring

```
app ──depends──▶ liquid_shell ──▶ liquid_shell_platform_interface ◀── liquid_shell_ios     (Swift, EventChannel)
                      │                                        ◀── liquid_shell_android (Kotlin, EventChannel)
                      └─ default_package: ios → liquid_shell_ios, android → liquid_shell_android
```

- `LiquidShellPlatform.instance` defaults to a **no-signal** implementation that emits `LiquidPlatformSignals.none` once. Web, macOS, Windows, Linux and plain `flutter test` therefore never touch a channel.
- `LiquidShellIOS.registerWith()` and `LiquidShellAndroid.registerWith()` set `instance = EventChannelLiquidShellPlatform()`. The channel code lives once, in the interface package. Both native sides speak the same protocol (§6.2).
- Only `liquid_shell_platform_interface` may be imported by `liquid_shell/lib/`. The platform packages are never imported by Dart code; they only register.

## 4. Public API

All names below are exported from `package:liquid_shell/liquid_shell.dart`. Signatures are binding. Dartdoc wording and private members are left to the plan. Every public class is `@immutable` unless it is a widget or state. Value classes implement `==`/`hashCode` by hand with `Object.hash`.

### 4.1 `LiquidShell`

```dart
typedef LiquidBeforeDestinationChange = Future<bool> Function(int index);

class LiquidShell extends StatefulWidget {
  const LiquidShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.beforeDestinationChange,
    this.onSelectedDestinationHidden,
    this.tabBarTrailing,
    this.sidebarHeader,
    this.sidebarFooter,
    this.chromeBuilder,
    this.breakpoints = const LiquidShellBreakpoints(),
    this.sidebarWidth = 300,
    this.minimizeOnScroll = true,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  /// All destinations, in display order. Indices refer to this list.
  /// Labels must be unique (debug assert, §7).
  final List<LiquidDestination> destinations;

  /// The destination whose content `body` currently shows.
  final int selectedIndex;

  /// Called after a user selects a destination, once any guard has accepted.
  /// Also called when `index == selectedIndex` (reselect). Apps usually pop
  /// that branch to its root.
  final ValueChanged<int> onDestinationSelected;

  /// The content. Any widget: an IndexedStack, a router's shell child, and so on.
  /// The shell never rebuilds it under a new parent (§5.6).
  final Widget body;

  /// Optional async guard, for example "Discard changes?". Runs before every
  /// user selection, including reselect. `false` cancels the selection.
  final LiquidBeforeDestinationChange? beforeDestinationChange;

  /// Called when the layout becomes compact while a `sidebarOnly`
  /// destination is selected (§5.5).
  final ValueChanged<int>? onSelectedDestinationHidden;

  /// Action at the trailing end of the tab bar (for example ⌕). Also shown
  /// as the first sidebar row (§5.4).
  final LiquidTabAction? tabBarTrailing;

  /// Leading part of the sidebar header row. The hide button is always
  /// added at the trailing end by the shell.
  final Widget? sidebarHeader;

  /// Pinned to the bottom of the sidebar.
  final Widget? sidebarFooter;

  /// Replaces or wraps the default chrome per slot (§4.5).
  final LiquidChromeBuilder? chromeBuilder;

  final LiquidShellBreakpoints breakpoints;

  /// Sidebar width in logical pixels. Asserted `0 < sidebarWidth < breakpoints.regular`.
  final double sidebarWidth;

  /// Compact bottom bar only: shrink to the selected tab while the user
  /// scrolls content down; expand on scroll up or tap (§5.7, Q3).
  final bool minimizeOnScroll;

  final LiquidShellStrings strings;
}
```

### 4.2 Destinations, badges, trailing action

```dart
enum LiquidPlacement {
  /// Tab bar and sidebar.
  everywhere,
  /// Sidebar only. Never in the tab bar.
  sidebarOnly,
}

class LiquidDestination {
  const LiquidDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
    this.placement = LiquidPlacement.everywhere,
  });

  final Widget icon;
  final Widget? selectedIcon;     // falls back to icon
  final String label;             // visible text and semantics label
  final LiquidBadge? badge;
  final LiquidPlacement placement;
}

sealed class LiquidBadge {
  const LiquidBadge._();
  /// Numeric badge. Shows "max+" above max. Hidden when count is 0.
  const factory LiquidBadge.count(int count, {int max}) = LiquidCountBadge;
  /// Small dot with no number.
  const factory LiquidBadge.dot() = LiquidDotBadge;
}

final class LiquidCountBadge extends LiquidBadge {
  const LiquidCountBadge(this.count, {this.max = 99})
      : assert(count >= 0), assert(max > 0), super._();
  final int count;
  final int max;
}

final class LiquidDotBadge extends LiquidBadge {
  const LiquidDotBadge() : super._();
}

class LiquidTabAction {
  const LiquidTabAction({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final Widget icon;
  final VoidCallback onPressed;
  /// Screen-reader label. Also the visible text of the sidebar row (§5.4).
  final String semanticLabel;
}
```

Badge drawing: the count is a capsule (minimum 16 × 16, 11/16 w600 text) and the dot is 8 × 8. Both sit at the top-end corner of the icon in bars, and at the trailing end of sidebar rows. Colours are `colorScheme.error` and `onError`. Semantics: `"<label>, <strings.badgeCount(count)>"` or `"<label>, <strings.badgeDot>"`.

Destination asserts (debug): `destinations` is not empty; 1–5 destinations are `everywhere` (Q4); `selectedIndex` is in range (§7); every `label` is non-empty.

### 4.3 Breakpoints and layout vocabulary

```dart
enum LiquidSizeClass { compact, regular }

class LiquidShellBreakpoints {
  const LiquidShellBreakpoints({this.regular = 700, this.tiledSidebar = 1024})
      : assert(regular > 0), assert(tiledSidebar >= regular);

  /// Widths below this are compact.
  final double regular;

  /// A regular layout tiles the sidebar beside the body only when it is
  /// landscape AND at least this wide. Otherwise the sidebar overlays (Q1).
  final double tiledSidebar;

  LiquidSizeClass sizeClassOf(double width);
}

enum LiquidChromeKind {
  bottomBar,       // compact: floating pill at the bottom
  topBar,          // regular, sidebar hidden: pill at the top + toggle
  sidebarOverlay,  // regular, sidebar shown over the body (top bar stays underneath)
  sidebarTiled,    // regular, sidebar beside the body, no tab bar
  hidden,          // a LiquidHideChrome is active (§4.4)
}
```

Width and height are the shell's own **layout constraints** (`LayoutBuilder`), not the screen size. The shell therefore behaves correctly in Split View, freeform windows and tests. "Landscape" means `maxWidth > maxHeight`.

### 4.4 `LiquidShellScope` and page helpers

```dart
abstract final class LiquidShellScope {
  /// Nearest shell's data. Outside any shell: asserts in debug, returns
  /// LiquidShellScopeData.none() in release.
  static LiquidShellScopeData of(BuildContext context);
  static LiquidShellScopeData? maybeOf(BuildContext context);

  /// Padding that keeps content clear of both chrome and system UI:
  /// per side, max(chromeInsets, MediaQuery.paddingOf(context)).
  static EdgeInsets contentPaddingOf(BuildContext context);
}

class LiquidShellScopeData {
  const LiquidShellScopeData({
    required this.sizeClass,
    required this.chromeKind,
    required this.chromeInsets,
    required this.sidebarVisible,
    required this.setSidebarVisible,
  });
  factory LiquidShellScopeData.none();   // compact, hidden, EdgeInsets.zero, false, no-op

  final LiquidSizeClass sizeClass;
  final LiquidChromeKind chromeKind;
  /// The part of the body covered by chrome, measured from the body's edges (§5.3).
  final EdgeInsets chromeInsets;
  final bool sidebarVisible;
  /// Shows or hides the sidebar. Ignored in compact (debug log).
  final ValueSetter<bool> setSidebarVisible;
  // == and hashCode compare every field except setSidebarVisible.
}

/// While mounted with enabled == true inside a shell, hides all chrome
/// (bar, toggle, sidebar). For full-frame pages pushed inside a branch.
/// Requests are reference-counted. Outside a shell it does nothing.
class LiquidHideChrome extends StatefulWidget {
  const LiquidHideChrome({required this.child, this.enabled = true, super.key});
  final Widget child;
  final bool enabled;
}

/// For pages pushed ABOVE the shell (root navigator): publishes
/// LiquidShellScopeData.none() to its subtree. Replaces the app's NoTabBarInset.
class LiquidNoChrome extends StatelessWidget {
  const LiquidNoChrome({required this.child, super.key});
  final Widget child;
}

/// Padding(LiquidShellScope.contentPaddingOf(context)). For non-scrolling
/// content. Replaces the app's GlassContentInset.
class LiquidContentInset extends StatelessWidget {
  const LiquidContentInset({required this.child, super.key});
  final Widget child;
}
```

These replace pieces of the app: `tabBarInsetFor` and `_TabBarInsetScope` become `chromeInsets`; `TabSearchScope.kind` and `sidebarOpen` become `chromeKind` and `sidebarVisible`; `detailOpen` becomes `LiquidHideChrome`; `NoTabBarInset` becomes `LiquidNoChrome`; `glassContentPadding` and `GlassContentInset` become `contentPaddingOf` and `LiquidContentInset`; `pageTopInset` and `tabPageTopInset` become `contentPaddingOf(context).top` plus the page's own gap.

### 4.5 Custom chrome

```dart
enum LiquidChromeSlot { tabBar, sidebar }

typedef LiquidChromeBuilder = Widget Function(
  BuildContext context,
  LiquidChromeDetails details,
  Widget defaultChrome,
);

class LiquidChromeDetails {
  const LiquidChromeDetails({ /* all fields required */ });

  final LiquidChromeSlot slot;
  final LiquidChromeKind kind;              // never hidden (the builder is not called then)
  final List<LiquidDestination> destinations;
  /// Indices (into destinations) this slot shows: everywhere-only for
  /// tabBar, all for sidebar.
  final List<int> visibleIndices;
  final int selectedIndex;
  /// Runs the same path as a tap: guard, then onDestinationSelected, then
  /// close the overlay.
  final ValueChanged<int> select;
  final LiquidTabAction? trailing;
  final bool minimized;                     // tabBar slot, compact only
  final VoidCallback expand;                // tabBar slot: leave minimised state
  final bool sidebarVisible;
  final ValueSetter<bool> setSidebarVisible;
  final LiquidShellStrings strings;
}
```

- The shell calls `chromeBuilder` once per visible slot, passing the widget it would have drawn as `defaultChrome`. Apps can wrap it or ignore it.
- Placement does not change. The tab-bar slot is aligned to the bottom (`bottomBar`) or the top (`topBar`, toggle included) and is **measured**, so `chromeInsets` stay correct for custom bars. The sidebar slot gets tight width `sidebarWidth` and full height.
- `chromeBuilder` cannot move or reparent `body` (§5.6).

### 4.6 Strings

```dart
class LiquidShellStrings {
  const LiquidShellStrings({
    this.showSidebar = 'Show sidebar',
    this.hideSidebar = 'Hide sidebar',
    this.tabBarExpanded = 'Navigation bar opened',
    this.expandTabBarHint = 'Tap to open the navigation bar',
    this.badgeDot = 'New',
    this.badgeCount = defaultBadgeCount,
  });

  final String showSidebar;        // toggle tooltip and semantics
  final String hideSidebar;        // sidebar hide button, overlay barrier label
  final String tabBarExpanded;     // announcement when the minimised bar expands
  final String expandTabBarHint;   // semantics hint while minimised
  final String badgeDot;
  final String Function(int count) badgeCount;

  static String defaultBadgeCount(int count) => '$count new';
}
```

Destination labels and the trailing action label come from the app (`LiquidDestination.label`, `LiquidTabAction.semanticLabel`). The library therefore has no other user-visible strings. Apps localise by building `LiquidShellStrings` from their own i18n system.

### 4.7 Glass

```dart
enum LiquidGlassTier { liquid, frosted, solid }

/// A glass surface. The background comes from the renderer the policy
/// picks; child is drawn on top and is never rebuilt when the tier changes.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({required this.child, this.borderRadius, super.key});
  final Widget child;
  final BorderRadius? borderRadius;   // null → LiquidGlassTheme.of(context).borderRadius
}

class LiquidGlassSpec {
  const LiquidGlassSpec({required this.borderRadius, required this.theme});
  final BorderRadius borderRadius;
  final LiquidGlassTheme theme;
}

abstract class LiquidGlassRenderer {
  const LiquidGlassRenderer();
  LiquidGlassTier get tier;
  /// Whether this renderer can draw on this device right now.
  bool isSupported(BuildContext context) => true;
  /// The background layer only (blur, tint, rim, shadow). Must not paint
  /// outside the shape except for a shadow.
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec);
}

class LiquidGlassSignals {
  const LiquidGlassSignals({
    this.reduceTransparency = false,  // platform (§6)
    this.highContrast = false,        // MediaQuery.highContrastOf (iOS only in Flutter)
    this.powerSave = false,           // platform (§6), Android
    this.blurDisabled = false,        // platform (§6), Android API ≥ 31
    this.canBlur = true,              // false on Android without Impeller (Q6)
  });
  final bool reduceTransparency, highContrast, powerSave, blurDisabled, canBlur;
  bool get prefersSolid =>
      reduceTransparency || highContrast || powerSave || blurDisabled || !canBlur;
}

class LiquidGlassPolicy {
  const LiquidGlassPolicy({this.forcedTier, this.renderers = const []});

  /// App override. Wins over every signal (§5.8). null → automatic.
  final LiquidGlassTier? forcedTier;

  /// Extra renderers, e.g. a liquid adapter. For each tier the first
  /// supported registered renderer wins; built-in frosted and solid fill
  /// the rest. Solid is always available.
  final List<LiquidGlassRenderer> renderers;

  /// Overridable. Default algorithm in §5.8.
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals);

  /// The renderer that will draw `tier` (after fallbacks).
  LiquidGlassRenderer rendererFor(BuildContext context, LiquidGlassTier tier);
}

/// Sets the policy for a subtree. Put it in MaterialApp.builder for an
/// app-wide policy. Without one, `const LiquidGlassPolicy()` applies.
class LiquidGlassScope extends InheritedWidget {
  const LiquidGlassScope({required this.policy, required super.child, super.key});
  final LiquidGlassPolicy policy;
  static LiquidGlassPolicy policyOf(BuildContext context);
}

class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  const LiquidGlassTheme({
    required this.tint,
    required this.solid,
    required this.border,
    required this.rimHighlight,
    required this.shadow,
    required this.labelStyle,
    this.borderWidth = 1,
    this.blurSigma = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  /// Defaults for light and dark, derived from a ColorScheme (§5.9).
  factory LiquidGlassTheme.fromColorScheme(ColorScheme scheme);

  /// Theme extension if present, otherwise fromColorScheme(Theme.of(context).colorScheme).
  /// Never force-unwraps.
  static LiquidGlassTheme of(BuildContext context);

  final Color tint;              // frosted fill
  final Color solid;             // solid fill
  final Color border;
  final double borderWidth;
  final Color rimHighlight;      // frosted top-edge highlight
  final BoxShadow shadow;        // drawn outside the shape only
  final double blurSigma;
  final BorderRadius borderRadius;   // default bar shape (pill)
  final TextStyle labelStyle;    // compact tab labels

  @override LiquidGlassTheme copyWith({ /* every field */ });
  @override LiquidGlassTheme lerp(covariant LiquidGlassTheme? other, double t);
}
```

### 4.8 Platform interface (package `liquid_shell_platform_interface`)

```dart
class LiquidPlatformSignals {
  const LiquidPlatformSignals({
    this.reduceTransparency = false,
    this.powerSave = false,
    this.blurDisabled = false,
  });
  static const none = LiquidPlatformSignals();
  /// Lenient decoding: unknown keys are ignored; missing or non-bool → false.
  factory LiquidPlatformSignals.fromMap(Object? payload);
  final bool reduceTransparency, powerSave, blurDisabled;
}

abstract class LiquidShellPlatform extends PlatformInterface {
  LiquidShellPlatform() : super(token: _token);
  static LiquidShellPlatform get instance;          // default: no-signal impl
  static set instance(LiquidShellPlatform value);   // PlatformInterface.verifyToken
  /// Emits the current value on listen, then every change.
  Stream<LiquidPlatformSignals> watchSignals();
}

class EventChannelLiquidShellPlatform extends LiquidShellPlatform {
  @visibleForTesting
  static const channel = EventChannel('vn.lasoai.liquid_shell/signals');
  @override Stream<LiquidPlatformSignals> watchSignals();
}
```

`liquid_shell` re-exports nothing from the interface except `LiquidPlatformSignals`, which an app may need for a custom `LiquidGlassPolicy`. Tests swap `LiquidShellPlatform.instance` for a fake that extends `LiquidShellPlatform` (`MockPlatformInterfaceMixin` is not needed).

### 4.9 Exported vs internal

Exported: everything in §4.1–4.7 plus `LiquidPlatformSignals`, **plus `LiquidTabBar` and `LiquidSidebar` as standalone public widgets (Q12 = Yes): each gets a documented constructor taking the same destinations / selection / badge / trailing / header / footer inputs the shell passes, its own tests, an example case and a README section.** `LiquidTabBar` also takes `bool? narrow` and is exported with the constant `kLiquidNarrowWidth = 340` (Q17, §5.3): `narrow: true` uses the narrow pill padding; `null` (the default) means `MediaQuery.sizeOf(context).width < kLiquidNarrowWidth`. The shell always passes it explicitly from its own constraints. Neither `LiquidShellBreakpoints` nor `LiquidGlassTheme` gains a field: the pill margins are not themeable, so the threshold is a constant. Internal (`lib/src`, not exported): the sidebar toggle widget, the frosted and solid renderers, the bar height reporter, the signals controller, the large content viewer, the text-scale helpers and the narrow label fitter with its minimum `kLiquidMinLabelSize` = 10 (Q18; not exported, no public API change).

Test-only hooks (`@visibleForTesting`, exported): `debugLiquidGlassCanBlurOverride` (a `bool?` top-level variable) and `debugResetLiquidGlassSignals()`.

## 5. Behaviour

### 5.1 Layout by width and orientation

`w` and `h` are the shell's constraints. `B` = `breakpoints`.

| Layout | Condition | Sidebar | Tab bar | Trailing action | Toggle | `sidebarOnly` items | Body |
|---|---|---|---|---|---|---|---|
| **Compact** | `w < B.regular` | never | bottom pill | glass circle at the pill's end | none | not shown | full frame; content runs under the bar |
| **Regular, overlay** (portrait, or landscape narrower than `B.tiledSidebar`) | `w ≥ B.regular` and not tiled | hidden by default; when shown it **covers** the body and the top bar, with a dismissible barrier | top pill, centred | circle at the pill's end; when the sidebar is shown, the first sidebar row | 48pt circle at the top start when hidden; hide button in the sidebar header when shown | sidebar only | full frame, never resized |
| **Regular, tiled** | `w ≥ B.tiledSidebar` and `w > h` | shown by default, **beside** the body | none while the sidebar is shown; top pill + toggle when it is hidden | sidebar row when shown; circle when hidden | as above | sidebar only | `w − sidebarWidth` wide while the sidebar is shown |
| **Hidden** | any `LiquidHideChrome` active | none | none | none | none | — | full frame |

iOS and Android behave identically. iPhone 393 → compact. iPhone Pro Max landscape 932 → regular overlay. iPad 11" portrait 834 → regular overlay. iPad 11" landscape 1194 → tiled. Android phone 412 → compact. Android tablet landscape 1280 → tiled.

`chromeKind` is derived as: hidden → `hidden`; compact → `bottomBar`; regular with the sidebar hidden → `topBar`; overlay shown → `sidebarOverlay`; tiled shown → `sidebarTiled`. The function is pure (`shell_layout.dart`) and is tested over every cell.

### 5.2 Sidebar visibility

- One shell-wide `sidebarVisible` state (Q2). It does not depend on the branch.
- Initial value: `true` when the presentation is tiled, `false` when it is overlay.
- When the presentation changes (compact ↔ overlay ↔ tiled, through rotation or resize), the value **resets** to the new presentation's default.
- Changes come from: the toggle (show), the sidebar's hide button, the overlay barrier (tap), the overlay **closing itself after a selection is accepted**, `LiquidShellScopeData.setSidebarVisible`, and the system back gesture while the overlay is shown (Q10). A tiled sidebar does not close on selection.
- In compact the state is `false` and setters are ignored.
- Show and hide are not animated in P1 (same as the app today).

### 5.3 Geometry and insets

Numbers are preserved from the app. `pad` = `MediaQuery.paddingOf` of the shell.

| Element | Geometry |
|---|---|
| Bottom bar row | Horizontal margin 16, or 8 when narrow (below). Bottom gap = 21 when the bottom system inset is a gesture area (always on iOS; on Android when `systemGestureInsets.bottom > 0`), otherwise `max(21, viewPadding.bottom + 8)` (Q9). The pill is 62 high at text scale 1. Compact cells stack the icon over the label. The trailing circle is the same height as the pill, square, 8 from the pill. |
| Top bar row | Starts at `pad.top + 20`. The pill is 52 high. Cells put the icon beside the label. Margin 16; when the toggle is present, each side also reserves 20 + 48 + 8 so the pill stays centred. |
| Toggle | 48 × 48 glass circle at `(start: 20, top: pad.top + 20)`. |
| Sidebar | `sidebarWidth` wide, full height. Glass with `BorderRadius.zero` and a 1px end border in `outlineVariant`. Inner padding 16 horizontal, 24 vertical, plus `pad`. Order: header row `[sidebarHeader (expanded) │ hide button]`, trailing-action row (§5.4), destination rows in list order, spacer, `sidebarFooter`. Rows: 12 radius, 12 horizontal padding, 12 icon–label gap. Selected row: `primaryContainer` / `onPrimaryContainer`, w600; otherwise w500. |
| Overlay barrier | `ModalBarrier(dismissible: true, semanticsLabel: strings.hideSidebar)` over the body and top bar, under the sidebar. Colour `scrim` at 0.32. |

`chromeInsets` by kind:

| Kind | `chromeInsets` |
|---|---|
| `bottomBar` | `bottom` = measured row height + bottom gap (83 before the first measurement) |
| `topBar`, `sidebarOverlay` | `top` = `pad.top` + 20 + measured pill height (`pad.top + 72` before measurement) |
| `sidebarTiled`, `hidden` | zero (the body is already beside the sidebar or the chrome is gone) |
| any kind, bar **measured at 0** | zero. A `chromeBuilder` bar that collapses to 0pt draws nothing, so neither the bottom gap nor the `pad.top + 20` band is added for it (amended 2026-10-08, Task 10 review M4). Before the first measurement the initial extents still apply |

**Narrow widths (Q17, amended 2026-10-08).** The shell is *narrow* when its constraint width `w < kLiquidNarrowWidth` (340). In the compact bottom bar a narrow shell uses a horizontal row margin of **8** instead of 16, and the pill's inner horizontal padding is **4** instead of 8 (vertical padding stays 4). Cell width with 5 tabs plus the trailing circle at 320 is then, at text scale 1, (320 − 2×8 − 62 − 8 − 2×4) / 5 = **45.2pt**, at or above the 44pt HIG hit target (40.4pt with the regular values). Larger text below the accessibility threshold grows the pill and the square trailing circle with it, so cells can drop under 44pt there (amended 2026-10-08, Task 10 re-review N3). At `w ≥ 340` nothing changes: (340 − 32 − 62 − 8 − 16) / 5 = 44.4pt. The top bar is unaffected (it only exists at `w ≥ B.regular`, and its pill padding is already 4). Standalone `LiquidTabBar` applies the same inner padding through its `narrow` flag (§4.9); its outer margins are the caller's. The flag defaults from `MediaQuery` width, which is the window: a bar in a pane narrower than the window (an in-app split view), and a `chromeBuilder` that builds its own `LiquidTabBar` in a shell narrower than the window, must pass `narrow` explicitly (Task 10 re-review N2).

**Narrow labels (Q18, owner 2026-10-09: 1B).** In the narrow bottom bar (`narrow == true`) a label that does not fit its cell is fitted in three steps: (1) it takes the cell's 8pt side padding (the cell keeps the geometry above: `min(share, max(icon, label) + 16)`, never under 44 when the share allows); (2) it shrinks, as a uniform scale of the drawn label, down to `kLiquidMinLabelSize` = **10** logical pixels, or to its own size when the style is already smaller (it never grows); (3) only then does it ellipsize, at that minimum. The selected label uses the same style as the others; only its colour changes (amended 2026-10-09, label-fit review). The label is measured with its own style after the text scaler, as drawn. It keeps its unscaled line height, so fitting never changes the pill height. At text scale 1 the default label is 10pt, so there step 1 alone does the work: at 320 with "Home", "Explore", "Inbox", "Saved", "Settings" every label fits at 10pt (Inter: widest "Settings" 43.1pt in a 45.2pt cell). Step 2 acts between text scale 1 and the AX threshold, and with a theme `labelStyle` above 10pt. Regular width (`narrow == false`) and the top bar are unchanged: 8pt padding, ellipsis at the style's size.

The bar is measured after layout and reported only once its height has been stable for 2 frames. The report is keyed by `(sizeClass, textScaler)`. This is ported from `_HeightReporter`. In tiled-shown, the body gets `MediaQuery` with `size.width = w − sidebarWidth` and the start padding set to 0, so pages beside the sidebar see their real width.

### 5.4 Trailing action

`tabBarTrailing` shows wherever a tab bar shows (bottom and top bars) as a separate glass circle. While the sidebar is shown, it also appears as the first sidebar row: icon plus `semanticLabel` as the text, same row style, never "selected" (Q5). It is never hidden by minimisation. P3 replaces the sidebar row with a real search field when the action is a search.

### 5.5 Selection, guard, `sidebarOnly`

1. A tap on a cell or row calls `select(i)`. If a guard call is already in flight, the tap is ignored.
2. If there is no `beforeDestinationChange`, the shell calls `onDestinationSelected(i)` and closes the overlay sidebar.
3. Otherwise it awaits the guard:
   - `true`: call `onDestinationSelected(i)` and close the overlay.
   - `false`: do nothing; the overlay stays open.
   - The guard throws: same as `false`, plus `FlutterError.reportError` (§7).
   - The shell is unmounted while the guard is pending: drop the result.
   - `destinations` changed while the guard was pending: an accepted selection goes to the destination with the requested label (the same index if it is still there, else its only match), or is dropped. Labels are therefore required to be unique (§7; Task 10 review M7, re-review N1).
4. Programmatic changes to `selectedIndex` never call the guard.
5. Reselect (`i == selectedIndex`) runs the same path.
6. **`sidebarOnly` selected in compact.** The pill highlights nothing and the selection is kept. After the frame in which the layout becomes compact (or on the first frame if it starts compact), the shell calls `onSelectedDestinationHidden(selectedIndex)` once. It does not call it again until the layout leaves compact and comes back. In a regular layout with the sidebar hidden, the top pill also highlights nothing, and there is no callback, because the toggle can reveal the selection.

### 5.6 Per-tab state

`body` is always the **first** child of the shell's `Stack`. It is wrapped in the same `Positioned → MediaQuery → KeyedSubtree(GlobalObjectKey(state))` chain in every layout. Layout changes only change `Positioned` values and `MediaQuery` data. Chrome, the barrier and the sidebar are later siblings. Toggling the sidebar, switching compact ↔ regular, rotating, `LiquidHideChrome`, swapping `chromeBuilder` and theme/tier changes therefore never unmount `body`, and branch `State` survives with no reliance on router keys. The library never wraps `body` in anything that tears down children, such as `IndexedStack` or `Offstage`. Keeping branch bodies alive is the router's or app's job.

### 5.7 Minimise on scroll (compact bottom bar only)

Ported from the app (Q3). It applies only when `minimizeOnScroll` is set and the layout is `bottomBar`. A `UserScrollNotification` from `body` with direction `reverse` minimises the bar; `forward` expands it. The minimised pill shows only the selected destination; the trailing circle stays. A tap on the minimised pill expands it without changing the tab, and announces `strings.tabBarExpanded` with `SemanticsService.sendAnnouncement`. While minimised, the cell omits `selected` and carries `strings.expandTabBarHint`. Under Reduce Motion (`MediaQuery.disableAnimations`) the `AnimatedSize` is removed, not set to zero duration. The flag is not reset when the size class changes; it simply stops applying.

### 5.8 Glass tier resolution

`LiquidGlass` reads the platform signals from a process-wide listenable. It starts the platform stream when the first `LiquidGlass` mounts and cancels it when the last one unmounts, so no widget has to be placed in `MaterialApp.builder`. `LiquidGlassSignals` combines the platform signals with `MediaQuery.highContrastOf` and `canBlur`. `canBlur` is false only when `defaultTargetPlatform == TargetPlatform.android` and `ui.ImageFilter.isShaderFilterSupported` is false (no Impeller: Skia on API ≤ 28) (Q6, Q7). It reads `defaultTargetPlatform`, not `Theme.platform`, because the capability belongs to the device, not the theme. `debugLiquidGlassCanBlurOverride` replaces it in tests.

`LiquidGlassPolicy.resolve`, default:

1. `forcedTier != null` → that tier. If no supported renderer exists for it, step down liquid → frosted → solid and log once with `debugPrint` (debug only). P1 has no liquid renderer, so forcing liquid draws frosted.
2. `signals.prefersSolid` → `solid`.
3. Otherwise the highest tier with a supported renderer: `liquid` if a registered liquid renderer's `isSupported` is true, else `frosted`.

Built-in renderers:

- **Frosted.** `ClipRRect(borderRadius)` → `BackdropFilter.grouped(blur σ = blurSigma)` (inside the shell's `BackdropGroup`, so all chrome shares one backdrop read) → shadow painted only **outside** the shape (ported `_OutsideOf`, so it never shows through the tint) → tint fill → `borderWidth` border in `border` → 1px rim highlight: a gradient from `rimHighlight` at the top to transparent at mid-height. Outside a `BackdropGroup`, plain `BackdropFilter`.
- **Solid.** No `BackdropFilter`. Outside-only shadow, `solid` fill, border.

Transitions: a tier change cross-fades over 200ms, and instantly when `disableAnimations` is set. The blur layer is not in the tree when the solid tier is fully shown. `child` is always the second `Stack` child, so a tier switch keeps its focus and scroll state.

Budget rule (from the vk343 research): the chrome uses one backdrop group per shell. Glass is never used on list cells.

### 5.9 Theme defaults

`LiquidGlassTheme.fromColorScheme(s)` follows the displayed theme (`Theme.of`), never `platformBrightness`. That avoids the latent bug in `AdaptiveBlurView`.

| Field | Light (`s.brightness == light`) | Dark |
|---|---|---|
| `tint` | `s.surface` @ 0.72 | `s.surface` @ 0.90 |
| `solid` | `s.surface` | `s.surface` |
| `border` | `s.outline` @ 0.28 | `s.onSurface` @ 0.18 |
| `rimHighlight` | white @ 0.50 | white @ 0.18 |
| `shadow` | `BoxShadow(color: 0x24000000, offset: (0, 6), blurRadius: 20, spreadRadius: -2)` | same |
| `labelStyle` | 10/14, w600, letter spacing 0.4, no font family (inherits the theme font) | same |
| `blurSigma`, `borderWidth`, `borderRadius` | 10, 1, pill (999) | same |

Tab colours come from `ColorScheme`: the selected cell is `primary` on a `primaryContainer` chip; unselected is `onSurfaceVariant`. Regular top-bar labels use `textTheme.labelMedium`; sidebar rows use `textTheme.bodyLarge`.

### 5.10 Accessibility, text scale, RTL

- Every cell and row is a button with `label` (plus the badge suffix) and `selected` (except while minimised). The toggle, hide button and trailing circle have tooltips and semantics from `strings` / `semanticLabel`.
- AX text scale (`textScaler.scale(14) / 14 ≥ 1.6`): bar cells become icon-only. The label moves to semantics. Icon size is capped at 36. A long press shows the internal large content viewer (`UILargeContentViewer` analogue).
- Below the AX threshold, narrow bottom-bar labels shrink to fit, never under 10pt, before they ellipsize (Q18, §5.3). The label in semantics is always the full text. Known trade-off (owner decision 1B): between text scale 1 and the AX threshold a narrow label can draw below the size the user chose, down to 10pt, and the large content viewer only starts at the AX threshold. The README states this.
- All placements are directional (`start`/`end`). In RTL the toggle sits at the top right and the trailing circle sits at the pill's left.
- The overlay sidebar is modal for screen readers: the barrier blocks the semantics of the content behind it.

## 6. Platform signals

### 6.1 Contract

| Signal | iOS | Android | Other platforms |
|---|---|---|---|
| `reduceTransparency` | `UIAccessibility.isReduceTransparencyEnabled` | `Settings.Global.ANIMATOR_DURATION_SCALE == 0` **or** high contrast: `UiModeManager.getContrast() > 0` on API ≥ 34, **or** `Settings.Secure` `"high_text_contrast_enabled" == 1` | false |
| `powerSave` | false (Q8) | `PowerManager.isPowerSaveMode` | false |
| `blurDisabled` | false | API ≥ 31: `!WindowManager.isCrossWindowBlurEnabled` (false when the GPU cannot blur, battery saver is on, or the developer "disable window blurs" option is set). API < 31: false | false |

Android 16/17's "Reduce blur effects" toggle has no confirmed public API. P1 relies on `isCrossWindowBlurEnabled` reflecting it; the plan checks this on an API 36 emulator and records the result.

### 6.2 Channel protocol

- One `EventChannel`, `vn.lasoai.liquid_shell/signals`, using the standard codec.
- On `listen`, native sends the current value at once, then one event per change. On `cancel`, native removes every observer.
- Event payload: `{"reduceTransparency": bool, "powerSave": bool, "blurDisabled": bool}`. Dart decodes it leniently (§4.8).
- A failed read of one field sends `false` for that field. It is not an error event.

### 6.3 iOS (`LiquidShellPlugin.swift`)

`FlutterPlugin` + `FlutterStreamHandler`. It observes `UIAccessibility.reduceTransparencyStatusDidChangeNotification` on the main queue. This is ported from `AppDelegate.swift:42-74` with the channel renamed. It ships for CocoaPods and Swift Package Manager (the same source in `Sources/liquid_shell_ios`), with an empty privacy manifest.

### 6.4 Android (`LiquidShellPlugin.kt`, `SignalReader.kt`)

`FlutterPlugin` + `ActivityAware` + `EventChannel.StreamHandler`. `SignalReader` holds the pure mapping from raw values (scale, contrast, setting int, power flag, blur flag, API level) to the payload, and has JVM unit tests. Observers registered on listen:

- `ContentObserver` on `Settings.Global.ANIMATOR_DURATION_SCALE` and on `Settings.Secure` `high_text_contrast_enabled`.
- `UiModeManager.addContrastChangeListener` (API ≥ 34).
- A receiver for `PowerManager.ACTION_POWER_SAVE_MODE_CHANGED`.
- `WindowManager.addCrossWindowBlurEnabledListener` (API ≥ 31). This uses the activity's `WindowManager` when attached and falls back to the application context.

Every read is wrapped in `try/catch` (`SecurityException`, `SettingNotFoundException`, `RuntimeException`) → `false`. Every observer is removed on cancel, detach from activity and detach from engine. No permissions are needed.

### 6.5 Dart side and fallbacks

| Situation | Result |
|---|---|
| Platform package not registered (web, desktop, `flutter test`) | Default no-signal instance → `none`. No channel call. |
| `MissingPluginException` or `PlatformException` on listen | `none`. Logged once with `debugPrint`, in debug only. |
| Error event on the stream | Reset to `none`, log in debug only, and keep listening. |
| Stream closes | Keep the last value. |
| Malformed payload or field | That field is `false`. |

Glass always keeps rendering; a signal failure can only make the result *more* glassy, never blank.

## 7. Error handling

| Case | Debug | Release |
|---|---|---|
| Platform signal fails or is unsupported | `debugPrint` once | Treated as off (§6.5) |
| `selectedIndex` out of range | `assert` with a message naming the range | Treated as `0` |
| `destinations` empty | `assert` | Body only, no chrome |
| More than 5, or zero, `everywhere` destinations (Q4) | `assert` | Draws them; cells shrink to fit. Up to 5 + trailing stay ≥ 44pt wide down to 320 at text scale 1 (Q17) |
| Negative `LiquidBadge.count` | `assert` | Hidden, as for 0 |
| `beforeDestinationChange` throws | `FlutterError.reportError(FlutterErrorDetails(exception, stack, library: 'liquid_shell', context: ErrorDescription('while running beforeDestinationChange')))`; selection refused | same |
| Guard completes after unmount | ignored | ignored |
| `sidebarOnly` selected and the layout is compact | — | §5.5 item 6 |
| Device cannot blur (no Impeller on Android, system blur disabled) | — | Solid tier |
| Forced tier has no supported renderer | `debugPrint` once | Next lower tier |
| A registered renderer's `isSupported` throws | `FlutterError.reportError` | Treated as unsupported |
| No `LiquidGlassTheme` extension | — | `fromColorScheme` (no force-unwrap) |
| `LiquidShellScope.of` outside a shell | `assert` | `LiquidShellScopeData.none()` |
| `setSidebarVisible` in compact | `debugPrint` | ignored |
| `LiquidHideChrome` outside a shell | — | no-op |
| Bar height never settles | — | Initial extents (83 / `pad.top + 72`) stay in use |
| `sidebarWidth` ≥ `breakpoints.regular` | `assert` | Used as given |
| Duplicate `LiquidDestination.label`s (labels must be unique) | `assert` naming the repeated labels | Drawn as given; an accepted guarded selection whose destination moved may be dropped, because the guard re-finds it by label (§5.5) |

Exceptions thrown by app callbacks (`onDestinationSelected`, `LiquidTabAction.onPressed`) and by app widgets (`chromeBuilder`, third-party `buildBackground`) are not caught. Flutter reports them as usual. The built-in renderers do not throw.

## 8. From the app to the library

### 8.1 File map

Paths on the left are relative to vankhan `7319398`. Paths on the right are relative to the new repo.

| Existing | New home | Part |
|---|---|---|
| `lib/core/layout/adaptive_shell.dart`, Flutter path | `liquid_shell/lib/src/shell/liquid_shell.dart`, `shell_layout.dart`, `bar_measure.dart` (`_HeightReporter`), `chrome/sidebar_toggle.dart` (`_ShowSidebarButton`) | P1 |
| `adaptive_shell.dart`, native path (~L313-641), `_afterRootPages` | `liquid_shell_ios` (native shell) / `liquid_shell_go_router` (root-pages walk) | P2 / P5 |
| `lib/core/layout/app_sidebar.dart` | `liquid_shell/lib/src/chrome/sidebar.dart` | P1 |
| `lib/core/layout/breakpoint.dart` | `liquid_shell/lib/src/shell/breakpoints.dart` | P1 |
| `lib/core/layout/tab_search_action.dart` | Folded into `LiquidShellScopeData.chromeKind` / `sidebarVisible`; the Material-only `TabSearchAction` is dropped | P1 |
| `lib/core/layout/page_insets.dart` | `LiquidShellScope.contentPaddingOf` | P1 |
| `lib/core/layout/text_scale.dart` | `liquid_shell/lib/src/chrome/text_scale.dart` | P1 |
| `lib/shared/widgets/large_content_viewer.dart` | `liquid_shell/lib/src/chrome/large_content_viewer.dart` | P1 |
| `lib/shared/widgets/glass/glass_surface.dart` | `liquid_shell/lib/src/glass/liquid_glass.dart`, `frosted_renderer.dart`, `solid_renderer.dart` | P1 |
| `lib/shared/widgets/glass/glass_material.dart`: `glassMaterialFor` | `liquid_shell/lib/src/glass/policy.dart` | P1 |
| `glass_material.dart`: `liquidGlassConfigFor`, `TitleBarKind` | native glass adapter / back button | P2 / P3 |
| `lib/shared/widgets/glass/glass_tab_bar.dart` | `liquid_shell/lib/src/chrome/tab_bar.dart` | P1 |
| `lib/shared/widgets/navigation/tab_bar_kind.dart` | `LiquidChromeKind` in `shell_layout.dart`; native kinds come back as adapters | P1 / P2 |
| `lib/shared/widgets/navigation/app_tab_bar.dart` | Dropped (no Material chrome); the kind → widget switch moves into `liquid_shell.dart` | P1 |
| `lib/shared/widgets/navigation/app_tabs.dart` | `LiquidDestination`; Văn Khấn keeps its own list | P1 / P5 |
| `lib/core/a11y/reduce_transparency_channel.dart` | `liquid_shell_platform_interface/lib/src/event_channel_platform.dart` | P1 |
| `lib/core/a11y/reduce_transparency_scope.dart` | `liquid_shell/lib/src/glass/signals_controller.dart` (no placement rule) | P1 |
| `ios/Runner/AppDelegate.swift:42-74` | `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift` | P1 |
| `lib/config/theme/app_colors.dart:220-378` (`AppGlassColors` tint/border/solid) | `LiquidGlassTheme` (values generalised to `ColorScheme`, §5.9). `GlassLevel` variants stay in the app; `AppSheetColors.opaqueTint` goes to the glass UI kit | P1 |
| `lib/config/theme/app_theme.dart:143,:198` (tab label 10/14 w600 0.4) | `LiquidGlassTheme.labelStyle` default | P1 |
| `app_motion.dart` / `app_radius.dart` values (200ms, pill 999, control 12) | Private constants in `liquid_shell` | P1 |
| `glass_scaffold.dart`, `scroll_edge_effect.dart`, `glass_primary_button.dart` | Glass UI kit package (later) | — |
| `glass_app_bar.dart` | Back button / title bar | P3 |
| `liquid_glass_support.dart`, `native_tab_bar.dart`, `native_top_chrome.dart`, `native_chrome_visibility.dart`, `native_shell_insets.dart`, `native_sidebar_footer.dart`, `vankhan_shell` | `liquid_shell_ios` | P2 |
| `native_shell_chrome.dart` (`RootRouteObserver`, `nativeShellChrome`) | `liquid_shell_go_router` / `liquid_shell_ios` | P5 / P2 |
| `list_detail_layout.dart`, `readable_width.dart`, `balanced_columns.dart` | Stay in the app | — |
| `lib/root.dart`, `lib/my_app.dart`, `config/routing/app_router.dart`, `route_names.dart` | Stay in the app (MIXED; never extracted) | P5 migrates the wiring |

Tests move with their code (inventory §6.1). The moved P1 tests are rewritten against the new API: `adaptive_shell_test` (without go_router fakes, `LocaleKeys` or `ritual_list_body`), `app_sidebar_test`, `breakpoint_test`, `text_scale_test`, `page_insets_test`, `glass_surface_test` (`BackdropFilter` finders instead of `AdaptiveBlurView`; the pixel-capture shadow test is kept), `glass_material_test` (tier part), `glass_tab_bar_test`, `tab_bar_kind_test`, `reduce_transparency_*_test`. They count as P1 TDD: each test goes red against the new skeleton before the code lands.

### 8.2 Couplings to remove

| Coupling (where) | Replacement |
|---|---|
| `easy_localization` + `LocaleKeys`: `navigation_search_open` (adaptive_shell :498, :859; app_sidebar :108; glass_tab_bar :414; tab_search_action :60), `navigation_sidebar_show` (:1106), `navigation_sidebar_hide` (app_sidebar :72), `app_name` (app_sidebar :65), `navigation_expanded_announcement` (glass_tab_bar :90), `navigation_expand_hint` (:147), tab labels `navigation_today/rituals/settings` (app_tabs :42-52) | `LiquidShellStrings`, `LiquidTabAction.semanticLabel`, `sidebarHeader`, `LiquidDestination.label` |
| `kAppTabs` and hard-coded `shown = [0, 1, 2]` (glass_tab_bar :69, :74; app_sidebar :39; adaptive_shell :495; app_tab_bar :80, :93) | `destinations` (any count, Q4) |
| go_router `StatefulNavigationShell`, `goBranch`, `route.branches.length` (adaptive_shell :10, :243, :381, :721, :750) | `selectedIndex` / `onDestinationSelected` / `body` |
| `_ritualBranchIndex = 1` (adaptive_shell :203, :704) and per-branch sidebar memory (:299) | One shell-wide state + `setSidebarVisible` (Q2) |
| `detailOpen` (:245-251, :948-951) | `LiquidHideChrome` |
| `AppGlassColors` / `AppSheetColors` with `!` force-unwrap (glass_surface :99, :106, :195) | `LiquidGlassTheme.of` |
| `AppRadius`, `AppMotion`, `AppTheme.tabBarLabelTextStyle` | Private constants + `LiquidGlassTheme` |
| `ReduceTransparencyScope` + app-named channel `vn.lasoai.vankhan/a11y` | Signals controller + `vn.lasoai.liquid_shell/signals` |
| `AppLogger` (adaptive_shell :16, :634; channel :3) | `debugPrint` (debug only) / `FlutterError.reportError` |
| `adaptive_platform_ui` `AdaptiveBlurView` (glass_surface :1, :213) | Built-in frosted renderer |
| `native_liquid_glass` (`LiquidGlassContainer`, `liquidGlassAvailable`) | `LiquidGlassRenderer` seam; adapter later |
| `vankhan_shell` / `VankhanShell` / native footer sink | Not in P1 (P2) |
| `GlassMaterial` naming `native/flutter/solid` | `LiquidGlassTier.liquid/frosted/solid` |
| `equatable` (`EquatableMixin` in `AppGlassColors`) | Hand-written `==` / `hashCode` |
| `Theme.of(context).platform` → `materialBar`/`materialRail` on Android | Removed: the chrome is the same on every platform |
| Be Vietnam Pro font and app brand colours | Not shipped. Tests use the bundled OFL Inter (§10.4) |

## 9. Provenance rule

- **Only SAFE code goes in.** The 29 files and 3 slices listed as SAFE in inventory §2 may be ported. The six MIXED files (`root.dart`, `my_app.dart`, `app_router.dart`, `route_names.dart`, `app_theme.dart`, `app_colors.dart`) are **never** copied. Only the SAFE slices named in §8.1 are lifted from `app_theme.dart` and `app_colors.dart`, and only as values.
- Porting means re-typing into the new API, with new names and English comments. Vietnamese comments and VK/B ticket references are not carried over.
- **`calculator_promax` helpers are rewritten from scratch, never copied.** This applies to `integration_test/support/evidence.dart` and `test_driver/integration_test.dart`, whose headers say "Chép từ calculator_promax"; the owner has not confirmed their provenance. The person writing the replacement must not open those files while writing it. The new `example/integration_test` and the screenshot driver follow the public `integration_test` package docs only.
- `test/helpers/real_fonts.dart` is ours (VK-*) but tied to the app font. It is rewritten as a generic font loader (§10.4).
- No app assets, screenshots (`docs/qa/...`), fonts or colours ship.
- `tool/check_provenance.sh` runs in CI. It fails if any file outside `docs/` contains `vankhan`, `Văn Khấn`, `calculator_promax`, `LocaleKeys`, `easy_localization`, `go_router`, `AppColors`, `AppGlassColors` or `GetIt`.
- Every package `LICENSE` is MIT, with the copyright line from Q15.

## 10. Testing

TDD applies to every task (red → green → commit), with per-task review and a whole-branch review at the end.

### 10.1 Unit (pure Dart, `liquid_shell/test/unit/`, interface `test/`)

- `shell_layout`: size class at 699/700, presentation at `tiledSidebar ± 1` × portrait/landscape, `chromeKind` for every cell of §5.1, insets for every kind (§5.3), bottom-gap rule (§5.3, Q9).
- Sidebar state machine: initial value per presentation, reset on presentation change, compact ignores setters.
- `LiquidGlassPolicy.resolve`: each signal alone → solid; none → frosted; liquid renderer registered and supported → liquid; registered but unsupported → frosted; `forcedTier` for each tier, including forced liquid with no renderer → frosted; renderer `isSupported` throws → unsupported plus a reported error; `canBlur` false only on Android (Q6).
- `LiquidGlassTheme`: `fromColorScheme` light and dark values (§5.9), `copyWith`, `lerp` endpoints, `==`.
- `LiquidBadge`: count 0 hidden, `max+` overflow, semantics strings.
- `LiquidShellStrings` defaults; `LiquidShellScopeData ==` ignores the setter.
- Platform interface: `fromMap` with full, missing, non-bool and non-map payloads; default instance emits `none` without a channel; `verifyToken` rejects an `implements` fake; `EventChannelLiquidShellPlatform` with a mocked stream handler covers events, error event → `none`, and `MissingPluginException` → `none`.
- Android `SignalReaderTest` (JVM): every row of §6.1 for API 30, 31, 34 and 36 inputs.

### 10.2 Widget (`liquid_shell/test/widget/`)

- **Chrome by width:** compact, overlay (portrait and narrow landscape) and tiled at 393×852, 932×430, 834×1194, 1194×834. Assert which chrome exists, `chromeKind` and the insets seen by a probe in `body`.
- **Badges:** count, overflow, dot, hidden at 0; semantics label includes the badge.
- **`sidebarOnly`:** absent from the pill, present in the sidebar; selected in compact → nothing highlighted and `onSelectedDestinationHidden` called once; resize regular → compact → regular → compact calls it twice in total.
- **Sidebar slots:** header and footer render; the hide button is always present; the trailing action row appears and calls `onPressed`.
- **Trailing action:** circle in the bottom and top bars; it survives minimisation.
- **`beforeDestinationChange`:** accept → callback and overlay closes; refuse → no callback and overlay stays open; throw → no callback and `FlutterError.onError` receives `library: 'liquid_shell'`; a second tap while pending is ignored; unmount while pending does not call back; reselect runs the guard.
- **Per-tab state:** a stateful counter inside `body` keeps its value across a sidebar toggle, compact ↔ regular, rotation, `LiquidHideChrome` on/off, adding and removing `chromeBuilder`, and a tier change.
- **`LiquidHideChrome`:** hides every slot and zeroes the insets; reference counting with two instances; `enabled: false` is a no-op; outside a shell it is a no-op.
- **`LiquidNoChrome` / `LiquidContentInset` / `contentPaddingOf`.**
- **Selection range:** out-of-range `selectedIndex` asserts in debug. The release behaviour is tested through the pure resolver, which maps it to 0.
- **Minimise:** reverse scroll minimises, forward expands, tap expands without changing tab, announcement sent (`tester.binding` semantics announcements), no `AnimatedSize` under `disableAnimations`.
- **Tier policy per signal:** a fake platform emits each signal → `BackdropFilter` absent and solid fill present; reset → frosted. High contrast via `MediaQuery`. `debugLiquidGlassCanBlurOverride = false` on Android → solid.
- **Theme:** light and dark take their values from `LiquidGlassTheme.of`; a custom extension is honoured; with no extension nothing throws.
- **Semantics:** labels, `selected`, the minimised hint, the toggle and hide tooltips from `strings`, barrier label, AX text scale 2.0 → icon-only with a label in semantics and long press → large content viewer.
- **System back** with the overlay shown closes it (Q10).
- **Outside shadow:** pixel-capture test ported from `glass_surface_test.dart:258-300`.
- **Custom chrome:** `chromeBuilder` receives `defaultChrome` and correct details per slot; a custom bar of height 100 is measured into `chromeInsets`; a custom bar of height 0 yields zero insets.
- **Narrow widths (Q17):** at 320×568 with 5 tabs + trailing every cell is ≥ 44pt wide inside the real shell; 375 keeps margin 16 and padding 8; 339 is narrow and 340 is not; RTL mirrors it; standalone `LiquidTabBar` follows `narrow` and the `MediaQuery` default.
- **Narrow labels (Q18):** at 320 a label that fits after taking the side padding draws at its own size with no ellipsis; at text scale 1.3 a label shrinks to fit and stays ≥ 10pt; a label too long at 10pt ellipsizes at exactly 10pt; the selected label fits; regular width keeps padding 8 and ellipsizes at the style's size; RTL behaves the same. In the example (Inter, iPhone, 320pt shell) all five labels of `NarrowWidthCase` fit untruncated at ≥ 10pt, selected or not.

### 10.3 Goldens: regression guard and doc images

- They live in `liquid_shell/example/test/goldens/`, so the image renders exactly the code shown in the README (§11). Tag: `golden` (`dart_test.yaml`).
- Each golden writes to `liquid_shell/doc/images/<name>.png` (`matchesGoldenFile('../../../doc/images/<name>.png')`).
- Harness `example/test/support/golden_harness.dart` is written fresh. It loads Inter (OFL 1.1, `example/test/fonts/` + `OFL.txt`) and MaterialIcons from the Flutter SDK cache. It sets the logical size, `devicePixelRatio = 2`, the safe-area padding per device, `Theme.platform`, and light/dark themes. It paints a deterministic wallpaper (`CustomPainter`, no image assets) so the glass is visible.
- Devices: iPhone 393×852 (padding top 59, bottom 34); iPad 834×1194 and 1194×834 (top 24, bottom 20); Android 412×915 (top 24, gesture bottom 24).
- `example/test/flutter_test_config.dart` installs a comparator that tolerates ≤ 0.5% differing pixels (Q11); `example/test/golden_comparator_test.dart` pins that boundary (just under passes, just over fails; added 2026-10-09, Task 12 review). It also sets `debugLiquidGlassCanBlurOverride = true`, because `flutter test` defaults to the Android platform and may report no shader filters; without the override, every golden would show the solid tier. `case_tier_solid` gets solid through `forcedTier`, not through this flag. Widget tests in `liquid_shell/test` set the same override in their own `flutter_test_config.dart`, except the tests that exercise it.
- Golden list: `hero_{iphone,ipad_landscape,android}_{light,dark}` (6); one per case in §11 (`case_basic`, `case_badges`, `case_sidebar_only`, `case_sidebar_slots`, `case_trailing`, `case_guard`, `case_custom_chrome`, `case_custom_theme`, `case_tier_frosted`, `case_tier_solid`, `case_narrow` (added 2026-10-09, Task 12)); form factors `ff_iphone`, `ff_ipad_portrait`, `ff_ipad_portrait_sidebar_open`, `ff_ipad_landscape`, `ff_android`. A `case_tier_liquid` golden is added in P4.

### 10.4 One command for images

`tool/update_goldens.sh` runs `flutter test --tags golden --update-goldens` in `liquid_shell/example`. It must run on the golden reference toolchain (Q11). It is the only way doc images are produced; nobody edits them by hand.

### 10.5 Integration (`liquid_shell/example/integration_test/signals_test.dart`)

- Both platforms: `LiquidShellPlatform.instance` is the event-channel implementation; `watchSignals().first` completes within 5 s with a well-formed value; the shell renders frosted with default settings.
- Android (`tool/integration_android.sh`; CI runs it on API 34, and the plan runs it once locally on API 36): the host script sets each signal with `adb` before a run and passes the expectation through `--dart-define`:
  - `settings put global animator_duration_scale 0` → `reduceTransparency`
  - `settings put global low_power 1` (after `cmd battery unplug`) → `powerSave`
  - `wm disable-blur 1` → `blurDisabled`
  Each run asserts the signal and the solid tier, then the script restores the settings. API 36 also records whether "Reduce blur effects" flips `blurDisabled` (§6.1).
- iOS (`tool/integration_ios.sh`, latest iOS simulator): channel round-trip and default value. Reduce Transparency has no supported `simctl` toggle, so toggling it is a manual check: flip it in Settings while the example runs, then save a screenshot to `docs/qa/` as evidence.
- The screenshot driver for these runs is written fresh (§9).

### 10.6 CI (GitHub Actions, `.github/workflows/ci.yaml`)

Matrix `flutter: [3.38.x, stable]` unless noted.

| Job | Runner | Steps |
|---|---|---|
| `checks` | ubuntu-latest | `flutter pub get` (workspace) → `dart format --output=none --set-exit-if-changed .` → `flutter analyze --fatal-infos` → `flutter test --exclude-tags golden --coverage` per package → `tool/check_provenance.sh` → `tool/check_readme_snippets.dart` |
| `android-unit` | ubuntu-latest | `./gradlew :liquid_shell_android:testDebugUnitTest` from `example/android` |
| `goldens` | macos-latest | `flutter test --tags golden` in `example`. Blocking on 3.38.x; `continue-on-error` on stable (Q11). Failure diffs are uploaded as an artifact |
| `integration-android` | ubuntu-latest (KVM, `reactivecircus/android-emulator-runner`, API 34) | `tool/integration_android.sh` |
| `integration-ios` | macos-latest | `tool/integration_ios.sh` |
| `pana` | ubuntu-latest, stable only | `dart pub global activate pana`; `pana --exit-code-threshold 0` for each of the 4 packages; `flutter pub publish --dry-run` for each |

`--exit-code-threshold 0` fails the job if any pana point is lost, which enforces "max score". Coverage gate: Q14.

## 11. Example app

`liquid_shell/example`: a case list on the home screen, and each entry opens one self-contained screen. Each case file has a `// #docregion readme` region, which is the README snippet. A region is a set of members of the screen's `State` class (its fields, `build` and helpers), so it compiles when pasted into the `State` of a new `StatefulWidget` that imports `material.dart` and `liquid_shell.dart`, with the example's `DemoPage` and `kDemoDestinations` as stand-ins (amended 2026-10-09, Task 13). Every region compiles on its own (Task 13 review): the hide-chrome page is its own case, the guard's body is a plain page, and the trailing region includes its search page method, which is also the nested `no-chrome` region. The README quickstart is `lib/quickstart.dart`, a whole app (`main`, `MaterialApp`, `LiquidShell`) whose `quickstart` region compiles in a fresh `flutter create` project. `tool/check_readme_snippets.dart` fails on any region that no README or `doc/` snippet uses.

| Case | File | Shows |
|---|---|---|
| Basic 3 tabs | `lib/cases/basic_tabs.dart` | Smallest `LiquidShell` with an `IndexedStack` body; content scrolls under the bar with `LiquidContentInset` |
| Badges | `lib/cases/badges.dart` | `count(3)`, `count(120)` → "99+", `dot()` |
| `sidebarOnly` | `lib/cases/sidebar_only.dart` | Two sidebar-only destinations plus `onSelectedDestinationHidden` switching to tab 0 |
| Sidebar header/footer | `lib/cases/sidebar_slots.dart` | App title header, profile-style footer |
| Trailing ⌕ | `lib/cases/trailing_action.dart` | `LiquidTabAction` opening a search page that uses `LiquidNoChrome` |
| "Discard changes?" guard | `lib/cases/discard_guard.dart` | `beforeDestinationChange` showing a dialog, with an "Unsaved changes" switch |
| Hide the chrome | `lib/cases/hide_chrome.dart` | A detail page pushed inside the branch's own `Navigator` (as a router's shell branch does) with `LiquidHideChrome` (split from the guard case 2026-10-09, Task 13 review) |
| Custom chrome | `lib/cases/custom_chrome.dart` | `chromeBuilder` wrapping the default bar and replacing the sidebar |
| Custom theme | `lib/cases/custom_theme.dart` | `LiquidGlassTheme` extension with brand tint, blur and label style; light/dark switch |
| Forced tier | `lib/cases/forced_tier.dart` | Segmented liquid/frosted/solid via `LiquidGlassScope(policy: LiquidGlassPolicy(forcedTier: …))`; liquid shows frosted plus a note until P4 |
| Form factors | `lib/cases/form_factors.dart` | The basic shell inside fixed frames (iPhone 393×852, iPad portrait 834×1194, iPad landscape 1194×834, Android 412×915), scaled to fit, so one device shows every layout |
| Standalone widgets | `lib/cases/standalone_widgets.dart` | §4.9: `LiquidTabBar` at the bottom of the app's own `Scaffold` on a phone, `LiquidSidebar` beside the page from 700pt; no `LiquidShell` (added 2026-10-09, Task 13 review) |
| Narrow width | `lib/cases/narrow_width.dart` | 5 tabs + a trailing action in a 320pt-wide shell: margin 8, pill padding 4, 45.2pt cells at text scale 1 (Q17), labels fitted untruncated (Q18); the shell decides from its own width, not the screen's (added 2026-10-08, Task 11). The case clips its 320pt shell, which stands for a narrow window, so the wallpaper discs stay inside it |

Shared support: `lib/support/wallpaper.dart` (the same painter the goldens use; it does not clip, so on iPad the discs show through the tiled sidebar's glass, owner 2026-10-09: 2A) and `lib/support/demo_page.dart` (a long list). `example/test/cases_smoke_test.dart` pumps every case at phone and tablet sizes with no exceptions, and checks the guard, hide/no-chrome pages, the sidebar-only fallback, the custom sidebar leaving the primary scroll controller to the body, and the narrow-width cells.

## 12. Documentation

### 12.1 `liquid_shell/README.md`

1. Title, one-line pitch, badges (pub, CI, license).
2. **Hero images**: a 2 × 3 grid, iPhone / iPad landscape / Android × light / dark (`doc/images/hero_*`).
3. Features list (only what P1 ships) and platform table (iOS, Android; other platforms: frosted, no signals).
4. Install (`flutter pub add liquid_shell`).
5. **Quickstart**: a whole app from `example/lib/quickstart.dart` (`main`, `MaterialApp`, a two-tab `LiquidShell`), checked like every snippet; the shell itself is about 10 lines.
6. **Cases**: one `###` section per §11 row, each with **one snippet** (its docregion) and **one image** (its golden). In order: basic tabs, badges, sidebar-only, sidebar slots, trailing action, guard, hide chrome / no chrome, custom chrome, standalone tab bar and sidebar, custom theme, forced tier, form factors, narrow width.
7. Layout rules: a short version of the §5.1 table.
8. Accessibility and fallbacks: the signals table from §6.1.
9. Limitations (5-tab maximum, narrow label shrink between text scale 1 and 1.6, `PopScope` calls while the overlay sidebar is open, native iOS 26 chrome in P2, liquid tier in P4); links to `doc/`; roadmap (P2–P6 in one line each); license.

Images use relative paths (`doc/images/…`). pub.dev rewrites them against `repository`, so they appear on pub.dev only once the public repo exists (P6).

**P6 release checklist, images (added 2026-10-09, Task 13 review).** pub.dev never serves README images from the archive (`doc/images/` is in `.pubignore`); it rewrites relative URLs to `https://github.com/anvu69/liquid_shell/raw/main/liquid_shell/doc/images/…`, and only when pana's repository verification did not fail. Before `dart pub publish`: (1) the GitHub repo is public; (2) `liquid_shell/doc/images/*` is on `main`; (3) pana reports the repository as verified (no lost repository points). Relative images track `main`, so an older version's page shows the current images.

### 12.2 `liquid_shell/doc/`

- `theming.md`: `LiquidGlassTheme` fields, defaults table, light/dark, per-brand example.
- `tiers.md`: tiers, `LiquidGlassPolicy` algorithm, signals per platform, writing a `LiquidGlassRenderer`, forced tier.
- `router_integration.md`: the seam with plain `Navigator`/`IndexedStack`, with go_router `StatefulShellRoute` by hand (until P5 ships the adapter), where `LiquidHideChrome` and `LiquidNoChrome` go, and keeping branch state alive.

### 12.3 Snippet check

`tool/check_readme_snippets.dart` checks that every README snippet equals its `#docregion` in `example/lib/cases/` (Q13). The README and the images therefore can't drift from the code.

## 13. Process

- Tracking stays in Plane VK-345. The plan (`docs/plans/2026-10-08-p1-foundation.md`, via `superpowers:writing-plans`) creates one sub-issue per task.
- Work happens on branch `VK-345-p1-foundation` of this local repo. Commits follow `type(scope): …`, with scopes `shell`, `glass`, `platform`, `ios`, `android`, `example`, `docs`, `ci`.
- TDD, per-task review, whole-branch review, then verification: every command in §10.6 is run locally (except the CI-only matrix) with its output pasted as evidence.
- Nothing in vankhan changes. No remote is created or pushed without the owner's consent.

## 14. Risks

| Risk | Mitigation |
|---|---|
| `BackdropGroup` / `BackdropFilter.grouped` or `ImageFilter.isShaderFilterSupported` may be missing or behave differently on Flutter 3.38 | Plan task 1 verifies them on 3.38.x. If missing: plain `BackdropFilter`, and `canBlur` derived from the Android API level (≤ 28 → false) |
| Blur cost on low-end Android (jank, battery) | Solid on power save, blur-disabled and no-Impeller; one backdrop group per shell; never on list cells. P4 adds adaptive quality |
| Android signals: "Reduce blur effects" has no public API; `high_text_contrast_enabled` is an undocumented key; OEM variance | Every read is `try/catch` → off; API 36 emulator check recorded (§10.5); documented as best-effort in `tiers.md` |
| Goldens differ across OS and Flutter versions | One reference toolchain (macOS + 3.38.x), 0.5% tolerance, stable goldens non-blocking (Q11) |
| pana max score with federated packages, SwiftPM, workspace and `resolution: workspace` | `pana` + `publish --dry-run` in CI from the first task. Fallback: drop the workspace for `pubspec_overrides.yaml` path overrides |
| Bottom pill over Android 3-button navigation | Gap rule (§5.3, Q9), Android goldens with gesture and 3-button padding |
| Android look changes for Văn Khấn users (Material → glass) when P5 migrates | Owner decision A; `chromeBuilder` escape hatch; flagged again in the P5 spec |
| The API churns before 0.1.0 | Versions stay `0.1.0-dev.x` until P6; breaking changes are allowed and listed in CHANGELOG |
| Body reparenting by a future change destroys branch state | §5.6 invariant + widget test across every transition |
| Provenance slip (copying the `calculator_promax` helpers, app assets or brand values) | §9 rule, `check_provenance.sh` in CI, review checklist item |
| A single-flight guard swallows taps while a dialog is open | Intended: the dialog is modal; documented in the guard's dartdoc |
| iOS Low Power Mode keeps frosted glass (Q8) | Matches the system's own glass; revisit if users report it |

## 15. Open questions

> **Resolved 2026-10-08 — the owner accepted every default below ("Ok hết"), with Q12 changed to Yes and Q16 changed to iOS 15.0. The rest of this spec is amended accordingly wherever it says otherwise.**

Every entry has a recommended default. If the owner says nothing, the default applies.

| # | Question | Recommended default |
|---|---|---|
| Q1 | Tiled vs overlay: orientation only, or orientation plus a minimum width? | Tiled only when **landscape and width ≥ 1024** (`LiquidShellBreakpoints.tiledSidebar`). Phones in landscape (≈ 900) get the overlay, so the body is never squeezed below compact |
| Q2 | Sidebar visibility: per branch (as the app does today) or one shell-wide state? | **One shell-wide state.** Default shown when tiled, hidden when overlay, reset when the presentation changes. Apps change it with `LiquidShellScopeData.setSidebarVisible` (Văn Khấn's rituals rule moves there in P5) |
| Q3 | Keep minimise-on-scroll in P1? It is existing app behaviour, not a listed feature | **Yes, `minimizeOnScroll: true`.** It is ported as is, and its `sendAnnouncement` is what sets the 3.38 floor |
| Q4 | Limit on `everywhere` (tab bar) destinations | **Assert 1–5** in debug; release draws them all with shrinking cells. `sidebarOnly` is unlimited |
| Q5 | Where the trailing action lives while the sidebar is shown | **First sidebar row** (icon + `semanticLabel`). P3 replaces it with a search field |
| Q6 | Does "no Impeller → solid" apply beyond Android? | **Android only.** Web and desktop keep frosted (they have no signals and blur works there) |
| Q7 | Detecting a "weak GPU" on Android | **No extra heuristic in P1:** `isCrossWindowBlurEnabled` (API ≥ 31) + no-Impeller. No low-RAM rule; P4's adaptive quality covers the rest |
| Q8 | Should iOS Low Power Mode force solid? | **No.** The design lists only reduce transparency for iOS, and the system glass ignores Low Power Mode |
| Q9 | Bottom gap on Android with 3-button navigation | **21 over gesture areas, otherwise `max(21, viewPadding.bottom + 8)`** |
| Q10 | System back while the overlay sidebar is shown | **Closes the sidebar** (`PopScope` on the shell's route). P5 re-checks this with go_router |
| Q11 | Golden reference toolchain | **macOS runner + Flutter 3.38.x is blocking**; stable runs non-blocking; 0.5% pixel tolerance. Images are regenerated on macOS with `tool/update_goldens.sh` |
| Q12 | Export the tab bar and sidebar as standalone widgets? | **Yes (owner, 2026-10-08).** Export `LiquidTabBar` and `LiquidSidebar` as public, documented, tested widgets so apps can compose their own chrome; `chromeBuilder` still hands over `defaultChrome` |
| Q13 | Automated README snippet check | **Yes**, `tool/check_readme_snippets.dart` in CI (small script, prevents doc drift) |
| Q14 | Coverage gate | **90% line coverage** for `liquid_shell/lib` and `liquid_shell_platform_interface/lib`, as a fixed floor, without ratchet files |
| Q15 | Copyright line in the MIT `LICENSE` | **`Copyright (c) 2026 lasoai.vn`** |
| Q16 | Native floors | **iOS 15.0 (owner, 2026-10-08: Xcode 27 rejects deployment targets below 15.0; matches the vankhan app, ADR there); Android `minSdk` = Flutter's default (`flutter.minSdkVersion`), `compileSdk` 36** |
| Q17 | Narrow-width hit targets (owner 2026-10-08: C) | **Resolved 2026-10-08, option C.** At 320pt (iPad Slide Over, ⅓ Split View, small phones) 5 tabs + the trailing circle gave 40.4pt cells, under the 44pt HIG target. Below the constant `kLiquidNarrowWidth` = **340** (shell constraint width `w < 340`; exactly 340 is regular) the compact bottom row margin becomes **8** (was 16) and the pill's inner horizontal padding **4** (was 8). 5 tabs + trailing at 320 → **45.2pt** cells. Applied in `LiquidShell`'s compact layout and in standalone `LiquidTabBar` (`narrow` flag, default from `MediaQuery` width). A constant, not a `LiquidShellBreakpoints` / `LiquidGlassTheme` field, because the margins are not themeable. §4.9, §5.3 amended. No debug assert: the configuration is legal |
| Q18 | Narrow tab labels truncate at 320 (owner 2026-10-09: 1B) | **Resolved 2026-10-09, option 1B: narrow labels auto-shrink.** At 320 with 5 tabs + trailing (45.2pt cells, Q17) the example's labels ellipsized ("Ho…", "Exp…", "Sav…", "Set…"). In the narrow bottom bar a label first takes the cell's 8pt side padding, then shrinks to `kLiquidMinLabelSize` = **10** logical pixels (or its own smaller size; it never grows), and only then ellipsizes. Implemented as a FittedBox-style uniform scale of the label's `Text` with a minimum scale, in an internal custom render object (`RenderFitLabel`, `fit_label.dart`; not a `FittedBox`) that supports intrinsic sizing, so the bar's `IntrinsicHeight` keeps working; the label keeps its unscaled line height. **Narrow only** (decision 2026-10-09, as the owner stated): regular width and the top bar keep padding 8 and ellipsize at the style's size. AX text scales are unchanged (icon-only cells, large content viewer). The selected label uses the same style as the others (only the colour changes); it is measured as drawn either way. Cell geometry (Q17) is unchanged. The minimum is an internal constant, not a parameter: no public API change (§4.9). §5.3, §5.10, §10.2, §11 amended. Supersedes the Task 12 review's suggestion to shorten the example labels |
