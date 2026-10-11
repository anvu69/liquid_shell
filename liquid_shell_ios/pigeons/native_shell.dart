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

// --- Native dialogs (spec P3a §6) ------------------------------------------

/// What a native dialog is.
enum NativeDialogKind { alert, actionSheet }

/// How an action looks (`UIAlertAction.Style`).
enum NativeDialogActionStyle { standard, cancel, destructive }

/// How a dialog ended.
enum NativeDialogOutcome { chose, dismissed, unavailable }

/// Why a dialog was not shown (spec P3a §5.2).
enum NativeDialogUnavailableReason {
  osTooOld,
  noWindow,
  refused,
  disabledByEnvironment,
}

class NativeDialogAction {
  NativeDialogAction({
    required this.label,
    required this.style,
    required this.enabled,
  });

  String label;
  NativeDialogActionStyle style;
  bool enabled;
}

/// A rect in the Flutter view's points.
class NativeRect {
  NativeRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double x;
  double y;
  double width;
  double height;
}

class NativeDialogRequest {
  NativeDialogRequest({
    required this.kind,
    required this.actions,
    required this.tintArgb,
    required this.dark,
    required this.rtl,
    required this.requireGlass,
    this.title,
    this.message,
    this.preferredIndex,
    this.anchor,
  });

  NativeDialogKind kind;
  String? title;
  String? message;
  List<NativeDialogAction> actions;
  int? preferredIndex;
  NativeRect? anchor;
  int tintArgb;
  bool dark;
  bool rtl;
  bool requireGlass;
}

class NativeDialogResult {
  NativeDialogResult({required this.outcome, this.actionIndex, this.reason});

  NativeDialogOutcome outcome;
  int? actionIndex;
  NativeDialogUnavailableReason? reason;
}

/// Test-only: the dialog on screen.
class NativeDialogSnapshot {
  NativeDialogSnapshot({
    required this.kind,
    required this.labels,
    this.title,
    this.message,
    this.preferredIndex,
    this.sourceRect,
  });

  NativeDialogKind kind;
  String? title;
  String? message;
  List<String> labels;
  int? preferredIndex;
  NativeRect? sourceRect;
}

/// Dart → native dialogs.
@HostApi()
abstract class NativeDialogHostApi {
  /// Presents [request]; answers when it closes, or at once when it
  /// cannot be shown.
  @async
  NativeDialogResult present(NativeDialogRequest request);

  /// Debug builds only: the dialog this engine shows, or null.
  NativeDialogSnapshot? debugCurrent();

  /// Debug builds only: closes the dialog this engine shows as if
  /// [actionIndex] were tapped; -1 dismisses it without a choice.
  void debugRespond(int actionIndex);
}
