import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart' show SpringDescription;
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/chrome/lens_track.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

/// What the lens is doing.
enum LensPhase {
  /// At the committed slot, nothing moves.
  rest,

  /// Finger down, travel within the touch slop.
  pressed,

  /// Finger down and moved beyond the slop: the lens follows it.
  dragging,

  /// After a tap: the 0.35 s flight envelope.
  flying,

  /// Springs returning to rest.
  settling,
}

/// The side of a segment lens that follows its area after a tap's lift.
enum _Follow {
  /// The height is the area over the width.
  height,

  /// The width is the area over the height.
  width,
}

/// What a segment flight is landing.
enum _Flight {
  /// A tap on another segment: the lift, then the wobble.
  tap,

  /// An up in place or after a drag: the release spring.
  release,

  /// A programmatic change: a slide, no engage, no resize.
  show,
}

/// Everything the bar paints for one frame. Bar-local.
@immutable
class LensFrame {
  /// Creates a frame.
  const LensFrame({
    required this.lens,
    this.visible = true,
    this.engage = 0,
    this.refraction = 0,
    this.pillScale = 1,
    this.highlight = 0,
    this.glowCenter,
    this.glowDiameter = 0,
    this.glowOpacity = 0,
    this.popSlot,
    this.popScale = 1,
    this.ghost,
    this.ghostOpacity = 0,
    this.restOpacity = 1,
    this.magnifyGain = TabSprings.magnify,
  });

  /// The lens capsule.
  final Rect lens;

  /// Whether a lens is drawn at all (nothing selected and untouched: no).
  final bool visible;

  /// 0 = gray rest fill, 1 = clear glass.
  final double engage;

  /// Lens refraction amount, 0–1.
  final double refraction;

  /// Pill scale about its centre.
  final double pillScale;

  /// Pill highlight amount, 0–1 (peak per brightness in the painter).
  final double highlight;

  /// Finger glow centre, or null.
  final Offset? glowCenter;

  /// Finger glow diameter.
  final double glowDiameter;

  /// Finger glow opacity.
  final double glowOpacity;

  /// The slot whose tinted content pops, or null.
  final int? popSlot;

  /// Its scale.
  final double popScale;

  /// Reduce motion: the outgoing rest fill, or null.
  final Rect? ghost;

  /// Its opacity.
  final double ghostOpacity;

  /// Opacity of the rest fill at [lens] (reduce motion fade-in).
  final double restOpacity;

  /// The tinted copy's magnification gain at full engage.
  final double magnifyGain;

  /// Scale of the tinted copy about the lens centre.
  double get magnify => 1 + magnifyGain * engage;

  /// A copy with the given fields replaced (debug overrides and goldens).
  LensFrame copyWith({
    Rect? lens,
    double? engage,
    double? refraction,
    double? pillScale,
    double? highlight,
  }) => LensFrame(
    lens: lens ?? this.lens,
    visible: visible,
    engage: engage ?? this.engage,
    refraction: refraction ?? this.refraction,
    pillScale: pillScale ?? this.pillScale,
    highlight: highlight ?? this.highlight,
    glowCenter: glowCenter,
    glowDiameter: glowDiameter,
    glowOpacity: glowOpacity,
    popSlot: popSlot,
    popScale: popScale,
    ghost: ghost,
    ghostOpacity: ghostOpacity,
    restOpacity: restOpacity,
    magnifyGain: magnifyGain,
  );
}

/// The lens state machine. Pure: the widget feeds it pointer
/// events in track-local coordinates and calls [advance] once per frame.
class LensMotion {
  /// Starts at rest on [selected] (null: nothing highlighted), moving on
  /// [profile] ([LensProfile.tab] when null).
  LensMotion({
    required LensTrack geometry,
    required int? selected,
    LensProfile? profile,
    this.reduceMotion = false,
  }) : _geometry = geometry,
       profile = profile ?? LensProfile.tab,
       _committed = _valid(selected, geometry) {
    final rest = _restRect(_committed);
    _x = SpringValue(rest.center.dx, this.profile.tap);
    _x2 = SpringValue(rest.center.dx, this.profile.tap);
    _w = SpringValue(rest.width, TabSprings.widthOut);
    _h = SpringValue(rest.height, TabSprings.heightOut);
  }

  /// Reduce motion.
  bool reduceMotion;

  /// The springs and envelope the lens moves on.
  final LensProfile profile;

  LensTrack _geometry;
  int? _committed;
  int? _pending;
  LensPhase _phase = LensPhase.rest;

  late final SpringValue _x;

  /// A segment tap slide's secondary spring: the lens x
  /// is [_x] blended with it by [_share] until the slide rests or is
  /// interrupted (`_fold`).
  late final SpringValue _x2;
  double _share = 0;
  late final SpringValue _w;
  late final SpringValue _h;

