import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// Runs before every test file in this package.
///
/// Without `--enable-impeller` there are no shader filters, so glass is
/// frosted unless a test opts into the liquid tier with
/// `debugLiquidGlassCanRefractOverride`; this resets it after each test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDown(() {
    debugLiquidGlassCanRefractOverride = null;
    debugResetLiquidGlassSignals();
    debugResetLiquidNative();
  });
  await testMain();
}
