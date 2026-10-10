import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/dialogs/dialog_plan.dart';
import 'package:liquid_shell/src/dialogs/dialog_types.dart';
import 'package:liquid_shell/src/dialogs/glass_dialogs.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Shows an alert and completes with the chosen action's value.
///
/// Who draws it depends on [presentation]:
///
/// * [LiquidDialogPresentation.auto] (the default): on iOS 26 and later,
///   the system's `UIAlertController`, with Liquid Glass and above any
///   native chrome. On earlier iOS and on Android, a Flutter glass alert.
/// * [LiquidDialogPresentation.system]: the system's `UIAlertController`
///   on every iOS version (without glass before 26); a Flutter glass alert
///   elsewhere.
/// * [LiquidDialogPresentation.flutter]: always the Flutter glass alert.
///
/// The Flutter glass alert is also drawn when the system one cannot be
/// shown, for example when the app runs with the diagnostic environment
/// variable `LIQUID_SHELL_NATIVE_OFF=1`. It is pushed on the root
/// [Navigator], so [context] needs one above it. [title], [message] and
/// every label come from the app.
///
/// Completes with the cancel action's value (or null without one) when
/// the alert closes without a choice (Escape, Android back, a dismissal by
/// the system), and with null when it could never be shown because
/// [context] was unmounted first. If the root [Navigator] is disposed
/// while the Flutter glass alert is up, the future never completes, as
/// with `showDialog`.
///
/// Throws [ArgumentError] at once, before anything is shown, for a blank
/// [title], no actions, more than one cancel or preferred action, a blank
/// label, a disabled preferred action, or no enabled action.
Future<T?> showLiquidAlert<T>(
  BuildContext context, {
  required String title,
  required List<LiquidAlertAction<T>> actions,
  String? message,
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
}) {
  if (title.trim().isEmpty) {
    throw ArgumentError.value(title, 'title', 'must not be blank');
  }
  checkAlertActions(actions);
  return _present(
    context,
    actions: actions,
    presentation: presentation,
    strings: const LiquidShellStrings(),
    request: dialogRequestFor(
      context,
      kind: LiquidNativeDialogKind.alert,
      title: title,
      message: message,
      actions: actions,
      presentation: presentation,
    ),
  );
}

/// Shows an action sheet and completes with the chosen action's value.
///
/// [presentation] picks who draws it, as for [showLiquidAlert]: the
/// system's `UIAlertController` on iOS 26 and later with
/// [LiquidDialogPresentation.auto], on every iOS with
/// [LiquidDialogPresentation.system], and otherwise (or with
/// `LIQUID_SHELL_NATIVE_OFF=1`) a Flutter glass sheet pushed on the root
/// [Navigator] above [context].
///
/// On iPad, and in the Flutter sheet at regular width, the sheet points
/// at [anchor] (global logical coordinates); when [anchor] is null it
/// points at [context]'s render box. So pass the tapped widget's context,
/// for example from a `Builder` around the button. [strings] labels the
/// Flutter sheet's barrier for screen readers.
///
/// Completes with the cancel action's value (or null without one) when
/// the sheet closes without a choice (a tap outside, Escape, Android back,
/// a dismissal by the system), and with null when it could never be shown
/// because [context] was unmounted first. If the root [Navigator] is
/// disposed while the Flutter glass sheet is up, the future never
/// completes, as with `showDialog`.
///
/// Throws [ArgumentError] at once, before anything is shown, for no
/// actions, more than one cancel action, a blank label, more than one or
/// a disabled preferred action, or no enabled action.
Future<T?> showLiquidActionSheet<T>(
  BuildContext context, {
  required List<LiquidAlertAction<T>> actions,
  String? title,
  String? message,
  Rect? anchor,
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
  LiquidShellStrings strings = const LiquidShellStrings(),
}) {
  checkAlertActions(actions);
  return _present(
    context,
    actions: actions,
    presentation: presentation,
    strings: strings,
    request: dialogRequestFor(
      context,
      kind: LiquidNativeDialogKind.actionSheet,
      title: title,
      message: message,
      actions: actions,
      presentation: presentation,
      anchor: anchor ?? anchorOf(context),
    ),
  );
}

/// Native first; the Flutter glass dialog when the platform has none,
/// refuses, fails, or [presentation] asks for Flutter.
Future<T?> _present<T>(
  BuildContext context, {
  required LiquidNativeDialogRequest request,
  required List<LiquidAlertAction<T>> actions,
  required LiquidDialogPresentation presentation,
  required LiquidShellStrings strings,
}) async {
  final platform = LiquidShellPlatform.instance;
  final memory = NativeDialogMemory.instance;
  if (presentation != LiquidDialogPresentation.flutter &&
      platform.supportsNativeDialogs &&
      !memory.refuses(requireGlass: request.requireGlass)) {
    switch (await _presentNative(platform, request)) {
      case LiquidNativeDialogChose(:final index):
        return dialogValue(actions, index);
      case LiquidNativeDialogDismissed():
        return dialogValue(actions, null);
      case LiquidNativeDialogUnavailable(:final reason):
        memory.remember(reason, requireGlass: request.requireGlass);
    }
    if (!context.mounted) return null;
  }
  final index = await showGlassDialog(context, request, strings: strings);
  return dialogValue(actions, index);
}

/// [platform]'s native dialog, never an error. Implementations turn a
/// `PlatformException` into
/// [LiquidNativeDialogUnavailableReason.channelError] themselves; anything
/// else they throw (a reply that does not decode, a broken implementation)
/// is reported to [FlutterError] and becomes `channelError` here, so the
/// caller gets the Flutter fallback instead of the error.
Future<LiquidNativeDialogResult> _presentNative(
  LiquidShellPlatform platform,
  LiquidNativeDialogRequest request,
) async {
  try {
    return await platform.presentNativeDialog(request);
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'liquid_shell',
        context: ErrorDescription('while presenting a native dialog'),
      ),
    );
    return const LiquidNativeDialogUnavailable(
      LiquidNativeDialogUnavailableReason.channelError,
    );
  }
}
