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
  });

  /// The icon. Sized and coloured by the shell.
  final Widget icon;

  /// Called on tap.
  final VoidCallback onPressed;

  /// Screen-reader label and tooltip. Also the visible text of the sidebar
  /// row.
  final String semanticLabel;

  /// Field by field. Widgets ([icon]) and callbacks ([onPressed]) compare by
  /// identity; use const or stable instances, or two equal-looking actions
  /// are never `==`.
  @override
  bool operator ==(Object other) =>
      other is LiquidTabAction &&
      other.icon == icon &&
      other.onPressed == onPressed &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(icon, onPressed, semanticLabel);
}
