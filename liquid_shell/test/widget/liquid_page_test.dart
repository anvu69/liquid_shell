import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/pages/page_title.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

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

/// The bar's [title] in the large style (bold).
Finder _largeTitle(String title) => find.descendant(
  of: find.byType(FlutterPageBar),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Text && w.data == title && w.style?.fontWeight == FontWeight.w700,
  ),
);

/// The bar's [title] in the inline style (semibold).
Finder _inlineTitle(String title) => find.descendant(
  of: find.byType(FlutterPageBar),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Text && w.data == title && w.style?.fontWeight == FontWeight.w600,
  ),
);

/// A page body that records the padding of each of its builds. With a
/// [controller] it is a list of 40 rows of 40 pt.
class _Padded extends StatelessWidget {
  const _Padded(this.paddings, {this.controller});

  final List<EdgeInsets> paddings;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    paddings.add(MediaQuery.paddingOf(context));
    if (controller == null) return const SizedBox.expand();
    return ListView(
      controller: controller,
      children: [
        for (var i = 0; i < 40; i++)
          SizedBox(height: 40, child: Text('row $i')),
      ],
    );
  }
}

/// Pumps a root page with a collapsing large title over a [_Padded] list.
Future<ScrollController> _pumpCollapsing(
  WidgetTester tester,
  List<EdgeInsets> paddings,
) async {
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await _pump(
    tester,
    home: LiquidPage(
      title: 'Library',
      largeTitle: true,
      child: _Padded(paddings, controller: scroll),
    ),
  );
  return scroll;
}

/// A scroll controller disposed when the test ends.
ScrollController _scroll() {
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  return scroll;
}

/// A list of 40 rows of 40 pt.
Widget _rows(ScrollController scroll) {
  // Its paddings are recorded, and not read.
  final paddings = <EdgeInsets>[];
  return _Padded(paddings, controller: scroll);
}

/// The top of the large title of a page titled 'Library'.
double _largeTop(WidgetTester tester) =>
    tester.getRect(_largeTitle('Library')).top;

/// Pumps a root page titled 'Library' with a collapsing large title over
/// [child], in a [Material] for text fields, and returns the large title's
/// resting top.
Future<double> _pumpLargeTitle(WidgetTester tester, Widget child) async {
  await _pump(
    tester,
    home: Material(
      child: LiquidPage(title: 'Library', largeTitle: true, child: child),
    ),
  );
  return _largeTop(tester);
}

