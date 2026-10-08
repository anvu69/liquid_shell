import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/policy.dart';

/// Sets the [LiquidGlassPolicy] for a subtree.
///
/// Put it in `MaterialApp.builder` for an app-wide policy. Without one,
/// `const LiquidGlassPolicy()` applies.
class LiquidGlassScope extends InheritedWidget {
  /// Creates a scope.
  const LiquidGlassScope({
    required this.policy,
    required super.child,
    super.key,
  });

  /// The policy for this subtree.
  final LiquidGlassPolicy policy;

  /// The nearest scope's policy, or `const LiquidGlassPolicy()`.
  static LiquidGlassPolicy policyOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassScope>()?.policy ??
      const LiquidGlassPolicy();

  @override
  bool updateShouldNotify(LiquidGlassScope oldWidget) =>
      policy != oldWidget.policy;
}
