import 'package:flutter/material.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';

/// iOS-style large content viewer: at accessibility text sizes a long press
/// on an icon-only control shows its icon and label large in the middle of
/// the screen until the finger lifts. Below that size it returns [child].
///
/// The long press wins the gesture arena, so lifting the finger after the
/// card appears does not activate the control. No animation, so it already
/// respects reduce motion.
class LargeContentViewer extends StatefulWidget {
  /// Wraps [child] with the long-press viewer.
  const LargeContentViewer({
    required this.icon,
    required this.label,
    required this.child,
    super.key,
  });

  /// Key of the floating card, for tests.
  static const overlayKey = ValueKey<String>('liquid-large-content-viewer');

  /// Icon shown in the card.
  final Widget icon;

  /// Label shown in the card.
  final String label;

  /// The control.
  final Widget child;

  @override
  State<LargeContentViewer> createState() => _LargeContentViewerState();
}

class _LargeContentViewerState extends State<LargeContentViewer> {
  OverlayEntry? _entry;

  void _show() {
    _hide();
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ExcludeSemantics(
          child: Center(
            child: _Card(icon: widget.icon, label: widget.label),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    _entry = entry;
  }

  void _hide() {
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The text scale dropped below AX mid-press: the gesture detector is
    // gone and no long-press end will arrive to remove the card.
    if (!isAxTextScale(context)) _hide();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAxTextScale(context)) return widget.child;
    return GestureDetector(
      excludeFromSemantics: true,
      onLongPressStart: (_) => _show(),
      onLongPressEnd: (_) => _hide(),
      onLongPressCancel: _hide,
      child: widget.child,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Transparent Material: the card lives in the Overlay, outside any
    // Scaffold, and Text needs a Material ancestor for its default style.
    return Material(
      key: LargeContentViewer.overlayKey,
      type: MaterialType.transparency,
      child: LiquidGlass(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: 64,
                  color: theme.colorScheme.onSurface,
                ),
                child: icon,
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
