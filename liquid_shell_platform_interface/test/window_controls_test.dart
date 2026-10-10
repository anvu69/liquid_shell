import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  group('LiquidWindowControls', () {
    test('zero is the default and isZero', () {
      expect(LiquidWindowControls.zero.isZero, isTrue);
      expect(const LiquidWindowControls(leading: 1).isZero, isFalse);
    });

    test('sanitized turns negative and non-finite fields into 0', () {
      expect(
        LiquidWindowControls.sanitized(leading: -4, top: double.nan),
        LiquidWindowControls.zero,
      );
      expect(
        LiquidWindowControls.sanitized(
          leading: double.infinity,
          top: double.negativeInfinity,
        ),
        LiquidWindowControls.zero,
      );
      expect(
        LiquidWindowControls.sanitized(leading: 78, top: 24),
        const LiquidWindowControls(leading: 78, top: 24),
      );
    });

    test('indentFor indents only rows that start inside the band', () {
      const controls = LiquidWindowControls(leading: 78, top: 24);
      expect(controls.indentFor(rowTop: 0), 78);
      expect(controls.indentFor(rowTop: 16), 78);
      expect(controls.indentFor(rowTop: 24), 0);
      expect(LiquidWindowControls.zero.indentFor(rowTop: 0), 0);
    });

    test('== and hashCode compare both fields', () {
      const a = LiquidWindowControls(leading: 1, top: 2);
      expect(a, const LiquidWindowControls(leading: 1, top: 2));
      expect(
        a.hashCode,
        const LiquidWindowControls(leading: 1, top: 2).hashCode,
      );
      expect(a, isNot(const LiquidWindowControls(leading: 1, top: 3)));
      expect(a, isNot(const LiquidWindowControls(leading: 2, top: 2)));
      expect(a.toString(), 'LiquidWindowControls(leading: 1.0, top: 2.0)');
    });
  });
}
