import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _params = LiquidOpticsParams(
  tint: Color(0x38FFFFFF),
  rim: Color(0x80FFFFFF),
  refraction: 1,
  dispersion: 0.3,
  blurSigma: 3,
);

List<double> _uniforms(
  Rect rect, {
  BorderRadius radii = BorderRadius.zero,
  LiquidOpticsParams params = _params,
  double scale = 3,
  Size pass = const Size(1179, 2556),
}) => liquidUniforms(
  rect: rect,
  radii: radii,
  params: params,
  scale: scale,
  pass: pass,
).toList();

Matcher _floats(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (a, b) => (a - b).abs() < 1e-4,
  'within 1e-4 of',
);

void main() {
  group('liquidDisplacement (spec §4.1 steps 4-7)', () {
    test('zero at the edge and once the bezel is flat', () {
      expect(liquidDisplacement(0), 0);
      expect(liquidDisplacement(1), 0);
      expect(liquidDisplacement(1.5), 0);
    });

    test('inward (negative), peaking about 27 near the edge', () {
      // Bezel 20, thickness 48 (spec §3.6.1): past ~2 pt in, the shift falls
      // faster than the depth grows, so the band mirrors what lies inside.
      expect(liquidDisplacement(0.02), closeTo(-22.384, 0.01));
      expect(liquidDisplacement(0.05), closeTo(-27.233, 0.01));
      expect(liquidDisplacement(0.1), closeTo(-26.107, 0.01));
      expect(liquidDisplacement(0.3), closeTo(-13.724, 0.01));
      expect(liquidDisplacement(0.5), closeTo(-4.904, 0.01));
    });

    test('scales with thickness and vanishes without it', () {
      expect(liquidDisplacement(0.1, thickness: 96), closeTo(-64.567, 0.01));
      expect(liquidDisplacement(0.1, thickness: 0), 0);
    });

    test('dispersion: a higher index bends more', () {
      expect(liquidDisplacement(0.1, index: 1.47), closeTo(-25.157, 0.01));
      expect(liquidDisplacement(0.1, index: 1.53), closeTo(-27.028, 0.01));
    });
  });

  group('liquidUniforms (spec §4.2)', () {
    test('a pill in the middle of the screen, at 3x', () {
      // 320x64 pt at (40, 700) pt; radius 999 clamps to half the height.
      const rect = Rect.fromLTWH(120, 2100, 960, 192);
      expect(
        _uniforms(rect, radii: BorderRadius.circular(999)),
        _floats([
          120, 2100, 960, 192, // rect
          96, 96, 96, 96, // radii: min(999*3, 192/2)
          60, 144, 1.5, 0.3, // bezel 20*3, thickness 48*3, index, dispersion
          1, 1, 1, 0x38 / 255, // tint
          1, 1, 1, 0x80 / 255, // rim
          -0.5, -0.85, 4.5, 1.1, // light, rim width 1.5*3, saturation
        ]),
      );
    });

    test('per-corner radii keep their order tl, tr, br, bl', () {
      const rect = Rect.fromLTWH(300, 300, 600, 300);
      final u = _uniforms(
        rect,
        radii: const BorderRadius.only(
          topLeft: Radius.circular(1),
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(3),
          bottomLeft: Radius.circular(4),
        ),
      );
      expect(u.sublist(4, 8), _floats([3, 6, 9, 12]));
    });

    test('the bezel never exceeds half the short side', () {
      final u = _uniforms(const Rect.fromLTWH(300, 300, 600, 40));
      expect(u[8], 20);
    });

    test('refraction and dispersion feed thickness and spread', () {
      final flat = _uniforms(
        const Rect.fromLTWH(300, 300, 600, 300),
        params: const LiquidOpticsParams(
          tint: Color(0x00000000),
          rim: Color(0x00000000),
          refraction: 0,
          dispersion: 2, // clamps to 1
          blurSigma: 0,
        ),
      );
      expect(flat[9], 0);
      expect(flat[11], 1);
    });

    test('screen-edge rule: a sidebar flush left, top and bottom', () {
      // 320 pt sidebar on an 834x1194 pt iPad at 2x.
      const pass = Size(1668, 2388);
      const rect = Rect.fromLTWH(0, 0, 640, 2388);
      final u = _uniforms(rect, scale: 2, pass: pass);
      // reach = bezel 40 + max radius 0 + 2 = 42 on the left, top, bottom.
      expect(u.sublist(0, 4), _floats([-42, -42, 682, 2472]));
    });

    test('screen-edge rule in RTL: flush right, top and bottom', () {
      const pass = Size(1668, 2388);
      const rect = Rect.fromLTWH(1028, 0, 640, 2388);
      final u = _uniforms(rect, scale: 2, pass: pass);
      expect(u.sublist(0, 4), _floats([1028, -42, 682, 2472]));
    });

    test('scale 1 keeps logical numbers', () {
      final u = _uniforms(
        const Rect.fromLTWH(10, 10, 100, 50),
        scale: 1,
        pass: const Size(400, 800),
      );
      expect(u.sublist(8, 10), _floats([20, 48]));
      // List index k is shader float k + 2: index 22 is the rim width.
      expect(u[22], 1.5);
    });

    test('returns LiquidOptics.floatCount floats', () {
      expect(
        _uniforms(const Rect.fromLTWH(300, 300, 600, 300)),
        hasLength(LiquidOptics.floatCount),
      );
    });
  });

  test('LiquidOpticsParams equality', () {
    expect(_params, _params.copyWithForTest());
    expect(_params.hashCode, _params.copyWithForTest().hashCode);
    expect(
      _params,
      isNot(
        const LiquidOpticsParams(
          tint: Color(0x38FFFFFF),
          rim: Color(0x80FFFFFF),
          refraction: 1,
          dispersion: 0.31,
          blurSigma: 3,
        ),
      ),
    );
  });
}

extension on LiquidOpticsParams {
  LiquidOpticsParams copyWithForTest() => LiquidOpticsParams(
    tint: tint,
    rim: rim,
    refraction: refraction,
    dispersion: dispersion,
    blurSigma: blurSigma,
  );
}
