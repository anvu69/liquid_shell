import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The liquid lens program, loaded once per process (spec §5.1).
///
/// `null` until loaded, and forever if both asset keys fail; glass then
/// stays frosted. Never throws.
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

  /// Loads the program; later calls return the same future.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    Object? failure;
    for (final key in debugAssetKeysOverride ?? assetKeys) {
      try {
        value = await ui.FragmentProgram.fromAsset(key);
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

  /// Test hook: forgets the program, so the next test loads it again.
  /// Called by `debugResetLiquidGlassSignals` (not annotated
  /// `@visibleForTesting`, because that function lives in `lib/`).
  void debugReset() {
    _loading = null;
    _logged = false;
    value = null;
  }
}