  /// After a segment tap's lift: the lens area, and the side that follows
  /// it; null otherwise.
  final SpringValue _area = SpringValue(0, TabSprings.widthOut);
  _Follow? _follow;
  final SpringValue _scale = SpringValue(1, TabSprings.scaleOut);
  late final SpringValue _engage = SpringValue(0, profile.engageOut);
  late final SpringValue _refraction = SpringValue(0, profile.effectOut);
  late final SpringValue _highlight = SpringValue(0, profile.effectOut);
  final SpringValue _glowOpacity = SpringValue(0, TabSprings.glowIn);
  final SpringValue _glowDiameter = SpringValue(
    TabSprings.glowDiameter,
    TabSprings.glowIn,
  );
  late final SpringValue _pop = SpringValue(1, profile.tap);

  Offset? _glowCenter;
  double? _rippleAge;
  double _rippleOpacity = 0;
  double _rippleDiameter = TabSprings.glowDiameter;
  double _downX = 0;
  double _travel = 0;

  /// Time since the touch-down (or the semantics tap) that started this
  /// interaction: native answers 25 ms after the down, and a tap's flight
  /// envelope is timed from it.
  double _since = 0;

  /// Where the press aims the lens: the finger, clamped to the slots.
  double _aim = 0;

  /// The flight follows a flick to the finger's slot.
  bool _flick = false;

  /// The segment flight's kind.
  _Flight _flight = _Flight.tap;

  /// A fast drag release's landing: its size gains
  /// (zero for a slow release), the side of the target the lens left
  /// from, and when the lens x passed the target (null until it does).
  Size _landing = Size.zero;
  double _landSide = 0;
  double? _landAt;

  /// The press is on the lens's own slot: a segment lens grows only there.
  bool _pressOnLens = false;

  /// The widest stretch of this flight so far (two slots or more).
  double _stretch = 1;

  /// When the tap's press ends on the [_since] clock: the lift, or 66 ms
  /// for a quicker tap. The lens keeps the press look 25 ms past it.
  double _releaseAt = 0;
  int _flightSlots = 1;

  /// A segment tap goes to the left on screen: its lift is tall, not wide.
  bool _liftLeft = false;
  double _flightTarget = 0;
  int? _popSlot;
  int _lastSlot = 0;
  final List<int> _crossings = [];
  int? _ghostSlot;
  double _ghostAge = 0;
  double _fadeIn = 1;

  List<SpringValue> get _springs => [
    _x,
    _x2,
    _w,
    _h,
    _area,
    _scale,
    _engage,
    _refraction,
    _highlight,
    _glowOpacity,
    _glowDiameter,
    _pop,
  ];

  /// The lens centre x: [_x], or a running tap slide's blend.
  double get _lensX => _x.value + _share * (_x2.value - _x.value);

  /// Ends a running tap slide's blend: [_x] takes the blended position
  /// and speed, so whatever comes next starts where the lens is.
  void _fold() {
    if (_share == 0) return;
    final velocity = _x.velocity + _share * (_x2.velocity - _x.velocity);
    _x.place(_lensX, velocity);
    _share = 0;
  }

  static int? _valid(int? slot, LensTrack g) =>
      slot != null && slot >= 0 && slot < g.slots.length ? slot : null;

  /// The finger glow, pill scale, highlight and content pop: the tab
  /// envelope's; a segment lens has none.
  bool get _effects => profile.envelope is TabEnvelope;

  /// The geometry; a new one at rest moves the lens without animation.
  LensTrack get geometry => _geometry;
  set geometry(LensTrack value) {
    if (value == _geometry) return;
    _fold();
    _geometry = value;
    _committed = _valid(_committed, value);
    _pending = _valid(_pending, value);
    final committed = _committed;
    switch (_phase) {
      case LensPhase.rest:
        _jumpTo(committed);
      case LensPhase.flying:
        if (committed != null) _flightTarget = value.centreOf(committed);
      case LensPhase.settling:
        if (committed != null) _x.target = value.centreOf(committed);
      case LensPhase.pressed || LensPhase.dragging:
        _x.target = value.clampCentre(_x.target);
        _aim = value.clampCentre(_aim);
    }
  }

  /// The current phase.
  LensPhase get phase => _phase;

  /// The slot the lens belongs to.
  int? get committed => _committed;

  /// A commit the app has not confirmed yet.
  int? get pending => _pending;

  /// A finger is down.
  bool get interacting =>
      _phase == LensPhase.pressed || _phase == LensPhase.dragging;

  Rect _restRect(int? slot) => slot == null || slot >= _geometry.slots.length
      ? Rect.zero
      : _geometry.slots[slot];

  void _jumpTo(int? slot) {
    final r = _restRect(slot);
    _share = 0;
    _x.jump(r.center.dx);
    _x2.jump(r.center.dx);
    _w.jump(r.width);
    _h.jump(r.height);
    _area.jump(r.width * r.height);
    _follow = null;
    _scale.jump(1);
    _engage.jump(0);
    _refraction.jump(0);
    _highlight.jump(0);
    _glowOpacity.jump(0);
    _glowDiameter.jump(TabSprings.glowDiameter);
    _pop.jump(1);
    _glowCenter = null;
    _rippleAge = null;
    _ghostSlot = null;
    _fadeIn = 1;
    _popSlot = null;
    _flick = false;
    _phase = LensPhase.rest;
  }

