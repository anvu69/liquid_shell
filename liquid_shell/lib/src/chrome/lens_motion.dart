import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/painting.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

/// What the lens is doing (spec VK-503 §8.2).
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

/// Everything the bar paints for one frame (spec §8.4). Bar-local.
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
  });

  /// The lens capsule.
  final Rect lens;

  /// Whether a lens is drawn at all (nothing selected and untouched: no).
  final bool visible;

  /// 0 = gray rest fill, 1 = clear glass (spec §7.1).
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

  /// Scale of the tinted copy about the lens centre.
  double get magnify => 1 + TabSprings.magnify * engage;

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
  );
}

/// The lens state machine (spec §8). Pure: the widget feeds it pointer
/// events in bar-local coordinates and calls [advance] once per frame.
class LensMotion {
  /// Starts at rest on [selected] (null: nothing highlighted).
  LensMotion({
    required TabBarGeometry geometry,
    required int? selected,
    this.reduceMotion = false,
  }) : _geometry = geometry,
       _committed = _valid(selected, geometry) {
    final rest = _restRect(_committed);
    _x = SpringValue(rest.center.dx, TabSprings.tap);
    _w = SpringValue(rest.width, TabSprings.widthOut);
    _h = SpringValue(rest.height, TabSprings.heightOut);
  }

  /// Reduce motion (spec §13.2).
  bool reduceMotion;

  TabBarGeometry _geometry;
  int? _committed;
  int? _pending;
  LensPhase _phase = LensPhase.rest;

  late final SpringValue _x;
  late final SpringValue _w;
  late final SpringValue _h;
  final SpringValue _scale = SpringValue(1, TabSprings.scaleOut);
  final SpringValue _engage = SpringValue(0, TabSprings.engageOut);
  final SpringValue _refraction = SpringValue(0, TabSprings.effectOut);
  final SpringValue _highlight = SpringValue(0, TabSprings.effectOut);
  final SpringValue _glowOpacity = SpringValue(0, TabSprings.glowIn);
  final SpringValue _glowDiameter = SpringValue(
    TabSprings.glowDiameter,
    TabSprings.glowIn,
  );
  final SpringValue _pop = SpringValue(1, TabSprings.tap);

  Offset? _glowCenter;
  double? _rippleAge;
  double _rippleOpacity = 0;
  double _rippleDiameter = TabSprings.glowDiameter;
  double _downX = 0;
  double _travel = 0;

  /// Time since the touch-down (or the semantics tap) that started this
  /// interaction: native answers 25 ms after the down, and a tap's flight
  /// envelope is timed from it (research §3, §4.1).
  double _since = 0;

  /// Where the press aims the lens: the finger, clamped to the slots.
  double _aim = 0;

  /// The flight follows a flick to the finger's slot (spec §8.2).
  bool _flick = false;

  /// The widest stretch of this flight so far (two slots or more).
  double _stretch = 1;

  /// When the tap's press ends on the [_since] clock: the lift, or 66 ms
  /// for a quicker tap. The lens keeps the press look 25 ms past it.
  double _releaseAt = 0;
  int _flightSlots = 1;
  double _flightTarget = 0;
  int? _popSlot;
  int _lastSlot = 0;
  final List<int> _crossings = [];
  int? _ghostSlot;
  double _ghostAge = 0;
  double _fadeIn = 1;

  List<SpringValue> get _springs => [
    _x,
    _w,
    _h,
    _scale,
    _engage,
    _refraction,
    _highlight,
    _glowOpacity,
    _glowDiameter,
    _pop,
  ];

  static int? _valid(int? slot, TabBarGeometry g) =>
      slot != null && slot >= 0 && slot < g.slots.length ? slot : null;

