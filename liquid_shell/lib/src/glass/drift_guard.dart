import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';

/// After every frame, asks each attached [RenderLiquidBackdrop] whether it
/// moved without repainting, so a lens under an ancestor that moved only
/// its layer is corrected one frame later (spec §5.3).
///
/// Registers one post-frame callback at a time and only while a backdrop
/// is attached; an idle app runs no frames, so it does no work.
class LiquidDriftGuard {
  LiquidDriftGuard._();

  /// The single instance.
  static final instance = LiquidDriftGuard._();

  final Set<RenderLiquidBackdrop> _backdrops = {};
  bool _scheduled = false;

  /// Number of attached backdrops, for tests.
  @visibleForTesting
  int get debugCount => _backdrops.length;

  /// Starts checking [backdrop] after each frame.
  void add(RenderLiquidBackdrop backdrop) {
    _backdrops.add(backdrop);
    _schedule();
  }

  /// Stops checking [backdrop].
  void remove(RenderLiquidBackdrop backdrop) => _backdrops.remove(backdrop);

  void _schedule() {
    if (_scheduled || _backdrops.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      for (final backdrop in _backdrops.toList()) {
        backdrop.checkDrift();
      }
      _schedule();
    }, debugLabel: 'LiquidDriftGuard');
  }
}
