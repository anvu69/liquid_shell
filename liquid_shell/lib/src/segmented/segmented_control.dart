import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/chrome/lens_clip.dart';
import 'package:liquid_shell/src/chrome/sized_layout_builder.dart';
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
class LiquidSegment with Diagnosticable {
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

  @override
  bool operator ==(Object other) =>
      other is LiquidSegment &&
      other.label == label &&
      other.enabled == enabled &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(label, enabled, semanticLabel);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// A segmented control drawn after iOS 26's `UISegmentedControl`, with a
/// liquid lens for its selection (spec VK-550). Controlled: rebuild it with
/// the index [onChanged] reports.
///
/// The visible track is 32 pt tall, centred in a 44 pt box, so every
/// segment's hit target is the full box height × its width. Segments are at
/// least 44 pt wide, except in a width below 44 pt per segment (see
/// [expand]). It never overflows its parent and never cuts a segment off.
///
/// A negative [selectedIndex] fails at construction; fewer than two
/// [segments] or a [selectedIndex] past the last segment fail at build (a
/// const constructor cannot read a list's length).
class LiquidSegmentedControl extends StatefulWidget {
  /// Creates a segmented control of at least two [segments].
  const LiquidSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.expand = true,
    this.semanticLabel,
    super.key,
  }) : assert(
         selectedIndex == null || selectedIndex >= 0,
         'selectedIndex must not be negative.',
       );

  /// The segments, two or more, in index order (right to left in RTL).
  final List<LiquidSegment> segments;

  /// The selected segment, or null for none.
  final int? selectedIndex;

  /// Called with the index of the segment the user chose, in [segments].
  /// Not called for the segment already selected or for a disabled one.
  /// Null disables the whole control (drawn at half opacity).
  final ValueChanged<int>? onChanged;

  /// Fill the incoming width (true) or size to the labels (false): every
  /// segment as wide as the widest label (Medium weight) plus 18 pt, and at
  /// least 44 pt.
  ///
  /// - Under an unbounded width (in a `Row` without `Expanded`, or asked
  ///   for its intrinsic width) the control sizes to the labels either way.
  /// - It never overflows: when the width it is given is narrower than it
  ///   asks for, every segment shrinks equally to fit, as native's do.
  ///   Below 44 pt per segment, hit targets follow the segment width, and
  ///   labels that do not fit ellipsize.
  final bool expand;

  /// What a screen reader says for the control as a whole.
  final String? semanticLabel;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<LiquidSegment>('segments', segments))
      ..add(IntProperty('selectedIndex', selectedIndex, ifNull: 'none'))
      ..add(
        FlagProperty('enabled', value: onChanged != null, ifFalse: 'disabled'),
      )
      ..add(
        FlagProperty(
          'expand',
          value: expand,
          ifTrue: 'expand',
          ifFalse: 'intrinsic',
        ),
      )
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }

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
    // An override without a size or a line height keeps the spec's 13 pt
    // on 15.67, so the drawn line and the geometry's agree.
    final themed = theme.segmentLabelStyle;
    final fontSize = themed.fontSize ?? SegmentMetrics.labelSize;
    final style = themed.copyWith(
      fontSize: fontSize,
      height:
          themed.height ?? SegmentMetrics.labelLine / SegmentMetrics.labelSize,
    );
    final medium = style.copyWith(fontWeight: FontWeight.w500);
    final lineHeight = scaler.scale(fontSize) * style.height!;
    List<double>? widths;

    SegmentGeometry geometryFor(BoxConstraints constraints) {
      SegmentGeometry fill(double width) => segmentGeometry(
        count: count,
        maxWidth: width,
        lineHeight: lineHeight,
        direction: direction,
      );
      final maxWidth = constraints.maxWidth;
      if (widget.expand && maxWidth.isFinite) return fill(maxWidth);
      final intrinsic = segmentGeometry(
        count: count,
        maxWidth: double.infinity,
        lineHeight: lineHeight,
        direction: direction,
        mediumLabelWidths: widths ??= [
          for (final s in widget.segments)
            _width(s.label, medium, scaler, direction),
        ],
      );
      // Never cut a segment off: too narrow for the labels, shrink to fit.
      return intrinsic.size.width > maxWidth ? fill(maxWidth) : intrinsic;
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      // Orders the segments' nodes visually, right to left in RTL.
      textDirection: direction,
      // Answers intrinsic sizes, which a LayoutBuilder cannot (an
      // IntrinsicWidth, an AlertDialog's content).
      child: SizedLayoutBuilder(
        sizeFor: (constraints) => geometryFor(constraints).size,
        builder: (context, constraints) {
          final g = geometryFor(constraints);
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
  /// draw only: the segment nodes carry the semantics. The DefaultTextStyle
  /// keeps the ambient one out: under a MaterialApp with no Material above,
  /// it is the yellow-underlined error style, and [style] inherits.
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
