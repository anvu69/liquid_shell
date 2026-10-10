import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import 'support/golden_harness.dart';

/// Runs before every test file of the example.
///
/// `flutter test` reports Android without shader filters, so without the
/// override every golden would show the solid tier. `case_tier_solid` gets
/// solid through `forcedTier`, not through this flag.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => debugLiquidGlassCanBlurOverride = true);
  tearDown(() {
    debugLiquidGlassCanBlurOverride = null;
    debugResetLiquidGlassSignals();
    // Tests that install a native platform leave the native link started.
    debugResetLiquidNative();
  });
  await loadGoldenFonts();
  final local = goldenFileComparator;
  if (local is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      local.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

/// Passes when at most [tolerance] of the pixels differ (Q11: 0.5%).
class TolerantGoldenComparator extends LocalFileComparator {
  /// Creates the comparator for the test file at [testFile].
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  /// Largest accepted ratio of differing pixels, between 0 and 1.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
