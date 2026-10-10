import 'package:flutter/foundation.dart';
import 'package:liquid_shell/src/search/search_controller.dart';

/// The search tab's field (spec P3b §4.2). Give it to `LiquidShell.search`
/// with a destination whose role is `LiquidDestinationRole.search`.
@immutable
class LiquidSearch {
  /// Creates the search config.
  const LiquidSearch({
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
  });

  /// The query, the active state and the scope; owned by the app.
  final LiquidSearchController controller;

  /// Text of the empty field. Null: the platform's own ("Search" in the
  /// device language natively, `LiquidShellStrings.searchPlaceholder` in
  /// the Flutter field).
  final String? placeholder;

  /// Every text change the user makes, IME composition included. Not called
  /// for text the app sets through [controller].
  final ValueChanged<String>? onChanged;

  /// The user pressed the keyboard's Search key.
  final ValueChanged<String>? onSubmitted;

  /// Field by field; callbacks by identity.
  @override
  bool operator ==(Object other) =>
      other is LiquidSearch &&
      identical(other.controller, controller) &&
      other.placeholder == placeholder &&
      other.onChanged == onChanged &&
      other.onSubmitted == onSubmitted;

  @override
  int get hashCode =>
      Object.hash(controller, placeholder, onChanged, onSubmitted);
}
