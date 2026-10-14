import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/cases/segments.dart';
import 'package:liquid_shell_example/main.dart';
import 'package:liquid_shell_example/support/demo_page.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';

import 'support/installed_native.dart';

/// The destination labels of the only [LiquidShell] on screen.
List<String> shellLabels(WidgetTester tester) => [
  for (final d
      in tester.widget<LiquidShell>(find.byType(LiquidShell)).destinations)
    d.label,
];

const _sizes = {'phone': Size(393, 852), 'tablet': Size(1194, 834)};

Future<void> _openCase(WidgetTester tester, String id) async {
  await tester.pumpWidget(const ExampleApp());
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final entry in kCases) {
      testWidgets('${entry.id} on a $sizeName opens without errors', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        await _openCase(tester, entry.id);
        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is LiquidShell ||
                w is LiquidTabBar ||
                w is LiquidSidebar ||
                w is LiquidSegmentedControl,
          ),
          findsWidgets,
        );
      });
    }
  }

  group('segments (spec VK-550 §13)', () {
    Future<void> open(WidgetTester tester) async {
      // The reference screen's device: an iPhone 17 Pro.
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await _openCase(tester, 'segments');
    }

    testWidgets('five controls at the native reference frames; a tap on '
        'Songs selects it', (tester) async {
      await open(tester);
      expect(find.byType(LiquidSegmentedControl), findsNWidgets(5));
      // UIKit puts each 32 pt control's top at trackTop; the Flutter track
      // is on the same line, in the middle of its 44 pt box.
      for (final row in kSegmentsRows) {
        final control = tester.widget<LiquidSegmentedControl>(
          _control(row.id),
        );
        expect([for (final s in control.segments) s.label], row.labels);
        expect(control.onChanged != null, row.enabled, reason: row.id);
        expect(control.expand, row.fullWidth, reason: row.id);
        final box = tester.getRect(_segments(row.id));
        expect(box.height, 44, reason: row.id);
        expect(box.center.dy, row.trackTop + 16, reason: row.id);
        if (row.fullWidth) {
          expect(box.left, 16, reason: row.id);
          expect(box.right, 402 - 16, reason: row.id);
        } else {
          expect(box.center.dx, 201, reason: row.id);
          expect(box.width, lessThan(402 - 32), reason: row.id);
        }
      }
      await tester.tap(_segment('full3', 'Songs'));
      await tester.pumpAndSettle();
      expect(_selectedOf(tester, 'full3'), 1);
      expect(_selectedOf(tester, 'intrinsic3'), 0, reason: 'its own index');
    });

    testWidgets('the disabled control ignores a tap', (tester) async {
      await open(tester);
      final disabled = tester.widget<LiquidSegmentedControl>(
        _control('disabled3'),
      );
      expect(disabled.onChanged, isNull);
      await tester.tap(_segment('disabled3', 'Songs'));
      await tester.pumpAndSettle();
      expect(_selectedOf(tester, 'disabled3'), 0);
    });

    testWidgets('right to left puts segment 0 at the right', (tester) async {
      await open(tester);
      double centreOf(String label) =>
          tester.getCenter(_segment('full3', label)).dx;
      expect(centreOf('All'), lessThan(centreOf('Places')));
      await _tapPanel(tester, kSegmentsRtlKey);
      expect(centreOf('All'), greaterThan(centreOf('Places')));
      expect(tester.getRect(_segments('full3')).left, 16, reason: 'frame');
    });

    testWidgets('text ×2 grows the controls, centred on the same line', (
      tester,
    ) async {
      await open(tester);
      await _tapPanel(tester, kSegmentsLargeTextKey);
      for (final row in kSegmentsRows) {
        final box = tester.getRect(_segments(row.id));
        expect(box.height, greaterThan(44), reason: row.id);
        expect(box.center.dy, row.trackTop + 16, reason: row.id);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });

    testWidgets('Next selects the next segment from code, without '
        'onChanged', (tester) async {
      await open(tester);
      for (final expected in [1, 2, 0]) {
        await _tapPanel(tester, kSegmentsNextKey);
        expect(_selectedOf(tester, 'full3'), expected);
      }
    });
  });

  testWidgets('the guard asks before leaving dirty edits', (tester) async {
    await _openCase(tester, 'guard');
    await tester.tap(_slot('Explore', within: find.byType(LiquidTabBar)));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('the guard moves on and clears the edits after "Discard"', (
    tester,
  ) async {
    await _openCase(tester, 'guard');
    await tester.tap(_slot('Explore', within: find.byType(LiquidTabBar)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Explore item 1'), findsOneWidget);
    expect(find.text('Home item 1'), findsNothing);

    // The edits are gone, so the next change does not ask again.
    final dirty = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(dirty.value, isFalse);
    await tester.tap(_slot('Home', within: find.byType(LiquidTabBar)));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('the detail page hides the chrome', (tester) async {
    await _openCase(tester, 'hide_chrome');
    await tester.tap(find.text('Open a full-frame detail page'));
    await tester.pumpAndSettle();
    expect(find.text('Detail item 1'), findsOneWidget);
    // Offstage too: a page pushed above the shell would only cover the bar.
    expect(find.byType(LiquidTabBar, skipOffstage: false), findsNothing);
    final detail = tester.element(find.text('Detail item 1'));
    expect(LiquidShellScope.of(detail).chromeKind, LiquidChromeKind.hidden);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('trailing compose opens a page with no chrome', (tester) async {
    await _openCase(tester, 'trailing');
    await tester.tap(find.byTooltip('Compose'));
    await tester.pumpAndSettle();
    final field = tester.element(find.byType(TextField));
    expect(LiquidShellScope.of(field), LiquidShellScopeData.none());
  });

  testWidgets('narrow: the trailing compose opens a page with no chrome', (
    tester,
  ) async {
    await _openCase(tester, 'narrow');
    await tester.tap(find.byTooltip('Compose'));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);
    final field = tester.element(find.byType(TextField));
    expect(LiquidShellScope.of(field), LiquidShellScopeData.none());
  });

  testWidgets('a sidebar-only selection falls back to the first tab on a '
      'phone', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(834, 1194);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'sidebar_only');
    await tester.tap(find.byTooltip('Show sidebar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Destination 4'), findsOneWidget);

    tester.view.physicalSize = const Size(393, 852);
    await tester.pumpAndSettle();
    expect(find.text('Destination 1'), findsOneWidget);
  });

  testWidgets('the replacement sidebar leaves the primary scroll controller '
      'to the body', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1194, 834);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'custom_chrome');
    // A list that takes the route's controller hides it from its own
    // descendants, so ask from above both lists.
    final route = tester.element(find.byType(LiquidShell));
    // Tiled: the body list and the custom sidebar list sit side by side; a
    // status-bar tap must scroll the body only.
    expect(find.text('Home item 1'), findsOneWidget);
    expect(PrimaryScrollController.of(route).positions, hasLength(1));
  });

  testWidgets('narrow: 5 tabs + trailing in a 320pt shell keep 44pt cells at '
      'text scale 1 (Q17)', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'narrow');
    expect(tester.takeException(), isNull, reason: 'no overflow');

    final shell = tester.getRect(find.byType(LiquidShell));
    expect(shell.width, 320);
    final bar = find.byType(LiquidTabBar);
    // The slots' touch and semantics nodes.
    final cells = [
      for (final label in shellLabels(tester))
        tester.getRect(_slot(label, within: bar)),
    ];
    expect(cells, hasLength(5));
    // Native slots (spec VK-503 §5.1): pitch (320 − 2×8 margin − 62 circle −
    // 8 gap − 2×4 inset − 8 overlap) / 5 = 43.6, hit capsule 43.6 + 8.
    for (final cell in cells) {
      expect(cell.width, moreOrLessEquals(51.6, epsilon: 0.01));
      expect(cell.width, greaterThanOrEqualTo(44));
    }
    // The narrow row margin is 8 on both sides of the shell, not the screen.
    expect(cells.first.left - shell.left, 8 + 4);
    final circle = tester.getRect(
      find.ancestor(
        of: find.descendant(
          of: bar,
          matching: find.byIcon(Icons.edit_outlined),
        ),
        matching: find.byType(LiquidGlass),
      ),
    );
    expect(shell.right - circle.right, 8);
  });

  testWidgets('standalone: a phone gets a LiquidTabBar in your own Scaffold', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'standalone');
    expect(find.byType(LiquidShell), findsNothing);
    expect(find.byType(LiquidSidebar), findsNothing);
    expect(find.byType(LiquidTabBar), findsOneWidget);
    await tester.tap(_slot('Explore', within: find.byType(LiquidTabBar)));
    await tester.pumpAndSettle();
    expect(find.text('Explore item 1'), findsOneWidget);
  });

  // Owner E1 (spec P2 §15): on iOS 26 every case with a real shell runs
  // native; the Flutter-by-nature cases keep the Flutter chrome and say why.
  const nativeIds = {
    'basic',
    'badges',
    'sidebar_only',
    'sidebar_slots',
    'trailing',
    'guard',
    'alerts',
    'hide_chrome',
    'native_chrome',
    'search',
  };
  const flutterIds = {
    'custom_chrome',
    'custom_theme',
    'forced_tier',
    'form_factors',
    'narrow',
    'standalone',
    'segments',
  };

  test('every case is either native or Flutter by nature', () {
    expect({...nativeIds, ...flutterIds}, {for (final c in kCases) c.id});
    expect(nativeIds.intersection(flutterIds), isEmpty);
  });

  group('on iOS 26 with native chrome installed', () {
    for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
      for (final id in nativeIds) {
        testWidgets('$id on a $sizeName draws native chrome', (tester) async {
          installNative();
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = size;
          addTearDown(tester.view.reset);
          // Every native case is describable: the missing-symbol hint
          // stays quiet.
          final logs = <String>[];
          final original = debugPrint;
          debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
          addTearDown(() => debugPrint = original);
          await _openCase(tester, id);
          debugPrint = original;
          expect(logs.where((l) => l.contains('sfSymbol')), isEmpty);
          expect(tester.takeException(), isNull);
          // The search case's pages are LiquidPages, not DemoPages.
          final page = tester.element(
            find
                .byWidgetPredicate((w) => w is DemoPage || w is LiquidPage)
                .first,
          );
          expect(LiquidShellScope.of(page).nativeChrome, isTrue);
          expect(find.byType(LiquidTabBar), findsNothing);
          expect(find.byType(LiquidSidebar), findsNothing);
          expect(find.text(kDrawnByFlutter), findsNothing);
        });
      }

      for (final id in flutterIds) {
        testWidgets('$id on a $sizeName keeps the Flutter chrome and says '
            'why', (tester) async {
          installNative();
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = size;
          addTearDown(tester.view.reset);
          await _openCase(tester, id);
          expect(tester.takeException(), isNull);
          // Every shell draws its Flutter chrome: none waits for native
          // (hidden) or hands it over. The segments case has no shell.
          final pages = find
              .byWidgetPredicate((w) => w is DemoPage || w is SegmentsCase)
              .evaluate();
          expect(pages, isNotEmpty);
          for (final page in pages) {
            final scope = LiquidShellScope.maybeOf(page);
            if (scope == null) continue; // standalone: no shell
            expect(scope.nativeChrome, isFalse);
            expect(scope.chromeKind, isNot(LiquidChromeKind.hidden));
          }
          expect(find.text(kDrawnByFlutter), findsOneWidget);
        });
      }
    }
  });

  testWidgets('native_chrome has a native footer; off iOS 26 the trailing '
      'action counts', (tester) async {
    await _openCase(tester, 'native_chrome');
    final shell = tester.widget<LiquidShell>(find.byType(LiquidShell));
    expect(shell.nativeSidebarFooter, isNotNull);
    await tester.tap(find.byTooltip('Compose'));
    await tester.pumpAndSettle();
    expect(find.text('Drafts: 1'), findsOneWidget);
  });

  testWidgets('native_chrome guards dirty edits: keep stays, discard leaves', (
    tester,
  ) async {
    await _openCase(tester, 'native_chrome');
    final shell = tester.widget<LiquidShell>(find.byType(LiquidShell));
    expect(shell.beforeDestinationChange, isNotNull);

    // Clean: no question.
    await tester.tap(find.text('Inbox').first);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(tester.widget<DemoPage>(find.byType(DemoPage)).title, 'Inbox');

    await tester.tap(find.text('Unsaved changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(tester.widget<DemoPage>(find.byType(DemoPage)).title, 'Inbox');

    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(tester.widget<DemoPage>(find.byType(DemoPage)).title, 'Home');
  });

  testWidgets(
    'standalone: a wide window gets a LiquidSidebar beside the page',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1194, 834);
      addTearDown(tester.view.reset);
      await _openCase(tester, 'standalone');
      expect(find.byType(LiquidShell), findsNothing);
      expect(find.byType(LiquidTabBar), findsNothing);
      final sidebar = tester.getRect(find.byType(LiquidSidebar));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final page = tester.getRect(find.text('Settings item 1'));
      expect(page.left, greaterThanOrEqualTo(sidebar.right));
    },
  );

  testWidgets('the alerts case answers through the Flutter glass alert', (
    tester,
  ) async {
    await _openCase(tester, 'alerts');
    await tester.tap(find.text('Alert'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Result: discard'), findsOneWidget);
  });

  testWidgets('a tap outside the action sheet answers its cancel value', (
    tester,
  ) async {
    await _openCase(tester, 'alerts');
    await tester.tap(find.text('Action sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Delete photo'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Result: cancel'), findsOneWidget);
  });

  testWidgets('every case destination has a filled selectedIcon (spec '
      'VK-503 §14)', (tester) async {
    for (final entry in kCases) {
      await tester.pumpWidget(MaterialApp(home: entry.page));
      await tester.pump();
      final shells = tester.widgetList<LiquidShell>(find.byType(LiquidShell));
      for (final shell in shells) {
        for (final d in shell.destinations) {
          if (d.role == LiquidDestinationRole.search) continue;
          expect(
            d.selectedIcon,
            isNotNull,
            reason: '${entry.id}: ${d.label} needs a filled selectedIcon',
          );
        }
      }
    }
  });

  testWidgets('autorun shows the alert by itself, then the result', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp(demo: 'alert'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Result: keep'), findsWidgets);
  });
}

/// The segments case's control [id] (`kSegmentsRows`), by its frame.
Finder _segments(String id) => find.byKey(ValueKey('segments-$id'));

/// The [LiquidSegmentedControl] of [_segments].
Finder _control(String id) => find.descendant(
  of: _segments(id),
  matching: find.byType(LiquidSegmentedControl),
);

int? _selectedOf(WidgetTester tester, String id) =>
    tester.widget<LiquidSegmentedControl>(_control(id)).selectedIndex;

/// The segment [label] of control [id]: its touch and semantics node (the
/// label is drawn once per weight).
Finder _segment(String id, String label) =>
    find.descendant(of: _segments(id), matching: find.bySemanticsLabel(label));

/// Taps the segments case's panel control [key], scrolled into view.
Future<void> _tapPanel(WidgetTester tester, Key key) async {
  final control = find.byKey(key);
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

/// The touch and semantics node of the tab labelled [label] in [within]:
/// the drawn row ignores pointers and draws each label twice (spec VK-503
/// §6.3).
Finder _slot(String label, {required Finder within}) => find.descendant(
  of: within,
  matching: find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.button == true &&
        (w.properties.label?.startsWith(label) ?? false),
  ),
);
