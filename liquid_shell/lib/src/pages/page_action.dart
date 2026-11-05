import 'package:flutter/widgets.dart';

/// A trailing action in a `LiquidPage`'s bar: a native bar button on iOS
/// 26+ with native chrome, a glass circle in the Flutter bar elsewhere.
///
/// It has no `==`: it holds a callback. The shell compares what the bars
/// show ([sfSymbol], [label], enabled) and always runs the newest
/// [onPressed].
@immutable
class LiquidPageAction {
  /// Creates an action.
  const LiquidPageAction({
    required this.sfSymbol,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : assert(sfSymbol != '', 'sfSymbol names an SF Symbol'),
       assert(label != '', 'label is read by assistive technology');

  /// The native button's image, an SF Symbol name (for example `heart`).
  /// Required: an action never moves its page to the Flutter bar. A name
  /// with no symbol shows [label] as text natively.
  final String sfSymbol;

  /// The Flutter bar's icon. Sized and coloured by the bar.
  final Widget icon;

  /// Semantics label and tooltip; the native accessibility label.
  final String label;

  /// Called on tap. Null disables the action in both bars.
  final VoidCallback? onPressed;
}
