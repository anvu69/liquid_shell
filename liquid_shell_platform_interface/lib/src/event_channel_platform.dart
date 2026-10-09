import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell_platform_interface/src/liquid_shell_platform.dart';
import 'package:liquid_shell_platform_interface/src/platform_signals.dart';

/// [LiquidShellPlatform] over one `EventChannel`, shared by the iOS and
/// Android packages.
///
/// Protocol: on `listen` the native side sends the current signals, then one
/// event per change; on `cancel` it removes every observer. Events are maps
/// decoded by [LiquidPlatformSignals.fromMap].
///
/// Any number of [watchSignals] streams may be listened to at once, from any
/// number of instances. They share one native stream: the first listener
/// starts it, a later listener first receives the latest value, and the
/// native side is cancelled only when the last listener leaves.
///
/// Failures never surface as errors. A missing plugin or a failed `listen`
/// emits [LiquidPlatformSignals.none]; an error event emits
/// [LiquidPlatformSignals.none] and the stream keeps listening. Failures are
/// logged with `debugPrint` in debug builds only.
class EventChannelLiquidShellPlatform extends LiquidShellPlatform {
  /// The signal channel. Visible so tests can mock it.
  @visibleForTesting
  static const channel = EventChannel('vn.lasoai.liquid_shell/signals');

  static bool _loggedListenFailure = false;

  // The message handler of a channel is global, so the native stream is
  // shared by every listener of every instance.
  static final Set<StreamController<LiquidPlatformSignals>> _listeners = {};
  static LiquidPlatformSignals? _latest;

  /// Lets tests observe the once-only listen-failure log again.
  @visibleForTesting
  static void debugResetLogging() => _loggedListenFailure = false;

  @override
  Stream<LiquidPlatformSignals> watchSignals() {
    late final StreamController<LiquidPlatformSignals> controller;
    controller = StreamController<LiquidPlatformSignals>(
      onListen: () => _join(controller),
      onCancel: () => _leave(controller),
    );
    return controller.stream;
  }

  static Future<void> _join(
    StreamController<LiquidPlatformSignals> controller,
  ) async {
    _listeners.add(controller);
    if (_listeners.length > 1) {
      final latest = _latest;
      if (latest != null) controller.add(latest);
      return;
    }
    await _start();
  }

  static Future<void> _leave(
    StreamController<LiquidPlatformSignals> controller,
  ) async {
    if (!_listeners.remove(controller) || _listeners.isNotEmpty) return;
    await _stop();
  }

  static Future<void> _start() async {
    channel.binaryMessenger.setMessageHandler(channel.name, (data) async {
      if (data == null) {
        // End of stream: close every listener; the last close stops us.
        for (final listener in [..._listeners]) {
          await listener.close();
        }
        return null;
      }
      try {
        _emit(
          LiquidPlatformSignals.fromMap(channel.codec.decodeEnvelope(data)),
        );
      } on PlatformException catch (error) {
        _debugLog('error event ${error.code}; using none');
        _emit(LiquidPlatformSignals.none);
      }
      return null;
    });
    try {
      await _methods.invokeMethod<void>('listen');
    } on MissingPluginException catch (error) {
      _listenFailed(error);
      _emit(LiquidPlatformSignals.none);
    } on PlatformException catch (error) {
      _listenFailed(error);
      _emit(LiquidPlatformSignals.none);
    }
  }

  static Future<void> _stop() async {
    _latest = null;
    channel.binaryMessenger.setMessageHandler(channel.name, null);
    try {
      await _methods.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // Nothing was listening natively.
    } on PlatformException {
      // The native side is already gone; nothing to clean up here.
    }
  }

  static MethodChannel get _methods =>
      MethodChannel(channel.name, channel.codec);

  static void _emit(LiquidPlatformSignals signals) {
    _latest = signals;
    for (final listener in [..._listeners]) {
      listener.add(signals);
    }
  }

  static void _listenFailed(Object error) {
    if (_loggedListenFailure) return;
    _loggedListenFailure = true;
    _debugLog('listen failed ($error); using none');
  }

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint('liquid_shell signals: $message');
  }
}
