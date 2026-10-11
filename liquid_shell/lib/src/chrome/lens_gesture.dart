import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/gestures.dart';

/// The tab lens's one-finger recognizer (spec VK-503 §8.6). It reports
/// the touch from pointer down either way, so the lens engages at
/// touch-down.
///
/// Eager: it wins the arena on pointer down. Not eager (AX text sizes, or a
/// vertical scroll view around the bar): it wins on a horizontal move
/// beyond the touch slop or on pointer up. Until then the large content
/// viewer's long press, or a vertical drag of the scroll view, can win
/// first, and the lens gets [onCancel]. A horizontal drag still beats a
/// page view around the bar: the bar's recognizer sees each move first.
class LensGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Creates the recognizer.
  LensGestureRecognizer({super.debugOwner, this.eager = true});

  /// Accept on pointer down.
  bool eager;

  /// Finger down, local to the detector.
  void Function(Offset local)? onDown;

  /// Finger moved.
  void Function(Offset local)? onMove;

  /// Finger up with its horizontal velocity (pt/s).
  void Function(Offset local, double velocityX)? onUp;

  /// The touch was lost (arena, cancel).
  VoidCallback? onCancel;

  int? _pointer;
  Offset _downGlobal = Offset.zero;
  bool _accepted = false;
  VelocityTracker? _tracker;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _downGlobal = event.position;
    _accepted = false;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    if (eager) resolve(GestureDisposition.accepted);
    invokeCallback<void>('onDown', () => onDown?.call(event.localPosition));
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _tracker?.addPosition(event.timeStamp, event.localPosition);
    if (event is PointerMoveEvent) {
      final dx = (event.position - _downGlobal).dx.abs();
      if (!_accepted && dx > computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.accepted);
      }
      invokeCallback<void>('onMove', () => onMove?.call(event.localPosition));
    } else if (event is PointerUpEvent) {
      if (!_accepted) resolve(GestureDisposition.accepted);
      final v = _tracker?.getVelocity().pixelsPerSecond.dx ?? 0;
      invokeCallback<void>('onUp', () => onUp?.call(event.localPosition, v));
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      invokeCallback<void>('onCancel', () => onCancel?.call());
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) => _accepted = true;

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    invokeCallback<void>('onCancel', () => onCancel?.call());
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _tracker = null;
    _accepted = false;
  }

  @override
  String get debugDescription => 'liquid tab lens';
}
