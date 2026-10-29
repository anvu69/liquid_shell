import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

// Native page bars on every tab (spec P3b-2 §4.4, §4.5, §6.1, §6.7).

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home', sfSymbol: 'house'),
  LiquidDestination(
    icon: Icon(Icons.book),
    label: 'Library',
    sfSymbol: 'books.vertical',
  ),
  LiquidDestination(
    icon: Icon(Icons.settings),
    label: 'Settings',
    sfSymbol: 'gear',
  ),
];

/// iPhone portrait with UIKit's compact bar in the bottom safe area.
const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

final List<GlobalKey<NavigatorState>> _navigators = [
  for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
];

/// Home: a LiquidPage root. Library: a LiquidPage root with a large
/// title. Settings: a root without LiquidPage. Each in its own navigator.
Widget _page(int index) => Navigator(
  key: _navigators[index],
  onGenerateRoute: (_) => MaterialPageRoute<void>(
    builder: (_) => switch (index) {
      0 => const LiquidPage(
        title: 'Home',
        child: TestPage(label: 'Home'),
      ),
      1 => const LiquidPage(
        title: 'Library',
        largeTitle: true,
        child: TestPage(label: 'Library'),
      ),
      _ => const TestPage(label: 'Settings'),
    },
  ),
);

Future<FakeNativePlatform> _pump(
  WidgetTester tester, {
  int initialIndex = 0,
  LiquidNativeShellState state = _compact,
  Size size = kPhone,
  EdgeInsets padding = _compactPadding,
}) async {
  final fake = installFakeNative(state: state);
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      pageBuilder: _page,
    ),
    size: size,
    padding: padding,
  );
  return fake;
}

/// Pushes [page] on tab [tab]'s navigator and settles.
Future<void> _push(WidgetTester tester, int tab, Widget page) async {
  _navigators[tab].currentState!
      .push(MaterialPageRoute<void>(builder: (_) => page))
      .ignore();
  await tester.pumpAndSettle();
}

/// A LiquidPage titled [title] over a [TestPage] labelled the same.
Widget _liquid(String title) => LiquidPage(
  title: title,
  child: TestPage(label: title),
);

/// The titles of tab [tab]'s native stack in the last config.
List<String> _titles(FakeNativePlatform fake, int tab) => [
  for (final page in fake.last.tabs[tab].pages) page.title,
];

void main() {
  group('VK-442: every tab of an engaged shell', () {
    testWidgets('has a native page bar: LiquidPage draws only its child', (
      tester,
    ) async {
      await _pump(tester);
      expect(scopeOf(tester).nativePageBar, isTrue);
      expect(find.byType(LiquidBackButton), findsNothing);
    });

    testWidgets('sends the pages pushed on it', (tester) async {
      final fake = await _pump(tester);
      await _push(tester, 0, _liquid('Detail'));
      expect(_titles(fake, 0), ['Home', 'Detail']);
      expect(find.byType(LiquidBackButton), findsNothing);
    });

    testWidgets('Library keeps its large title in the config', (tester) async {
      final fake = await _pump(tester, initialIndex: 1);
      expect(fake.last.tabs[1].pages, const [
        LiquidNativePage(title: 'Library', largeTitle: true),
      ]);
    });
  });

  group('VK-442: the stand-in root (spec §6.1)', () {
    testWidgets('a LiquidPage above a root without one gets a root titled '
        "with the destination's label", (tester) async {
      final fake = await _pump(tester, initialIndex: 2);
      expect(fake.last.tabs[2].pages, isEmpty, reason: 'no LiquidPage yet');
      await _push(tester, 2, _liquid('About'));
      expect(fake.last.tabs[2].pages, const [
        LiquidNativePage(title: 'Settings', largeTitle: false),
        LiquidNativePage(title: 'About'),
      ]);
    });

    testWidgets('a native pop to the stand-in root pops every page', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      await _push(tester, 2, _liquid('About'));
      await _push(tester, 2, _liquid('Profile'));
      expect(_titles(fake, 2), ['Settings', 'About', 'Profile']);
      fake.emitNative(const LiquidNativePopToPage(2, index: 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-About')), findsNothing);
      expect(find.byKey(const ValueKey('list-Settings')), findsOneWidget);
      expect(fake.last.tabs[2].pages, isEmpty);
    });

    testWidgets('a native pop-to above the stand-in maps its index', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      for (final title in ['About', 'Profile', 'Licences']) {
        await _push(tester, 2, _liquid(title));
      }
      fake.emitNative(const LiquidNativePopToPage(2, index: 1));
      await tester.pumpAndSettle();
      expect(_titles(fake, 2), ['Settings', 'About']);
    });

    testWidgets('the back circle over the stand-in pops the page', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      await _push(tester, 2, _liquid('About'));
      fake.emitNative(const LiquidNativeBackTapped(2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-About')), findsNothing);
      expect(fake.last.tabs[2].pages, isEmpty);
    });

    testWidgets('a LiquidPage root of its navigator gets none', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await _push(tester, 0, _liquid('Detail'));
      expect(fake.last.tabs[0].pages.first.title, 'Home');
      expect(fake.last.tabs[0].pages, hasLength(2));
    });
  });

  group("VK-442: LiquidHideChrome keeps a page's native bar (spec §4.4)", () {
    const photo = LiquidHideChrome(
      child: LiquidPage(
        title: 'Photo',
        child: TestPage(label: 'Photo'),
      ),
    );

    testWidgets('over a LiquidPage: the tab bar hides, the chrome stays', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await _push(tester, 0, photo);
      expect(_titles(fake, 0), ['Home', 'Photo']);
      expect(fake.last.tabBarHidden, isTrue);
      expect(fake.last.hidden, isFalse);
      final scope = scopeOf(tester, 'Photo');
      expect(scope.chromeKind, LiquidChromeKind.hidden);
      expect(scope.chromeInsets, EdgeInsets.zero);
      expect(scope.nativePageBar, isTrue, reason: 'the page keeps its bar');

      _navigators[0].currentState!.pop();
      await tester.pumpAndSettle();
      expect(fake.last.tabBarHidden, isFalse, reason: 'the request ended');
      expect(fake.last.hidden, isFalse);
    });

    testWidgets('over a page without LiquidPage: the whole chrome hides', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      await _push(
        tester,
        2,
        const LiquidHideChrome(child: TestPage(label: 'Plain')),
      );
      expect(fake.last.tabs[2].pages, isEmpty);
      expect(fake.last.hidden, isTrue);
      expect(fake.last.tabBarHidden, isFalse);
    });
  });

  group('VK-442: window controls (spec §4.5)', () {
    const controls = LiquidWindowControls(leading: 66, top: 24);

    testWidgets('a tab without pages under the compact native bar keeps '
        "native's window controls", (tester) async {
      final fake = await _pump(tester, initialIndex: 2);
      fake.emitNative(const LiquidWindowControlsChanged(controls));
      await tester.pump();
      expect(scopeOf(tester, 'Settings').windowControls, controls);
    });

    testWidgets("LiquidHideChrome at regular width passes native's window "
        'controls', (tester) async {
      final fake = await _pump(
        tester,
        initialIndex: 2,
        state: kInstalled,
        size: kTabletLandscape,
        padding: const EdgeInsets.only(top: 74, bottom: 20),
      );
      await _push(
        tester,
        2,
        const LiquidHideChrome(child: TestPage(label: 'Plain')),
      );
      fake.emitNative(const LiquidWindowControlsChanged(controls));
      await tester.pump();
      expect(scopeOf(tester, 'Plain').windowControls, controls);
    });
  });
}
