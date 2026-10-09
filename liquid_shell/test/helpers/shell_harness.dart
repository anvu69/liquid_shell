import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// Home · Inbox (count 3) · Reports (sidebar only) · Settings (dot).
const kDestinations = [
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
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    label: 'Settings',
    badge: LiquidBadge.dot(),
  ),
];

/// Reference sizes from spec §10.2.
const kPhone = Size(393, 852);
const kPhoneLandscape = Size(932, 430);
const kTabletPortrait = Size(834, 1194);
const kTabletLandscape = Size(1194, 834);

/// Scaffolds a LiquidShell that owns its selection, like an app would.
class TestShell extends StatefulWidget {
  const TestShell({
    this.destinations = kDestinations,
    this.initialIndex = 0,
    this.selections,
    this.guard,
    this.onHidden,
    this.trailing,
    this.sidebarHeader,
    this.sidebarFooter,
    this.chromeBuilder,
    this.minimizeOnScroll = true,
    this.strings = const LiquidShellStrings(),
    this.pageBuilder,
    this.offstageBranches = false,
    this.nativeChrome = LiquidNativeChrome.auto,
    this.nativeSidebarFooter,
    super.key,
  });

  final List<LiquidDestination> destinations;
  final int initialIndex;
  final List<int>? selections;
  final LiquidBeforeDestinationChange? guard;
  final ValueChanged<int>? onHidden;
  final LiquidTabAction? trailing;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final LiquidChromeBuilder? chromeBuilder;
  final bool minimizeOnScroll;
  final LiquidShellStrings strings;

  /// Builds the page of one destination. Defaults to [TestPage].
  final Widget Function(int index)? pageBuilder;

  /// Keeps branches alive the way a router's indexed-stack shell route does
  /// (`Offstage` + `TickerMode`) instead of with an `IndexedStack`
  /// (`Visibility`).
  final bool offstageBranches;

  final LiquidNativeChrome nativeChrome;
  final LiquidNativeSidebarFooter? nativeSidebarFooter;

  @override
  State<TestShell> createState() => TestShellState();
}

class TestShellState extends State<TestShell> {
  late int index = widget.initialIndex;

  void select(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: widget.destinations,
    selectedIndex: index,
    onDestinationSelected: (i) {
      widget.selections?.add(i);
      select(i);
    },
    beforeDestinationChange: widget.guard,
    onSelectedDestinationHidden: widget.onHidden,
    tabBarTrailing: widget.trailing,
    sidebarHeader: widget.sidebarHeader,
    sidebarFooter: widget.sidebarFooter,
    chromeBuilder: widget.chromeBuilder,
    minimizeOnScroll: widget.minimizeOnScroll,
    strings: widget.strings,
    nativeChrome: widget.nativeChrome,
    nativeSidebarFooter: widget.nativeSidebarFooter,
    body: widget.offstageBranches
        ? Stack(
            fit: StackFit.expand,
            children: [
              for (final (i, page) in _pages.indexed)
                Offstage(
                  offstage: i != index,
                  child: TickerMode(enabled: i == index, child: page),
                ),
            ],
          )
        : IndexedStack(index: index, children: _pages),
  );

  List<Widget> get _pages => [
    for (final (i, d) in widget.destinations.indexed)
      widget.pageBuilder?.call(i) ?? TestPage(label: d.label),
  ];
}

/// A scrolling page with a tap counter, to prove its State survives.
class TestPage extends StatefulWidget {
  const TestPage({required this.label, super.key});

  final String label;

  @override
  State<TestPage> createState() => TestPageState();
}

class TestPageState extends State<TestPage> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey('list-${widget.label}'),
    padding: LiquidShellScope.contentPaddingOf(context),
    children: [
      TextButton(
        key: ValueKey('counter-${widget.label}'),
        onPressed: () => setState(() => taps++),
        child: Text('${widget.label} page: $taps'),
      ),
      for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('row $i')),
    ],
  );
}

/// Pumps [shell] in a MaterialApp on a window of [size] logical pixels.
Future<void> pumpShell(
  WidgetTester tester,
  Widget shell, {
  Size size = kPhone,
  EdgeInsets padding = const EdgeInsets.only(top: 59, bottom: 34),
  EdgeInsets? gestureInsets,
  TargetPlatform platform = TargetPlatform.iOS,
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    )
    ..viewPadding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    )
    ..systemGestureInsets = gestureInsets == null
        ? FakeViewPadding.zero
        : FakeViewPadding(bottom: gestureInsets.bottom);
  addTearDown(tester.view.reset);
  final base =
      theme ??
      ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
      );
  await tester.pumpWidget(
    MaterialApp(
      theme: base.copyWith(platform: platform),
      home: Directionality(textDirection: direction, child: shell),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Resizes the window and lets the bar measurement settle.
Future<void> resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// Fails when any [Text] in the tree, offstage included, has no text style
/// above it: the empty [DefaultTextStyle.fallback] (no app at all) or
/// `MaterialApp`'s red, double-underlined "fallback style" (no `Material`).
void expectNoFallbackText(WidgetTester tester) {
  final bad = <String>[
    for (final element in find.byType(Text, skipOffstage: false).evaluate())
      if (_isFallback(DefaultTextStyle.of(element).style))
        (element.widget as Text).data ?? '<rich text>',
  ];
  expect(bad, isEmpty, reason: 'Text drawn in the fallback style');
}

bool _isFallback(TextStyle style) =>
    style == const TextStyle() ||
    (style.debugLabel?.contains('fallback style') ?? false);

/// The scope data seen by the page of [label].
LiquidShellScopeData scopeOf(WidgetTester tester, [String label = 'Home']) =>
    LiquidShellScope.of(tester.element(find.byKey(ValueKey('list-$label'))));

/// Taps of the page of [label], even while it is offstage.
int tapsOf(WidgetTester tester, String label) => tester
    .state<TestPageState>(
      find.ancestor(
        of: find.byKey(ValueKey('list-$label'), skipOffstage: false),
        matching: find.byType(TestPage, skipOffstage: false),
      ),
    )
    .taps;
