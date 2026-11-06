// liquid_shell/test/unit/native_minimize_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/native/native_minimize.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

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

    test('start re-arms the expand: the next scroll may expand again', () {
      t.start(tab: 0);
      drag(400, 400);
      expect(fling(0, -400), MinimizeScrollResult.expand);
      t.start(tab: 0);
      drag(300, 300);
      expect(fling(0, -300), MinimizeScrollResult.expand);
    });

    test("at rest the offset drops to the view's own: drift is dropped", () {
      t.start(tab: 0);
      drag(500, 500);
      // Pixels corrected without a notification (content shrank above),
      // or a new view in place of the old one.
      expect(
        t.end(tab: 0, pixels: 320, minScrollExtent: 0),
        MinimizeScrollResult.moved,
      );
      expect(t.offsetOf(0), 320);
      expect(
        t.end(tab: 0, pixels: 320, minScrollExtent: 0),
        MinimizeScrollResult.none,
      );
      t.end(tab: 0, pixels: 0.25, minScrollExtent: 0);
      expect(t.offsetOf(0), kMinimizeAwayFromTop);
      t.end(tab: 0, pixels: -100, minScrollExtent: -100);
      expect(t.offsetOf(0), 0);
    });

    test('at rest the offset never rises: UIKit may still be decelerating', () {
      // Two lists in one tab (a TabBarView): A rests at 50, B at 3000. A
      // flick up B's middle floors the offset at the top's edge; B rests
      // at 2700. Raised there, inside UIKit's deceleration after the flick
      // (spike C11), the jump would read as a scroll down and minimize.
      t.start(tab: 0);
      drag(50, 50); // list A
      t
        ..end(tab: 0, pixels: 50, minScrollExtent: 0)
        ..start(tab: 0);
      fling(2700, -300); // list B, from 3000
      expect(t.offsetOf(0), kMinimizeAwayFromTop);
      expect(
        t.end(tab: 0, pixels: 2700, minScrollExtent: 0),
        MinimizeScrollResult.none,
      );
      expect(t.offsetOf(0), kMinimizeAwayFromTop);
      // At its top the view's own still wins, from an overscroll too.
      t.start(tab: 1);
      drag(-30, -30, tab: 1);
      expect(
        t.end(tab: 1, pixels: 0, minScrollExtent: 0),
        MinimizeScrollResult.moved,
      );
      expect(t.offsetOf(1), 0);
      // The offset at the top, the view below its own at rest (pixels
      // corrected): just off the top, never the view's own.
      expect(
        t.end(tab: 1, pixels: 2700, minScrollExtent: 0),
        MinimizeScrollResult.moved,
      );
      expect(t.offsetOf(1), kMinimizeAwayFromTop);
    });

    test('a nested view moves the offset but is never the top', () {
      t.start(tab: 0);
      drag(500, 500); // the page
      t.start(tab: 0);
      expect(
        t.update(
          tab: 0,
          pixels: 0,
          minScrollExtent: 0,
          delta: -80,
          dragging: false,
          nested: true,
        ),
        MinimizeScrollResult.moved,
      );
      expect(t.offsetOf(0), 420);
      t.update(
        tab: 0,
        pixels: -20,
        minScrollExtent: 0,
        delta: -600,
        dragging: false,
        nested: true,
      );
      expect(t.offsetOf(0), kMinimizeAwayFromTop);
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

    /// Feeds a tracker every notification under [child], on tab 0.
    Future<List<MinimizeScrollResult>> listen(
      WidgetTester tester,
      MinimizeScrollTracker tracker,
      Widget child,
    ) async {
      final results = <MinimizeScrollResult>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              results.add(tracker.handleNotification(n, tab: 0));
              return false;
            },
            child: child,
          ),
        ),
      );
      return results;
    }

    List<Widget> rows(int count) => [
      for (var i = 0; i < count; i++) SizedBox(height: 40, child: Text('$i')),
    ];

    testWidgets('the adapter: a list nested in a vertical one never reaches '
        'the top nor expands; the outer one does', (tester) async {
      final tracker = MinimizeScrollTracker();
      final results = await listen(
        tester,
        tracker,
        ListView(
          key: const ValueKey('outer'),
          children: [
            ...rows(20),
            SizedBox(
              height: 200,
              child: ListView(
                key: const ValueKey('inner'),
                children: rows(30),
              ),
            ),
            ...rows(40),
          ],
        ),
      );
      // The inner list shows at 300..500 once the page is at 500.
      await tester.dragFrom(const Offset(400, 100), const Offset(0, -500));
      await tester.pumpAndSettle();
      final inner = find.byKey(const ValueKey('inner'));
      await tester.drag(inner, const Offset(0, -600));
      await tester.pumpAndSettle();
      results.clear();
      // A short, fast fling: the deceleration, not the drag, reaches the
      // inner list's top.
      await tester.fling(inner, const Offset(0, 100), 5000);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: inner, matching: find.byType(Scrollable)),
            )
            .position
            .pixels,
        0,
      );
      expect(results, isNot(contains(MinimizeScrollResult.expand)));
      expect(tracker.offsetOf(0), greaterThanOrEqualTo(kMinimizeAwayFromTop));
      await tester.flingFrom(
        const Offset(400, 100),
        const Offset(0, 100),
        5000,
      );
      await tester.pumpAndSettle();
      expect(results, contains(MinimizeScrollResult.expand));
      expect(tracker.offsetOf(0), 0);
    });

    testWidgets('the adapter: a list in a horizontal PageView is the page', (
      tester,
    ) async {
      final tracker = MinimizeScrollTracker();
      final results = await listen(
        tester,
        tracker,
        PageView(
          children: [ListView(key: const ValueKey('list'), children: rows(60))],
        ),
      );
      final list = find.byKey(const ValueKey('list'));
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      // The deceleration, not the drag, reaches the top.
      await tester.fling(list, const Offset(0, 100), 5000);
      await tester.pumpAndSettle();
      expect(results, contains(MinimizeScrollResult.expand));
      expect(tracker.offsetOf(0), 0);
    });
  });

  group('nativeTabsMayRebuild (spec VK-600 §8.6)', () {
    const home = LiquidNativeTab(title: 'Home', sfSymbol: 'house');
    const inbox = LiquidNativeTab(title: 'Inbox', sfSymbol: 'tray');
    const action = LiquidNativeAction(title: 'Add', sfSymbol: 'plus');
    const base = LiquidNativeChromeConfig(engaged: true, tabs: [home, inbox]);

    test('the first config, other tabs or another trailing action', () {
      expect(nativeTabsMayRebuild(null, base), isTrue);
      expect(
        nativeTabsMayRebuild(
          base,
          const LiquidNativeChromeConfig(engaged: true, tabs: [home]),
        ),
        isTrue,
      );
      expect(
        nativeTabsMayRebuild(
          base,
          const LiquidNativeChromeConfig(
            engaged: true,
            tabs: [home, inbox],
            trailing: action,
          ),
        ),
        isTrue,
      );
      expect(
        nativeTabsMayRebuild(
          base,
          const LiquidNativeChromeConfig(
            engaged: true,
            tabs: [
              home,
              LiquidNativeTab(title: 'Inbox', sfSymbol: 'tray.2'),
            ],
          ),
        ),
        isTrue,
        reason: 'any change of a tab counts',
      );
    });

    test('a selection, visibility or minimize change does not', () {
      expect(
        nativeTabsMayRebuild(
          base,
          // A new, equal list: the shell builds one for every config.
          LiquidNativeChromeConfig(
            engaged: true,
            tabs: List.of(base.tabs),
            selectedIndex: 1,
            hidden: true,
            interactive: false,
            minimizeOnScroll: true,
          ),
        ),
        isFalse,
      );
    });

    test("a change of a tab's pages only does (a push or a pop)", () {
      // A push or a pop builds or drops a native host whose proxy starts
      // at 0: the offset must follow that config (VK-442).
      const pushed = LiquidNativeChromeConfig(
        engaged: true,
        tabs: [
          home,
          LiquidNativeTab(
            title: 'Inbox',
            sfSymbol: 'tray',
            pages: [LiquidNativePage(title: 'Inbox', largeTitle: false)],
          ),
        ],
      );
      expect(nativeTabsMayRebuild(base, pushed), isTrue, reason: 'a push');
      expect(nativeTabsMayRebuild(pushed, base), isTrue, reason: 'a pop');
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
