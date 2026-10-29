import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/search/search_chrome.dart';

import '../helpers/shell_harness.dart';

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.library_music), label: 'Library'),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

// kPhone is 393 × 852; the row bottom is 852 − 21.
const double _rowBottom = 852.0 - 21;

Future<LiquidSearchController> _pump(
  WidgetTester tester, {
  Widget Function(int index)? pageBuilder,
}) async {
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      pageBuilder: pageBuilder,
      search: LiquidSearch(controller: controller),
    ),
  );
  return controller;
}

/// Whether the idle ⌕ shows the lens hover.
bool _hovered(WidgetTester tester) => tester
    .widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kSearchFieldKey),
        matching: find.byType(TabHoverHighlight),
      ),
    )
    .hovered
    .value;

/// A lens drag from Home that is now over the ⌕.
Future<TestGesture> _hoverSearch(WidgetTester tester) async {
  final g = await tester.startGesture(
    tester.getCenter(find.bySemanticsLabel('Home')),
  );
  await g.moveTo(tester.getCenter(find.byKey(kSearchFieldKey)));
  await tester.pump(const Duration(milliseconds: 100));
  expect(_hovered(tester), isTrue);
  return g;
}

/// The colour the bar draws its collapsed circle's icon in.
Color? _collapsedIconColor(WidgetTester tester) {
  final icon = find.descendant(
    of: find.byType(GlassTabBar),
    matching: find.byIcon(Icons.home),
  );
  expect(icon, findsOneWidget);
  return IconTheme.of(tester.element(icon)).color;
}

