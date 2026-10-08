import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

import '../helpers/shell_harness.dart';

const _tablet = EdgeInsets.only(top: 24, bottom: 20);

void main() {
  group('chrome by width (§5.1)', () {
    testWidgets('iPhone 393×852 → bottom bar', (tester) async {
      await pumpShell(tester, const TestShell());
      final scope = scopeOf(tester);
      expect(scope.sizeClass, LiquidSizeClass.compact);
      expect(scope.chromeKind, LiquidChromeKind.bottomBar);
      expect(scope.chromeInsets, const EdgeInsets.only(bottom: 83));
      expect(scope.sidebarVisible, isFalse);
      expect(find.byType(LiquidTabBar), findsOneWidget);
      expect(find.byType(LiquidSidebar), findsNothing);
      expect(find.byTooltip('Show sidebar'), findsNothing);
      // The pill sits 21 above the bottom edge, over the home indicator.
      final pill = tester.getRect(
        find.descendant(
          of: find.byType(LiquidTabBar),
          matching: find.byType(LiquidGlass),
        ),
      );
      expect(pill.bottom, 852 - 21);
      expect(pill.height, 62);
    });

    testWidgets('932×430 landscape phone → top bar, sidebar overlays', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kPhoneLandscape,
        padding: const EdgeInsets.only(left: 59, right: 59, bottom: 21),
      );
      final scope = scopeOf(tester);
      expect(scope.sizeClass, LiquidSizeClass.regular);
      expect(scope.chromeKind, LiquidChromeKind.topBar);
      expect(scope.chromeInsets, const EdgeInsets.only(top: 72));
      expect(find.byTooltip('Show sidebar'), findsOneWidget);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarOverlay);
      expect(find.byType(LiquidSidebar), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('iPad portrait 834×1194 → top bar; body never resized', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
      expect(scopeOf(tester).chromeInsets, const EdgeInsets.only(top: 96));
      // The pill is centred; the toggle is a 48pt circle at (20, pad.top+20).
      expect(
        tester.getRect(find.byType(SidebarToggle)),
        const Rect.fromLTWH(20, 44, 48, 48),
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('list-Home'))).width,
        834,
      );
    });

    testWidgets('iPad landscape 1194×834 → tiled sidebar, body beside it', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletLandscape,
        padding: _tablet,
      );
      final scope = scopeOf(tester);
      expect(scope.chromeKind, LiquidChromeKind.sidebarTiled);
      expect(scope.chromeInsets, EdgeInsets.zero);
      expect(scope.sidebarVisible, isTrue);
      expect(find.byType(LiquidTabBar), findsNothing);
      final body = tester.element(find.byKey(const ValueKey('list-Home')));
      expect(MediaQuery.sizeOf(body).width, 1194 - 300);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('list-Home'))).dx,
        300,
      );

      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
      expect(find.byType(LiquidTabBar), findsOneWidget);
      expect(MediaQuery.sizeOf(body).width, 1194);
    });

    testWidgets('tiled: the body loses the start padding the sidebar covers', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletLandscape,
        padding: const EdgeInsets.only(left: 30, top: 24),
      );
      final body = tester.element(find.byKey(const ValueKey('list-Home')));
      expect(MediaQuery.paddingOf(body).left, 0);
      expect(MediaQuery.paddingOf(body).top, 24);
    });
  });

  group('hit targets at narrow widths (Q4, Q17)', () {
    const labels = ['Home', 'Inbox', 'Search', 'Library', 'Settings'];
    final add = LiquidTabAction(
      icon: const Icon(Icons.add),
      onPressed: () {},
      semanticLabel: 'Add',
    );

    Future<List<Rect>> cells(
      WidgetTester tester,
      int count, {
      LiquidTabAction? trailing,
      List<int>? selections,
      double width = 320,
      TextDirection direction = TextDirection.ltr,
    }) async {
      await pumpShell(
        tester,
        TestShell(
          destinations: [
            for (final label in labels.take(count))
              LiquidDestination(icon: const Icon(Icons.circle), label: label),
          ],
          trailing: trailing,
          selections: selections,
        ),
        size: Size(width, 568),
        padding: const EdgeInsets.only(top: 20),
        direction: direction,
      );
      return [
        for (final label in labels.take(count))
          tester.getRect(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(InkWell),
            ),
          ),
      ];
    }

    // The bottom row: the shell's Align, as wide as the window minus margins.
    Rect row(WidgetTester tester) => tester.getRect(
      find
          .ancestor(of: find.byType(LiquidTabBar), matching: find.byType(Align))
          .first,
    );

    // The pill: the first glass inside the bar (the second is the circle).
    Rect pill(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(LiquidTabBar),
            matching: find.byType(LiquidGlass),
          )
          .first,
    );

    Rect circle(WidgetTester tester) => tester.getRect(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(LiquidGlass),
      ),
    );

    testWidgets('320: 5 tabs + trailing keep 45.2pt cells with margin 8 and '
        'pill padding 4, tile the pill, and each tap selects its tab', (
      tester,
    ) async {
      final selections = <int>[];
      final rects = await cells(
        tester,
        5,
        trailing: add,
        selections: selections,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(row(tester).left, 8);
      expect(row(tester).right, 312);
      expect(rects.first.left - pill(tester).left, 4);
      // (320 − 2×8 margin − 62 circle − 8 gap − 2×4 pill padding) / 5.
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.width, moreOrLessEquals(45.2, epsilon: 0.01));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, moreOrLessEquals(rects[i - 1].right));
      }
      expect(circle(tester).right, 312);
      for (final label in labels) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(selections, [0, 1, 2, 3, 4]);
    });

    testWidgets('375: the regular margin 16 and pill padding 8 are kept', (
      tester,
    ) async {
      final rects = await cells(tester, 5, trailing: add, width: 375);
      expect(row(tester).left, 16);
      expect(row(tester).right, 375 - 16);
      expect(rects.first.left - pill(tester).left, 8);
      expect(circle(tester).right, 375 - 16);
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('339 is narrow, 340 is not (kLiquidNarrowWidth)', (
      tester,
    ) async {
      var rects = await cells(tester, 5, trailing: add, width: 339);
      expect(row(tester).left, 8);
      expect(row(tester).right, 339 - 8);
      expect(rects.first.left - pill(tester).left, 4);
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }

      rects = await cells(tester, 5, trailing: add, width: 340);
      expect(row(tester).left, 16);
      expect(row(tester).right, 340 - 16);
      expect(rects.first.left - pill(tester).left, 8);
      // (340 − 32 − 62 − 8 − 16) / 5 = 44.4.
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('RTL at 320: mirrored, same margins, 45.2pt cells', (
      tester,
    ) async {
      final rects = await cells(
        tester,
        5,
        trailing: add,
        direction: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(row(tester).left, 8);
      expect(row(tester).right, 312);
      // The circle sits at the pill's left; the first tab at its right.
      expect(circle(tester).left, 8);
      expect(pill(tester).right - rects.first.right, 4);
      expect(rects.first.left, greaterThan(rects.last.left));
      for (final rect in rects) {
        expect(rect.width, moreOrLessEquals(45.2, epsilon: 0.01));
      }
    });

    testWidgets('4 tabs + trailing, or 5 tabs alone, keep 44pt cells', (
      tester,
    ) async {
      for (final rect in await cells(tester, 4, trailing: add)) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }
      for (final rect in await cells(tester, 5)) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }
    });
  });

  group('sidebar', () {
    testWidgets('overlay closes on barrier tap; Hide button closes it', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(800, 600));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);
    });

    testWidgets('the overlay barrier hides the content behind it from '
        'screen readers and is labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(find.semantics.byLabel('Home page: 0'), findsOne);
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Home page: 0'), findsNothing);
      expect(find.semantics.byLabel('Hide sidebar'), findsOne);
      handle.dispose();
    });

    testWidgets('system back closes the overlay (Q10)', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);
      expect(find.byType(TestShell), findsOneWidget);
    });

    group("back blocked by the app's own PopScope", () {
      /// Sends system back with `debugPrint` captured; returns the logs.
      Future<List<String>> back(WidgetTester tester) async {
        final logs = <String>[];
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
        try {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } finally {
          debugPrint = original;
        }
        return logs;
      }

      const blocked = PopScope<Object?>(canPop: false, child: TestShell());

      testWidgets('tiled: the sidebar stays, nothing is logged', (
        tester,
      ) async {
        await pumpShell(
          tester,
          blocked,
          size: kTabletLandscape,
          padding: _tablet,
        );
        expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarTiled);
        final logs = await back(tester);
        expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarTiled);
        expect(scopeOf(tester).sidebarVisible, isTrue);
        expect(logs, isEmpty);
      });

      testWidgets('compact: nothing changes, nothing is logged', (
        tester,
      ) async {
        await pumpShell(tester, blocked);
        final logs = await back(tester);
        expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
        expect(logs, isEmpty);
      });

      testWidgets('overlay: back still closes it (Q10)', (tester) async {
        await pumpShell(
          tester,
          blocked,
          size: kTabletPortrait,
          padding: _tablet,
        );
        await tester.tap(find.byTooltip('Show sidebar'));
        await tester.pumpAndSettle();
        expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarOverlay);
        await back(tester);
        expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
        expect(find.byType(LiquidSidebar), findsNothing);
      });
    });

    testWidgets('visibility resets when the presentation changes (Q2)', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletLandscape,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).sidebarVisible, isFalse);

      await resize(tester, kTabletPortrait);
      expect(scopeOf(tester).sidebarVisible, isFalse);
      await resize(tester, kTabletLandscape);
      expect(scopeOf(tester).sidebarVisible, isTrue, reason: 'tiled default');
    });

    testWidgets('setSidebarVisible from the scope; ignored in compact', (
      tester,
    ) async {
      final logs = <String>[];
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      scopeOf(tester).setSidebarVisible(true);
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarOverlay);

      await resize(tester, kPhone);
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        scopeOf(tester).setSidebarVisible(true);
        await tester.pumpAndSettle();
      } finally {
        debugPrint = original;
      }
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(logs.single, contains('compact'));
    });

    testWidgets('header, footer, hide button and trailing row', (
      tester,
    ) async {
      var searched = 0;
      await pumpShell(
        tester,
        TestShell(
          sidebarHeader: const Text('Acme'),
          sidebarFooter: const Text('Signed in as Ana'),
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () => searched++,
            semanticLabel: 'Search',
          ),
        ),
        size: kTabletLandscape,
        padding: _tablet,
      );
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('Signed in as Ana'), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsOneWidget);
      await tester.tap(find.text('Search'));
      expect(searched, 1);
    });

    testWidgets('RTL: the toggle sits at the top right', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
        direction: TextDirection.rtl,
      );
      expect(
        tester.getRect(find.byType(SidebarToggle)),
        const Rect.fromLTWH(834 - 20 - 48, 44, 48, 48),
      );
    });
  });

  group('trailing action', () {
    LiquidTabAction search(VoidCallback onPressed) => LiquidTabAction(
      icon: const Icon(Icons.search),
      onPressed: onPressed,
      semanticLabel: 'Search',
    );

    testWidgets('a circle in the bottom bar, kept when minimised', (
      tester,
    ) async {
      var pressed = 0;
      await pumpShell(tester, TestShell(trailing: search(() => pressed++)));
      await tester.tap(find.byTooltip('Search'));
      expect(pressed, 1);

      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing, reason: 'minimised');
      expect(find.byTooltip('Search'), findsOneWidget);
    });

    testWidgets('a circle in the top bar', (tester) async {
      await pumpShell(
        tester,
        TestShell(trailing: search(() {})),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(find.byTooltip('Search'), findsOneWidget);
    });
  });

  group('bottom gap (Q9)', () {
    testWidgets('Android 3-button navigation: max(21, padding + 8)', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: const Size(412, 915),
        padding: const EdgeInsets.only(top: 24, bottom: 48),
        platform: TargetPlatform.android,
      );
      final pill = tester.getRect(
        find.descendant(
          of: find.byType(LiquidTabBar),
          matching: find.byType(LiquidGlass),
        ),
      );
      expect(pill.bottom, 915 - 56);
      expect(scopeOf(tester).chromeInsets.bottom, 62 + 56);
    });

    testWidgets('Android gesture navigation: 21', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: const Size(412, 915),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        gestureInsets: const EdgeInsets.only(bottom: 24),
        platform: TargetPlatform.android,
      );
      expect(scopeOf(tester).chromeInsets.bottom, 83);
    });
  });

  group('page helpers', () {
    testWidgets('LiquidHideChrome hides every slot and zeroes the insets; '
        'requests are reference-counted', (tester) async {
      await pumpShell(
        tester,
        TestShell(
          pageBuilder: (i) => i == 0
              ? const _HideChromePage()
              : TestPage(label: kDestinations[i].label),
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      final state = tester.state<_HideChromePageState>(
        find.byType(_HideChromePage),
      )..set(first: true, second: true);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsNothing);
      expect(find.byTooltip('Show sidebar'), findsNothing);
      final scope = LiquidShellScope.of(tester.element(find.text('probe')));
      expect(scope.chromeKind, LiquidChromeKind.hidden);
      expect(scope.chromeInsets, EdgeInsets.zero);

      state.set(first: false, second: true);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsNothing, reason: 'one left');

      state.set(first: false, second: false);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsOneWidget);
    });

    group('only the visible branch or route hides the chrome', () {
      Widget hidesOnInbox(int i) => i == 1
          ? LiquidHideChrome(child: TestPage(label: kDestinations[i].label))
          : TestPage(label: kDestinations[i].label);

      for (final offstage in [false, true]) {
        final keptBy = offstage ? 'Offstage + TickerMode' : 'IndexedStack';
        testWidgets('kept alive by $keptBy: a programmatic switch away shows '
            'the chrome, switching back hides it', (tester) async {
          await pumpShell(
            tester,
            TestShell(
              initialIndex: 1,
              pageBuilder: hidesOnInbox,
              offstageBranches: offstage,
            ),
          );
          expect(find.byType(LiquidTabBar), findsNothing);

          // A deep link or notification tap: no user selection involved.
          tester.state<TestShellState>(find.byType(TestShell)).select(0);
          await tester.pumpAndSettle();
          expect(find.byType(LiquidTabBar), findsOneWidget);
          expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);

          tester.state<TestShellState>(find.byType(TestShell)).select(1);
          await tester.pumpAndSettle();
          expect(find.byType(LiquidTabBar), findsNothing);
        });

        testWidgets('kept alive by $keptBy: an inactive branch that hides '
            'from the start does not hide the chrome', (tester) async {
          await pumpShell(
            tester,
            TestShell(pageBuilder: hidesOnInbox, offstageBranches: offstage),
          );
          expect(find.byType(LiquidTabBar), findsOneWidget);
        });
      }

      testWidgets('a route covered by an opaque route stops hiding; popping '
          'back to it hides again', (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await pumpShell(
          tester,
          TestShell(
            pageBuilder: (i) => i == 0
                ? Navigator(
                    key: navigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const TestPage(label: 'Home'),
                    ),
                  )
                : TestPage(label: kDestinations[i].label),
          ),
        );
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const LiquidHideChrome(child: Text('detail')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiquidTabBar), findsNothing);

        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const Text('above')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiquidTabBar), findsOneWidget);

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(LiquidTabBar), findsNothing);
      });
    });

    testWidgets('a hide request made outside a frame applies at once', (
      tester,
    ) async {
      await pumpShell(tester, const TestShell());
      final registry =
          tester
                .widget<ShellScopeMarker>(find.byType(ShellScopeMarker))
                .registry!
            ..addHideRequest();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(find.byType(LiquidTabBar), findsNothing);

      registry.removeHideRequest();
      await tester.pump();
      expect(find.byType(LiquidTabBar), findsOneWidget);
    });

    testWidgets('LiquidHideChrome(enabled: false) and outside a shell are '
        'no-ops', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiquidHideChrome(child: Text('alone'))),
      );
      expect(find.text('alone'), findsOneWidget);

      await pumpShell(
        tester,
        TestShell(
          pageBuilder: (i) => LiquidHideChrome(
            enabled: false,
            child: TestPage(label: kDestinations[i].label),
          ),
        ),
      );
      expect(find.byType(LiquidTabBar), findsOneWidget);
    });

    testWidgets('LiquidNoChrome publishes none(); contentPaddingOf takes the '
        'larger of chrome and system padding', (tester) async {
      await pumpShell(tester, const TestShell());
      final inShell = tester.element(find.byKey(const ValueKey('list-Home')));
      expect(
        LiquidShellScope.contentPaddingOf(inShell),
        const EdgeInsets.only(top: 59, bottom: 83),
      );

      final navigator = Navigator.of(inShell);
      unawaitedPush(navigator);
      await tester.pumpAndSettle();
      final above = tester.element(find.text('above'));
      expect(LiquidShellScope.of(above), LiquidShellScopeData.none());
      expect(
        LiquidShellScope.contentPaddingOf(above),
        const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(
        tester
            .widget<Padding>(
              find
                  .ancestor(
                    of: find.text('above'),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding,
        const EdgeInsets.only(top: 59, bottom: 34),
      );
    });

    testWidgets('LiquidShellScope.of outside a shell asserts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              LiquidShellScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    test('LiquidShellScopeData == ignores the setter', () {
      LiquidShellScopeData data(ValueSetter<bool> setter) =>
          LiquidShellScopeData(
            sizeClass: LiquidSizeClass.regular,
            chromeKind: LiquidChromeKind.topBar,
            chromeInsets: const EdgeInsets.only(top: 96),
            sidebarVisible: false,
            setSidebarVisible: setter,
          );
      expect(data((_) {}), data((_) {}));
      expect(data((_) {}).hashCode, data((_) {}).hashCode);
      expect(
        LiquidShellScopeData.none(),
        LiquidShellScopeData(
          sizeClass: LiquidSizeClass.compact,
          chromeKind: LiquidChromeKind.hidden,
          chromeInsets: EdgeInsets.zero,
          sidebarVisible: false,
          setSidebarVisible: (_) {},
        ),
      );
      // The no-shell setter does nothing (and does not throw).
      LiquidShellScopeData.none().setSidebarVisible(true);
    });
  });

  group('custom chrome', () {
    testWidgets('the builder gets the default chrome and the details of '
        'each visible slot', (tester) async {
      final calls = <LiquidChromeDetails>[];
      await pumpShell(
        tester,
        TestShell(
          initialIndex: 1,
          chromeBuilder: (context, details, defaultChrome) {
            calls.add(details);
            return KeyedSubtree(
              key: ValueKey('custom-${details.slot.name}'),
              child: defaultChrome,
            );
          },
        ),
        size: kTabletLandscape,
        padding: _tablet,
      );
      final sidebar = calls.lastWhere(
        (d) => d.slot == LiquidChromeSlot.sidebar,
      );
      expect(sidebar.kind, LiquidChromeKind.sidebarTiled);
      expect(sidebar.visibleIndices, [0, 1, 2, 3]);
      expect(sidebar.selectedIndex, 1);
      expect(sidebar.sidebarVisible, isTrue);
      expect(find.byKey(const ValueKey('custom-sidebar')), findsOneWidget);
      expect(find.byType(LiquidSidebar), findsOneWidget);

      sidebar.setSidebarVisible(false);
      await tester.pumpAndSettle();
      final bar = calls.lastWhere((d) => d.slot == LiquidChromeSlot.tabBar);
      expect(bar.kind, LiquidChromeKind.topBar);
      expect(bar.visibleIndices, [0, 1, 3]);
      expect(bar.minimized, isFalse);
      expect(find.byKey(const ValueKey('custom-tabBar')), findsOneWidget);

      bar.select(3);
      await tester.pumpAndSettle();
      expect(scopeOf(tester, 'Settings').chromeKind, LiquidChromeKind.topBar);
    });

    testWidgets('a custom 100pt bar is measured into chromeInsets', (
      tester,
    ) async {
      await pumpShell(
        tester,
        TestShell(
          chromeBuilder: (context, details, defaultChrome) =>
              details.slot == LiquidChromeSlot.tabBar
              ? const SizedBox(width: 300, height: 100, child: Text('bar'))
              : defaultChrome,
        ),
      );
      expect(scopeOf(tester).chromeInsets, const EdgeInsets.only(bottom: 121));
      expect(find.byType(LiquidTabBar), findsNothing);
    });

    testWidgets('a custom bar collapsed to 0pt is measured: no inset', (
      tester,
    ) async {
      await pumpShell(
        tester,
        TestShell(
          chromeBuilder: (context, details, defaultChrome) =>
              details.slot == LiquidChromeSlot.tabBar
              ? const SizedBox(width: 300, height: 0)
              : defaultChrome,
        ),
      );
      expect(scopeOf(tester).chromeInsets, EdgeInsets.zero);
    });

    // A chromeBuilder result has no Scaffold or Material of the app above
    // it. Its text must still get the theme's style, like the default
    // chrome, not MaterialApp's red, double-underlined fallback.
    for (final (slot, size, padding) in [
      (LiquidChromeSlot.tabBar, kPhone, const EdgeInsets.only(bottom: 34)),
      (LiquidChromeSlot.sidebar, kTabletLandscape, _tablet),
    ]) {
      testWidgets('text in a custom ${slot.name} gets the theme text style', (
        tester,
      ) async {
        await pumpShell(
          tester,
          TestShell(
            chromeBuilder: (context, details, defaultChrome) =>
                details.slot == slot
                ? Text('custom ${slot.name}')
                : defaultChrome,
            // TestPage has no Material of its own; only chrome is checked.
            pageBuilder: (_) => const SizedBox.expand(),
          ),
          size: size,
          padding: padding,
        );
        final element = tester.element(find.text('custom ${slot.name}'));
        final style = DefaultTextStyle.of(element).style;
        final body = Theme.of(element).textTheme.bodyMedium!;
        expect(style.debugLabel, isNot(contains('fallback style')));
        expect(style.decoration, isNot(TextDecoration.underline));
        expect(style.fontSize, body.fontSize);
        expect(style.color, body.color);
        expectNoFallbackText(tester);
      });
    }

    // The standalone widgets bring their own transparent Material, so they
    // work in a bare route with no Scaffold.
    testWidgets('standalone tab bar and sidebar text outside a Material', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = kTabletLandscape;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiquidSidebar(
                destinations: kDestinations,
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                header: const Text('Header'),
                footer: const Text('Footer'),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LiquidTabBar(
                    destinations: [kDestinations[0], kDestinations[1]],
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
      expectNoFallbackText(tester);
    });

    test('LiquidChromeDetails ==', () {
      void select(int _) {}
      void expand() {}
      // One shared instance: LiquidChromeDetails == compares the callbacks.
      // The positional bool is the public callback's own signature
      // (`void Function(bool)`), which a test double cannot change.
      // ignore: avoid_positional_boolean_parameters
      void setVisible(bool _) {}
      LiquidChromeDetails details({
        LiquidChromeSlot slot = LiquidChromeSlot.tabBar,
        LiquidChromeKind kind = LiquidChromeKind.bottomBar,
        List<LiquidDestination> destinations = kDestinations,
        List<int> visible = const [0, 1, 3],
        int selected = 0,
        ValueChanged<int>? onSelect,
        LiquidTabAction? trailing,
        bool minimized = false,
        VoidCallback? onExpand,
        bool sidebarVisible = false,
        ValueSetter<bool>? onSetVisible,
        LiquidShellStrings strings = const LiquidShellStrings(),
      }) => LiquidChromeDetails(
        slot: slot,
        kind: kind,
        destinations: destinations,
        visibleIndices: visible,
        selectedIndex: selected,
        select: onSelect ?? select,
        trailing: trailing,
        minimized: minimized,
        expand: onExpand ?? expand,
        sidebarVisible: sidebarVisible,
        setSidebarVisible: onSetVisible ?? setVisible,
        strings: strings,
      );
      expect(details(), details());
      expect(details().hashCode, details().hashCode);
      expect(
        details(visible: [0, 1, 3]),
        details(),
        reason: 'lists compare by content',
      );
      final different = {
        'slot': details(slot: LiquidChromeSlot.sidebar),
        'kind': details(kind: LiquidChromeKind.topBar),
        'destinations': details(destinations: const []),
        'visibleIndices': details(visible: const [0, 1]),
        'selectedIndex': details(selected: 1),
        'select': details(onSelect: (_) {}),
        'trailing': details(
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: expand,
            semanticLabel: 'Search',
          ),
        ),
        'minimized': details(minimized: true),
        'expand': details(onExpand: () {}),
        'sidebarVisible': details(sidebarVisible: true),
        'setSidebarVisible': details(onSetVisible: (_) {}),
        'strings': details(strings: const LiquidShellStrings(badgeDot: 'x')),
      };
      for (final MapEntry(:key, :value) in different.entries) {
        expect(value, isNot(details()), reason: key);
      }
    });
  });
}

void unawaitedPush(NavigatorState navigator) {
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => const LiquidNoChrome(
          child: Scaffold(body: LiquidContentInset(child: Text('above'))),
        ),
      ),
    ),
  );
}

class _HideChromePage extends StatefulWidget {
  const _HideChromePage();

  @override
  State<_HideChromePage> createState() => _HideChromePageState();
}

class _HideChromePageState extends State<_HideChromePage> {
  bool first = false;
  bool second = false;

  void set({required bool first, required bool second}) => setState(() {
    this.first = first;
    this.second = second;
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('list-Home'),
    children: [
      if (first) const LiquidHideChrome(child: SizedBox(height: 1)),
      if (second) const LiquidHideChrome(child: SizedBox(height: 1)),
      const Text('probe'),
    ],
  );
}
