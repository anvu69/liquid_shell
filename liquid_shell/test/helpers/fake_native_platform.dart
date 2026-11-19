import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import 'fake_signals_platform.dart';

/// An installed, regular-width native shell.
const kInstalled = LiquidNativeShellState(installed: true);

/// A platform with native chrome whose answers a test controls.
class FakeNativePlatform extends FakeSignalsPlatform {
  FakeNativePlatform({this.state = kInstalled});

  /// What [attachNativeChrome] answers, unless [attachGate] is set.
  LiquidNativeShellState state;

  /// When set, [attachNativeChrome] waits for it (the pending state).
  Completer<LiquidNativeShellState>? attachGate;

  /// Every config sent, in order.
  final configs = <LiquidNativeChromeConfig>[];

  /// Every `setNativeSidebarVisible` call.
  final sidebarCalls = <bool>[];

  /// Every `setNativeSearchText`.
  final searchTexts = <String>[];

  /// Every `setNativeSearchActive`.
  final searchActives = <bool>[];

  /// Number of `dismissNativeSearchKeyboard` calls.
  int searchKeyboardDismissals = 0;

  /// Every `setNativeSearchScope`.
  final searchScopes = <int>[];

  /// Every `setNativeMinimizeScroll`, as (tab, offset).
  final minimizeScrolls = <(int, double)>[];

  /// Number of `expandNativeTabBar` calls.
  int tabBarExpands = 0;

  /// Every `setNativePageScroll`, as (tab, offset).
  final pageScrolls = <(int, double)>[];

  /// What [readWindowControls] answers.
  LiquidWindowControls controls = LiquidWindowControls.zero;

  /// Number of [readWindowControls] calls.
  int controlReads = 0;

  // Synchronous, like a platform message handled before the next frame:
  // the `pump` after [emitNative] then builds what the event changed.
  // (Asynchronous delivery would land after that pump's frame check, so
  // a single pump would never draw it.)
  final _native = StreamController<LiquidNativeEvent>.broadcast(sync: true);

  /// The last config sent.
  LiquidNativeChromeConfig get last => configs.last;

  /// Sends a native event.
  void emitNative(LiquidNativeEvent event) => _native.add(event);

  /// Whether answers say native applied the engaged config
  /// (`engagedApplied`), as soon as they are given: the default, so a test
  /// that does not care about the hand-over (VK-1064) sees the shell engage
  /// at once. False: answers keep the [state]'s own value until [ack].
  bool autoAck = true;

  LiquidNativeShellState _answer(LiquidNativeShellState state) =>
      autoAck && state.installed && !state.engagedApplied
      ? _acked(state)
      : state;

  static LiquidNativeShellState _acked(LiquidNativeShellState state) =>
      _with(state, engagedApplied: true);

  static LiquidNativeShellState _with(
    LiquidNativeShellState state, {
    bool? engagedApplied,
    int? appliedEpoch,
  }) => LiquidNativeShellState(
    installed: state.installed,
    compact: state.compact,
    sidebar: state.sidebar,
    verticalBarSide: state.verticalBarSide,
    engagedApplied: engagedApplied ?? state.engagedApplied,
    appliedEpoch: appliedEpoch ?? state.appliedEpoch,
    unavailableReason: state.unavailableReason,
  );

  /// The native model (spec 2026-11-18 applied-epoch): when true, applying
  /// a config pushes a state with that config's `engaged` and `epoch`, as
  /// native does, once per change. Off by default: the platform then never
  /// echoes an epoch (0), the window-wide rule of dev.13.
  bool echoEpochs = false;

  /// With [echoEpochs], whether each config is applied as it arrives.
  /// False: native holds it until [applyLast].
  bool autoApply = true;

  /// Native applies the last config it got (and so every earlier one):
  /// pushes its `engaged` and `epoch` when they change the state.
  void applyLast() {
    if (configs.isNotEmpty) apply(configs.last);
  }

  /// Native applies [config]: pushes its `engaged` and `epoch` when they
  /// change the state.
  void apply(LiquidNativeChromeConfig config) {
    final next = _with(
      state,
      engagedApplied: config.engaged,
      appliedEpoch: config.epoch,
    );
    if (next == state) return;
    state = next;
    _native.add(LiquidNativeStateChanged(state));
  }

  /// Changes the state and pushes it, as UIKit does after a layout.
  void pushState(LiquidNativeShellState next) {
    state = _answer(next);
    _native.add(LiquidNativeStateChanged(state));
  }

  /// Pushes the current state with `engagedApplied: true`, as native does
  /// once it has applied an engaged config.
  void ack() {
    if (echoEpochs) return applyLast();
    state = _acked(state);
    _native.add(LiquidNativeStateChanged(state));
  }

  @override
  bool get supportsNativeChrome => true;

  @override
  Future<LiquidNativeShellState> attachNativeChrome() async {
    final answer = _answer(await (attachGate?.future ?? Future.value(state)));
    state = answer;
    return answer;
  }

  /// When set, [updateNativeChrome] completes only once it does (native
  /// still applying the config).
  Completer<void>? updateGate;

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) async {
    configs.add(config);
    await updateGate?.future;
    if (echoEpochs && autoApply) applyLast();
  }

  @override
  Future<void> setNativeSidebarVisible({required bool visible}) async =>
      sidebarCalls.add(visible);

  @override
  Future<void> setNativeSearchText(String text) async => searchTexts.add(text);

  @override
  Future<void> setNativeSearchActive({required bool active}) async =>
      searchActives.add(active);

  @override
  Future<void> dismissNativeSearchKeyboard() async =>
      searchKeyboardDismissals++;

  @override
  Future<void> setNativeSearchScope(int index) async => searchScopes.add(index);

  @override
  Future<void> setNativePageScroll({
    required int tab,
    required double offset,
  }) async => pageScrolls.add((tab, offset));

  @override
  Future<void> setNativeMinimizeScroll({
    required int tab,
    required double offset,
  }) async => minimizeScrolls.add((tab, offset));

  @override
  Future<void> expandNativeTabBar() async => tabBarExpands++;

  @override
  Future<LiquidWindowControls> readWindowControls() async {
    controlReads++;
    return controls;
  }

  @override
  Stream<LiquidNativeEvent> get nativeEvents => _native.stream;

  /// What [supportsNativeDialogs] answers (iOS: true).
  bool nativeDialogs = true;

  /// Every dialog request, in order.
  final dialogRequests = <LiquidNativeDialogRequest>[];

  /// Answers for the next requests, in order. When empty, a request waits
  /// for [dialogGate] (created on demand).
  final dialogAnswers = <LiquidNativeDialogResult>[];

  /// Completes the requests that found no queued answer.
  Completer<LiquidNativeDialogResult>? dialogGate;

  @override
  bool get supportsNativeDialogs => nativeDialogs;

  @override
  Future<LiquidNativeDialogResult> presentNativeDialog(
    LiquidNativeDialogRequest request,
  ) {
    dialogRequests.add(request);
    if (dialogAnswers.isNotEmpty) {
      return Future.value(dialogAnswers.removeAt(0));
    }
    return (dialogGate ??= Completer()).future;
  }
}

/// Installs a [FakeNativePlatform] until the current test ends.
FakeNativePlatform installFakeNative({
  LiquidNativeShellState state = kInstalled,
}) {
  final original = LiquidShellPlatform.instance;
  final fake = FakeNativePlatform(state: state);
  LiquidShellPlatform.instance = fake;
  addTearDown(() => LiquidShellPlatform.instance = original);
  return fake;
}
