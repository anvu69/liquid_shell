import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/fit_label.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/tab_bar.dart' show LiquidActionCircle;

import '../helpers/shell_harness.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(120),
  ),
  LiquidDestination(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
    placement: LiquidPlacement.sidebarOnly,
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    label: 'Settings',
    badge: LiquidBadge.dot(),
  ),
];

Widget _host({
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  LiquidTabBarPosition position = LiquidTabBarPosition.bottom,
  LiquidTabAction? trailing,
  bool minimized = false,
  VoidCallback? onExpand,
  List<LiquidDestination> destinations = _destinations,
  double textScale = 1,
  bool disableAnimations = false,
  double width = 393,
  TextDirection direction = TextDirection.ltr,
  bool? narrow,
  LiquidGlassTheme? glassTheme,
}) => MaterialApp(
  theme: ThemeData(
    colorScheme: _scheme,
    extensions: [?glassTheme],
  ),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 852),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: width,
            child: Center(
              child: LiquidTabBar(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected ?? (_) {},
                position: position,
                trailing: trailing,
                minimized: minimized,
                onExpand: onExpand,
                narrow: narrow,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder _cell(String label) => find.bySemanticsLabel(RegExp('^$label'));

/// A bottom label in the normal copy of the row (the tinted copy draws it a
/// second time, clipped to the lens: spec VK-503 §6.3).
Finder _label(String label) =>
    find.descendant(of: find.byKey(kTabNormalKey), matching: find.text(label));

/// A bottom label in the tinted copy.
Finder _tinted(String label) =>
    find.descendant(of: find.byKey(kTabTintedKey), matching: find.text(label));

void main() {
  testWidgets('shows only everywhere destinations', (tester) async {
    await tester.pumpWidget(_host());
    expect(_label('Home'), findsOneWidget);
    expect(_label('Inbox'), findsOneWidget);
    expect(_label('Settings'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('a tap reports the index in the full destination list', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));
    await tester.tap(tabSlot('Settings'));
    await tester.tap(tabSlot('Home'));
    expect(selected, [3, 0]);
  });

  testWidgets('semantics: button, selected, label with badge', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(selectedIndex: 1));
    expect(
      tester.getSemantics(_cell('Inbox')),
      matchesSemantics(
        label: 'Inbox, 120 new',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_cell('Settings')),
      matchesSemantics(
        label: 'Settings, New',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a selected sidebarOnly destination highlights nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selectedIndex: 2));
    final foreground = LiquidGlassTheme.fromColorScheme(_scheme).tabForeground;
    for (final label in ['Home', 'Inbox', 'Settings']) {
      expect(visibleTabLabelColor(tester, label), foreground, reason: label);
    }
    // No lens: the tinted copy is clipped away entirely.
    final tinted = tester.widget<ClipPath>(find.byKey(kTabTintedKey));
    final size = tester.getSize(find.byKey(kTabTintedKey));
    expect(tinted.clipper!.getClip(size).getBounds().isEmpty, isTrue);
  });

  testWidgets('badges draw on the icons', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('bottom pill is 62 high at text scale 1; trailing is a '
      'square of the same height, 8 away', (tester) async {
    await tester.pumpWidget(
      _host(
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    final pill = tester.getRect(find.byType(LiquidGlass).first);
    final circle = tester.getRect(find.byType(LiquidGlass).last);
    expect(pill.height, 62);
    expect(circle.height, 62);
    expect(circle.width, 62);
    // The bar fills its 393 row: the pill is start-pinned, the circle
    // end-pinned, at least 8 apart (spec VK-503 §5.1).
    expect(circle.right - pill.left, 393);
    expect(circle.left - pill.right, greaterThanOrEqualTo(8));
  });

  testWidgets('top pill is 52 high with icons beside labels', (tester) async {
    await tester.pumpWidget(_host(position: LiquidTabBarPosition.top));
    expect(tester.getRect(find.byType(LiquidGlass).first).height, 52);
    final icon = tester.getRect(find.byIcon(Icons.home_outlined));
    final label = tester.getRect(find.text('Home'));
    expect(label.left, greaterThan(icon.right));
  });

  testWidgets('trailing action: tap, tooltip and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () => pressed++,
          semanticLabel: 'Search',
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    expect(pressed, 1);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('trailing circle: a white press highlight instead of ink, '
      'native foreground (spec VK-503 §8.8)', (tester) async {
    await tester.pumpWidget(
      _host(
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    final circle = find.byKey(kTabTrailingKey);
    expect(
      find.descendant(of: circle, matching: find.byType(InkWell)),
      findsNothing,
    );
    final press = find.descendant(
      of: circle,
      matching: find.byType(TabHoverHighlight),
    );
    // One overlay serves press, keyboard focus and the lens drag.
    expect(press, findsOneWidget);
    bool pressed() => tester.widget<TabHoverHighlight>(press).hovered.value;
    expect(pressed(), isFalse);
    final g = await tester.startGesture(tester.getCenter(circle));
    // On touch-down, as native: no wait for the gesture arena.
    await tester.pump();
    expect(pressed(), isTrue);
    await g.up();
    await tester.pump();
    expect(pressed(), isFalse);
    final icon = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.search),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    final glass = LiquidGlassTheme.of(tester.element(circle));
    expect(icon.data.color, glass.tabForeground);
    expect(icon.data.size, glass.tabIconSize);
  });

  for (final position in LiquidTabBarPosition.values) {
    testWidgets('trailing circle (${position.name}): Tab focuses it with a '
        'visible highlight; Enter and Space activate it', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          position: position,
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () => pressed++,
            semanticLabel: 'Search',
          ),
        ),
      );
      final overlay = find.descendant(
        of: find.byType(LiquidActionCircle),
        matching: find.byType(TabHoverHighlight),
      );
      bool lit() => tester.widget<TabHoverHighlight>(overlay).hovered.value;
      expect(lit(), isFalse);
      // The top bar's cells take focus first; the circle comes after them.
      for (var i = 0; i < 6 && !lit(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(lit(), isTrue, reason: 'focus shows the highlight');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pressed, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pressed, 2);
    });
  }

  testWidgets('minimised: the selected icon only, in a 48 circle; trailing '
      'kept (spec VK-503 §10)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        selectedIndex: 1,
        minimized: true,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.edit),
          semanticLabel: 'Compose',
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
    expect(find.bySemanticsLabel(RegExp('^Inbox')), findsOneWidget);
    expect(find.bySemanticsLabel('Compose'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('minimised tap expands, keeps the tab and announces', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final selected = <int>[];
    var expanded = 0;
    await tester.pumpWidget(
      _host(
        selectedIndex: 1,
        minimized: true,
        onSelected: selected.add,
        onExpand: () => expanded++,
      ),
    );
    expect(
      tester.getSemantics(_cell('Inbox')),
      matchesSemantics(
        label: 'Inbox, 120 new',
        hint: 'Tap to open the navigation bar',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(tabSlot('Inbox'));
    expect(expanded, 1);
    expect(selected, isEmpty);
    final announcements = tester.takeAnnouncements();
    expect(announcements.single.message, 'Navigation bar opened');
    handle.dispose();
  });

  testWidgets('AX text scale: icon-only cells, label in semantics, long '
      'press shows the large content viewer', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(textScale: 2));
    expect(find.text('Home'), findsNothing);
    expect(_cell('Home'), findsOneWidget);
    // Both copies of the row draw the icon (spec VK-503 §6.3).
    expect(tester.getSize(find.byIcon(Icons.home_outlined).first).height, 36);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home_outlined).first),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(LargeContentViewer.overlayKey), findsNothing);
    handle.dispose();
  });

  testWidgets('five destinations fit a 320pt phone without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 320,
        destinations: [
          for (final label in ['One', 'Two', 'Three', 'Four', 'Five'])
            LiquidDestination(icon: const Icon(Icons.circle), label: label),
        ],
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL puts the trailing circle at the pill start', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        direction: TextDirection.rtl,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    final pill = tester.getRect(find.byType(LiquidGlass).first);
    final circle = tester.getRect(find.byType(LiquidGlass).last);
    expect(circle.right, lessThan(pill.left));
  });

  testWidgets('announcement uses the ambient text direction', (tester) async {
    await tester.pumpWidget(
      _host(minimized: true, direction: TextDirection.rtl, onExpand: () {}),
    );
    await tester.tap(tabSlot('Home'));
    expect(tester.takeAnnouncements().single.textDirection, TextDirection.rtl);
  });

  testWidgets('minimised without onExpand: no hint and no announcement', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final selected = <int>[];
    await tester.pumpWidget(
      _host(selectedIndex: 1, minimized: true, onSelected: selected.add),
    );
    expect(
      tester.getSemantics(_cell('Inbox')),
      // Inert without onExpand, but it keeps P1's tap action.
      matchesSemantics(
        label: 'Inbox, 120 new',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // matchesSemantics skips a null hint, so check it directly.
    expect(tester.getSemantics(_cell('Inbox')).hint, isEmpty);
    await tester.tap(tabSlot('Inbox'));
    expect(tester.takeAnnouncements(), isEmpty);
    expect(selected, isEmpty);
    handle.dispose();
  });

  testWidgets('every bottom slot draws selectedIcon ?? icon (spec VK-503 '
      '§6.1)', (tester) async {
    const destinations = [
      LiquidDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      LiquidDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
    ];
    await tester.pumpWidget(_host(destinations: destinations));
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.home), findsWidgets);
    expect(find.byIcon(Icons.inbox_outlined), findsWidgets);
  });

  testWidgets('minimised on a sidebarOnly selection shows the first tab '
      'destination', (tester) async {
    await tester.pumpWidget(_host(selectedIndex: 2, minimized: true));
    // Icon only (spec VK-503 §10).
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsNothing);
    expect(find.byIcon(Icons.inbox_outlined), findsNothing);
  });

  testWidgets('minimised with no tab destinations draws an empty pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        minimized: true,
        destinations: const [
          LiquidDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
            placement: LiquidPlacement.sidebarOnly,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('the large content card goes when the text scale drops below '
      'AX mid-press', (tester) async {
    await tester.pumpWidget(_host(textScale: 2));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home_outlined).first),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    await tester.pumpWidget(_host());
    // The overlay drops a removed entry on the next frame.
    await tester.pump();
    expect(find.byKey(LargeContentViewer.overlayKey), findsNothing);
    await gesture.up();
  });

  testWidgets('the large content card goes when its cell is removed '
      'mid-press', (tester) async {
    await tester.pumpWidget(_host(textScale: 2));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home_outlined).first),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    await tester.pumpWidget(_host(textScale: 2, destinations: const []));
    // The overlay drops a removed entry on the next frame.
    await tester.pump();
    expect(find.byKey(LargeContentViewer.overlayKey), findsNothing);
    await gesture.up();
  });

  group('standalone use asserts its required ancestors', () {
    const bar = LiquidTabBar(
      destinations: _destinations,
      selectedIndex: 0,
      onDestinationSelected: _ignore,
    );

    testWidgets('Overlay', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(textDirection: TextDirection.ltr, child: bar),
        ),
      );
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('No Overlay widget found'),
            contains('LiquidTabBar widgets require an Overlay widget ancestor'),
          ),
        ),
      );
    });

    testWidgets('Directionality', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(data: MediaQueryData(), child: bar),
      );
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('No Directionality widget found'),
        ),
      );
    });
  });

  group('narrow labels fit (Q18)', _narrowLabelTests);

  group('narrow (Q17)', () {
    final search = LiquidTabAction(
      icon: const Icon(Icons.search),
      onPressed: () {},
      semanticLabel: 'Search',
    );

    // Five tabs and a circle at text scale 1.3 (13pt labels).
    Widget bar(double width, List<String> labels, {bool? narrow}) => _host(
      width: width,
      narrow: narrow,
      textScale: 1.3,
      trailing: search,
      destinations: [
        for (final label in labels)
          LiquidDestination(icon: const Icon(Icons.circle), label: label),
      ],
    );

    void expectEllipsized(
      WidgetTester tester,
      List<String> labels, {
      required bool ellipsized,
    }) {
      for (final label in labels) {
        expect(
          _ellipsized(tester, _label(label)),
          ellipsized,
          reason: label,
        );
      }
    }

    test('the threshold is 340', () {
      expect(kLiquidNarrowWidth, 340);
    });

    testWidgets('narrow: true fits the labels at any width, narrow: false '
        'does not', (tester) async {
      // Five letters: wider than the 61.4 label box at 13pt, not at 10pt.
      const labels = ['Homes', 'Mails', 'Feeds', 'Chats', 'Helps'];
      await tester.pumpWidget(bar(393, labels, narrow: true));
      expectEllipsized(tester, labels, ellipsized: false);
      await tester.pumpWidget(bar(393, labels, narrow: false));
      expectEllipsized(tester, labels, ellipsized: true);
    });

    testWidgets('by default it follows the MediaQuery width: 339 narrow, '
        '340 not', (tester) async {
      // Four letters: wider than the ≈50.7 label box at 13pt, not at 10pt.
      const labels = ['Home', 'Mail', 'Feed', 'Chat', 'Help'];
      await tester.pumpWidget(bar(339, labels));
      expectEllipsized(tester, labels, ellipsized: false);
      await tester.pumpWidget(bar(340, labels));
      expectEllipsized(tester, labels, ellipsized: true);
    });

    testWidgets('the top bar keeps its 4pt padding either way', (
      tester,
    ) async {
      Future<double> padding({required double width, bool? narrow}) async {
        await tester.pumpWidget(
          _host(
            width: width,
            narrow: narrow,
            position: LiquidTabBarPosition.top,
          ),
        );
        await tester.pumpAndSettle();
        final pill = tester.getRect(find.byType(LiquidGlass).first);
        final home = tester.getRect(
          find.ancestor(of: find.text('Home'), matching: find.byType(InkWell)),
        );
        return home.left - pill.left;
      }

      expect(await padding(width: 393), 4);
      expect(await padding(width: 320), 4);
      expect(await padding(width: 393, narrow: true), 4);
    });
  });
}

