import 'package:flutter/material.dart';

/// The note's first words on a case that keeps the Flutter chrome.
const kDrawnByFlutter = 'Drawn by Flutter';

/// Why the case below keeps the Flutter chrome where native chrome is
/// available (iOS 26), or null for a case that runs native there. The case
/// list puts it above every case; [DrawnByFlutterNote] shows it.
class DrawnByFlutter extends InheritedWidget {
  /// Provides [reason] to [child].
  const DrawnByFlutter({required this.reason, required super.child, super.key});

  /// One line: why this case is drawn by Flutter. Null: no note.
  final String? reason;

  /// The nearest [reason], or null.
  static String? reasonOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DrawnByFlutter>()?.reason;

  @override
  bool updateShouldNotify(DrawnByFlutter oldWidget) =>
      oldWidget.reason != reason;
}

/// A small note, "Drawn by Flutter" and the [DrawnByFlutter.reason] above
/// it. Shows nothing without a reason.
class DrawnByFlutterNote extends StatelessWidget {
  /// Creates the note.
  const DrawnByFlutterNote({super.key});

  @override
  Widget build(BuildContext context) {
    final reason = DrawnByFlutter.reasonOf(context);
    if (reason == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.brush_outlined,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kDrawnByFlutter,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      reason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
