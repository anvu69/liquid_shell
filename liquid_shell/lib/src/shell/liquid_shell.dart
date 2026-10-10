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
import 'package:liquid_shell/src/native/native_chrome.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell/src/native/native_layout.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/shell/bar_measure.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/chrome_builder.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Decides whether a user selection may proceed. Return `false` to cancel.
typedef LiquidBeforeDestinationChange = Future<bool> Function(int index);

/// Horizontal margin of the tab bar rows.
const double _kBarMargin = 16;

/// Horizontal margin of the bottom row below [kLiquidNarrowWidth] (Q17).
const double _kNarrowBarMargin = 8;

/// Space each side of the top pill reserves while the toggle is shown:
/// toggle inset + toggle + gap.
const double _kToggleReserve =
    kSidebarToggleInset + kSidebarToggleSize + kLiquidTabBarTrailingGap;

/// The labels that occur more than once in [destinations], quoted.
String _repeatedLabels(List<LiquidDestination> destinations) {
  final seen = <String>{};
  return {
    for (final d in destinations)
      if (!seen.add(d.label)) '"${d.label}"',
  }.join(', ');
}

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
///
/// On iOS 26, on iPhone and iPad, in an app that opted in, the chrome is
/// the platform's own `UITabBarController` tab bar and sidebar
/// ([nativeChrome]); everywhere else it is drawn in Flutter.
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
    this.nativeChrome = LiquidNativeChrome.auto,
    this.nativeSidebarFooter,
    super.key,
  });

  /// All destinations, in display order. Indices refer to this list.
  ///
  /// Labels must be unique (asserted in debug): a label is the semantics
  /// label of its cell, and [beforeDestinationChange] re-finds a pending
  /// selection by label.
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
  ///
  /// If [destinations] changes while the guard is pending, an accepted
  /// selection goes to the destination with the same label (labels must be
  /// unique), or is dropped when that label is gone.
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
  ///
  /// The result sits in a transparent `Material`, like the default chrome,
  /// so its text gets the theme's `bodyMedium` style and ink splashes have a
  /// target without a `Scaffold` above the shell.
  ///
  /// The shell's accessibility support (semantics, 44pt hit targets, the
  /// large content viewer, the overlay's modal barrier) belongs to the
  /// default chrome. A replacement must provide its own.
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

  /// Whether the platform may draw the chrome (spec P2 §5.1). With
  /// [LiquidNativeChrome.auto] the shell uses native chrome when the
  /// platform installed it, its width is regular, it has no [chromeBuilder],
  /// and every destination (and [tabBarTrailing]) has an `sfSymbol`.
  /// Native chrome shows neither [sidebarHeader] nor [sidebarFooter]; see
  /// [nativeSidebarFooter].
  ///
  /// A window has one native chrome, and the newest shell owns it. A shell
  /// nested in another shell's body (sub-tabs) would take it from the outer
  /// shell, which then shows no navigation: give the inner shell
  /// [LiquidNativeChrome.off].
  final LiquidNativeChrome nativeChrome;

  /// The native sidebar's footer. The Flutter sidebar uses [sidebarFooter].
  final LiquidNativeSidebarFooter? nativeSidebarFooter;

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

  // --- native chrome (spec P2 §7) ----------------------------------------
  final NativeChromeHost _host = NativeChromeHost.instance;
  final WindowControlsSource _windowControls = WindowControlsSource.instance;
  NativeChromeClaim? _claim;
  ModalRoute<Object?>? _route;
  bool _routeCurrent = true;
  bool _coveredByPush = false;
  bool _tickersOff = false;
  bool _nativeEngaged = false;
  LiquidNativeShellState? _nativeState;
  LiquidNativeChromeConfig? _nativeConfig;
  bool _nativeSendScheduled = false;
  bool _forceNativeSend = false;

  @override
  void initState() {
    super.initState();
    _windowControls.acquire();
    _windowControls.value.addListener(_rebuild);
    _host.addListener(_rebuild);
    _host.state.addListener(_rebuild);
    _syncClaim();
  }

  @override
  void didUpdateWidget(LiquidShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nativeChrome != widget.nativeChrome) _syncClaim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Two signals that a page covers the shell (spec P2 §7.4):
    // - a page route pushed above drives our secondary animation (dialogs
    //   and popups do not): forward or completed hides from the first frame
    //   of the push;
    // - the Overlay turns our tickers off once an opaque route covers us.
    //   That also catches the routes that never drive the secondary
    //   animation (a fullscreenDialog, a PageRouteBuilder, a router's
    //   custom transition page) and an offstage branch, as P1's
    //   LiquidHideChrome does.
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _route?.secondaryAnimation?.removeStatusListener(_onCoverChanged);
      _route = route;
      route?.secondaryAnimation?.addStatusListener(_onCoverChanged);
    }
    _routeCurrent = route?.isCurrent ?? true;
    _coveredByPush =
        route?.secondaryAnimation?.status.isForwardOrCompleted ?? false;
    // A dependency: the change rebuilds us. The layout builder still runs
    // under an obstructed entry (Flutter >= 3.44), so the config is sent.
    _tickersOff = !TickerMode.valuesOf(context).enabled;
  }

  void _onCoverChanged(AnimationStatus status) {
    final covered = status.isForwardOrCompleted;
    if (covered != _coveredByPush && mounted) {
      setState(() => _coveredByPush = covered);
    }
  }

  /// Whether a page covers the shell, so the native chrome must hide.
  bool get _covered => _coveredByPush || _tickersOff;

  void _rebuild() {
    if (mounted) _outsideBuild(() => mounted ? setState(() {}) : null);
  }

  /// Claims the native chrome in `auto`, gives it back in `off`.
  void _syncClaim() {
    if (widget.nativeChrome == LiquidNativeChrome.auto) {
      _claim ??= _host.claim(_onNativeEvent);
    } else {
      _claim?.release();
      _claim = null;
    }
  }

  @override
  void dispose() {
    _route?.secondaryAnimation?.removeStatusListener(_onCoverChanged);
    _claim?.release();
    _host.removeListener(_rebuild);
    _host.state.removeListener(_rebuild);
    _windowControls.value.removeListener(_rebuild);
    _windowControls.release();
    _minimized.dispose();
    super.dispose();
  }

  /// Native taps (spec P2 §7.3). A destination tap takes the same path as
  /// a Flutter tap, guard included; native does not select until we answer.
  void _onNativeEvent(LiquidNativeEvent event) {
    if (!mounted) return;
    switch (event) {
      case LiquidNativeDestinationTapped(:final index):
        // Checked at the boundary: an index from the platform.
        if (index < 0 || index >= widget.destinations.length) return;
        unawaited(_select(index).whenComplete(_resyncNativeAfterFrame));
      case LiquidNativeTrailingTapped():
        widget.tabBarTrailing?.onPressed();
      case LiquidNativeFooterTapped():
        widget.nativeSidebarFooter?.onPressed();
      case LiquidNativeStateChanged() || LiquidWindowControlsChanged():
        break;
    }
  }

  /// Sends the latest native config after the frame: never during build,
  /// at most once per frame, deduplicated by the host.
  void _scheduleNativeSend(LiquidNativeChromeConfig config) {
    _nativeConfig = config;
    if (_nativeSendScheduled) return;
    _nativeSendScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _nativeSendScheduled = false;
      final latest = _nativeConfig;
      final force = _forceNativeSend;
      _forceNativeSend = false;
      if (mounted && latest != null) _claim?.update(latest, force: force);
    });
  }

  /// After every native destination tap, whatever came of it (accepted,
  /// refused, dropped by single flight or because the destination vanished,
  /// or accepted but ignored by the app): the native chrome may already
  /// show the tapped tab (a selection UIKit made without asking), so the
  /// next frame's config is sent even when it equals the last one.
  void _resyncNativeAfterFrame() {
    if (!mounted) return;
    _forceNativeSend = true;
    _rebuild();
  }

  // --- hide chrome -------------------------------------------------------

  @override
  void addHideRequest() => _changeHideRequests(1);

  @override
  void removeHideRequest() => _changeHideRequests(-1);

  void _changeHideRequests(int delta) => _outsideBuild(() {
    if (mounted) setState(() => _hideRequests += delta);
  });

  /// Runs [apply] now, or right after the frame when called during one.
  ///
  /// Pages ask from `initState`, `build` or `dispose`, which run while the
  /// shell lays out its body; the shell cannot be marked dirty then.
  void _outsideBuild(VoidCallback apply) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  // --- sidebar and selection ---------------------------------------------

  /// The scope's and the chrome's setter. Safe from a page's `initState` or
  /// `build`: it then applies after the frame. Idempotent.
  void _setSidebarVisible(bool visible) =>
      _outsideBuild(() => _applySidebarVisible(visible));

  void _applySidebarVisible(bool visible) {
    if (!mounted) return;
    if (_nativeEngaged) {
      _claim?.setSidebarVisible(visible: visible);
      return;
    }
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
    if (!mounted || _measured[key] == height) return;
    setState(() => _measured = {..._measured, key: height});
  }

  void _onSelect(int index) => unawaited(_select(index));

  /// The one path every user selection takes (§5.5): single-flight guard,
  /// then the callback, then the overlay closes.
  Future<void> _select(int requestedIndex) async {
    var index = requestedIndex;
    if (_guardPending) return;
    final guard = widget.beforeDestinationChange;
    if (guard != null) {
      final requested = widget.destinations[index].label;
      _setGuardPending(true);
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
        _setGuardPending(false);
      }
      if (!mounted) return;
      if (!accepted) return;
      // The list may have changed while the guard ran: find the requested
      // destination in the current one, or drop the selection.
      final current = _currentIndexOf(requested, index);
      if (current == null) return;
      index = current;
    }
    widget.onDestinationSelected(index);
    if (!mounted) return;
    if (_nativeEngaged) {
      if (_nativeState?.sidebar == LiquidNativeSidebar.overlay) {
        _setSidebarVisible(false);
      }
    } else if (_presentation == ShellPresentation.overlay) {
      _setSidebarVisible(false);
    }
  }

  /// The native chrome is inert while a guard runs (spec P2 §7.3): its
  /// dialog is drawn in the Flutter view, under an overlay sidebar, which
  /// UIKit closes for a non-interactive config.
  void _setGuardPending(bool pending) {
    _guardPending = pending;
    if (_nativeEngaged) _rebuild();
  }

  /// Where the destination labelled [label], once at [index], is now: the
  /// same index when it is still there, else its only other position, else
  /// null. Matched by label because apps rebuild destinations (new badge,
  /// non-const icon) and `==` would then miss an unchanged one.
  int? _currentIndexOf(String label, int index) {
    final destinations = widget.destinations;
    if (index < destinations.length && destinations[index].label == label) {
      return index;
    }
    final matches = [
      for (final (i, d) in destinations.indexed)
        if (d.label == label) i,
    ];
    return matches.length == 1 ? matches.single : null;
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
      destinations.map((d) => d.label).toSet().length == length,
      'LiquidShell destination labels must be unique; '
      '${_repeatedLabels(destinations)} repeats. A label is the semantics '
      'label of its cell, and a guarded selection re-finds its destination '
      'by label.',
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
    assert(_debugCheckArguments(), 'invalid LiquidShell arguments');
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final size = constraints.biggest;
    final presentation = presentationFor(size, widget.breakpoints);
    final native = _resolveNative(context, presentation);
    if (native != null) return native;
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
      // The same transparent Material the default chrome sits in: custom
      // chrome has no Scaffold above it, so without one its Text would get
      // MaterialApp's red fallback style and its InkWells no ink target.
      return Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (context) => builder(context, details, defaultChrome),
        ),
      );
    }

    Widget measured(Widget child) => BarMeasure(
      tag: barKey,
      onHeight: (height) => _onBarHeight(barKey, height),
      child: child,
    );

    switch (kind) {
      case LiquidChromeKind.bottomBar:
        // Q17: narrow shells trade margin for 44pt-wide cells.
        final narrow = size.width < kLiquidNarrowWidth;
        final margin = narrow ? _kNarrowBarMargin : _kBarMargin;
        children.add(
          Positioned(
            left: margin,
            right: margin,
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
                        narrow: narrow,
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
        // iPadOS 26 windowed: the row starts past the window controls; the
        // pill keeps equal reserves on both sides so it stays centred.
        final indent = _windowControls.value.value.indentFor(
          rowTop: kTopBarGap,
        );
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
                            _kBarMargin +
                            (toggle ? _kToggleReserve : 0) +
                            indent,
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
                        start: kSidebarToggleInset + indent,
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
          windowControls: _windowControls.value.value,
        ),
        registry: this,
        // One backdrop read for all chrome glass (budget rule, §5.8).
        child: BackdropGroup(child: Stack(children: children)),
      ),
    );
  }

  /// The native chrome layout, or null to draw Flutter chrome (spec P2 §7).
  ///
  /// Also sends this shell's config to the platform when it owns the
  /// native chrome, engaged or not, so the platform hides it when this
  /// shell falls back to Flutter chrome.
  Widget? _resolveNative(BuildContext context, ShellPresentation presentation) {
    final claim = _claim;
    final state = _host.state.value;
    _nativeState = state;
    final owner = claim?.isOwner ?? false;
    final describable = nativeDescribable(
      widget.destinations,
      widget.tabBarTrailing,
    );
    final possible = nativeChromePossible(
      mode: widget.nativeChrome,
      hasChromeBuilder: widget.chromeBuilder != null,
      describable: describable,
    );
    final engaged = nativeChromeEngaged(
      mode: widget.nativeChrome,
      owner: owner,
      state: state,
      hasChromeBuilder: widget.chromeBuilder != null,
      describable: describable,
    );
    // Only for a shell that asked for native chrome and could use it.
    if (!describable &&
        widget.nativeChrome == LiquidNativeChrome.auto &&
        widget.chromeBuilder == null &&
        (state?.installed ?? false)) {
      NativeChromeHost.debugLogOnce(
        'notDescribable',
        'liquid_shell: native chrome needs an sfSymbol on every destination '
            'and on tabBarTrailing; drawing Flutter chrome.',
      );
    }
    final wasEngaged = _nativeEngaged;
    _nativeEngaged = engaged;
    if (engaged != wasEngaged) _presentation = null;
    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final selected = resolveSelectedIndex(
      widget.selectedIndex,
      widget.destinations.length,
    );
    if (owner) {
      final theme = Theme.of(context);
      _scheduleNativeSend(
        nativeConfigFor(
          engaged: engaged,
          destinations: widget.destinations,
          selectedIndex: selected,
          trailing: widget.tabBarTrailing,
          footer: widget.nativeSidebarFooter,
          tint: theme.colorScheme.primary,
          dark: theme.brightness == Brightness.dark,
          rtl: rtl,
          // The compact bar is drawn above the Flutter view: it would
          // cover the bottom of a sheet or dialog drawn there, so it hides
          // while one is above the shell. The top bar and sidebar only
          // turn inert (§7.4).
          hidden:
              _hideRequests > 0 ||
              _covered ||
              ((state?.compact ?? false) && !_routeCurrent),
          interactive: _routeCurrent && !_guardPending,
        ),
      );
    }
    // Pending: the platform may install native chrome (any iOS 26 iPhone
    // or iPad, owner D1) but has not answered yet, and this shell would use
    // it. Draw no chrome rather than flash the Flutter one (a frame or
    // two). A shell that could not use native chrome anyway (a missing
    // sfSymbol, a chromeBuilder) draws Flutter chrome from its first frame.
    final pending =
        possible &&
        owner &&
        state == null &&
        LiquidShellPlatform.instance.supportsNativeChrome;
    // Standby: another shell (pushed above, or nested) owns the native
    // chrome, which this one would otherwise use. Draw no chrome, so no
    // Flutter chrome shows beside the native one while the other shell's
    // route slides in or out; this one engages when it owns it again.
    final standby = possible && !owner && (state?.installed ?? false);
    if (!engaged && !pending && !standby) return null;

    final kind = engaged
        ? nativeChromeKind(state: state!, hidden: _hideRequests > 0)
        : LiquidChromeKind.hidden;
    final insets = nativeChromeInsets(kind: kind, padding: media.padding);
    // UIKit's size class decides the bar once it has answered; before
    // that, the shell's own width.
    final sizeClass = engaged
        ? (state!.compact ? LiquidSizeClass.compact : LiquidSizeClass.regular)
        : sizeClassOf(presentation);
    // UIKit's compact bar hides sidebar-only destinations, as P1's does.
    if (engaged) {
      _reportHiddenSelection(
        sizeClass == LiquidSizeClass.compact
            ? ShellPresentation.compact
            : ShellPresentation.overlay,
        selected,
      );
    }
    // Tiled: UIKit does not resize the Flutter view; it reports the
    // sidebar's width as the start padding. Make it real width here.
    final tiled = kind == LiquidChromeKind.sidebarTiled;
    final bodyStart = tiled
        ? (rtl ? media.padding.right : media.padding.left)
        : 0.0;
    var bodyMedia = media.copyWith(
      size: Size(media.size.width - bodyStart, media.size.height),
    );
    if (tiled) {
      bodyMedia = bodyMedia.removePadding(removeLeft: !rtl, removeRight: rtl);
    }
    final overlay = kind == LiquidChromeKind.sidebarOverlay;
    return PopScope(
      // System back closes an overlay sidebar first (P1 Q10, natively too).
      canPop: !overlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && overlay) _setSidebarVisible(false);
      },
      child: ShellScopeMarker(
        data: LiquidShellScopeData(
          sizeClass: sizeClass,
          chromeKind: kind,
          chromeInsets: insets,
          sidebarVisible: state?.sidebarVisible ?? false,
          setSidebarVisible: _setSidebarVisible,
          nativeChrome: engaged,
          // UIKit's top bar and sidebar make room for the cluster; the
          // body starts below or beside them (spec P2 §8.3). The compact
          // bar is at the bottom: the top is the body's to clear.
          windowControls: engaged && sizeClass == LiquidSizeClass.regular
              ? LiquidWindowControls.zero
              : _windowControls.value.value,
        ),
        registry: this,
        // The same chain as the Flutter layout (BackdropGroup → Stack →
        // body first), so switching between native and Flutter chrome
        // never moves the body (§5.6).
        child: BackdropGroup(
          child: Stack(
            children: [
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
                      onNotification: (n) => false,
                      child: widget.body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