// The size a label is drawn at: its style's size after the text scaler,
// times the scale it is painted with (its global rect over its own size).
double _drawnSize(WidgetTester tester, Finder text, {double base = 10}) {
  final scaler = MediaQuery.textScalerOf(tester.element(text));
  final scale = tester.getRect(text).width / tester.getSize(text).width;
  return scaler.scale(base) * scale;
}

bool _ellipsized(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

/// The label box of [label]'s slot: the slot (its semantics node) less 4 at
/// each side (spec VK-503 §5.1).
Rect _cellOf(WidgetTester tester, String label) {
  final slot = tester.getRect(tabSlot(label));
  return Rect.fromLTRB(slot.left + 4, slot.top, slot.right - 4, slot.bottom);
}

void _narrowLabelTests() {
  // Four letters: about 42pt at 10pt in the test font, so each fits its
  // label box (46.8pt here: the 320 row less the 70 circle, over 5 slots) at
  // 10pt, and at text scale 1.3 (13pt) only once shrunk.
  const short = ['Home', 'Mail', 'Feed', 'Chat', 'Help'];
  final search = LiquidTabAction(
    icon: const Icon(Icons.search),
    onPressed: () {},
    semanticLabel: 'Search',
  );

  List<LiquidDestination> destinations(List<String> labels) => [
    for (final label in labels)
      LiquidDestination(icon: const Icon(Icons.circle), label: label),
  ];

  Widget narrowBar({
    List<String> labels = short,
    double textScale = 1.3,
    int selectedIndex = 0,
    bool? narrow,
    TextDirection direction = TextDirection.ltr,
    LiquidGlassTheme? glassTheme,
  }) => _host(
    width: 320,
    destinations: destinations(labels),
    trailing: search,
    textScale: textScale,
    selectedIndex: selectedIndex,
    narrow: narrow,
    direction: direction,
    glassTheme: glassTheme,
  );

  void expectFitted(
    WidgetTester tester,
    String label, {
    Finder Function(String) copy = _label,
  }) {
    final text = copy(label);
    expect(_ellipsized(tester, text), isFalse, reason: '$label ellipsized');
    final size = _drawnSize(tester, text);
    // Rects go through the paint transform: allow float noise.
    expect(
      size,
      greaterThanOrEqualTo(kLiquidMinLabelSize - 1e-9),
      reason: label,
    );
    final rect = tester.getRect(text);
    final cell = _cellOf(tester, label);
    expect(rect.left, greaterThanOrEqualTo(cell.left - 0.01), reason: label);
    expect(rect.right, lessThanOrEqualTo(cell.right + 0.01), reason: label);
  }

  test('the minimum is 10', () {
    expect(kLiquidMinLabelSize, 10);
  });

  testWidgets('text scale 1: a label fits its label box and keeps its 10pt '
      'size', (tester) async {
    await tester.pumpWidget(narrowBar(textScale: 1));
    for (final label in short) {
      expectFitted(tester, label);
      expect(
        _drawnSize(tester, _label(label)),
        moreOrLessEquals(10),
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 1.3: labels shrink to fit their cells, not below '
      '10pt', (tester) async {
    await tester.pumpWidget(narrowBar());
    for (final label in short) {
      expectFitted(tester, label);
      expect(_drawnSize(tester, _label(label)), lessThan(13), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected label fits too', (tester) async {
    for (final index in [0, 4]) {
      await tester.pumpWidget(narrowBar(selectedIndex: index));
      await tester.pumpAndSettle();
      // The lens covers the selected label only.
      final foreground = LiquidGlassTheme.fromColorScheme(
        _scheme,
      ).tabForeground;
      for (final (i, label) in short.indexed) {
        expect(
          visibleTabLabelColor(tester, label),
          i == index ? _scheme.primary : foreground,
          reason: label,
        );
      }
      expectFitted(tester, short[index]);
      expectFitted(tester, short[index], copy: _tinted);
    }
  });

  testWidgets('a label too long even at 10pt ellipsizes at exactly 10pt', (
    tester,
  ) async {
    await tester.pumpWidget(
      narrowBar(labels: ['Home', 'Mail', 'Feed', 'Chat', 'Settings']),
    );
    expect(_ellipsized(tester, _label('Settings')), isTrue);
    expect(_drawnSize(tester, _label('Settings')), moreOrLessEquals(10));
    final text = tester.getRect(_label('Settings'));
    final cell = _cellOf(tester, 'Settings');
    expect(text.left, greaterThanOrEqualTo(cell.left - 0.01));
    expect(text.right, lessThanOrEqualTo(cell.right + 0.01));
    expectFitted(tester, 'Home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a style already under 10pt is never enlarged', (tester) async {
    final small = LiquidGlassTheme.fromColorScheme(_scheme);
    await tester.pumpWidget(
      narrowBar(
        textScale: 1,
        labels: ['Home', 'Mail', 'Feed', 'Chat', 'Settings'],
        glassTheme: small.copyWith(
          labelStyle: small.labelStyle.copyWith(fontSize: 8),
        ),
      ),
    );
    expect(_drawnSize(tester, _label('Home'), base: 8), moreOrLessEquals(8));
    expect(_ellipsized(tester, _label('Settings')), isTrue);
    expect(
      _drawnSize(tester, _label('Settings'), base: 8),
      moreOrLessEquals(8),
    );
  });

  testWidgets("regular width does not fit: ellipsis at the style's size, "
      'across the label box', (tester) async {
    await tester.pumpWidget(narrowBar(narrow: false));
    for (final label in short) {
      expect(_ellipsized(tester, _label(label)), isTrue, reason: label);
      expect(
        _drawnSize(tester, _label(label)),
        moreOrLessEquals(13),
        reason: label,
      );
      final text = tester.getRect(_label(label));
      final cell = _cellOf(tester, label);
      expect(text.left - cell.left, moreOrLessEquals(0), reason: label);
    }
  });

  testWidgets('RTL: labels fit the same way, cells run right to left', (
    tester,
  ) async {
    await tester.pumpWidget(narrowBar(direction: TextDirection.rtl));
    for (final label in short) {
      expectFitted(tester, label);
      expect(_drawnSize(tester, _label(label)), lessThan(13), reason: label);
    }
    expect(
      _cellOf(tester, short.first).left,
      greaterThan(_cellOf(tester, short.last).left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AX text scale stays icon-only when narrow', (tester) async {
    await tester.pumpWidget(narrowBar(textScale: 2));
    for (final label in short) {
      expect(find.text(label), findsNothing);
    }
  });
}

void _ignore(int _) {}
