// liquid_shell/test/unit/native_minimize_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/native/native_minimize.dart';

void main() {
  group('MinimizeScrollTracker (spec VK-600 §9.1)', () {
    late MinimizeScrollTracker t;
    setUp(() => t = MinimizeScrollTracker());

    MinimizeScrollResult drag(
      double pixels,
      double delta, {
      int tab = 0,
      double min = 0,
    }) => t.update(
      tab: tab,
      pixels: pixels,
      minScrollExtent: min,
      delta: delta,
      dragging: true,
    );

    MinimizeScrollResult fling(double pixels, double delta, {int tab = 0}) =>
        t.update(
          tab: tab,
          pixels: pixels,
          minScrollExtent: 0,
          delta: delta,
          dragging: false,
        );

    test('one scroll view: the offset is its pixels', () {
      t.start(tab: 0);
      expect(drag(40, 40), MinimizeScrollResult.moved);
      expect(drag(300, 260), MinimizeScrollResult.moved);
      expect(t.offsetOf(0), 300);
      expect(drag(300, 0), MinimizeScrollResult.none);
    });

    test('at and past the top: pixels below minScrollExtent', () {
      t.start(tab: 0);
      drag(100, 100);
      drag(-30, -130);
      expect(t.offsetOf(0), -30);
      t.start(tab: 0);
      drag(-100, 0, min: -100);
      expect(t.offsetOf(0), 0);
    });

    test('several views: continuous, then the snap to the top', () {
      t.start(tab: 0);
      drag(500, 500); // list A
      t.start(tab: 0);
      drag(50, -50); // list B, from 100
      expect(t.offsetOf(0), 450);
      drag(1, -49);
      expect(t.offsetOf(0), 401);
      drag(0, -1);
      expect(t.offsetOf(0), 0);
    });

    test('a view below its own top never reads as the top', () {
      t.start(tab: 1);
      drag(10, 10, tab: 1);
      t.start(tab: 1);
      drag(350, -50, tab: 1);
      expect(t.offsetOf(1), kMinimizeAwayFromTop);
    });

    test('tabs keep their own offsets; forget drops one', () {
      drag(200, 200);
      drag(80, 80, tab: 2);
      expect(t.offsetOf(0), 200);
      expect(t.offsetOf(2), 80);
      t.forget(2);
      expect(t.offsetOf(2), 0);
    });

    test('a fling up to the top expands, once per scroll', () {
      t.start(tab: 0);
      drag(400, 400);
      expect(fling(200, -200), MinimizeScrollResult.moved);
      expect(fling(-12, -212), MinimizeScrollResult.expand);
      expect(fling(-20, -8), MinimizeScrollResult.moved);
      expect(fling(0, 20), MinimizeScrollResult.moved); // the bounce back
      t.start(tab: 0);
      expect(fling(0, 0), MinimizeScrollResult.none);
    });

    test('a drag to the top never expands; nor does a bounce back', () {
      t.start(tab: 0);
      drag(300, 300);
      expect(drag(-40, -340), MinimizeScrollResult.moved);
      expect(fling(-10, 30), MinimizeScrollResult.moved);
      expect(fling(0, 10), MinimizeScrollResult.moved);
    });

    test('a programmatic scroll to the top expands', () {
      t.start(tab: 0);
      drag(600, 600);
      t.start(tab: 0); // animateTo starts its own scroll
      expect(fling(300, -300), MinimizeScrollResult.moved);
      expect(fling(0, -300), MinimizeScrollResult.expand);
    });

    testWidgets('the adapter reads vertical notifications only', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      FixedScrollMetrics metrics(double pixels, AxisDirection direction) =>
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: pixels,
            viewportDimension: 800,
            axisDirection: direction,
            devicePixelRatio: 3,
          );
      final tracker = MinimizeScrollTracker();
      expect(
        tracker.handleNotification(
          ScrollStartNotification(
            metrics: metrics(0, AxisDirection.down),
            context: context,
          ),
          tab: 0,
        ),
        MinimizeScrollResult.none,
      );
      expect(
        tracker.handleNotification(
          ScrollUpdateNotification(
            metrics: metrics(120, AxisDirection.right),
            context: context,
            scrollDelta: 120,
          ),
          tab: 0,
        ),
        MinimizeScrollResult.none,
      );
      expect(
        tracker.handleNotification(
          ScrollUpdateNotification(
            metrics: metrics(120, AxisDirection.down),
            context: context,
            scrollDelta: 120,
            dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
          ),
          tab: 0,
        ),
        MinimizeScrollResult.moved,
      );
      expect(tracker.offsetOf(0), 120);
      expect(
        tracker.handleNotification(
          ScrollUpdateNotification(
            metrics: metrics(0, AxisDirection.down),
            context: context,
            scrollDelta: -120,
          ),
          tab: 0,
        ),
        MinimizeScrollResult.expand,
      );
    });
  });

  group('nativeMinimizeActive (spec VK-600 §9.2)', () {
    bool active({
      bool owner = true,
      bool engaged = true,
      bool compact = true,
      bool minimizeOnScroll = true,
      bool searchSelected = false,
      bool hidden = false,
      bool routeCurrent = true,
    }) => nativeMinimizeActive(
      owner: owner,
      engaged: engaged,
      compact: compact,
      minimizeOnScroll: minimizeOnScroll,
      searchSelected: searchSelected,
      hidden: hidden,
      routeCurrent: routeCurrent,
    );

    test('only when every fact holds', () {
      expect(active(), isTrue);
      expect(active(owner: false), isFalse);
      expect(active(engaged: false), isFalse);
      expect(active(compact: false), isFalse);
      expect(active(minimizeOnScroll: false), isFalse);
      expect(active(searchSelected: true), isFalse);
      expect(active(hidden: true), isFalse);
      expect(active(routeCurrent: false), isFalse);
    });
  });
}
