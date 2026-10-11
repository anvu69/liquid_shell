// Native vs Flutter liquid screenshots for the owner's acceptance (spec
// 2026-10-10 §10.4, §11). tool/compare_ios.sh and tool/compare_android.sh
// run it; tool/side_by_side.dart places the pairs next to each other.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/main.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// `ios` or `android`: the first part of every screenshot name.
const _platform = String.fromEnvironment('COMPARE_PLATFORM');

/// The device part of the name, for example `iphone` or `ipad`.
const _device = String.fromEnvironment('COMPARE_DEVICE');

/// The modes to capture, comma-separated (`native,flutterLiquid`).
const _modes = String.fromEnvironment(
  'COMPARE_MODES',
  defaultValue: 'native,flutterLiquid',
);

/// Whether native chrome must engage in `native` mode (iOS 26).
const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');

/// Cases also captured with the sidebar shown, at regular width (iPad).
const _sidebarCases = {'sidebar_only', 'sidebar_slots'};

/// The cases with native chrome (owner decision E1), in README order.
const kCompareCases = [
  'basic',
  'badges',
  'sidebar_only',
  'sidebar_slots',
  'trailing',
  'guard',
  'hide_chrome',
  'native_chrome',
];

Future<void> _open(WidgetTester tester, String id) async {
  // From the top: the previous case may have left the list scrolled past
  // this row, and scrollUntilVisible only scrolls one way.
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// Lets the native side answer and lay out.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String mode) async {
  final label = mode == 'flutterLiquid'
      ? 'Flutter liquid'
      : (defaultTargetPlatform == TargetPlatform.iOS ? 'Native' : 'Auto');
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('chrome-mode')),
      matching: find.text(label),
    ),
  );
  // Native chrome attaches over the channel: give it a moment.
  await _settle(tester);
}

/// Back to the case list. The root navigator pops: with native chrome
/// there is no Flutter back button for `pageBack` to tap.
Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await _settle(tester);
}

bool _liquidShown() => find
    .byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidBackdrop')
    .evaluate()
    .isNotEmpty;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The screenshots are compared and published: no DEBUG banner.
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('native and Flutter liquid, case by case', (tester) async {
    expect(_platform, isNotEmpty, reason: 'pass COMPARE_PLATFORM');
    await LiquidGlass.precache();
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    for (final mode in _modes.split(',')) {
      for (final id in kCompareCases) {
        await _open(tester, id);
        await _select(tester, mode);

        final scope = LiquidShellScope.of(
          tester.element(find.byType(DemoPage).first),
        );
        if (mode == 'flutterLiquid') {
          expect(scope.nativeChrome, isFalse, reason: '$id: forced liquid');
          expect(_liquidShown(), isTrue, reason: '$id: liquid drawn');
        } else if (_expectNative) {
          expect(scope.nativeChrome, isTrue, reason: '$id: native chrome');
        }

        // Scroll so cards and wallpaper sit under the chrome, then back a
        // little: scrolling down minimises the Flutter bar (the native one
        // does not), scrolling up expands it again.
        final list = find.byType(Scrollable).first;
        await tester.drag(list, const Offset(0, -340));
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, 40));
        // The bar's expand animation can still be running on the device
        // after pumpAndSettle: give it time, or the shot catches it half way.
        await _settle(tester);
        await binding.takeScreenshot('${_platform}_${_device}_${id}_$mode');

        if (_sidebarCases.contains(id) &&
            scope.sizeClass == LiquidSizeClass.regular) {
          scope.setSidebarVisible(true);
          await _settle(tester);
          await binding.takeScreenshot(
            '${_platform}_${_device}_${id}_sidebar_$mode',
          );
          LiquidShellScope.of(
            tester.element(find.byType(DemoPage).first),
          ).setSidebarVisible(false);
          await _settle(tester);
        }

        await _back(tester);
      }
    }
  });
}
