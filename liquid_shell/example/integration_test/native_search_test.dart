// The native search tab on real simulators (spec P3b §12.5).
//
// tool/integration_ios_native.sh runs it with EXPECT_NATIVE=true on iPhone
// and iPad, iOS 26.5 and 27.0, and with EXPECT_NATIVE=false on iOS 18 when
// that runtime exists (the Flutter search UI). It drives the native field
// through the plugin's debug hooks and checks both sides.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

/// Lets the platform answer and UIKit lay out: channel round trips and
/// layout passes take real time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

const _app = MaterialApp(debugShowCheckedModeBanner: false, home: SearchCase());

LiquidShellIOS get _ios => LiquidShellPlatform.instance as LiquidShellIOS;

/// The real iOS platform, also recording the page offsets the shell sends.
/// Installed before the first test: one instance receives every native
/// call (the Pigeon receiver belongs to the instance that started it).
class _RecordingIOS extends LiquidShellIOS {
  final scrolls = <(int, double)>[];

  @override
  Future<void> setNativePageScroll({required int tab, required double offset}) {
    scrolls.add((tab, offset));
    return super.setNativePageScroll(tab: tab, offset: offset);
  }
}

/// The scope seen by the search page's content.
LiquidShellScopeData _scope(WidgetTester tester) => LiquidShellScope.of(
  tester.element(
    find.byType(LiquidSearchScopeBar).evaluate().isNotEmpty
        ? find.byType(LiquidSearchScopeBar).first
        : find.byType(GridView).first,
  ),
);

/// The search case's controller.
LiquidSearchController _controller(WidgetTester tester) =>
    tester.widget<LiquidShell>(find.byType(LiquidShell)).search!.controller;

