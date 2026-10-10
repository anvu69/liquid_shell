import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

/// Records registrations like a shell does.
class _Registry implements PageRegistry {
  final records = <_Record>[];
  final offsets = <double>[];

  /// Most registrations alive at once.
  int peak = 0;

  List<String> stack() => [
    for (final e in pageStackFor(
      records.map((r) => r.entry),
      isTop: (e) => e.isTop,
    ))
      e.title,
  ];

  @override
  PageHandle registerPage(PageEntry entry) {
    final record = _Record(this, entry);
    records.add(record);
    if (records.length > peak) peak = records.length;
    return record;
  }
}

class _Record implements PageHandle {
  _Record(this.registry, this.entry);

  final _Registry registry;
  PageEntry entry;

  @override
  void update(PageEntry entry) => this.entry = entry;

  @override
  void scrolled(double offset) => registry.offsets.add(offset);

  @override
  void unregister() => registry.records.remove(this);
}

LiquidShellScopeData _scope({
  bool nativePageBar = false,
  LiquidSearchPhase? phase,
  LiquidSizeClass sizeClass = LiquidSizeClass.compact,
}) => LiquidShellScopeData(
  sizeClass: sizeClass,
  chromeKind: LiquidChromeKind.hidden,
  chromeInsets: EdgeInsets.zero,
  sidebarVisible: false,
  setSidebarVisible: (_) {},
  searchPhase: phase,
  nativePageBar: nativePageBar,
);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('taps $taps'),
      ),
      for (var i = 0; i < 40; i++) SizedBox(height: 40, child: Text('row $i')),
    ],
  );
}

/// A root page whose key the test changes while another page covers it.
class _Rekey extends StatefulWidget {
  const _Rekey();

  @override
  State<_Rekey> createState() => _RekeyState();
}

class _RekeyState extends State<_Rekey> {
  int _key = 0;

  void rekey() => setState(() => _key++);

  @override
  Widget build(BuildContext context) => LiquidPage(
    key: ValueKey(_key),
    title: 'Root',
    child: const _Counter(),
  );
}

