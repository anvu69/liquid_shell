import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  group('LiquidPlatformSignals.fromMap', () {
    test('reads every field from a full payload', () {
      final signals = LiquidPlatformSignals.fromMap(const {
        'reduceTransparency': true,
        'powerSave': true,
        'blurDisabled': true,
      });
      expect(
        signals,
        const LiquidPlatformSignals(
          reduceTransparency: true,
          powerSave: true,
          blurDisabled: true,
        ),
      );
    });

    test('a missing field is false', () {
      final signals = LiquidPlatformSignals.fromMap(const {'powerSave': true});
      expect(signals.reduceTransparency, isFalse);
      expect(signals.powerSave, isTrue);
      expect(signals.blurDisabled, isFalse);
    });

    test('a non-bool field is false and unknown keys are ignored', () {
      final signals = LiquidPlatformSignals.fromMap(const {
        'reduceTransparency': 1,
        'powerSave': 'true',
        'blurDisabled': null,
        'somethingNew': true,
      });
      expect(signals, LiquidPlatformSignals.none);
    });

    test('a non-map payload is none', () {
      expect(LiquidPlatformSignals.fromMap(null), LiquidPlatformSignals.none);
      expect(LiquidPlatformSignals.fromMap(true), LiquidPlatformSignals.none);
      expect(
        LiquidPlatformSignals.fromMap(const [true]),
        LiquidPlatformSignals.none,
      );
    });
  });

  test('none has every signal off', () {
    expect(LiquidPlatformSignals.none.reduceTransparency, isFalse);
    expect(LiquidPlatformSignals.none.powerSave, isFalse);
    expect(LiquidPlatformSignals.none.blurDisabled, isFalse);
  });

  test('== and hashCode compare every field', () {
    const a = LiquidPlatformSignals(powerSave: true);
    const b = LiquidPlatformSignals(powerSave: true);
    const c = LiquidPlatformSignals(blurDisabled: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a.toString(), contains('powerSave: true'));
  });
}