  /// Finger down at [local].
  void down(Offset local) {
    if (_geometry.slots.isEmpty) return;
    _fold();
    if (_committed == null && !interacting) {
      final r = _geometry.slots[_geometry.slotNearest(local.dx)];
      _x.jump(_geometry.clampCentre(local.dx));
      _w.jump(r.width);
      _h.jump(r.height);
    }
    _phase = LensPhase.pressed;
    _downX = local.dx;
    _travel = 0;
    _lastSlot = _geometry.slotNearest(_x.value);
    _crossings.clear();
    // A new press ends any tap pop still running (fast tab hopping).
    _pop.target = 1;
    _since = 0;
    _flick = false;
    _aim = _geometry.clampCentre(local.dx);
    final committed = _committed;
    _pressOnLens =
        committed == null || _geometry.slotNearest(_aim) == committed;
    if (reduceMotion) {
      // No slide toward the finger: a tap dissolves in place (§13.2). The
      // capsule follows only once the press turns into a drag.
      _x.spring = profile.reduced;
    } else {
      // The lens turns toward the finger 25 ms after the down, not at it
      // (research §4.1 trace: the press answers at 25-30 ms).
      _x.spring = profile.dragFollow;
      if (_effects) {
        _glowCenter = local;
        _rippleAge = null;
        _glowDiameter.jump(TabSprings.glowDiameter);
      }
    }
  }

  /// Finger moved to [local]. The lens x answers in [advance] (`_steerX`).
  void move(Offset local) {
    if (!interacting) return;
    _travel = math.max(_travel, (local.dx - _downX).abs());
    if (_travel > kTouchSlop) _phase = LensPhase.dragging;
    if (!reduceMotion && _effects) _glowCenter = local;
    if (reduceMotion && _phase == LensPhase.pressed) return;
    _aim = _geometry.clampCentre(local.dx);
  }

  /// Finger up at [local] with horizontal [velocity]; returns the committed
  /// slot. A slot [canCommit] refuses is never committed: the
  /// nearest one it allows is (disabled segments); with
  /// none allowed the up is a [cancel] and returns null.
  int? up(
    Offset local, {
    double velocity = 0,
    bool Function(int slot)? canCommit,
  }) {
    if (!interacting) return null;
    final tap = _phase == LensPhase.pressed;
    final flick = velocity.abs() >= profile.flickVelocity;
    final x = tap || flick ? local.dx : _x.value;
    final slot = canCommit == null
        ? _geometry.slotNearest(x)
        : _nearestAllowed(x, canCommit);
    if (slot == null) {
      cancel();
      return null;
    }
    _startRipple();
    _commit(slot, tap: tap, flick: flick && !tap);
    return slot;
  }

  /// The slot [allowed] accepts whose centre is nearest [x], or null.
  int? _nearestAllowed(double x, bool Function(int slot) allowed) {
    int? best;
    var distance = double.infinity;
    for (var s = 0; s < _geometry.slots.length; s++) {
      final d = (_geometry.centreOf(s) - x).abs();
      if (allowed(s) && d < distance) {
        best = s;
        distance = d;
      }
    }
    return best;
  }

  /// The touch was taken away: back to the committed slot, no commit.
  void cancel() {
    if (!interacting) return;
    _startRipple();
    _settleBack();
  }

  /// A tap from semantics (or a test): the tap path without a press.
  void tapSlot(int slot) {
    if (slot < 0 || slot >= _geometry.slots.length) return;
    _since = 0;
    _commit(slot, tap: true);
  }

  /// A programmatic selection: slides on [LensProfile.programmatic], or
  /// jumps when it is null or under reduce motion.
  void show(int? slot) {
    _pending = null;
    _fold();
    final committed = _committed = _valid(slot, _geometry);
    final spring = profile.programmatic;
    if (spring == null || reduceMotion || committed == null) {
      _jumpTo(committed);
      return;
    }
    // Whatever was flying stops being a tap or a flick: its pop springs
    // back and nothing holds the lens clear.
    _flick = false;
    _pop.target = 1;
    if (profile.envelope is SegmentEnvelope) {
      // The slide starts showDelay late (`programmatic_2seg`).
      _phase = LensPhase.flying;
      _flight = _Flight.show;
      _since = 0;
      _flightTarget = _geometry.centreOf(committed);
      _x.spring = spring;
      return;
    }
    _x.retarget(_geometry.centreOf(committed), spring);
    _phase = LensPhase.settling;
  }

  /// Follows the app's [selected] on a rebuild, for every lens widget:
  /// a pending commit it adopts is accepted (one it has not answered is
  /// left to `LensTicker`, which returns it at rest); a change of its own,
  /// with no finger down, is a [show]. True when the lens now moves and
  /// the widget's ticker must run (a slide); a jump needs no tick.
  bool follow(int? selected) {
    if (_pending != null) {
      if (selected == _pending) accept();
      return false;
    }
    if (selected == _committed || interacting) return false;
    show(selected);
    return _phase != LensPhase.rest;
  }

  /// The app adopted the pending commit.
  void accept() => _pending = null;

