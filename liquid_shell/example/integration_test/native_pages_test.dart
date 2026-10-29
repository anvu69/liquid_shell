// Native page bars on every tab on real simulators (spec P3b-2 §8.2).
//
// tool/integration_ios_native.sh runs it with EXPECT_NATIVE=true on iPhone
// and iPad, iOS 26.5 and 27.0. It drives the example's pages case with
// Flutter taps and the plugin's debug hooks, and reads UIKit's navigation
// controllers back (`debugSnapshot().tabs`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/pages.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

/// Lets the platform answer and UIKit lay out: channel round trips and
/// layout passes take real time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

LiquidShellIOS get _ios => LiquidShellPlatform.instance as LiquidShellIOS;

/// UIKit's navigation controller of tab [index].
Future<NativeTabSnapshot> _tab(int index) async =>
    (await _ios.debugSnapshot()).tabs.singleWhere((t) => t.tab == index);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String state) =>
      binding.takeScreenshot('pages_${_runName}_$state');

  void expectResumed() => expect(
    WidgetsBinding.instance.lifecycleState,
    AppLifecycleState.resumed,
    reason: 'the Flutter view never leaves the window',
  );

  testWidgets('every tab has a native bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(debugShowCheckedModeBanner: false, home: PagesCase()),
    );
    await _settle(tester);
    final scope = LiquidShellScope.of(tester.element(find.text('Detail 1')));
    expect(scope.nativePageBar, _expectNative);
    await shot('home');
    if (!_expectNative) return;
    final compact = scope.sizeClass == LiquidSizeClass.compact;

    // Home: the default title, on the bar row at compact width only.
    var home = await _tab(0);
    expect(home.pageTitles, ['Home']);
    expect(home.barHidden, !compact);
    expect(home.titleModes, [if (compact) 'inline' else 'never']);

    // A pushed page: the bar, inline, with the back circle.
    await tester.tap(find.text('Detail 1'));
    await _settle(tester);
    home = await _tab(0);
    expect(home.pageTitles, ['Home', 'Detail 1']);
    expect(home.barHidden, isFalse);
    expect(home.titleModes.last, 'never');
    expect(
      find.byType(LiquidBackButton),
      findsNothing,
      reason: 'UIKit draws it',
    );
    await shot('home_detail');
    await _ios.debugTap(NativeTapTarget.back); // Home
    await _settle(tester);
    expect((await _tab(0)).pageTitles, ['Home']);
    expect(find.text('Detail 1 item 1'), findsNothing);

    // Library: the large title on its own row.
    await _ios.debugTap(NativeTapTarget.destination, 1);
    await _settle(tester);
    final library = await _tab(1);
    expect(library.pageTitles, ['Library']);
    expect(library.barHidden, isFalse);
    expect(library.titleModes, ['always']);
    await shot('library');

    // Settings: no LiquidPage at its root, no bar; About above it gets a
    // stand-in root titled with the tab's label.
    await _ios.debugTap(NativeTapTarget.destination, 2);
    await _settle(tester);
    expect((await _tab(2)).barHidden, isTrue);
    await tester.tap(find.text('About'));
    await _settle(tester);
    final settings = await _tab(2);
    expect(settings.pageTitles, ['Settings', 'About']);
    expect(settings.barHidden, isFalse);
    expect(settings.titleModes, ['never', 'never']);
    await shot('settings_about');
    await _ios.debugTap(NativeTapTarget.back, 2);
    await _settle(tester);
    expect((await _tab(2)).barHidden, isTrue);
    expect(find.text('About item 1'), findsNothing);

    // LiquidHideChrome over a LiquidPage: the tab bar hides, the page
    // keeps its bar.
    await _ios.debugTap(NativeTapTarget.destination); // Home
    await _settle(tester);
    await tester.tap(find.text('Photo'));
    await _settle(tester);
    final photo = await _tab(0);
    expect(photo.pageTitles, ['Home', 'Photo']);
    expect(photo.barHidden, isFalse, reason: 'the page keeps its bar');
    final photoScope = LiquidShellScope.of(
      tester.element(find.text('Photo item 1')),
    );
    expect(photoScope.chromeKind, LiquidChromeKind.hidden);
    await shot('photo');
    await _ios.debugTap(NativeTapTarget.back); // Home
    await _settle(tester);
    expect((await _tab(0)).pageTitles, ['Home']);
    expectResumed();
  });
}
