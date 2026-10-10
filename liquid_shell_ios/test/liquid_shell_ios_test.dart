import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_ios/src/mapping.dart';
import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
import 'package:liquid_shell_ios/src/platform.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Records Dart → native calls; answers with [state] and [controls].
class _FakeHost extends NativeShellHostApi {
  final calls = <Object>[];
  NativeShellState state = NativeShellState(
    installed: true,
    compact: false,
    sidebar: NativeSidebar.tiled,
  );
  NativeWindowControls controls = NativeWindowControls(leading: 66, top: 24);
  PlatformException? failure;

  void _maybeFail() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<NativeShellState> attach() async {
    calls.add('attach');
    _maybeFail();
    return state;
  }

  @override
  Future<void> update(NativeChromeConfig config) async {
    calls.add(config);
    _maybeFail();
  }

  @override
  Future<void> setSidebarVisible(bool visible) async {
    calls.add('setSidebarVisible($visible)');
    _maybeFail();
  }

  @override
  Future<NativeWindowControls> windowControls() async {
    calls.add('windowControls');
    _maybeFail();
    return controls;
  }

  @override
  Future<void> debugTap(NativeTapTarget target, int index) async {
    calls.add('debugTap(${target.name}, $index)');
    _maybeFail();
  }

  @override
  Future<void> setSearchText(String text) async {
    calls.add('setSearchText($text)');
    _maybeFail();
  }

  @override
  Future<void> setSearchActive(bool active) async {
    calls.add('setSearchActive($active)');
    _maybeFail();
  }

  @override
  Future<void> setPageScroll(int tab, double offset) async {
    calls.add('setPageScroll($tab, $offset)');
    _maybeFail();
  }

  NativeDebugSnapshot snapshot = NativeDebugSnapshot(
    selectedTab: 'destination2',
    searchActive: true,
    searchText: 'hồ',
    placement: 'stacked',
    pageTitles: ['Search', 'Hồ Hoàn Kiếm'],
    fieldFrame: NativeRect(x: 20, y: 86, width: 780, height: 44),
    firstResponderIsSearch: true,
  );

  @override
  Future<NativeDebugSnapshot> debugSnapshot() async {
    calls.add('debugSnapshot');
    _maybeFail();
    return snapshot;
  }
}