  /// The app did not adopt it: snap back to [slot].
  void returnTo(int? slot) {
    _pending = null;
    _fold();
    _committed = _valid(slot, _geometry);
    if (_committed == null) {
      _jumpTo(null);
      return;
    }
    _settleBack();
  }

  /// Slots the lens entered while dragging since the last call.
  List<int> takeCrossings() {
    final out = List.of(_crossings);
    _crossings.clear();
    return out;
  }

  void _settleBack() {
    _phase = LensPhase.settling;
    final c = _committed;
    if (c == null) {
      _jumpTo(null);
      return;
    }
    _x.retarget(
      _geometry.centreOf(c),
      reduceMotion ? profile.reduced : profile.snap,
    );
  }

  void _startRipple() {
    if (reduceMotion || _glowCenter == null) return;
    _rippleAge = 0;
    // From the full glow, as native: a quick tap lifts before the glow's
    // 80 ms fade-in has run, and its ripple would start invisible.
    _rippleOpacity = TabSprings.glowOpacity;
    _rippleDiameter = _glowDiameter.value;
  }

  void _commit(int slot, {required bool tap, bool flick = false}) {
    _fold();
    final from = _committed;
    _committed = slot;
    _pending = slot;
    if (reduceMotion) {
      if (tap) {
        if (from != null && from != slot) {
          _ghostSlot = from;
          _ghostAge = 0;
          _fadeIn = 0;
        }
        final r = _restRect(slot);
        _x.jump(r.center.dx);
        _w.jump(r.width);
        _h.jump(r.height);
        _phase = LensPhase.settling;
      } else {
        _settleBack();
      }
      return;
    }
    if (profile.envelope case final SegmentEnvelope e) {
      _commitSegment(e, from, slot, tap: tap, flick: flick);
      return;
    }
    if (flick) {
      // Native keeps the clear lens 0.215 s past the release and lands it
      // on Home within about 0.12 s without passing it (research trace,
      // spec §8.2, Task 16 re-review).
      _phase = LensPhase.flying;
      _flick = true;
      _flightSlots = 1;
      _releaseAt = _since;
      _flightTarget = _geometry.centreOf(slot);
      _x.retarget(_flightTarget, profile.flickLand);
      return;
    }
    if (!tap) {
      _settleBack();
      return;
    }
    _phase = LensPhase.flying;
    _flick = false;
    _stretch = 1;
    // A tap reads as a press of at least 66 ms. After a long press the
    // envelope moves up so the lens stays clear 0.12 s past the lift, as
    // native's press release does (research §4.1 trace).
    _releaseAt = math.max(_since, TabSprings.tapPress);
    final late = _releaseAt + profile.releaseHold - TabSprings.flightHold;
    if (late > 0) {
      _since -= late;
      _releaseAt -= late;
    }
    _flightSlots = from == null ? 1 : math.max(1, (slot - from).abs());
    _flightTarget = _geometry.centreOf(slot);
    // Timed from the down: within the first 25 ms the lens still holds;
    // after that it flies on, keeping the speed the press gave it.
    if (_since >= profile.tapDelay) {
      _x.retarget(_flightTarget, profile.tap);
    } else {
      _x.spring = profile.tap;
    }
    _popSlot = slot;
    _pop.retarget(TabSprings.pop, profile.tap);
  }

  /// A segment commit. The flight's clock restarts at
  /// the up, as the native rows' does: a tap lifts and lands on the tap
  /// spring, an up in place or after a drag releases.
  void _commitSegment(
    SegmentEnvelope e,
    int? from,
    int slot, {
    required bool tap,
    required bool flick,
  }) {
    final pressed = _since;
    _phase = LensPhase.flying;
    _flick = flick;
    _flight = tap && slot != from ? _Flight.tap : _Flight.release;
    _flightTarget = _geometry.centreOf(slot);
    _liftLeft = _flightTarget < _lensX;
    _follow = null;
    // An up in place keeps the press look until the press has lasted
    // pressHold (`tapOnSelected`); a longer press releases at once.
    _releaseAt = tap ? math.max(0, e.pressHold - pressed) : 0;
    _since = 0;
    // A drag released fast lands: the drag squash rebounds, wider and
    // flatter, once the lens passes its target (spec §8.4).
    _landing = tap ? Size.zero : _landingFor(e, _x.velocity);
    _landSide = (_x.value - _flightTarget).sign;
    _landAt = null;
    if (_flight == _Flight.tap) {
      // Two springs from where the lens is; `_steerX` and `_segmentTargets`
      // send them after their delays.
      _x.spring = profile.tap;
      _x2
        ..place(_x.value, _x.velocity)
        ..retarget(_x.target, e.slide.secondary);
      _share = e.slide.share;
    } else {
      _x.retarget(_flightTarget, flick ? profile.flickLand : profile.snap);
    }
  }

