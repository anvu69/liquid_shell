import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Test hook replacing the shader-filter probe. `null` (the default)
/// probes.
///
/// `flutter test` has no shader filters unless run with
/// `--enable-impeller`, so glass there is frosted by default; tests of the
/// liquid tier set this to `true` and inject a filter factory.
@visibleForTesting
bool? debugLiquidGlassCanRefractOverride;

/// Whether this device can draw the liquid lens: `ImageFilter.shader` is
/// supported (Impeller). False on Skia (Android 9 and lower) and the web,
/// which then draw frosted (spec 2026-10-10 §6).
bool liquidGlassCanRefract() =>
    debugLiquidGlassCanRefractOverride ??
    ui.ImageFilter.isShaderFilterSupported;

/// Process-wide platform signals.
///
/// Starts the platform stream when the first `LiquidGlass` mounts and
/// cancels it when the last one unmounts. Keeps the last value when the
/// stream closes; an error event resets to [LiquidPlatformSignals.none].
class LiquidSignalsController extends ChangeNotifier
    implements ValueListenable<LiquidPlatformSignals> {
  LiquidSignalsController._();

  /// The single instance.
  static final instance = LiquidSignalsController._();

  LiquidPlatformSignals _value = LiquidPlatformSignals.none;
  int _users = 0;
  StreamSubscription<LiquidPlatformSignals>? _subscription;

  @override
  LiquidPlatformSignals get value => _value;

  /// Registers one user; the first one starts the platform stream.
  void acquire() {
    _users++;
    if (_users == 1) {
      var logged = false;
      _subscription = LiquidShellPlatform.instance.watchSignals().listen(
        _set,
        onError: (Object error) {
          // Once per subscription: a broken channel repeats its error.
          if (kDebugMode && !logged) {
            logged = true;
            debugPrint('liquid_shell signals: $error; using none');
          }
          _set(LiquidPlatformSignals.none);
        },
      );
    }
  }

  /// Unregisters one user; the last one cancels the platform stream.
  void release() {
    if (_users == 0) return;
    _users--;
    if (_users == 0) _cancel();
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _set(LiquidPlatformSignals value) {
    if (value == _value) return;
    _value = value;
    notifyListeners();
  }
}

/// Test hook: forgets the platform signals, the stream and the once-only
/// debug logs, so the next test starts clean.
@visibleForTesting
void debugResetLiquidGlassSignals() {
  LiquidSignalsController.instance
    .._cancel()
    .._users = 0
    .._set(LiquidPlatformSignals.none);
  debugResetPolicyLogging();
  LiquidShaderProgram.instance.debugReset();
}
