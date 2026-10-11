import 'package:liquid_shell_platform_interface/src/native_chrome.dart';
import 'package:liquid_shell_platform_interface/src/native_dialog.dart';
import 'package:liquid_shell_platform_interface/src/platform_signals.dart';
import 'package:liquid_shell_platform_interface/src/window_controls.dart';
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

  /// Whether this platform can ever provide native chrome. Read
  /// synchronously, so a shell knows whether to wait for
  /// [attachNativeChrome] before drawing its own chrome. Default: false.
  bool get supportsNativeChrome => false;

  /// The native shell's current state. Safe to call again (hot restart).
  /// Default: [LiquidNativeShellState.unavailable].
  Future<LiquidNativeShellState> attachNativeChrome() async =>
      LiquidNativeShellState.unavailable;

  /// Sends the whole native chrome config. Default: does nothing.
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) async {}

  /// Shows or hides the native sidebar. Default: does nothing.
  Future<void> setNativeSidebarVisible({required bool visible}) async {}

  /// Reads the window controls now. Default: [LiquidWindowControls.zero].
  Future<LiquidWindowControls> readWindowControls() async =>
      LiquidWindowControls.zero;

  /// Native taps, native shell changes and window-control changes, as a
  /// broadcast stream. Default: no events.
  Stream<LiquidNativeEvent> get nativeEvents => const Stream.empty();

  /// Whether this platform may present native dialogs. Read synchronously,
  /// so a caller without them draws its own at once. Default: false.
  bool get supportsNativeDialogs => false;

  /// Presents [request] natively and completes when it closes, or at once
  /// with [LiquidNativeDialogUnavailable]. Default: unavailable
  /// ([LiquidNativeDialogUnavailableReason.unsupportedPlatform]).
  Future<LiquidNativeDialogResult> presentNativeDialog(
    LiquidNativeDialogRequest request,
  ) async => const LiquidNativeDialogUnavailable(
    LiquidNativeDialogUnavailableReason.unsupportedPlatform,
  );
}

class _NoSignalLiquidShellPlatform extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(LiquidPlatformSignals.none);
}
