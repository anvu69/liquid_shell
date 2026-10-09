import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/fit_label.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';

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

void main() {
  testWidgets('shows only everywhere destinations', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('a tap reports the index in the full destination list', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));
    await tester.tap(find.text('Settings'));
    await tester.tap(find.text('Home'));
    expect(selected, [3, 0]);
  });

  testWidgets('selected cell: primary on a primaryContainer chip', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selectedIndex: 1));
    expect(
      tester.widget<Text>(find.text('Inbox')).style!.color,
      _scheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('Home')).style!.color,
      _scheme.onSurfaceVariant,
    );
    final chips = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == _scheme.primaryContainer);
    expect(chips, hasLength(1));
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
    for (final label in ['Home', 'Inbox', 'Settings']) {
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        _scheme.onSurfaceVariant,
      );
    }
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
    expect(circle.left - pill.right, 8);
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

  testWidgets('minimised: only the selected cell, trailing kept', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        selectedIndex: 1,
        minimized: true,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
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
    await tester.tap(find.text('Inbox'));
    expect(expanded, 1);
    expect(selected, isEmpty);
    final announcements = tester.takeAnnouncements();
    expect(announcements.single.message, 'Navigation bar opened');
    handle.dispose();
  });

  testWidgets('AnimatedSize is removed under disableAnimations', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.byType(AnimatedSize), findsOneWidget);
    await tester.pumpWidget(_host(disableAnimations: true));
    expect(find.byType(AnimatedSize), findsNothing);
  });

  testWidgets('expanding animates the glass itself, so its rounded shape and '
      'outside shadow follow the size', (tester) async {
    await tester.pumpWidget(_host(selectedIndex: 1, minimized: true));
    final glass = find.byType(LiquidGlass);
    final shadow = find.descendant(
      of: glass,
      matching: find.byType(OutsideShadow),
    );
    final small = tester.getSize(glass).width;

    await tester.pumpWidget(_host(selectedIndex: 1));
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-animation: the glass is outermost (no AnimatedSize clips it), it
    // has the in-between width, and its shadow is drawn at that width.
    expect(
      find.ancestor(of: glass, matching: find.byType(AnimatedSize)),
      findsNothing,
    );
    final mid = tester.getSize(glass).width;
    expect(tester.getSize(shadow).width, mid);

    await tester.pumpAndSettle();
    final full = tester.getSize(glass).width;
    expect(mid, greaterThan(small));
    expect(mid, lessThan(full));
  });

  testWidgets('AX text scale: icon-only cells, label in semantics, long '
      'press shows the large content viewer', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(textScale: 2));
    expect(find.text('Home'), findsNothing);
    expect(_cell('Home'), findsOneWidget);
    expect(tester.getSize(find.byIcon(Icons.home_outlined)).height, 36);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home_outlined)),
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
    await tester.tap(find.text('Home'));
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
      matchesSemantics(
        label: 'Inbox, 120 new',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // matchesSemantics skips a null hint, so check it directly.
    expect(tester.getSemantics(_cell('Inbox')).hint, isEmpty);
    await tester.tap(find.text('Inbox'));
    expect(tester.takeAnnouncements(), isEmpty);
    expect(selected, isEmpty);
    handle.dispose();
  });

  testWidgets('the selected cell draws selectedIcon, the others icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        destinations: const [
          LiquidDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          LiquidDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
        ],
      ),
    );
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsNothing);
  });

  testWidgets('minimised on a sidebarOnly selection shows the first tab '
      'destination', (tester) async {
    await tester.pumpWidget(_host(selectedIndex: 2, minimized: true));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Inbox'), findsNothing);
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
      tester.getCenter(find.byIcon(Icons.home_outlined)),
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
      tester.getCenter(find.byIcon(Icons.home_outlined)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    await tester.pumpWidget(_host(textScale: 2, destinations: const []));
    // The overlay drops a removed entry on the next frame.
    await tester.pump();
    expect(find.byKey(LargeContentViewer.overlayKey), findsNothing);
    await gesture.up();
  });

  testWidgets('a bottom cell is at most 88 wide', (tester) async {
    const label = 'Notifications and settings';
    await tester.pumpWidget(
      _host(
        destinations: const [
          LiquidDestination(icon: Icon(Icons.notifications), label: label),
        ],
      ),
    );
    final cell = find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(cell).width, lessThanOrEqualTo(88));
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

  group('narrow pill padding (Q17)', () {
    // Inner padding = the first cell's start minus the pill's start.
    Future<double> padding(
      WidgetTester tester, {
      required double width,
      bool? narrow,
      LiquidTabBarPosition position = LiquidTabBarPosition.bottom,
    }) async {
      await tester.pumpWidget(
        _host(width: width, narrow: narrow, position: position),
      );
      // A second pump in one test animates the pill size; let it land.
      await tester.pumpAndSettle();
      final pill = tester.getRect(find.byType(LiquidGlass).first);
      final home = tester.getRect(
        find.ancestor(of: find.text('Home'), matching: find.byType(InkWell)),
      );
      return home.left - pill.left;
    }

    test('the threshold is 340', () {
      expect(kLiquidNarrowWidth, 340);
    });

    testWidgets('narrow: true uses 4, narrow: false uses 8, at any width', (
      tester,
    ) async {
      expect(await padding(tester, width: 393, narrow: true), 4);
      expect(await padding(tester, width: 320, narrow: false), 8);
    });

    testWidgets('by default it follows the MediaQuery width: 339 narrow, '
        '340 not', (tester) async {
      expect(await padding(tester, width: 339), 4);
      expect(await padding(tester, width: 340), 8);
    });

    testWidgets('the top bar keeps its 4pt padding either way', (
      tester,
    ) async {
      const top = LiquidTabBarPosition.top;
      expect(await padding(tester, width: 393, position: top), 4);
      expect(await padding(tester, width: 320, position: top), 4);
      expect(await padding(tester, width: 393, narrow: true, position: top), 4);
    });

    testWidgets('RTL: the narrow padding is at the pill end too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(width: 320, direction: TextDirection.rtl),
      );
      final pill = tester.getRect(find.byType(LiquidGlass).first);
      final home = tester.getRect(
        find.ancestor(of: find.text('Home'), matching: find.byType(InkWell)),
      );
      expect(pill.right - home.right, 4);
    });
  });
}

