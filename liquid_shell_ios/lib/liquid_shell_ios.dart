/// The iOS implementation of liquid_shell.
library;

import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Registers the event-channel signal reader for iOS.
///
/// Called by the generated plugin registrant. Apps never call it.
abstract final class LiquidShellIOS {
  /// Makes [EventChannelLiquidShellPlatform] the active implementation.
  static void registerWith() {
    LiquidShellPlatform.instance = EventChannelLiquidShellPlatform();
  }
}