  /// The times on the interaction clock at which the envelope's targets
  /// change in the current phase: the tab's 25 ms answer; a segment's
  /// press, slide, release and hold ends (ascending).
  List<double> _delays() {
    if (reduceMotion) return const [];
    final e = profile.envelope;
    if (e is! SegmentEnvelope) return [profile.tapDelay];
    if (interacting) return [e.pressDelay];
    if (_phase != LensPhase.flying) return const [];
    return switch (_flight) {
      _Flight.tap => [
        e.slide.delay,
        e.slide.secondaryDelay,
        e.pressDelay,
        _liftUntil(e),
        e.engageHold,
      ]..sort(),
      _Flight.release => [
        _releaseAt,
        _releaseAt + e.releaseDelay,
        _releaseAt + (_flick ? profile.flickHold : profile.releaseHold),
        if (_landAt case final at?) at + e.landingHold,
      ]..sort(),
      _Flight.show => [e.showDelay],
    };
  }

  /// Advances [dt] seconds; true while anything still moves.
  bool advance(double dt) {
    final before = _since;
    if (_phase != LensPhase.settling && _phase != LensPhase.rest) {
      _since += dt;
    }
    // A delay ends inside this frame (the tab's 25 ms answer, a segment's
    // press or commit delay): every spring runs to it on the old targets,
    // then the rest of the frame on the new ones, so the lens answers on
    // time, not a frame early.
    var at = before;
    for (final delay in _delays()) {
      if (delay <= at || delay > _since) continue;
      _setTargets(at);
      for (final s in _springs) {
        s.advance(delay - at);
      }
      at = delay;
    }
    _setTargets(_since);
    final rest = at == before ? dt : _since - at;
    for (final s in _springs) {
      s.advance(rest);
    }
    _followArea();
    if (_phase == LensPhase.flying &&
        _flight == _Flight.release &&
        _landAt == null &&
        _landing != Size.zero &&
        (_x.value - _flightTarget).sign != _landSide) {
      _landAt = _since;
    }
    if (_phase == LensPhase.flying) _endFlight();
    _advanceRipple(dt);
    _advanceGhost(dt);
    switch (_phase) {
      // Travel during the press is not a crossing (Q6): track it silently.
      case LensPhase.pressed:
        _lastSlot = _geometry.slotNearest(_x.value);
      case LensPhase.dragging:
        _queueCrossing();
      case LensPhase.flying || LensPhase.settling || LensPhase.rest:
        break;
    }
    final moving = _isMoving();
    if (!moving && _phase == LensPhase.settling) {
      for (final s in _springs) {
        s.jump(s.target);
      }
      _share = 0;
      _popSlot = null;
      _follow = null;
      _phase = LensPhase.rest;
    }
    return moving;
  }

  /// A flight ends when its envelope is over: a tap's, or 0.215 s after a
  /// flick's release; a segment flight's when its last hold ends.
  void _endFlight() {
    if (profile.envelope case final SegmentEnvelope e) {
      final end = switch (_flight) {
        _Flight.tap => [
          e.slide.delay,
          e.slide.secondaryDelay,
          e.engageHold,
          _liftUntil(e),
        ].reduce(math.max),
        _Flight.release => math.max(
          _releaseAt +
              math.max(
                e.releaseDelay,
                _flick ? profile.flickHold : profile.releaseHold,
              ),
          _landingEnd(e),
        ),
        _Flight.show => e.showDelay,
      };
      if (_since >= end) _phase = LensPhase.settling;
      return;
    }
    if (_flick) {
      if (_since - _releaseAt >= profile.flickHold) {
        _phase = LensPhase.settling;
      }
      return;
    }
    if (_since >= TabSprings.popUntil) _pop.target = 1;
    if (_since >= TabSprings.flightHold) _phase = LensPhase.settling;
  }

  /// When a landing's lift ends: 0 without one; never before the lens
  /// has passed its target (unless it comes to rest short of it).
  double _landingEnd(SegmentEnvelope e) {
    if (_landing == Size.zero) return 0;
    final at = _landAt;
    if (at != null) return at + e.landingHold;
    return _x.settled(0.5) ? 0 : double.infinity;
  }

  /// The targets of every spring at [since] seconds into the interaction.
  void _setTargets(double since) {
    switch (profile.envelope) {
      case TabEnvelope():
        _tabTargets(since);
      case final SegmentEnvelope e:
        _segmentTargets(e, since);
    }
  }

  /// The lens x, for every envelope. Once [answered], a
  /// drag follows the finger on dragFollow (under reduce motion the
  /// rest-size capsule follows on the spring the down chose), and a press
  /// leans toward the finger on the tap spring when [pressLeans]. A flight
  /// heads for its slot once answered; a flick's from its release.
  void _steerX({required bool answered, required bool pressLeans}) {
    switch (_phase) {
      case LensPhase.dragging:
        if (!answered) return;
        if (reduceMotion) {
          _x.target = _aim;
        } else {
          _x.retarget(_aim, profile.dragFollow);
        }
      case LensPhase.pressed:
        // A press that may still be a tap moves on the tap spring (the
        // native tab traces include their 66 ms press).
        if (answered && pressLeans && !reduceMotion) {
          _x.retarget(_aim, profile.tap);
        }
      case LensPhase.flying:
        if (answered || _flick) _x.target = _flightTarget;
      case LensPhase.settling || LensPhase.rest:
        break;
    }
  }

  /// Retargets [value] to [target], on [rising] when it grows, else on
  /// [falling].
  static void _fade(
    SpringValue value,
    double target,
    SpringDescription rising,
    SpringDescription falling,
  ) => value.retarget(target, target >= value.value ? rising : falling);

