import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';

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
  });

  /// No shell: compact, hidden chrome, zero insets, no sidebar.
  factory LiquidShellScopeData.none() => const LiquidShellScopeData(
    sizeClass: LiquidSizeClass.compact,
    chromeKind: LiquidChromeKind.hidden,
    chromeInsets: EdgeInsets.zero,
    sidebarVisible: false,
    setSidebarVisible: _ignore,
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
  final ValueSetter<bool> setSidebarVisible;

  /// Field by field, except [setSidebarVisible] (spec §4.4). The setter is an
  /// action, not state: pages depend on what the shell shows, so equality
  /// covers the four values only. Two scopes that show the same thing are
  /// equal whatever function they carry, e.g. [LiquidShellScopeData.none]
  /// and data built with any other setter (closures equal only themselves).
  @override
  bool operator ==(Object other) =>
      other is LiquidShellScopeData &&
      other.sizeClass == sizeClass &&
      other.chromeKind == chromeKind &&
      other.chromeInsets == chromeInsets &&
      other.sidebarVisible == sidebarVisible;

  @override
  int get hashCode =>
      Object.hash(sizeClass, chromeKind, chromeInsets, sidebarVisible);
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
    super.key,
  });

  /// Scope data for the subtree.
  final LiquidShellScopeData data;

  /// Where [LiquidHideChrome] registers; null above or outside a shell.
  final HideChromeRegistry? registry;

  @override
  bool updateShouldNotify(ShellScopeMarker oldWidget) =>
      data != oldWidget.data || registry != oldWidget.registry;
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

/// While mounted with [enabled] inside a shell, hides all chrome (bar,
/// toggle, sidebar) and zeroes the insets. For full-frame pages pushed
/// inside a branch. Requests are reference-counted. Outside a shell it
/// does nothing.
class LiquidHideChrome extends StatefulWidget {
  /// Hides the chrome while [child] is mounted.
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
    _sync();
  }

  @override
  void didUpdateWidget(LiquidHideChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled && _registry != null) {
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
/// underneath.
class LiquidNoChrome extends StatelessWidget {
  /// Creates the wrapper.
  const LiquidNoChrome({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) => ShellScopeMarker(
    data: LiquidShellScopeData.none(),
    registry: null,
    child: child,
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
