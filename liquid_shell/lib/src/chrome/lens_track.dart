import 'dart:ui';

/// The slots a lens moves over: a tab bar's slots or a
/// segmented control's thumbs. Track-local coordinates.
abstract interface class LensTrack {
  /// Rest lens rects, in index order (mirrored in RTL).
  List<Rect> get slots;

  /// Centre x of [slot].
  double centreOf(int slot);

  /// The slot whose centre is nearest [x]; the first one on a tie.
  int slotNearest(double x);

  /// [x] clamped to [first slot centre, last slot centre].
  double clampCentre(double x);

  /// The rest lens size at lens centre [x].
  Size restLensAt(double x);

  /// A tap flight's size factor (the iPad top bar), null elsewhere.
  Size? get tapInflation;
}
