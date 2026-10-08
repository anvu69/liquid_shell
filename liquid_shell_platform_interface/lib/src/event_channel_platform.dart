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
/// Failures never surface as errors. A missing plugin or a failed `listen`
/// emits [LiquidPlatformSignals.none]; an error event emits
/// [LiquidPlatformSignals.none] and the stream keeps listening. Failures are
/// logged with `debugPrint` in debug builds only.
class EventChannelLiquidShellPlatform extends LiquidShellPlatform {
  /// The signal channel. Visible so tests can mock it.
  @visibleForTesting
  static const channel = EventChannel('vn.lasoai.liquid_shell/signals');

  static bool _loggedListenFailure = false;

  /// Lets tests observe the once-only listen-failure log again.
  @visibleForTesting
  static void debugResetLogging() => _loggedListenFailure = false;

  @override
  Stream<LiquidPlatformSignals> watchSignals() {
    final messenger = channel.binaryMessenger;
    final methods = MethodChannel(channel.name, channel.codec);
    late final StreamController<LiquidPlatformSignals> controller;

    Future<void> onListen() async {
      messenger.setMessageHandler(channel.name, (data) async {
        if (data == null) {
          await controller.close();
          return null;
        }
        try {
          controller.add(
            LiquidPlatformSignals.fromMap(channel.codec.decodeEnvelope(data)),
          );
        } on PlatformException catch (error) {
          _debugLog('error event ${error.code}; using none');
          controller.add(LiquidPlatformSignals.none);
        }
        return null;
      });
      try {
        await methods.invokeMethod<void>('listen');
      } on MissingPluginException catch (error) {
        _listenFailed(error);
        controller.add(LiquidPlatformSignals.none);
      } on PlatformException catch (error) {
        _listenFailed(error);
        controller.add(LiquidPlatformSignals.none);
      }
    }

    Future<void> onCancel() async {
      messenger.setMessageHandler(channel.name, null);
      try {
        await methods.invokeMethod<void>('cancel');
      } on MissingPluginException {
        // Nothing was listening natively.
      } on PlatformException {
        // The native side is already gone; nothing to clean up here.
      }
    }

    controller = StreamController<LiquidPlatformSignals>(
      onListen: onListen,
      onCancel: onCancel,
    );
    return controller.stream;
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
