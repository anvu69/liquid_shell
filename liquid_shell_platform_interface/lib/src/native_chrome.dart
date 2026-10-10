import 'package:flutter/foundation.dart';
import 'package:liquid_shell_platform_interface/src/window_controls.dart';

/// Where the native sidebar is.
enum LiquidNativeSidebar {
  /// Closed, or the layout is compact.
  hidden,

  /// Shown over the content (portrait); the content keeps its size.
  overlay,

  /// Shown beside the content (landscape); the platform reports its width
  /// as the start safe-area inset.
  tiled,
}

/// Why native chrome is not installed.
enum LiquidNativeUnavailableReason {
  /// The platform has no native chrome (Android, web, desktop, tests).
  unsupportedPlatform,

  /// iOS or iPadOS before 26.
  osTooOld,

  /// An iPad app running on a Mac ("Designed for iPad").
  iPadAppOnMac,

  /// The app did not opt in (`LiquidShellNativeChrome` in Info.plist).
  notEnabled,

  /// The diagnostic environment variable `LIQUID_SHELL_NATIVE_OFF=1`.
  disabledByEnvironment,

  /// The scene's root view controller is not a `FlutterViewController`.
  rootNotFlutter,

  /// The plugin registered after the scene connected; installing then
  /// would detach a visible Flutter view.
  registeredLate,

  /// A channel call failed.
  channelError,
}

/// The native shell as the platform reports it.
@immutable
class LiquidNativeShellState {
  /// Creates a state.
  const LiquidNativeShellState({
    required this.installed,
    this.compact = false,
    this.sidebar = LiquidNativeSidebar.hidden,
    this.unavailableReason,
  });

  /// No native chrome on this platform.
  static const unavailable = LiquidNativeShellState(
    installed: false,
    unavailableReason: LiquidNativeUnavailableReason.unsupportedPlatform,
  );

  /// Whether the native container is installed in the window.
  final bool installed;

  /// Whether the platform's horizontal size class is compact.
  final bool compact;

  /// The native sidebar.
  final LiquidNativeSidebar sidebar;

  /// Set when [installed] is false.
  final LiquidNativeUnavailableReason? unavailableReason;

  /// Whether the sidebar is shown.
  bool get sidebarVisible => sidebar != LiquidNativeSidebar.hidden;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeShellState &&
      other.installed == installed &&
      other.compact == compact &&
      other.sidebar == sidebar &&
      other.unavailableReason == unavailableReason;

  @override
  int get hashCode =>
      Object.hash(installed, compact, sidebar, unavailableReason);

  @override
  String toString() =>
      'LiquidNativeShellState(installed: $installed, compact: $compact, '
      'sidebar: ${sidebar.name}, '
      'unavailableReason: ${unavailableReason?.name})';
}

/// One native tab: a tab bar item and a sidebar row.
@immutable
class LiquidNativeTab {
  /// Creates a tab.
  const LiquidNativeTab({
    required this.title,
    required this.sfSymbol,
    this.badge,
    this.sidebarOnly = false,
  });

  /// Visible title and accessibility label.
  final String title;

  /// SF Symbol name, for example `house`.
  final String sfSymbol;

  /// Badge text; an empty string draws a dot; null draws none.
  final String? badge;

  /// Shown in the sidebar only, never in the tab bar.
  final bool sidebarOnly;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeTab &&
      other.title == title &&
      other.sfSymbol == sfSymbol &&
      other.badge == badge &&
      other.sidebarOnly == sidebarOnly;

  @override
  int get hashCode => Object.hash(title, sfSymbol, badge, sidebarOnly);

  @override
  String toString() =>
      'LiquidNativeTab(title: $title, sfSymbol: $sfSymbol, badge: $badge, '
      'sidebarOnly: $sidebarOnly)';
}

/// A native action item: the trailing tab bar action.
@immutable
class LiquidNativeAction {
  /// Creates an action.
  const LiquidNativeAction({required this.title, required this.sfSymbol});

  /// Accessibility label, and the sidebar row text.
  final String title;

  /// SF Symbol name.
  final String sfSymbol;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeAction &&
      other.title == title &&
      other.sfSymbol == sfSymbol;

  @override
  int get hashCode => Object.hash(title, sfSymbol);

  @override
  String toString() => 'LiquidNativeAction(title: $title, sfSymbol: $sfSymbol)';
}

/// The native sidebar footer.
@immutable
class LiquidNativeFooter {
  /// Creates a footer.
  const LiquidNativeFooter({
    required this.title,
    required this.subtitle,
    required this.sfSymbol,
    required this.semanticLabel,
  });

  /// First line.
  final String title;

  /// Second line.
  final String subtitle;

  /// SF Symbol name.
  final String sfSymbol;

  /// Accessibility label of the whole footer.
  final String semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeFooter &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.sfSymbol == sfSymbol &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(title, subtitle, sfSymbol, semanticLabel);

