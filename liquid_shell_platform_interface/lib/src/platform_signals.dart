import 'package:flutter/foundation.dart';

/// Accessibility and power signals read from the operating system.
///
/// `liquid_shell` maps them to a glass tier (its spec 2026-10-10 §6).
/// Every field defaults to `false`; a signal that cannot be read is
/// reported as `false`.
@immutable
class LiquidPlatformSignals {
  /// Creates a set of signals. Every field defaults to `false`.
  const LiquidPlatformSignals({
    this.reduceTransparency = false,
    this.powerSave = false,
    this.blurDisabled = false,
    this.lowEnd = false,
    this.glesOnly = false,
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
      lowEnd: read('lowEnd'),
      glesOnly: read('glesOnly'),
    );
  }

  /// Every signal off.
  static const none = LiquidPlatformSignals();

  /// iOS Reduce Transparency; on Android, animations off or high contrast.
  final bool reduceTransparency;

  /// Android battery saver; iOS Low Power Mode.
  final bool powerSave;

  /// Android 12+: the system disabled window blurs.
  final bool blurDisabled;

  /// Android: a low-RAM device or under 3 GiB of memory.
  final bool lowEnd;

  /// Android 10+ without Vulkan 1.1: Flutter renders with OpenGL ES.
  final bool glesOnly;

  @override
  bool operator ==(Object other) =>
      other is LiquidPlatformSignals &&
      other.reduceTransparency == reduceTransparency &&
      other.powerSave == powerSave &&
      other.blurDisabled == blurDisabled &&
      other.lowEnd == lowEnd &&
      other.glesOnly == glesOnly;

  @override
  int get hashCode => Object.hash(
    reduceTransparency,
    powerSave,
    blurDisabled,
    lowEnd,
    glesOnly,
  );

  @override
  String toString() =>
      'LiquidPlatformSignals(reduceTransparency: $reduceTransparency, '
      'powerSave: $powerSave, blurDisabled: $blurDisabled, '
      'lowEnd: $lowEnd, glesOnly: $glesOnly)';
}
