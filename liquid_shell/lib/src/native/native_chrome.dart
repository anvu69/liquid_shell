import 'package:flutter/foundation.dart';

/// Whether a `LiquidShell` may hand its chrome to the platform.
enum LiquidNativeChrome {
  /// Native chrome wherever the platform offers it and the shell can
  /// describe itself natively (spec P2 §5.1): today iPadOS 26 at regular
  /// width, in an app that opted in. Flutter chrome everywhere else.
  auto,

  /// Always Flutter chrome.
  off,
}

/// The native sidebar footer: a profile-style row pinned to the bottom of
/// the native sidebar. Native chrome cannot host Flutter widgets, so this
/// is data; `LiquidShell.sidebarFooter` still draws the Flutter sidebar's.
@immutable
class LiquidNativeSidebarFooter {
  /// Creates a footer.
  const LiquidNativeSidebarFooter({
    required this.title,
    required this.subtitle,
    required this.sfSymbol,
    required this.semanticLabel,
    required this.onPressed,
  });

  /// First line, for example a profile name.
  final String title;

  /// Second line.
  final String subtitle;

  /// SF Symbol name, for example `person.crop.circle`.
  final String sfSymbol;

  /// VoiceOver label of the whole footer.
  final String semanticLabel;

  /// Called on tap, after the native side has closed an overlay sidebar.
  /// It does not run `beforeDestinationChange`: guard it yourself if it
  /// navigates away from unsaved work.
  final VoidCallback onPressed;

  /// Field by field; [onPressed] compares by identity.
  @override
  bool operator ==(Object other) =>
      other is LiquidNativeSidebarFooter &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.sfSymbol == sfSymbol &&
      other.semanticLabel == semanticLabel &&
      other.onPressed == onPressed;

  @override
  int get hashCode =>
      Object.hash(title, subtitle, sfSymbol, semanticLabel, onPressed);
}
