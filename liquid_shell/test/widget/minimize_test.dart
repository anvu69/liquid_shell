import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _screen = Size(402, 874);
const double _top = 874.0 - 21 - 62;
const _three = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

Future<StateSetter> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  VoidCallback? onTrailing,
  List<int>? log,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  var minimized = false;
  late StateSetter set;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: _screen, disableAnimations: reduceMotion),
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              set = (fn) => setState(() {
                fn();
                minimized = !minimized;
              });
              return Stack(
                children: [
                  Positioned(
                    left: TabMetrics.margin,
                    right: TabMetrics.margin,
                    bottom: 21,
                    child: LiquidTabBar(
                      destinations: _three,
                      selectedIndex: 0,
                      onDestinationSelected: (i) => log?.add(i),
                      minimized: minimized,
                      onExpand: () => setState(() => minimized = false),
                      trailing: LiquidTabAction(
                        icon: const Icon(Icons.edit),
                        semanticLabel: 'Compose',
                        onPressed: onTrailing ?? () {},
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  return set;
}

Rect _pill(WidgetTester tester) => tester.getRect(find.byKey(kTabPillKey));

/// The bar alone, as the shell builds it for the search row (Task 10).
Future<StateSetter> _pumpBar(
  WidgetTester tester, {
  TabDragTarget? target,
  bool collapseDelay = true,
  List<int>? log,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  var minimized = false;
  late StateSetter set;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            set = (fn) => setState(() {
              fn();
              minimized = !minimized;
            });
            return Stack(
              children: [
                Positioned(
                  left: TabMetrics.margin,
                  right: TabMetrics.margin,
                  bottom: 21,
                  child: GlassTabBar(
                    destinations: _three,
                    selectedIndex: 0,
                    onSelect: (i) => log?.add(i),
                    minimized: minimized,
                    reserveTrailing: true,
                    externalTarget: target,
                    collapseDelay: collapseDelay,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  return set;
}

/// The reserved trailing circle, bar-local (screen centre 350).
const _reserved = Rect.fromLTWH(329 - 31, 0, 62, 62);

void main() {
  testWidgets('collapse starts after 240 ms and ends at the 48 circle', (
    tester,
  ) async {
    final toggle = await _pump(tester);
    toggle(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_pill(tester), const Rect.fromLTWH(21, _top, 274, 62));
    await tester.pumpAndSettle();
    expect(_pill(tester), const Rect.fromLTWH(28, _top + 7, 48, 48));
    // The trailing circle shrank about its own centre.
    final trailing = tester.getRect(find.byKey(kTabTrailingKey));
    expect(trailing.size, const Size(48, 48));
    expect(trailing.center, const Offset(350, _top + 31));
  });

  testWidgets('a tap on the circle expands', (tester) async {
    final toggle = await _pump(tester);
    toggle(() {});
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(52, _top + 31));
    await tester.pumpAndSettle();
    expect(_pill(tester), const Rect.fromLTWH(21, _top, 274, 62));
  });

  testWidgets('reduce motion: instant, no delay', (tester) async {
    final toggle = await _pump(tester, reduceMotion: true);
    toggle(() {});
    await tester.pump();
    expect(_pill(tester), const Rect.fromLTWH(28, _top + 7, 48, 48));
  });

  testWidgets('drag onto the trailing circle: hover, release fires it, no '
      'commit', (tester) async {
    var fired = 0;
    final log = <int>[];
    await _pump(tester, onTrailing: () => fired++, log: log);
    final g = await tester.startGesture(const Offset(115, _top + 31));
    await g.moveTo(const Offset(350, _top + 31));
    await tester.pump(const Duration(milliseconds: 100));
    // One overlay on the circle: the drag hover lights it too.
    final highlight = tester.widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kTabTrailingKey),
        matching: find.byType(TabHoverHighlight),
      ),
    );
    expect(highlight.hovered.value, isTrue);
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 1);
    expect(log, isEmpty);
  });

  testWidgets('a minimize mid-drag drops the hover and the drag', (
    tester,
  ) async {
    var fired = 0;
    final log = <int>[];
    final toggle = await _pump(tester, onTrailing: () => fired++, log: log);
    final g = await tester.startGesture(const Offset(115, _top + 31));
    await g.moveTo(const Offset(350, _top + 31));
    await tester.pump();
    TabHoverHighlight highlight() => tester.widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kTabTrailingKey),
        matching: find.byType(TabHoverHighlight),
      ),
    );
    expect(highlight().hovered.value, isTrue);
    toggle(() {});
    await tester.pumpAndSettle();
    expect(highlight().hovered.value, isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 0);
    expect(log, isEmpty);
  });

  group('shell-owned target (search ⌕, spec §11)', () {
    testWidgets('reserveTrailing lays the pill out as beside a circle', (
      tester,
    ) async {
      await _pumpBar(tester);
      expect(_pill(tester), const Rect.fromLTWH(21, _top, 274, 62));
      expect(find.byKey(kTabTrailingKey), findsNothing);
    });

    testWidgets('a release over the external target fires it, no commit; '
        'leaving it clears the hover and commits', (tester) async {
      var fired = 0;
      final log = <int>[];
      final target = TabDragTarget(
        rect: () => _reserved,
        onRelease: () => fired++,
      );
      addTearDown(target.dispose);
      await _pumpBar(tester, target: target, log: log);
      var g = await tester.startGesture(const Offset(115, _top + 31));
      await g.moveTo(const Offset(350, _top + 31));
      await tester.pump();
      expect(target.hovered.value, isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
      expect(log, isEmpty);
      expect(target.hovered.value, isFalse);

      g = await tester.startGesture(const Offset(115, _top + 31));
      await g.moveTo(const Offset(350, _top + 31));
      await g.moveTo(const Offset(201, _top + 31));
      // A drag commits where the lens is: let it catch up, frame by frame.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(target.hovered.value, isFalse);
      await g.up();
      await tester.pumpAndSettle();
      expect(fired, 1);
      expect(log, [1]);
    });

    testWidgets('collapseDelay false: the collapse starts at once', (
      tester,
    ) async {
      final toggle = await _pumpBar(tester, collapseDelay: false);
      toggle(() {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_pill(tester).height, lessThan(62));
      await tester.pumpAndSettle();
      expect(_pill(tester), const Rect.fromLTWH(28, _top + 7, 48, 48));
    });
  });
}
