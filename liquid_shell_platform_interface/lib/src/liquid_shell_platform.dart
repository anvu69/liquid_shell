import 'package:liquid_shell_platform_interface/src/platform_signals.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that platform implementations of liquid_shell extend.
///
/// Implementations must `extend` this class (not `implement` it), so that
/// adding a method later is not a breaking change.
abstract class LiquidShellPlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  LiquidShellPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiquidShellPlatform _instance = _NoSignalLiquidShellPlatform();

  /// The active implementation.
  ///
  /// Defaults to one that emits [LiquidPlatformSignals.none] once and never
  /// touches a platform channel (web, desktop, `flutter test`).
  static LiquidShellPlatform get instance => _instance;

  /// Platform packages set this from their `registerWith()`.
  static set instance(LiquidShellPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Emits the current signals on listen, then every change.
  Stream<LiquidPlatformSignals> watchSignals();
}

class _NoSignalLiquidShellPlatform extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(LiquidPlatformSignals.none);
}
