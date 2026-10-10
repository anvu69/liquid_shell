import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frame_guard.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';

const _ms = Duration(milliseconds: 1);
const _budget = Duration(microseconds: 16667);

List<Duration> _window(Duration each) => List.filled(kLiquidWindowFrames, each);

void main() {
  tearDown(() => debugLiquidFrameGuardEnabled = false);

  group('p90', () {
    test('nearest rank', () {
      expect(p90(const []), Duration.zero);
      expect(p90([for (var i = 1; i <= 10; i++) _ms * i]), _ms * 9);
      expect(p90([_ms * 5]), _ms * 5);
      expect(p90([for (var i = 100; i >= 1; i--) _ms * i]), _ms * 90);
    });
  });

  group('liquidFramesTooSlow', () {
    final slow = _budget * 1.3;
    final fast = _budget * 1.2;

    test('needs three slow windows in a row', () {
      expect(liquidFramesTooSlow([slow, slow], _budget), isFalse);
      expect(liquidFramesTooSlow([slow, slow, slow], _budget), isTrue);
      expect(liquidFramesTooSlow([slow, fast, slow], _budget), isFalse);
      expect(liquidFramesTooSlow([fast, slow, slow, slow], _budget), isTrue);
    });

    test('exactly 1.25 × budget is not slow', () {
      final edge = _budget * 1.25;
      expect(liquidFramesTooSlow([edge, edge, edge], _budget), isFalse);
    });

    test('a 120 Hz budget is half as long', () {
      const budget120 = Duration(microseconds: 8333);
      final p = _ms * 12;
      expect(liquidFramesTooSlow([p, p, p], budget120), isTrue);
      expect(liquidFramesTooSlow([p, p, p], _budget), isFalse);
    });
  });

  group('LiquidFrameGuard', () {
    final guard = LiquidFrameGuard.instance;
    tearDown(guard.debugReset);

    test('turns slowFrames on after three slow windows and stays on', () {
      final slow = guard.budget * 2;
      guard.addRasterTimes([..._window(slow), ..._window(slow)]);
      expect(guard.value, isFalse);
      guard.addRasterTimes(_window(slow));
      expect(guard.value, isTrue);
      guard.addRasterTimes(_window(Duration.zero));
      expect(guard.value, isTrue);
    });

    test('a fast window resets the run', () {
      final slow = guard.budget * 2;
      guard.addRasterTimes([
        ..._window(slow),
        ..._window(slow),
        ..._window(Duration.zero),
        ..._window(slow),
        ..._window(slow),
      ]);
      expect(guard.value, isFalse);
    });

    test('subscribes only while a surface is held and enabled', () {
      guard.acquire();
      expect(guard.debugSubscribed, isFalse, reason: 'off in debug');
      guard.release();

      debugLiquidFrameGuardEnabled = true;
      guard.acquire();
      expect(guard.debugSubscribed, isTrue);
      guard.release();
      expect(guard.debugSubscribed, isFalse);
    });

    testWidgets('a liquid backdrop holds the guard while attached', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = true;
      debugLiquidFilterFactory = (shader, sigma) =>
          ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      addTearDown(() => debugLiquidFilterFactory = null);
      await tester.runAsync(LiquidGlass.precache);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(guard.debugUsers, 1);
      await tester.pumpWidget(const SizedBox());
      expect(guard.debugUsers, 0);
    });

    testWidgets('slowFrames demotes LiquidGlass to frosted', (tester) async {
      debugLiquidGlassCanRefractOverride = true;
      debugLiquidFilterFactory = (shader, sigma) =>
          ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      addTearDown(() => debugLiquidFilterFactory = null);
      await tester.runAsync(LiquidGlass.precache);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackdrop), findsOneWidget);

      final slow = guard.budget * 2;
      guard.addRasterTimes([
        ..._window(slow),
        ..._window(slow),
        ..._window(slow),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackdrop), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
