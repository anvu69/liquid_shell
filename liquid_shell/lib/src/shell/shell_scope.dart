import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// What the nearest `LiquidShell` tells its body.
@immutable
class LiquidShellScopeData {
  /// Creates scope data.
  const LiquidShellScopeData({
    required this.sizeClass,
    required this.chromeKind,
    required this.chromeInsets,
    required this.sidebarVisible,
    required this.setSidebarVisible,
    this.nativeChrome = false,
    this.windowControls = LiquidWindowControls.zero,
    this.searchPhase,
    this.nativePageBar = false,
  });

  /// No shell: compact, hidden chrome, zero insets, no sidebar. Window
  /// controls belong to the window, not the shell, so they pass through.
  factory LiquidShellScopeData.none({
    LiquidWindowControls windowControls = LiquidWindowControls.zero,
  }) => LiquidShellScopeData(
    sizeClass: LiquidSizeClass.compact,
    chromeKind: LiquidChromeKind.hidden,
    chromeInsets: EdgeInsets.zero,
    sidebarVisible: false,
    setSidebarVisible: _ignore,
    windowControls: windowControls,
  );

  static void _ignore(bool visible) {}

  /// Compact or regular.
  final LiquidSizeClass sizeClass;

  /// The chrome on screen.
  final LiquidChromeKind chromeKind;

  /// The part of the body covered by chrome, from the body's edges.
  final EdgeInsets chromeInsets;

  /// Whether the sidebar is shown.
  final bool sidebarVisible;

  /// Shows or hides the sidebar. Ignored in compact (logged in debug).
  ///
  /// Safe to call while a page builds (`initState`, `didChangeDependencies`,
  /// `build`): the change then applies right after that frame.
  final ValueSetter<bool> setSidebarVisible;

  /// Whether the platform draws the chrome (native chrome on an iOS 26
  /// iPhone or iPad). The insets then come from the platform's safe area:
  /// at regular width [chromeInsets] top is the top padding while the
  /// native top bar shows; at compact width (every iPhone, and a narrow
  /// iPad window) [chromeInsets] bottom is the bottom padding while the
  /// native floating tab bar shows.
  final bool nativeChrome;

  /// The iPadOS 26 window controls, zero elsewhere (always zero on an
  /// iPhone). Zero while [nativeChrome] is true at regular width: the
  /// native top bar and sidebar make room for them. Under the native
  /// compact bar, which sits at the bottom, they are the real cluster.
  /// Rows at the top of a page clear them with
  /// `LiquidWindowControlsClearance`.
  final LiquidWindowControls windowControls;

  /// The search tab's phase; null when the shell has no search tab.
  final LiquidSearchPhase? searchPhase;

  /// The selected tab has a native navigation bar (iOS 26 native chrome):
  /// `LiquidPage` draws no Flutter bar, and [windowControls] is zero.
  final bool nativePageBar;

  /// Field by field, except [setSidebarVisible] (spec §4.4). The setter is an
  /// action, not state: pages depend on what the shell shows, so equality
  /// covers the values only. Two scopes that show the same thing are
  /// equal whatever function they carry, e.g. [LiquidShellScopeData.none]
  /// and data built with any other setter (closures equal only themselves).
  @override
  bool operator ==(Object other) =>
      other is LiquidShellScopeData &&
      other.sizeClass == sizeClass &&
      other.chromeKind == chromeKind &&
      other.chromeInsets == chromeInsets &&
      other.sidebarVisible == sidebarVisible &&
      other.nativeChrome == nativeChrome &&
      other.windowControls == windowControls &&
      other.searchPhase == searchPhase &&
      other.nativePageBar == nativePageBar;

  @override
  int get hashCode => Object.hash(
    sizeClass,
    chromeKind,
    chromeInsets,
    sidebarVisible,
    nativeChrome,
    windowControls,
    searchPhase,
    nativePageBar,
  );
}

/// Receives hide-chrome requests. Implemented by the shell's state.
abstract interface class HideChromeRegistry {
  /// One more [LiquidHideChrome] is active.
  void addHideRequest();

  /// One fewer [LiquidHideChrome] is active.
  void removeHideRequest();
}

