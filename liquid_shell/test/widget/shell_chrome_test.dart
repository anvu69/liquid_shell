import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
import 'package:liquid_shell/src/search/search_chrome.dart'
    show kSearchFieldKey;
import 'package:liquid_shell/src/shell/shell_layout.dart'
    show kTopBarGap, kTopPillExtent;
import 'package:liquid_shell/src/shell/shell_scope.dart';

import '../helpers/shell_harness.dart';

const _tablet = EdgeInsets.only(top: 24, bottom: 20);
const _searchDestinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

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
    }, variant: iosDevice);

    testWidgets('932×430 landscape phone with compactHeight 0 (P1) → top '
        'bar, sidebar overlays', (tester) async {
      await pumpShell(
        tester,
        const TestShell(breakpoints: LiquidShellBreakpoints(compactHeight: 0)),
        size: kPhoneLandscape,
        padding: const EdgeInsets.only(left: 59, right: 59, bottom: 21),
      );
      final scope = scopeOf(tester);
      expect(scope.sizeClass, LiquidSizeClass.regular);
      expect(scope.chromeKind, LiquidChromeKind.topBar);
      expect(
        scope.chromeInsets,
        const EdgeInsets.only(top: kTopBarGap + kTopPillExtent),
      );
      expect(find.byTooltip('Show sidebar'), findsOneWidget);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarOverlay);
      expect(find.byType(LiquidSidebar), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('landscape phone: the 44 pt bottom bar at margin 38 (VK-503 '
        'Q8)', (tester) async {
      await pumpShell(tester, const TestShell(), size: kPhoneLandscape);
      expect(scopeOf(tester).sizeClass, LiquidSizeClass.compact);
      final pill = tester.getRect(find.byKey(kTabPillKey));
      expect(pill.height, 44);
      expect(pill.left, greaterThanOrEqualTo(38));
    });

    testWidgets('the shell breakpoints pick the landscape form, not the '
        'window (compactHeight 600 at 1000×550)', (tester) async {
      await pumpShell(
        tester,
        const TestShell(
          breakpoints: LiquidShellBreakpoints(compactHeight: 600),
        ),
        size: const Size(1000, 550),
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(find.byType(LiquidTabBar), findsOneWidget);
      final pill = tester.getRect(find.byKey(kTabPillKey));
      expect(pill.height, 44);
      expect(pill.left, greaterThanOrEqualTo(38));
    });

    testWidgets('a compact landscape window at least compactHeight tall '
        'keeps the 62 pt bar (690×600, VK-503 Q8)', (tester) async {
      await pumpShell(tester, const TestShell(), size: const Size(690, 600));
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
      final pill = tester.getRect(find.byKey(kTabPillKey));
      expect(pill.height, 62);
      expect(scopeOf(tester).chromeInsets, const EdgeInsets.only(bottom: 83));
    }, variant: iosDevice);

    testWidgets('compactHeight 0 restores P1: a 690×430 shell keeps the '
        '62 pt bar at margin 21', (tester) async {
      await pumpShell(
        tester,
        TestShell(
          breakpoints: const LiquidShellBreakpoints(compactHeight: 0),
          // Start-pins the pill, so its left edge is the row margin.
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () {},
            semanticLabel: 'Search',
          ),
        ),
        size: const Size(690, 430),
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
      final pill = tester.getRect(find.byKey(kTabPillKey));
      expect(pill.height, 62);
      expect(pill.left, 21);
    });

    testWidgets('the measured bar height is kept per form: a rotation uses '
        'the right height on its first frame', (tester) async {
      await pumpShell(tester, const TestShell());
      expect(scopeOf(tester).chromeInsets.bottom, 62 + 21);
      // Before the landscape bar is measured: its own 44, not portrait's 62.
      tester.view.physicalSize = kPhoneLandscape;
      await tester.pump();
      expect(scopeOf(tester).chromeInsets.bottom, 44 + 21);
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeInsets.bottom, 44 + 21);
      // Back to portrait: the cached 62 at once, not landscape's 44.
      tester.view.physicalSize = kPhone;
      await tester.pump();
      expect(scopeOf(tester).chromeInsets.bottom, 62 + 21);
    }, variant: iosDevice);

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
      expect(
        scopeOf(tester).chromeInsets,
        const EdgeInsets.only(top: 24 + kTopBarGap + kTopPillExtent),
      );
      // The pill is centred; the toggle is a 48pt circle at
      // (20, pad.top + 5.5), centred on the 48pt row (spec VK-503 §12.2).
      expect(
        tester.getRect(find.byType(SidebarToggle)),
        const Rect.fromLTWH(20, 24 + kTopBarGap, 48, 48),
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
      // The slots' touch and semantics nodes (spec VK-503 §5.1).
      return [
        for (final label in labels.take(count)) tester.getRect(tabSlot(label)),
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

    testWidgets('320: 5 tabs + trailing keep 51.6pt slots with margin 8 and '
        'inset 4, tile the pill, and each tap selects its tab', (
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
      // Native slots (spec VK-503 §5.1): pitch 43.6, hit capsule 51.6.
      final home = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.startsWith('Home') ?? false),
        ),
      );
      expect(home.width, closeTo(51.6, 0.01));
      expect(home.width, greaterThanOrEqualTo(44));
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      // Neighbouring capsules overlap by 8, so the pill stays tiled.
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, moreOrLessEquals(rects[i - 1].right - 8));
      }
      expect(circle(tester).right, 312);
      for (final rect in rects) {
        await tester.tapAt(rect.center);
        await tester.pumpAndSettle();
      }
      expect(selections, [0, 1, 2, 3, 4]);
    });

    testWidgets('375: the regular margin 21 is kept; native slots', (
      tester,
    ) async {
      final rects = await cells(tester, 5, trailing: add, width: 375);
      expect(row(tester).left, 21);
      expect(row(tester).right, 375 - 21);
      expect(circle(tester).right, 375 - 21);
      // (375 − 42 − 70 − 16) / 5 + 8 (spec VK-503 §5.1).
      expect(rects.first.width, closeTo(57.4, 0.01));
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
      // (339 − 16 − 70 − 16) / 5 + 8.
      expect(rects.first.width, closeTo(55.4, 0.01));
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }

      rects = await cells(tester, 5, trailing: add, width: 340);
      expect(row(tester).left, 21);
      expect(row(tester).right, 340 - 21);
      // (340 − 42 − 70 − 16) / 5 + 8.
      expect(rects.first.width, closeTo(50.4, 0.01));
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('RTL at 320: mirrored, same margins, 51.6pt slots', (
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
        expect(rect.width, moreOrLessEquals(51.6, epsilon: 0.01));
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

    // VK-702 M2: the overlay is modal for the keyboard too.
    testWidgets('overlay: Tab stays in the sidebar; the page behind takes '
        'no focus until it closes', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      FocusNode page() => Focus.of(tester.element(find.text('Home page: 0')));
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(page().canRequestFocus, isFalse, reason: 'the page behind');
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          focused.findAncestorWidgetOfExactType<LiquidSidebar>(),
          isNotNull,
          reason: 'Tab ${i + 1}',
        );
      }
      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(page().canRequestFocus, isTrue, reason: 'closed');
    });

    group('with the search tab selected', () {
      Future<LiquidSearchController> pumpSearch(WidgetTester tester) async {
        final controller = LiquidSearchController();
        addTearDown(controller.dispose);
        await pumpShell(
          tester,
          TestShell(
            destinations: _searchDestinations,
            initialIndex: 1,
            search: LiquidSearch(controller: controller),
          ),
          size: kTabletPortrait,
          padding: _tablet,
        );
        return controller;
      }

      testWidgets('overlay: Tab does not reach the idle search field', (
        tester,
      ) async {
        final controller = await pumpSearch(tester);
        expect(
          scopeOf(tester, 'Search').searchPhase,
          LiquidSearchPhase.selected,
        );
        await tester.tap(find.byTooltip('Show sidebar'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus!.context!;
          expect(
            focused.findAncestorWidgetOfExactType<LiquidSidebar>(),
            isNotNull,
            reason:
                'Tab ${i + 1}: ${focused.widget}, active: '
                '${controller.isActive}',
          );
        }
        expect(controller.isActive, isFalse);
      });

      testWidgets('overlay: Escape in the active search field ends the '
          'search and leaves the sidebar open', (tester) async {
        final controller = await pumpSearch(tester);
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(controller.isActive, isTrue);
        scopeOf(tester, 'Search').setSidebarVisible(true);
        await tester.pumpAndSettle();
        expect(controller.isActive, isTrue, reason: 'VK-774');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.isActive, isFalse);
        expect(find.byType(LiquidSidebar), findsOne);
      });

      // VK-778: the shell's own field never gets focus back. Focusing it
      // idle starts a search, so a search ended under the overlay would
      // start again when the overlay closes.
      testWidgets('overlay: a search ended under it stays ended when it '
          'closes', (tester) async {
        final controller = await pumpSearch(tester);
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        scopeOf(tester, 'Search').setSidebarVisible(true);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.isActive, isFalse, reason: 'the field ended it');
        await tester.tapAt(const Offset(800, 600));
        await tester.pumpAndSettle();
        expect(find.byType(LiquidSidebar), findsNothing);
        expect(controller.isActive, isFalse);
      });
    });

    // VK-702: the overlay's Escape handler wraps the whole shell; with
    // semantics it merged the compact search field into a node the size of
    // the shell, and XCUITest's tap at its centre missed the field.
    testWidgets('the Escape handler adds no semantics node: the compact '
        "search field's node is its text input, inside the drawn field", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: _searchDestinations,
          initialIndex: 1,
          search: LiquidSearch(controller: controller),
        ),
      );
      expect(find.byType(LiquidSidebar), findsNothing);
      final node = tester.getSemantics(find.byType(TextField));
      var rect = node.rect;
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        if (n.transform != null) {
          rect = MatrixUtils.transformRect(n.transform!, rect);
        }
      }
      expect(rect, tester.getRect(find.byType(EditableText)));
      final field = tester.getRect(find.byKey(kSearchFieldKey));
      expect(field.expandToInclude(rect), field, reason: 'inside $field');
      handle.dispose();
    });

    testWidgets('overlay: Escape closes it', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);
    });

    // VK-778: the open overlay takes focus from the page and the top bar
    // (VK-702 M2). Closing it gives focus back to the node that held it,
    // but not after a destination is chosen: the page changes.
    group('focus returns when the overlay closes (VK-778)', () {
      Future<FocusNode> focusThenOpen(WidgetTester tester) async {
        final node = Focus.of(tester.element(find.text('Home page: 0')))
          ..requestFocus();
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue, reason: 'precondition');
        scopeOf(tester).setSidebarVisible(true);
        await tester.pumpAndSettle();
        expect(node.hasFocus, isFalse, reason: 'the overlay is modal');
        return node;
      }

      final closers = <String, Future<void> Function(WidgetTester)>{
        'Escape': (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        'the barrier': (tester) => tester.tapAt(const Offset(800, 600)),
        'Hide': (tester) => tester.tap(find.byTooltip('Hide sidebar')),
        'system back': (tester) => tester.binding.handlePopRoute(),
      };
      for (final MapEntry(key: how, value: close) in closers.entries) {
        testWidgets('closed by $how: the node that held focus has it again', (
          tester,
        ) async {
          await pumpShell(
            tester,
            const TestShell(),
            size: kTabletPortrait,
            padding: _tablet,
          );
          final node = await focusThenOpen(tester);
          await close(tester);
          await tester.pumpAndSettle();
          expect(find.byType(LiquidSidebar), findsNothing);
          expect(FocusManager.instance.primaryFocus, same(node));
        });
      }

      // Vietnamese IME rule: focus moves, nothing else. The field is not
      // rebuilt and nothing is written into it.
      testWidgets('a text field has focus again, not rebuilt or written to', (
        tester,
      ) async {
        final text = TextEditingController(text: 'phở');
        addTearDown(text.dispose);
        var builds = 0;
        await pumpShell(
          tester,
          TestShell(
            pageBuilder: (i) => i == 0
                ? Builder(
                    builder: (context) {
                      builds++;
                      return Material(
                        child: Center(child: TextField(controller: text)),
                      );
                    },
                  )
                : TestPage(label: kDestinations[i].label),
          ),
          size: kTabletPortrait,
          padding: _tablet,
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        final field = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final node = field.widget.focusNode;
        expect(node.hasPrimaryFocus, isTrue, reason: 'precondition');
        LiquidShellScope.of(
          tester.element(find.byType(TextField)),
        ).setSidebarVisible(true);
        await tester.pumpAndSettle();
        expect(node.hasFocus, isFalse, reason: 'the overlay is modal');
        final value = text.value;
        final built = builds;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(node));
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(field),
        );
        expect(text.value, value);
        expect(builds, built);
      });

      testWidgets('a destination chosen in the overlay: the page left behind '
          'gets no focus', (tester) async {
        await pumpShell(
          tester,
          // Offstage branches stay focusable: focus given back would land
          // in a hidden page.
          const TestShell(offstageBranches: true),
          size: kTabletPortrait,
          padding: _tablet,
        );
        final node = await focusThenOpen(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(LiquidSidebar),
            matching: find.text('Inbox'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiquidSidebar), findsNothing);
        expect(find.text('Inbox page: 0'), findsOne);
        expect(node.hasFocus, isFalse);
      });

      // Asked while out of the tree, a node takes focus whenever it comes
      // back (FocusNode defers the request).
      testWidgets('a node that left the tree while the overlay was open '
          'takes no focus when it comes back', (tester) async {
        final node = FocusNode(debugLabel: 'app node');
        addTearDown(node.dispose);
        final shown = ValueNotifier(true);
        addTearDown(shown.dispose);
        await pumpShell(
          tester,
          TestShell(
            pageBuilder: (i) => i == 0
                ? ValueListenableBuilder<bool>(
                    valueListenable: shown,
                    builder: (context, on, _) => on
                        ? Focus(focusNode: node, child: const Text('node'))
                        : const SizedBox(),
                  )
                : TestPage(label: kDestinations[i].label),
          ),
          size: kTabletPortrait,
          padding: _tablet,
        );
        node.requestFocus();
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue, reason: 'precondition');
        LiquidShellScope.of(
          tester.element(find.text('node')),
        ).setSidebarVisible(true);
        await tester.pumpAndSettle();
        shown.value = false;
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(LiquidSidebar), findsNothing);
        shown.value = true;
        await tester.pumpAndSettle();
        expect(node.hasFocus, isFalse);
      });
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

    group('setSidebarVisible while a page builds applies after the frame', () {
      final pages = <String, Widget Function()>{
        'initState': () => Builder(
          builder: (context) => _HidesSidebarInInitState(
            setSidebarVisible: LiquidShellScope.of(context).setSidebarVisible,
          ),
        ),
        'didChangeDependencies': () => const _HidesSidebarOnDependencies(),
        'build': () => Builder(
          builder: (context) {
            LiquidShellScope.of(context).setSidebarVisible(false);
            return const TestPage(label: 'Home');
          },
        ),
      };
      for (final MapEntry(key: where, value: page) in pages.entries) {
        testWidgets('from $where', (tester) async {
          await pumpShell(
            tester,
            TestShell(
              pageBuilder: (i) =>
                  i == 0 ? page() : TestPage(label: kDestinations[i].label),
            ),
            size: kTabletLandscape,
            padding: _tablet,
            settle: false,
          );
          expect(tester.takeException(), isNull);
          expect(
            scopeOf(tester).chromeKind,
            LiquidChromeKind.sidebarTiled,
            reason: 'not during the frame that asked',
          );

          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
          await tester.pumpAndSettle();
          expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
        });
      }
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
        const Rect.fromLTWH(834 - 20 - 48, 24 + kTopBarGap, 48, 48),
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

    // VK-702 M1: the device decides, not an app's ThemeData.platform.
    testWidgets(
      'an Android device themed as iOS: max(21, padding + 8)',
      (
        tester,
      ) async {
        await pumpShell(
          tester,
          const TestShell(),
          size: const Size(412, 915),
          padding: const EdgeInsets.only(top: 24, bottom: 48),
        );
        expect(scopeOf(tester).chromeInsets.bottom, 62 + 56);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('an iPhone themed as Android: 21', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        platform: TargetPlatform.android,
      );
      expect(scopeOf(tester).chromeInsets.bottom, 62 + 21);
    }, variant: iosDevice);
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
        navigator.currentState!
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const LiquidHideChrome(child: Text('detail')),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        expect(find.byType(LiquidTabBar), findsNothing);

        navigator.currentState!
            .push(
              MaterialPageRoute<void>(builder: (_) => const Text('above')),
            )
            .ignore();
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
    }, variant: iosDevice);

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
    }, variant: iosDevice);

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

  // VK-702 M10: a landscape phone's notch; the bars keep to the safe width.
  group('side safe area (VK-702)', () {
    const notchLeft = EdgeInsets.only(left: 59, bottom: 21);
    Rect pill(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(LiquidTabBar),
        matching: find.byType(LiquidGlass),
      ),
    );

    testWidgets('landscape bottom bar: centred between the insets', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kPhoneLandscape,
        padding: notchLeft,
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(pill(tester).center.dx, (59 + 932) / 2);
    });

    testWidgets('landscape top bar (compactHeight 0): centred between the '
        'insets', (tester) async {
      await pumpShell(
        tester,
        const TestShell(breakpoints: LiquidShellBreakpoints(compactHeight: 0)),
        size: kPhoneLandscape,
        padding: notchLeft,
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
      expect(pill(tester).center.dx, (59 + 932) / 2);
    });

    testWidgets('landscape top bar (compactHeight 0): clears the right '
        'inset', (tester) async {
      await pumpShell(
        tester,
        const TestShell(breakpoints: LiquidShellBreakpoints(compactHeight: 0)),
        size: kPhoneLandscape,
        padding: const EdgeInsets.only(right: 59, bottom: 21),
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
      expect(pill(tester).center.dx, (932 - 59) / 2);
    });

    Future<void> pumpSearchRow(WidgetTester tester, EdgeInsets padding) async {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: _searchDestinations,
          search: LiquidSearch(controller: controller),
        ),
        size: kPhoneLandscape,
        padding: padding,
      );
    }

    testWidgets('landscape search row: the ⌕ clears the right inset', (
      tester,
    ) async {
      await pumpSearchRow(tester, const EdgeInsets.only(right: 59, bottom: 21));
      final idle = tester.getRect(find.byKey(kSearchFieldKey));
      expect(idle.right, lessThanOrEqualTo(932 - 59));
    });

    testWidgets('landscape search row, left inset: the ⌕ keeps the right '
        'edge, and a drag onto it hovers it', (tester) async {
      await pumpSearchRow(tester, const EdgeInsets.only(bottom: 21));
      final noInset = tester.getRect(find.byKey(kSearchFieldKey));
      await pumpSearchRow(tester, notchLeft);
      final idle = tester.getRect(find.byKey(kSearchFieldKey));
      expect(idle, noInset, reason: 'laid out in the safe width, then moved');
      // The drop target is the ⌕ as drawn.
      final g = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Home')),
      );
      await g.moveTo(idle.center);
      await tester.pump(const Duration(milliseconds: 100));
      final hovered = tester
          .widget<TabHoverHighlight>(
            find.descendant(
              of: find.byKey(kSearchFieldKey),
              matching: find.byType(TabHoverHighlight),
            ),
          )
          .hovered
          .value;
      expect(hovered, isTrue);
      await g.cancel();
    });
  });
}

