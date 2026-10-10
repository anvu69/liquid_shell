import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import 'support/golden_harness.dart';

/// Runs before every test file of the example.
///
/// Without `--enable-impeller` there are no shader filters, so the
/// `golden` images show frosted glass; `liquid_golden` runs with
/// `--enable-impeller` and shows the liquid tier.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDown(() {
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
