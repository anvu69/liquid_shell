import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// Where a [LiquidTabBar] sits, which sets its cell layout.
enum LiquidTabBarPosition {
  /// Compact: floating at the bottom, icon over label, 62pt pill.
  bottom,

  /// Regular: floating at the top, label-only cells, 48 pt pill.
  top,
}

/// A landscape window lower than this gets the landscape bottom bar (the
/// `LiquidShellBreakpoints.compactHeight` default).
const double kLiquidCompactHeight = 500;

/// The gap between the pill and the trailing circle.
const double kLiquidTabBarTrailingGap = 8;

/// Below this width (logical pixels) the bottom tab bar is *narrow*:
/// `LiquidShell` shrinks the row margin to 8, so 5 tabs plus a trailing
/// action keep hit targets of at least 44pt down to 320 at text scale 1
/// (iPad Slide Over, ⅓ Split View, small phones).
/// Larger text grows the pill, and the square trailing circle with it, so
/// cells can drop below 44pt there.
///
/// A narrow bar also fits its labels: a label that does not fit its
/// label box first shrinks down to 10pt, and only then ellipsizes.
const double kLiquidNarrowWidth = 340;

/// A floating glass pill of destinations, with an optional separate glass
/// circle for a [LiquidTabAction].
///
/// `LiquidShell` places it for you. Use it directly to build your own
/// chrome. It draws the row only: the caller adds the outer margins.
///
/// The bottom bar fills the width it is given and places a native-sized pill
/// in it: centred, or pinned to the start with the trailing
/// circle at the end. The gaps pass touches through. Selection commits on
/// release, and every slot draws `selectedIcon ?? icon`.
///
/// Standalone use needs a [Directionality] and an [Overlay] above it: the
/// trailing tooltip and the large content viewer (long press at accessibility
/// text sizes) show in the overlay. Inside a route of a `MaterialApp` both
/// are present; in `MaterialApp.builder`, above the `Navigator`, there is no
/// [Overlay]. Debug builds assert both. ([MediaQuery] always comes from the
/// enclosing `View`.)
class LiquidTabBar extends StatelessWidget {
  /// Creates a tab bar.
  const LiquidTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.position = LiquidTabBarPosition.bottom,
    this.trailing,
    this.minimized = false,
    this.onExpand,
    this.strings = const LiquidShellStrings(),
    this.narrow,
    super.key,
  });

  /// All destinations. Only [LiquidPlacement.everywhere] ones are shown.
  final List<LiquidDestination> destinations;

  /// Index into [destinations]. A hidden (sidebar-only) index highlights
  /// nothing.
  final int selectedIndex;

  /// Called with an index into [destinations] when a tab is chosen while
  /// the bar is not minimised: on release of a tap, of a drag (the tab
  /// nearest the lens) or of a flick, and on Enter or Space when a tab has
  /// keyboard focus.
  final ValueChanged<int> onDestinationSelected;

  /// Bottom (compact) or top (regular) layout.
  final LiquidTabBarPosition position;

  /// Optional action in a separate circle at the trailing end.
  final LiquidTabAction? trailing;

  /// Collapses the bottom bar to a 48pt circle with the selected icon. A tap
  /// then calls [onExpand] and does not change the destination.
  final bool minimized;

  /// Called when the minimised bar is tapped. When null, the minimised bar
  /// neither announces an expansion nor carries the expand hint.
  final VoidCallback? onExpand;

  /// Strings for the minimised hint, the expand announcement and badges.
  final LiquidShellStrings strings;

  /// Whether to fit the bottom labels (they shrink to 10pt before they
  /// ellipsize). Null: narrow when
  /// `MediaQuery.sizeOf(context).width` is below [kLiquidNarrowWidth]. The
  /// top bar is the same either way.
  ///
  /// `MediaQuery` is the window. When the bar sits in a pane narrower than
  /// the window (an in-app split view, a fixed-width column), pass [narrow]
  /// yourself, for example `constraints.maxWidth < kLiquidNarrowWidth` from
  /// a `LayoutBuilder` around the pane. The same goes for a `LiquidShell`
  /// `chromeBuilder` that builds its own [LiquidTabBar] while the shell is
  /// narrower than the window: the shell decides from its own width, the
  /// default here from the window's.
  final bool? narrow;

  @override
  Widget build(BuildContext context) {
    assert(
      debugCheckHasDirectionality(context),
      'LiquidTabBar needs a Directionality ancestor.',
    );
    assert(
      debugCheckHasOverlay(context),
      'LiquidTabBar needs an Overlay ancestor.',
    );
    final size = MediaQuery.sizeOf(context);
    final landscape =
        TabBarLandscapeScope.maybeOf(context) ??
        size.width > size.height && size.height < kLiquidCompactHeight;
    final form = position == LiquidTabBarPosition.top
        ? TabBarForm.top
        : landscape
        ? TabBarForm.landscape
        : TabBarForm.compact;
    return GlassTabBar(
      form: form,
      destinations: destinations,
      selectedIndex: selectedIndex,
      onSelect: onDestinationSelected,
      trailing: trailing,
      minimized: minimized && form != TabBarForm.top,
      onCollapsedTap: onExpand,
      strings: strings,
      narrow: narrow ?? size.width < kLiquidNarrowWidth,
    );
  }
}

