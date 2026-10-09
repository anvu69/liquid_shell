import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/native/native_chrome.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Whether the shell's chrome is native right now (spec P2 §5.1). Pure.
///
/// Every condition must hold: the app allows it, this shell owns the
/// window's native chrome, the platform installed it, the platform's size
/// class is regular, the shell's own width is regular, the shell has no
/// custom Flutter chrome, and every destination (and the trailing action)
/// can be drawn natively.
bool nativeChromeEngaged({
  required LiquidNativeChrome mode,
  required bool owner,
  required LiquidNativeShellState? state,
  required ShellPresentation presentation,
  required bool hasChromeBuilder,
  required bool describable,
}) =>
    nativeChromePossible(
      mode: mode,
      presentation: presentation,
      hasChromeBuilder: hasChromeBuilder,
      describable: describable,
    ) &&
    owner &&
    state != null &&
    state.installed &&
    !state.compact;

/// The conditions of [nativeChromeEngaged] that the shell knows without the
/// platform: the app allows it, the shell's width is regular, it has no
/// custom Flutter chrome, and it can be drawn natively. Pure.
///
/// While the platform has not answered (pending), only a shell for which
/// this holds waits with no chrome; every other one draws Flutter chrome
/// from its first frame.
bool nativeChromePossible({
  required LiquidNativeChrome mode,
  required ShellPresentation presentation,
  required bool hasChromeBuilder,
  required bool describable,
}) =>
    mode == LiquidNativeChrome.auto &&
    presentation != ShellPresentation.compact &&
    !hasChromeBuilder &&
    describable;

/// Whether every destination and the trailing action have an SF Symbol.
bool nativeDescribable(
  List<LiquidDestination> destinations,
  LiquidTabAction? trailing,
) =>
    destinations.isNotEmpty &&
    destinations.every((d) => d.sfSymbol != null) &&
    (trailing == null || trailing.sfSymbol != null);

/// The native badge text: a count as drawn by the Flutter badge, `''` for
/// a dot (UIKit draws an empty badge as a dot), null when hidden.
String? nativeBadgeText(LiquidBadge? badge) {
  if (!badgeVisible(badge)) return null;
  return switch (badge!) {
    LiquidDotBadge() => '',
    final LiquidCountBadge count => badgeText(count),
  };
}

/// The chrome kind while native chrome is engaged. The tab bar shows when
/// the sidebar is hidden; UIKit's own compact bar never engages.
LiquidChromeKind nativeChromeKind({
  required LiquidNativeShellState state,
  required bool hidden,
}) {
  if (hidden) return LiquidChromeKind.hidden;
  return switch (state.sidebar) {
    LiquidNativeSidebar.hidden => LiquidChromeKind.topBar,
    LiquidNativeSidebar.overlay => LiquidChromeKind.sidebarOverlay,
    LiquidNativeSidebar.tiled => LiquidChromeKind.sidebarTiled,
  };
}

/// The insets of native chrome: the tab bar (or the overlay's held top) is
/// already in the Flutter view's safe area, so the top inset is the top
/// padding; tiled and hidden cover nothing.
EdgeInsets nativeChromeInsets({
  required LiquidChromeKind kind,
  required double topPadding,
}) => switch (kind) {
  LiquidChromeKind.topBar ||
  LiquidChromeKind.sidebarOverlay => EdgeInsets.only(top: topPadding),
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
}) => LiquidNativeChromeConfig(
  engaged: engaged,
  tabs: [
    for (final d in destinations)
      LiquidNativeTab(
        title: d.label,
        sfSymbol: d.sfSymbol ?? '',
        badge: nativeBadgeText(d.badge),
        sidebarOnly: d.placement == LiquidPlacement.sidebarOnly,
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
);