  /// The geometry; a new one at rest moves the lens without animation.
  TabBarGeometry get geometry => _geometry;
  set geometry(TabBarGeometry value) {
    if (value == _geometry) return;
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

  /// A commit the app has not confirmed yet (spec §8.7).
  int? get pending => _pending;

  /// A finger is down.
  bool get interacting =>
      _phase == LensPhase.pressed || _phase == LensPhase.dragging;

  Rect _restRect(int? slot) => slot == null || slot >= _geometry.slots.length
      ? Rect.zero
      : _geometry.slots[slot];

  void _jumpTo(int? slot) {
    final r = _restRect(slot);
    _x.jump(r.center.dx);
    _w.jump(r.width);
    _h.jump(r.height);
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
    if (reduceMotion) {
      // No slide toward the finger: a tap dissolves in place (§13.2). The
      // capsule follows only once the press turns into a drag.
      _x.spring = TabSprings.reduced;
    } else {
      // The lens turns toward the finger 25 ms after the down, not at it
      // (research §4.1 trace: the press answers at 25-30 ms).
      _x.spring = TabSprings.dragFollow;
      _glowCenter = local;
      _rippleAge = null;
      _glowDiameter.jump(TabSprings.glowDiameter);
    }
  }

  /// Finger moved to [local].
  void move(Offset local) {
    if (!interacting) return;
    _travel = math.max(_travel, (local.dx - _downX).abs());
    if (_travel > kTouchSlop) _phase = LensPhase.dragging;
    if (!reduceMotion) _glowCenter = local;
    if (reduceMotion && _phase == LensPhase.pressed) return;
    _aim = _geometry.clampCentre(local.dx);
    if (reduceMotion || _since >= TabSprings.tapDelay) _x.target = _aim;
  }

  /// Finger up at [local] with horizontal [velocity]; returns the committed
  /// slot (spec §8.2).
  int? up(Offset local, {double velocity = 0}) {
    if (!interacting) return null;
    final tap = _phase == LensPhase.pressed;
    final flick = velocity.abs() >= TabSprings.flickVelocity;
    final slot = _geometry.slotNearest(tap || flick ? local.dx : _x.value);
    _startRipple();
    _commit(slot, tap: tap, flick: flick && !tap);
    return slot;
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

  /// A programmatic selection: jump (spec §8.7, Q12).
  void show(int? slot) {
    _pending = null;
    _committed = _valid(slot, _geometry);
    _jumpTo(_committed);
  }

  /// The app adopted the pending commit.
  void accept() => _pending = null;

  /// The app did not adopt it: snap back to [slot].
  void returnTo(int? slot) {
    _pending = null;
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
      reduceMotion ? TabSprings.reduced : TabSprings.snap,
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
    if (flick) {
      // Native keeps the clear lens through the flight to the finger's slot
      // and lands it on the follow spring (research trace: 0.12 s from
      // release, engaged until it lands). Spec §8.2, Task 16.
      _phase = LensPhase.flying;
      _flick = true;
      _flightSlots = 1;
      _flightTarget = _geometry.centreOf(slot);
      _x.retarget(_flightTarget, TabSprings.dragFollow);
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
    final late = _releaseAt + TabSprings.releaseHold - TabSprings.flightHold;
    if (late > 0) {
      _since -= late;
      _releaseAt -= late;
    }
    _flightSlots = from == null ? 1 : math.max(1, (slot - from).abs());
    _flightTarget = _geometry.centreOf(slot);
    // Timed from the down: within the first 25 ms the lens still holds;
    // after that it flies on, keeping the speed the press gave it.
    if (_since >= TabSprings.tapDelay) {
      _x.retarget(_flightTarget, TabSprings.tap);
    } else {
      _x.spring = TabSprings.tap;
    }
    _popSlot = slot;
    _pop.retarget(TabSprings.pop, TabSprings.tap);
  }

  /// Advances [dt] seconds; true while anything still moves.
  bool advance(double dt) {
    final before = _since;
    if (_phase != LensPhase.settling && _phase != LensPhase.rest) {
      _since += dt;
    }
    // The 25 ms delay ends inside this frame: every spring runs to it on
    // the old targets, then the rest of the frame on the new ones, so the
    // lens answers at 25 ms, not a frame early.
    final crossing =
        !reduceMotion &&
        before < TabSprings.tapDelay &&
        _since >= TabSprings.tapDelay;
    if (crossing) {
      _setTargets(before);
      for (final s in _springs) {
        s.advance(TabSprings.tapDelay - before);
      }
    }
    _setTargets(_since);
    final rest = crossing ? _since - TabSprings.tapDelay : dt;
    for (final s in _springs) {
      s.advance(rest);
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
      _popSlot = null;
      _phase = LensPhase.rest;
    }
    return moving;
  }

  /// A flight ends when its envelope is over (a tap) or when it lands (a
  /// flick: the lens first within 1 pt of the finger's slot).
  void _endFlight() {
    if (_flick) {
      if ((_x.value - _flightTarget).abs() <= 1) _phase = LensPhase.settling;
      return;
    }
    if (_since >= TabSprings.popUntil) _pop.target = 1;
    if (_since >= TabSprings.flightHold) _phase = LensPhase.settling;
  }

  /// The targets of every spring at [since] seconds into the interaction.
  void _setTargets(double since) {
    final rest = _geometry.restLensAt(_x.value);
    var w = rest.width;
    var h = rest.height;
    var scale = 1.0;
    var engage = 0.0;
    var refraction = 0.0;
    var highlight = 0.0;
    final answered = reduceMotion || since >= TabSprings.tapDelay;
    final pressing =
        _phase == LensPhase.pressed || _phase == LensPhase.dragging;
    if (pressing && answered && !reduceMotion) {
      // A press that may still be a tap moves on the tap spring (the native
      // tap traces include their 66 ms press); a drag follows the finger.
      _x.retarget(
        _aim,
        _phase == LensPhase.dragging ? TabSprings.dragFollow : TabSprings.tap,
      );
    }
    // A tap shows the press until 25 ms after its press ends, and a tap
    // quicker than 66 ms reads as a 66 ms press: every measured native tap
    // was one, and the lens swells before it lifts (research §3 trace).
    final pressLook =
        answered &&
        !reduceMotion &&
        (pressing ||
            (_phase == LensPhase.flying &&
                !_flick &&
                since < _releaseAt + TabSprings.tapDelay));
    if (pressLook) {
      if (!pressing) _x.target = _flightTarget;
      w *= TabSprings.pressWidthFactor;
      h *= TabSprings.pressHeightFactor;
      scale = pressing ? TabSprings.pressScale : TabSprings.bulge;
      engage = 1;
      refraction = 1;
      highlight = pressing
          ? TabSprings.highlightPress
          : TabSprings.highlightTap;
    } else if (_phase == LensPhase.flying && _flick) {
      _x.target = _flightTarget;
      w *= TabSprings.stretchFloor;
      h *= 1 + TabSprings.liftGain;
      engage = 1;
      refraction = 1;
    } else if (_phase == LensPhase.flying && answered) {
      _x.target = _flightTarget;
      if (_geometry.form == TabBarForm.top) {
        if (since < TabSprings.liftUntil) {
          w *= TabSprings.topTapWidth;
          h *= TabSprings.topTapHeight;
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
    _w.retarget(w, w >= _w.value ? TabSprings.widthIn : TabSprings.widthOut);
    _h.retarget(h, h >= _h.value ? TabSprings.heightIn : TabSprings.heightOut);
    _scale.retarget(
      scale,
      scale >= _scale.value ? TabSprings.scaleIn : TabSprings.scaleOut,
    );
    _engage.retarget(
      engage,
      engage >= _engage.value ? TabSprings.engageIn : TabSprings.engageOut,
    );
    _refraction.retarget(
      refraction,
      refraction >= _refraction.value
          ? TabSprings.effectIn
          : TabSprings.effectOut,
    );
    _highlight.retarget(
      highlight,
      highlight >= _highlight.value
          ? TabSprings.highlightIn
          : TabSprings.effectOut,
    );
    // The glow, like the lens, answers 25 ms after the down (research
    // LittleGlowView trace: 0.06 at 33 ms, 0.23 at 66 ms).
    final holding = interacting && !reduceMotion && answered;
    _glowOpacity.retarget(
      holding ? TabSprings.glowOpacity : 0,
      holding ? TabSprings.glowIn : TabSprings.effectOut,
    );
    if (holding) _glowDiameter.target = TabSprings.glowHeldDiameter;
  }

  /// The ripple's progress [age] seconds after the lift: a critically
  /// damped spring of [TabSprings.glowFade] response, 25 ms late. It fits
  /// the native LittleGlowView trace, scale and opacity alike (×1.54 and
  /// 0.82 of the glow at +83 ms, ×3.34 and 0.22 at +250 ms).
  static double _rippleAt(double age) {
    final t = age - TabSprings.tapDelay;
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
    _fadeIn = (_ghostAge / TabSprings.ghostFade).clamp(0.0, 1.0);
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
    final cy = _geometry.slots.isEmpty
        ? _geometry.size.height / 2
        : _geometry.slots.first.center.dy;
    final age = _rippleAge;
    final ripple = age == null ? null : _rippleAt(age);
    return LensFrame(
      lens: Rect.fromCenter(
        center: Offset(_x.value, cy),
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
    );
  }
}

/// The minimize morph scalar: 0 = full bar, 1 = circle (spec VK-503 §10).
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
