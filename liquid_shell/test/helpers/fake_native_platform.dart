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

  /// What [readWindowControls] answers.
  LiquidWindowControls controls = LiquidWindowControls.zero;

  /// Number of [readWindowControls] calls.
  int controlReads = 0;

  final _native = StreamController<LiquidNativeEvent>.broadcast();

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
