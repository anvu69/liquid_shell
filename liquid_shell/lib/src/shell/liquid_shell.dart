import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_shell/src/chrome/sidebar.dart';
import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
import 'package:liquid_shell/src/chrome/tab_bar.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/shell/bar_measure.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/chrome_builder.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// Decides whether a user selection may proceed. Return `false` to cancel.
typedef LiquidBeforeDestinationChange = Future<bool> Function(int index);

/// Horizontal margin of the tab bar rows.
const double _kBarMargin = 16;

/// Space each side of the top pill reserves while the toggle is shown:
/// toggle inset + toggle + gap.
const double _kToggleReserve =
    kSidebarToggleInset + kSidebarToggleSize + kLiquidTabBarTrailingGap;

/// An adaptive navigation shell with no router dependency.
///
/// Below `breakpoints.regular` it floats a glass tab bar at the bottom.
/// From there up it shows a glass sidebar: over the body in portrait (or
/// narrow landscape), beside it in landscape at `breakpoints.tiledSidebar`
/// and wider, with a top tab bar and a toggle while the sidebar is hidden.
///
/// [body] is always the first child of the same subtree, so per-tab state
/// survives every layout change. Keeping branch bodies alive (for example
/// with an `IndexedStack`) is the app's or router's job.
///
/// Like [LiquidTabBar], it needs a [Directionality] and an [Overlay] above
/// it (tooltips and the large content viewer show in the overlay): put it
/// inside a route, for example as a `MaterialApp.home` or a router's shell
/// route, not in `MaterialApp.builder`. Without them the chrome fails a
/// debug assert.
class LiquidShell extends StatefulWidget {
  /// Creates a shell.
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
  final List<LiquidDestination> destinations;

  /// The destination whose content [body] currently shows.
  final int selectedIndex;

  /// Called after a user selects a destination, once any guard has
  /// accepted. Also called when `index == selectedIndex` (reselect); apps
  /// usually pop that branch to its root.
  final ValueChanged<int> onDestinationSelected;

  /// The content: an `IndexedStack`, a router's shell child, and so on. The
  /// shell never rebuilds it under a new parent.
  final Widget body;

  /// Optional async guard, for example "Discard changes?". Runs before every
  /// user selection, including reselect; `false` or a throw cancels it.
  /// Taps while it is pending are ignored.
  final LiquidBeforeDestinationChange? beforeDestinationChange;

  /// Called once when the layout becomes compact while a sidebar-only
  /// destination is selected.
  final ValueChanged<int>? onSelectedDestinationHidden;

  /// Action at the trailing end of the tab bar, also the first sidebar row.
  final LiquidTabAction? tabBarTrailing;

  /// Leading part of the sidebar header row. The shell adds the hide button.
  final Widget? sidebarHeader;

  /// Pinned to the bottom of the sidebar.
  final Widget? sidebarFooter;

  /// Replaces or wraps the default chrome per slot.
  final LiquidChromeBuilder? chromeBuilder;

  /// Width thresholds.
  final LiquidShellBreakpoints breakpoints;

  /// Sidebar width. `0 < sidebarWidth < breakpoints.regular`.
  final double sidebarWidth;

  /// Compact bottom bar only: shrink to the selected tab while content
  /// scrolls down; expand on scroll up or tap.
  final bool minimizeOnScroll;

  /// Every user-visible string.
  final LiquidShellStrings strings;

  @override
  State<LiquidShell> createState() => _LiquidShellState();
}

