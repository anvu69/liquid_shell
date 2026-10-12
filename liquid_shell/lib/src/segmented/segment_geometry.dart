import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:liquid_shell/src/chrome/lens_track.dart';

/// Measured metrics of the native segmented control (spec VK-550 §5).
abstract final class SegmentMetrics {
  /// The track's height at 1x text (spike §2).
  static const double trackHeight = 32;

  /// The minimum hit box (owner rule, Q-C).
  static const double box = 44;

  /// The gap between the track and a resting thumb (spike §2).
  static const double thumbInset = 2;

  /// Half the intrinsic padding around a label: label + 18 (spike §2).
  static const double labelPadding = 9;

  /// The narrowest intrinsic segment (Q-C; native is 32).
  static const double minSegment = 44;

  /// The track height minus one label line: 32 - 15.67.
  static const double labelBoxOffset = 16.33;

  /// How much the pressed thumb grows (spike §3).
  static const Size pressedGrow = Size(24, 16);

  /// The label text scale cap (Q-D).
  static const double maxTextScale = 2;
}

/// The laid-out segments of a control, track-local (spec VK-550 §5).
@immutable
class SegmentGeometry implements LensTrack {
  /// Creates a geometry from already laid-out rects.
  const SegmentGeometry({
    required this.size,
    required this.track,
    required this.segments,
    required this.slots,
    required this.labels,
  });

  /// The box: (W, max(44, H)).
  final Size size;

  /// The visible track: W x H, vertically centred in [size].
  final Rect track;

  /// Segment rects in index order, mirrored in RTL.
  final List<Rect> segments;

  /// The rest thumbs: [segments] deflated by the thumb inset.
  @override
  final List<Rect> slots;

  /// The label boxes, centred in their segment.
  final List<Rect> labels;

  /// The segment whose hit area (full box height) holds [p], or null.
  int? segmentAt(Offset p) {
    if (p.dy < 0 || p.dy > size.height) return null;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (p.dx >= s.left && p.dx < s.right) return i;
    }
    if (segments.isNotEmpty && p.dx == segments.last.right) {
      return segments.length - 1;
    }
    return null;
  }

  @override
  double centreOf(int slot) => slots[slot].center.dx;

  @override
  int slotNearest(double x) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < slots.length; i++) {
      final d = (centreOf(i) - x).abs();
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  @override
  double clampCentre(double x) {
    if (slots.isEmpty) return x;
    final centres = [for (final s in slots) s.center.dx];
    return x.clamp(centres.reduce(math.min), centres.reduce(math.max));
  }

  /// Every thumb has one size, (W/n − 4) × (H − 4), so the lens size does
  /// not depend on [x] (spec §5).
  @override
  Size restLensAt(double x) => slots.isEmpty
      ? Size.zero
      : Size(
          size.width / slots.length - 2 * SegmentMetrics.thumbInset,
          track.height - 2 * SegmentMetrics.thumbInset,
        );

  @override
  Size? get tapInflation => null;

  @override
  bool operator ==(Object other) =>
      other is SegmentGeometry &&
      other.size == size &&
      other.track == track &&
      listEquals(other.segments, segments) &&
      listEquals(other.slots, slots) &&
      listEquals(other.labels, labels);

  @override
  int get hashCode => Object.hash(
    size,
    track,
    Object.hashAll(segments),
    Object.hashAll(slots),
    Object.hashAll(labels),
  );
}

/// Lays out [count] segments (spec VK-550 §5). With [mediumLabelWidths] the
/// width is intrinsic (each segment at least [SegmentMetrics.minSegment],
/// Q-C), else [maxWidth] is filled: below 44 pt per segment the segments
/// shrink equally to fit, as native's do.
SegmentGeometry segmentGeometry({
  required int count,
  required double maxWidth,
  required double lineHeight,
  required TextDirection direction,
  List<double>? mediumLabelWidths,
}) {
  final height = math.max(
    SegmentMetrics.trackHeight,
    lineHeight + SegmentMetrics.labelBoxOffset,
  );
  final boxHeight = math.max(SegmentMetrics.box, height);
  final double segmentWidth;
  if (mediumLabelWidths != null) {
    final widest = mediumLabelWidths.fold<double>(0, math.max);
    segmentWidth = math.max(
      SegmentMetrics.minSegment,
      widest.ceilToDouble() + 2 * SegmentMetrics.labelPadding,
    );
  } else {
    segmentWidth = maxWidth / count;
  }
  final width = mediumLabelWidths == null ? maxWidth : segmentWidth * count;
  final trackTop = (boxHeight - height) / 2;
  const inset = SegmentMetrics.thumbInset;
  final segments = <Rect>[];
  for (var i = 0; i < count; i++) {
    // x = i * W / n, multiplied first so the rects match the native sums.
    final slot = direction == TextDirection.rtl ? count - 1 - i : i;
    segments.add(
      Rect.fromLTRB(
        slot * width / count,
        trackTop,
        (slot + 1) * width / count,
        trackTop + height,
      ),
    );
  }
  final labelWidth = math.max(
    0,
    segmentWidth - 2 * SegmentMetrics.labelPadding,
  );
  return SegmentGeometry(
    size: Size(width, boxHeight),
    track: Rect.fromLTWH(0, trackTop, width, height),
    segments: segments,
    slots: [for (final s in segments) s.deflate(inset)],
    labels: [
      for (final s in segments)
        Rect.fromCenter(
          center: s.center,
          width: labelWidth.toDouble(),
          height: lineHeight,
        ),
    ],
  );
}
