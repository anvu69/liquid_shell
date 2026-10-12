import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter/physics.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

/// The shape a lens takes in flight: which envelope `LensMotion` runs
/// (spec VK-550 §8.1).
@immutable
sealed class LensEnvelope {
  /// Const constructor for subclasses.
  const LensEnvelope();
}

/// VK-503's tab envelope: LensMotion's existing targets, reading TabSprings.
final class TabEnvelope extends LensEnvelope {
  /// The tab envelope.
  const TabEnvelope();
}

/// VK-550's segment envelope (spec VK-550 §8.3, §8.4): a press grows the
/// lens in place, a tap lifts it on the way and wobbles it after, a drag
/// squashes it with speed. Each constant names the native rows it comes
/// from (`docs/qa/vk550/native_reference.json`).
final class SegmentEnvelope extends LensEnvelope {
  /// The segment envelope.
  const SegmentEnvelope({
    required this.pressGrow,
    required this.pressSize,
    required this.pressDelay,
    required this.pressHold,
    required this.releaseSize,
    required this.releaseDelay,
    required this.commitDelay,
    required this.showDelay,
    required this.engageHold,
    required this.liftNear,
    required this.liftFar,
    required this.liftUntil,
    required this.wobble,
    required this.squashKnee,
    required this.squashGain,
    required this.squashMax,
    required this.magnify,
  });

  /// How much a press grows the lens, width and height.
  final Size pressGrow;

  /// The size spring of a press and of a tap's lift.
  final SpringDescription pressSize;

  /// Seconds after the down (or a tap's commit) before size and engage
  /// answer.
  final double pressDelay;

  /// An in-place up (a tap on the selected segment) keeps the press look
  /// until the press has lasted this long.
  final double pressHold;

  /// The size spring back to rest after a press or a drag.
  final SpringDescription releaseSize;

  /// Seconds after the up before the release spring starts.
  final double releaseDelay;

  /// Seconds after a tap's commit before the lens x leaves.
  final double commitDelay;

  /// Seconds after a programmatic change before the lens x leaves.
  final double showDelay;

  /// Seconds after a tap's commit the lens stays clear.
  final double engageHold;

  /// A one-segment tap's lift: width and height gains.
  final Size liftNear;

  /// The lift of a tap over two segments or more.
  final Size liftFar;

  /// Seconds after the commit the lift lasts: (one segment, two or more).
  final (double, double) liftUntil;

  /// The size spring after the lift (the landing wobble).
  final SpringDescription wobble;

  /// Lens speed (pt/s) above which a drag squashes the lens.
  final double squashKnee;

  /// Squash per pt/s above the knee: width loss, height gain.
  final Size squashGain;

  /// The squash limits: width and height factors.
  final Size squashMax;

  /// Scale of the w500 copy at full engage.
  final double magnify;
}

/// Every spring and envelope constant a `LensMotion` reads (spec VK-550
/// §8.1).
@immutable
final class LensProfile {
  /// Creates a profile.
  const LensProfile({
    required this.tap,
    required this.dragFollow,
    required this.snap,
    required this.flickLand,
    required this.reduced,
    required this.engageIn,
    required this.engageOut,
    required this.effectIn,
    required this.effectOut,
    required this.tapDelay,
    required this.flickVelocity,
    required this.flickHold,
    required this.releaseHold,
    required this.ghostFade,
    required this.envelope,
    this.programmatic,
  });

  /// Lens x after a tap; content pop.
  final SpringDescription tap;

  /// Lens x following the finger.
  final SpringDescription dragFollow;

  /// Lens x after a drag release, or back after a rejected commit.
  final SpringDescription snap;

  /// Lens x landing a flick.
  final SpringDescription flickLand;

  /// Lens x under reduce motion.
  final SpringDescription reduced;

  /// Engage (gray fill to clear glass) rising.
  final SpringDescription engageIn;

  /// Engage falling.
  final SpringDescription engageOut;

  /// Refraction rising.
  final SpringDescription effectIn;

  /// Refraction, highlight and glow falling.
  final SpringDescription effectOut;

  /// Seconds after the down before the lens answers.
  final double tapDelay;

  /// Release speed (points per second) at or above which a drag is a flick.
  final double flickVelocity;

  /// Seconds a flick keeps the clear lens past its release.
  final double flickHold;

  /// Seconds a tap's lens stays clear past the lift.
  final double releaseHold;

  /// Reduce motion: seconds the outgoing rest fill takes to fade.
  final double ghostFade;

  /// A programmatic change slides on it; null jumps (VK-503 Q12).
  final SpringDescription? programmatic;

  /// The flight envelope.
  final LensEnvelope envelope;