  /// The tab envelope's targets.
  void _tabTargets(double since) {
    final rest = _geometry.restLensAt(_x.value);
    var w = rest.width;
    var h = rest.height;
    var scale = 1.0;
    var engage = 0.0;
    var refraction = 0.0;
    var highlight = 0.0;
    final answered = reduceMotion || since >= profile.tapDelay;
    final pressing =
        _phase == LensPhase.pressed || _phase == LensPhase.dragging;
    _steerX(answered: answered, pressLeans: true);
    // A tap shows the press until 25 ms after its press ends, and a tap
    // quicker than 66 ms reads as a 66 ms press: every measured native tap
    // was one, and the lens swells before it lifts (research §3 trace).
    final pressLook =
        answered &&
        !reduceMotion &&
        (pressing ||
            (_phase == LensPhase.flying &&
                !_flick &&
                since < _releaseAt + profile.tapDelay));
    if (pressLook) {
      w *= TabSprings.pressWidthFactor;
      h *= TabSprings.pressHeightFactor;
      scale = pressing ? TabSprings.pressScale : TabSprings.bulge;
      engage = 1;
      refraction = 1;
      highlight = pressing
          ? TabSprings.highlightPress
          : TabSprings.highlightTap;
    } else if (_phase == LensPhase.flying && _flick) {
      w *= TabSprings.stretchFloor;
      h *= 1 + TabSprings.liftGain;
      engage = 1;
      refraction = 1;
    } else if (_phase == LensPhase.flying && answered) {
      final inflation = _geometry.tapInflation;
      if (inflation != null) {
        if (since < TabSprings.liftUntil) {
          w *= inflation.width;
          h *= inflation.height;
        }
      } else if (_flightSlots == 1) {
        // One slot lifts: narrow and tall until 0.20 s (research §3).
        if (since < TabSprings.liftUntil) {
          w *= TabSprings.stretchFloor;
          h *= 1 + TabSprings.liftGain;
        }
      } else {
        // Two slots or more stretch wide and low with the lens's speed and
        // hold the widest stretch until 0.20 s, then lift late (research
        // §3 trace: 127 × 56 at 0.18 s, 115 × 66 at 0.28 s).
        if (since < TabSprings.liftUntil) {
          _stretch = math.max(_stretch, TabSprings.stretchFor(_x.velocity));
          w *= _stretch;
        } else if (since < TabSprings.farLiftUntil) {
          h *= 1 + TabSprings.liftGain * TabSprings.liftGateFar;
        }
      }
      scale = since < TabSprings.bulgeUntil ? TabSprings.bulge : 1;
      engage = since < TabSprings.flightHold ? 1 : 0;
      refraction = since < TabSprings.refractUntil ? 1 : 0;
      highlight = since < TabSprings.highlightUntil
          ? TabSprings.highlightTap
          : 0;
    }
    _fade(_w, w, TabSprings.widthIn, TabSprings.widthOut);
    _fade(_h, h, TabSprings.heightIn, TabSprings.heightOut);
    _fade(_scale, scale, TabSprings.scaleIn, TabSprings.scaleOut);
    _fade(_engage, engage, profile.engageIn, profile.engageOut);
    _fade(_refraction, refraction, profile.effectIn, profile.effectOut);
    _fade(_highlight, highlight, TabSprings.highlightIn, profile.effectOut);
    // The glow, like the lens, answers 25 ms after the down (research
    // LittleGlowView trace: 0.06 at 33 ms, 0.23 at 66 ms).
    final holding = interacting && !reduceMotion && answered;
    _glowOpacity.retarget(
      holding ? TabSprings.glowOpacity : 0,
      holding ? TabSprings.glowIn : profile.effectOut,
    );
    if (holding) _glowDiameter.target = TabSprings.glowHeldDiameter;
  }

