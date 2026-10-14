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
    this.scopes,
    this.onChanged,
    this.onSubmitted,
    this.dismissKeyboardOnDrag = true,
  }) : assert(
         scopes == null || scopes.length >= 2,
         'LiquidSearch.scopes needs two titles or more, or null.',
       );

  /// The query, the active state and the scope. Owned by the app: the app
  /// creates and disposes it and keeps it alive as long as the shell; the
  /// shell never disposes it. A new controller between builds is fine.
  final LiquidSearchController controller;

  /// Text of the empty field. Null: the platform's own ("Search" in the
  /// device language natively, `LiquidShellStrings.searchPlaceholder` in
  /// the Flutter field).
  final String? placeholder;

  /// Scope titles ("All", "Songs", "Places"), two or more, or null for none
  /// (spec VK-550 §11). Native chrome on iOS 26+ shows them in UIKit's scope
  /// bar while the search is active; elsewhere `LiquidSearchScopeBar` shows
  /// them. Bound to [LiquidSearchController.scopeIndex].
  final List<String>? scopes;

  /// Every text change the user makes, IME composition included. Not called
  /// for text the app sets through [controller].
  final ValueChanged<String>? onChanged;

  /// The user pressed the keyboard's Search key.
  final ValueChanged<String>? onSubmitted;

  /// Whether a user drag that scrolls the shell's body (the results, a
  /// page pushed in the search tab) puts the keyboard away while the search
  /// is active, keeping the search, as Apple Music does. A programmatic
  /// scroll never does. Default true. See
  /// `LiquidSearchController.dismissKeyboard`.
  final bool dismissKeyboardOnDrag;

  /// Field by field, [scopes] by value; callbacks by identity.
  @override
  bool operator ==(Object other) =>
      other is LiquidSearch &&
      identical(other.controller, controller) &&
      other.placeholder == placeholder &&
      listEquals(other.scopes, scopes) &&
      other.onChanged == onChanged &&
      other.onSubmitted == onSubmitted &&
      other.dismissKeyboardOnDrag == dismissKeyboardOnDrag;

  @override
  int get hashCode => Object.hash(
    controller,
    placeholder,
    scopes == null ? null : Object.hashAll(scopes!),
    onChanged,
    onSubmitted,
    dismissKeyboardOnDrag,
  );
}
