import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/pages/page_title.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// One page of a tab: its title for the navigation bar, and the back
/// button when its navigator can pop.
///
/// With native chrome on iOS 26+, a page in any of the shell's tabs gets
/// UIKit's navigation bar: the platform draws the title and the glass back
/// circle, and this widget draws only [child]. Elsewhere (iOS before 26,
/// Android, Flutter chrome, and pages pushed above the shell) it draws a
/// Flutter glass bar. Both bars follow the same title rules:
///
/// * a pushed page: the title small and centred, with the back button;
/// * a root page with [largeTitle] true: a large-title row under the bar
///   row, which scrolls away as the page scrolls while the small title
///   fades into the bar row;
/// * a root page with [largeTitle] null: the large title on the bar row at
///   compact width, as in Apple Music; no bar at regular width, where the
///   shell's own chrome is the title row;
/// * a root page with [largeTitle] false: no bar.
class LiquidPage extends StatefulWidget {
  /// Creates a page.
  const LiquidPage({
    required this.title,
    required this.child,
    this.largeTitle,
    super.key,
  });

  /// The navigation bar title; also the next page's native back label.
  final String title;

  /// A root page's large title. true: its own row, which collapses as
  /// the page scrolls. null: on the bar row at compact width, no title row
  /// at regular width. false: no title row.
  /// Ignored on a pushed page, whose title is always inline.
  final bool? largeTitle;

  /// The page. Its first vertical scroll view drives the native large
  /// title's collapse and the scroll-edge effect, and the Flutter bar's
  /// collapse.
  final Widget child;

  @override
  State<LiquidPage> createState() => _LiquidPageState();
}

class _LiquidPageState extends State<LiquidPage> {
  static int _nextOrder = 0;
  // A route's place in push order, taken when its first page registers. A
  // page recreated in a lower route (a new key) keeps its route's place
  // instead of sorting above the pages pushed after it.
  static final Expando<int> _routeOrder = Expando('LiquidPage route order');
  int? _orderWithoutRoute;

  int _orderOf(ModalRoute<Object?>? route) => route == null
      ? _orderWithoutRoute ??= _nextOrder++
      : _routeOrder[route] ??= _nextOrder++;
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
      sequence: _orderOf(route),
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

  // Scrolls, and the first layout of a scroll position. A position
  // restored from PageStorage reports its offset only through its metrics.
  // So does a page moved with a GlobalKey, which registers again with a
  // new handle: the moved Scrollable builds a new position (its
  // didChangeDependencies), whose first layout reports the kept offset.
  bool _onScroll(Notification notification) {
    final (depth, metrics) = switch (notification) {
      ScrollUpdateNotification(:final depth, :final metrics) => (
        depth,
        metrics,
      ),
      ScrollMetricsNotification(:final depth, :final metrics) => (
        depth,
        metrics,
      ),
      _ => (-1, null),
    };
    if (depth == 0 && metrics != null && metrics.axis == Axis.vertical) {
      _handle?.scrolled(metrics.pixels);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scope = LiquidShellScope.maybeOf(context);
    final child = KeyedSubtree(
      key: _childKey,
      child: NotificationListener<Notification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
    if (scope?.nativePageBar ?? false) return child;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final mode = pageTitleModeFor(
      root: !canPop,
      largeTitle: widget.largeTitle,
      sizeClass:
          scope?.sizeClass ??
          const LiquidShellBreakpoints().sizeClassOf(
            MediaQuery.sizeOf(context).width,
          ),
    );
    if (mode == PageTitleMode.hidden) return child;
    return FlutterPageBar(
      title: widget.title,
      mode: mode,
      canPop: canPop,
      hideLargeTitle: scope?.searchPhase == LiquidSearchPhase.active,
      child: child,
    );
  }
}

/// A 44pt glass circle with a back chevron. Pops the
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

  // A future of our own to hand to `unawaited`: newer SDKs mark `maybePop`
  // `@awaitNotRequired` (unnecessary_unawaited) while 3.44 still asks for
  // it (discarded_futures).
  static Future<void> _maybePop(BuildContext context) async {
    await Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        // A dependency: the bar builds this button `const`, so only the
        // marker can rebuild it when the strings change.
        context
            .dependOnInheritedWidgetOfExactType<ShellScopeMarker>()
            ?.strings
            .back ??
        const LiquidShellStrings().back;
    void pressed() =>
        onPressed != null ? onPressed!() : unawaited(_maybePop(context));
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
