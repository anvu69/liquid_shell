import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/cases/segments.dart';
import 'package:liquid_shell_example/main.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

void main() {
  testWidgets('no demo: the case list', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(CaseList), findsOneWidget);
    expect(find.byType(SearchCase), findsNothing);
  });

  testWidgets('demo search: the search case, with semantics on (XCUITest)', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp(demo: 'search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchCase), findsOneWidget);
    expect(find.byType(CaseList), findsNothing);
    expect(tester.binding.semanticsEnabled, isTrue);
    debugReleaseDemoSemantics();
  });

  testWidgets('demo search-guarded: the search case with guarded details', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp(demo: 'search-guarded'));
    await tester.pumpAndSettle();
    final shown = tester.widget<SearchCase>(find.byType(SearchCase));
    // flutter_test checks for live semantics handles before any tear-down.
    debugReleaseDemoSemantics();
    expect(shown.guardDetails, isTrue);
  });

  // VK-551: the search case as a page above the case list, as a person
  // opens it: an edge swipe on its root pops the whole case.
  for (final (demo, forced) in [
    ('search-above', null),
    ('search-above-liquid', LiquidGlassTier.liquid),
  ]) {
    testWidgets('demo $demo: the search case above the case list, forced '
        'tier $forced', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ExampleApp(demo: demo));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SearchCase));
      final semantics = tester.binding.semanticsEnabled;
      debugReleaseDemoSemantics();
      expect(semantics, isTrue);
      expect(LiquidGlassScope.policyOf(context).forcedTier, forced);
      expect(find.byType(CaseList, skipOffstage: false), findsOneWidget);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.byType(SearchCase), findsNothing);
      expect(find.byType(CaseList), findsOneWidget);
    });
  }

  // tool/tab_frames.sh: the native run (tabs) and the Flutter liquid run
  // (tabs-liquid) open the same basic case.
  for (final (demo, forced) in [
    ('tabs', null),
    ('tabs-liquid', LiquidGlassTier.liquid),
  ]) {
    testWidgets('demo $demo: the basic tabs case, forced tier $forced', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ExampleApp(demo: demo));
      await tester.pumpAndSettle();
      expect(find.byType(BasicTabsCase), findsOneWidget);
      expect(find.byType(CaseList), findsNothing);
      final context = tester.element(find.byType(BasicTabsCase));
      expect(LiquidGlassScope.policyOf(context).forcedTier, forced);
    });
  }

  // tool/segment_frames.sh (spec VK-550 §14.5): the Flutter run opens the
  // segments case in the Flutter liquid tier; `segments-native` is the
  // Runner's own UIKit screen, so Dart shows the case list under it.
  for (final (demo, forced) in [
    ('segments', null),
    ('segments-liquid', LiquidGlassTier.liquid),
  ]) {
    testWidgets('demo $demo: the segments case, forced tier $forced', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ExampleApp(demo: demo));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentsCase), findsOneWidget);
      expect(find.byType(CaseList), findsNothing);
      final context = tester.element(find.byType(SegmentsCase));
      expect(LiquidGlassScope.policyOf(context).forcedTier, forced);
    });
  }

  // The search demos are framed like a case opened from the list, so the
  // switch on their pages works (L4).
  testWidgets('demo search: the switch forces the liquid tier', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp(demo: 'search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SearchCase));
    debugReleaseDemoSemantics();
    expect(
      LiquidGlassScope.policyOf(context).forcedTier,
      LiquidGlassTier.liquid,
    );
  });

  // The minimize UI tests (spec VK-600 §12.5): a status-bar tap scrolls the
  // page to the top (a programmatic scroll), and "Next tab" selects the
  // next destination from the app, not from the bar. Semantics are on, so
  // XCUITest reads Flutter's rows.
  testWidgets(
    'demo minimize: a status-bar tap scrolls to the top; Next tab selects '
    'the next destination',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(402, 874)
        ..padding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ExampleApp(demo: 'minimize'));
      await tester.pumpAndSettle();
      final semantics = tester.binding.semanticsEnabled;
      debugReleaseDemoSemantics();
      expect(semantics, isTrue);
      expect(find.byType(CaseList), findsNothing);
      String title() => tester.widget<DemoPage>(find.byType(DemoPage)).title;
      expect(title(), 'Home');

      final list = find.descendant(
        of: find.byType(DemoPage),
        matching: find.byType(Scrollable),
      );
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(list).position;
      expect(position.pixels, greaterThan(100));
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.statusBar.name,
        SystemChannels.statusBar.codec.encodeMethodCall(
          const MethodCall('handleScrollToTop'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(position.pixels, 0);

      await tester.tap(find.text('Next tab'));
      await tester.pumpAndSettle();
      expect(title(), 'Explore');
      await tester.tap(find.text('Next tab'));
      await tester.pumpAndSettle();
      expect(title(), 'Settings');
      await tester.tap(find.text('Next tab'));
      await tester.pumpAndSettle();
      expect(title(), 'Home');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('an unknown demo falls back to the case list', (tester) async {
    await tester.pumpWidget(const ExampleApp(demo: 'nope'));
    expect(find.byType(CaseList), findsOneWidget);
    debugReleaseDemoSemantics();
  });
}
