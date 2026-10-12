// The rest material of the liquid tab bar against native iOS 26.5 pixels
// (spec VK-503 §6.2, §6.4, §17.4 "rest colours"). Research §2 and §5 give
// native over a white and a black page; the example's frame strips
// (Task 15, `tab-strips/idb`, `extra/search_close.png`) give native over the
// example's own pages, where the milky fill matters most.
@Tags(['impeller'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _scale = 3.0;
const _screen = Size(402, 420);

/// The rendered bar over [page], and the pill rect.
Future<(ByteData, Rect)> _bar(
  WidgetTester tester, {
  required Brightness brightness,
  required Color page,
}) async {
  await tester.runAsync(LiquidGlass.precache);
  tester.view
    ..devicePixelRatio = _scale
    ..physicalSize = _screen * _scale;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      // The default (seeded, tinted) scheme: native glass is neutral, so
      // the tint must not take the scheme's hue.
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        backgroundColor: page,
        body: BackdropGroup(
          child: Stack(
            children: [
              Positioned(
                left: TabMetrics.margin,
                right: TabMetrics.margin,
                bottom: 21,
                child: LiquidTabBar(
                  destinations: const [
                    LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
                    LiquidDestination(icon: Icon(Icons.map), label: 'Map'),
                    LiquidDestination(icon: Icon(Icons.settings), label: 'Set'),
                  ],
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
  final data = (await tester.runAsync(() => image!.toByteData()))!;
  image!.dispose();
  return (data, tester.getRect(find.byKey(kTabPillKey)));
}

List<int> _rgb(ByteData data, Offset p) {
  final i =
      ((p.dy * _scale).floor() * (_screen.width * _scale).round() +
          (p.dx * _scale).floor()) *
      4;
  return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
}

double _luma(List<int> rgb) => (rgb[0] + rgb[1] + rgb[2]) / 3;

/// A pill pixel with nothing drawn on it: between slots 1 and 2.
Offset _fillPoint(Rect pill) => Offset(pill.left + 4 + 86 * 2, pill.center.dy);

/// Inside the selection capsule of slot 0, left of the Home icon.
Offset _capsulePoint(Rect pill) => Offset(pill.left + 16, pill.center.dy);

Matcher _near(double native) => inInclusiveRange(native - 4, native + 4);

void main() {
  setUp(() => debugLiquidGlassCanRefractOverride = true);
  tearDown(debugResetLiquidGlassSignals);

  testWidgets('light over white: #FEFEFE pill and #ECECEC capsule, neutral '
      '(research §2, §5)', (tester) async {
    final (data, pill) = await _bar(
      tester,
      brightness: Brightness.light,
      page: const Color(0xFFFFFFFF),
    );
    final fill = _rgb(data, _fillPoint(pill));
    final capsule = _rgb(data, _capsulePoint(pill));
    expect(_luma(fill), _near(254), reason: 'fill $fill');
    expect(_luma(capsule), _near(236), reason: 'capsule $capsule');
    // No scheme hue: native's capsule is #ECECEC, not #E0DDE4.
    expect((capsule[2] - capsule[1]).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('light over the example page: as milky as native (search '
      'strip: page 225/223/240 → field 242/240/254)', (tester) async {
    final (data, pill) = await _bar(
      tester,
      brightness: Brightness.light,
      page: const Color(0xFFE1DFF0),
    );
    final fill = _rgb(data, _fillPoint(pill));
    expect(_luma(fill), _near(245.3), reason: 'fill $fill');
  });

  testWidgets('dark over black: #191919 pill, #3A3A3A capsule, a dim top rim '
      '(research §2, §5: rim 54 → 47 → 39)', (tester) async {
    final (data, pill) = await _bar(
      tester,
      brightness: Brightness.dark,
      page: const Color(0xFF000000),
    );
    final fill = _rgb(data, _fillPoint(pill));
    final capsule = _rgb(data, _capsulePoint(pill));
    expect(_luma(fill), _near(25), reason: 'fill $fill');
    expect(_luma(capsule), _near(58), reason: 'capsule $capsule');
    final rim = [
      for (var y = pill.top; y < pill.top + 2; y += 1 / _scale)
        _luma(_rgb(data, Offset(_fillPoint(pill).dx, y))),
    ];
    expect(
      rim.reduce((a, b) => a > b ? a : b),
      lessThanOrEqualTo(54 + 4),
      reason: 'top rim $rim',
    );
  });

  testWidgets('dark over the example page: native 27 over 25 (idb strip)', (
    tester,
  ) async {
    final (data, pill) = await _bar(
      tester,
      brightness: Brightness.dark,
      page: const Color(0xFF19191C),
    );
    final fill = _rgb(data, _fillPoint(pill));
    expect(_luma(fill), _near(27), reason: 'fill $fill');
  });

  testWidgets('dark: a press and its release do not light the pill (idb '
      'dark strip: native stays 25 beside the lens while Flutter rose to '
      '79 under the white highlight and glow; review item 6)', (
    tester,
  ) async {
    final (_, pill) = await _bar(
      tester,
      brightness: Brightness.dark,
      page: const Color(0xFF000000),
    );
    final home = Offset(pill.left + 4 + 47, pill.center.dy);
    final g = await tester.startGesture(home);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final view = tester.binding.renderViews.single;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
    final data = (await tester.runAsync(() => image!.toByteData()))!;
    image!.dispose();
    final fill = _rgb(data, _fillPoint(pill));
    expect(_luma(fill), _near(25), reason: 'fill $fill');
  });

  testWidgets('dark: the fading lens stays between the engaged lens and the '
      'rest capsule (review item 6: engage 0.9 drew 116, the ends 18 and 55)', (
    tester,
  ) async {
    final lumas = <double>[];
    for (final e in [1.0, 0.9, 0.7, 0.5, 0.3, 0.1, 0.0]) {
      debugTabLensOverride = (f) => f.copyWith(engage: e, refraction: 0);
      addTearDown(() => debugTabLensOverride = null);
      final (data, pill) = await _bar(
        tester,
        brightness: Brightness.dark,
        page: const Color(0xFF000000),
      );
      lumas.add(_luma(_rgb(data, _capsulePoint(pill))));
    }
    final lo = math.min(lumas.first, lumas.last) - 4;
    final hi = math.max(lumas.first, lumas.last) + 4;
    for (final l in lumas) {
      expect(l, inInclusiveRange(lo, hi), reason: 'engage 1 → 0: $lumas');
    }
  });
}
