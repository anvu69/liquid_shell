import 'package:flutter/material.dart';
import 'package:liquid_shell/src/dialogs/dialog_types.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Throws [ArgumentError] for actions UIKit would crash on or draw blank:
/// none, more than one cancel action, more than one preferred action, a
/// blank label (spec P3a §4.2).
void checkAlertActions<T>(List<LiquidAlertAction<T>> actions) {
  if (actions.isEmpty) {
    throw ArgumentError.value(actions, 'actions', 'needs at least one action');
  }
  final cancels = actions
      .where((a) => a.style == LiquidAlertActionStyle.cancel)
      .length;
  if (cancels > 1) {
    throw ArgumentError.value(actions, 'actions', 'at most one cancel action');
  }
  if (actions.where((a) => a.preferred).length > 1) {
    throw ArgumentError.value(
      actions,
      'actions',
      'at most one preferred action',
    );
  }
  if (actions.any((a) => a.label.trim().isEmpty)) {
    throw ArgumentError.value(actions, 'actions', 'every label needs text');
  }
}

/// The value for a dialog that ended on [index], or without a choice
/// (null): then the cancel action's value, or null without one.
T? dialogValue<T>(List<LiquidAlertAction<T>> actions, int? index) {
  if (index != null && index >= 0 && index < actions.length) {
    return actions[index].value;
  }
  for (final action in actions) {
    if (action.style == LiquidAlertActionStyle.cancel) return action.value;
  }
  return null;
}

/// [context]'s render box in global logical coordinates (the Flutter
/// view's points), or null before layout.
Rect? anchorOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final rect = Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
  return rect.isFinite ? rect : null;
}

/// The request for a dialog, read from [context] before any await.
LiquidNativeDialogRequest dialogRequestFor<T>(
  BuildContext context, {
  required LiquidNativeDialogKind kind,
  required List<LiquidAlertAction<T>> actions,
  required LiquidDialogPresentation presentation,
  String? title,
  String? message,
  Rect? anchor,
}) {
  final theme = Theme.of(context);
  final preferred = actions.indexWhere((a) => a.preferred);
  return LiquidNativeDialogRequest(
    kind: kind,
    title: title,
    message: message,
    actions: [
      for (final action in actions)
        LiquidNativeDialogAction(
          label: action.label,
          style: switch (action.style) {
            LiquidAlertActionStyle.standard =>
              LiquidNativeDialogActionStyle.standard,
            LiquidAlertActionStyle.cancel =>
              LiquidNativeDialogActionStyle.cancel,
            LiquidAlertActionStyle.destructive =>
              LiquidNativeDialogActionStyle.destructive,
          },
          enabled: action.enabled,
        ),
    ],
    preferredIndex: kind == LiquidNativeDialogKind.alert && preferred >= 0
        ? preferred
        : null,
    anchor: anchor != null && anchor.isFinite ? anchor : null,
    tintArgb: theme.colorScheme.primary.toARGB32(),
    dark: theme.brightness == Brightness.dark,
    rtl: Directionality.of(context) == TextDirection.rtl,
    requireGlass: presentation != LiquidDialogPresentation.system,
  );
}

/// Refusals that cannot change while the process runs (spec P3a §6):
/// later calls skip the channel and draw Flutter at once.
final class NativeDialogMemory {
  NativeDialogMemory._();

  /// The memory. Replaced by [debugReset].
  static NativeDialogMemory instance = NativeDialogMemory._();

  /// Forgets everything. Tests, through `debugResetLiquidNative`.
  static void debugReset() => instance = NativeDialogMemory._();

  bool _osTooOld = false;
  bool _disabled = false;

  /// Whether a request with [requireGlass] is known to be refused.
  bool refuses({required bool requireGlass}) =>
      _disabled || (requireGlass && _osTooOld);

  /// Remembers [reason] if it is permanent.
  void remember(
    LiquidNativeDialogUnavailableReason reason, {
    required bool requireGlass,
  }) {
    switch (reason) {
      case LiquidNativeDialogUnavailableReason.osTooOld:
        if (requireGlass) _osTooOld = true;
      case LiquidNativeDialogUnavailableReason.disabledByEnvironment:
        _disabled = true;
      case LiquidNativeDialogUnavailableReason.unsupportedPlatform ||
          LiquidNativeDialogUnavailableReason.noWindow ||
          LiquidNativeDialogUnavailableReason.refused ||
          LiquidNativeDialogUnavailableReason.channelError:
        break;
    }
  }
}
