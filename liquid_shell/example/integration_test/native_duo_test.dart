// Flutter content under the iPhone Duo's vertical bar (spec VK-930 §4).
//
// Run on an iPhone Duo iOS 27.1 simulator, folded outer screen portrait
// (the posture a fresh simulator boots in), with native chrome. Not in the
// default NATIVE_TARGETS.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a tab page clears the vertical bar and starts at the top bar region',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BasicTabsCase(),
        ),
      );
      await _settle(tester);
      final padding = MediaQuery.paddingOf(
        tester.element(find.byType(DemoPage).first),
      );
      debugPrint('liquid_shell duo: padding $padding');
      await binding.takeScreenshot('duo_${_runName}_tabs');
      expect(padding.right, closeTo(84, 0.5), reason: 'the vertical bar');
      expect(padding.top, greaterThanOrEqualTo(24));
    },
  );
}
