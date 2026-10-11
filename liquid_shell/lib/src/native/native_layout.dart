import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/native/native_chrome.dart';
import 'package:liquid_shell/src/search/search_layout.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Whether the shell's chrome is native right now (spec P2 §5.1). Pure.
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
}) =>
    nativeChromePossible(
      mode: mode,
      hasChromeBuilder: hasChromeBuilder,
      describable: describable,
    ) &&
    owner &&
    state != null &&
    state.installed;

/// The conditions of [nativeChromeEngaged] that the shell knows without the
/// platform: the app allows it, it has no custom Flutter chrome, and it
/// can be drawn natively. Pure.
///
/// While the platform has not answered (pending), only a shell for which
/// this holds waits with no chrome; every other one draws Flutter chrome
/// from its first frame.
bool nativeChromePossible({
  required LiquidNativeChrome mode,
  required bool hasChromeBuilder,
  required bool describable,
}) => mode == LiquidNativeChrome.auto && !hasChromeBuilder && describable;

/// Whether every destination and the trailing action have an SF Symbol. The
/// search destination needs none: UIKit's search tab has its own image.
/// Only the first one is the search tab (spec P3b §14); an extra one is
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
/// describe itself (spec P2 §15, E2): one line naming every destination
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
/// the bottom, else the top bar while the sidebar is hidden.
LiquidChromeKind nativeChromeKind({
  required LiquidNativeShellState state,
  required bool hidden,
}) {
  if (hidden) return LiquidChromeKind.hidden;
  if (state.compact) return LiquidChromeKind.bottomBar;
  return switch (state.sidebar) {
    LiquidNativeSidebar.hidden => LiquidChromeKind.topBar,
    LiquidNativeSidebar.overlay => LiquidChromeKind.sidebarOverlay,
    LiquidNativeSidebar.tiled => LiquidChromeKind.sidebarTiled,
  };
}

/// The insets of native chrome. The bar is already in the Flutter view's
/// safe area [padding]: the top bar (or the overlay's held top) in the
/// top padding, the compact bar in the bottom padding. Tiled and hidden
/// cover nothing.
EdgeInsets nativeChromeInsets({
  required LiquidChromeKind kind,
  required EdgeInsets padding,
}) => switch (kind) {
  LiquidChromeKind.topBar ||
  LiquidChromeKind.sidebarOverlay => EdgeInsets.only(top: padding.top),
  LiquidChromeKind.bottomBar => EdgeInsets.only(bottom: padding.bottom),
  _ => EdgeInsets.zero,
};

/// Everything the native chrome shows (spec P2 §6.2).
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
  String? searchPlaceholder,
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
    search: searchIndex == null
        ? null
        : LiquidNativeSearchConfig(placeholder: searchPlaceholder),
  );
}

/// Whether the selected tab has a native navigation bar (spec P3b §8.3).
/// P3b-1: the search tab only, while native chrome is engaged. P3b-2 makes
/// it every engaged tab.
bool nativePageBarFor({
  required bool engaged,
  required int selected,
  required int? searchIndex,
}) => engaged && searchIndex != null && selected == searchIndex;