// The size a label is drawn at: its style's size after the text scaler,
// times the scale it is painted with (its global rect over its own size).
double _drawnSize(WidgetTester tester, String label, {double base = 10}) {
  final text = find.text(label);
  final scaler = MediaQuery.textScalerOf(tester.element(text));
  final scale = tester.getRect(text).width / tester.getSize(text).width;
  return scaler.scale(base) * scale;
}

bool _ellipsized(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines;

Rect _cellOf(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
);

void _narrowLabelTests() {
  // Four letters: about 42pt at 10pt in the test font, so each fits a narrow
  // cell (about 46pt here) only without the 8pt side padding, and at text
  // scale 1.3 (13pt) only once shrunk.
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

  void expectFitted(WidgetTester tester, String label) {
    expect(_ellipsized(tester, label), isFalse, reason: '$label ellipsized');
    final size = _drawnSize(tester, label);
    // Rects go through the paint transform: allow float noise.
    expect(
      size,
      greaterThanOrEqualTo(kLiquidMinLabelSize - 1e-9),
      reason: label,
    );
    final text = tester.getRect(find.text(label));
    final cell = _cellOf(tester, label);
    expect(text.left, greaterThanOrEqualTo(cell.left - 0.01), reason: label);
    expect(text.right, lessThanOrEqualTo(cell.right + 0.01), reason: label);
  }

  test('the minimum is 10', () {
    expect(kLiquidMinLabelSize, 10);
  });

  testWidgets('text scale 1: a label takes the side padding before it '
      'ellipsizes, and keeps its 10pt size', (tester) async {
    await tester.pumpWidget(narrowBar(textScale: 1));
    for (final label in short) {
      expectFitted(tester, label);
      expect(_drawnSize(tester, label), moreOrLessEquals(10), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 1.3: labels shrink to fit their cells, not below '
      '10pt', (tester) async {
    await tester.pumpWidget(narrowBar());
    for (final label in short) {
      expectFitted(tester, label);
      expect(_drawnSize(tester, label), lessThan(13), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected label fits too', (tester) async {
    for (final index in [0, 4]) {
      await tester.pumpWidget(narrowBar(selectedIndex: index));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(short[index])).style!.color,
        _scheme.primary,
      );
      expectFitted(tester, short[index]);
    }
  });

  testWidgets('a label too long even at 10pt ellipsizes at exactly 10pt', (
    tester,
  ) async {
    await tester.pumpWidget(
      narrowBar(labels: ['Home', 'Mail', 'Feed', 'Chat', 'Settings']),
    );
    expect(_ellipsized(tester, 'Settings'), isTrue);
    expect(_drawnSize(tester, 'Settings'), moreOrLessEquals(10));
    final text = tester.getRect(find.text('Settings'));
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
    expect(_drawnSize(tester, 'Home', base: 8), moreOrLessEquals(8));
    expect(_ellipsized(tester, 'Settings'), isTrue);
    expect(_drawnSize(tester, 'Settings', base: 8), moreOrLessEquals(8));
  });

  testWidgets('regular width is unchanged: padding 8, ellipsis at the '
      "style's size", (tester) async {
    await tester.pumpWidget(narrowBar(narrow: false));
    for (final label in short) {
      expect(_ellipsized(tester, label), isTrue, reason: label);
      expect(_drawnSize(tester, label), moreOrLessEquals(13), reason: label);
      final text = tester.getRect(find.text(label));
      final cell = _cellOf(tester, label);
      expect(text.left - cell.left, moreOrLessEquals(8), reason: label);
    }
  });

  testWidgets('RTL: labels fit the same way, cells run right to left', (
    tester,
  ) async {
    await tester.pumpWidget(narrowBar(direction: TextDirection.rtl));
    for (final label in short) {
      expectFitted(tester, label);
      expect(_drawnSize(tester, label), lessThan(13), reason: label);
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