/// Publishes [data] (and the hide registry) to the subtree.
class ShellScopeMarker extends InheritedWidget {
  /// Creates the marker.
  const ShellScopeMarker({
    required this.data,
    required this.registry,
    required super.child,
    this.pages,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  /// Scope data for the subtree.
  final LiquidShellScopeData data;

  /// Where [LiquidHideChrome] registers; null above or outside a shell.
  final HideChromeRegistry? registry;

  /// Where `LiquidPage`s register; null outside a shell.
  final PageRegistry? pages;

  /// The shell's strings (the back button's label).
  final LiquidShellStrings strings;

  @override
  bool updateShouldNotify(ShellScopeMarker oldWidget) =>
      data != oldWidget.data ||
      registry != oldWidget.registry ||
      pages != oldWidget.pages ||
      strings != oldWidget.strings;
}

/// Reads the nearest `LiquidShell`.
abstract final class LiquidShellScope {
  /// The nearest shell's data. Outside any shell: asserts in debug, returns
  /// [LiquidShellScopeData.none] in release.
  static LiquidShellScopeData of(BuildContext context) {
    final data = maybeOf(context);
    assert(
      data != null,
      'LiquidShellScope.of() called outside a LiquidShell. Use maybeOf(), or '
      'wrap pages pushed above the shell in LiquidNoChrome.',
    );
    return data ?? LiquidShellScopeData.none();
  }

  /// The nearest shell's data, or null outside any shell.
  static LiquidShellScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScopeMarker>()?.data;

  /// Padding that keeps content clear of both chrome and system UI: per
  /// side, the larger of the chrome insets and `MediaQuery.paddingOf`.
  static EdgeInsets contentPaddingOf(BuildContext context) {
    final chrome = maybeOf(context)?.chromeInsets ?? EdgeInsets.zero;
    final system = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      math.max(chrome.left, system.left),
      math.max(chrome.top, system.top),
      math.max(chrome.right, system.right),
      math.max(chrome.bottom, system.bottom),
    );
  }
}

/// While mounted with [enabled] inside a shell, and while on screen, hides
/// all chrome (bar, toggle, sidebar) and zeroes the insets. For full-frame
/// pages pushed inside a branch. Requests are reference-counted. Outside a
/// shell it does nothing.
///
/// "On screen" means no ancestor `Visibility` is hidden and tickers are on
/// (`TickerMode`). Branches kept alive but hidden therefore do not hide the
/// chrome: an `IndexedStack` hides the inactive ones with `Visibility`, a
/// router's indexed-stack shell route with `Offstage` and `TickerMode`,
/// and a `Navigator` turns tickers off for a route covered by an opaque
/// one. After a switch away from a branch whose page hides the
/// chrome, the chrome comes back; switching back hides it again.
class LiquidHideChrome extends StatefulWidget {
  /// Hides the chrome while [child] is mounted and on screen.
  const LiquidHideChrome({required this.child, this.enabled = true, super.key});

  /// The page.
  final Widget child;

  /// Whether to hide the chrome.
  final bool enabled;

  @override
  State<LiquidHideChrome> createState() => _LiquidHideChromeState();
}

class _LiquidHideChromeState extends State<LiquidHideChrome> {
  HideChromeRegistry? _registry;
  bool _active = false;
  bool _onScreen = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = context
        .dependOnInheritedWidgetOfExactType<ShellScopeMarker>()
        ?.registry;
    if (registry != _registry) {
      _deactivate();
      _registry = registry;
    }
    // Both register a dependency, so a branch or route switch lands here.
    _onScreen = Visibility.of(context) && TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(LiquidHideChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled && _onScreen && _registry != null) {
      if (!_active) {
        _active = true;
        _registry!.addHideRequest();
      }
    } else {
      _deactivate();
    }
  }

  void _deactivate() {
    if (!_active) return;
    _active = false;
    _registry?.removeHideRequest();
  }

  @override
  void dispose() {
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// For pages pushed ABOVE the shell (on the root navigator): publishes
/// [LiquidShellScopeData.none] to [child], so its insets ignore the chrome
/// underneath. The window controls still pass through: they belong to the
/// window.
class LiquidNoChrome extends StatefulWidget {
  /// Creates the wrapper.
  const LiquidNoChrome({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  State<LiquidNoChrome> createState() => _LiquidNoChromeState();
}

class _LiquidNoChromeState extends State<LiquidNoChrome> {
  final WindowControlsSource _controls = WindowControlsSource.instance;

  @override
  void initState() {
    super.initState();
    _controls.acquire();
  }

  @override
  void dispose() {
    _controls.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<LiquidWindowControls>(
        valueListenable: _controls.value,
        builder: (context, controls, child) => ShellScopeMarker(
          data: LiquidShellScopeData.none(windowControls: controls),
          registry: null,
          child: child!,
        ),
        child: widget.child,
      );
}

/// `Padding(LiquidShellScope.contentPaddingOf(context))`, for content that
/// does not scroll.
class LiquidContentInset extends StatelessWidget {
  /// Creates the inset.
  const LiquidContentInset({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: LiquidShellScope.contentPaddingOf(context),
    child: child,
  );
}
