import 'package:flutter/foundation.dart';

/// Accessibility and power signals read from the operating system.
///
/// Any of them being `true` makes `liquid_shell` draw solid instead of
/// glass. Every field defaults to `false`; a signal that cannot be read is
/// reported as `false`.
@immutable
class LiquidPlatformSignals {
  /// Creates a set of signals. Every field defaults to `false`.
  const LiquidPlatformSignals({
    this.reduceTransparency = false,
    this.powerSave = false,
    this.blurDisabled = false,
  });

  /// Lenient decoding of a channel payload.
  ///
  /// Unknown keys are ignored. A missing or non-`bool` field is `false`. A
  /// payload that is not a map is [none].
  factory LiquidPlatformSignals.fromMap(Object? payload) {
    if (payload is! Map) return none;
    bool read(String key) => payload[key] == true;
    return LiquidPlatformSignals(
      reduceTransparency: read('reduceTransparency'),
      powerSave: read('powerSave'),
      blurDisabled: read('blurDisabled'),
    );
  }

  /// Every signal off.
  static const none = LiquidPlatformSignals();

  /// iOS Reduce Transparency; on Android, animations off or high contrast.
  final bool reduceTransparency;

  /// Android battery saver.
  final bool powerSave;

  /// Android 12+: the system disabled window blurs.
  final bool blurDisabled;

  @override
  bool operator ==(Object other) =>
      other is LiquidPlatformSignals &&
      other.reduceTransparency == reduceTransparency &&
      other.powerSave == powerSave &&
      other.blurDisabled == blurDisabled;

  @override
  int get hashCode => Object.hash(reduceTransparency, powerSave, blurDisabled);

  @override
  String toString() =>
      'LiquidPlatformSignals(reduceTransparency: $reduceTransparency, '
      'powerSave: $powerSave, blurDisabled: $blurDisabled)';
}
