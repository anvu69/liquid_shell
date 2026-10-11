/// The platform interface of the liquid_shell federated plugin.
///
/// Apps depend on `liquid_shell`, never on this package directly.
library;

export 'src/event_channel_platform.dart';
export 'src/liquid_shell_platform.dart';
export 'src/native_chrome.dart';
export 'src/native_dialog.dart';
export 'src/platform_signals.dart';
export 'src/window_controls.dart';