  /// The segment envelope's targets, [since]
  /// seconds after the down, the commit or the programmatic change. No
  /// glow, pill scale, highlight or pop: those springs stay at rest.
  void _segmentTargets(SegmentEnvelope e, double since) {
    final flight = _phase == LensPhase.flying ? _flight : null;
    // A press does not move x (`press`, `pressOther`); a drag follows.
    _steerX(
      answered: switch (flight) {
        _Flight.tap => since >= e.slide.delay,
        _Flight.show => since >= e.showDelay,
        _Flight.release || null => true,
      },
      pressLeans: false,
    );
    if (flight == _Flight.tap && since >= e.slide.secondaryDelay) {
      _x2.target = _flightTarget;
    }
    final rest = _geometry.restLensAt(_lensX);
    final pressed = Size(
      rest.width + e.pressGrow.width,
      rest.height + e.pressGrow.height,
    );
    // The size target (null: keep it) and its spring (null: keep it).
    Size? size = rest;
    SpringDescription? spring;
    var engage = 0.0;
    if (reduceMotion) {
      // The rest-size capsule, never engaged (spec §12.2).
    } else if (interacting) {
      spring = e.pressSize;
      final dragging = _phase == LensPhase.dragging;
      if ((dragging || _pressOnLens) && since >= e.pressDelay) {
        size = dragging ? _squashed(e, pressed) : pressed;
        engage = 1;
      }
    } else if (flight == _Flight.tap) {
      final answered = since >= e.pressDelay;
      final lift = _lift(e);
      final lifting = since < _liftUntil(e);
      (size, spring) = _liftThenWobble(
        e,
        rest,
        lift,
        lifting: lifting,
        answered: answered,
      );
      if (!lifting && answered && _follow == null) {
        // The lift is over: the side it stretched most wobbles back, the
        // other keeps the area (spec §8.4).
        _follow = lift.width * rest.width >= lift.height * rest.height
            ? _Follow.height
            : _Follow.width;
        _area
          ..spring = e.wobbleArea
          ..place(
            _w.value * _h.value,
            _w.value * _h.velocity + _h.value * _w.velocity,
          );
      }
      engage = answered && since < e.engageHold ? 1 : 0;
    } else if (flight == _Flight.release) {
      if (since < _releaseAt) {
        spring = e.pressSize;
        size = pressed;
      } else if (since < _releaseAt + e.releaseDelay) {
        size = null;
      } else if (_landAt case final at?) {
        (size, spring) = _liftThenWobble(
          e,
          rest,
          _landing,
          lifting: since < at + e.landingHold,
          answered: true,
        );
      } else {
        spring = e.releaseSize;
      }
      final hold = _flick ? profile.flickHold : profile.releaseHold;
      engage = since < _releaseAt + hold ? 1 : 0;
    } else if (flight == _Flight.show) {
      spring = e.releaseSize;
    }
    if (size != null) {
      _w.target = size.width;
      _h.target = size.height;
    }
    if (spring != null) {
      _w.spring = spring;
      _h.spring = spring;
    }
    // A tap's wobble keeps the area to rest, through its settling; a press,
    // a release or a programmatic slide drives both sides again.
    if (flight != _Flight.tap && flight != null) _follow = null;
    if (interacting || reduceMotion) _follow = null;
    _area.target = rest.width * rest.height;
    _fade(_engage, engage, profile.engageIn, profile.engageOut);
    _fade(_refraction, engage, profile.effectIn, profile.effectOut);
  }

  /// A segment tap's lift gains: by its direction on screen.
  Size _lift(SegmentEnvelope e) => _liftLeft ? e.liftLeft : e.liftRight;

  /// When a segment tap's lift ends: by its direction on screen.
  double _liftUntil(SegmentEnvelope e) =>
      _liftLeft ? e.liftUntil.$2 : e.liftUntil.$1;

  /// The side that keeps the area takes its value from it.
  void _followArea() {
    final follow = _follow;
    if (follow == null) return;
    final (driver, follower) = switch (follow) {
      _Follow.height => (_w, _h),
      _Follow.width => (_h, _w),
    };
    final d = math.max(driver.value, 1);
    follower.place(
      _area.value / d,
      (_area.velocity * d - _area.value * driver.velocity) / (d * d),
    );
  }

  /// [pressed] squashed by the lens speed: narrower and taller above the
  /// knee, up to the limits.
  Size _squashed(SegmentEnvelope e, Size pressed) {
    final over = math.max(0, _x.velocity.abs() - e.squashKnee);
    return Size(
      pressed.width *
          math.max(e.squashMax.width, 1 - e.squashGain.width * over),
      pressed.height *
          math.min(e.squashMax.height, 1 + e.squashGain.height * over),
    );
  }

  /// A drag release's landing gains at lens speed [velocity]:
  /// [SegmentEnvelope.landing] scaled as the drag squash is, from nothing
  /// at the knee to all of it where the squash saturates.
  static Size _landingFor(SegmentEnvelope e, double velocity) {
    final over = math.max(0, velocity.abs() - e.squashKnee);
    final scale = math.min(
      1,
      over * e.squashGain.width / (1 - e.squashMax.width),
    );
    return Size(e.landing.width * scale, e.landing.height * scale);
  }

  /// The hand-off a tap's lift and a fast release's landing share:
  /// while [lifting], the size heads on the press spring for [rest] scaled
  /// by [gain] (once [answered]); after, the wobble spring takes it back
  /// to rest.
  static (Size, SpringDescription) _liftThenWobble(
    SegmentEnvelope e,
    Size rest,
    Size gain, {
    required bool lifting,
    required bool answered,
  }) {
    if (!lifting) return (rest, e.wobble);
    return (
      answered
          ? Size(rest.width * (1 + gain.width), rest.height * (1 + gain.height))
          : rest,
      e.pressSize,
    );
  }

  /// The ripple's progress [age] seconds after the lift: a critically
  /// damped spring of [TabSprings.glowFade] response, 25 ms late. It fits
  /// the native LittleGlowView trace, scale and opacity alike (×1.54 and
  /// 0.82 of the glow at +83 ms, ×3.34 and 0.22 at +250 ms).
  double _rippleAt(double age) {
    final t = age - profile.tapDelay;
    if (t <= 0) return 0;
    final x = 2 * math.pi / TabSprings.glowFade * t;
    return 1 - math.exp(-x) * (1 + x);
  }