const _config = LiquidNativeChromeConfig(
  engaged: true,
  tabs: [
    LiquidNativeTab(title: 'Home', sfSymbol: 'house', badge: '3'),
    LiquidNativeTab(title: 'Files', sfSymbol: 'folder', sidebarOnly: true),
  ],
  selectedIndex: 1,
  trailing: LiquidNativeAction(title: 'Search', sfSymbol: 'magnifyingglass'),
  footer: LiquidNativeFooter(
    title: 'Ann',
    subtitle: 'Profile',
    sfSymbol: 'person.crop.circle',
    semanticLabel: 'Ann, profile',
  ),
  tintArgb: 0xFF3D5AFE,
  dark: true,
  rtl: true,
  hidden: true,
  interactive: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LiquidShellPlatform original;
  setUp(() => original = LiquidShellPlatform.instance);
  tearDown(() {
    LiquidShellPlatform.instance = original;
    // Receiving is process-wide: forget the previous test's receiver.
    NativeShellFlutterApi.setUp(null);
  });

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Sends a native → Dart call; true when a receiver answered it.
  Future<bool> deliver(String method, List<Object?> args) async {
    var answered = false;
    await messenger.handlePlatformMessage(
      'dev.flutter.pigeon.liquid_shell_ios.NativeShellFlutterApi.$method',
      NativeShellFlutterApi.pigeonChannelCodec.encodeMessage(args),
      (reply) => answered = reply != null,
    );
    await pumpEventQueue();
    return answered;
  }

  /// Captures `debugPrint` until the test ends.
  List<String> captureLogs() {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = previous);
    return logs;
  }

  test('registerWith installs LiquidShellIOS, which keeps the signals', () {
    LiquidShellIOS.registerWith();
    expect(LiquidShellPlatform.instance, isA<LiquidShellIOS>());
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
    expect(LiquidShellPlatform.instance.supportsNativeChrome, isTrue);
  });

  test('attachNativeChrome maps the native state', () async {
    final host = _FakeHost();
    final state = await liquidShellIOSWithHost(host).attachNativeChrome();
    expect(
      state,
      const LiquidNativeShellState(
        installed: true,
        sidebar: LiquidNativeSidebar.tiled,
      ),
    );
    expect(host.calls, ['attach']);
  });

  test('every native unavailable reason and sidebar maps by name', () {
    for (final reason in NativeUnavailableReason.values) {
      final state = stateFromNative(
        NativeShellState(
          installed: false,
          compact: true,
          sidebar: NativeSidebar.hidden,
          unavailableReason: reason,
        ),
      );
      expect(state.unavailableReason?.name, reason.name);
      expect(state.compact, isTrue);
    }
    for (final sidebar in NativeSidebar.values) {
      final state = stateFromNative(
        NativeShellState(installed: true, compact: false, sidebar: sidebar),
      );
      expect(state.sidebar.name, sidebar.name);
      expect(state.unavailableReason, isNull);
    }
  });

  test('a failed attach reports channelError instead of throwing', () async {
    final host = _FakeHost()..failure = PlatformException(code: 'gone');
    final state = await liquidShellIOSWithHost(host).attachNativeChrome();
    expect(state.installed, isFalse);
    expect(
      state.unavailableReason,
      LiquidNativeUnavailableReason.channelError,
    );
  });

  test('updateNativeChrome sends every field', () async {
    final host = _FakeHost();
    await liquidShellIOSWithHost(host).updateNativeChrome(_config);
    final sent = host.calls.single as NativeChromeConfig;
    expect(sent.engaged, isTrue);
    expect(sent.tabs.map((t) => t.title), ['Home', 'Files']);
    expect(sent.tabs.map((t) => t.sfSymbol), ['house', 'folder']);
    expect(sent.tabs.map((t) => t.badge), ['3', null]);
    expect(sent.tabs.map((t) => t.sidebarOnly), [false, true]);
    expect(sent.selectedIndex, 1);
    expect(sent.trailing?.title, 'Search');
    expect(sent.trailing?.sfSymbol, 'magnifyingglass');
    expect(sent.footer?.title, 'Ann');
    expect(sent.footer?.subtitle, 'Profile');
    expect(sent.footer?.sfSymbol, 'person.crop.circle');
    expect(sent.footer?.semanticLabel, 'Ann, profile');
    expect(sent.tintArgb, 0xFF3D5AFE);
    expect(sent.dark, isTrue);
    expect(sent.rtl, isTrue);
    expect(sent.hidden, isTrue);
    expect(sent.interactive, isFalse);

    final dormant = configToNative(LiquidNativeChromeConfig.dormant);
    expect(dormant.engaged, isFalse);
    expect(dormant.trailing, isNull);
    expect(dormant.footer, isNull);
  });

  test('setNativeSidebarVisible and debugTap reach the host', () async {
    final host = _FakeHost();
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativeSidebarVisible(visible: false);
    await platform.debugTap(NativeTapTarget.footer);
    expect(host.calls, ['setSidebarVisible(false)', 'debugTap(footer, 0)']);
  });

  test('failed calls are swallowed and logged once per method', () async {
    final logs = captureLogs();
    final host = _FakeHost()..failure = PlatformException(code: 'gone');
    final platform = liquidShellIOSWithHost(host);
    for (var i = 0; i < 2; i++) {
      await platform.attachNativeChrome();
      await platform.updateNativeChrome(_config);
      await platform.setNativeSidebarVisible(visible: true);
      await platform.readWindowControls();
      await platform.debugTap(NativeTapTarget.destination, 1);
    }
    expect(host.calls, hasLength(10));
    expect(logs, [
      'liquid_shell native: attach failed (gone); falling back',
      'liquid_shell native: update failed (gone); falling back',
      'liquid_shell native: setSidebarVisible failed (gone); falling back',
      'liquid_shell native: windowControls failed (gone); falling back',
      'liquid_shell native: debugTap failed (gone); falling back',
    ]);
  });

  test('nothing is received before the first attach, read or listen', () async {
    liquidShellIOSWithHost(_FakeHost());
    // No receiver yet: the channel buffers the call instead of answering.
    expect(await deliver('onTrailingTapped', []), isFalse);
  });

  test('attachNativeChrome starts receiving; unheard events drop', () async {
    final platform = liquidShellIOSWithHost(_FakeHost());
    await platform.attachNativeChrome();
    // Answered, but nothing listens yet: the event is dropped, not queued.
    expect(await deliver('onFooterTapped', []), isTrue);

    final events = <LiquidNativeEvent>[];
    final subscription = platform.nativeEvents.listen(events.add);
    addTearDown(subscription.cancel);
    expect(await deliver('onDestinationTapped', [1]), isTrue);
    expect(events, [const LiquidNativeDestinationTapped(1)]);
  });

  test('readWindowControls starts receiving too', () async {
    final platform = liquidShellIOSWithHost(_FakeHost());
    await platform.readWindowControls();
    expect(await deliver('onTrailingTapped', []), isTrue);

    final events = <LiquidNativeEvent>[];
    final subscription = platform.nativeEvents.listen(events.add);
    addTearDown(subscription.cancel);
    expect(
      await deliver('onWindowControlsChanged', [
        NativeWindowControls(leading: 66, top: 30),
      ]),
      isTrue,
    );
    expect(events, [
      const LiquidWindowControlsChanged(
        LiquidWindowControls(leading: 66, top: 30),
      ),
    ]);
  });

  test('readWindowControls sanitizes; a failure reads zero', () async {
    final host = _FakeHost();
    final platform = liquidShellIOSWithHost(host);
    expect(
      await platform.readWindowControls(),
      const LiquidWindowControls(leading: 66, top: 24),
    );
    host.controls = NativeWindowControls(leading: -3, top: double.nan);
    expect(await platform.readWindowControls(), LiquidWindowControls.zero);
    host.failure = PlatformException(code: 'gone');
    expect(await platform.readWindowControls(), LiquidWindowControls.zero);
  });

  test('native calls arrive on nativeEvents through the channel', () async {
    final platform = liquidShellIOSWithHost(_FakeHost());
    final events = <LiquidNativeEvent>[];
    final subscription = platform.nativeEvents.listen(events.add);
    addTearDown(subscription.cancel);

    await deliver('onDestinationTapped', [2]);
    await deliver('onTrailingTapped', []);
    await deliver('onFooterTapped', []);
    await deliver('onStateChanged', [
      NativeShellState(
        installed: true,
        compact: true,
        sidebar: NativeSidebar.hidden,
      ),
    ]);
    await deliver('onWindowControlsChanged', [
      NativeWindowControls(leading: 66, top: -1),
    ]);
    await pumpEventQueue();

    expect(events, hasLength(5));
    expect(events[0], const LiquidNativeDestinationTapped(2));
    expect(events[1], isA<LiquidNativeTrailingTapped>());
    expect(events[2], isA<LiquidNativeFooterTapped>());
    expect(
      (events[3] as LiquidNativeStateChanged).state,
      const LiquidNativeShellState(installed: true, compact: true),
    );
    expect(
      (events[4] as LiquidWindowControlsChanged).controls,
      const LiquidWindowControls(leading: 66),
    );
  });

  test('updateNativeChrome sends search, pages and the placeholder', () async {
    final host = _FakeHost();
    await liquidShellIOSWithHost(host).updateNativeChrome(
      const LiquidNativeChromeConfig(
        engaged: true,
        tabs: [
          LiquidNativeTab(title: 'Home', sfSymbol: 'house'),
          LiquidNativeTab(
            title: 'Search',
            sfSymbol: '',
            search: true,
            pages: [
              LiquidNativePage(title: 'Search', largeTitle: true),
              LiquidNativePage(title: 'Hồ Hoàn Kiếm'),
            ],
          ),
        ],
        search: LiquidNativeSearchConfig(placeholder: 'Songs, places'),
      ),
    );
    final sent = host.calls.single as NativeChromeConfig;
    expect(sent.tabs.map((t) => t.search), [false, true]);
    expect(sent.tabs.first.pages, isEmpty);
    expect(sent.tabs.last.pages.map((p) => p.title), [
      'Search',
      'Hồ Hoàn Kiếm',
    ]);
    expect(sent.tabs.last.pages.map((p) => p.largeTitle), [true, null]);
    expect(sent.search?.placeholder, 'Songs, places');
  });

  test('no search config maps to null', () async {
    final host = _FakeHost();
    await liquidShellIOSWithHost(host).updateNativeChrome(_config);
    expect((host.calls.single as NativeChromeConfig).search, isNull);
  });

  test('search commands and page scroll reach the host', () async {
    final host = _FakeHost();
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativeSearchText('hồ');
    await platform.setNativeSearchActive(active: true);
    await platform.setNativePageScroll(tab: 2, offset: 48.5);
    expect(host.calls, [
      'setSearchText(hồ)',
      'setSearchActive(true)',
      'setPageScroll(2, 48.5)',
    ]);
  });

  test('a non-finite page scroll offset is not sent', () async {
    final host = _FakeHost();
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativePageScroll(tab: 0, offset: double.nan);
    await platform.setNativePageScroll(tab: 0, offset: double.infinity);
    expect(host.calls, isEmpty);
  });

  test('failed search commands are swallowed and logged once each', () async {
    final logs = captureLogs();
    final host = _FakeHost()..failure = PlatformException(code: 'gone');
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativeSearchText('a');
    await platform.setNativeSearchText('b');
    await platform.setNativeSearchActive(active: false);
    expect(logs.where((l) => l.contains('setSearchText')), hasLength(1));
    expect(logs.where((l) => l.contains('setSearchActive')), hasLength(1));
  });

  test('debugSnapshot passes the native snapshot through', () async {
    final host = _FakeHost();
    final snapshot = await liquidShellIOSWithHost(host).debugSnapshot();
    expect(snapshot.pageTitles, ['Search', 'Hồ Hoàn Kiếm']);
    expect(snapshot.placement, 'stacked');
    expect(host.calls, ['debugSnapshot']);
  });

  test('rectFromNative maps, and zeroes a non-finite rect', () {
    expect(
      rectFromNative(NativeRect(x: 8, y: 490, width: 330, height: 48)),
      const Rect.fromLTWH(8, 490, 330, 48),
    );
    expect(
      rectFromNative(NativeRect(x: double.nan, y: 0, width: 1, height: 1)),
      Rect.zero,
    );
  });

  test(
    'native search and back calls on the real channel arrive as events',
    () async {
      final platform = liquidShellIOSWithHost(_FakeHost());
      final events = <LiquidNativeEvent>[];
      final subscription = platform.nativeEvents.listen(events.add);
      addTearDown(subscription.cancel);

      expect(await deliver('onSearchTextChanged', ['hô', true]), isTrue);
      expect(await deliver('onSearchActiveChanged', [true]), isTrue);
      expect(await deliver('onSearchSubmitted', ['hồ']), isTrue);
      expect(
        await deliver('onSearchFieldChanged', [
          NativeRect(x: 8, y: 490, width: 330, height: 48),
        ]),
        isTrue,
      );
      expect(await deliver('onBackTapped', [2]), isTrue);

      expect(events, [
        const LiquidNativeSearchTextChanged('hô', composing: true),
        const LiquidNativeSearchActiveChanged(true),
        const LiquidNativeSearchSubmitted('hồ'),
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
        const LiquidNativeBackTapped(2),
      ]);
    },
  );
}
