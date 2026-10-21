import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/gestures.dart';

/// The tab lens's one-finger recognizer. It reports
/// the touch from pointer down either way, so the lens engages at
/// touch-down.
///
/// Eager: it wins the arena on pointer down. Not eager (AX text sizes, or a
/// vertical scroll view around the bar): it wins on a horizontal move
/// beyond the touch slop or on pointer up. Until then the large content
/// viewer's long press, or a vertical drag of the scroll view, can win
/// first, and the lens gets [onCancel]. A horizontal drag still beats a
/// page view around the bar: the bar's recognizer sees each move first,
/// unless [claimsDragAt] says no for this touch.
class LensGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Creates the recognizer.
  LensGestureRecognizer({super.debugOwner, this.eager = true});

  /// Accept on pointer down.
  bool eager;

  /// Whether a touch that comes down at this local point may take a
  /// horizontal drag; null: every touch may. A touch it refuses is never
  /// accepted on a move: it waits for the up (a tap) and leaves a drag to
  /// a scroll view or page view around the widget, and it is not [eager].
  bool Function(Offset local)? claimsDragAt;

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
  bool _claims = true;
  VelocityTracker? _tracker;
  Duration _lastSample = Duration.zero;

  /// A finger still this long before it lifts has no release velocity
  /// (Flutter's own `_assumePointerMoveStoppedMilliseconds`).
  static const Duration _stopped = Duration(milliseconds: 40);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _downGlobal = event.position;
    _accepted = false;
    _claims = claimsDragAt?.call(event.localPosition) ?? true;
    _lastSample = event.timeStamp;
    // UIKit's release velocity, as Flutter's iOS scroll views read it: a
    // weighted mean of the last three steps. The least-squares fit reads
    // the slope at the last sample, so a flick that eases out just before
    // the finger lifts reads far below its speed (−281 against ≈ 800 pt/s
    // for an idb swipe) and lands on the lagging lens's slot, where native
    // lands on the finger's (VK-503 Task 16).
    _tracker = IOSScrollViewFlingVelocityTracker(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    if (eager && _claims) resolve(GestureDisposition.accepted);
    invokeCallback<void>('onDown', () => onDown?.call(event.localPosition));
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      // Down and moves only, as Flutter's drag recognizers feed theirs: the
      // up sample would reset the tracker's "stopped" clock, so a drag that
      // rushes, pauses and lifts would read as a flick (Task 16 review I1).
      _tracker?.addPosition(event.timeStamp, event.localPosition);
      _lastSample = event.timeStamp;
      final dx = (event.position - _downGlobal).dx.abs();
      if (!_accepted &&
          _claims &&
          dx > computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.accepted);
      }
      invokeCallback<void>('onMove', () => onMove?.call(event.localPosition));
    } else if (event is PointerUpEvent) {
      if (!_accepted) resolve(GestureDisposition.accepted);
      final stopped = event.timeStamp - _lastSample > _stopped;
      final v = stopped ? 0.0 : _tracker?.getVelocity().pixelsPerSecond.dx ?? 0;
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
