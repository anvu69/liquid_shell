import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/chrome/lens_clip.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

/// The track, for tests.
@visibleForTesting
const kSegmentTrackKey = ValueKey<String>('liquid-segment-track');

/// The rest thumb, for tests.
@visibleForTesting
const kSegmentThumbKey = ValueKey<String>('liquid-segment-thumb');

/// The normal (w400) label row's clip, for tests.
@visibleForTesting
const kSegmentNormalKey = ValueKey<String>('liquid-segment-normal');

/// The selected (w500) label row's clip, for tests.
@visibleForTesting
const kSegmentSelectedKey = ValueKey<String>('liquid-segment-selected');

const BorderRadius _capsule = BorderRadius.all(Radius.circular(999));

/// One segment of a [LiquidSegmentedControl].
@immutable
class LiquidSegment {
  /// Creates a text segment.
  const LiquidSegment({
    required this.label,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The title, one line; it ellipsizes when it does not fit.
  final String label;

  /// Whether the segment can be chosen. A disabled segment draws its label
  /// at half opacity and is never committed.
  final bool enabled;

  /// What a screen reader says instead of [label].
  final String? semanticLabel;
}

/// A segmented control drawn after iOS 26's `UISegmentedControl`, with a
/// liquid lens for its selection (spec VK-550). Controlled: rebuild it with
/// the index [onChanged] reports.
///
/// The visible track is 32 pt tall, centred in a 44 pt box, so every
/// segment's hit target is the full box height × its width. Segments are at
/// least 44 pt wide, except when [expand] fills a width below 44 pt per
/// segment (see there).
class LiquidSegmentedControl extends StatefulWidget {
  /// Creates a segmented control of at least two [segments].
  const LiquidSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.expand = true,
    this.semanticLabel,
    super.key,
  });

  /// The segments, two or more, in index order (right to left in RTL).
  final List<LiquidSegment> segments;

  /// The selected segment, or null for none.
  final int? selectedIndex;

  /// Called with the segment the user chose. Null disables the whole
  /// control (drawn at half opacity).
  final ValueChanged<int>? onChanged;

  /// Fill the incoming width (true) or size to the labels: every segment as
  /// wide as the widest label plus 18 pt (false).
  ///
  /// When filling, the control never overflows: below 44 pt per segment,
  /// every segment shrinks equally to fit (as native's), hit targets follow
  /// the segment width and labels ellipsize. Sized to the labels, every
  /// segment is at least 44 pt wide.
  final bool expand;

  /// What a screen reader says for the control as a whole.
  final String? semanticLabel;

  @override
  State<LiquidSegmentedControl> createState() => _LiquidSegmentedControlState();
}

class _LiquidSegmentedControlState extends State<LiquidSegmentedControl> {
  bool get _enabled => widget.onChanged != null;

  void _choose(int i) {
    if (!_enabled || !widget.segments[i].enabled) return;
    // Native sends no valueChanged for the selected segment (Task 1,
    // `tapOnSelected`).
    if (i == widget.selectedIndex) return;
    widget.onChanged!(i);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.segments.length;
    final selected = widget.selectedIndex;
    assert(count >= 2, 'LiquidSegmentedControl needs two segments or more.');
    assert(
      selected == null || (selected >= 0 && selected < count),
      'selectedIndex $selected is outside 0..${count - 1}.',
    );
    final theme = LiquidGlassTheme.of(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: SegmentMetrics.maxTextScale);
    final style = theme.segmentLabelStyle;
    final medium = style.copyWith(fontWeight: FontWeight.w500);
    final lineHeight =
        scaler.scale(style.fontSize ?? 13) * (style.height ?? 1.2);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      // Orders the segments' nodes visually, right to left in RTL.
      textDirection: direction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fill = widget.expand && constraints.maxWidth.isFinite;
          final g = segmentGeometry(
            count: count,
            maxWidth: fill ? constraints.maxWidth : double.infinity,
            lineHeight: lineHeight,
            direction: direction,
            mediumLabelWidths: fill
                ? null
                : [
                    for (final s in widget.segments)
                      _width(s.label, medium, scaler, direction),
                  ],
          );
          final thumb = selected == null ? null : g.slots[selected];
          return SizedBox.fromSize(
            size: g.size,
            child: Opacity(
              opacity: _enabled ? 1 : 0.5,
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: g.track,
                    child: DecoratedBox(
                      key: kSegmentTrackKey,
                      decoration: BoxDecoration(
                        color: theme.segmentTrack,
                        borderRadius: _capsule,
                      ),
                    ),
                  ),
                  if (thumb != null)
                    Positioned.fromRect(
                      rect: thumb,
                      child: DecoratedBox(
                        key: kSegmentThumbKey,
                        decoration: BoxDecoration(
                          color: theme.segmentThumb,
                          borderRadius: _capsule,
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: ClipPath(
                      key: kSegmentNormalKey,
                      clipper: LensClip(thumb ?? Rect.zero, inside: false),
                      child: _row(g, style, scaler),
                    ),
                  ),
                  if (thumb != null)
                    Positioned.fill(
                      child: ClipPath(
                        key: kSegmentSelectedKey,
                        clipper: LensClip(thumb, inside: true),
                        child: _row(g, medium, scaler),
                      ),
                    ),
                  for (final (i, s) in widget.segments.indexed)
                    Positioned(
                      left: g.segments[i].left,
                      width: g.segments[i].width,
                      top: 0,
                      bottom: 0,
                      child: Semantics(
                        container: true,
                        button: true,
                        inMutuallyExclusiveGroup: true,
                        selected: i == selected,
                        enabled: _enabled && s.enabled,
                        label: s.semanticLabel ?? s.label,
                        onTap: _enabled && s.enabled ? () => _choose(i) : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Every label in [style], one line, centred in its label box. The rows
  /// draw only: the segment nodes carry the semantics.
  Widget _row(SegmentGeometry g, TextStyle style, TextScaler scaler) =>
      IgnorePointer(
        child: ExcludeSemantics(
          child: DefaultTextStyle(
            style: style,
            child: Stack(
              children: [
                for (final (i, s) in widget.segments.indexed)
                  Positioned.fromRect(
                    rect: g.labels[i],
                    child: Opacity(
                      opacity: s.enabled ? 1 : 0.5,
                      child: Text(
                        s.label,
                        style: style,
                        textScaler: scaler,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  static double _width(
    String label,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