void main() {
  testWidgets('idle: pill pinned at 21, ⌕ circle at the end', (tester) async {
    await _pump(tester);
    expect(tester.getRect(find.byKey(kTabPillKey)).left, 21);
    expect(
      tester.getRect(find.byKey(kSearchFieldKey)),
      const Rect.fromLTWH(393 - 21 - 62, _rowBottom - 62, 62, 62),
    );
  }, variant: iosDevice);

  testWidgets(
    'selected: the bar itself collapses to the 48 circle at 28',
    (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();
      final circle = tester.getRect(find.byKey(kSearchCollapsedKey));
      expect(circle, const Rect.fromLTWH(28, _rowBottom - 55, 48, 48));
      expect(tester.getRect(find.byKey(kTabPillKey)), circle);
      expect(
        find.descendant(
          of: find.byKey(kSearchCollapsedKey),
          matching: find.bySemanticsLabel('Home'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(kSearchCollapsedKey));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(kTabPillKey)).height, 62);
    },
    variant: iosDevice,
  );

  testWidgets('drag from Home onto ⌕: highlight, release selects search', (
    tester,
  ) async {
    await _pump(tester);
    final home = tester.getCenter(find.bySemanticsLabel('Home'));
    final search = tester.getCenter(find.byKey(kSearchFieldKey));
    final g = await tester.startGesture(home);
    await g.moveTo(search);
    await tester.pump(const Duration(milliseconds: 100));
    final highlight = tester.widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kSearchFieldKey),
        matching: find.byType(TabHoverHighlight),
      ),
    );
    expect(highlight.hovered.value, isTrue);
    await g.up();
    await tester.pumpAndSettle();
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
  });

  testWidgets('a selection mid-hover lets go of the ⌕ highlight', (
    tester,
  ) async {
    await _pump(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Home')),
    );
    await g.moveTo(tester.getCenter(find.byKey(kSearchFieldKey)));
    await tester.pump(const Duration(milliseconds: 100));
    // The app selects search while the finger is still over the ⌕.
    tester.state<TestShellState>(find.byType(TestShell)).select(2);
    await tester.pumpAndSettle();
    tester.state<TestShellState>(find.byType(TestShell)).select(0);
    await tester.pumpAndSettle();
    final highlight = tester.widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kSearchFieldKey),
        matching: find.byType(TabHoverHighlight),
      ),
    );
    expect(highlight.hovered.value, isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(
      scopeOf(tester).searchPhase,
      LiquidSearchPhase.idle,
      reason: 'the late release neither selects search nor commits',
    );
    expect(tester.state<TestShellState>(find.byType(TestShell)).index, 0);
  });

  testWidgets('the bar leaving the tree mid-drag lets go of the highlight', (
    tester,
  ) async {
    final hide = ValueNotifier(false);
    addTearDown(hide.dispose);
    await _pump(
      tester,
      pageBuilder: (i) => i == 0
          ? ValueListenableBuilder<bool>(
              valueListenable: hide,
              builder: (_, hidden, child) =>
                  LiquidHideChrome(enabled: hidden, child: child!),
              child: const TestPage(label: 'Home'),
            )
          : TestPage(label: _destinations[i].label),
    );
    final g = await _hoverSearch(tester);
    hide.value = true;
    await tester.pumpAndSettle();
    hide.value = false;
    await tester.pumpAndSettle();
    expect(_hovered(tester), isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(scopeOf(tester).searchPhase, LiquidSearchPhase.idle);
  });

  testWidgets('a second finger scrolling while the lens hovers the ⌕', (
    tester,
  ) async {
    await _pump(tester);
    final g = await _hoverSearch(tester);
    // The scroll minimizes the idle bar, which cancels the lens.
    final scroll = await tester.startGesture(const Offset(200, 400));
    for (var i = 0; i < 6; i++) {
      await scroll.moveBy(const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await scroll.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlassTabBar>(find.byType(GlassTabBar)).minimized,
      true,
    );
    expect(_hovered(tester), isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(scopeOf(tester).searchPhase, LiquidSearchPhase.idle);
  });

  testWidgets('selected: the collapsed circle draws the previous tab '
      'untinted', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    expect(
      _collapsedIconColor(tester),
      LiquidGlassTheme.of(
        tester.element(find.byType(GlassTabBar)),
      ).tabForeground,
    );
  });

  testWidgets('idle, scroll-minimized: the circle keeps the current tab '
      'tinted', (tester) async {
    await _pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('list-Home')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      _collapsedIconColor(tester),
      Theme.of(tester.element(find.byType(GlassTabBar))).colorScheme.primary,
    );
  });

  // VK-503 Task 16: native shrinks the field into the ⌕ in step with the
  // pill growing back (search_close strip: both 0.55 → 0.69 → 0.86 → 0.99
  // of the way, row by row). The field ran on its own 350 ms ease and the
  // bar on the expand spring, so the ⌕ led early and then trailed as an
  // elongated capsule for 4 to 6 frames.
  for (final (name, closing) in [('close', true), ('open', false)]) {
    testWidgets('search $name: the field and the bar move on one clock', (
      tester,
    ) async {
      await _pump(tester);
      final idlePill = tester.getRect(find.byKey(kTabPillKey));
      final idleField = tester.getRect(find.byKey(kSearchFieldKey));
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();
      final circle = tester.getRect(find.byKey(kTabPillKey));
      final selectedField = tester.getRect(find.byKey(kSearchFieldKey));
      if (closing) {
        await tester.tap(find.byKey(kSearchCollapsedKey));
      } else {
        // Back to idle first, then open again from there.
        await tester.tap(find.byKey(kSearchCollapsedKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(kSearchFieldKey));
      }
      final (fieldFrom, fieldTo) = closing
          ? (selectedField, idleField)
          : (idleField, selectedField);
      final (barFrom, barTo) = closing
          ? (circle, idlePill)
          : (idlePill, circle);
      for (var f = 0; f < 30; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        final bar = tester.getRect(find.byKey(kTabPillKey));
        final field = tester.getRect(find.byKey(kSearchFieldKey));
        final barDone =
            (bar.width - barFrom.width) / (barTo.width - barFrom.width);
        final fieldDone =
            (field.width - fieldFrom.width) / (fieldTo.width - fieldFrom.width);
        // 0.06: the bar's ×0.96 dip (spec §10) scales its glass too.
        expect(
          fieldDone,
          closeTo(barDone, 0.06),
          reason: 'frame $f: bar $barDone, field $fieldDone',
        );
      }
    });
  }

  // VK-779: in compact landscape the idle ⌕ is as wide as the 44 bar is
  // tall, and the field's Row has 56 of fixed parts (14 + 20 + 8 + 14).
  // Idle paints the Row at opacity 0; the first frame out of idle painted
  // it at 44: "A RenderFlex overflowed by 12 pixels on the right".
  group('VK-779: compact landscape, idle → selected', () {
    const platforms = TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    });

    /// The shell in compact landscape, Flutter chrome, on Home.
    Future<GlobalKey<TestShellState>> pumpLandscape(
      WidgetTester tester, {
      TextDirection direction = TextDirection.ltr,
    }) async {
      final shell = GlobalKey<TestShellState>();
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          key: shell,
          destinations: _destinations,
          search: LiquidSearch(controller: controller),
        ),
        size: kPhoneLandscape,
        padding: const EdgeInsets.only(bottom: 21),
        platform: defaultTargetPlatform,
        direction: direction,
      );
      expect(
        tester.getSize(find.byKey(kSearchFieldKey)).width,
        44,
        reason: 'the landscape ⌕',
      );
      return shell;
    }

    /// The morph ran with no error, and the field is selected at its full
    /// width, the text field taking all but the fixed parts.
    void expectSelected(WidgetTester tester) {
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(
        scopeOf(tester, 'Search').searchPhase,
        LiquidSearchPhase.selected,
      );
      final field = tester.getSize(find.byKey(kSearchFieldKey)).width;
      expect(tester.getSize(find.byType(TextField)).width, field - 56);
    }

    testWidgets('a tap on the ⌕', (tester) async {
      await pumpLandscape(tester);
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();
      expectSelected(tester);
    }, variant: platforms);

    testWidgets('a lens drag dropped on the ⌕', (tester) async {
      await pumpLandscape(tester);
      final g = await _hoverSearch(tester);
      await g.up();
      await tester.pumpAndSettle();
      expectSelected(tester);
    }, variant: platforms);

    testWidgets('the app selects the search tab', (tester) async {
      final shell = await pumpLandscape(tester);
      shell.currentState!.select(2);
      await tester.pumpAndSettle();
      expectSelected(tester);
    }, variant: platforms);

    for (final direction in TextDirection.values) {
      testWidgets('the first frame shows the leading edge '
          '(${direction.name})', (tester) async {
        await pumpLandscape(tester, direction: direction);
        await tester.tap(find.bySemanticsLabel('Search'));
        await tester.pump();
        final field = tester.getRect(find.byKey(kSearchFieldKey));
        expect(field.width, 44, reason: "the morph's first frame");
        final icon = tester.getRect(
          find.descendant(
            of: find.byKey(kSearchFieldKey),
            matching: find.byIcon(Icons.search),
          ),
        );
        if (direction == TextDirection.ltr) {
          expect(icon.left, field.left + 14);
        } else {
          expect(icon.right, field.right - 14);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    // The IME rule: the field is never rebuilt, so a composition survives
    // every phase change.
    testWidgets('the field is one element from idle to active and back', (
      tester,
    ) async {
      await pumpLandscape(tester);
      final element = tester.element(find.byType(TextField));
      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();
      expect(
        identical(tester.element(find.byType(TextField)), element),
        isTrue,
        reason: 'selected',
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        scopeOf(tester, 'Search').searchPhase,
        LiquidSearchPhase.active,
      );
      expect(
        identical(tester.element(find.byType(TextField)), element),
        isTrue,
        reason: 'active',
      );
      await tester.tap(find.bySemanticsLabel('Cancel search'));
      await tester.pumpAndSettle();
      expect(
        identical(tester.element(find.byType(TextField)), element),
        isTrue,
        reason: 'selected again',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