/// Whether the bottom [LiquidTabBar]s under it take the landscape form.
/// Internal: `LiquidShell` decides it from its own size and breakpoints,
/// which a bar reading the window cannot, and
/// a `chromeBuilder`'s own bar follows it too.
class TabBarLandscapeScope extends InheritedWidget {
  /// Creates the scope.
  const TabBarLandscapeScope({
    required this.landscape,
    required super.child,
    super.key,
  });

  /// The landscape form, or the compact one.
  final bool landscape;

  /// The nearest scope's value, or null outside a shell.
  static bool? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TabBarLandscapeScope>()
      ?.landscape;

  @override
  bool updateShouldNotify(TabBarLandscapeScope oldWidget) =>
      oldWidget.landscape != landscape;
}

/// A glass circle for a [LiquidTabAction]: square, as tall as its row. A
/// press shows the white highlight, not ink; so do
/// keyboard focus, a pointer hovering it and [highlight].
///
/// It takes keyboard focus; Enter and Space activate it.
class LiquidActionCircle extends StatefulWidget {
  /// Creates the circle.
  const LiquidActionCircle({required this.action, this.highlight, super.key});

  /// The action.
  final LiquidTabAction action;

  /// Lights the circle from outside: the tab lens dragged over it.
  final ValueListenable<bool>? highlight;

  @override
  State<LiquidActionCircle> createState() => _LiquidActionCircleState();
}

class _LiquidActionCircleState extends State<LiquidActionCircle> {
  /// The one overlay: pressed, focused, hovered or the outside highlight.
  final ValueNotifier<bool> _lit = ValueNotifier(false);
  bool _pressed = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.highlight?.addListener(_update);
    _update();
  }

  @override
  void didUpdateWidget(LiquidActionCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      oldWidget.highlight?.removeListener(_update);
      widget.highlight?.addListener(_update);
      _update();
    }
  }

  @override
  void dispose() {
    widget.highlight?.removeListener(_update);
    _lit.dispose();
    super.dispose();
  }

  void _update() => _lit.value =
      _pressed || _focused || _hovered || (widget.highlight?.value ?? false);

  void _press(bool down) {
    _pressed = down;
    _update();
  }

  void _activate() => widget.action.onPressed();

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final theme = LiquidGlassTheme.of(context);
    return Semantics(
      container: true,
      button: true,
      label: action.semanticLabel,
      onTap: action.onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: action.semanticLabel,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _activate(),
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) => _activate(),
            ),
          },
          onShowFocusHighlight: (on) {
            _focused = on;
            _update();
          },
          onShowHoverHighlight: (on) {
            _hovered = on;
            _update();
          },
          // On touch-down, as native: no wait for the gesture arena.
          child: Listener(
            onPointerDown: (_) => _press(true),
            onPointerUp: (_) => _press(false),
            onPointerCancel: (_) => _press(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: action.onPressed,
              child: AspectRatio(
                aspectRatio: 1,
                child: TabHoverHighlight(
                  hovered: _lit,
                  child: LiquidGlass(
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: theme.tabIconSize,
                          color: theme.tabForeground,
                        ),
                        child: action.icon,
                      ),
                    ),
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