  void _advanceRipple(double dt) {
    final age = _rippleAge;
    if (age == null) return;
    final next = age + dt;
    if (_rippleAt(next) >= 0.99) {
      _rippleAge = null;
      _glowCenter = null;
      _glowOpacity.jump(0);
      _glowDiameter.jump(TabSprings.glowDiameter);
    } else {
      _rippleAge = next;
    }
  }

  void _advanceGhost(double dt) {
    if (_ghostSlot == null && _fadeIn >= 1) return;
    _ghostAge += dt;
    _fadeIn = (_ghostAge / profile.ghostFade).clamp(0.0, 1.0);
    if (_fadeIn >= 1) _ghostSlot = null;
  }

  void _queueCrossing() {
    final s = _geometry.slotNearest(_x.value);
    if (s == _lastSlot) return;
    _lastSlot = s;
    _crossings.add(s);
  }

  bool _isMoving() {
    if (interacting || _phase == LensPhase.flying) return true;
    if (_rippleAge != null || _ghostSlot != null || _fadeIn < 1) return true;
    return !(_x.settled(0.5) &&
        (_share == 0 || _x2.settled(0.5)) &&
        _w.settled(0.5) &&
        _h.settled(0.5) &&
        _scale.settled(0.001) &&
        _engage.settled(0.005) &&
        _refraction.settled(0.005) &&
        _highlight.settled(0.005) &&
        _glowOpacity.settled(0.005) &&
        _pop.settled(0.002));
  }

  /// The frame to paint now.
  LensFrame get frame {
    final cy = _geometry.slots.isEmpty ? 0.0 : _geometry.slots.first.center.dy;
    final age = _rippleAge;
    final ripple = age == null ? null : _rippleAt(age);
    return LensFrame(
      lens: Rect.fromCenter(
        center: Offset(_lensX, cy),
        width: _w.value,
        height: _h.value,
      ),
      visible: _committed != null || interacting,
      engage: _engage.value.clamp(0.0, 1.0),
      refraction: _refraction.value.clamp(0.0, 1.0),
      pillScale: _scale.value,
      highlight: _highlight.value.clamp(0.0, 1.0),
      glowCenter: _glowCenter,
      glowDiameter: ripple == null
          ? _glowDiameter.value
          : _rippleDiameter * (1 + (TabSprings.glowRipple - 1) * ripple),
      glowOpacity: ripple == null
          ? _glowOpacity.value.clamp(0.0, 1.0)
          : _rippleOpacity * (1 - ripple),
      popSlot: _popSlot,
      popScale: _pop.value,
      ghost: _ghostSlot == null ? null : _restRect(_ghostSlot),
      ghostOpacity: _ghostSlot == null ? 0 : 1 - _fadeIn,
      restOpacity: _fadeIn,
      magnifyGain: switch (profile.envelope) {
        TabEnvelope() => TabSprings.magnify,
        SegmentEnvelope(:final magnifyGain) => magnifyGain,
      },
    );
  }
}

/// The minimize morph scalar: 0 = full bar, 1 = circle.
class MinimizeMotion {
  /// Starts at rest.
  MinimizeMotion({required bool minimized})
    : _target = minimized,
      _value = SpringValue(minimized ? 1 : 0, TabSprings.collapse);

  /// Reduce motion: every change is instant.
  bool reduceMotion = false;

  bool _target;
  final SpringValue _value;
  double _wait = 0;

  /// The morph amount (it overshoots below 0 on expand).
  double get value => _value.value;

  /// The requested state.
  bool get minimized => _target;

  /// Requests [minimized]; a collapse waits [TabSprings.minimizeDelay]
  /// when [delayed].
  // The state is the call's subject (`set(true)`), as on a switch.
  // ignore: avoid_positional_boolean_parameters
  void set(bool minimized, {bool delayed = true}) {
    if (minimized == _target) return;
    _target = minimized;
    final end = minimized ? 1.0 : 0.0;
    if (reduceMotion) {
      _wait = 0;
      _value.jump(end);
      return;
    }
    _value.spring = minimized ? TabSprings.collapse : TabSprings.expand;
    // An expand is a tap (the circle, or a selection change): it answers
    // 25 ms later, as every native touch does (Task 16 review item 7).
    _wait = minimized
        ? (delayed ? TabSprings.minimizeDelay : 0)
        : TabSprings.tapDelay;
    if (_wait == 0) _value.target = end;
  }

  /// Advances [dt]; true while moving or waiting.
  bool advance(double dt) {
    var run = dt;
    if (_wait > 0) {
      _wait -= dt;
      if (_wait > 0) return true;
      // The wait ends inside this frame: only the rest of it moves.
      run = -_wait;
      _wait = 0;
      _value.target = _target ? 1 : 0;
    }
    _value.advance(run);
    if (_value.settled(0.005)) {
      _value.jump(_value.target);
      return false;
    }
    return true;
  }

  /// The ×0.96 dip at the midpoint.
  double get dip =>
      1 - TabSprings.dip * math.sin(math.pi * value.clamp(0.0, 1.0));
}
