import 'package:flutter/foundation.dart';
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

/// VK-550's segment envelope (Task 4 fills it).
final class SegmentEnvelope extends LensEnvelope {
  /// The segment envelope.
  const SegmentEnvelope();
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
}
