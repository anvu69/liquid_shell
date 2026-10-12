import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/chrome/lens_track.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

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
    final t = LensProfile.tab;
    final sliding = LensProfile(
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
}
