import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

const double line = 15.67;

void main() {
  SegmentGeometry full(int n, {TextDirection d = TextDirection.ltr}) =>
      segmentGeometry(count: n, maxWidth: 370, lineHeight: line, direction: d);

  test('3 segments at 370: native thumbs within ±1 (spike §2)', () {
    final g = full(3);
    expect(g.size, const Size(370, 44));
    expect(g.track, const Rect.fromLTWH(0, 6, 370, 32));
    const native = [
      Rect.fromLTWH(2, 8, 119, 28),
      Rect.fromLTWH(125, 8, 119, 28),
      Rect.fromLTWH(248, 8, 120, 28),
    ];
    for (var i = 0; i < 3; i++) {
      expect(g.slots[i].left, closeTo(native[i].left, 1));
      expect(g.slots[i].width, closeTo(native[i].width, 1));
      expect(g.slots[i].top, 8);
      expect(g.slots[i].height, 28);
    }
  });

  test('2 and 5 segments: thumbs 181 and 70 wide', () {
    expect(full(2).slots.first.width, closeTo(181, 1));
    expect(full(5).slots.first.width, closeTo(70, 1));
  });

  test('intrinsic: widest Medium label + 18, segments ≥ 44 (Q-C)', () {
    SegmentGeometry intrinsic(List<double> w) => segmentGeometry(
      count: w.length,
      maxWidth: double.infinity,
      lineHeight: line,
      direction: TextDirection.ltr,
      mediumLabelWidths: w,
    );
    expect(intrinsic(const [16, 39, 40.67]).size.width, 177);
    expect(intrinsic(const [16, 97.7]).size.width, closeTo(234, 2));
    expect(intrinsic(const [9.3, 8.7, 9]).size.width, 132);
  });

  test('RTL mirrors: segment 0 is at the right', () {
    final g = full(3, d: TextDirection.rtl);
    expect(g.segments[0].right, 370);
    expect(g.segments[2].left, 0);
  });

  test('text scale 2: the track grows, the box follows', () {
    final g = segmentGeometry(
      count: 3,
      maxWidth: 370,
      lineHeight: line * 2,
      direction: TextDirection.ltr,
    );
    expect(g.track.height, closeTo(line * 2 + 16.33, 0.01));
    expect(g.size.height, g.track.height);
    expect(g.slots.first.height, g.track.height - 4);
  });

  test('LensTrack: nearest, clamp, hit area over the whole box', () {
    final g = full(3);
    expect(g.slotNearest(10), 0);
    expect(g.slotNearest(200), 1);
    expect(g.clampCentre(0), g.slots.first.center.dx);
    expect(g.clampCentre(999), g.slots.last.center.dx);
    expect(g.segmentAt(const Offset(200, 1)), 1);
    expect(g.segmentAt(const Offset(200, 43)), 1);
    expect(g.segmentAt(const Offset(200, 45)), isNull);
    expect(g.restLensAt(200), const Size(119.33333333333334, 28));
    expect(g.tapInflation, isNull);
  });
}
