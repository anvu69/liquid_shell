import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter/physics.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';
import 'package:liquid_shell/src/glass/lens_look.dart';

/// The shape a lens takes in flight: which envelope `LensMotion` runs.
@immutable
sealed class LensEnvelope {
  /// Const constructor for subclasses.
  const LensEnvelope();
}

/// The tab envelope: LensMotion's existing targets, reading TabSprings.
final class TabEnvelope extends LensEnvelope {
  /// The tab envelope.
  const TabEnvelope();
}

/// The segment envelope: a press grows the lens in place, a tap lifts it on the
/// way and wobbles it after, a drag squashes it with speed. Each constant names
/// the native rows it comes from (`docs/qa/vk550/native_reference.json`).
final class SegmentEnvelope extends LensEnvelope {
  /// The segment envelope.
  const SegmentEnvelope({
    required this.pressGrow,
    required this.pressSize,
    required this.pressDelay,
    required this.pressHold,
    required this.releaseSize,
    required this.releaseDelay,
    required this.slide,
    required this.showDelay,
    required this.engageHold,
    required this.liftRight,
    required this.liftLeft,
    required this.liftUntil,
    required this.wobble,
    required this.wobbleArea,
    required this.squashKnee,
    required this.squashGain,
    required this.squashMax,
    required this.landing,
    required this.landingHold,
    required this.magnifyGain,
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

  /// The lens x of a tap: the slide to the new segment.
  final TapSlide slide;

  /// Seconds after a programmatic change before the lens x leaves.
  final double showDelay;

  /// Seconds after a tap's commit the lens stays clear.
  final double engageHold;

  /// A tap's lift to the right on screen: width and height gains, wide
  /// (`tap_1_2`, `tap_2_3`).
  final Size liftRight;

  /// A tap's lift to the left on screen: tall (`tap_3_1`).
  final Size liftLeft;

  /// Seconds after the commit the lift lasts: ([liftRight], [liftLeft]).
  final (double, double) liftUntil;

  /// The size spring after the lift (the landing wobble): it drives the
  /// side the lift stretched most.
  final SpringDescription wobble;

  /// After a tap's lift the lens keeps its area: the area
  /// returns to rest on this spring, and the side the lift stretched less
  /// is the area over the other.
  final SpringDescription wobbleArea;

  /// Lens speed (pt/s) above which a drag squashes the lens.
  final double squashKnee;

  /// Squash per pt/s above the knee: width loss, height gain.
  final Size squashGain;

  /// The squash limits: width and height factors.
  final Size squashMax;

  /// A fast drag release's landing: once the lens x passes its
  /// target, the size heads for rest scaled by these gains (wider, flatter)
  /// on [pressSize], then [wobble] takes it back. Full where the drag
  /// squash saturates, none below [squashKnee].
  final Size landing;

  /// Seconds after the lens x passes its target that the landing gains
  /// hold, before the wobble.
  final double landingHold;

  /// Magnification gain of the w500 copy at full engage (scale − 1, as
  /// `TabSprings.magnify`).
  final double magnifyGain;
}

/// A segment tap's slide: two springs from the
/// commit, blended. The primary is the profile's `tap` spring; a secondary
/// share adds native's overshoot and its late return.
@immutable
final class TapSlide {
  /// Creates a slide.
  const TapSlide({
    required this.delay,
    required this.secondary,
    required this.secondaryDelay,
    required this.share,
  });

  /// Seconds after the commit before the primary leaves.
  final double delay;

  /// The secondary spring.
  final SpringDescription secondary;

  /// Seconds after the commit before the secondary leaves.
  final double secondaryDelay;

  /// The secondary's share of the lens x.
  final double share;
}

/// Every spring and envelope constant a `LensMotion` reads.
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
    this.look = LensLook.tab,
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

  /// A programmatic change slides on it; null jumps.
  final SpringDescription? programmatic;

  /// The flight envelope.
  final LensEnvelope envelope;

  /// What the engaged lens looks like (the shader's optics).
  final LensLook look;

  /// Exactly TabSprings.
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

  /// The segmented control's. The press, release
  /// and programmatic springs are the spike's fits (`native_reference.json`
  /// `fits`); the tap slide and the envelope knobs are fitted in Task 4 to
  /// the per-frame rows named on each.
  static final LensProfile segment = LensProfile(
    // The tap slide's primary (see `slide`).
    tap: fittedSpring(0.751, 0.577),
    // Spike §3: the drag lag, 6.77 pt at 82.2 pt/s, is VK-503's within 5 %.
    dragFollow: TabSprings.dragFollow,
    // A drag's release (Task 8 review, Q-E; Task 15): fitted to both
    // native landings. `flick`: overshoot 4.40 pt (native 4.04), lowest
    // point +0.229 s (0.221), within 0.5 pt from +0.493 s (0.503).
    // `flickLanding` as the simulator drives it: median overshoot 3.11 pt
    // over the frame phases (native 3.86; 2.71 to 3.65 by phase). One
    // linear spring cannot hold both: native's overshoot barely changes
    // with speed (4.04 at about 630 pt/s, 3.86 at about 450) and ours
    // does, so the errors are shared; Task 8's 0.8 / 0.59 s put `flick`
    // at 4.10 and `flickLanding` at 2.85 (on the edge of its ±1 pt). The
    // `slow_drag.release_rows` stay within 2 pt (x, w, h). Task 4's
    // 0.64 / 0.31 s bottomed out 31 % and settled 47 % early.
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
    look: LensLook.segment,
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
      // All five native tap captures (`tap_1_2`, `tap_2_3`, `tap_3_1`,
      // `dark.tap_1_2`, `tap_1_3_5seg`: 123 to 247 pt), each on its
      // engage-aligned clock (spec §14.5): x within 1.8 pt of every row to
      // +0.6 s, overshoot 2.35 / 4.7 / 2.8 pt (native 2.5-2.6 / 5.0 /
      // 2.3), within 0.5 pt of rest from +0.70 s (native +0.70 / +0.75).
      // With the primary `tap` spring above.
      slide: TapSlide(
        delay: 0.0144,
        secondary: fittedSpring(0.623, 0.285),
        secondaryDelay: 0.032,
        share: 0.286,
      ),
      // `programmatic_2seg`: the slide starts one or two frames after the
      // write; 30 ms puts every row within 1.6 pt (rms 0.8).
      showDelay: 0.03,
      // `tap_1_2`, `tap_2_3`, `tap_3_1` engage: clear to +0.335 s, then
      // engageOut (within 0.1 of every row from +0.1 s).
      engageHold: 0.335,
      // The lift follows the direction on screen, nothing else (Task 15
      // review: native_taps.json, two, three and five segments, LTR and
      // RTL, 74 to 296 pt): to the right it is wide, to the left tall,
      // whatever the distance or the target segment.
      // `tap_1_2`, `tap_2_3` (right): w ×1.31, h ×1.37 to +0.235 s; peaks
      // 154.8 × 37.9 against native's 159.2 × 39.2, then the wobble
      // narrows it to 111.0 (native 108.2).
      liftRight: const Size(0.31, 0.37),
      // `tap_3_1` (left): h ×1.78 to +0.215 s, w held; peak h 48.4 (native
      // 49.5), then the wobble lowers it to 23.3 (native 23.35).
      liftLeft: const Size(0.01, 0.78),
      liftUntil: (0.235, 0.215),
      // The size spring after the lift. Task 4 fitted 0.42 / 0.47 s with
      // the lifts above; the Task 15 review refitted it with the direction
      // rule on the fixture's five taps and native_taps.json's fitting
      // split (31 taps): every peak h and wobble extreme within 10 % but
      // the w swing after a long tap to the right on five segments (222
      // and 296 pt: +13 to +15 %). At 0.42 short taps to the left swelled
      // 10.5 % too wide.
      wobble: fittedSpring(0.48, 0.47),
      // Task 15: after the lift native keeps the lens's area within 4 %
      // of rest from +0.45 s (w × h of `tap_1_2`, `tap_3_1`,
      // `tap_1_3_5seg`), so a lens that narrows grows taller and one that
      // flattens grows wider: `tap_3_1`'s wide, flat landing. Fitted to
      // those rows from +0.25 s: `tap_1_2` h within 1.3 pt (rms 0.8),
      // `tap_3_1` w within 7 pt (rms 4.2; its swell 142.4 against 136.1),
      // `tap_1_3_5seg` h within 2.6 pt (rms 1.3).
      wobbleArea: fittedSpring(0.8, 0.36),
      // `flick` (rows before its release): from 200 pt/s the lens narrows
      // and rises with its speed; the flick's peaks are 135 × 48 (native
      // 138 × 49.7).
      squashKnee: 200,
      squashGain: const Size(0.00024, 0.00028),
      // Spike §3: h ×1.13 of pressed, w −12 % at about 800 pt/s.
      squashMax: const Size(0.88, 1.13),
      landing: const Size(_landingW, _landingH),
      landingHold: _landingHold,
      // `lens.labelMagnify` 1.0: the w500 copy is not magnified.
      magnifyGain: 0,
    ),
  );
}

/// The segment lens after a drag's release (see [LensProfile.segment]).
final SpringDescription _segmentRelease = fittedSpring(0.785, 0.585);

// The `flick` landing (Task 8 review, Q-E), with [_segmentRelease] and the
// tap's wobble: w swells ×1.099 (native ×1.103) and h dips ×0.872 (×0.877)
// at +0.335 / +0.339 s after the up (native +0.335 / +0.335). Measured with
// the wobble at ζ 0.42, before the Task 15 review refitted it to 0.48, and
// not measured again since. At the flick's lens speed these gains apply at
// about two thirds; a slow drag (below the squash knee) has none, as
// `slow_drag`.
const double _landingW = 0.16;
const double _landingH = -0.21;
const double _landingHold = 0.2;
