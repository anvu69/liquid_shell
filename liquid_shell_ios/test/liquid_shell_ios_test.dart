import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
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
  tearDown(() => LiquidShellPlatform.instance = original);

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
    final state = await LiquidShellIOS(hostApi: host).attachNativeChrome();
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
    final state = await LiquidShellIOS(hostApi: host).attachNativeChrome();
    expect(state.installed, isFalse);
    expect(
      state.unavailableReason,
      LiquidNativeUnavailableReason.channelError,
    );
  });

  test('updateNativeChrome sends every field', () async {
    final host = _FakeHost();
    await LiquidShellIOS(hostApi: host).updateNativeChrome(_config);
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
    final platform = LiquidShellIOS(hostApi: host);
    await platform.setNativeSidebarVisible(visible: false);
    await platform.debugTap(NativeTapTarget.footer);
    expect(host.calls, ['setSidebarVisible(false)', 'debugTap(footer, 0)']);
  });

  test('failed sends are swallowed', () async {
    final host = _FakeHost()..failure = PlatformException(code: 'gone');
    final platform = LiquidShellIOS(hostApi: host);
    await platform.updateNativeChrome(_config);
    await platform.updateNativeChrome(_config);
    await platform.setNativeSidebarVisible(visible: true);
    expect(host.calls, hasLength(3));
  });

  test('readWindowControls sanitizes; a failure reads zero', () async {
    final host = _FakeHost();
    final platform = LiquidShellIOS(hostApi: host);
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
    final platform = LiquidShellIOS(hostApi: _FakeHost());
    final events = <LiquidNativeEvent>[];
    final subscription = platform.nativeEvents.listen(events.add);
    addTearDown(subscription.cancel);

    const codec = NativeShellFlutterApi.pigeonChannelCodec;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<void> deliver(String method, List<Object?> args) async {
      await messenger.handlePlatformMessage(
        'dev.flutter.pigeon.liquid_shell_ios.NativeShellFlutterApi.$method',
        codec.encodeMessage(args),
        (_) {},
      );
    }

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
}
