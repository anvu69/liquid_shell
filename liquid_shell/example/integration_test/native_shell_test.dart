// The native iOS 26 shell on a real simulator (spec P2 §9.4).
//
// tool/integration_ios_native.sh runs it on an iPad and on an iPhone with
// iOS 26 or later (EXPECT_NATIVE=true): every iOS 26 iPhone and iPad gets
// the native bar (owner D1). EXPECT_NATIVE=false is for a device that must
// keep the Flutter chrome. The example opts in with LiquidShellNativeChrome
// in Info.plist.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/badges.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/native_chrome.dart';
import 'package:liquid_shell_example/support/demo_page.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

/// Lets the platform answer and UIKit lay out: channel round trips and
/// layout passes take real time, not fake frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

LiquidShellScopeData _scope(WidgetTester tester) =>
    LiquidShellScope.of(tester.element(find.byType(DemoPage).first));

/// The case without the debug banner: its screenshots are doc images.
const _app = MaterialApp(
  debugShowCheckedModeBanner: false,
  home: NativeChromeCase(),
);

String _title(WidgetTester tester) =>
    tester.widget<DemoPage>(find.byType(DemoPage).first).title;

/// The real iOS platform, also recording every config the shell sends.
/// Installed before the first test: one instance receives every native
/// call (the Pigeon receiver belongs to the instance that started it).
class _RecordingIOS extends LiquidShellIOS {
  final configs = <LiquidNativeChromeConfig>[];

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) {
    configs.add(config);
    return super.updateNativeChrome(config);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (LiquidShellPlatform.instance is LiquidShellIOS) {
    LiquidShellPlatform.instance = _RecordingIOS();
  }

  testWidgets('install state matches the device', (tester) async {
    final platform = LiquidShellPlatform.instance;
    expect(platform, isA<LiquidShellIOS>());
    final state = await platform.attachNativeChrome();
    debugPrint('liquid_shell native: $state');
    expect(state.installed, _expectNative);
  });

  testWidgets('the native case draws native or Flutter chrome, not both', (
    tester,
  ) async {
    await tester.pumpWidget(_app);
    await _settle(tester);
    final scope = _scope(tester);
    debugPrint(
      'liquid_shell native: kind ${scope.chromeKind.name} '
      'insets ${scope.chromeInsets} controls ${scope.windowControls}',
    );
    expect(scope.nativeChrome, _expectNative);
    expect(find.byType(LiquidTabBar).evaluate().isEmpty, _expectNative);
    expect(find.byType(LiquidSidebar).evaluate().isEmpty, isTrue);
    // Moving the Flutter view never paused the engine (approach C). The
    // integration binding may report no state at all (null): also fine.
    expect(
      WidgetsBinding.instance.lifecycleState,
      isNot(
        anyOf(
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.detached,
        ),
      ),
    );
    // Full screen: no window controls (a rounded corner is not a cluster).
    expect(scope.windowControls, LiquidWindowControls.zero);
    await binding.takeScreenshot('native_${_runName}_home');
  });

  // Owner E1 (spec P2 §15): every shell case of the example has its
  // symbols, so the plain cases run native too, not only this one.
  for (final (name, page) in [
    ('basic', const BasicTabsCase()),
    ('badges', const BadgesCase()),
  ]) {
    testWidgets('the $name case draws native chrome', (tester) async {
      await tester.pumpWidget(
        MaterialApp(debugShowCheckedModeBanner: false, home: page),
      );
      await _settle(tester);
      final scope = _scope(tester);
      debugPrint('liquid_shell native: $name ${scope.chromeKind.name}');
      expect(scope.nativeChrome, _expectNative);
      expect(find.byType(LiquidTabBar).evaluate().isEmpty, _expectNative);
      await binding.takeScreenshot('native_${_runName}_case_$name');
    });
  }

  testWidgets('native taps select; the trailing action calls the app', (
    tester,
  ) async {
    if (!_expectNative) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    final platform = LiquidShellPlatform.instance as LiquidShellIOS;

    // The native bar is in the Flutter view's safe area: the top bar row
    // at regular width, UIKit's compact bar at the bottom (owner D1). A
    // landscape iPad starts with the sidebar tiled: no bar row then.
    final scope = _scope(tester);
    final padding = MediaQuery.paddingOf(
      tester.element(find.byType(DemoPage).first),
    );
    debugPrint('liquid_shell native: ${scope.chromeKind.name} $padding');
    switch (scope.chromeKind) {
      case LiquidChromeKind.bottomBar:
        expect(scope.chromeInsets, EdgeInsets.only(bottom: padding.bottom));
        expect(padding.bottom, greaterThan(40));
      case LiquidChromeKind.sidebarTiled:
        expect(scope.chromeInsets, EdgeInsets.zero);
      case LiquidChromeKind.topBar ||
          LiquidChromeKind.sidebarOverlay ||
          LiquidChromeKind.hidden:
        expect(scope.chromeInsets.top, padding.top);
        expect(padding.top, greaterThan(40));
    }

    await platform.debugTap(NativeTapTarget.destination, 1);
    await _settle(tester);
    expect(find.text('Inbox'), findsWidgets);

    await platform.debugTap(NativeTapTarget.trailing);
    await _settle(tester);
    expect(find.text('Drafts: 1'), findsOneWidget);
  });

  // The guard round trip on the real native chrome (final review I2): the
  // tap only proposes, the app's dialog answers, and the native selection
  // follows the answer. Started from the portrait overlay sidebar when the
  // simulator is portrait, where the dialog must not open under it (I1).
  testWidgets('a dirty page: a native tap asks first; keep stays, discard '
      'leaves', (tester) async {
    if (!_expectNative) return;
    final recorder = LiquidShellPlatform.instance as _RecordingIOS;
    await tester.pumpWidget(_app);
    await _settle(tester);
    await tester.tap(find.text('Unsaved changes'));
    await _settle(tester);
    _scope(tester).setSidebarVisible(true);
    await _settle(tester);
    final overlay =
        _scope(tester).chromeKind == LiquidChromeKind.sidebarOverlay;
    debugPrint('liquid_shell native: guard from ${_scope(tester).chromeKind}');
    double bodyBottom() => MediaQuery.paddingOf(
      tester.element(find.byType(DemoPage).first),
    ).bottom;
    final bottom = bodyBottom();

    await recorder.debugTap(NativeTapTarget.destination, 1);
    await _settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    // The body behind the dialog keeps its bottom padding, also where the
    // compact bar hid (owner decision): nothing behind it jumps.
    expect(bodyBottom(), bottom);
    // Inert under the dialog; an overlay sidebar closed natively (UIKit
    // reports it hidden), so nothing native covers the dialog.
    expect(recorder.configs.last.interactive, isFalse);
    expect(recorder.configs.last.selectedIndex, 0);
    if (overlay) expect(_scope(tester).sidebarVisible, isFalse);
    // The compact bar would cover the dialog's bottom: it hides.
    final compact = _scope(tester).sizeClass == LiquidSizeClass.compact;
    expect(recorder.configs.last.hidden, compact);
    await binding.takeScreenshot('native_${_runName}_guard');

    final beforeKeep = recorder.configs.length;
    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    expect(find.text('Discard changes?'), findsNothing);
    expect(_title(tester), 'Home');
    expect(bodyBottom(), bottom);
    // Re-synced: the current selection went back to UIKit, interactive.
    final resent = recorder.configs.sublist(beforeKeep);
    expect(resent, isNotEmpty);
    expect(resent.last.selectedIndex, 0);
    expect(resent.last.interactive, isTrue);

    await recorder.debugTap(NativeTapTarget.destination, 1);
    await _settle(tester);
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    expect(_title(tester), 'Inbox');
    expect(recorder.configs.last.selectedIndex, 1);
    expect(recorder.configs.last.interactive, isTrue);
  });

  testWidgets('the sidebar opens from Dart and reports back', (tester) async {
    if (!_expectNative) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    _scope(tester).setSidebarVisible(true);
    await _settle(tester);
    final scope = _scope(tester);
    if (scope.sizeClass == LiquidSizeClass.compact) {
      // UIKit's compact bar has no sidebar: the request is ignored.
      expect(scope.sidebarVisible, isFalse);
      expect(scope.chromeKind, LiquidChromeKind.bottomBar);
      return;
    }
    expect(scope.sidebarVisible, isTrue);
    expect(
      scope.chromeKind,
      anyOf(LiquidChromeKind.sidebarOverlay, LiquidChromeKind.sidebarTiled),
    );
    // VK-403: tiled, the body starts at the sidebar's edge and fills the
    // rest; overlay, it keeps the whole window under the sidebar.
    final page = tester.getRect(find.byType(DemoPage).first);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    debugPrint('liquid_shell native: ${scope.chromeKind.name} page $page');
    if (scope.chromeKind == LiquidChromeKind.sidebarTiled) {
      expect(page.left, greaterThan(200));
      expect(page.right, window.width);
    } else {
      expect(page.left, 0);
      expect(page.width, window.width);
    }
    await binding.takeScreenshot('native_${_runName}_sidebar');

    final platform = LiquidShellPlatform.instance as LiquidShellIOS;
    await platform.debugTap(NativeTapTarget.footer);
    await _settle(tester);
    expect(find.text('Settings'), findsWidgets);

    _scope(tester).setSidebarVisible(false);
    await _settle(tester);
    expect(_scope(tester).sidebarVisible, isFalse);
  });

  testWidgets('a page above the shell hides the native chrome', (
    tester,
  ) async {
    if (!_expectNative) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    // The padding on the bar's side: the top bar row, or the compact bar.
    final compact = _scope(tester).sizeClass == LiquidSizeClass.compact;
    double barSide(EdgeInsets padding) =>
        compact ? padding.bottom : padding.top;
    final below = barSide(
      MediaQuery.paddingOf(tester.element(find.byType(DemoPage).first)),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final pushed = navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const LiquidNoChrome(
          child: Scaffold(body: DemoPage(title: 'Above')),
        ),
      ),
    );
    await _settle(tester);
    final above = barSide(
      MediaQuery.paddingOf(tester.element(find.byType(DemoPage).last)),
    );
    // The bar left the safe area with the hidden chrome.
    expect(above, lessThan(below));
    navigator.pop();
    await pushed;
    await _settle(tester);
    expect(_scope(tester).nativeChrome, isTrue);
  });
}
