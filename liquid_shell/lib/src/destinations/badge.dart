import 'package:flutter/material.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// A badge on a destination: a count or a dot.
@immutable
sealed class LiquidBadge {
  const LiquidBadge._();

  /// Numeric badge. Shows "max+" above [LiquidCountBadge.max]. Hidden when
  /// the count is 0.
  const factory LiquidBadge.count(int count, {int max}) = LiquidCountBadge;

  /// Small dot with no number.
  const factory LiquidBadge.dot() = LiquidDotBadge;
}

/// A numeric badge. See [LiquidBadge.count].
final class LiquidCountBadge extends LiquidBadge {
  /// Creates a count badge. [count] must not be negative.
  const LiquidCountBadge(this.count, {this.max = 99})
    : assert(count >= 0, 'count must not be negative'),
      assert(max > 0, 'max must be positive'),
      super._();

  /// The number to show. 0 hides the badge.
  final int count;

  /// Above this the badge shows "max+".
  final int max;

  @override
  bool operator ==(Object other) =>
      other is LiquidCountBadge && other.count == count && other.max == max;

  @override
  int get hashCode => Object.hash(count, max);
}

/// A dot badge. See [LiquidBadge.dot].
final class LiquidDotBadge extends LiquidBadge {
  /// Creates a dot badge.
  const LiquidDotBadge() : super._();

  @override
  bool operator ==(Object other) => other is LiquidDotBadge;

  @override
  int get hashCode => (LiquidDotBadge).hashCode;
}

/// Whether [badge] draws anything. A count of 0 (or a negative count in
/// release builds) is hidden.
bool badgeVisible(LiquidBadge? badge) => switch (badge) {
  null => false,
  LiquidDotBadge() => true,
  LiquidCountBadge(:final count) => count > 0,
};

/// The visible text of a count badge.
String badgeText(LiquidCountBadge badge) =>
    badge.count > badge.max ? '${badge.max}+' : '${badge.count}';

/// [label] followed by the spoken badge, for example "Inbox, 3 new".
String badgeSemanticsLabel(
  String label,
  LiquidBadge? badge,
  LiquidShellStrings strings,
) {
  if (!badgeVisible(badge)) return label;
  return switch (badge!) {
    LiquidDotBadge() => '$label, ${strings.badgeDot}',
    LiquidCountBadge(:final count) => '$label, ${strings.badgeCount(count)}',
  };
}

/// Draws a [LiquidBadge]: an error-coloured capsule (min 16×16, 11/16 w600
/// text) or an 8×8 dot. Adds no semantics; the label carries the badge.
class LiquidBadgeView extends StatelessWidget {
  /// Creates the badge view.
  const LiquidBadgeView({required this.badge, super.key});

  /// The badge to draw.
  final LiquidBadge badge;

  @override
  Widget build(BuildContext context) {
    if (!badgeVisible(badge)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: switch (badge) {
        LiquidDotBadge() => SizedBox.square(
          dimension: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
        final LiquidCountBadge count => DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  badgeText(count),
                  style: TextStyle(
                    fontSize: 11,
                    height: 16 / 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onError,
                  ),
                ),
              ),
            ),
          ),
        ),
      },
    );
  }
}
