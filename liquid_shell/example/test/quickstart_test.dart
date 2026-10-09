import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/quickstart.dart' as quickstart;

/// The README quickstart is a whole app: it runs as written.
void main() {
  testWidgets('the quickstart app runs and switches tabs', (tester) async {
    quickstart.main();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LiquidShell), findsOneWidget);
    expect(find.text('Tab 1'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Tab 2'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
