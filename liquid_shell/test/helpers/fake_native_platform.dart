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

  /// Changes the state and pushes it, as UIKit does after a layout.
  void pushState(LiquidNativeShellState next) {
    state = next;
    _native.add(LiquidNativeStateChanged(next));
  }

  @override
  bool get supportsNativeChrome => true;

  @override
  Future<LiquidNativeShellState> attachNativeChrome() =>
      attachGate?.future ?? Future.value(state);

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) async =>
      configs.add(config);

  @override
  Future<void> setNativeSidebarVisible({required bool visible}) async =>
      sidebarCalls.add(visible);

  @override
  Future<void> setNativeSearchText(String text) async => searchTexts.add(text);

  @override
  Future<void> setNativeSearchActive({required bool active}) async =>
      searchActives.add(active);

  @override
  Future<void> setNativePageScroll({
    required int tab,
    required double offset,
  }) async => pageScrolls.add((tab, offset));

  @override
  Future<LiquidWindowControls> readWindowControls() async {
    controlReads++;
    return controls;
  }

  @override
  Stream<LiquidNativeEvent> get nativeEvents => _native.stream;
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
