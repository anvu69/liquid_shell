import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Installs a platform that reports native chrome installed, as an
/// opted-in app on iOS 26 does, until the current test ends.
InstalledNative installNative() {
  final original = LiquidShellPlatform.instance;
  final native = InstalledNative();
  LiquidShellPlatform.instance = native;
  addTearDown(() {
    LiquidShellPlatform.instance = original;
    unawaited(native._events.close());
  });
  return native;
}

/// Native chrome installed; [emit] plays a native event (a tab tap, the
/// field's text), as UIKit sends them.
class InstalledNative extends LiquidShellPlatform {
  // Synchronous, so the pump after [emit] builds what it changed.
  final _events = StreamController<LiquidNativeEvent>.broadcast(sync: true);

  /// Sends [event] to the shell.
  void emit(LiquidNativeEvent event) => _events.add(event);

  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(LiquidPlatformSignals.none);

  @override
  bool get supportsNativeChrome => true;

  @override
  Future<LiquidNativeShellState> attachNativeChrome() async =>
      const LiquidNativeShellState(installed: true);

  @override
  Stream<LiquidNativeEvent> get nativeEvents => _events.stream;
}
