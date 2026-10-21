import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

/// The frame loop of a lens widget: it advances a
/// [LensMotion] on wall time, clicks once per slot crossing, hands a
/// commit the app did not adopt back to the selection, and stops when
/// nothing moves. A tab bar and a segmented control share it.
class LensTicker {
  /// `motion`: the widget's motion, null until it lays out a track (only
  /// `extra` runs then). `selected`: the app's current selection, as a
  /// slot. `onFrame`: the widget's `setState`. `extra`: another motion
  /// advanced first on the same frame (the tab bar's minimize), true while
  /// it moves. `trace`: acceptance traces, once per tick with a motion.
  LensTicker({
    required this._vsync,
    required this._motion,
    required this._selected,
    required this._onFrame,
    this._extra,
    this._trace,
  });

  final TickerProvider _vsync;
  final LensMotion? Function() _motion;
  final int? Function() _selected;
  final VoidCallback _onFrame;
  final bool Function(double dt)? _extra;
  final void Function(Duration elapsed, LensFrame frame)? _trace;

  /// Created on the first kick: a widget nobody touches never makes one,
  /// and [dispose] must not create it (no ancestor lookups there).
  Ticker? _ticker;
  Duration _last = Duration.zero;
  bool _disposed = false;

  /// Starts the ticker if it is not running.
  void kick() {
    if (_disposed) return;
    final ticker = _ticker ??= _vsync.createTicker(_onTick);
    if (ticker.isActive) return;
    _last = Duration.zero;
    unawaited(_start(ticker));
  }

  /// Stops and releases the ticker; later kicks do nothing.
  void dispose() {
    _disposed = true;
    _ticker?.dispose();
  }

  // A future of our own to hand to `unawaited`: newer SDKs mark
  // `Ticker.start` `@awaitNotRequired` (unnecessary_unawaited) while 3.44
  // still asks for it (discarded_futures).
  // The future ends when the ticker stops; nothing waits for it.
  static Future<void> _start(Ticker ticker) async {
    await ticker.start();
  }

  void _onTick(Duration elapsed) {
    // Wall time, as Core Animation: a long frame moves the lens on. The
    // springs cap one step at SpringValue.maxAdvance (VK-503 Task 16: a
    // 1/30 s cap left the lens 10 ms behind after a 44 ms first frame).
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(
      0.0,
      SpringValue.maxAdvance,
    );
    _last = elapsed;
    final extraMoving = _extra?.call(dt) ?? false;
    final m = _motion();
    var moving = m != null && m.advance(dt);
    if (m != null) {
      for (final _ in m.takeCrossings()) {
        // Spec VK-503 §9 / Q6: one selection click per slot crossing while
        // dragging.
        unawaited(HapticFeedback.selectionClick());
      }
      if (!moving) {
        final selected = _selected();
        if (m.pending != null && m.pending != selected) {
          // The app did not adopt the commit (spec VK-503 §8.7).
          m.returnTo(selected);
          moving = true;
        } else {
          m.accept();
        }
      }
    }
    if (!moving && !extraMoving) _ticker?.stop();
    if (m != null) _trace?.call(elapsed, m.frame);
    _onFrame();
  }
}

/// The acceptance-trace sample every lens widget reports, once per tick:
/// the ticker time `t` in seconds, the
/// lens centre in global coordinates (`x`, `y`; [frame] is local to
/// [context]'s render box), the lens size (`w`, `h`) and `engage`.
Map<String, double> lensTraceSample(
  BuildContext context,
  Duration elapsed,
  LensFrame frame,
) {
  final box = context.findRenderObject() as RenderBox?;
  final centre = box == null
      ? frame.lens.center
      : box.localToGlobal(frame.lens.center);
  return {
    't': elapsed.inMicroseconds / 1e6,
    'x': centre.dx,
    'y': centre.dy,
    'w': frame.lens.width,
    'h': frame.lens.height,
    'engage': frame.engage,
  };
}
