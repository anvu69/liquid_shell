import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell_ios/src/mapping.dart';
import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// A [LiquidShellIOS] that talks to [hostApi] instead of the real channel.
@visibleForTesting
LiquidShellIOS liquidShellIOSWithHost(NativeShellHostApi hostApi) =>
    LiquidShellIOS._(hostApi);

/// The iOS platform: the event-channel signal reader plus the native
/// iOS 26 shell (iPhone and iPad) and the iPadOS window controls over the
/// Pigeon channel.
///
/// Registered by the generated plugin registrant. Apps never use it.
class LiquidShellIOS extends EventChannelLiquidShellPlatform {
  /// Creates the platform.
  ///
  /// Touches no channel: `registerWith` runs before `main`, when no
  /// binding exists yet. Native events are received from the first
  /// [attachNativeChrome], [readWindowControls] or [nativeEvents] listener.
  LiquidShellIOS() : this._(NativeShellHostApi());

  LiquidShellIOS._(this._host);

  /// Makes a [LiquidShellIOS] the active implementation.
  static void registerWith() {
    LiquidShellPlatform.instance = LiquidShellIOS();
  }

  final NativeShellHostApi _host;
  late final StreamController<LiquidNativeEvent> _events =
      StreamController.broadcast(onListen: _receive);
  final Set<String> _loggedFailures = {};
  bool _receiving = false;

  /// Starts receiving native → Dart calls. Idempotent.
  void _receive() {
    if (_receiving) return;
    _receiving = true;
    NativeShellFlutterApi.setUp(_NativeReceiver(_events.add));
  }

  @override
  bool get supportsNativeChrome => true;

  /// Native events. A broadcast stream: an event that arrives while
  /// nothing listens is dropped, not queued. Nothing is lost by that: the
  /// state and the window controls are answered again by
  /// [attachNativeChrome] and [readWindowControls], and a tap with no shell
  /// listening has nobody to act on it.
  @override
  Stream<LiquidNativeEvent> get nativeEvents => _events.stream;

  @override
  Future<LiquidNativeShellState> attachNativeChrome() async {
    _receive();
    try {
      return stateFromNative(await _host.attach());
    } on PlatformException catch (error) {
      _logOnce('attach', error);
      return const LiquidNativeShellState(
        installed: false,
        unavailableReason: LiquidNativeUnavailableReason.channelError,
      );
    }
  }

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) =>
      _send('update', () => _host.update(configToNative(config)));

  @override
  Future<void> setNativeSidebarVisible({required bool visible}) =>
      _send('setSidebarVisible', () => _host.setSidebarVisible(visible));

  @override
  Future<LiquidWindowControls> readWindowControls() async {
    _receive();
    try {
      return controlsFromNative(await _host.windowControls());
    } on PlatformException catch (error) {
      _logOnce('windowControls', error);
      return LiquidWindowControls.zero;
    }
  }

  @override
  Future<void> setNativeSearchText(String text) =>
      _send('setSearchText', () => _host.setSearchText(text));

  @override
  Future<void> setNativeSearchActive({required bool active}) =>
      _send('setSearchActive', () => _host.setSearchActive(active));

  @override
  Future<void> setNativePageScroll({
    required int tab,
    required double offset,
  }) async {
    // Checked at the boundary: a NaN or infinite offset never crosses.
    if (!offset.isFinite) return;
    await _send('setPageScroll', () => _host.setPageScroll(tab, offset));
  }

  /// Debug builds of the plugin report the native search and page state;
  /// release builds an empty snapshot. For integration tests.
  @visibleForTesting
  Future<NativeDebugSnapshot> debugSnapshot() => _host.debugSnapshot();

  /// Debug builds of the plugin run the code path of a user tap on
  /// [target]; release builds ignore it. For integration tests. Like every
  /// other call, a channel failure is logged once and never thrown.
  @visibleForTesting
  Future<void> debugTap(NativeTapTarget target, [int index = 0]) =>
      _send('debugTap', () => _host.debugTap(target, index));

  Future<void> _send(String what, Future<void> Function() call) async {
    try {
      await call();
    } on PlatformException catch (error) {
      _logOnce(what, error);
    }
  }

  /// Channel failures never throw into the shell: they fall back (Flutter
  /// chrome, zero window controls) and are logged once per call in debug.
  void _logOnce(String what, PlatformException error) {
    if (!kDebugMode || !_loggedFailures.add(what)) return;
    debugPrint(
      'liquid_shell native: $what failed (${error.code}); falling back',
    );
  }
}

/// Native → Dart calls, turned into interface events. Kept apart from
/// [LiquidShellIOS] so the Pigeon API is not part of its public surface.
final class _NativeReceiver implements NativeShellFlutterApi {
  _NativeReceiver(this._emit);

  final void Function(LiquidNativeEvent event) _emit;

  @override
  void onDestinationTapped(int index) =>
      _emit(LiquidNativeDestinationTapped(index));

  @override
  void onTrailingTapped() => _emit(const LiquidNativeTrailingTapped());

  @override
  void onFooterTapped() => _emit(const LiquidNativeFooterTapped());

  @override
  void onStateChanged(NativeShellState state) =>
      _emit(LiquidNativeStateChanged(stateFromNative(state)));

  @override
  void onWindowControlsChanged(NativeWindowControls controls) =>
      _emit(LiquidWindowControlsChanged(controlsFromNative(controls)));

  @override
  void onSearchTextChanged(String text, bool composing) =>
      _emit(LiquidNativeSearchTextChanged(text, composing: composing));

  @override
  void onSearchActiveChanged(bool active) =>
      _emit(LiquidNativeSearchActiveChanged(active));

  @override
  void onSearchSubmitted(String text) =>
      _emit(LiquidNativeSearchSubmitted(text));

  @override
  void onSearchFieldChanged(NativeRect frame) =>
      _emit(LiquidNativeSearchFieldChanged(rectFromNative(frame)));

  @override
  void onBackTapped(int tab) => _emit(LiquidNativeBackTapped(tab));
}
