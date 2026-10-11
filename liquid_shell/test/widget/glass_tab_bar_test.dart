import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/destinations/badge.dart' show LiquidBadgeView;

const _screen = Size(402, 874);
const _three = [
  LiquidDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  LiquidDestination(
    icon: Icon(Icons.map_outlined),
    selectedIcon: Icon(Icons.map),
    label: 'Explore',
    badge: LiquidBadge.count(3),
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];

final ColorScheme _scheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF0088FF),
);

Future<void> _pump(
  WidgetTester tester, {
  int selected = 0,
  ValueChanged<int>? onSelect,
  LiquidTabAction? trailing,
  bool minimized = false,
  VoidCallback? onExpand,
  TextDirection direction = TextDirection.ltr,
  List<LiquidDestination> destinations = _three,
  VoidCallback? onBody,
  Size screen = _screen,
  double margin = TabMetrics.margin,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = screen * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBody,
                ),
              ),
              Positioned(
                left: margin,
                right: margin,
                bottom: 21,
                child: LiquidTabBar(
                  destinations: destinations,
                  selectedIndex: selected,
                  onDestinationSelected: onSelect ?? (_) {},
                  trailing: trailing,
                  minimized: minimized,
                  onExpand: onExpand,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Screen rect of the semantics node labelled [label] (a slot).
Rect _slot(WidgetTester tester, String label) => tester.getRect(
  find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        (w.properties.label?.startsWith(label) ?? false) &&
        w.properties.button == true,
  ),
);

const double _top = 874.0 - 21 - 62;

void main() {
  testWidgets('pill and slots match native geometry (research §1.1)', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getRect(find.byKey(kTabPillKey)),
      const Rect.fromLTWH(64, _top, 274, 62),
    );
    expect(_slot(tester, 'Home'), const Rect.fromLTWH(68, _top + 4, 94, 54));
    expect(
      _slot(tester, 'Explore'),
      const Rect.fromLTWH(154, _top + 4, 94, 54),
    );
    expect(
      _slot(tester, 'Settings'),
      const Rect.fromLTWH(240, _top + 4, 94, 54),
    );
  });

  testWidgets('every slot draws the filled icon, in both copies', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
    expect(find.byIcon(Icons.home), findsNWidgets(2));
  });

  testWidgets('colours: normal = tabForeground, tinted = primary w600', (
    tester,
  ) async {
    await _pump(tester);
    Color? iconColor(Key copy) => IconTheme.of(
      tester.element(
        find.descendant(
          of: find.byKey(copy),
          matching: find.byIcon(Icons.home),
        ),
      ),
    ).color;
    expect(iconColor(kTabNormalKey), const Color(0xFF191919));
    expect(iconColor(kTabTintedKey), _scheme.primary);
    final tinted = tester.widget<Text>(
      find.descendant(
        of: find.byKey(kTabTintedKey),
        matching: find.text('Home'),
      ),
    );
    expect(tinted.style!.fontWeight, FontWeight.w600);
    expect(tinted.style!.fontSize, 10);
    expect(tinted.style!.letterSpacing, 0);
  });

  testWidgets('the tinted copy is clipped to the lens, the normal copy '
      'outside it', (tester) async {
    await _pump(tester, selected: 1);
    final size = tester.getSize(find.byKey(kTabNormalKey));
    final inside = tester
        .widget<ClipPath>(find.byKey(kTabTintedKey))
        .clipper!
        .getClip(size)
        .getBounds();
    // Pill-local slot 1: x 4 + 86 = 90, y 4, 94 × 54.
    expect(inside, const Rect.fromLTWH(90, 4, 94, 54));
    final outside = tester
        .widget<ClipPath>(find.byKey(kTabNormalKey))
        .clipper!
        .getClip(size);
    expect(outside.contains(const Offset(137, 31)), isFalse);
    expect(outside.contains(const Offset(40, 31)), isTrue);
  });

  testWidgets('the row content adds no semantics: one node per slot '
      '(spec §8.9)', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: 1);
    expect(find.bySemanticsLabel(RegExp('^Home')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Explore')), findsOneWidget);
    expect(find.bySemanticsLabel('3'), findsNothing);
    handle.dispose();
  });

  testWidgets('a fully minimized bar holds no row content (spec §10)', (
    tester,
  ) async {
    await _pump(tester, minimized: true);
    expect(find.byKey(kTabNormalKey), findsNothing);
    expect(find.byKey(kTabTintedKey), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });

  testWidgets('no ink anywhere in the bar', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('badge at the icon frame trailing top, 4 in and 4 up', (
    tester,
  ) async {
    await _pump(tester);
    final frame = tabIconFrame(const Rect.fromLTWH(90, 4, 94, 54));
    expect(
      tester.getTopLeft(find.byType(LiquidBadgeView)),
      Offset(64 + frame.right - 4, _top + frame.top - 4),
    );
    expect(tester.getSize(find.byType(LiquidBadgeView)).height, 21.33);
  });

  testWidgets('RTL: the badge mirrors to the icon frame leading top, 4 in '
      'and 4 up', (tester) async {
    await _pump(tester, direction: TextDirection.rtl);
    // Explore is the middle slot either way: pill-local 90, 94 wide.
    final frame = tabIconFrame(const Rect.fromLTWH(90, 4, 94, 54));
    expect(
      tester.getTopRight(find.byType(LiquidBadgeView)),
      Offset(64 + frame.left + 4, _top + frame.top - 4),
    );
    expect(tester.getSize(find.byType(LiquidBadgeView)).height, 21.33);
  });

  testWidgets('the margins and the gaps pass touches to the body', (
    tester,
  ) async {
    var body = 0;
    await _pump(tester, onBody: () => body++);
    await tester.tapAt(const Offset(40, _top + 31));
    expect(body, 1);
  });

  testWidgets('a tap selects the full-list index', (tester) async {
    final taps = <int>[];
    await _pump(tester, onSelect: taps.add);
    await tester.tapAt(const Offset(287, _top + 31));
    await tester.pumpAndSettle();
    expect(taps, [2]);
  });

  testWidgets('the 8 pt overlap of two slots is split at its midpoint: a '
      'tap goes to the nearest slot', (tester) async {
    for (final direction in TextDirection.values) {
      final taps = <int>[];
      await _pump(tester, onSelect: taps.add, direction: direction);
      // Home 68–162 and Explore 154–248 overlap on 154–162; centre 158.
      final home = _slot(tester, 'Home').center.dx;
      final explore = _slot(tester, 'Explore').center.dx;
      final mid = (home + explore) / 2;
      final towardHome = home < explore ? -2.0 : 2.0;
      await tester.tapAt(Offset(mid + towardHome, _top + 31));
      await tester.tapAt(Offset(mid - towardHome, _top + 31));
      expect(taps, [0, 1], reason: '$direction');
    }
  });

  testWidgets('at 320 (margin 8, 5 tabs + circle) every tab keeps a tap '
      'area of at least 44, inside its semantics capsule (P1 Q17)', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      final taps = <int>[];
      await _pump(
        tester,
        screen: const Size(320, 568),
        margin: TabMetrics.narrowMargin,
        direction: direction,
        onSelect: taps.add,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.edit),
          semanticLabel: 'Compose',
          onPressed: () {},
        ),
        destinations: [
          for (final label in ['One', 'Two', 'Three', 'Four', 'Five'])
            LiquidDestination(icon: const Icon(Icons.circle), label: label),
        ],
      );
      const labels = ['One', 'Two', 'Three', 'Four', 'Five'];
      const y = 568 - 21 - 31.0;
      Future<int?> hit(double x) async {
        taps.clear();
        await tester.tapAt(Offset(x, y));
        return taps.isEmpty ? null : taps.single;
      }

      // The edge between [a] (hit at x = a) and [b] (hit at x = b), to 0.001.
      Future<double> edge(double a, double b) async {
        final left = await hit(a);
        var lo = a;
        var hi = b;
        for (var i = 0; i < 20; i++) {
          final m = (lo + hi) / 2;
          if (await hit(m) == left) {
            lo = m;
          } else {
            hi = m;
          }
        }
        return (lo + hi) / 2;
      }

      final pill = tester.getRect(find.byKey(kTabPillKey));
      final nodes = [for (final label in labels) _slot(tester, label)];
      final order = [0, 1, 2, 3, 4]
        ..sort((a, b) => nodes[a].center.dx.compareTo(nodes[b].center.dx));
      final edges = [
        await edge(pill.left - 1, nodes[order.first].center.dx),
        for (var k = 0; k + 1 < order.length; k++)
          await edge(
            nodes[order[k]].center.dx,
            nodes[order[k + 1]].center.dx,
          ),
        await edge(nodes[order.last].center.dx, pill.right + 1),
      ];
      for (final (k, i) in order.indexed) {
        final reason = '$direction ${labels[i]}';
        expect(await hit(nodes[i].center.dx), i, reason: reason);
        // Bisection finds each edge to about 1e-4.
        expect(
          edges[k + 1] - edges[k],
          greaterThanOrEqualTo(44 - 1e-3),
          reason: reason,
        );
        expect(
          edges[k],
          greaterThanOrEqualTo(nodes[i].left - 0.01),
          reason: reason,
        );
        expect(
          edges[k + 1],
          lessThanOrEqualTo(nodes[i].right + 0.01),
          reason: reason,
        );
      }
    }
  });

  testWidgets('trailing: pill pinned start, 62 circle at the end', (
    tester,
  ) async {
    await _pump(
      tester,
      trailing: LiquidTabAction(
        icon: const Icon(Icons.edit),
        semanticLabel: 'Compose',
        onPressed: () {},
      ),
    );
    expect(
      tester.getRect(find.byKey(kTabPillKey)),
      const Rect.fromLTWH(21, _top, 274, 62),
    );
    expect(
      tester.getRect(find.byKey(kTabTrailingKey)),
      const Rect.fromLTWH(319, _top, 62, 62),
    );
  });

  testWidgets('RTL: slot 0 on the right', (tester) async {
    await _pump(tester, direction: TextDirection.rtl);
    expect(
      _slot(tester, 'Home').left,
      greaterThan(_slot(tester, 'Settings').left),
    );
  });

  testWidgets('minimized: a 48 circle at x 28 with one node', (tester) async {
    var expanded = 0;
    await _pump(tester, minimized: true, onExpand: () => expanded++);
    expect(
      tester.getRect(find.byKey(kTabPillKey)),
      const Rect.fromLTWH(28, _top + 7, 48, 48),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.button == true,
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(52, _top + 31));
    expect(expanded, 1);
    // The old pill area passes touches through.
    await tester.tapAt(const Offset(200, _top + 31));
    expect(expanded, 1);
  });

  testWidgets('top form: 48 pill, label-only 17 pt cells, icon-only search', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(834, 1210) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: LiquidTabBar(
              position: LiquidTabBarPosition.top,
              destinations: const [
                ..._three,
                LiquidDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                  role: LiquidDestinationRole.search,
                ),
              ],
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(kTabPillKey)).height, 48);
    expect(find.byIcon(Icons.home), findsNothing);
    expect(find.byIcon(Icons.search), findsNWidgets(2));
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(kTabTintedKey),
        matching: find.text('Home'),
      ),
    );
    expect(label.style!.fontSize, 17);
    expect(label.style!.fontWeight, FontWeight.w600);
  });

  testWidgets('landscape form: 44 pill, icon beside a 12 pt label', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(874, 402) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: TabMetrics.landscapeMargin,
                right: TabMetrics.landscapeMargin,
                bottom: 20,
                child: LiquidTabBar(
                  destinations: _three,
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(kTabPillKey)).height, 44);
    final icon = tester.getRect(
      find
          .descendant(
            of: find.byKey(kTabNormalKey),
            matching: find.byIcon(Icons.map),
          )
          .first,
    );
    final label = tester.getRect(
      find.descendant(
        of: find.byKey(kTabNormalKey),
        matching: find.text('Explore'),
      ),
    );
    expect(label.left, greaterThan(icon.right));
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(kTabNormalKey),
              matching: find.text('Explore'),
            ),
          )
          .style!
          .fontSize,
      12,
    );
  });

  testWidgets('landscape form, RTL: the icon at the slot start (right), the '
      'label before it', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(874, 402) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: TabMetrics.landscapeMargin,
                  right: TabMetrics.landscapeMargin,
                  bottom: 20,
                  child: LiquidTabBar(
                    destinations: _three,
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final icon = tester.getRect(
      find
          .descendant(
            of: find.byKey(kTabNormalKey),
            matching: find.byIcon(Icons.map),
          )
          .first,
    );
    final label = tester.getRect(
      find.descendant(
        of: find.byKey(kTabNormalKey),
        matching: find.text('Explore'),
      ),
    );
    expect(label.right, lessThan(icon.left));
  });

  testWidgets('top form: slots measure labels in the style the cells draw '
      '(label + 31), not the ambient one', (tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(834, 1210) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            // An ambient style the bar's own Material replaces.
            style: const TextStyle(wordSpacing: 100),
            child: Align(
              alignment: Alignment.topCenter,
              child: LiquidTabBar(
                position: LiquidTabBarPosition.top,
                destinations: const [
                  LiquidDestination(icon: Icon(Icons.home), label: 'A B'),
                  LiquidDestination(icon: Icon(Icons.map), label: 'C'),
                ],
                selectedIndex: 0,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    double drawn(String label) => tester
        .getSize(
          find.descendant(
            of: find.byKey(kTabTintedKey),
            matching: find.text(label),
          ),
        )
        .width;
    expect(
      tester.getSize(find.byKey(kTabPillKey)).width,
      moreOrLessEquals(8 + drawn('A B') + 31 + drawn('C') + 31),
    );
  });

  testWidgets('standalone: a landscape window at least 500 tall keeps the '
      'compact form (690×600)', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(690, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LiquidTabBar(
              destinations: _three,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(kTabPillKey)).height, 62);
  });

  testWidgets('landscape form at AX sizes: icon-only slots of 49 (label '
      'width 0)', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(874, 402) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(874, 402),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: TabMetrics.landscapeMargin,
                  right: TabMetrics.landscapeMargin,
                  bottom: 20,
                  child: LiquidTabBar(
                    destinations: _three,
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Explore'), findsNothing);
    // 2 × inset + 3 × 49 + 2 × 4 gaps.
    expect(tester.getSize(find.byKey(kTabPillKey)).width, 8 + 3 * 49 + 8);
  });
}
