import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/sidebar.dart';
import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
import 'package:liquid_shell/src/chrome/tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/glass_scope.dart';
import 'package:liquid_shell/src/glass/scroll_pocket.dart';
import 'package:liquid_shell/src/native/native_chrome.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell/src/native/native_layout.dart';
import 'package:liquid_shell/src/native/native_minimize.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/search/search.dart';
import 'package:liquid_shell/src/search/search_chrome.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/search/search_layout.dart';
import 'package:liquid_shell/src/search/shell_search.dart';
import 'package:liquid_shell/src/shell/bar_measure.dart';
import 'package:liquid_shell/src/shell/branch_navigators.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/chrome_builder.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Decides whether a user selection may proceed. Return `false` to cancel.
typedef LiquidBeforeDestinationChange = Future<bool> Function(int index);

/// Horizontal margin of the top tab bar row.
const double _kBarMargin = 16;

/// Horizontal margin of the bottom tab bar row.
const double _kBottomBarMargin = TabMetrics.margin;

/// Horizontal margin of the bottom row below [kLiquidNarrowWidth].
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
/// Below `breakpoints.regular`, and in landscape lower than
/// `breakpoints.compactHeight` (phones), it floats a glass tab bar at the
/// bottom: icon over label, or icon beside label in landscape. From there
/// up it shows a glass sidebar: over the body in portrait (or narrow
/// landscape), beside it in landscape at `breakpoints.tiledSidebar` and
/// wider, with a top tab bar and a toggle while the sidebar is hidden.
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
    this.search,
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

  /// Compact bottom bar only, Flutter-drawn or native (iOS 26+): shrink to
  /// the selected tab while the body scrolls down. Scrolling back up in
  /// mid-content does not expand it; a fling or a programmatic scroll that
  /// ends at the top does, as does a tap on the minimized circle. A change
  /// of the selected destination expands the Flutter bar, and the native
  /// bar too unless the change selects the search destination (UIKit keeps
  /// its own form there). Neither bar minimizes while the search
  /// destination is selected, nor at regular width. With native chrome,
  /// `true` also shows UIKit's bottom scroll-edge effect under the compact
  /// bar (a soft blur of the body there); `false` hides it.
  final bool minimizeOnScroll;

  /// Every user-visible string.
  final LiquidShellStrings strings;

  /// Whether the platform may draw the chrome. With
  /// [LiquidNativeChrome.auto] the shell uses native chrome when the
  /// platform installed it, it has no [chromeBuilder], and every
  /// destination (and [tabBarTrailing]) has an `sfSymbol`. In debug, a shell
  /// that only lacks symbols logs one line naming them.
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

  /// The search tab's field. Required with a destination whose role is
  /// [LiquidDestinationRole.search], and only then. Search is a tab: its
  /// page is that destination's page, never a page pushed above the shell.
  final LiquidSearch? search;

  @override
  State<LiquidShell> createState() => _LiquidShellState();
}