  /// Exactly TabSprings (spec VK-503 §8.1).
  static final LensProfile tab = LensProfile(
    tap: TabSprings.tap,
    dragFollow: TabSprings.dragFollow,
    snap: TabSprings.snap,
    flickLand: TabSprings.flickLand,
    reduced: TabSprings.reduced,
    engageIn: TabSprings.engageIn,
    engageOut: TabSprings.engageOut,
    effectIn: TabSprings.effectIn,
    effectOut: TabSprings.effectOut,
    tapDelay: TabSprings.tapDelay,
    flickVelocity: TabSprings.flickVelocity,
    flickHold: TabSprings.flickHold,
    releaseHold: TabSprings.releaseHold,
    ghostFade: TabSprings.ghostFade,
    envelope: const TabEnvelope(),
  );

  /// VK-550's segmented control (spec VK-550 §8.2). The springs are the
  /// spike's fits (`native_reference.json` `fits`); the envelope knobs are
  /// fitted in Task 4 to the per-frame rows named on each, by least squares
  /// over w and h (sizes) or engage (holds), 1/60 s frames.
  static final LensProfile segment = LensProfile(
    // Spike §3: three taps, least squares over 1.2 s.
    tap: fittedSpring(0.87, 0.41),
    // Spike §3: the drag lag, 6.77 pt at 82.2 pt/s, is VK-503's within 5 %.
    dragFollow: TabSprings.dragFollow,
    // A drag's release, fitted to `slow_drag.release_rows` and the `flick`
    // rows after its release (x): least squares, with the flick's overshoot
    // held to native's 3.9-4.2 pt (`flickLanding`, `flick`): 3.9 pt.
    snap: _segmentRelease,
    // One release spring: native's flick lands as its slow drag does.
    flickLand: _segmentRelease,
    reduced: TabSprings.reduced,
    engageIn: TabSprings.engageIn,
    engageOut: TabSprings.engageOut,
    effectIn: TabSprings.effectIn,
    effectOut: TabSprings.effectOut,
    // A segment press answers on the envelope's own delays.
    tapDelay: 0,
    flickVelocity: TabSprings.flickVelocity,
    // The lens stays clear 0.11 s after an up: `release` (engage within
    // 0.04 of every row), `slow_drag.release_rows` and the `flick` rows
    // after its release agree.
    flickHold: 0.11,
    releaseHold: 0.11,
    ghostFade: TabSprings.ghostFade,
    // Spike §3: the programmatic slide (rms 0.67 pt).
    programmatic: fittedSpring(0.82, 0.41),
    envelope: SegmentEnvelope(
      // Spike §3: 119 × 28 → 143 × 44 (`geometry.pressedGrow`).
      pressGrow: const Size(24, 16),
      // Spike §3: the press, rms 0.08 pt (`fits.pressSize`).
      pressSize: fittedSpring(1, 0.25),
      pressDelay: 0.024,
      // `tapOnSelected`: a 70 ms tap on the selected segment grows to
      // 142.5 × 43.7 and lets go about 0.24 s after the down (w and h within
      // 1.5 pt of every row).
      pressHold: 0.235,
      // Spike §3: the release in place (`fits.releaseSize`).
      releaseSize: fittedSpring(1, 0.24),
      releaseDelay: 0.016,
      // Spike §3: the tap slide leaves 8 ms after the commit (`fits.tap`).
      commitDelay: 0.008,
      // `programmatic_2seg`: the slide starts one or two frames after the
      // write; 30 ms puts every row within 1.6 pt (rms 0.8).
      showDelay: 0.03,
      // `tap_1_2`, `tap_2_3`, `tap_3_1` engage: clear to +0.335 s, then
      // engageOut (within 0.1 of every row from +0.1 s).
      engageHold: 0.335,
      // `tap_1_2`, `tap_2_3`: w ×1.31, h ×1.37 to +0.235 s; peaks 154.8 ×
      // 37.9 against native's 159.2 × 39.2, then the wobble narrows it to
      // 111.0 (native 108.2).
      liftNear: const Size(0.31, 0.37),
      // `tap_3_1`: h ×1.78 to +0.215 s, w held; peak h 48.4 (native 49.5),
      // then the wobble lowers it to 23.3 (native 23.35).
      liftFar: const Size(0.01, 0.78),
      liftUntil: (0.235, 0.215),
      // The size spring after the lift, fitted with the lifts above.
      wobble: fittedSpring(0.42, 0.47),
      // `flick` (rows before its release): from 200 pt/s the lens narrows
      // and rises with its speed; the flick's peaks are 135 × 48 (native
      // 138 × 49.7).
      squashKnee: 200,
      squashGain: const Size(0.00024, 0.00028),
      // Spike §3: h ×1.13 of pressed, w −12 % at about 800 pt/s.
      squashMax: const Size(0.88, 1.13),
      // `lens.labelMagnify`: the w500 copy is not magnified.
      magnify: 1,
    ),
  );
}

/// The segment lens after a drag's release (see [LensProfile.segment]).
final SpringDescription _segmentRelease = fittedSpring(0.64, 0.31);
