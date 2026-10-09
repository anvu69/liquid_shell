import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// Runs before every test file in this package.
///
/// `flutter test` reports Android with no shader filters, so the device
/// probe would answer "cannot blur" and every glass would be solid. Tests
/// that exercise the probe set the override back to null themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => debugLiquidGlassCanBlurOverride = true);
  tearDown(() {
    debugLiquidGlassCanBlurOverride = null;
    debugResetLiquidGlassSignals();
    debugResetLiquidNative();
  });
  await testMain();
}