class _LiquidShellState extends State<LiquidShell>
    implements HideChromeRegistry, PageRegistry, NestedShellBack {
  final ValueNotifier<bool> _minimized = ValueNotifier(false);
  late final GlobalObjectKey _bodyKey = GlobalObjectKey(this);

  /// Settled bar heights per (size class, text scale).
  /// Measured bar heights by size class, bar form and text scale: each
  /// orientation keeps its own, so a rotation never starts from the other
  /// one's height.
  Map<(LiquidSizeClass, TabBarForm, double), double> _measured = const {};
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
  LiquidNativeChromeConfig Function()? _nativeConfig;
  bool _nativeSendScheduled = false;
  bool _forceNativeSend = false;
  bool _symbolHintLogged = false;
  // The compact native bar's bottom inset (Flutter's bottom view padding
  // while the bar shows) and the window size it was read at.
  double? _barBottom;
  Size? _barSize;

  // --- the native bar's minimize (spec VK-600 §9) --------------------------
  final MinimizeScrollTracker _minimizeScroll = MinimizeScrollTracker();
  bool _minimizeActive = false;
  bool _minimizeSendScheduled = false;
  bool _minimizeForce = false;
  // This shell's first activation expands the native bar after its offset:
  // a bar an earlier shell left minimized (a new key, a hot restart) does
  // not follow a proxy's jump to the top.
  bool _minimizeEverActive = false;
  bool _minimizeExpandPending = false;
  (int, double)? _minimizeSent;
  // The last config handed to the claim: a new one with other tabs may
  // rebuild the native tab hosts, at offset 0.
  LiquidNativeChromeConfig? _minimizeConfig;

  // --- search and pages (spec P3b §8) --------------------------------------
  late final ShellSearch _search = ShellSearch(
    claim: () => _claim,
    onChange: _rebuild,
  );
  final List<_PageRecord> _pageRecords = [];
  final Map<int, List<LiquidNativePage>> _pageStacks = {};
  // The records behind each sent stack, kept while no page is on top.
  final Map<int, List<_PageRecord>> _stackRecords = {};
  bool _nativePageBar = false;
  bool _searchDeactivatedForRoute = false;
  // The scroll offset native has for the top page (spec P3b §7.7).
  _PageRecord? _scrollRecord;
  double _scrollSent = 0;
  // The top page that had no offset at the last sync (N-4).
  _PageRecord? _scrollWaited;
  bool _scrollScheduled = false;
  // The destination the fallback's collapsed circle returns to.
  int _previousIndex = 0;
  // The idle ⌕, bar-local: a lens drag released over it selects search
  // (spec VK-503 §8.8).
  Rect _searchTargetRect = Rect.zero;
  late final TabDragTarget _searchTarget = TabDragTarget(
    rect: () => _searchTargetRect,
    onRelease: _selectSearch,
  );

  // --- the selected tab's navigator (VK-567) -------------------------------
  // Found after the frame; see [_backScope].
  List<BranchNavigator> _branches = const [];
  bool _branchCanPop = false;
  bool _branchScanScheduled = false;
  bool _branchCheckArmed = false;

  // What the last build's [_backScope] blocks for (VK-774).
  bool _backOverlay = false;
  bool _backSearch = false;

  @override
  void initState() {
    super.initState();
    _windowControls.acquire();
    _windowControls.value.addListener(_rebuild);
    _host.addListener(_rebuild);
    _host.state.addListener(_rebuild);
    _syncClaim();
    _configureSearch();
    _scheduleBranchScan();
  }

  @override
  void didUpdateWidget(LiquidShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nativeChrome != widget.nativeChrome) _syncClaim();
    // A selection change expands the minimized bar (spec VK-503 §10, Q7),
    // and puts another tab's navigator on screen.
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _minimized.value = false;
      _scheduleBranchScan();
      // The new tab's proxy takes the pan: native gets its offset (§9.2).
      _minimizeForce = true;
      _scheduleMinimizeSend();
    }
    for (
      var i = widget.destinations.length;
      i < oldWidget.destinations.length;
      i++
    ) {
      _minimizeScroll.forget(i);
    }
    _configureSearch();
  }

  // A new key builds the next shell before this one is disposed, and a
  // GlobalKey move takes this one out and back: the controller takes one
  // shell at a time.
  @override
  void deactivate() {
    _search.detach();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _configureSearch();
    _scheduleBranchScan();
  }

  void _configureSearch() => _search.configure(
    widget.search,
    hasSearchDestination: searchIndexOf(widget.destinations) != null,
  );

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
    _searchTarget.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Native taps. A destination tap takes the same path as
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
      case LiquidNativeSearchTextChanged() ||
          LiquidNativeSearchActiveChanged() ||
          LiquidNativeSearchSubmitted() ||
          LiquidNativeSearchScopeChanged() ||
          LiquidNativeSearchFieldChanged():
        _search.onNativeEvent(event);
      case LiquidNativeBackTapped(:final tab):
        _onNativeBack(tab);
      case LiquidNativePopToPage(:final tab, :final index):
        unawaited(_onNativePopTo(tab, index));
      case LiquidNativeStateChanged(:final state):
        // After the host's forced resend. The same state as the last build
        // saw is a reconnected scene, whose field lost the text.
        _search.replay(reconnect: state == _nativeState);
        // A reconnected scene's tab hosts start at offset 0, too.
        _minimizeForce = true;
        _scheduleMinimizeSend();
        _rebuild();
      case LiquidWindowControlsChanged():
        break;
    }
  }

  /// Sends the latest native config after the frame: never during build,
  /// at most once per frame, deduplicated by the host. [config] is built
  /// then, once the body has built too (the page stack).
  void _scheduleNativeSend(LiquidNativeChromeConfig Function() config) {
    _nativeConfig = config;
    if (_nativeSendScheduled) return;
    _nativeSendScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _nativeSendScheduled = false;
      final latest = _nativeConfig;
      final force = _forceNativeSend;
      _forceNativeSend = false;
      if (mounted && latest != null) {
        final config = latest();
        _claim?.update(config, force: force);
        _search.afterConfigSent();
        // New native tab hosts start at offset 0: the offset follows the
        // config that may have built them, never precedes it.
        if (nativeTabsMayRebuild(_minimizeConfig, config)) {
          _minimizeForce = true;
          _sendMinimize();
        }
        _minimizeConfig = config;
      }
    });
  }

  // --- pages (PageRegistry) -----------------------------------------------
  //
  // Pages register, update and leave while the body builds, after the
  // shell's own build: every change rebuilds the shell after the frame
  // (`_rebuild`). The stack is computed after the frame, when the config
  // is sent (spec P3b §8.4), never in the build: on a tab switch the
  // pages of both tabs only hear of it once the shell has built, and the
  // tab just left would still say its page is the one on screen (VK-491).

  @override
  PageHandle registerPage(PageEntry entry) {
    final record = _PageRecord(this, entry);
    _pageRecords.add(record);
    _rebuild();
    return record;
  }

  /// The page the user sees in the selected tab, if it is a LiquidPage.
  _PageRecord? get _topRecord {
    _PageRecord? top;
    for (final record in _pageRecords) {
      final entry = record.entry;
      if (entry.isTop && (top == null || entry.sequence > top.entry.sequence)) {
        top = record;
      }
    }
    return top;
  }

  PageEntry? get _topPageEntry => _topRecord?.entry;

  /// The selected tab's stack, root first. With no page on top (a page
  /// above the shell, a sheet in the tab's navigator) the last stack stays,
  /// less the pages that left: emptying it would pop native to the root,
  /// and push everything again, animated, when the cover goes.
  List<_PageRecord> _stackFor(int tab) {
    final records = Map<PageEntry, _PageRecord>.identity();
    for (final record in _pageRecords) {
      records[record.entry] = record;
    }
    final stack = [
      for (final entry in pageStackFor(records.keys, isTop: (e) => e.isTop))
        records[entry]!,
    ];
    if (stack.isNotEmpty) return stack;
    final kept = _stackRecords[tab] ?? const <_PageRecord>[];
    // Only a cover keeps it (spec §8.4 rule 3 otherwise: no stack):
    // - the shell's route is covered (a page or dialog above the shell);
    // - the last top page is still current in its navigator, so only
    //   something outside it hides it (also the frame where the shell is
    //   uncovered before that page has heard of it);
    // - a popup route (a sheet) is above it: it stays on screen.
    // A page pushed in the tab without LiquidPage covers it opaquely and
    // is none of these.
    final top = kept.isEmpty ? null : kept.last;
    final keep =
        !_routeCurrent ||
        _covered ||
        (top != null &&
            ((top.entry.route?.isCurrent ?? false) || top.entry.onScreen));
    if (!keep) return const [];
    return [
      for (final record in kept)
        if (_pageRecords.contains(record) &&
            (record.entry.route?.isActive ?? false))
          record,
    ];
  }

  /// Computes [tab]'s stack for the config. After the frame: the pages
  /// have heard of this frame's changes by then.
  void _updatePageStack(int tab) {
    final stack = _stackFor(tab);
    _stackRecords[tab] = stack;
    _pageStacks[tab] = [
      for (final record in stack)
        LiquidNativePage(
          title: record.entry.title,
          largeTitle: record.entry.largeTitle,
        ),
    ];
  }

  /// The native back button: a proposal for the selected
  /// tab's top page. `maybePop` runs its PopScope. Under a sheet in the
  /// tab's navigator the kept stack shows a live back button: it pops the
  /// sheet, as the sheet's barrier does. Above the shell the chrome is not
  /// interactive, and nothing pops.
  void _onNativeBack(int tab) {
    if (tab !=
        resolveSelectedIndex(
          widget.selectedIndex,
          widget.destinations.length,
        )) {
      return;
    }
    final kept = _routeCurrent && !_covered
        ? _stackRecords[tab]?.lastOrNull?.entry
        : null;
    unawaited(_maybePop((_topPageEntry ?? kept)?.navigator));
  }

  // A future of our own to hand to `unawaited`: newer SDKs mark `maybePop`
  // `@awaitNotRequired` (unnecessary_unawaited) while 3.44 still asks for
  // it (discarded_futures).
  static Future<void> _maybePop(NavigatorState? navigator) async {
    await navigator?.maybePop();
  }

  /// UIKit's other pops: the back button's long-press
  /// menu, an accessibility escape, a pop-to-root. Native did not pop; the
  /// pages above [index] pop here, top first, each through its PopScope.
  /// A refused pop ends it, and the native stack follows what is left.
  /// One page down is exactly a back tap.
  Future<void> _onNativePopTo(int tab, int index) async {
    final stack = _stackRecords[tab];
    if (stack == null || index < 0 || index >= stack.length - 1) return;
    if (index == stack.length - 2) return _onNativeBack(tab);
    if (tab !=
            resolveSelectedIndex(
              widget.selectedIndex,
              widget.destinations.length,
            ) ||
        !_routeCurrent ||
        _covered) {
      return;
    }
    for (final record in stack.sublist(index + 1).reversed) {
      final route = record.entry.route;
      final navigator = record.entry.navigator;
      if (!mounted || route == null || navigator == null) return;
      if (!route.isActive) continue;
      // Only the top page pops: something else on top (a sheet) ends it.
      if (!route.isCurrent) return;
      await navigator.maybePop();
      if (route.isActive) return;
    }
  }

  /// Sends the top page's offset after the frame: one message per frame,
  /// only for the top page of a tab with a native bar.
  void _scheduleScrollSync() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _syncScroll())
      ..ensureVisualUpdate();
  }

  void _syncScroll() {
    _scrollScheduled = false;
    if (!mounted) return;
    final top = _nativePageBar ? _topRecord : null;
    if (top == null) {
      _scrollRecord = null;
      return;
    }
    // Not laid out yet (a new page, or one moved with a GlobalKey): its
    // scroll position reports its offset after its first layout, in that
    // frame's post-frame callbacks. Still nothing a frame later: the page
    // has no scroll view and sits at its top. Native may reuse a host for
    // it whose proxy keeps the old offset, so 0 is sent.
    var offset = top.offset;
    if (offset == null) {
      if (!identical(top, _scrollWaited)) {
        _scrollWaited = top;
        _scheduleScrollSync();
        return;
      }
      offset = 0;
    }
    // A new top page is always sent, once per navigation: native may
    // reuse a host for it (a same-count stack, pushReplacement) whose
    // proxy keeps the old offset.
    if (identical(top, _scrollRecord) && offset == _scrollSent) return;
    _scrollRecord = top;
    _scrollSent = offset;
    _claim?.setPageScroll(
      tab: resolveSelectedIndex(
        widget.selectedIndex,
        widget.destinations.length,
      ),
      offset: offset,
    );
  }

  /// Whether the shell drives the native bar's minimize now. On becoming
  /// active, the selected tab's offset is sent once, even if unchanged: the
  /// native side may have reset it. The first time, the bar expands after it.
  void _setMinimizeActive(bool active) {
    if (active && !_minimizeActive) {
      _minimizeForce = true;
      if (!_minimizeEverActive) {
        _minimizeEverActive = true;
        _minimizeExpandPending = true;
      }
      _scheduleMinimizeSend();
    }
    _minimizeActive = active;
  }

  /// Sends the selected tab's minimize offset after the frame: one message
  /// per frame at most, like [_scheduleScrollSync].
  void _scheduleMinimizeSend() {
    if (_minimizeSendScheduled) return;
    _minimizeSendScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _minimizeSendScheduled = false;
        _sendMinimize();
      })
      ..ensureVisualUpdate();
  }

  /// Sends (selected tab, its offset) while active, when forced or when it
  /// differs from the last one sent.
  void _sendMinimize() {
    final force = _minimizeForce;
    _minimizeForce = false;
    if (!mounted || !_minimizeActive) return;
    final tab = resolveSelectedIndex(
      widget.selectedIndex,
      widget.destinations.length,
    );
    final sent = (tab, _minimizeScroll.offsetOf(tab));
    if (!force && sent == _minimizeSent) return;
    _minimizeSent = sent;
    _claim?.setMinimizeScroll(tab: sent.$1, offset: sent.$2);
    if (_minimizeExpandPending) {
      _minimizeExpandPending = false;
      _claim?.expandTabBar();
    }
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

  // --- the selected tab's navigator (VK-567) -------------------------------

  /// Finds the selected tab's navigator after the frame, once the body has
  /// built: a new shell, a new selection, a moved shell.
  void _scheduleBranchScan() {
    if (_branchScanScheduled) return;
    _branchScanScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _branchScanScheduled = false;
        _scanBranches();
      })
      ..ensureVisualUpdate();
  }

  /// A navigator in the body changed its history (a push, a pop, a new
  /// navigator). Navigators send this after the frame.
  bool _onBranchNavigation(NavigationNotification notification) {
    _outsideBuild(_scanBranches);
    return false;
  }

  /// Walks the body for its on-screen navigators (the selected tab's).
  void _scanBranches() {
    if (!mounted) return;
    final body = _bodyKey.currentContext;
    _branches = body == null ? const [] : onScreenNavigatorsUnder(body);
    _checkBranches(rescan: false);
    _armBranchCheck();
  }

  /// Whether a navigator found by the last scan is still on screen and can
  /// pop. Cheap: its ancestors plus, at a navigator's overlay, the entries
  /// after the one on the path (up to 12 levels each, looking for a route
  /// barrier), not the tree.
  ///
  /// A navigator that came on screen or went off it since the scan (a tab a
  /// router shows frames after the selection) asks for a new scan: its
  /// nested navigators were not walked.
  void _checkBranches({bool rescan = true}) {
    final body = _bodyKey.currentContext;
    var canPop = false;
    for (final b in _branches) {
      final onScreen =
          body != null &&
          b.target.mounted &&
          isOnScreenUnder(b.target.context, body);
      if (rescan && onScreen != b.onScreen && b.target.mounted) {
        _scanBranches();
        return;
      }
      if (onScreen && _canPop(b.target)) canPop = true;
    }
    if (canPop != _branchCanPop) setState(() => _branchCanPop = canPop);
  }

  /// While the body has a navigator, checks it again after every frame (no
  /// frame is asked for). `canPop()` changes with no navigation event when
  /// a drawer, a persistent bottom sheet or any local-history entry comes
  /// or goes, and a branch can go offstage frames after the selection (the
  /// end of a cross-fade): a stale answer kept the shell's route blocked at
  /// the tab's root, or let back pop a hidden tab's page.
  void _armBranchCheck() {
    if (_branchCheckArmed || _branches.isEmpty) return;
    _branchCheckArmed = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _branchCheckArmed = false;
      if (!mounted) return;
      _checkBranches();
      _armBranchCheck();
    });
  }

  /// Back while the selected tab can pop: its top page pops, through its
  /// own PopScope. With several navigators on screen (an iPad detail
  /// beside its master), the last one in tree order that can pop.
  void _popBranch() {
    // A fresh walk: back may come before the frame that would tell.
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      _scanBranches();
    }
    for (final (:target, :handled, :onScreen) in _branches.reversed) {
      if (!onScreen || !target.mounted || !_canPop(target)) continue;
      // The app's NavigatorPopHandler around it asks the same navigator in
      // the same turn: a second ask would close a drawer and pop its page.
      if (handled) return;
      if (target is NestedShellBack) {
        (target as NestedShellBack).handleBack();
        return;
      }
      final navigator = target as NavigatorState;
      unawaited(
        _maybePop(navigator).whenComplete(() {
          if (mounted) _scheduleBranchScan();
        }),
      );
      return;
    }
  }

  /// The shell's say over its own route's pops (system back, the iOS edge
  /// swipe), in this order:
  /// 1. an overlay sidebar closes first (natively too);
  /// 2. an active search deactivates. Natively, popping
  ///    left UIKit's search active under the hidden chrome, its keyboard
  ///    with nothing to dismiss it;
  /// 3. while the selected tab's navigator can pop, its top page pops,
  /// as on iOS; at the tab's root the shell's route pops.
  ///
  /// A blocked route also loses the edge swipe: Flutter hit-tests the
  /// outer route's back gesture before a tab route's, so in a shell that
  /// is itself a pushed page the swipe on any tab's pushed page popped the
  /// whole shell. Blocked, the swipe falls to the tab's top page.
  ///
  /// The route calls every PopScope on it, so a back blocked by another one
  /// (an exit wrapper, an unsaved form) lands here too. A
  /// `NavigatorPopHandler` with a callback around the branch answers back
  /// for its navigator; the shell then only blocks its own route.
  Widget _backScope({
    required bool overlay,
    required bool searchActive,
    required Widget child,
  }) {
    _backOverlay = overlay;
    _backSearch = searchActive;
    return PopScope(
      canPop: !claimsBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
      },
      child: child,
    );
  }

  @override
  bool get claimsBack => _backOverlay || _backSearch || _branchCanPop;

  @override
  void handleBack() {
    if (_backOverlay) {
      _setSidebarVisible(false);
    } else if (_backSearch) {
      _search.deactivate();
    } else {
      _popBranch();
    }
  }

  static bool _canPop(State target) => switch (target) {
    NavigatorState() => target.canPop(),
    NestedShellBack() => (target as NestedShellBack).claimsBack,
    _ => false,
  };

  /// The body under its listeners: one subtree for both layouts, so a
  /// switch between native and Flutter chrome keeps its state.
  /// [kind] null: native chrome.
  Widget _bodySubtree(LiquidChromeKind? kind) => KeyedSubtree(
    key: _bodyKey,
    child: NotificationListener<NavigationNotification>(
      onNotification: _onBranchNavigation,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onBodyScroll(n, kind),
        child: widget.body,
      ),
    ),
  );

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

  void _onBarHeight(
    (LiquidSizeClass, TabBarForm, double) key,
    double height,
  ) {
    if (!mounted || _measured[key] == height) return;
    setState(() => _measured = {..._measured, key: height});
  }

  void _onSelect(int index) => unawaited(_select(index));

  /// The one path every user selection takes: single-flight guard,
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

  /// The native chrome is inert while a guard runs: its
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

  /// Selects the search tab through the guard. A tear-off, so search
  /// chrome details compare equal across builds.
  void _selectSearch() {
    final index = searchIndexOf(widget.destinations);
    if (index != null) _onSelect(index);
  }

  /// The body's scrolling: a user drag puts the search keyboard away
  /// ([ShellSearch.onBodyScroll]); it drives the native bar's
  /// minimize ([kind] null: native chrome); a user scroll
  /// minimizes the Flutter bar.
  bool _onBodyScroll(ScrollNotification notification, LiquidChromeKind? kind) {
    _search.onBodyScroll(notification);
    final result = _trackMinimize(notification, kind);
    // A fling or a programmatic scroll that reached the top expands the
    // Flutter bar (VK-600 Q2, Q3); a drag back there does not (VK-503 Q7).
    if (kind == LiquidChromeKind.bottomBar &&
        widget.minimizeOnScroll &&
        !_search.selected &&
        result == MinimizeScrollResult.expand) {
      _expand();
    }
    if (notification is UserScrollNotification && kind != null) {
      _onScroll(notification, kind);
    }
    return false;
  }

  /// Feeds the selected tab's minimize offset, in both chrome modes. Only a
  /// view on screen counts: an `IndexedStack` keeps the other tabs' lists,
  /// and the app may scroll one of them.
  MinimizeScrollResult _trackMinimize(
    ScrollNotification notification,
    LiquidChromeKind? kind,
  ) {
    final context = notification.context;
    final body = _bodyKey.currentContext;
    if (context != null && body != null && !isOnScreenUnder(context, body)) {
      return MinimizeScrollResult.none;
    }
    final tab = resolveSelectedIndex(
      widget.selectedIndex,
      widget.destinations.length,
    );
    final result = _minimizeScroll.handleNotification(notification, tab: tab);
    if (kind == null &&
        _minimizeActive &&
        result != MinimizeScrollResult.none) {
      _scheduleMinimizeSend();
      if (result == MinimizeScrollResult.expand) _claim?.expandTabBar();
    }
    return result;
  }

  bool _onScroll(UserScrollNotification notification, LiquidChromeKind kind) {
    // Only vertical scrolling reads as "moving through content"; a carousel
    // or PageView swipe leaves the bar alone.
    // Suspended while the search tab is selected (spec P3b §9.2).
    if (!widget.minimizeOnScroll ||
        kind != LiquidChromeKind.bottomBar ||
        _search.selected ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _minimized.value = true;
      case ScrollDirection.forward:
        break; // Q7: native stays minimized; a tap or a selection expands.
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  /// A dialog, sheet or menu above the shell hides the compact native bar
  /// (it would cover the overlay's bottom), and native gives Flutter the
  /// window's own bottom safe area. The body behind the overlay keeps the
  /// bar's inset, so nothing there jumps 49pt and back (owner decision);
  /// the overlay, above the shell, lays out against the home indicator.
  /// Also held after the pop until native shows the bar again. A page
  /// pushed above, `LiquidHideChrome`, or a new window size drops it.
  MediaQueryData _holdBarInset(MediaQueryData media, {required bool barShown}) {
    final bottom = media.viewPadding.bottom;
    if (!barShown || _covered) {
      _barBottom = null;
      return media;
    }
    final held = _barBottom;
    if (held == null || media.size != _barSize || bottom >= held) {
      // The bar shows (or a fresh window size): its inset is the truth.
      _barBottom = bottom;
      _barSize = media.size;
      return media;
    }
    return media.copyWith(
      viewPadding: media.viewPadding.copyWith(bottom: held),
      padding: media.padding.copyWith(
        bottom: math.max(0, held - media.viewInsets.bottom),
      ),
    );
  }

  /// Once per entry into compact, after the frame.
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
    final searches = [
      for (final (i, d) in destinations.indexed)
        if (d.role == LiquidDestinationRole.search) i,
    ];
    assert(
      searches.length <= 1,
      'LiquidShell allows one search destination; got ${searches.length}.',
    );
    assert(
      searches.isEmpty || searches.single == length - 1,
      'The search destination must be the last destination.',
    );
    assert(
      searches.every(
        (i) => destinations[i].placement == LiquidPlacement.everywhere,
      ),
      'The search destination must be placed everywhere.',
    );
    assert(
      searches.isEmpty || widget.search != null,
      'A search destination needs LiquidShell.search.',
    );
    assert(
      searches.isNotEmpty || widget.search == null,
      'LiquidShell.search needs a destination with '
      'LiquidDestinationRole.search.',
    );
    assert(
      searches.isEmpty || widget.tabBarTrailing == null,
      'A shell with a search destination has no tabBarTrailing: both are '
      'the trailing ⌕.',
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
    if (native != null) {
      // Native chrome draws no Flutter field.
      if (_search.holdsField) _search.releaseField();
      return native;
    }
    final previousPresentation = _presentation;
    final sizeClassChanged =
        previousPresentation != null &&
        sizeClassOf(previousPresentation) != sizeClassOf(presentation);
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
    final searchIndex = searchIndexOf(widget.destinations);
    _search
      ..native = false
      ..selected = searchIndex != null && selected == searchIndex;
    _nativePageBar = false;
    if (searchIndex == null || selected != searchIndex) {
      _previousIndex = selected;
    } else if (_previousIndex >= searchIndex) {
      // The app's list changed under the search tab: the one that was
      // there is gone (search is last, so every other index is below it).
      _previousIndex = 0;
    }
    final phase = searchIndex == null
        ? null
        : searchPhaseFor(
            selected: selected,
            searchIndex: searchIndex,
            active: _search.controller?.isActive ?? false,
          );

    final kind = chromeKindFor(
      presentation: presentation,
      sidebarVisible: _sidebarVisible,
      // Release fallback for an empty list (§7): body only, no chrome.
      hidden: _hideRequests > 0 || widget.destinations.isEmpty,
    );
    // The Flutter field keeps focus only while it is shown and stays where
    // it is (spec P3b §8.2, §9.4). Hidden chrome, another tab (a sidebar
    // row, the app's selectedIndex) or the other size class (the compact
    // row and the regular top field are different parents) let go of it
    // first; ShellSearch then ends any composition.
    final fieldShown =
        phase != null &&
        phase != LiquidSearchPhase.idle &&
        kind != LiquidChromeKind.hidden;
    if (_search.holdsField && (!fieldShown || sizeClassChanged)) {
      _search.releaseField();
    }
    final bottomGap = bottomGapFor(
      // The device decides, not an app's ThemeData.platform (VK-702).
      platform: defaultTargetPlatform,
      viewPaddingBottom: media.viewPadding.bottom,
      gestureInsetBottom: media.systemGestureInsets.bottom,
    );
    // The body: always the first child, always the same wrappers.
    final tiled = kind == LiquidChromeKind.sidebarTiled;
    // Q17: narrow shells trade margin for 44pt-wide cells.
    final narrow = size.width < kLiquidNarrowWidth;
    final barMargin = narrow ? _kNarrowBarMargin : _kBottomBarMargin;
    // A compact shell in landscape lower than compactHeight (a phone) gets
    // the 44 pt bar (spec VK-503 §5.2, §12.1); compactHeight 0 restores P1.
    final landscape =
        size.width > size.height &&
        size.height < widget.breakpoints.compactHeight;
    final barForm = sizeClass == LiquidSizeClass.regular
        ? TabBarForm.top
        : landscape
        ? TabBarForm.landscape
        : TabBarForm.compact;
    final barKey = (sizeClass, barForm, media.textScaler.scale(14));
    // The bottom row before it is measured: the form's own pill extent.
    final measuredBar =
        _measured[barKey] ??
        (barForm == TabBarForm.landscape ? TabMetrics.landscapeExtent : null);
    final bottomRowExtent = measuredBar ?? kBottomPillExtent;
    // The bars clear the side safe area: a phone's notch in landscape
    // (VK-702). The search rects are laid out between the two insets.
    final sideLeft = media.padding.left;
    final sideRight = media.padding.right;
    final compactRects = phase != null && kind == LiquidChromeKind.bottomBar
        ? compactSearchRects(
            phase: phase,
            size: Size(size.width - sideLeft - sideRight, size.height),
            rowBottom: size.height - bottomGap,
            rowExtent: bottomRowExtent,
            margin: barMargin,
            keyboard: media.viewInsets.bottom,
            direction: Directionality.of(context),
          ).shift(sideLeft)
        : null;
    // A hover on the ⌕ outlives a drag whose bar stops feeding the target
    // (search selected, chrome hidden, another layout). Cleared after the
    // frame: the ⌕ that listens may be mid-build.
    final searchTargetFed =
        phase == LiquidSearchPhase.idle && compactRects != null;
    if (!searchTargetFed && _searchTarget.hovered.value) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchTarget.hovered.value = false;
      });
    }
    // The regular top field (spec P3b §9.3): selected and active only.
    final regularFieldTop =
        phase != null &&
            phase != LiquidSearchPhase.idle &&
            kind != LiquidChromeKind.bottomBar &&
            kind != LiquidChromeKind.hidden
        ? regularSearchFieldTop(
            phase: phase,
            paddingTop: media.padding.top,
            barExtent: _measured[barKey] ?? kTopPillExtent,
            tiled: tiled,
          )
        : null;
    var insets = chromeInsetsFor(
      kind: kind,
      topPadding: media.padding.top,
      measuredBar: measuredBar,
      bottomGap: bottomGap,
    );
    // Content clears the field in every phase (spec P3b §4.6).
    if (compactRects != null && phase == LiquidSearchPhase.active) {
      insets = insets.copyWith(
        bottom: size.height - compactRects.field.top + kSearchFieldGap,
      );
    }
    if (regularFieldTop != null) {
      insets = insets.copyWith(
        top: regularFieldTop + kRegularSearchFieldExtent + kSearchFieldGap,
      );
    }
    final bodyStart = tiled ? widget.sidebarWidth : 0.0;
    var bodyMedia = media.copyWith(
      size: Size(size.width - bodyStart, size.height),
    );
    if (tiled) {
      bodyMedia = bodyMedia.removePadding(removeLeft: !rtl, removeRight: rtl);
    }
    // The overlay sidebar is modal for the keyboard too (VK-702): nothing
    // behind its barrier takes focus.
    final modal = kind == LiquidChromeKind.sidebarOverlay;
    final children = <Widget>[
      PositionedDirectional(
        start: bodyStart,
        top: 0,
        end: 0,
        bottom: 0,
        child: MediaQuery(
          data: bodyMedia,
          child: ExcludeFocus(excluding: modal, child: _bodySubtree(kind)),
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
          ? [
              for (final i in tabBarIndices(widget.destinations))
                // The compact pill holds the other destinations (§9.2).
                if (!(phase != null &&
                    kind == LiquidChromeKind.bottomBar &&
                    i == searchIndex))
                  i,
            ]
          : [for (var i = 0; i < widget.destinations.length; i++) i],
      selectedIndex: selected,
      select: _onSelect,
      trailing: widget.tabBarTrailing,
      minimized: minimized,
      expand: _expand,
      sidebarVisible: sidebarShown,
      setSidebarVisible: _setSidebarVisible,
      strings: widget.strings,
      search: phase == null
          ? null
          : LiquidSearchChromeDetails(
              phase: phase,
              controller: _search.controller!,
              previousIndex: _previousIndex,
              selectSearch: _selectSearch,
            ),
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

    final searchDestination = searchIndex == null
        ? null
        : widget.destinations[searchIndex];
    final morph = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : kSearchMorphDuration;
    // One field for every phase and both layouts: ShellSearch owns its
    // controller and focus node for the shell's lifetime (spec P3b §9.4).
    Widget searchField({VoidCallback? inlineCancel}) => slot(
      details(LiquidChromeSlot.searchField),
      SearchFieldGlass(
        phase: phase!,
        editing: _search.editing,
        focus: _search.focus,
        placeholder:
            widget.search?.placeholder ?? widget.strings.searchPlaceholder,
        searchLabel: searchDestination!.label,
        searchIcon: searchDestination.icon,
        onOpen: () => _onSelect(searchIndex!),
        onSubmitted: _search.submit,
        onDeactivate: _search.deactivate,
        cancelLabel: widget.strings.cancelSearch,
        inlineCancel: inlineCancel,
        highlight: _searchTarget.hovered,
      ),
    );

    // Spec VK-503 §15: the pocket under the default bottom bar. It follows
    // the scroll view, not the bar, so it stays while the bar is minimized.
    if (kind == LiquidChromeKind.bottomBar && widget.chromeBuilder == null) {
      children.add(
        Positioned(
          key: kScrollPocketKey,
          left: 0,
          right: 0,
          bottom: 0,
          // The native landscape pocket is 128.8 pt (measured, see
          // kScrollPocketLandscapeExtent), not the portrait 148.
          height: barForm == TabBarForm.landscape
              ? kScrollPocketLandscapeExtent
              : kScrollPocketExtent,
          child: const ScrollEdgePocket(),
        ),
      );
    }

    switch (kind) {
      case LiquidChromeKind.bottomBar:
        final margin = barMargin;
        if (phase != null && compactRects != null) {
          // The search row (spec P3b §9.2): the pill of the other
          // destinations, then the ⌕ circle that becomes the field.
          final rowExtent = bottomRowExtent;
          final idle = phase == LiquidSearchPhase.idle;
          // The ⌕ in the bar's own coordinates: its top-left is the row's.
          _searchTargetRect = compactRects.field.shift(
            Offset(-margin - sideLeft, -(size.height - bottomGap - rowExtent)),
          );
          children.add(
            CompactSearchChrome(
              phase: phase,
              rects: compactRects,
              pill: Positioned(
                left: margin + sideLeft,
                right: margin + sideRight,
                bottom: bottomGap,
                child: IgnorePointer(
                  ignoring: phase == LiquidSearchPhase.active,
                  child: AnimatedOpacity(
                    opacity: phase == LiquidSearchPhase.active ? 0 : 1,
                    duration: morph,
                    curve: kSearchMorphCurve,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 1,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _minimized,
                        builder: (context, minimized, _) {
                          // Scroll minimizes in idle only (spec P3b §9.2);
                          // selected, the bar collapses into the previous
                          // tab's circle (spec VK-503 §11).
                          final scrolled =
                              widget.minimizeOnScroll && minimized && idle;
                          final collapsed = scrolled || !idle;
                          return measured(
                            TabBarLandscapeScope(
                              landscape: landscape,
                              child: slot(
                                details(
                                  LiquidChromeSlot.tabBar,
                                  minimized: collapsed,
                                ),
                                GlassTabBar(
                                  // Only the pill takes the landscape
                                  // form: the search rects keep the
                                  // portrait morph (native landscape
                                  // search was not captured).
                                  form: barForm,
                                  destinations: widget.destinations.sublist(
                                    0,
                                    searchIndex,
                                  ),
                                  selectedIndex: idle
                                      ? selected
                                      : _previousIndex,
                                  onSelect: _onSelect,
                                  minimized: collapsed,
                                  collapseDelay: idle,
                                  tintCollapsed: idle,
                                  onCollapsedTap: idle
                                      ? _expand
                                      : () => _onSelect(_previousIndex),
                                  announceExpand: idle,
                                  collapsedKey: idle
                                      ? null
                                      : kSearchCollapsedKey,
                                  reserveTrailing: true,
                                  externalTarget: idle ? _searchTarget : null,
                                  strings: widget.strings,
                                  narrow: narrow,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              field: searchField(),
              onCancel: _search.cancel,
              strings: widget.strings,
            ),
          );
          break;
        }
        final barRowMargin = narrow
            ? _kNarrowBarMargin
            : landscape
            ? TabMetrics.landscapeMargin
            : _kBottomBarMargin;
        children.add(
          Positioned(
            left: barRowMargin + sideLeft,
            right: barRowMargin + sideRight,
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
                    // The shell's size picks the form, not the window's.
                    TabBarLandscapeScope(
                      landscape: landscape,
                      child: slot(
                        details(
                          LiquidChromeSlot.tabBar,
                          minimized: isMinimized,
                        ),
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
        final bar = measured(
          slot(
            details(LiquidChromeSlot.tabBar),
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        _kBarMargin + (toggle ? _kToggleReserve : 0) + indent,
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
        );
        // Active, the field takes the bar row (spec P3b §9.3). Shells
        // without search keep P1's tree.
        final active = phase == LiquidSearchPhase.active;
        children.add(
          Positioned(
            left: sideLeft,
            right: sideRight,
            top: media.padding.top + kTopBarGap,
            child: ExcludeFocus(
              excluding: modal,
              child: phase == null
                  ? bar
                  : IgnorePointer(
                      ignoring: active,
                      child: AnimatedOpacity(
                        opacity: active ? 0 : 1,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: bar,
                      ),
                    ),
            ),
          ),
        );
      case LiquidChromeKind.sidebarTiled || LiquidChromeKind.hidden:
        break;
    }

    if (regularFieldTop != null) {
      final indent = _windowControls.value.value.indentFor(
        rowTop: regularFieldTop - media.padding.top,
      );
      final start = bodyStart + kRegularSearchMargin + indent;
      children.add(
        AnimatedPositioned(
          key: kSearchFieldKey,
          duration: morph,
          curve: kSearchMorphCurve,
          left: rtl ? kRegularSearchMargin : start,
          right: rtl ? start : kRegularSearchMargin,
          top: regularFieldTop,
          height: kRegularSearchFieldExtent,
          // Behind the overlay an idle field takes no focus (focusing it
          // starts the search); an active one keeps it (VK-774).
          child: ExcludeFocus(
            excluding: modal && phase == LiquidSearchPhase.selected,
            child: searchField(inlineCancel: _search.cancel),
          ),
        ),
      );
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
          // Overlay: focus starts in the sidebar when nothing holds it, so
          // Escape reaches the shell. An active search keeps its focus.
          child: Focus(
            autofocus: modal,
            skipTraversal: true,
            includeSemantics: false,
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
        ),
      );
    }

    return _backScope(
      overlay: kind == LiquidChromeKind.sidebarOverlay,
      searchActive: phase == LiquidSearchPhase.active,
      child: ShellScopeMarker(
        data: LiquidShellScopeData(
          sizeClass: sizeClass,
          chromeKind: kind,
          chromeInsets: insets,
          sidebarVisible: sidebarShown,
          setSidebarVisible: _setSidebarVisible,
          windowControls: _windowControls.value.value,
          searchPhase: phase,
          searchScopes: widget.search?.scopes,
        ),
        registry: this,
        pages: this,
        strings: widget.strings,
        // Escape closes the overlay sidebar, wherever focus is in the shell.
        child: CallbackShortcuts(
          bindings: {
            if (modal)
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _setSidebarVisible(false),
          },
          // One backdrop read for all chrome glass (budget rule, §5.8).
          child: BackdropGroup(child: Stack(children: children)),
        ),
      ),
    );
  }

  /// In debug, once per shell: names what lacks an `sfSymbol` when only
  /// that keeps this shell from native chrome: `auto`, no
  /// `chromeBuilder`, and the platform answered that native chrome is
  /// installed. While the answer is pending nothing is logged: the device
  /// may not support it, and the once-per-shell line would be spent.
  void _debugHintMissingSymbols({
    required LiquidNativeShellState? state,
    required bool describable,
  }) {
    if (!kDebugMode || _symbolHintLogged || describable) return;
    if (widget.nativeChrome != LiquidNativeChrome.auto ||
        widget.chromeBuilder != null) {
      return;
    }
    if (state == null || !state.installed) return;
    final hint = nativeSymbolHint(widget.destinations, widget.tabBarTrailing);
    if (hint == null) return;
    _symbolHintLogged = true;
    debugPrint(hint);
  }

  /// The native chrome layout, or null to draw Flutter chrome.
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
    final forced = LiquidGlassScope.policyOf(context).forcedTier != null;
    final possible = nativeChromePossible(
      mode: widget.nativeChrome,
      hasChromeBuilder: widget.chromeBuilder != null,
      describable: describable,
      glassTierForced: forced,
    );
    final engaged = nativeChromeEngaged(
      mode: widget.nativeChrome,
      owner: owner,
      state: state,
      hasChromeBuilder: widget.chromeBuilder != null,
      describable: describable,
      glassTierForced: forced,
    );
    _debugHintMissingSymbols(state: state, describable: describable);
    final wasEngaged = _nativeEngaged;
    _nativeEngaged = engaged;
    if (engaged != wasEngaged) _presentation = null;
    var media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final selected = resolveSelectedIndex(
      widget.selectedIndex,
      widget.destinations.length,
    );
    final searchIndex = searchIndexOf(widget.destinations);
    _search
      ..native = engaged
      ..selected = searchIndex != null && selected == searchIndex;
    _nativePageBar = nativePageBarFor(
      engaged: engaged,
      selected: selected,
      searchIndex: searchIndex,
    );
    if (_nativePageBar || _scrollRecord != null) _scheduleScrollSync();
    final searchActive = _search.controller?.isActive ?? false;
    // A dialog or sheet above an active search: the keyboard and the field
    // would sit above its barrier (spec §7.10). Once per covering.
    if (_routeCurrent) {
      _searchDeactivatedForRoute = false;
    } else if (engaged && searchActive && !_searchDeactivatedForRoute) {
      _searchDeactivatedForRoute = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search.deactivate();
      });
    }
    // The compact bar is drawn above the Flutter view: it would cover the
    // bottom of a sheet or dialog drawn there, so it hides while one is
    // above the shell. The top bar and sidebar only turn inert (§7.4).
    final hidden =
        _hideRequests > 0 ||
        _covered ||
        ((state?.compact ?? false) && !_routeCurrent);
    if (owner) {
      final theme = Theme.of(context);
      final destinations = widget.destinations;
      final trailing = widget.tabBarTrailing;
      final footer = widget.nativeSidebarFooter;
      final minimizeOnScroll = widget.minimizeOnScroll;
      final interactive = _routeCurrent && !_guardPending;
      final placeholder = widget.search?.placeholder;
      final scopes = widget.search?.scopes;
      final pageBar = _nativePageBar;
      // `hidden` and `interactive` are taken now; `_stackFor` reads
      // `_routeCurrent` and `_covered` after the frame. Both are set before
      // the frame ends, so they agree: do not "fix" one side.
      _scheduleNativeSend(() {
        if (pageBar) _updatePageStack(selected);
        return nativeConfigFor(
          engaged: engaged,
          destinations: destinations,
          selectedIndex: selected,
          trailing: trailing,
          footer: footer,
          tint: theme.colorScheme.primary,
          dark: theme.brightness == Brightness.dark,
          rtl: rtl,
          hidden: hidden,
          interactive: interactive,
          minimizeOnScroll: minimizeOnScroll,
          searchPlaceholder: placeholder,
          searchScopes: scopes,
          pageStacks: _pageStacks,
        );
      });
    }
    // An offset that must follow a config (new native tab hosts) is sent
    // from the config's own callback ([_scheduleNativeSend]).
    _setMinimizeActive(
      nativeMinimizeActive(
        owner: owner,
        engaged: engaged,
        compact: state?.compact ?? false,
        minimizeOnScroll: widget.minimizeOnScroll,
        searchSelected: _search.selected,
        hidden: hidden,
        routeCurrent: _routeCurrent,
      ),
    );
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
    media = _holdBarInset(media, barShown: kind == LiquidChromeKind.bottomBar);
    var insets = nativeChromeInsets(kind: kind, padding: media.padding);
    if (_search.selected) {
      // The iPhone field above the keyboard is not in the safe area.
      insets = insets.copyWith(
        bottom: math.max(
          insets.bottom,
          nativeSearchBottomInset(
            field: _search.field,
            size: media.size,
            padding: media.padding,
            viewInsets: media.viewInsets,
            active: searchActive,
          ),
        ),
      );
    }
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
    final phase = searchIndex == null
        ? null
        : searchPhaseFor(
            selected: selected,
            searchIndex: searchIndex,
            active: searchActive,
          );
    return _backScope(
      overlay: overlay,
      searchActive: phase == LiquidSearchPhase.active,
      child: ShellScopeMarker(
        data: LiquidShellScopeData(
          sizeClass: sizeClass,
          chromeKind: kind,
          chromeInsets: insets,
          sidebarVisible: state?.sidebarVisible ?? false,
          setSidebarVisible: _setSidebarVisible,
          nativeChrome: engaged,
          searchPhase: phase,
          nativePageBar: _nativePageBar,
          // UIKit's scope bar draws them (spec VK-550 §10.3). Native chrome
          // engages on iOS 26+ only, so nothing else gates it. Pending and
          // standby too: no Flutter chrome is drawn then, and a Flutter
          // scope bar would show only to vanish when native engages
          // (Task 10 review M3).
          nativeSearchScopes: widget.search?.scopes != null,
          searchScopes: widget.search?.scopes,
          // UIKit's top bar, sidebar and navigation bars make room for the
          // cluster; the body starts below or beside them (spec P2 §8.3,
          // P3b §7.9). The compact bar is at the bottom: the top is the
          // body's to clear.
          windowControls:
              (engaged && sizeClass == LiquidSizeClass.regular) ||
                  _nativePageBar
              ? LiquidWindowControls.zero
              : _windowControls.value.value,
        ),
        registry: this,
        pages: this,
        strings: widget.strings,
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
                  child: _bodySubtree(null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One `LiquidPage` registered with a shell.
final class _PageRecord implements PageHandle {
  _PageRecord(this._shell, this.entry);

  final _LiquidShellState _shell;
  PageEntry entry;

  /// The page's last scroll offset; null until its scroll
  /// view reports one.
  double? offset;

  @override
  void update(PageEntry next) {
    if (next.sameAs(entry)) return;
    entry = next;
    _shell._rebuild();
  }

  @override
  void scrolled(double offset) {
    if (offset == this.offset) return;
    this.offset = offset;
    if (_shell.mounted) _shell._scheduleScrollSync();
  }

  @override
  void unregister() {
    _shell._pageRecords.remove(this);
    if (_shell.mounted) _shell._rebuild();
  }
}