class _LiquidShellState extends State<LiquidShell>
    implements HideChromeRegistry {
  final ValueNotifier<bool> _minimized = ValueNotifier(false);
  late final GlobalObjectKey _bodyKey = GlobalObjectKey(this);

  /// Settled bar heights per (size class, text scale).
  Map<(LiquidSizeClass, double), double> _measured = const {};
  ShellPresentation? _presentation;
  bool _sidebarVisible = false;
  bool _guardPending = false;
  int _hideRequests = 0;
  bool _hiddenSelectionReported = false;

  @override
  void dispose() {
    _minimized.dispose();
    super.dispose();
  }

  // --- hide chrome -------------------------------------------------------

  @override
  void addHideRequest() => _changeHideRequests(1);

  @override
  void removeHideRequest() => _changeHideRequests(-1);

  void _changeHideRequests(int delta) {
    void apply() {
      if (mounted) setState(() => _hideRequests += delta);
    }

    // Requests arrive while pages build or unmount; the shell cannot be
    // marked dirty then, so they apply right after the frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  // --- sidebar and selection ---------------------------------------------

  void _setSidebarVisible(bool visible) {
    if (_presentation == ShellPresentation.compact) {
      if (kDebugMode) {
        debugPrint(
          'liquid_shell: setSidebarVisible($visible) ignored in the compact '
          'layout.',
        );
      }
      return;
    }
    if (_sidebarVisible != visible) {
      setState(() => _sidebarVisible = visible);
    }
  }

  void _onBarHeight((LiquidSizeClass, double) key, double height) {
    if (!mounted || height <= 0 || _measured[key] == height) return;
    setState(() => _measured = {..._measured, key: height});
  }

  void _onSelect(int index) => unawaited(_select(index));

  /// The one path every user selection takes (§5.5): single-flight guard,
  /// then the callback, then the overlay closes.
  Future<void> _select(int index) async {
    if (_guardPending) return;
    final guard = widget.beforeDestinationChange;
    if (guard != null) {
      _guardPending = true;
      var accepted = false;
      try {
        accepted = await guard(index);
      } on Object catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'liquid_shell',
            context: ErrorDescription('while running beforeDestinationChange'),
          ),
        );
      } finally {
        _guardPending = false;
      }
      if (!mounted || !accepted) return;
    }
    widget.onDestinationSelected(index);
    if (mounted && _presentation == ShellPresentation.overlay) {
      _setSidebarVisible(false);
    }
  }

  void _expand() => _minimized.value = false;

  bool _onScroll(UserScrollNotification notification, LiquidChromeKind kind) {
    // Only vertical scrolling reads as "moving through content"; a carousel
    // or PageView swipe leaves the bar alone.
    if (!widget.minimizeOnScroll ||
        kind != LiquidChromeKind.bottomBar ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _minimized.value = true;
      case ScrollDirection.forward:
        _minimized.value = false;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  /// §5.5 item 6: once per entry into compact, after the frame.
  void _reportHiddenSelection(ShellPresentation presentation, int selected) {
    if (presentation != ShellPresentation.compact) {
      _hiddenSelectionReported = false;
      return;
    }
    final destinations = widget.destinations;
    final hidden =
        destinations.isNotEmpty &&
        destinations[selected].placement == LiquidPlacement.sidebarOnly;
    if (!hidden || _hiddenSelectionReported) return;
    _hiddenSelectionReported = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelectedDestinationHidden?.call(selected);
    });
  }

  bool _debugCheckArguments() {
    final destinations = widget.destinations;
    final length = destinations.length;
    assert(length > 0, 'LiquidShell.destinations must not be empty.');
    final tabs = tabBarIndices(destinations).length;
    assert(
      length == 0 || (tabs >= 1 && tabs <= 5),
      'LiquidShell needs 1 to 5 destinations with LiquidPlacement.everywhere; '
      'got $tabs.',
    );
    assert(
      length == 0 ||
          (widget.selectedIndex >= 0 && widget.selectedIndex < length),
      'LiquidShell.selectedIndex ${widget.selectedIndex} is out of range '
      '0..${length - 1}.',
    );
    assert(
      destinations.every((d) => d.label.isNotEmpty),
      'Every LiquidDestination.label must be non-empty.',
    );
    assert(
      widget.sidebarWidth > 0 &&
          widget.sidebarWidth < widget.breakpoints.regular,
      'LiquidShell.sidebarWidth must be > 0 and < breakpoints.regular.',
    );
    return true;
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    assert(_debugCheckArguments());
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final size = constraints.biggest;
    final presentation = presentationFor(size, widget.breakpoints);
    _sidebarVisible = sidebarVisibleFor(
      previous: _presentation,
      current: presentation,
      visible: _sidebarVisible,
    );
    _presentation = presentation;

    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sizeClass = sizeClassOf(presentation);
    final selected = resolveSelectedIndex(
      widget.selectedIndex,
      widget.destinations.length,
    );
    _reportHiddenSelection(presentation, selected);

    final kind = chromeKindFor(
      presentation: presentation,
      sidebarVisible: _sidebarVisible,
      // Release fallback for an empty list (§7): body only, no chrome.
      hidden: _hideRequests > 0 || widget.destinations.isEmpty,
    );
    final barKey = (sizeClass, media.textScaler.scale(14));
    final bottomGap = bottomGapFor(
      platform: Theme.of(context).platform,
      viewPaddingBottom: media.viewPadding.bottom,
      gestureInsetBottom: media.systemGestureInsets.bottom,
    );
    final insets = chromeInsetsFor(
      kind: kind,
      topPadding: media.padding.top,
      measuredBar: _measured[barKey],
      bottomGap: bottomGap,
    );

    // The body: always the first child, always the same wrappers.
    final tiled = kind == LiquidChromeKind.sidebarTiled;
    final bodyStart = tiled ? widget.sidebarWidth : 0.0;
    var bodyMedia = media.copyWith(
      size: Size(size.width - bodyStart, size.height),
    );
    if (tiled) {
      bodyMedia = bodyMedia.removePadding(removeLeft: !rtl, removeRight: rtl);
    }
    final children = <Widget>[
      PositionedDirectional(
        start: bodyStart,
        top: 0,
        end: 0,
        bottom: 0,
        child: MediaQuery(
          data: bodyMedia,
          child: KeyedSubtree(
            key: _bodyKey,
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) => _onScroll(n, kind),
              child: widget.body,
            ),
          ),
        ),
      ),
    ];

    final sidebarShown =
        kind == LiquidChromeKind.sidebarOverlay ||
        kind == LiquidChromeKind.sidebarTiled;

    LiquidChromeDetails details(
      LiquidChromeSlot slot, {
      bool minimized = false,
    }) => LiquidChromeDetails(
      slot: slot,
      kind: kind,
      destinations: widget.destinations,
      visibleIndices: slot == LiquidChromeSlot.tabBar
          ? tabBarIndices(widget.destinations)
          : [for (var i = 0; i < widget.destinations.length; i++) i],
      selectedIndex: selected,
      select: _onSelect,
      trailing: widget.tabBarTrailing,
      minimized: minimized,
      expand: _expand,
      sidebarVisible: sidebarShown,
      setSidebarVisible: _setSidebarVisible,
      strings: widget.strings,
    );

    Widget slot(LiquidChromeDetails details, Widget defaultChrome) {
      final builder = widget.chromeBuilder;
      if (builder == null) return defaultChrome;
      return Builder(
        builder: (context) => builder(context, details, defaultChrome),
      );
    }

    Widget measured(Widget child) => BarMeasure(
      tag: barKey,
      onHeight: (height) => _onBarHeight(barKey, height),
      child: child,
    );

    switch (kind) {
      case LiquidChromeKind.bottomBar:
        children.add(
          Positioned(
            left: _kBarMargin,
            right: _kBarMargin,
            bottom: bottomGap,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ValueListenableBuilder<bool>(
                valueListenable: _minimized,
                builder: (context, minimized, _) {
                  // The flag is kept when the option or layout changes; it
                  // only stops applying (§5.7).
                  final isMinimized = widget.minimizeOnScroll && minimized;
                  return measured(
                    slot(
                      details(LiquidChromeSlot.tabBar, minimized: isMinimized),
                      LiquidTabBar(
                        destinations: widget.destinations,
                        selectedIndex: selected,
                        onDestinationSelected: _onSelect,
                        trailing: widget.tabBarTrailing,
                        minimized: isMinimized,
                        onExpand: _expand,
                        strings: widget.strings,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      case LiquidChromeKind.topBar || LiquidChromeKind.sidebarOverlay:
        final toggle = kind == LiquidChromeKind.topBar;
        children.add(
          Positioned(
            left: 0,
            right: 0,
            top: media.padding.top + kTopBarGap,
            child: measured(
              slot(
                details(LiquidChromeSlot.tabBar),
                Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            _kBarMargin + (toggle ? _kToggleReserve : 0),
                      ),
                      child: Center(
                        heightFactor: 1,
                        child: LiquidTabBar(
                          destinations: widget.destinations,
                          selectedIndex: selected,
                          onDestinationSelected: _onSelect,
                          position: LiquidTabBarPosition.top,
                          trailing: widget.tabBarTrailing,
                          strings: widget.strings,
                        ),
                      ),
                    ),
                    if (toggle)
                      PositionedDirectional(
                        start: kSidebarToggleInset,
                        top: 0,
                        child: SidebarToggle(
                          onPressed: () => _setSidebarVisible(true),
                          tooltip: widget.strings.showSidebar,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      case LiquidChromeKind.sidebarTiled || LiquidChromeKind.hidden:
        break;
    }

    if (kind == LiquidChromeKind.sidebarOverlay) {
      // Modal for screen readers: ModalBarrier blocks the semantics of every
      // earlier sibling (it wraps itself in BlockSemantics).
      children.add(
        Positioned.fill(
          child: ModalBarrier(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
            semanticsLabel: widget.strings.hideSidebar,
            onDismiss: () => _setSidebarVisible(false),
          ),
        ),
      );
    }

    if (sidebarShown) {
      children.add(
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: widget.sidebarWidth,
          child: slot(
            details(LiquidChromeSlot.sidebar),
            LiquidSidebar(
              destinations: widget.destinations,
              selectedIndex: selected,
              onDestinationSelected: _onSelect,
              onHide: () => _setSidebarVisible(false),
              header: widget.sidebarHeader,
              footer: widget.sidebarFooter,
              trailing: widget.tabBarTrailing,
              width: widget.sidebarWidth,
              strings: widget.strings,
            ),
          ),
        ),
      );
    }

    // System back closes the overlay sidebar before it pops anything (Q10).
    // The route calls every PopScope on it, so a back blocked by another one
    // (an exit wrapper, an unsaved form) lands here too: act only while the
    // overlay is what blocks it.
    return PopScope(
      canPop: kind != LiquidChromeKind.sidebarOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && kind == LiquidChromeKind.sidebarOverlay) {
          _setSidebarVisible(false);
        }
      },
      child: ShellScopeMarker(
        data: LiquidShellScopeData(
          sizeClass: sizeClass,
          chromeKind: kind,
          chromeInsets: insets,
          sidebarVisible: sidebarShown,
          setSidebarVisible: _setSidebarVisible,
        ),
        registry: this,
        // One backdrop read for all chrome glass (budget rule, §5.8).
        child: BackdropGroup(child: Stack(children: children)),
      ),
    );
  }
}
