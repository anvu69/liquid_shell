import 'package:flutter/foundation.dart';

/// How an alert or action-sheet action looks. The platform decides where
/// a cancel action sits.
enum LiquidAlertActionStyle {
  /// A plain action.
  standard,

  /// The cancel action: at most one per dialog. A dismissal without a
  /// choice completes with its value.
  cancel,

  /// A destructive action, drawn in the error colour.
  destructive,
}

/// One button of `showLiquidAlert` or `showLiquidActionSheet`. The dialog's
/// future completes with [value] when the user picks it.
@immutable
class LiquidAlertAction<T> {
  /// Creates an action.
  const LiquidAlertAction({
    required this.label,
    required this.value,
    this.style = LiquidAlertActionStyle.standard,
    this.preferred = false,
    this.enabled = true,
  });

  /// The button's text.
  final String label;

  /// What the dialog completes with when this action is picked.
  final T value;

  /// How it looks.
  final LiquidAlertActionStyle style;

  /// Alerts only: emphasised, and chosen by Return. Action sheets ignore
  /// it, as UIKit does. At most one per dialog.
  final bool preferred;

  /// Whether it can be picked.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is LiquidAlertAction<T> &&
      other.label == label &&
      other.value == value &&
      other.style == style &&
      other.preferred == preferred &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, value, style, preferred, enabled);
}

/// Who draws a dialog.
enum LiquidDialogPresentation {
  /// The platform's own dialog where it has Liquid Glass (iOS 26 and
  /// later); the Flutter glass dialog everywhere else.
  auto,

  /// The platform's own dialog wherever it has one: UIKit's alert on every
  /// iOS, without glass before 26. Flutter glass elsewhere.
  system,

  /// Always the Flutter glass dialog.
  flutter,
}
