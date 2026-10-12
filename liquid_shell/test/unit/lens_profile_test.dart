import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/chrome/lens_track.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

import '../helpers/native_rows.dart';

/// The tab profile with a programmatic slide (on its snap spring).
LensProfile slidingTab() {
  final t = LensProfile.tab;
  return LensProfile(
    tap: t.tap,
    dragFollow: t.dragFollow,
    snap: t.snap,
    flickLand: t.flickLand,
    reduced: t.reduced,
    engageIn: t.engageIn,
    engageOut: t.engageOut,
    effectIn: t.effectIn,
    effectOut: t.effectOut,
    tapDelay: t.tapDelay,
    flickVelocity: t.flickVelocity,
    flickHold: t.flickHold,
    releaseHold: t.releaseHold,
    ghostFade: t.ghostFade,
    envelope: t.envelope,
    programmatic: t.snap,
  );
}

void main() {
  test('LensProfile.tab is exactly TabSprings (spec VK-550 §4, R1)', () {
    final p = LensProfile.tab;
    expect(p.tap, same(TabSprings.tap));
    expect(p.dragFollow, same(TabSprings.dragFollow));
    expect(p.snap, same(TabSprings.snap));
    expect(p.flickLand, same(TabSprings.flickLand));
    expect(p.reduced, same(TabSprings.reduced));
    expect(p.engageIn, same(TabSprings.engageIn));
    expect(p.engageOut, same(TabSprings.engageOut));
    expect(p.effectIn, same(TabSprings.effectIn));
    expect(p.effectOut, same(TabSprings.effectOut));
    expect(p.tapDelay, TabSprings.tapDelay);
    expect(p.flickVelocity, TabSprings.flickVelocity);
    expect(p.flickHold, TabSprings.flickHold);
    expect(p.releaseHold, TabSprings.releaseHold);
    expect(p.ghostFade, TabSprings.ghostFade);
    expect(p.programmatic, isNull, reason: 'tabs jump (VK-503 Q12)');
    expect(p.envelope, isA<TabEnvelope>());
  });

  test('TabBarGeometry is a LensTrack; only the top form inflates taps', () {
    final LensTrack compact = compactTabGeometry(
      count: 3,
      maxWidth: 360,
      trailing: false,
      direction: TextDirection.ltr,
    );
    expect(compact.tapInflation, isNull);
    final top = topTabGeometry(
      labelWidths: const [40, 60, 50],
      iconOnly: const [false, false, false],
      maxWidth: 800,
      trailing: false,
      direction: TextDirection.ltr,
    );
    expect(top.tapInflation, const Size(1.34, 1.375));
  });

  test('LensMotion defaults to the tab profile', () {
    final m = LensMotion(
      geometry: compactTabGeometry(
        count: 3,
        maxWidth: 360,
        trailing: false,
        direction: TextDirection.ltr,
      ),
      selected: 0,
    );
    expect(m.profile, same(LensProfile.tab));
  });

  test('a programmatic spring slides show(); reduce motion still jumps', () {
    final sliding = slidingTab();
    final g = compactTabGeometry(
      count: 3,
      maxWidth: 360,
      trailing: false,
      direction: TextDirection.ltr,
    );
    final m = LensMotion(geometry: g, selected: 0, profile: sliding)..show(2);
    expect(m.committed, 2);
    expect(m.phase, LensPhase.settling);
    expect(m.frame.lens.center.dx, g.centreOf(0));
    expect(m.advance(1 / 60), isTrue);
    final x = m.frame.lens.center.dx;
    expect(x, greaterThan(g.centreOf(0)));
    expect(x, lessThan(g.centreOf(2)));
    for (var i = 0; i < 240 && m.advance(1 / 60); i++) {}
    expect(m.phase, LensPhase.rest);
    expect(m.frame.lens.center.dx, g.centreOf(2));

    final reduced = LensMotion(
      geometry: g,
      selected: 0,
      profile: sliding,
      reduceMotion: true,
    )..show(2);
    expect(reduced.phase, LensPhase.rest);
    expect(reduced.frame.lens.center.dx, g.centreOf(2));
  });

  test('a sliding show() mid-flight ends the tap pop and the flick hold', () {
    final g = compactTabGeometry(
      count: 3,
      maxWidth: 360,
      trailing: false,
      direction: TextDirection.ltr,
    );
    void settle(LensMotion m) {
      for (var i = 0; i < 240 && m.advance(1 / 60); i++) {}
    }

    final tap = LensMotion(geometry: g, selected: 0, profile: slidingTab())
      ..tapSlot(2);
    for (var i = 0; i < 6; i++) {
      tap.advance(1 / 60);
    }
    expect(tap.frame.popScale, greaterThan(1.05), reason: 'mid-pop');
    tap.show(1);
    settle(tap);
    expect(tap.phase, LensPhase.rest);
    expect(tap.frame.popScale, 1);
    expect(tap.frame.popSlot, isNull);

    final y = g.slots.first.center.dy;
    final flick = LensMotion(geometry: g, selected: 2, profile: slidingTab())
      ..down(Offset(g.centreOf(2), y));
    for (var i = 1; i <= 6; i++) {
      flick
        ..move(Offset(g.centreOf(2) - 20.0 * i, y))
        ..advance(1 / 60);
    }
    flick.up(Offset(g.centreOf(0), y), velocity: -1200);
    expect(flick.phase, LensPhase.flying);
    flick
      ..advance(1 / 60)
      ..show(1)
      ..advance(1 / 60);
    final engage = flick.frame.engage;
    flick.advance(1 / 60);
    expect(flick.frame.engage, lessThan(engage), reason: 'no flick hold');
    settle(flick);
    expect(flick.frame.lens.center.dx, g.centreOf(1));
    expect(flick.frame.engage, 0);
  });

  group('LensProfile.segment (spec VK-550 §8.2)', () {
    final fits = segmentReference()['fits'] as Map<String, dynamic>;
    final geometry = segmentReference()['geometry'] as Map<String, dynamic>;

    /// A spring's (damping ratio, response) for unit mass.
    (double, double) shapeOf(SpringDescription s) => (
      s.damping / (2 * math.sqrt(s.mass * s.stiffness)),
      2 * math.pi / math.sqrt(s.stiffness / s.mass),
    );

    void expectFit(SpringDescription s, String key) {
      final fit = fits[key] as Map<String, dynamic>;
      final (ratio, response) = shapeOf(s);
      expect(
        ratio,
        closeTo((fit['zeta'] as num).toDouble(), 1e-9),
        reason: key,
      );
      expect(
        response,
        closeTo((fit['response'] as num).toDouble(), 1e-9),
        reason: key,
      );
    }

    test('the native fits: programmatic, press and release sizes', () {
      final p = LensProfile.segment;
      expectFit(p.programmatic!, 'programmatic');
      final e = p.envelope as SegmentEnvelope;
      expectFit(e.pressSize, 'pressSize');
      expectFit(e.releaseSize, 'releaseSize');
      expect(
        e.pressDelay,
        (fits['pressSize'] as Map)['delay'],
      );
      expect(
        e.releaseDelay,
        (fits['releaseSize'] as Map)['delay'],
      );
      final grow = (geometry['pressedGrow'] as List).cast<num>();
      expect(e.pressGrow, Size(grow[0].toDouble(), grow[1].toDouble()));
    });

    test(
      'the finger follow is the VK-503 spring, as the drag lag confirms',
      () {
        final p = LensProfile.segment;
        expect(p.dragFollow, same(TabSprings.dragFollow));
        expect(
          p.tapDelay,
          0,
          reason: 'a segment press answers on its own delay',
        );
      },
    );
  });
}
