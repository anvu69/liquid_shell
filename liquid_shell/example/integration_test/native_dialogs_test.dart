// Native alerts and action sheets on a real simulator (spec P3a §9.4).
//
// tool/integration_ios_native.sh runs it beside native_shell_test.dart on
// an iPad and an iPhone with iOS 26 (EXPECT_NATIVE=true). Taps go through
// the presenter's debug hooks; real UIKit taps are RunnerUITests (XCUITest).
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/native_alerts.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// The real iOS platform, also recording every chrome config sent.
class _RecordingIOS extends LiquidShellIOS {
  final configs = <LiquidNativeChromeConfig>[];

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) {
    configs.add(config);
    return super.updateNativeChrome(config);
  }
}

/// Waits for the presenter to show a dialog (UIKit animates it in).
Future<NativeDialogDebugSnapshot> _shown(
  WidgetTester tester,
  LiquidShellIOS ios,
) async {
  for (var i = 0; i < 50; i++) {
    final shot = await ios.debugNativeDialog();
    if (shot != null) return shot;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('no native dialog appeared');
}

const _app = MaterialApp(
  debugShowCheckedModeBanner: false,
  home: NativeAlertsCase(),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (LiquidShellPlatform.instance is LiquidShellIOS) {
    LiquidShellPlatform.instance = _RecordingIOS();
  }
  _RecordingIOS ios() => LiquidShellPlatform.instance as _RecordingIOS;

  testWidgets('a native alert answers its value and leaves the chrome alone', (
    tester,
  ) async {
    if (!_expectNative) return;
    final states = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: states.add);
    addTearDown(listener.dispose);
    await tester.pumpWidget(_app);
    await _settle(tester);

    await tester.tap(find.text('Alert'));
    final shot = await _shown(tester, ios());
    expect(shot.actionSheet, isFalse);
    expect(shot.title, 'Discard changes?');
    expect(shot.message, 'Your edits will be lost.');
    expect(shot.labels, ['Keep editing', 'Discard']);
    // Drawn by UIKit, not Flutter; the native chrome is untouched.
    expect(find.text('Your edits will be lost.'), findsNothing);
    expect(ios().configs.last.interactive, isTrue);
    expect(ios().configs.last.hidden, isFalse);
    await binding.takeScreenshot('dialogs_${_runName}_alert');

    await ios().debugRespondToNativeDialog(1);
    await _settle(tester);
    expect(find.text('Result: discard'), findsOneWidget);
    expect(await ios().debugNativeDialog(), isNull);
    expect(states, isNot(contains(AppLifecycleState.inactive)));
  });

  testWidgets('an action sheet points at its button; outside is cancel', (
    tester,
  ) async {
    if (!_expectNative) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    final button = tester.getRect(
      find.ancestor(
        of: find.text('Action sheet'),
        matching: find.byType(ListTile),
      ),
    );

    await tester.tap(find.text('Action sheet'));
    final shot = await _shown(tester, ios());
    expect(shot.actionSheet, isTrue);
    expect(shot.labels, ['Delete photo', 'Share', 'Cancel']);
    final source = shot.sourceRect;
    if (source != null) {
      expect(source.left, closeTo(button.left, 0.5));
      expect(source.top, closeTo(button.top, 0.5));
      expect(source.width, closeTo(button.width, 0.5));
      expect(source.height, closeTo(button.height, 0.5));
    }
    final tablet =
        MediaQuery.sizeOf(
          tester.element(find.byType(NativeAlertsCase)),
        ).shortestSide >=
        600;
    if (tablet) expect(source, isNotNull);
    await binding.takeScreenshot('dialogs_${_runName}_sheet');

    await ios().debugRespondToNativeDialog(-1);
    await _settle(tester);
    expect(find.text('Result: cancel'), findsOneWidget);
  });

  testWidgets('an answer can open a second native alert at once', (
    tester,
  ) async {
    if (!_expectNative) return;
    await tester.pumpWidget(
      const MaterialApp(home: NativeAlertsCase(autorun: 'alert')),
    );
    await _settle(tester);
    expect((await _shown(tester, ios())).title, 'Discard changes?');
    await ios().debugRespondToNativeDialog(0);
    await _settle(tester);
    expect((await _shown(tester, ios())).title, 'Result: keep');
    await ios().debugRespondToNativeDialog(0);
    await _settle(tester);
    expect(await ios().debugNativeDialog(), isNull);
  });

  testWidgets('Flutter liquid draws the glass alert; the chrome turns inert', (
    tester,
  ) async {
    await tester.pumpWidget(_app);
    await _settle(tester);
    await tester.tap(find.text('Draw with Flutter liquid'));
    await _settle(tester);
    await tester.tap(find.text('Alert'));
    await _settle(tester);
    expect(find.text('Your edits will be lost.'), findsOneWidget);
    if (_expectNative) {
      expect(await ios().debugNativeDialog(), isNull);
      final compact =
          LiquidShellScope.of(
            tester.element(find.text('Alert')),
          ).sizeClass ==
          LiquidSizeClass.compact;
      expect(ios().configs.last.interactive, isFalse);
      expect(ios().configs.last.hidden, compact);
    }
    await binding.takeScreenshot('dialogs_${_runName}_alert_flutter');
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    expect(find.text('Result: discard'), findsOneWidget);
  });

  testWidgets("system presents UIKit's alert on every iOS", (tester) async {
    if (!Platform.isIOS) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    final context = tester.element(find.text('Alert'));
    final answer = showLiquidAlert<int>(
      context,
      title: 'System',
      actions: const [LiquidAlertAction(label: 'OK', value: 7)],
      presentation: LiquidDialogPresentation.system,
    );
    expect((await _shown(tester, ios())).title, 'System');
    await ios().debugRespondToNativeDialog(0);
    await _settle(tester);
    expect(await answer, 7);
  });
}
