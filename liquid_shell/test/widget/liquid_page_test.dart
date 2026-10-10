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
}
