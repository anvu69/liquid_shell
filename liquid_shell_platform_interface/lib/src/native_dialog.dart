import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// What a native dialog is.
enum LiquidNativeDialogKind {
  /// A centred alert.
  alert,

  /// An action sheet: from the bottom (or its source) on a phone, a popover
  /// at its anchor on a tablet.
  actionSheet,
}

/// How a native dialog action looks.
enum LiquidNativeDialogActionStyle {
  /// A plain action.
  standard,

  /// The cancel action. At most one per dialog: UIKit raises on a second.
  cancel,

  /// A destructive action, drawn in the error colour.
  destructive,
}

/// One button of a native dialog. Values never cross the channel: the
/// platform answers with the button's index.
@immutable
class LiquidNativeDialogAction {
  /// Creates an action.
  const LiquidNativeDialogAction({
    required this.label,
    this.style = LiquidNativeDialogActionStyle.standard,
    this.enabled = true,
  });

  /// The button's text, from the app.
  final String label;

  /// How it looks.
  final LiquidNativeDialogActionStyle style;

  /// Whether it can be chosen.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogAction &&
      other.label == label &&
      other.style == style &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, style, enabled);

  @override
  String toString() =>
      'LiquidNativeDialogAction($label, ${style.name}, enabled: $enabled)';
}

/// A whole dialog, as the platform (or the Flutter fallback) draws it.
@immutable
class LiquidNativeDialogRequest {
  /// Creates a request.
  const LiquidNativeDialogRequest({
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

  /// Alert or action sheet.
  final LiquidNativeDialogKind kind;

  /// The title, or null.
  final String? title;

  /// The message under the title, or null.
  final String? message;

  /// The buttons, in the app's order.
  final List<LiquidNativeDialogAction> actions;

  /// The alert's preferred action (bold, Return key); null for none and
  /// always null for an action sheet.
  final int? preferredIndex;

  /// Where an action sheet points, in global logical coordinates (the
  /// Flutter view's points); null for the view's centre.
  final Rect? anchor;

  /// The app's accent colour, `Color.toARGB32()`.
  final int tintArgb;

  /// Whether the app's theme is dark.
  final bool dark;

  /// Whether the text direction is right-to-left.
  final bool rtl;

  /// Present natively only where the system dialog is Liquid Glass
  /// (iOS 26+); false presents it on every iOS.
  final bool requireGlass;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogRequest &&
      other.kind == kind &&
      other.title == title &&
      other.message == message &&
      listEquals(other.actions, actions) &&
      other.preferredIndex == preferredIndex &&
      other.anchor == anchor &&
      other.tintArgb == tintArgb &&
      other.dark == dark &&
      other.rtl == rtl &&
      other.requireGlass == requireGlass;

  @override
  int get hashCode => Object.hash(
    kind,
    title,
    message,
    Object.hashAll(actions),
    preferredIndex,
    anchor,
    tintArgb,
    dark,
    rtl,
    requireGlass,
  );
}

/// Why a native dialog was not shown.
enum LiquidNativeDialogUnavailableReason {
  /// The platform has no native dialogs (Android, web, desktop, tests).
  unsupportedPlatform,

  /// iOS before 26 and the request requires glass.
  osTooOld,

  /// The engine's view is not in a window (headless, add-to-app).
  noWindow,

  /// UIKit refused the presentation.
  refused,

  /// The diagnostic environment variable `LIQUID_SHELL_NATIVE_OFF=1`.
  disabledByEnvironment,

  /// A channel call failed.
  channelError,
}

/// How a native dialog ended.
@immutable
sealed class LiquidNativeDialogResult {
  const LiquidNativeDialogResult();
}

/// The user chose the action at [index].
final class LiquidNativeDialogChose extends LiquidNativeDialogResult {
  /// Creates the result.
  const LiquidNativeDialogChose(this.index);

  /// Index into the request's actions.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogChose && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'LiquidNativeDialogChose($index)';
}

/// The dialog closed without a choice (a tap outside a popover, a dismissal
/// by the system).
final class LiquidNativeDialogDismissed extends LiquidNativeDialogResult {
  /// Creates the result.
  const LiquidNativeDialogDismissed();

  @override
  bool operator ==(Object other) => other is LiquidNativeDialogDismissed;

  @override
  int get hashCode => (LiquidNativeDialogDismissed).hashCode;

  @override
  String toString() => 'LiquidNativeDialogDismissed()';
}

/// The dialog was not shown; the caller draws its own.
final class LiquidNativeDialogUnavailable extends LiquidNativeDialogResult {
  /// Creates the result.
  const LiquidNativeDialogUnavailable(this.reason);

  /// Why.
  final LiquidNativeDialogUnavailableReason reason;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogUnavailable && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'LiquidNativeDialogUnavailable(${reason.name})';
}
