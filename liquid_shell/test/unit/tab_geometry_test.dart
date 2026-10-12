import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

/// Bar-local x → screen x on the 402 pt iPhone 17 Pro (21 pt row margin).
double screenX(double x) => x + TabMetrics.margin;

TabBarGeometry compact(
  int count, {
  double maxWidth = 360,
  bool trailing = false,
  TextDirection direction = TextDirection.ltr,
  double extent = TabMetrics.pillExtent,
}) => compactTabGeometry(
  count: count,
  maxWidth: maxWidth,
  trailing: trailing,
  direction: direction,
  extent: extent,
);

void main() {
  group('compact portrait (research §1.1)', () {
    test('3 tabs: a 274 pill centred at x 64 with 94 × 54 slots', () {
      final g = compact(3);
      expect(g.form, TabBarForm.compact);
      expect(g.size, const Size(360, 62));
      expect(screenX(g.pill.left), 64);
      expect(g.pill.size, const Size(274, 62));
      expect([for (final s in g.slots) screenX(s.left)], [68, 154, 240]);
      expect([for (final s in g.slots) screenX(s.center.dx)], [115, 201, 287]);
      for (final s in g.slots) {
        expect(s.size, const Size(94, 54));
        expect(s.top, 4);
      }
      expect(g.trailing, isNull);
      expect(g.minimizedTrailing, isNull);
    });

    test('neighbouring slots overlap by 8', () {
      final g = compact(4);
      for (var i = 1; i < g.slots.length; i++) {
        expect(g.slots[i - 1].right - g.slots[i].left, closeTo(8, 1e-9));
      }
    });

    test('4 tabs + trailing: pill pinned at the start, circle at the end', () {
      final g = compact(4, trailing: true);
      expect(g.pill, const Rect.fromLTWH(0, 0, 290, 62));
      // The research reads a 68.67 pitch; the formula gives 68.5 (±1 pt).
      expect(g.slots[1].left - g.slots[0].left, closeTo(68.67, 1));
      expect(g.trailing, const Rect.fromLTWH(298, 0, 62, 62));
      expect(screenX(g.trailing!.left), 319);
      expect(
        g.minimizedTrailing,
        Rect.fromCenter(
          center: const Offset(329, 31),
          width: 48,
          height: 48,
        ),
      );
    });

    test('5 tabs fill the 360 maximum', () {
      final g = compact(5);
      expect(g.pill, const Rect.fromLTWH(0, 0, 360, 62));
      expect(g.slots.last.right, 356);
    });

    test('an unbounded width takes the natural 16 + 86·n (+ circle)', () {
      final g = compact(3, maxWidth: double.infinity, trailing: true);
      expect(g.size, const Size(274 + 8 + 62, 62));
      expect(g.pill.width, 274);
    });

    test('minimized: a 48 circle at row start + 7 (screen x 28)', () {
      final g = compact(3);
      expect(g.minimized, const Rect.fromLTWH(7, 7, 48, 48));
      expect(screenX(g.minimized.left), 28);
    });

    test('a taller extent grows the slots, not the pitch', () {
      final g = compact(3, extent: 70);
      expect(g.size.height, 70);
      expect(g.slots.first.size, const Size(94, 62));
      expect(g.minimized.top, 11);
    });

    test('RTL mirrors: slot 0 on the right, pill and circle swapped', () {
      final g = compact(3, trailing: true, direction: TextDirection.rtl);
      expect(g.pill, const Rect.fromLTWH(360 - 274, 0, 274, 62));
      expect(g.trailing, const Rect.fromLTWH(0, 0, 62, 62));
      expect(g.slots.first.center.dx, greaterThan(g.slots.last.center.dx));
      expect(g.minimized, const Rect.fromLTWH(360 - 7 - 48, 7, 48, 48));
    });

    test('no destinations: an empty 16 pt pill without slots', () {
      final g = compact(0);
      expect(g.slots, isEmpty);
      expect(g.pill.width, 16);
    });
  });

  group('queries', () {
    final g = compact(3);

    test('slotNearest picks the closest centre; ties keep the first', () {
      expect(g.slotNearest(94), 0);
      expect(g.slotNearest(136), 0);
      expect(g.slotNearest(138), 1);
      expect(g.slotNearest(-50), 0);
      expect(g.slotNearest(999), 2);
    });

    test('clampCentre stays between the first and last centres', () {
      expect(g.clampCentre(0), 94);
      expect(g.clampCentre(150), 150);
      expect(g.clampCentre(400), 266);
      final rtl = compact(3, direction: TextDirection.rtl);
      expect(rtl.clampCentre(0), 94);
      expect(rtl.clampCentre(400), 266);
    });

    test('no slots: clampCentre is the pill centre, restLensAt is zero', () {
      final empty = compact(0);
      expect(empty.slots, isEmpty);
      expect(empty.clampCentre(0), empty.pill.center.dx);
      expect(empty.clampCentre(400), empty.pill.center.dx);
      expect(empty.restLensAt(empty.pill.center.dx), Size.zero);
    });

    test('restLensAt is the slot size (uniform slots)', () {
      expect(g.restLensAt(150), const Size(94, 54));
      expect(g.restLensAt(250), const Size(94, 54));
    });

    test('restLensAt interpolates between content-sized slots', () {
      const g2 = TabBarGeometry(
        form: TabBarForm.top,
        size: Size(200, 48),
        pill: Rect.fromLTWH(0, 0, 200, 48),
        slots: [Rect.fromLTWH(4, 4, 80, 40), Rect.fromLTWH(84, 4, 100, 40)],
        trailing: null,
        minimized: Rect.fromLTWH(0, 0, 200, 48),
        minimizedTrailing: null,
      );
      expect(g2.restLensAt(44), const Size(80, 40));
      expect(g2.restLensAt(89), const Size(90, 40));
      expect(g2.restLensAt(500), const Size(100, 40));
    });
  });

  group('cell parts', () {
    final slot = compact(3).slots.first;

    test('icon frame: 33 × 28, top 10 below the pill top, centred', () {
      final f = tabIconFrame(slot);
      expect(f.size, const Size(33, 28));
      expect(f.top, 10);
      expect(f.center.dx, slot.center.dx);
    });

    test('label box: top 39, slot width minus 8', () {
      final l = tabLabelBox(slot, 12);
      expect(l, Rect.fromLTWH(slot.left + 4, 39, 86, 12));
    });

    test('badge origin: icon frame right − 4, top − 4; mirrored in RTL', () {
      final f = tabIconFrame(slot);
      expect(
        tabBadgeOrigin(f, 21.33, TextDirection.ltr),
        Offset(f.right - 4, f.top - 4),
      );
      expect(
        tabBadgeOrigin(f, 21.33, TextDirection.rtl),
        Offset(f.left + 4 - 21.33, f.top - 4),
      );
    });
  });

  group('landscape (research §1.2)', () {
    // Home 83.7, Explore 90, Settings 94.7, Inbox 81 = label + 49.
    const labels = <double>[34.7, 41, 45.7, 32];

    test('44 pill, 36 items, 4 gaps, content-sized', () {
      final g = landscapeTabGeometry(
        labelWidths: labels,
        maxWidth: 874 - 2 * TabMetrics.landscapeMargin,
        trailing: true,
        direction: TextDirection.ltr,
      );
      expect(g.form, TabBarForm.landscape);
      expect(g.size.height, 44);
      expect(g.pill.left, 0);
      expect(
        [for (final s in g.slots) s.width],
        [for (final w in labels) closeTo(w + 49, 1e-9)],
      );
      for (final s in g.slots) {
        expect(s.height, 36);
        expect(s.top, 4);
      }
      expect(g.slots[1].left - g.slots[0].right, closeTo(4, 1e-9));
      expect(g.pill.width, closeTo(8 + 349.4 + 12, 1e-9));
      expect(g.trailing!.size, const Size(44, 44));
    });

    test('squeezed proportionally when the row is too narrow', () {
      final g = landscapeTabGeometry(
        labelWidths: labels,
        maxWidth: 300,
        trailing: false,
        direction: TextDirection.ltr,
      );
      expect(g.pill.width, 300);
      expect(g.slots.last.right, closeTo(296, 1e-9));
    });
  });

  group('regular top (research §1.3)', () {
    test('3 tabs: 274 wide, 48 tall, label + 31 items', () {
      final g = topTabGeometry(
        labelWidths: const [47.5, 59.5, 66],
        iconOnly: const [false, false, false],
        maxWidth: 800,
        trailing: false,
        direction: TextDirection.ltr,
      );
      expect(g.form, TabBarForm.top);
      expect(g.pill.size, const Size(274, 48));
      expect(g.pill.left, (800 - 274) / 2);
      expect([for (final s in g.slots) s.width], [78.5, 90.5, 97]);
      for (final s in g.slots) {
        expect(s.height, 40);
      }
    });

    test('4 tabs + search item: 397.5 wide, search 48.5', () {
      final g = topTabGeometry(
        labelWidths: const [47.5, 59.5, 66, 44, 0],
        iconOnly: const [false, false, false, false, true],
        maxWidth: 800,
        trailing: false,
        direction: TextDirection.ltr,
      );
      expect(g.pill.width, 397.5);
      expect(g.slots.last.width, 48.5);
    });

    test('trailing circle 48, gap 8, the group centred', () {
      final g = topTabGeometry(
        labelWidths: const [47.5, 59.5, 66],
        iconOnly: const [false, false, false],
        maxWidth: 800,
        trailing: true,
        direction: TextDirection.ltr,
      );
      expect(g.pill.left, (800 - 274 - 56) / 2);
      expect(g.trailing, Rect.fromLTWH(g.pill.right + 8, 0, 48, 48));
    });
  });
}