/// Scrolls [scroll] to [offset] and pumps the frame.
Future<void> _jump(
  WidgetTester tester,
  ScrollController scroll,
  double offset,
) async {
  scroll.jumpTo(offset);
  await tester.pump();
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
    expect(bar.mode, PageTitleMode.largeInRow);
    expect(bar.canPop, isFalse);
    expect(find.byType(LiquidBackButton), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets("a root page's large title sits on the bar row, as UIKit's "
      'inline large title (Apple Music): content starts under that row', (
    tester,
  ) async {
    EdgeInsets? padding;
    await _pump(
      tester,
      home: LiquidPage(
        title: 'Search',
        child: Builder(
          builder: (context) {
            padding = MediaQuery.paddingOf(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final title = tester.getRect(
      find.descendant(
        of: find.byType(FlutterPageBar),
        matching: find.text('Search'),
      ),
    );
    expect(title.top, greaterThanOrEqualTo(0));
    expect(title.bottom, lessThanOrEqualTo(kPageBarExtent));
    expect(title.left, 16, reason: 'leading, like UIKit');
    expect(padding!.top, kPageBarExtent);
  });

  for (final sizeClass in LiquidSizeClass.values) {
    testWidgets('a root page with largeTitle: true draws its large title on '
        'a 52 pt row under the bar row, content under that row '
        '(${sizeClass.name})', (tester) async {
      final paddings = <EdgeInsets>[];
      await _pump(
        tester,
        data: _scope(sizeClass: sizeClass),
        home: LiquidPage(
          title: 'Library',
          largeTitle: true,
          child: _Padded(paddings),
        ),
      );
      final large = tester.getRect(_largeTitle('Library'));
      expect(large.top, greaterThanOrEqualTo(kPageBarExtent));
      expect(
        large.bottom,
        lessThanOrEqualTo(kPageBarExtent + kLargeTitleExtent),
      );
      expect(large.left, 16, reason: 'leading, like UIKit');
      expect(paddings.last.top, kPageBarExtent + kLargeTitleExtent);
      expect(find.byType(LiquidBackButton), findsNothing);
    });
  }

  testWidgets("a pushed page's title is inline whatever its largeTitle", (
    tester,
  ) async {
    await _pump(tester);
    final paddings = <EdgeInsets>[];
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => LiquidPage(
              title: 'Detail',
              largeTitle: true,
              child: _Padded(paddings),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(_largeTitle('Detail'), findsNothing);
    expect(
      tester.getRect(_inlineTitle('Detail')).bottom,
      lessThanOrEqualTo(kPageBarExtent),
    );
    expect(paddings.last.top, kPageBarExtent);
    expect(find.byType(LiquidBackButton), findsOneWidget);
  });

  testWidgets('a root page with largeTitle: false draws no bar', (
    tester,
  ) async {
    for (final sizeClass in LiquidSizeClass.values) {
      await _pump(
        tester,
        data: _scope(sizeClass: sizeClass),
        home: const LiquidPage(
          title: 'Plain',
          largeTitle: false,
          child: SizedBox.expand(),
        ),
      );
      expect(find.byType(FlutterPageBar), findsNothing, reason: '$sizeClass');
    }
  });

  testWidgets('scrolling collapses the large row and fades the inline '
      'title in', (tester) async {
    final scroll = await _pumpCollapsing(tester, []);
    final rest = tester.getRect(_largeTitle('Library')).top;
    const steps = <(double, double, double)>[
      // (offset, large row shift, inline opacity)
      (0, 0, 0),
      (26, 26, 0),
      (39, 39, 0.5),
      (52, 52, 1),
      (120, 52, 1),
    ];
    final tops = <double>[];
    for (final (offset, _, _) in steps) {
      scroll.jumpTo(offset);
      await tester.pump();
      tops.add(tester.getRect(_largeTitle('Library')).top);
    }
    expect(tops, [for (final (_, shift, _) in steps) rest - shift]);

    final opacities = <double>[];
    for (final (offset, _, _) in steps) {
      scroll.jumpTo(offset);
      await tester.pump();
      opacities.add(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: _inlineTitle('Library'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
      );
    }
    expect(opacities, [for (final (_, _, opacity) in steps) opacity]);

    // The large row is clipped to its own row, under the bar row.
    final clip = tester.getRect(
      find
          .ancestor(of: _largeTitle('Library'), matching: find.byType(ClipRect))
          .first,
    );
    expect(clip.top, kPageBarExtent);
    expect(clip.height, kLargeTitleExtent);
  });

  testWidgets('the scroll-edge fade follows the collapsing row', (
    tester,
  ) async {
    const red = Color(0xFFFF0000);
    final boundary = GlobalKey();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(
      tester,
      home: RepaintBoundary(
        key: boundary,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: LiquidPage(
            title: 'Library',
            largeTitle: true,
            child: ListView(
              controller: scroll,
              children: const [
                SizedBox(height: 2000, child: ColoredBox(color: red)),
              ],
            ),
          ),
        ),
      ),
    );
    scroll.jumpTo(26);
    await tester.pump();
    final image = (await tester.runAsync(
      () => captureImage(boundary.currentContext! as Element),
    ))!;
    final bytes = (await tester.runAsync(image.toByteData))!;
    int green(int x, int y) => bytes.getUint8((y * image.width + x) * 4 + 1);

    final x = image.width - 8;
    // The bar row (0–54) shows no content.
    expect(green(x, 20), 255, reason: 'bar row');
    // The large row moved up by 26: what is left of it ends at 80, and the
    // content below it is opaque.
    expect(green(x, 90), 0, reason: 'content right below the large row');
    expect(green(x, 300), 0, reason: 'content below the large row');
  });

  testWidgets("the page's top padding stays under the large row while the "
      'title collapses', (tester) async {
    final paddings = <EdgeInsets>[];
    final scroll = await _pumpCollapsing(tester, paddings);
    for (final offset in const <double>[0, 26, 52, 120]) {
      scroll.jumpTo(offset);
      await tester.pump();
      expect(
        paddings.last.top,
        kPageBarExtent + kLargeTitleExtent,
        reason: 'offset $offset',
      );
    }
  });

  testWidgets('the collapse never rebuilds the page', (tester) async {
    final paddings = <EdgeInsets>[];
    final scroll = await _pumpCollapsing(tester, paddings);
    final rest = tester.getRect(_largeTitle('Library')).top;
    final builds = paddings.length;
    for (var frame = 1; frame <= 10; frame++) {
      scroll.jumpTo(frame * 6);
      await tester.pump();
    }
    expect(
      tester.getRect(_largeTitle('Library')).top,
      lessThan(rest),
      reason: 'the title collapsed',
    );
    expect(paddings, hasLength(builds), reason: 'no build of the page');
  });

  testWidgets('IME: a focused, composing field in a collapsing page keeps '
      'its state and its composition through a scroll and a bar switch', (
    tester,
  ) async {
    final registry = _Registry();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final field = TextEditingController();
    addTearDown(field.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final page = LiquidPage(
      title: 'Library',
      largeTitle: true,
      child: ListView(
        controller: scroll,
        children: [
          TextField(controller: field, focusNode: focus),
          for (var i = 0; i < 40; i++)
            SizedBox(height: 40, child: Text('row $i')),
        ],
      ),
    );
    Widget app({required bool native}) => ShellScopeMarker(
      data: _scope(nativePageBar: native),
      registry: null,
      pages: registry,
      child: MaterialApp(home: Material(child: page)),
    );
    await tester.pumpWidget(app(native: false));
    await tester.showKeyboard(find.byType(TextField));
    // Telex mid-word: "hoa" is marked text, as an IME composes it.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'hoa',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.pump();
    final editable = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    tester.testTextInput.log.clear();

    scroll.jumpTo(30);
    await tester.pump();
    await tester.pumpWidget(app(native: true));
    await tester.pumpWidget(app(native: false));
    scroll.jumpTo(10);
    await tester.pump();

    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editable),
    );
    expect(focus.hasFocus, isTrue);
    expect(field.value.composing, const TextRange(start: 0, end: 3));
    expect(
      tester.testTextInput.log.map((call) => call.method),
      everyElement(
        isNot(
          anyOf(
            'TextInput.clearClient',
            'TextInput.setClient',
            'TextInput.setEditingState',
          ),
        ),
      ),
    );
  });

  testWidgets('a multi-line text field never moves the large title', (
    tester,
  ) async {
    final list = _scroll();
    // A composer under the list: the field, not flexible, is laid out and
    // reports first.
    final rest = await _pumpLargeTitle(
      tester,
      Column(
        children: [
          Expanded(child: _rows(list)),
          const TextField(maxLines: 2),
        ],
      ),
    );
    final field = find.descendant(
      of: find.byType(TextField),
      matching: find.byType(Scrollable),
    );
    double fieldOffset() =>
        tester.state<ScrollableState>(field).position.pixels;

    await tester.enterText(find.byType(TextField), 'một\nhai\nba');
    await tester.pumpAndSettle();
    expect(fieldOffset(), greaterThan(0), reason: 'the field scrolled');
    expect(_largeTop(tester), rest, reason: 'typing a third line');

    await _jump(tester, list, 120);
    expect(_largeTop(tester), rest - kLargeTitleExtent, reason: 'the list');

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(fieldOffset(), 0, reason: 'the field scrolled back');
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: 'clearing the field',
    );
  });

  testWidgets('of two lists side by side, only the first drives the large '
      'title', (tester) async {
    final first = _scroll();
    final second = _scroll();
    final rest = await _pumpLargeTitle(
      tester,
      Column(
        children: [
          Expanded(child: _rows(first)),
          Expanded(child: _rows(second)),
        ],
      ),
    );
    await _jump(tester, first, 120);
    expect(_largeTop(tester), rest - kLargeTitleExtent);
    await _jump(tester, second, 5);
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: 'the second list',
    );
    await _jump(tester, first, 26);
    expect(_largeTop(tester), rest - 26);
  });

  testWidgets('when the list that drives the large title is disposed, the '
      'next list to report drives it', (tester) async {
    final first = _scroll();
    final second = _scroll();
    final showFirst = ValueNotifier(true);
    addTearDown(showFirst.dispose);
    final rest = await _pumpLargeTitle(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: showFirst,
        builder: (context, show, _) => Column(
          children: [
            if (show)
              Expanded(key: const ValueKey('first'), child: _rows(first)),
            Expanded(key: const ValueKey('second'), child: _rows(second)),
          ],
        ),
      ),
    );
    await _jump(tester, first, 120);
    await _jump(tester, second, 30);
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: 'the first list drives',
    );

    showFirst.value = false;
    // The frame lays the second list out taller, which it reports after the
    // frame; the next frame draws the title.
    await tester.pump();
    await tester.pump();
    expect(_largeTop(tester), rest - 30, reason: 'the second list reported');
    await _jump(tester, second, 40);
    expect(_largeTop(tester), rest - 40);
  });

  testWidgets("a list nested in the page's list never drives the large "
      'title', (tester) async {
    final outer = _scroll();
    final inner = _scroll();
    // The inner list is laid out, and reports, before the outer one.
    final rest = await _pumpLargeTitle(
      tester,
      ListView(
        controller: outer,
        children: [
          SizedBox(height: 200, child: _rows(inner)),
          for (var i = 0; i < 40; i++)
            SizedBox(height: 40, child: Text('row $i')),
        ],
      ),
    );
    await _jump(tester, inner, 40);
    expect(_largeTop(tester), rest, reason: 'the nested list');
    await _jump(tester, outer, 26);
    expect(_largeTop(tester), rest - 26, reason: "the page's list");
  });

  testWidgets("in a PageView of lists, the first page's list drives the "
      'large title; once that page is disposed, the shown list takes over '
      'at its first scroll', (tester) async {
    final first = _scroll();
    final second = _scroll();
    final pages = PageController();
    addTearDown(pages.dispose);
    final rest = await _pumpLargeTitle(
      tester,
      PageView(controller: pages, children: [_rows(first), _rows(second)]),
    );
    await _jump(tester, first, 120);
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: "the first page's list",
    );

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    expect(first.hasClients, isFalse, reason: 'the first page is disposed');
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: 'the title keeps the last offset until a list reports',
    );
    await _jump(tester, second, 30);
    expect(_largeTop(tester), rest - 30, reason: "the shown page's list");
  });

  testWidgets("in a PageView whose pages stay alive, only the first page's "
      'list drives the large title', (tester) async {
    final first = _scroll();
    final second = _scroll();
    final pages = PageController();
    addTearDown(pages.dispose);
    final rest = await _pumpLargeTitle(
      tester,
      PageView(
        controller: pages,
        allowImplicitScrolling: true,
        children: [_rows(first), _rows(second)],
      ),
    );
    await _jump(tester, first, 120);
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: "the first page's list",
    );
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    expect(first.hasClients, isTrue, reason: 'the first page is kept');
    await _jump(tester, second, 30);
    expect(
      _largeTop(tester),
      rest - kLargeTitleExtent,
      reason: "the second page's list",
    );
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
    navigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const LiquidPage(title: 'Inline', child: SizedBox.expand()),
          ),
        )
        .ignore();
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

    // A collapsing title too: its row goes, and the padding with it.
    final paddings = <EdgeInsets>[];
    await _pump(
      tester,
      data: _scope(phase: LiquidSearchPhase.active),
      home: LiquidPage(
        title: 'Library',
        largeTitle: true,
        child: _Padded(paddings),
      ),
    );
    expect(find.text('Library'), findsNothing);
    expect(paddings.last.top, kPageBarExtent);
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

  testWidgets('content scrolled up fades out under the bar row', (
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
    // The bar row (0–54), which holds the large title, shows no content.
    expect(green(x, 20), 255, reason: 'bar row');
    // Below the bar the content is opaque.
    expect(green(x, 80), 0, reason: 'content right below the bar');
    expect(green(x, 200), 0, reason: 'content below the bar');
  });

  // Same API, same bar wherever the shell draws Flutter chrome: iOS before
  // 26, Android, `nativeChrome: off` and a `chromeBuilder` (the last two
  // on a platform that offers native chrome).
  group('the Flutter bar on every Flutter-chrome target', () {
    /// Pumps a phone shell whose Home tab is a root page with a collapsing
    /// title over a [_Padded] list, and returns the list's controller.
    Future<ScrollController> pumpHome(
      WidgetTester tester,
      List<EdgeInsets> paddings, {
      LiquidNativeChrome nativeChrome = LiquidNativeChrome.auto,
      LiquidChromeBuilder? chromeBuilder,
    }) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: kNative,
          nativeChrome: nativeChrome,
          chromeBuilder: chromeBuilder,
          pageBuilder: (i) => i == 0
              ? LiquidPage(
                  title: 'Home',
                  largeTitle: true,
                  child: _Padded(paddings, controller: scroll),
                )
              : TestPage(label: kNative[i].label),
        ),
        platform: defaultTargetPlatform,
      );
      return scroll;
    }

    /// The bar sits under the status bar (59 pt on [kPhone]); its large row
    /// collapses by 52 and the page's padding stays.
    Future<void> expectFlutterBar(
      WidgetTester tester,
      ScrollController scroll,
      List<EdgeInsets> paddings,
    ) async {
      final scope = LiquidShellScope.of(tester.element(find.byType(ListView)));
      expect(scope.nativeChrome, isFalse, reason: 'Flutter chrome');
      expect(scope.nativePageBar, isFalse);
      const barTop = 59.0;
      const padding = barTop + kPageBarExtent + kLargeTitleExtent;
      final rest = tester.getRect(_largeTitle('Home')).top;
      expect(rest, greaterThanOrEqualTo(barTop + kPageBarExtent));
      expect(paddings.last.top, padding);
      scroll.jumpTo(kLargeTitleExtent);
      await tester.pump();
      expect(tester.getRect(_largeTitle('Home')).top, rest - kLargeTitleExtent);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: _inlineTitle('Home'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
      expect(paddings.last.top, padding);
    }

    testWidgets('iOS before 26', (tester) async {
      final paddings = <EdgeInsets>[];
      final scroll = await pumpHome(tester, paddings);
      await expectFlutterBar(tester, scroll, paddings);
    }, variant: iosDevice);

    testWidgets('Android', (tester) async {
      final paddings = <EdgeInsets>[];
      final scroll = await pumpHome(tester, paddings);
      await expectFlutterBar(tester, scroll, paddings);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS 26 with nativeChrome: off', (tester) async {
      installFakeNative();
      final paddings = <EdgeInsets>[];
      final scroll = await pumpHome(
        tester,
        paddings,
        nativeChrome: LiquidNativeChrome.off,
      );
      await expectFlutterBar(tester, scroll, paddings);
    }, variant: iosDevice);

    testWidgets('iOS 26 with a chromeBuilder', (tester) async {
      installFakeNative();
      final paddings = <EdgeInsets>[];
      final scroll = await pumpHome(
        tester,
        paddings,
        chromeBuilder: (context, details, chrome) => chrome,
      );
      await expectFlutterBar(tester, scroll, paddings);
    }, variant: iosDevice);
  });
}
