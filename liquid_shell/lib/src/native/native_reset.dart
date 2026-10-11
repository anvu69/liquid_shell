import 'package:flutter/foundation.dart';
import 'package:liquid_shell/src/dialogs/dialog_plan.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell/src/native/window_controls.dart';

/// Forgets the process-wide native chrome link and window-controls source,
/// and the remembered native dialog refusals, so the next shell asks
/// `LiquidShellPlatform.instance` afresh. For tests that swap the platform
/// instance; call it in `tearDown`.
@visibleForTesting
void debugResetLiquidNative() {
  NativeChromeHost.debugReset();
  WindowControlsSource.debugReset();
  NativeDialogMemory.debugReset();
}