Future<_Registry> _pump(
  WidgetTester tester, {
  LiquidShellScopeData? data,
  Widget home = const LiquidPage(title: 'Search', child: _Counter()),
}) async {
  final registry = _Registry();
  await tester.pumpWidget(
    ShellScopeMarker(
      data: data ?? _scope(),
      registry: null,
      pages: registry,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return registry;
}

void main() {
  testWidgets('pages register in push order; a pop shortens the stack', (
    tester,
  ) async {
    final registry = await _pump(tester);
    expect(registry.stack(), ['Search']);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const LiquidPage(title: 'Hồ Hoàn Kiếm', child: _Counter()),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(registry.stack(), ['Search', 'Hồ Hoàn Kiếm']);
    navigator.pop();
    await tester.pump(); // the pop has started: the lower route is current
    expect(registry.stack(), ['Search']);
    await tester.pumpAndSettle();
    expect(registry.records, hasLength(1));
  });

  testWidgets('only the visible branch makes the stack', (tester) async {
    final registry = await _pump(
      tester,
      home: const IndexedStack(
        index: 1,
        children: [
          LiquidPage(title: 'Home', child: _Counter()),
          LiquidPage(title: 'Search', child: _Counter()),
        ],
      ),
    );
    expect(registry.records, hasLength(2));
    expect(registry.stack(), ['Search']);
  });

  testWidgets('the visible branch is the top whatever its order', (
    tester,
  ) async {
    final registry = await _pump(
      tester,
      home: const IndexedStack(
        children: [
          LiquidPage(title: 'Home', child: _Counter()),
          LiquidPage(title: 'Search', child: _Counter()),
        ],
      ),
    );
    expect(registry.stack(), ['Home']);
  });

  testWidgets('a page replaced under a new key leaves before the new one '
      'registers', (tester) async {
    final registry = _Registry();
    Widget app(int key) => ShellScopeMarker(
      data: _scope(),
      registry: null,
      pages: registry,
      child: MaterialApp(
        home: LiquidPage(
          key: ValueKey(key),
          title: 'Search',
          child: const _Counter(),
        ),
      ),
    );
    await tester.pumpWidget(app(1));
    await tester.pumpWidget(app(2));
    expect(registry.records, hasLength(1));
    expect(registry.peak, 1, reason: 'detached in deactivate');
  });

  testWidgets('a page moved under a GlobalKey stays registered once', (
    tester,
  ) async {
    final registry = _Registry();
    final key = GlobalKey();
    Widget app({required bool wrapped}) {
      final page = LiquidPage(
        key: key,
        title: 'Search',
        child: const _Counter(),
      );
      return ShellScopeMarker(
        data: _scope(),
        registry: null,
        pages: registry,
        child: MaterialApp(
          home: wrapped ? Padding(padding: EdgeInsets.zero, child: page) : page,
        ),
      );
    }

    await tester.pumpWidget(app(wrapped: false));
    await tester.pumpWidget(app(wrapped: true));
    expect(registry.records, hasLength(1));
    expect(registry.stack(), ['Search']);
  });

  testWidgets('a root page at compact width gets a large title, no back', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(FlutterPageBar), findsOneWidget);
    final bar = tester.widget<FlutterPageBar>(find.byType(FlutterPageBar));
    expect(bar.large, isTrue);
    expect(bar.canPop, isFalse);
    expect(find.byType(LiquidBackButton), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('the bar titles carry a text style without a Material above', (
    tester,
  ) async {
    // MaterialApp's fallback (no Material): red, double-underlined text.
    void expectStyled(String title) {
      final style = DefaultTextStyle.of(
        tester.element(
          find.descendant(
            of: find.byType(FlutterPageBar),
            matching: find.text(title),
          ),
        ),
      ).style;
      expect(style.debugLabel ?? '', isNot(contains('fallback style')));
      expect(style.decoration, isNot(TextDecoration.underline));
    }

    final navigator = GlobalKey<NavigatorState>();
    await _pump(
      tester,
      home: Navigator(
        key: navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) =>
              const LiquidPage(title: 'Large', child: SizedBox.expand()),
        ),
      ),
    );
    expectStyled('Large');
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const LiquidPage(title: 'Inline', child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectStyled('Inline');
  });

  testWidgets('a pushed page gets the glass back button, which pops', (
    tester,
  ) async {
    await _pump(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const LiquidPage(title: 'Detail', child: _Counter()),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackButton), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    await tester.tap(find.byType(LiquidBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('a root page with an inline title at regular width has no bar', (
    tester,
  ) async {
    await _pump(tester, data: _scope(sizeClass: LiquidSizeClass.regular));
    expect(find.byType(FlutterPageBar), findsNothing);
  });

  testWidgets('the large title hides while the search is active', (
    tester,
  ) async {
    await _pump(tester, data: _scope(phase: LiquidSearchPhase.active));
    final bar = tester.widget<FlutterPageBar>(find.byType(FlutterPageBar));
    expect(bar.hideLargeTitle, isTrue);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets(
    'under a native bar nothing is drawn and the child keeps its state',
    (
      tester,
    ) async {
      final registry = _Registry();
      Widget app({required bool native}) => ShellScopeMarker(
        data: _scope(nativePageBar: native),
        registry: null,
        pages: registry,
        child: const MaterialApp(
          home: LiquidPage(title: 'Search', child: _Counter()),
        ),
      );
      await tester.pumpWidget(app(native: false));
      await tester.tap(find.text('taps 0'));
      await tester.pump();
      await tester.pumpWidget(app(native: true));
      await tester.pump();
      expect(find.byType(FlutterPageBar), findsNothing);
      expect(find.text('taps 1'), findsOneWidget, reason: 'same State');
      await tester.pumpWidget(app(native: false));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);
    },
  );

  testWidgets('the first vertical scroll view reports its offset', (
    tester,
  ) async {
    final registry = await _pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(registry.offsets, isNotEmpty);
    expect(registry.offsets.last, greaterThan(100));
  });

  testWidgets('LiquidBackButton reads its label from the shell strings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShellScopeMarker(
        data: _scope(),
        registry: null,
        strings: const LiquidShellStrings(back: 'Quay lại'),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: LiquidBackButton(onPressed: () {})),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Quay lại'), findsOneWidget);
    expect(tester.getSize(find.byType(LiquidBackButton)), const Size(44, 44));
  });

  test('searchPhase and nativePageBar join the scope equality', () {
    expect(_scope(), _scope());
    expect(_scope(phase: LiquidSearchPhase.selected), isNot(_scope()));
    expect(_scope(nativePageBar: true), isNot(_scope()));
    expect(
      _scope(nativePageBar: true).hashCode,
      _scope(nativePageBar: true).hashCode,
    );
  });

  testWidgets('a lower page recreated under a new key keeps its place', (
    tester,
  ) async {
    final registry = await _pump(tester, home: const _Rekey());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const LiquidPage(title: 'Detail', child: _Counter()),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    tester.state<_RekeyState>(find.byType(_Rekey, skipOffstage: false)).rekey();
    await tester.pump();
    expect(registry.records, hasLength(2));
    expect(registry.stack(), ['Root', 'Detail']);
  });

  testWidgets('the back label follows the shell strings', (tester) async {
    Widget app(String back) => ShellScopeMarker(
      data: _scope(),
      registry: null,
      strings: LiquidShellStrings(back: back),
      child: const MaterialApp(
        home: LiquidPage(title: 'Search', child: _Counter()),
      ),
    );
    await tester.pumpWidget(app('A'));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const LiquidPage(title: 'Detail', child: _Counter()),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('A'), findsOneWidget);
    await tester.pumpWidget(app('B'));
    await tester.pump();
    expect(find.bySemanticsLabel('B'), findsOneWidget);
    expect(find.bySemanticsLabel('A'), findsNothing);
  });

  testWidgets('content scrolled up fades out above the large title row', (
    tester,
  ) async {
    const red = Color(0xFFFF0000);
    final boundary = GlobalKey();
    await _pump(
      tester,
      home: RepaintBoundary(
        key: boundary,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: LiquidPage(
            title: 'Search',
            child: ListView(
              children: const [
                SizedBox(height: 2000, child: ColoredBox(color: red)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pump();
    final image = (await tester.runAsync(
      () => captureImage(boundary.currentContext! as Element),
    ))!;
    final bytes = (await tester.runAsync(image.toByteData))!;
    int green(int x, int y) => bytes.getUint8((y * image.width + x) * 4 + 1);

    final x = image.width - 8;
    // The bar row (0–54) and the large title row (54–106) show no content.
    expect(green(x, 20), 255, reason: 'bar row');
    expect(green(x, 60), 255, reason: 'top of the large title row');
    // Below the bar the content is opaque.
    expect(green(x, 200), 0, reason: 'content below the bar');
  });
}
