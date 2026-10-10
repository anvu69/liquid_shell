import 'package:flutter/widgets.dart';

/// An action at the trailing end of the tab bar (for example search). Also
/// shown as the first sidebar row while the sidebar is visible.
@immutable
class LiquidTabAction {
  /// Creates an action.
  const LiquidTabAction({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.sfSymbol,
  });

  /// The icon. Sized and coloured by the shell.
  final Widget icon;

  /// Called on tap.
  final VoidCallback onPressed;

  /// Screen-reader label and tooltip. Also the visible text of the sidebar
  /// row.
  final String semanticLabel;

  /// SF Symbol name (for example `magnifyingglass`) for native chrome,
  /// where the action is pinned to the tab bar's trailing end. Native chrome
  /// needs it: without it a shell with this action draws Flutter chrome,
  /// also on iOS 26, and logs one line in debug saying so.
  final String? sfSymbol;

  /// Field by field. Widgets ([icon]) and callbacks ([onPressed]) compare by
  /// identity; use const or stable instances, or two equal-looking actions
  /// are never `==`.
  @override
  bool operator ==(Object other) =>
      other is LiquidTabAction &&
      other.icon == icon &&
      other.onPressed == onPressed &&
      other.semanticLabel == semanticLabel &&
      other.sfSymbol == sfSymbol;

  @override
  int get hashCode => Object.hash(icon, onPressed, semanticLabel, sfSymbol);
}
