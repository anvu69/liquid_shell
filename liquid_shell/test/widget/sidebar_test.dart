import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(3),
  ),
  LiquidDestination(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
    placement: LiquidPlacement.sidebarOnly,
  ),
];

Widget _host({
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onHide,
  Widget? header,
  Widget? footer,
  LiquidTabAction? trailing,
  double width = 300,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 20),
  List<LiquidDestination> destinations = _destinations,
}) => MaterialApp(
  theme: ThemeData(colorScheme: _scheme),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(834, 600),
      padding: padding,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Directionality(
      textDirection: direction,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: LiquidSidebar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected ?? (_) {},
          onHide: onHide,
          header: header,
          footer: footer,
          trailing: trailing,
          width: width,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('lists every destination in order, sidebar-only included', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final ys = [
      for (final label in ['Home', 'Inbox', 'Reports'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    for (var i = 1; i < ys.length; i++) {
      expect(
        ys[i],
        greaterThan(ys[i - 1]),
        reason: 'row $i below row ${i - 1}',
      );
    }
  });

  testWidgets('without header and hide button the first row starts at the '
      'top padding', (tester) async {
    await tester.pumpWidget(_host());
    // 24 (safe area) + 24 (sidebar padding); no empty header row or gap.
    final firstRow = find.ancestor(
      of: find.text('Home'),
      matching: find.byType(InkWell),
    );
    expect(tester.getTopLeft(firstRow).dy, 48);
  });

  testWidgets('beside a body list, only the body follows the '
      'PrimaryScrollController', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: _scheme),
        home: PrimaryScrollController(
          controller: controller,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiquidSidebar(
                destinations: _destinations,
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                footer: const SizedBox(height: 500, child: Text('Profile')),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 100, child: Text('item $i')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(LiquidSidebar), const Offset(0, -300));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    final sidebarY = tester.getTopLeft(find.text('Profile')).dy;
    expect(find.text('item 0'), findsNothing);

    // What a status-bar tap does: scroll the primary controller to the top.
    controller.jumpTo(0);
    await tester.pump();

    expect(tester.getTopLeft(find.text('item 0')).dy, 0);
    expect(tester.getTopLeft(find.text('Profile')).dy, sidebarY);
  });

  testWidgets('selected row: primaryContainer, onPrimaryContainer w600', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selectedIndex: 2));
    final selected = tester.widget<Text>(find.text('Reports'));
    expect(selected.style!.color, _scheme.onPrimaryContainer);
    expect(selected.style!.fontWeight, FontWeight.w600);
    final other = tester.widget<Text>(find.text('Home'));
    expect(other.style!.color, _scheme.onSurface);
    expect(other.style!.fontWeight, FontWeight.w500);
    final fills = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.color == _scheme.primaryContainer);
    expect(fills, hasLength(1));
  });

  testWidgets('a tap reports the destination index', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));
    await tester.tap(find.text('Reports'));
    expect(selected, [2]);
  });

  testWidgets('semantics: selected state and badge in the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(selectedIndex: 1));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Inbox, 3 new')),
      matchesSemantics(
        label: 'Inbox, 3 new',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(find.text('3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('header, footer and hide button', (tester) async {
    var hidden = 0;
    await tester.pumpWidget(
      _host(
        header: const Text('My App'),
        footer: const Text('Profile'),
        onHide: () => hidden++,
      ),
    );
    expect(find.text('My App'), findsOneWidget);
    expect(find.byTooltip('Hide sidebar'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide sidebar'));
    expect(hidden, 1);
    // Footer pinned to the bottom: 600 − 20 (safe area) − 24 (padding).
    expect(tester.getBottomLeft(find.text('Profile')).dy, closeTo(556, 1));
  });

  testWidgets('no hide button without onHide', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byTooltip('Hide sidebar'), findsNothing);
  });

  testWidgets('the trailing action is the first row and never selected', (
    tester,
  ) async {
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
    expect(
      tester.getTopLeft(find.text('Search')).dy,
      lessThan(tester.getTopLeft(find.text('Home')).dy),
    );
    await tester.tap(find.text('Search'));
    expect(pressed, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Search')),
      matchesSemantics(label: 'Search', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('width and an end border in outlineVariant', (tester) async {
    await tester.pumpWidget(_host(width: 280));
    expect(tester.getSize(find.byType(LiquidSidebar)).width, 280);
    final border = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<BorderDirectional>()
        .single;
    expect(border.end.color, _scheme.outlineVariant);
  });

  testWidgets('scrolls instead of overflowing at large text', (tester) async {
    await tester.pumpWidget(
      _host(textScale: 3, footer: const SizedBox(height: 200)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls to the footer when content is taller than the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(footer: const SizedBox(height: 500, child: Text('Profile'))),
    );
    expect(tester.takeException(), isNull);
    final before = tester.getTopLeft(find.text('Profile')).dy;
    await tester.drag(find.byType(LiquidSidebar), const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Profile')).dy, lessThan(before));
  });

  testWidgets('rows start after the safe area on the leading side', (
    tester,
  ) async {
    // 40 (safe area) + 16 (sidebar padding) + 12 (row padding).
    await tester.pumpWidget(
      _host(padding: const EdgeInsets.only(left: 40, right: 10)),
    );
    expect(tester.getTopLeft(find.byIcon(Icons.home_outlined)).dx, 68);
    await tester.pumpWidget(
      _host(
        direction: TextDirection.rtl,
        padding: const EdgeInsets.only(left: 10, right: 40),
      ),
    );
    expect(
      tester.getTopRight(find.byIcon(Icons.home_outlined)).dx,
      tester.getTopRight(find.byType(LiquidSidebar)).dx - 68,
    );
  });

  testWidgets('the selected row draws selectedIcon, the others icon', (
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
}