/// Whether the device is an iPad (the stacked field at the top).
bool _isPad(WidgetTester tester) =>
    MediaQueryData.fromView(tester.view).size.shortestSide >= 600;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (LiquidShellPlatform.instance is LiquidShellIOS) {
    LiquidShellPlatform.instance = _RecordingIOS();
  }

  Future<void> shot(String phase) =>
      binding.takeScreenshot('search_${_runName}_$phase');

  void expectResumed() => expect(
    WidgetsBinding.instance.lifecycleState,
    AppLifecycleState.resumed,
    reason: 'the Flutter view never leaves the window',
  );

  testWidgets('the search tab, phase by phase', (tester) async {
    await tester.pumpWidget(_app);
    await _settle(tester);
    final controller = _controller(tester);
    await shot('idle');

    // Select the search tab: a native proposal, Dart's guard, then UIKit.
    if (_expectNative) {
      await _ios.debugTap(NativeTapTarget.destination, 2);
    } else {
      await tester.tap(find.bySemanticsLabel('Search'));
    }
    await _settle(tester);
    expect(find.text('Nhạc Trịnh'), findsOneWidget, reason: 'categories');
    var scope = _scope(tester);
    final selectedInsets = scope.chromeInsets;
    expect(scope.searchPhase, LiquidSearchPhase.selected);
    expect(scope.nativePageBar, _expectNative);
    NativeRect? selectedField;
    if (_expectNative) {
      final snapshot = await _ios.debugSnapshot();
      final padding = MediaQuery.paddingOf(
        tester.element(find.byType(GridView)),
      );
      debugPrint(
        'liquid_shell search selected: placement ${snapshot.placement} '
        'field ${snapshot.fieldFrame.x},${snapshot.fieldFrame.y} '
        '${snapshot.fieldFrame.width}x${snapshot.fieldFrame.height} '
        'insets ${scope.chromeInsets} padding $padding',
      );
      expect(snapshot.selectedTab, 'destination2');
      expect(snapshot.searchActive, isFalse, reason: 'Q13: not focused');
      expect(snapshot.fieldFrame.width, greaterThan(100));
      expect(snapshot.placement, _isPad(tester) ? 'stacked' : isNot('stacked'));
      selectedField = snapshot.fieldFrame;
    }
    await shot('selected');

    // Activate: the field focuses; the keyboard inset reaches Flutter.
    if (_expectNative) {
      await _ios.debugTap(NativeTapTarget.searchField, 2);
    } else {
      await tester.tap(find.byType(TextField));
    }
    await _settle(tester);
    scope = _scope(tester);
    expect(scope.searchPhase, LiquidSearchPhase.active);
    expect(find.text('Recently searched'), findsOneWidget);
    if (_expectNative) {
      final snapshot = await _ios.debugSnapshot();
      expect(snapshot.searchActive, isTrue);
      expect(snapshot.firstResponderIsSearch, isTrue);
      // The keyboard observers (Task 5): the field's end position reaches
      // Flutter once the keyboard is up, and Flutter's insets cover it.
      final media = MediaQueryData.fromView(tester.view);
      final keyboard = media.viewInsets.bottom;
      final field = snapshot.fieldFrame;
      debugPrint(
        'liquid_shell search active: keyboard $keyboard '
        'field ${field.x},${field.y} ${field.width}x${field.height} '
        'insets ${scope.chromeInsets}',
      );
      expect(keyboard, greaterThan(0), reason: 'the software keyboard');
      if (_isPad(tester)) {
        expect(
          scope.chromeInsets.top,
          greaterThanOrEqualTo(field.y + field.height - 1),
          reason: 'the insets cover the stacked field',
        );
      } else {
        expect(
          field.y + field.height,
          lessThanOrEqualTo(media.size.height - keyboard + 1),
          reason: 'the field rides on the keyboard',
        );
        expect(field.y, lessThan(selectedField!.y - 100));
        expect(
          scope.chromeInsets.bottom,
          greaterThanOrEqualTo(media.size.height - field.y - 1),
          reason: 'Flutter heard the raised field: its insets cover it',
        );
      }
    }
    await shot('active');

    // Text from Dart (the user's typing is XCUITest's, Task 12).
    controller.text = 'ho hoan';
    await _settle(tester);
    expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
    if (_expectNative) {
      expect((await _ios.debugSnapshot()).searchText, 'ho hoan');
    }
    await shot('results');

    // A result pushes a detail inside the tab: the native back circle.
    await tester.tap(find.text('Hồ Hoàn Kiếm'));
    await _settle(tester);
    if (_expectNative) {
      final snapshot = await _ios.debugSnapshot();
      expect(snapshot.pageTitles, ['Search', 'Hồ Hoàn Kiếm']);
      expect(find.byType(LiquidBackButton), findsNothing);
      await shot('detail');
      await _ios.debugTap(NativeTapTarget.back, 2);
    } else {
      expect(find.byType(LiquidBackButton), findsOneWidget);
      await shot('detail');
      await tester.tap(find.byType(LiquidBackButton));
    }
    await _settle(tester);
    expect(
      find.text('Hồ Hoàn Kiếm'),
      findsOneWidget,
      reason: 'back on results',
    );
    if (_expectNative) {
      expect((await _ios.debugSnapshot()).pageTitles, ['Search']);
    }

    // Home and back: the query is kept (Q2).
    FocusManager.instance.primaryFocus?.unfocus();
    if (_expectNative) {
      await _ios.debugTap(NativeTapTarget.searchCancel, 2);
      await _settle(tester);
      expect(controller.text, '', reason: '× clears (native semantics)');
      controller.text = 'phố';
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.destination);
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.destination, 2);
      await _settle(tester);
      final snapshot = await _ios.debugSnapshot();
      expect(snapshot.searchText, 'phố');
      // The keyboard went down: the field and the insets are back.
      expect(MediaQueryData.fromView(tester.view).viewInsets.bottom, 0);
      expect(snapshot.fieldFrame.y, closeTo(selectedField!.y, 1));
      expect(_scope(tester).chromeInsets, selectedInsets);
    } else {
      await tester.tap(find.bySemanticsLabel('Cancel search'));
      await _settle(tester);
      expect(controller.text, '');
    }
    expect(controller.isActive, isFalse);
    await shot('cancelled');
    expectResumed();
  });

  testWidgets(
    'debug taps: the field needs the search tab; back on a root page '
    'does nothing',
    (tester) async {
      await tester.pumpWidget(_app);
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.searchField, 2);
      await _settle(tester);
      var snapshot = await _ios.debugSnapshot();
      expect(snapshot.selectedTab, 'destination0');
      expect(snapshot.searchActive, isFalse);
      expect(
        LiquidShellScope.of(
          tester.element(find.byType(ListView).first),
        ).searchPhase,
        LiquidSearchPhase.idle,
      );

      await _ios.debugTap(NativeTapTarget.destination, 2);
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.back, 2);
      await _settle(tester);
      snapshot = await _ios.debugSnapshot();
      expect(snapshot.selectedTab, 'destination2');
      expect(snapshot.pageTitles, ['Search']);
      expect(find.text('Nhạc Trịnh'), findsOneWidget);
      expect(_scope(tester).searchPhase, LiquidSearchPhase.selected);
    },
    skip: !_expectNative,
  );

  testWidgets(
    'N-5: the native back under a sheet in the tab closes the sheet',
    (tester) async {
      await tester.pumpWidget(_app);
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.destination, 2);
      await _settle(tester);
      _controller(tester).text = 'ho hoan';
      await _settle(tester);
      await tester.tap(find.text('Hồ Hoàn Kiếm'));
      await _settle(tester);
      // A sheet in the tab's navigator: the kept stack shows a live back.
      showModalBottomSheet<void>(
        context: tester.element(find.byType(Chip)),
        builder: (_) => const SizedBox(
          height: 240,
          child: Center(child: Text('Sheet')),
        ),
      ).ignore();
      await _settle(tester);
      expect(find.text('Sheet'), findsOneWidget);
      expect((await _ios.debugSnapshot()).pageTitles, [
        'Search',
        'Hồ Hoàn Kiếm',
      ]);
      await shot('sheet');

      await _ios.debugTap(NativeTapTarget.back, 2);
      await _settle(tester);
      expect(find.text('Sheet'), findsNothing, reason: 'the back pops it');
      expect(find.byType(Chip), findsOneWidget, reason: 'the detail stays');
      expect((await _ios.debugSnapshot()).pageTitles, [
        'Search',
        'Hồ Hoàn Kiếm',
      ]);

      await _ios.debugTap(NativeTapTarget.back, 2);
      await _settle(tester);
      expect((await _ios.debugSnapshot()).pageTitles, ['Search']);
    },
    skip: !_expectNative,
  );

  testWidgets(
    'N-4: a page without a scroll view replacing a scrolled one starts at '
    'offset 0',
    (tester) async {
      final recorder = LiquidShellPlatform.instance as _RecordingIOS;
      final navigator = GlobalKey<NavigatorState>();
      final search = LiquidSearchController();
      addTearDown(search.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StatefulBuilder(
            builder: (context, setState) => LiquidShell(
              destinations: const [
                LiquidDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                  sfSymbol: 'house',
                ),
                LiquidDestination(
                  icon: Icon(Icons.search),
                  label: 'Find',
                  role: LiquidDestinationRole.search,
                ),
              ],
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              search: LiquidSearch(controller: search),
              body: IndexedStack(
                index: index,
                children: [
                  const LiquidPage(title: 'Home', child: SizedBox.expand()),
                  Navigator(
                    key: navigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const LiquidPage(
                        title: 'Find',
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.destination, 1);
      await _settle(tester);
      navigator.currentState!
          .push(
            MaterialPageRoute<void>(
              builder: (_) => LiquidPage(
                title: 'Long',
                largeTitle: true,
                child: ListView.builder(
                  controller: scroll,
                  itemCount: 80,
                  itemExtent: 48,
                  itemBuilder: (_, i) => Text('Row $i'),
                ),
              ),
            ),
          )
          .ignore();
      await _settle(tester);
      // The page's top padding with its title at rest (offset 0), read
      // above the list (a ListView takes the padding from its children).
      double topOf(Finder finder) =>
          MediaQuery.paddingOf(tester.element(finder)).top;
      final restingTop = topOf(find.byType(ListView));
      scroll.jumpTo(300);
      await _settle(tester);
      expect((await _ios.debugSnapshot()).pageTitles, ['Find', 'Long']);
      expect(recorder.scrolls.last, (1, 300.0));
      final scrolledTop = topOf(find.byType(ListView));
      await shot('scrolled');

      navigator.currentState!
          .pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const LiquidPage(
                title: 'Plain',
                largeTitle: true,
                child: Material(child: Center(child: Text('No scroll view'))),
              ),
            ),
          )
          .ignore();
      await _settle(tester);
      expect((await _ios.debugSnapshot()).pageTitles, ['Find', 'Plain']);
      expect(
        recorder.scrolls.last,
        (1, 0.0),
        reason: 'the reused host drops the old offset',
      );
      // The replacing page starts at the resting padding. UIKit draws these
      // pushed large titles small (spec §7.2), so nothing collapses and the
      // held top keeps the padding while scrolled: this pins "no jump",
      // and the offset itself is pinned by the call above.
      final replacedTop = topOf(find.text('No scroll view'));
      debugPrint(
        'liquid_shell N-4 top: resting $restingTop scrolled $scrolledTop '
        'replaced $replacedTop',
      );
      expect(replacedTop, closeTo(restingTop, 1));
      await shot('replaced');
    },
    skip: !_expectNative,
  );
}
