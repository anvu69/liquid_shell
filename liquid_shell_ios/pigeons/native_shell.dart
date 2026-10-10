// Pigeon source of the native shell channel (spec §6). Nothing imports it:
// `make pigeon` reads it and writes both ends, which are committed:
//   lib/src/native_shell_api.g.dart
//   ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift
// Edit this file, run `make pigeon`, commit all three. `make pigeon-check`
// (part of `make verify`) fails when the generated files drift.
//
// Pigeon's DSL: positional parameters are the order on the wire.
// ignore_for_file: avoid_positional_boolean_parameters
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/native_shell_api.g.dart',
    dartPackageName: 'liquid_shell_ios',
    swiftOut:
        'ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift',
  ),
)
/// Where the native sidebar is.
enum NativeSidebar { hidden, overlay, tiled }

/// Why the native shell is not installed.
enum NativeUnavailableReason {
  osTooOld,
  iPadAppOnMac,
  notEnabled,
  disabledByEnvironment,
  rootNotFlutter,
  registeredLate,
}

/// What `attach()` returns and `onStateChanged` pushes.
class NativeShellState {
  NativeShellState({
    required this.installed,
    required this.compact,
    required this.sidebar,
    this.unavailableReason,
  });

  bool installed;
  bool compact;
  NativeSidebar sidebar;
  NativeUnavailableReason? unavailableReason;
}

class NativeTab {
  NativeTab({
    required this.title,
    required this.sfSymbol,
    required this.sidebarOnly,
    this.badge,
  });

  String title;
  String sfSymbol;
  String? badge;
  bool sidebarOnly;
}

class NativeAction {
  NativeAction({required this.title, required this.sfSymbol});

  String title;
  String sfSymbol;
}

class NativeFooter {
  NativeFooter({
    required this.title,
    required this.subtitle,
    required this.sfSymbol,
    required this.semanticLabel,
  });

  String title;
  String subtitle;
  String sfSymbol;
  String semanticLabel;
}

/// The whole chrome. Applied in order: tabs, selection, footer, tint,
/// appearance, direction, visibility.
class NativeChromeConfig {
  NativeChromeConfig({
    required this.engaged,
    required this.tabs,
    required this.selectedIndex,
    required this.tintArgb,
    required this.dark,
    required this.rtl,
    required this.hidden,
    required this.interactive,
    this.trailing,
    this.footer,
  });

  bool engaged;
  List<NativeTab> tabs;
  int selectedIndex;
  NativeAction? trailing;
  NativeFooter? footer;
  int tintArgb;
  bool dark;
  bool rtl;
  bool hidden;
  bool interactive;
}

class NativeWindowControls {
  NativeWindowControls({required this.leading, required this.top});

  double leading;
  double top;
}

/// Test-only: what `debugTap` taps.
enum NativeTapTarget { destination, trailing, footer }

/// Dart → native.
@HostApi()
abstract class NativeShellHostApi {
  NativeShellState attach();

  void update(NativeChromeConfig config);

  void setSidebarVisible(bool visible);

  NativeWindowControls windowControls();

  /// Debug builds only: runs the same code path as a user tap on [target].
  /// Release builds ignore it.
  void debugTap(NativeTapTarget target, int index);
}

/// Native → Dart.
@FlutterApi()
abstract class NativeShellFlutterApi {
  void onDestinationTapped(int index);

  void onTrailingTapped();

  void onFooterTapped();

  void onStateChanged(NativeShellState state);

  void onWindowControlsChanged(NativeWindowControls controls);
}
