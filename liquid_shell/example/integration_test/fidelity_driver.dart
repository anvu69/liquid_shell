// What both acceptance drivers share: tab_fidelity_test.dart (spec VK-503
// §17.4) and segment_fidelity_test.dart (spec VK-550 §14.5). Touches, the
// settle, the wall-clock drag and the pixel readback live here once, so a
// fix to one reaches both.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bounds every settle: a perpetual animation fails the run within seconds
/// instead of stalling for pumpAndSettle's default 10 minutes.
Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

/// A drag as the finger made it, in screen points: down to up on the
/// driver's wall clock, and where the finger went down and came up.
typedef Drive = ({double seconds, double from, double to});

/// The touches of an acceptance run, and the finger its traces record.
///
/// Touches go in as the device's own. The tester's gestures make the live
/// binding paint a pointer marker (an orange ring and cross) over the
/// control for as long as the finger is down, which a native recording
/// does not have. On the device path, with the binding's
/// `shouldPropagateDevicePointerEvents`, the binding hands each event to
/// `GestureBinding` as it is, with the same hit test, and paints nothing.
class FidelityTouches {
  FidelityTouches._(this._tester);

  final WidgetTester _tester;

  /// The finger's x as the last event put it (a trace's `finger`).
  double finger = 0;

  /// Whether a finger is down (a trace's `touch`). It drops just before
  /// the up: the last touching sample is the frame before it.
  bool touching = false;

  int _pointer = 0;

  /// Runs [body] with device-path touches. The binding checks right after
  /// the test body, before any tearDown runs, that a test left the flag as
  /// it found it: the flag is reset here, not in a tearDown.
  static Future<void> run(
    WidgetTester tester,
    Future<void> Function(FidelityTouches touches) body,
  ) async {
    final binding = tester.binding..shouldPropagateDevicePointerEvents = true;
    try {
      await body(FidelityTouches._(tester));
    } finally {
      binding.shouldPropagateDevicePointerEvents = false;
    }
  }

  /// A new finger on the device path.
  TestGesture _gesture() => TestGesture(
    pointer: ++_pointer,
    dispatcher: (event) async =>
        _tester.binding.handlePointerEventForSource(event),
  );

  /// A finger down at [p]; lift it with [up].
  Future<TestGesture> down(
    Offset p, {
    Duration timeStamp = Duration.zero,
  }) async {
    finger = p.dx;
    touching = true;
    final g = _gesture();
    await g.down(p, timeStamp: timeStamp);
    return g;
  }

  /// Lifts [g].
  Future<void> up(TestGesture g, {Duration timeStamp = Duration.zero}) {
    touching = false;
    return g.up(timeStamp: timeStamp);
  }

  /// A finger down at [p] for [held] (a tap when zero), then up.
  Future<void> press(Offset p, [Duration held = Duration.zero]) async {
    final g = await down(p);
    if (held > Duration.zero) await _tester.pump(held);
    await up(g);
  }

  /// A tap at the centre of [target].
  Future<void> tapOn(Finder target) => press(_tester.getCenter(target));

  /// Drags from [from] to [to] on [y] at [speed] pt/s of wall-clock time:
  /// frames are live, so the finger's speed is real time, not pump time.
  /// Every event carries its wall-clock time stamp: without one the
  /// velocity tracker reads 0 and a flick never counts as a flick.
  ///
  /// The move loop runs once a frame, and by default the finger rests one
  /// more frame at the end before it lifts (the VK-503 tab drives). With
  /// [arrive] it lifts as it arrives, and plans to arrive half a frame
  /// early, so the gesture's down-to-up time, which the frame grid delays
  /// by up to a frame, centres on the distance over [speed]: a drive that
  /// must match a native gesture's time (the segment flick).
  Future<Drive> drag(
    double from,
    double to,
    double y,
    double speed, {
    bool arrive = false,
  }) async {
    final span = (to - from).abs();
    final sign = (to - from).sign;
    final pace = arrive ? span / math.max(1e-3, span / speed - 1 / 120) : speed;
    final clock = Stopwatch()..start();
    final g = await down(Offset(from, y), timeStamp: clock.elapsed);
    final start = clock.elapsedMicroseconds;
    var travelled = 0.0;
    while (travelled < span) {
      travelled = math.min(span, pace * clock.elapsedMicroseconds / 1e6);
      finger = from + sign * travelled;
      await g.moveTo(Offset(finger, y), timeStamp: clock.elapsed);
      if (arrive && travelled >= span) break;
      await _tester.pump(const Duration(milliseconds: 4));
    }
    final end = clock.elapsedMicroseconds;
    await up(g, timeStamp: clock.elapsed);
    return (seconds: (end - start) / 1e6, from: from, to: finger);
  }
}

/// The pixels of a repaint boundary, read back from the engine at the
/// device scale.
class Pixels {
  Pixels._(this._bytes, this._width, this._ratio);

  final ByteData _bytes;
  final int _width;
  final double _ratio;

  /// Renders the boundary under [boundary].
  static Future<Pixels> of(WidgetTester tester, GlobalKey boundary) async {
    final ratio = tester.view.devicePixelRatio;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: ratio);
    final width = image.width;
    final bytes = (await image.toByteData())!;
    image.dispose();
    return Pixels._(bytes, width, ratio);
  }

  /// The colour at [p] (logical points), red, green and blue.
  List<double> rgb(Offset p) {
    final i = ((p.dy * _ratio).floor() * _width + (p.dx * _ratio).floor()) * 4;
    return [for (var c = 0; c < 3; c++) _bytes.getUint8(i + c).toDouble()];
  }

  /// The darkest pixel of [rect], or the brightest: the stem of a glyph,
  /// clear of antialiasing.
  List<double> extreme(Rect rect, {required bool brightest}) {
    List<double>? best;
    for (var y = rect.top; y < rect.bottom; y += 1 / _ratio) {
      for (var x = rect.left; x < rect.right; x += 1 / _ratio) {
        final c = rgb(Offset(x, y));
        final l = c.reduce((a, b) => a + b);
        final e = best?.reduce((a, b) => a + b);
        if (e == null || (brightest ? l > e : l < e)) best = c;
      }
    }
    return best!;
  }
}
