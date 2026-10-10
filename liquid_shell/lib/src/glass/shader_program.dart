import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// The liquid lens program, loaded once per process (spec §5.1).
///
/// `null` until loaded, and forever if both asset keys fail or the engine
/// refuses the lens filter ([disable]); glass then stays frosted. Never
/// throws.
class LiquidShaderProgram extends ValueNotifier<ui.FragmentProgram?> {
  LiquidShaderProgram._() : super(null);

  /// The single instance.
  static final instance = LiquidShaderProgram._();

  /// Asset keys tried in order: an app loads a package's shader under
  /// `packages/<name>/`; this package's own tests only know the bare key.
  static const assetKeys = [
    'packages/liquid_shell/shaders/liquid_glass.frag',
    'shaders/liquid_glass.frag',
  ];

  /// Test hook replacing [assetKeys].
  @visibleForTesting
  static List<String>? debugAssetKeysOverride;

  Future<void>? _loading;
  bool _logged = false;
  bool _disabled = false;

  /// Loads the program; later calls return the same future.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    Object? failure;
    for (final key in debugAssetKeysOverride ?? assetKeys) {
      try {
        final program = await ui.FragmentProgram.fromAsset(key);
        if (!_disabled) value = program;
        return;
      } on Object catch (error) {
        failure = error;
      }
    }
    if (kDebugMode && !_logged) {
      _logged = true;
      debugPrint(
        'liquid_shell: liquid glass shader failed to load ($failure); '
        'drawing frosted.',
      );
    }
  }

  /// Drops the program for the rest of the session: building the lens
  /// filter threw [error], so the engine cannot draw it (spec §14). Every
  /// glass draws frosted from the next build. Reported once, in debug
  /// builds.
  void disable(Object error, StackTrace stack) {
    if (_disabled) return;
    _disabled = true;
    if (kDebugMode) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'liquid_shell',
          context: ErrorDescription(
            'while building the liquid glass filter; drawing frosted',
          ),
        ),
      );
    }
    // Called while painting: rebuild after this frame, not during it.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => value = null,
      debugLabel: 'LiquidShaderProgram.disable',
    );
  }

  /// Test hook: forgets the program, so the next test loads it again.
  /// Called by `debugResetLiquidGlassSignals` (not annotated
  /// `@visibleForTesting`, because that function lives in `lib/`).
  void debugReset() {
    _loading = null;
    _logged = false;
    _disabled = false;
    value = null;
  }
}
