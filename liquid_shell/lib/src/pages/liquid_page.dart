import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// One page of a tab: its title for the navigation bar, and the back
/// button when its navigator can pop (spec P3b §4.5).
///
/// Where its tab has a native navigation bar (iOS 26 native chrome: the
/// search tab), the platform draws the title and UIKit's glass back circle
/// and this widget draws only [child]. Elsewhere it draws a Flutter glass
/// bar. A root page with an inline title draws no bar: the shell's own
/// chrome is its title row.
class LiquidPage extends StatefulWidget {
  /// Creates a page.
  const LiquidPage({
    required this.title,
    required this.child,
    this.largeTitle,
    super.key,
  });

  /// Navigation bar title.
  final String title;

  /// Large title. Null: large on a tab's root page at compact width,
  /// inline otherwise.
  final bool? largeTitle;

  /// The page. Its first vertical scroll view drives the native large
  /// title's collapse and the scroll-edge effect.
  final Widget child;

  @override
  State<LiquidPage> createState() => _LiquidPageState();
}

class _LiquidPageState extends State<LiquidPage> {
  static int _nextSequence = 0;
  final int _sequence = _nextSequence++;
  // The child keeps its State when the bar switches between native and
  // Flutter (native chrome on or off).
  final GlobalKey _childKey = GlobalKey();
  PageRegistry? _registry;
  PageHandle? _handle;

  PageEntry _entry() {
    final route = ModalRoute.of(context);
    return PageEntry(
      title: widget.title,
      largeTitle: widget.largeTitle,
      route: route,
      navigator: Navigator.maybeOf(context),
      sequence: _sequence,
      // As `LiquidHideChrome`: an `IndexedStack` hides a branch with
      // `Visibility` and leaves its tickers on.
      onScreen: Visibility.of(context) && TickerMode.valuesOf(context).enabled,
      current: route?.isCurrent ?? false,
      active: route?.isActive ?? false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = context
        .dependOnInheritedWidgetOfExactType<ShellScopeMarker>()
        ?.pages;
    final entry = _entry();
    if (!identical(registry, _registry)) {
      _handle?.unregister();
      _registry = registry;
      _handle = registry?.registerPage(entry);
    } else {
      _handle?.update(entry);
    }
  }

  @override
  void didUpdateWidget(LiquidPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.largeTitle != widget.largeTitle) {
      _handle?.update(_entry());
    }
  }

  // Detached here, not only in dispose: a page moved with a GlobalKey, or
  // replaced under a new key, leaves the stack this frame. Reactivation
  // runs didChangeDependencies, which registers again.
  @override
  void deactivate() {
    _handle?.unregister();
    _handle = null;
    _registry = null;
    super.deactivate();
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _handle?.scrolled(notification.metrics.pixels);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scope = LiquidShellScope.maybeOf(context);
    final child = KeyedSubtree(
      key: _childKey,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
    if (scope?.nativePageBar ?? false) return child;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final sizeClass =
        scope?.sizeClass ??
        const LiquidShellBreakpoints().sizeClassOf(
          MediaQuery.sizeOf(context).width,
        );
    final large =
        widget.largeTitle ?? (!canPop && sizeClass == LiquidSizeClass.compact);
    if (!canPop && !large) return child;
    return FlutterPageBar(
      title: widget.title,
      large: large,
      canPop: canPop,
      hideLargeTitle: scope?.searchPhase == LiquidSearchPhase.active,
      child: child,
    );
  }
}

/// A 44pt glass circle with a back chevron (spec P3b §4.5). Pops the
/// nearest navigator with `maybePop` by default, so a page's `PopScope`
/// guard runs.
class LiquidBackButton extends StatelessWidget {
  /// Creates the button.
  const LiquidBackButton({this.onPressed, this.semanticLabel, super.key});

  /// Diameter.
  static const double size = 44;

  /// Called on tap. Null: `Navigator.maybePop(context)`.
  final VoidCallback? onPressed;

  /// Semantics and tooltip. Null: the shell's `LiquidShellStrings.back`.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        context
            .getInheritedWidgetOfExactType<ShellScopeMarker>()
            ?.strings
            .back ??
        const LiquidShellStrings().back;
    void pressed() => onPressed != null
        ? onPressed!()
        : unawaited(Navigator.maybePop(context));
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: pressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: LiquidGlass(
            borderRadius: const BorderRadius.all(Radius.circular(size / 2)),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: pressed,
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
