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
