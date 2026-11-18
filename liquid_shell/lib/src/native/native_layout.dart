import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/native/native_chrome.dart';
import 'package:liquid_shell/src/pages/page_title.dart';
import 'package:liquid_shell/src/search/search_layout.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Whether the shell's chrome is native right now. Pure.
///
/// Every condition must hold: the app allows it, this shell owns the
/// window's native chrome, the platform installed it, the shell has no
/// custom Flutter chrome, and every destination (and the trailing action)
/// can be drawn natively. Width does not matter (owner D1): UIKit draws
/// the compact bar at the bottom and the top bar or sidebar at regular
/// width, and reports which in [LiquidNativeShellState.compact].
bool nativeChromeEngaged({
  required LiquidNativeChrome mode,
  required bool owner,
  required LiquidNativeShellState? state,
  required bool hasChromeBuilder,
  required bool describable,
  required bool glassTierForced,
}) =>
    nativeChromePossible(
      mode: mode,
      hasChromeBuilder: hasChromeBuilder,
      describable: describable,
      glassTierForced: glassTierForced,
    ) &&
    owner &&
    state != null &&
    state.installed;

/// The conditions of [nativeChromeEngaged] that the shell knows without the
/// platform: the app allows it, it has no custom Flutter chrome, no
/// `LiquidGlassScope` above it forces a glass tier (an app that forces a
/// tier asks for Flutter glass), and it can be drawn
/// natively. Pure.
///
/// While the platform has not answered (pending), only a shell for which
/// this holds waits with no chrome; every other one draws Flutter chrome
/// from its first frame.
bool nativeChromePossible({
  required LiquidNativeChrome mode,
  required bool hasChromeBuilder,
  required bool describable,
  required bool glassTierForced,
}) =>
    mode == LiquidNativeChrome.auto &&
    !hasChromeBuilder &&
    !glassTierForced &&
    describable;

/// Whether every destination and the trailing action have an SF Symbol. The
/// search destination needs none: UIKit's search tab has its own image.
/// Only the first one is the search tab; an extra one is
/// standard and needs a symbol.
bool nativeDescribable(
  List<LiquidDestination> destinations,
  LiquidTabAction? trailing,
) {
  final searchIndex = searchIndexOf(destinations);
  return destinations.isNotEmpty &&
      destinations.indexed.every(
        (e) => e.$2.sfSymbol != null || e.$1 == searchIndex,
      ) &&
      (trailing == null || trailing.sfSymbol != null);
}

/// The debug hint for a shell that could use native chrome but cannot
/// describe itself: one line naming every destination
/// (by label) and the trailing action (by semantic label) without an
/// `sfSymbol`. Null when nothing lacks one. Pure.
String? nativeSymbolHint(
  List<LiquidDestination> destinations,
  LiquidTabAction? trailing,
) {
  final searchIndex = searchIndexOf(destinations);
  final labels = [
    for (final (i, d) in destinations.indexed)
      if (d.sfSymbol == null && i != searchIndex) '"${d.label}"',
  ];
  final missing = [
    if (labels.length == 1) 'destination ${labels.single}',
    if (labels.length > 1) 'destinations ${labels.join(', ')}',
    if (trailing != null && trailing.sfSymbol == null)
      'tabBarTrailing "${trailing.semanticLabel}"',
  ];
  if (missing.isEmpty) return null;
  return 'liquid_shell: drawing Flutter chrome where native chrome is '
      'available: no sfSymbol on ${missing.join(' and ')}. Add one, or set '
      'nativeChrome: LiquidNativeChrome.off.';
}

/// The native badge text: a count as drawn by the Flutter badge, `''` for
/// a dot (UIKit draws an empty badge as a dot), null when hidden.
String? nativeBadgeText(LiquidBadge? badge) {
  if (!badgeVisible(badge)) return null;
  return switch (badge!) {
    LiquidDotBadge() => '',
    final LiquidCountBadge count => badgeText(count),
  };
}

