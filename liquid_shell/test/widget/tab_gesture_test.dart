import 'package:flutter/gestures.dart'
    show DeviceGestureSettings, kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _screen = Size(402, 874);
const double _y = 874.0 - 21 - 31;
const _home = Offset(115, _y);
const _explore = Offset(201, _y);
const _settings = Offset(287, _y);

const _three = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

/// Owns the selection like an app; [adopt] false ignores every call (a
/// guard that says no). [wrap] puts the screen-sized page holding the bar
/// inside something else (a scroll view, a page view).
class _Harness extends StatefulWidget {
  const _Harness({
    required this.log,
    this.adopt = true,
    this.textScale = 1,
    this.wrap,
    super.key,
  });
  final List<int> log;
  final bool adopt;
  final double textScale;
  final Widget Function(BuildContext context, Widget page)? wrap;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;
  void select(int i) => setState(() => index = i);
  @override
  Widget build(BuildContext context) {
    final page = SizedBox.fromSize(
      size: _screen,
      child: Stack(
        children: [
          Positioned(
            left: TabMetrics.margin,
            right: TabMetrics.margin,
            bottom: 21,
            child: LiquidTabBar(
              destinations: _three,
              selectedIndex: index,
              onDestinationSelected: (i) {
                widget.log.add(i);
                if (widget.adopt) setState(() => index = i);
              },
            ),
          ),
        ],
      ),
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(widget.textScale),
      ),
      child: widget.wrap?.call(context, page) ?? page,
    );
  }
}

Future<GlobalKey<_HarnessState>> _pump(
  WidgetTester tester,
  List<int> log, {
  bool adopt = true,
  double textScale = 1,
  Widget Function(BuildContext context, Widget page)? wrap,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Harness(
          key: key,
          log: log,
          adopt: adopt,
          textScale: textScale,
          wrap: wrap,
        ),
      ),
    ),
  );
  return key;
}

