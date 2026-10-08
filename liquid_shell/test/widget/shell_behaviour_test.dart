import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import '../helpers/fake_signals_platform.dart';
import '../helpers/shell_harness.dart';

const _tablet = EdgeInsets.only(top: 24, bottom: 20);

Future<void> _openSidebar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Show sidebar'));
  await tester.pumpAndSettle();
}

void main() {
  group('selection', () {
    testWidgets('a tap selects; reselect calls back too', (tester) async {
      final selections = <int>[];
      await pumpShell(tester, TestShell(selections: selections));
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(selections, [1, 1]);
    });

    testWidgets('picking in the overlay closes it; tiled stays open', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await _openSidebar(tester);
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);

      await resize(tester, kTabletLandscape);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsOneWidget);
    });

    testWidgets('selectedIndex out of range asserts in debug', (tester) async {
      await pumpShell(
        tester,
        const TestShell(initialIndex: 9),
        settle: false,
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect('$error', contains('0..3'));
    });

    testWidgets('more than five tab bar destinations assert', (tester) async {
      await pumpShell(
        tester,
        TestShell(
          destinations: [
            for (var i = 0; i < 6; i++)
              LiquidDestination(icon: const Icon(Icons.circle), label: '$i'),
          ],
        ),
        settle: false,
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect('$error', contains('1 to 5'));
    });

    testWidgets('no tab bar destination asserts (Q4)', (tester) async {
      await pumpShell(
        tester,
        const TestShell(
          destinations: [
            LiquidDestination(
              icon: Icon(Icons.circle),
              label: 'Only',
              placement: LiquidPlacement.sidebarOnly,
            ),
          ],
        ),
        settle: false,
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect('$error', contains('1 to 5'));
    });

    testWidgets('an empty label asserts', (tester) async {
      await pumpShell(
        tester,
        const TestShell(
          destinations: [
            LiquidDestination(icon: Icon(Icons.circle), label: 'Home'),
            LiquidDestination(icon: Icon(Icons.circle), label: ''),
          ],
        ),
        settle: false,
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect('$error', contains('label must be non-empty'));
    });

    testWidgets('sidebarWidth outside (0, breakpoints.regular) asserts', (
      tester,
    ) async {
      for (final width in [0.0, 700.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: LiquidShell(
              destinations: kDestinations,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              sidebarWidth: width,
              body: const SizedBox(),
            ),
          ),
        );
        final error = tester.takeException();
        expect(error, isAssertionError, reason: '$width');
        expect('$error', contains('sidebarWidth'));
      }
    });

    testWidgets('empty destinations assert', (tester) async {
      await pumpShell(
        tester,
        const TestShell(destinations: []),
        settle: false,
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect('$error', contains('must not be empty'));
    });
  });
  group('beforeDestinationChange', () {
    testWidgets('accept → callback and the overlay closes', (tester) async {
      final selections = <int>[];
      final asked = <int>[];
      await pumpShell(
        tester,
        TestShell(
          selections: selections,
          guard: (i) async {
            asked.add(i);
            return true;
          },
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await _openSidebar(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(asked, [3]);
      expect(selections, [3]);
      expect(find.byType(LiquidSidebar), findsNothing);
    });

    testWidgets('refuse → no callback and the overlay stays open', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpShell(
        tester,
        TestShell(selections: selections, guard: (i) async => false),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await _openSidebar(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(find.byType(LiquidSidebar), findsOneWidget);
    });

    testWidgets('throw → refused and reported with library liquid_shell', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpShell(
        tester,
        TestShell(
          selections: selections,
          guard: (i) async => throw StateError('dialog failed'),
        ),
      );
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await tester.tap(find.text('Inbox'));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = original;
      }
      expect(selections, isEmpty);
      expect(errors.single.library, 'liquid_shell');
      expect(errors.single.exception, isA<StateError>());
      expect(
        errors.single.context.toString(),
        contains('beforeDestinationChange'),
      );
    });

    testWidgets('a second tap while the guard is pending is ignored', (
      tester,
    ) async {
      final selections = <int>[];
      final pending = Completer<bool>();
      final asked = <int>[];
      await pumpShell(
        tester,
        TestShell(
          selections: selections,
          guard: (i) {
            asked.add(i);
            return pending.future;
          },
        ),
      );
      await tester.tap(find.text('Inbox'));
      await tester.tap(find.text('Settings'));
      await tester.pump();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(asked, [1]);
      expect(selections, [1]);
    });

    testWidgets('unmounting while pending drops the result', (tester) async {
      final selections = <int>[];
      final pending = Completer<bool>();
      await pumpShell(
        tester,
        TestShell(selections: selections, guard: (i) => pending.future),
      );
      await tester.tap(find.text('Inbox'));
      await tester.pumpWidget(const SizedBox());
      pending.complete(true);
      await tester.pump();
      expect(selections, isEmpty);
    });

    testWidgets('reselect runs the guard; programmatic changes do not', (
      tester,
    ) async {
      final asked = <int>[];
      await pumpShell(
        tester,
        TestShell(
          guard: (i) async {
            asked.add(i);
            return true;
          },
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      tester.state<TestShellState>(find.byType(TestShell)).select(3);
      await tester.pumpAndSettle();
      expect(asked, [0]);
    });
  });
  group('sidebarOnly', () {
    testWidgets('absent from the pill, present in the sidebar', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(find.text('Reports'), findsNothing);
      await _openSidebar(tester);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('selected in compact: nothing highlighted, callback once', (
      tester,
    ) async {
      final hidden = <int>[];
      await pumpShell(
        tester,
        TestShell(initialIndex: 2, onHidden: hidden.add),
      );
      final scheme = Theme.of(
        tester.element(find.byType(LiquidTabBar)),
      ).colorScheme;
      for (final label in ['Home', 'Inbox', 'Settings']) {
        expect(
          tester.widget<Text>(find.text(label)).style!.color,
          scheme.onSurfaceVariant,
        );
      }
      expect(hidden, [2]);
      await tester.pump();
      expect(hidden, [2]);
    });

    testWidgets('regular → compact → regular → compact calls back twice', (
      tester,
    ) async {
      final hidden = <int>[];
      await pumpShell(
        tester,
        TestShell(initialIndex: 2, onHidden: hidden.add),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(hidden, isEmpty);
      await resize(tester, kPhone);
      await resize(tester, kTabletPortrait);
      await resize(tester, kPhone);
      expect(hidden, [2, 2]);
    });
  });
  group('per-tab state survives every chrome change (§5.6)', () {
    testWidgets('sidebar toggle, compact↔regular, rotation, hide chrome, '
        'chromeBuilder and tier', (tester) async {
      final platform = installFakeSignals();
      var useBuilder = false;
      var hide = false;
      late StateSetter rebuild;
      await pumpShell(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TestShell(
              chromeBuilder: useBuilder
                  ? (context, details, defaultChrome) => defaultChrome
                  : null,
              pageBuilder: (i) => i == 0
                  ? LiquidHideChrome(
                      enabled: hide,
                      child: TestPage(label: kDestinations[i].label),
                    )
                  : TestPage(label: kDestinations[i].label),
            );
          },
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.text('Home page: 0'));
      await tester.pump();
      expect(tapsOf(tester, 'Home'), 1);

      Future<void> check(String step) async {
        await tester.pumpAndSettle();
        expect(tapsOf(tester, 'Home'), 1, reason: step);
      }

      await _openSidebar(tester);
      await check('sidebar shown');
      await tester.tap(find.byTooltip('Hide sidebar'));
      await check('sidebar hidden');
      await resize(tester, kPhone);
      await check('compact');
      await resize(tester, kTabletLandscape);
      await check('rotation to tiled');
      await resize(tester, kTabletPortrait);
      await check('rotation back');
      rebuild(() => hide = true);
      await check('hide chrome on');
      rebuild(() => hide = false);
      await check('hide chrome off');
      rebuild(() => useBuilder = true);
      await check('chromeBuilder added');
      rebuild(() => useBuilder = false);
      await check('chromeBuilder removed');
      platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
      await check('tier change');
    });
  });

  group('minimise on scroll (§5.7)', () {
    testWidgets('reverse minimises, forward expands', (tester) async {
      await pumpShell(tester, const TestShell());
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('Home'), findsOneWidget);

      await tester.drag(list, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
    });

    testWidgets('a horizontal carousel does not minimise; the vertical '
        'page around it still does', (tester) async {
      await pumpShell(
        tester,
        TestShell(
          pageBuilder: (i) => ListView(
            key: ValueKey('page-$i'),
            children: [
              SizedBox(
                height: 120,
                child: ListView(
                  key: ValueKey('carousel-$i'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var c = 0; c < 20; c++)
                      SizedBox(width: 150, child: Text('card $c')),
                  ],
                ),
              ),
              for (var r = 0; r < 60; r++)
                SizedBox(height: 40, child: Text('row $r')),
            ],
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('carousel-0')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('card 0'), findsNothing, reason: 'it did scroll');
      expect(find.text('Inbox'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('page-0')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing);
    });

    testWidgets('a tap expands without changing tab and announces', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpShell(tester, TestShell(selections: selections));
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
      expect(selections, isEmpty);
      expect(
        tester.takeAnnouncements().single.message,
        'Navigation bar opened',
      );
    });

    testWidgets('minimizeOnScroll: false keeps the bar', (tester) async {
      await pumpShell(tester, const TestShell(minimizeOnScroll: false));
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
    });

    testWidgets('does not apply to the top bar', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
      // The scroll above left no minimised state behind for compact.
      await resize(tester, kPhone);
      expect(find.text('Inbox'), findsOneWidget);
    });
  });

  group('glass in the shell', () {
    testWidgets('chrome shares one BackdropGroup and turns solid on a '
        'signal', (tester) async {
      final platform = installFakeSignals();
      await pumpShell(
        tester,
        TestShell(
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () {},
            semanticLabel: 'Search',
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNWidgets(2));
      expect(find.byType(BackdropGroup), findsOneWidget);

      platform.emit(const LiquidPlatformSignals(powerSave: true));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('light and dark come from LiquidGlassTheme.of', (
      tester,
    ) async {
      final dark = ColorScheme.fromSeed(
        seedColor: const Color(0xFF3366CC),
        brightness: Brightness.dark,
      );
      await pumpShell(
        tester,
        const TestShell(),
        theme: ThemeData(colorScheme: dark),
      );
      final expected = LiquidGlassTheme.fromColorScheme(dark).tint;
      final fills = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == expected);
      expect(fills, isNotEmpty);
    });
  });

  group('strings', () {
    testWidgets('toggle and hide tooltips come from strings', (tester) async {
      await pumpShell(
        tester,
        const TestShell(
          strings: LiquidShellStrings(
            showSidebar: 'Hiện thanh bên',
            hideSidebar: 'Ẩn thanh bên',
          ),
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Hiện thanh bên'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ẩn thanh bên'), findsOneWidget);
    });
  });
}
