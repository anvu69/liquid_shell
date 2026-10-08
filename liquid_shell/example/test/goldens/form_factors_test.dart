@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';

import '../support/golden_harness.dart';

/// The basic shell on every reference device (spec §10.3).
void main() {
  for (final device in [iphone, ipadPortrait, ipadLandscape, android]) {
    final name = 'ff_${device.name}';
    testWidgets(name, (tester) async {
      await pumpGolden(tester, const BasicTabsCase(), device: device);
      await expectDocImage(tester, name);
    });
  }

  testWidgets('ff_ipad_portrait_sidebar_open', (tester) async {
    await pumpGolden(tester, const BasicTabsCase(), device: ipadPortrait);
    await tester.tap(find.byTooltip('Show sidebar'));
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'ff_ipad_portrait_sidebar_open');
  });
}
