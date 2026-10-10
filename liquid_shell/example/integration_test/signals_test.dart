// Signal channel round-trip on a real simulator or emulator (spec §10.5).
//
// tool/integration_ios.sh and tool/integration_android.sh pass the expected
// value of each signal with --dart-define. An empty value means "do not
// check this field" (for example, battery saver also disables window blurs).
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectReduceTransparency = String.fromEnvironment(
  'EXPECT_REDUCE_TRANSPARENCY',
);
const _expectPowerSave = String.fromEnvironment('EXPECT_POWER_SAVE');
const _expectBlurDisabled = String.fromEnvironment('EXPECT_BLUR_DISABLED');
const _expectLowEnd = String.fromEnvironment('EXPECT_LOW_END');
const _expectGlesOnly = String.fromEnvironment('EXPECT_GLES_ONLY');

/// Names the screenshot of this run, for example `android_powerSave`.
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

/// The tier the run's signals ask for (spec 2026-10-10 §6.3), mirroring
/// what the script switched on. An empty expectation counts as off.
LiquidGlassTier _expectedTier() {
  bool on(String value) => value == 'true';
  final reduce = on(_expectReduceTransparency);
  final powerSave = on(_expectPowerSave);
  final blurDisabled = on(_expectBlurDisabled);
  if (reduce || (blurDisabled && !powerSave)) return LiquidGlassTier.solid;
  if (powerSave ||
      on(_expectLowEnd) ||
      on(_expectGlesOnly) ||
      !ui.ImageFilter.isShaderFilterSupported) {
    return LiquidGlassTier.frosted;
  }
  return LiquidGlassTier.liquid;
}

/// Whether the internal liquid backdrop is on screen. It is not exported,
/// so it is matched by type name.
bool _liquidShown() => find
    .byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidBackdrop')
    .evaluate()
    .isNotEmpty;

void _check(String expected, {required bool actual, required String name}) {
  if (expected.isEmpty) return;
  expect(actual, expected == 'true', reason: name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform package registered the event channel', (
    tester,
  ) async {
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });

  testWidgets('watchSignals emits a well-formed value within 5 s', (
    tester,
  ) async {
    final signals = await LiquidShellPlatform.instance
        .watchSignals()
        .first
        .timeout(const Duration(seconds: 5));
    debugPrint('liquid_shell integration: $signals');

    _check(
      _expectReduceTransparency,
      actual: signals.reduceTransparency,
      name: 'reduceTransparency',
    );
    _check(_expectPowerSave, actual: signals.powerSave, name: 'powerSave');
    _check(
      _expectBlurDisabled,
      actual: signals.blurDisabled,
      name: 'blurDisabled',
    );
    _check(_expectLowEnd, actual: signals.lowEnd, name: 'lowEnd');
    _check(_expectGlesOnly, actual: signals.glesOnly, name: 'glesOnly');
  });

  testWidgets('the shell draws the tier the signals ask for', (tester) async {
    await LiquidGlass.precache();
    // nativeChrome off: on an iPad 26 the example opts into native chrome,
    // which has no Flutter glass to look at.
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidShell(
          nativeChrome: LiquidNativeChrome.off,
          destinations: kDemoDestinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const DemoPage(title: 'Home'),
        ),
      ),
    );
    // The first channel event arrives asynchronously, then the tier fades.
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    switch (_expectedTier()) {
      case LiquidGlassTier.solid:
        expect(find.byType(BackdropFilter), findsNothing);
        expect(_liquidShown(), isFalse);
      case LiquidGlassTier.frosted:
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(_liquidShown(), isFalse);
      case LiquidGlassTier.liquid:
        expect(_liquidShown(), isTrue);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('shell_$_runName');
  });
}