/// The chrome kind while native chrome is engaged: UIKit's compact bar at
/// the bottom, the system's vertical bar beside the body, else the top bar
/// while the sidebar is hidden.
LiquidChromeKind nativeChromeKind({
  required LiquidNativeShellState state,
  required bool hidden,
}) {
  if (hidden) return LiquidChromeKind.hidden;
  if (state.verticalBarSide != LiquidNativeVerticalBarSide.none) {
    return LiquidChromeKind.verticalBar;
  }
  if (state.compact) return LiquidChromeKind.bottomBar;
  return switch (state.sidebar) {
    LiquidNativeSidebar.hidden => LiquidChromeKind.topBar,
    LiquidNativeSidebar.overlay => LiquidChromeKind.sidebarOverlay,
    LiquidNativeSidebar.tiled => LiquidChromeKind.sidebarTiled,
  };
}

/// The insets of native chrome. The bar is already in the Flutter view's
/// safe area [padding]: the top bar (or the overlay's held top) in the
/// top padding, the compact bar in the bottom padding, the vertical bar in
/// the left or right padding on its [verticalBarSide]. Tiled and hidden
/// cover nothing.
EdgeInsets nativeChromeInsets({
  required LiquidChromeKind kind,
  required EdgeInsets padding,
  LiquidNativeVerticalBarSide verticalBarSide =
      LiquidNativeVerticalBarSide.none,
}) => switch (kind) {
  LiquidChromeKind.topBar ||
  LiquidChromeKind.sidebarOverlay => EdgeInsets.only(top: padding.top),
  LiquidChromeKind.bottomBar => EdgeInsets.only(bottom: padding.bottom),
  LiquidChromeKind.verticalBar => switch (verticalBarSide) {
    LiquidNativeVerticalBarSide.left => EdgeInsets.only(left: padding.left),
    LiquidNativeVerticalBarSide.right => EdgeInsets.only(right: padding.right),
    LiquidNativeVerticalBarSide.none => EdgeInsets.zero,
  },
  _ => EdgeInsets.zero,
};

/// Everything the native chrome shows.
LiquidNativeChromeConfig nativeConfigFor({
  required bool engaged,
  required List<LiquidDestination> destinations,
  required int selectedIndex,
  required LiquidTabAction? trailing,
  required LiquidNativeSidebarFooter? footer,
  required Color tint,
  required bool dark,
  required bool rtl,
  required bool hidden,
  required bool interactive,
  required bool minimizeOnScroll,
  bool tabBarHidden = false,
  String? searchPlaceholder,
  List<String>? searchScopes,
  Map<int, List<LiquidNativePage>> pageStacks = const {},
}) {
  final searchIndex = searchIndexOf(destinations);
  return LiquidNativeChromeConfig(
    engaged: engaged,
    tabs: [
      for (final (i, d) in destinations.indexed)
        LiquidNativeTab(
          title: d.label,
          sfSymbol: d.sfSymbol ?? '',
          badge: nativeBadgeText(d.badge),
          sidebarOnly: d.placement == LiquidPlacement.sidebarOnly,
          search: i == searchIndex,
          pages: pageStacks[i] ?? const [],
        ),
    ],
    selectedIndex: selectedIndex,
    trailing: trailing == null
        ? null
        : LiquidNativeAction(
            title: trailing.semanticLabel,
            sfSymbol: trailing.sfSymbol ?? '',
          ),
    footer: footer == null
        ? null
        : LiquidNativeFooter(
            title: footer.title,
            subtitle: footer.subtitle,
            sfSymbol: footer.sfSymbol,
            semanticLabel: footer.semanticLabel,
          ),
    tintArgb: tint.toARGB32(),
    dark: dark,
    rtl: rtl,
    hidden: hidden,
    interactive: interactive,
    minimizeOnScroll: minimizeOnScroll,
    tabBarHidden: tabBarHidden,
    search: searchIndex == null
        ? null
        : LiquidNativeSearchConfig(
            placeholder: searchPlaceholder,
            scopes: searchScopes,
          ),
  );
}

/// The steps of the page bar's hand-over between Flutter and native
/// (spec 2026-11-18, applied-epoch hand-over).
enum NativeHandover {
  /// Flutter's layout; no hand-over under way.
  none,

  /// Engaged, native not showing an engaged config yet (or showing one
  /// without the bar this shell's top page has): the pending layout and
  /// LiquidPage's own bar, the top held.
  waiting,

  /// This shell's config applied, its inset not here yet: native's layout,
  /// the top held below where the Flutter bar was.
  holding,

  /// Another engaged config on screen (an owner change, a quick
  /// re-engage): native's layout, the top held, until this shell's config
  /// is applied.
  takeover,

