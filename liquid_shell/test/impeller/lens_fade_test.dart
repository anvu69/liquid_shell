@Tags(['impeller'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _scale = 2.0;
const _screen = Size(402, 300);

/// A saturated page, so any lens pass that is not faded shows at once.
const _page = Color(0xFF0030FF);

/// The rendered screen, RGBA.
Future<ByteData> _capture(WidgetTester tester) async {
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
  final data = (await tester.runAsync(() => image!.toByteData()))!;
  image!.dispose();
  return data;
}

List<int> _rgb(ByteData data, Offset p) {
  final i =
      ((p.dy * _scale).round() * (_screen.width * _scale).round() +
          (p.dx * _scale).round()) *
      4;
  return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
}

/// The bar over [_page] with its lens frozen at [engage], refraction 1 (the
/// worst case: on a tap's release refraction leads engage).
Future<ByteData> _frame(WidgetTester tester, double engage) async {
  debugTabLensOverride = (f) => f.copyWith(engage: engage, refraction: 1);
  addTearDown(() => debugTabLensOverride = null);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: _page,
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
  return _capture(tester);
}

void main() {
  setUp(() => debugLiquidGlassCanRefractOverride = true);
  tearDown(debugResetLiquidGlassSignals);

  testWidgets('at engage 0.01 the page does not show through the lens: it '
      'stays the pill fill (spec §7.2, one fade)', (tester) async {
    await tester.runAsync(LiquidGlass.precache);
    tester.view
      ..devicePixelRatio = _scale
      ..physicalSize = _screen * _scale;
    addTearDown(tester.view.reset);
    final rest = await _frame(tester, 0);
    // Inside the lens, left of the Home icon and above its label.
    final lens = tester
        .widget<ClipPath>(find.byKey(kTabTintedKey))
        .clipper!
        .getClip(tester.getSize(find.byKey(kTabTintedKey)))
        .getBounds()
        .shift(tester.getTopLeft(find.byKey(kTabTintedKey)));
    final home = tester.getCenter(find.byIcon(Icons.home).first);
    final probe = Offset(home.dx - 30, home.dy - 6);
    expect(lens.contains(probe), isTrue);
    final before = _rgb(rest, probe);
    final after = _rgb(await _frame(tester, 0.01), probe);
    for (var c = 0; c < 3; c++) {
      expect(
        (after[c] - before[c]).abs(),
        lessThanOrEqualTo(4),
        reason: 'rest $before, engage 0.01 $after',
      );
    }
  });
}
