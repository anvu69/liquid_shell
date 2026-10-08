// Signal channel round-trip on a real simulator or emulator (spec §10.5).
//
// tool/integration_ios.sh and tool/integration_android.sh pass the expected
// value of each signal with --dart-define. An empty value means "do not
// check this field" (for example, battery saver also disables window blurs).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectReduceTransparency = String.fromEnvironment(
  'EXPECT_REDUCE_TRANSPARENCY',
);
const _expectPowerSave = String.fromEnvironment('EXPECT_POWER_SAVE');
const _expectBlurDisabled = String.fromEnvironment('EXPECT_BLUR_DISABLED');

void _check(String expected, {required bool actual, required String name}) {
  if (expected.isEmpty) return;
  expect(actual, expected == 'true', reason: name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
  });
}