  @override
  String toString() =>
      'LiquidNativeFooter(title: $title, subtitle: $subtitle, '
      'sfSymbol: $sfSymbol, semanticLabel: $semanticLabel)';
}

/// Everything the native chrome shows, sent whole on every change.
///
/// The platform applies it in a fixed order: tabs, then the selection,
/// then the footer, tint, appearance and direction, then visibility. A
/// selection therefore always lands on tabs that exist.
@immutable
class LiquidNativeChromeConfig {
  /// Creates a config.
  const LiquidNativeChromeConfig({
    required this.engaged,
    this.tabs = const [],
    this.selectedIndex = 0,
    this.trailing,
    this.footer,
    this.tintArgb = 0xFF007AFF,
    this.dark = false,
    this.rtl = false,
    this.hidden = false,
    this.interactive = true,
  });

  /// No shell uses native chrome: hidden, and Flutter gets the whole window.
  static const dormant = LiquidNativeChromeConfig(engaged: false);

  /// Whether a shell draws its chrome natively.
  final bool engaged;

  /// Every destination, in shell order.
  final List<LiquidNativeTab> tabs;

  /// Index into [tabs].
  final int selectedIndex;

  /// The trailing action, or null.
  final LiquidNativeAction? trailing;

  /// The sidebar footer, or null.
  final LiquidNativeFooter? footer;

  /// Tint as `Color.toARGB32()`.
  final int tintArgb;

  /// Dark appearance for the native chrome.
  final bool dark;

  /// Right-to-left layout for the native chrome.
  final bool rtl;

  /// Hide the chrome while [engaged] (a page hides it, or the shell's route
  /// is covered).
  final bool hidden;

  /// Whether the chrome takes touches (false while a modal route is above
  /// the shell).
  final bool interactive;

  /// Whether the native chrome is on screen.
  bool get visible => engaged && !hidden;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeChromeConfig &&
      other.engaged == engaged &&
      listEquals(other.tabs, tabs) &&
      other.selectedIndex == selectedIndex &&
      other.trailing == trailing &&
      other.footer == footer &&
      other.tintArgb == tintArgb &&
      other.dark == dark &&
      other.rtl == rtl &&
      other.hidden == hidden &&
      other.interactive == interactive;

  @override
  int get hashCode => Object.hash(
    engaged,
    Object.hashAll(tabs),
    selectedIndex,
    trailing,
    footer,
    tintArgb,
    dark,
    rtl,
    hidden,
    interactive,
  );

  @override
  String toString() =>
      'LiquidNativeChromeConfig(engaged: $engaged, tabs: $tabs, '
      'selectedIndex: $selectedIndex, trailing: $trailing, footer: $footer, '
      'tintArgb: 0x${tintArgb.toRadixString(16).padLeft(8, '0')}, '
      'dark: $dark, rtl: $rtl, hidden: $hidden, interactive: $interactive)';
}

/// Something the native side reports.
@immutable
sealed class LiquidNativeEvent {
  const LiquidNativeEvent();
}

/// The user tapped the native tab or sidebar row of destination [index].
/// The native selection does not change until the shell selects it.
final class LiquidNativeDestinationTapped extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeDestinationTapped(this.index);

  /// Index into the config's tabs.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDestinationTapped && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'LiquidNativeDestinationTapped($index)';
}

/// The user tapped the native trailing action.
final class LiquidNativeTrailingTapped extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeTrailingTapped();

  /// Every instance is equal: the event carries no value.
  @override
  bool operator ==(Object other) => other is LiquidNativeTrailingTapped;

  @override
  int get hashCode => (LiquidNativeTrailingTapped).hashCode;

  @override
  String toString() => 'LiquidNativeTrailingTapped()';
}

/// The user tapped the native sidebar footer.
final class LiquidNativeFooterTapped extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeFooterTapped();

  /// Every instance is equal: the event carries no value.
  @override
  bool operator ==(Object other) => other is LiquidNativeFooterTapped;

  @override
  int get hashCode => (LiquidNativeFooterTapped).hashCode;

  @override
  String toString() => 'LiquidNativeFooterTapped()';
}

/// The native shell changed (sidebar shown or hidden, size class).
final class LiquidNativeStateChanged extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeStateChanged(this.state);

  /// The new state.
  final LiquidNativeShellState state;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeStateChanged && other.state == state;

  @override
  int get hashCode => state.hashCode;

  @override
  String toString() => 'LiquidNativeStateChanged($state)';
}

/// The window controls changed.
final class LiquidWindowControlsChanged extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidWindowControlsChanged(this.controls);

  /// The new value.
  final LiquidWindowControls controls;

  @override
  bool operator ==(Object other) =>
      other is LiquidWindowControlsChanged && other.controls == controls;

  @override
  int get hashCode => controls.hashCode;

  @override
  String toString() => 'LiquidWindowControlsChanged($controls)';
}