/// The tinted clip's bounds (the lens), in screen coordinates.
Rect _lens(WidgetTester tester) => tester
    .widget<ClipPath>(find.byKey(kTabTintedKey))
    .clipper!
    .getClip(tester.getSize(find.byKey(kTabTintedKey)))
    .getBounds()
    .shift(tester.getTopLeft(find.byKey(kTabTintedKey)));

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// A slow drag from [from] to [to] in 3 pt steps, one 16 ms frame each,
/// then a second of holding still, then the release.
Future<void> _slowDrag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  final step = (to - from).dx.sign * 3;
  for (var x = from.dx; (to.dx - x) * step > 0; x += step) {
    await g.moveTo(Offset(x, from.dy));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.moveTo(to);
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tap commits on up, not on down, without haptics', (
    tester,
  ) async {
    final log = <int>[];
    final haptics = _haptics(tester);
    await _pump(tester, log);
    final g = await tester.startGesture(_settings);
    await tester.pump(const Duration(milliseconds: 50));
    expect(log, isEmpty);
    await g.up();
    await tester.pump();
    expect(log, [2]);
    await tester.pumpAndSettle();
    expect(_lens(tester).center.dx, closeTo(_settings.dx, 0.5));
    expect(haptics, isEmpty);
  });

  testWidgets('a slow drag commits the nearest slot on release, one click '
      'per crossing', (tester) async {
    final log = <int>[];
    final haptics = _haptics(tester);
    await _pump(tester, log);
    final g = await tester.startGesture(_home);
    for (var x = _home.dx; x < _settings.dx; x += 3) {
      await g.moveTo(Offset(x, _y));
      await tester.pump(const Duration(milliseconds: 16));
      expect(log, isEmpty, reason: 'moving never selects');
    }
    await g.moveTo(_settings);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  testWidgets('a cancelled touch commits nothing and returns', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final g = await tester.startGesture(_home);
    await g.moveTo(_settings);
    await tester.pump(const Duration(milliseconds: 300));
    await g.cancel();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_lens(tester).center.dx, closeTo(_home.dx, 0.5));
  });

  testWidgets('a fast flick that eases out before lifting commits the slot '
      'under the finger, as native (VK-503 Task 16)', (tester) async {
    // The events Flutter got from an idb swipe Settings → Home in 0.12 s
    // on the iOS 26.5 simulator (x in screen points, t in µs). The finger
    // slows over its last step (1057 → 524 pt/s) and lifts 10 ms later
    // in place. Native lands on Home; the least-squares tracker read
    // −281 pt/s here, below the 600 pt/s flick, so the lagging lens's slot
    // (Explore) won.
    const samples = [
      (0, 287.0),
      (16847, 266.7),
      (35915, 246.7),
      (55038, 226.3),
      (74120, 206.0),
      (96677, 175.7),
      (117624, 145.3),
      (136871, 125.0),
      (155958, 115.0),
    ];
    final log = <int>[];
    final key = await _pump(tester, log);
    key.currentState!.select(2);
    await tester.pump();
    final g = await tester.createGesture();
    var last = 0;
    for (final (i, (t, x)) in samples.indexed) {
      final at = Duration(microseconds: t);
      if (i == 0) {
        await g.down(Offset(x, _y), timeStamp: at);
      } else {
        await tester.pump(Duration(microseconds: t - last));
        await g.moveTo(Offset(x, _y), timeStamp: at);
      }
      last = t;
    }
    await tester.pump(const Duration(microseconds: 9656));
    await g.up(timeStamp: const Duration(microseconds: 165614));
    await tester.pumpAndSettle();
    expect(log, [0]);
    expect(_lens(tester).center.dx, closeTo(_home.dx, 0.5));
  });

  testWidgets('a rejected commit snaps back after the motion settles', (
    tester,
  ) async {
    final log = <int>[];
    await _pump(tester, log, adopt: false);
    await tester.tapAt(_settings);
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(_lens(tester).center.dx, closeTo(_home.dx, 0.5));
  });

  testWidgets('a programmatic change jumps in one frame', (tester) async {
    final key = await _pump(tester, <int>[]);
    key.currentState!.select(2);
    await tester.pump();
    expect(_lens(tester).center.dx, closeTo(_settings.dx, 0.01));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a semantics tap animates and commits', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    tester
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Explore',
          ),
        )
        .properties
        .onTap!();
    await tester.pump();
    expect(log, [1]);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(_lens(tester).center.dx, closeTo(_explore.dx, 0.5));
  });

  testWidgets('AX text: a long press shows the large content card; a drag '
      'still commits', (tester) async {
    final log = <int>[];
    await _pump(tester, log, textScale: 2);
    final g = await tester.startGesture(_explore);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(log, isEmpty, reason: 'lifting after the card does not select');
    final drag = await tester.startGesture(_home);
    await drag.moveTo(_settings);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(log, [2]);
  });

  testWidgets('the ticker stops at rest', (tester) async {
    await _pump(tester, <int>[]);
    await tester.tapAt(_explore);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a bar removed mid-touch goes quietly', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final g = await tester.startGesture(_home);
    await g.moveTo(_explore);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(const SizedBox());
    await g.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(log, isEmpty);
  });

  testWidgets('a second finger is ignored', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final first = await tester.startGesture(_home);
    final second = await tester.startGesture(_settings, pointer: 7);
    await tester.pump(const Duration(milliseconds: 16));
    await second.up();
    await tester.pump();
    expect(log, isEmpty);
    await first.up();
    await tester.pumpAndSettle();
    expect(log, [0], reason: 'the first finger taps Home (reselect)');
  });

  testWidgets('reduce motion: a tap commits on up and dissolves in place '
      'within 150 ms, without haptics', (tester) async {
    final log = <int>[];
    final haptics = _haptics(tester);
    await _pump(
      tester,
      log,
      wrap: (context, page) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: page,
      ),
    );
    await tester.tapAt(_settings);
    await tester.pump();
    expect(log, [2]);
    expect(
      _lens(tester).center.dx,
      closeTo(_settings.dx, 0.5),
      reason: 'no slide',
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(haptics, isEmpty);
  });

  group('inside other gesture owners', () {
    testWidgets('the bar takes the screen gesture settings: past their '
        'touch slop a horizontal move is the lens, not a horizontal drag '
        'around it', (tester) async {
      final log = <int>[];
      var outer = 0;
      await _pump(
        tester,
        log,
        // A device slop of 4 (Android's is about 8), well under kTouchSlop.
        wrap: (context, page) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            gestureSettings: const DeviceGestureSettings(touchSlop: 4),
          ),
          child: GestureDetector(
            onHorizontalDragStart: (_) => outer++,
            child: SingleChildScrollView(child: page),
          ),
        ),
      );
      final g = await tester.startGesture(_explore);
      await tester.pump();
      for (var dx = 2.0; dx <= 10; dx += 2) {
        await g.moveTo(_explore.translate(dx, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(outer, 0, reason: 'the lens won at the same slop');
      expect(log, [1]);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('a vertical drag that starts on the bar scrolls the list '
          'around it and selects nothing; a tap and a horizontal drag '
          'still select (text scale $scale)', (tester) async {
        final log = <int>[];
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await _pump(
          tester,
          log,
          textScale: scale,
          wrap: (context, page) => ListView(
            controller: scroll,
            children: [page, const SizedBox(height: 2000)],
          ),
        );
        await tester.dragFrom(_explore, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(100), reason: 'the list scrolled');
        expect(log, isEmpty);
        final up = Offset(0, scroll.offset);
        await tester.tapAt(_settings - up);
        await tester.pumpAndSettle();
        expect(log, [2]);
        await _slowDrag(tester, _settings - up, _home - up);
        expect(log, [2, 0]);
        expect(scroll.offset, up.dy, reason: 'the list did not move');
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('in a PageView, a horizontal drag on the bar moves the '
          'lens and commits; the page stays (text scale $scale)', (
        tester,
      ) async {
        final log = <int>[];
        final pages = PageController();
        addTearDown(pages.dispose);
        await _pump(
          tester,
          log,
          textScale: scale,
          wrap: (context, page) => PageView(
            controller: pages,
            children: [page, const SizedBox.expand()],
          ),
        );
        await _slowDrag(tester, _settings, _home);
        expect(log, [0]);
        expect(pages.page, 0);
        await _slowDrag(tester, _home, _settings);
        expect(log, [0, 2]);
        expect(pages.page, 0);
      });
    }

    testWidgets('in a TabBarView, a horizontal drag on the bar moves the '
        'lens and commits; the tab stays', (tester) async {
      final log = <int>[];
      late TabController tabs;
      await _pump(
        tester,
        log,
        wrap: (context, page) => DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              tabs = DefaultTabController.of(context);
              return TabBarView(children: [page, const SizedBox.expand()]);
            },
          ),
        ),
      );
      await _slowDrag(tester, _home, _settings);
      expect(log, [2]);
      expect(tabs.index, 0);
      expect(tabs.offset, 0);
    });
  });
}