void unawaitedPush(NavigatorState navigator) {
  navigator
      .push(
        MaterialPageRoute<void>(
          builder: (context) => const LiquidNoChrome(
            child: Scaffold(body: LiquidContentInset(child: Text('above'))),
          ),
        ),
      )
      .ignore();
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

/// Hides the sidebar from `initState`, with a setter read by its parent.
class _HidesSidebarInInitState extends StatefulWidget {
  const _HidesSidebarInInitState({required this.setSidebarVisible});

  final ValueSetter<bool> setSidebarVisible;

  @override
  State<_HidesSidebarInInitState> createState() =>
      _HidesSidebarInInitStateState();
}

class _HidesSidebarInInitStateState extends State<_HidesSidebarInInitState> {
  @override
  void initState() {
    super.initState();
    widget.setSidebarVisible(false);
  }

  @override
  Widget build(BuildContext context) => const TestPage(label: 'Home');
}

/// Hides the sidebar once it can read the scope.
class _HidesSidebarOnDependencies extends StatefulWidget {
  const _HidesSidebarOnDependencies();

  @override
  State<_HidesSidebarOnDependencies> createState() =>
      _HidesSidebarOnDependenciesState();
}

class _HidesSidebarOnDependenciesState
    extends State<_HidesSidebarOnDependencies> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = LiquidShellScope.of(context);
    if (_asked) return;
    _asked = true;
    scope.setSidebarVisible(false);
  }

  @override
  Widget build(BuildContext context) => const TestPage(label: 'Home');
}