  /// Native's layout and its real insets.
  done,

  /// Disengaged, native still showing: native's layout kept, the top and
  /// bottom held, until native has let go.
  releasing,

  /// Native let go, its inset not gone yet: Flutter's layout, the top held
  /// above where native's bar was.
  mirror,
}

/// One frame's verdict: the phase, whether the frame draws native's
/// layout, and whether a new hand-over starts (restart: take the top and
/// size now, and drop an earlier fallback).
typedef NativeHandoverStep = ({
  NativeHandover phase,
  bool layout,
  bool restart,
});

/// The next step of the hand-over from [phase]. Pure.
///
/// [engaged]: this shell's config is engaged. [releasable]: disengaged by
/// this shell itself (its mode, its destinations), not by another shell
/// taking the chrome. [mine]: native shows this shell's engaged config.
/// [nativeUp]: native shows an engaged config, not hidden. [barMismatch]:
/// that config shows no page bar, so this shell waits with its own.
/// [released]: native applied this shell's disengage or a later config.
/// [timedOut]: the phase's fallback fired. [moved]: the top or the size
/// differs from the hand-over's start; [resized]: the size does.
/// [flutterBar]: the top page draws a Flutter bar in Flutter's layout.
NativeHandoverStep nativeHandoverStep(
  NativeHandover phase, {
  required bool engaged,
  required bool releasable,
  required bool mine,
  required bool nativeUp,
  required bool barMismatch,
  required bool released,
  required bool timedOut,
  required bool moved,
  required bool resized,
  required bool flutterBar,
}) {
  const none = (phase: NativeHandover.none, layout: false, restart: false);
  const done = (phase: NativeHandover.done, layout: true, restart: false);
  NativeHandoverStep stay() => (
    phase: phase,
    layout: phase != NativeHandover.waiting && phase != NativeHandover.mirror,
    restart: false,
  );
  NativeHandoverStep start(NativeHandover next) => (
    phase: next,
    layout: next != NativeHandover.waiting && next != NativeHandover.mirror,
    restart: true,
  );
  NativeHandoverStep letGo() =>
      flutterBar ? start(NativeHandover.mirror) : none;

  if (!engaged) {
    switch (phase) {
      case NativeHandover.holding ||
          NativeHandover.takeover ||
          NativeHandover.done:
        if (!releasable) return none;
        return released ? letGo() : start(NativeHandover.releasing);
      case NativeHandover.releasing:
        if (released) return letGo();
        return timedOut || resized ? none : stay();
      case NativeHandover.mirror:
        return moved || timedOut ? none : stay();
      case NativeHandover.none || NativeHandover.waiting:
        return none;
    }
  }
  switch (phase) {
    case NativeHandover.none || NativeHandover.mirror:
      if (mine) return done;
      return start(
        nativeUp && !barMismatch
            ? NativeHandover.takeover
            : NativeHandover.waiting,
      );
    case NativeHandover.releasing:
      return mine ? done : start(NativeHandover.takeover);
    case NativeHandover.waiting:
      if (timedOut) return done;
      if (!mine) return stay();
      return !flutterBar || moved
          ? done
          : (phase: NativeHandover.holding, layout: true, restart: false);
    case NativeHandover.holding:
      return timedOut || moved ? done : stay();
    case NativeHandover.takeover:
      return mine || resized || timedOut ? done : stay();
    case NativeHandover.done:
      return done;
  }
}

/// Whether native draws a page bar for [config]'s selected tab: the bar
/// of its top page by the same rule as LiquidPage's (`pageTitleModeFor`),
/// at UIKit's size class ([compact]). The search tab always has one; a tab
/// without pages has none. Pure.
bool nativeConfigShowsPageBar(
  LiquidNativeChromeConfig config, {
  required bool compact,
}) {
  final index = config.selectedIndex;
  if (index < 0 || index >= config.tabs.length) return false;
  final tab = config.tabs[index];
  if (tab.search) return true;
  if (tab.pages.isEmpty) return false;
  final page = tab.pages.last;
  return pageTitleModeFor(
        root: tab.pages.length == 1,
        largeTitle: page.largeTitle,
        sizeClass: compact ? LiquidSizeClass.compact : LiquidSizeClass.regular,
        hasActions: page.actions.isNotEmpty,
      ) !=
      PageTitleMode.hidden;
}
