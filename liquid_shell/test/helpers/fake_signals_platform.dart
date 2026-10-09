import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// A [LiquidShellPlatform] whose signals a test sets with [emit].
///
/// Every listener first receives [current], then every later [emit].
class FakeSignalsPlatform extends LiquidShellPlatform {
  final _changes = StreamController<LiquidPlatformSignals>.broadcast();

  /// The value a new listener receives first.
  LiquidPlatformSignals current = LiquidPlatformSignals.none;

  /// Number of active listeners.
  int listeners = 0;

  /// Sends [signals] to every listener.
  void emit(LiquidPlatformSignals signals) {
    current = signals;
    _changes.add(signals);
  }

  /// Sends an error event to every listener.
  void emitError(Object error) => _changes.addError(error);

  @override
  Stream<LiquidPlatformSignals> watchSignals() {
    late final StreamController<LiquidPlatformSignals> controller;
    StreamSubscription<LiquidPlatformSignals>? forward;
    controller = StreamController<LiquidPlatformSignals>(
      onListen: () {
        listeners++;
        controller.add(current);
        forward = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        listeners--;
        await forward?.cancel();
      },
    );
    return controller.stream;
  }
}

/// Installs a [FakeSignalsPlatform] until the current test ends.
FakeSignalsPlatform installFakeSignals() {
  final original = LiquidShellPlatform.instance;
  final fake = FakeSignalsPlatform();
  LiquidShellPlatform.instance = fake;
  addTearDown(() => LiquidShellPlatform.instance = original);
  return fake;
}
