import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:liquid_shell/src/dialogs/dialog_metrics.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

// The pure layout rules of the Flutter glass dialogs (spec P3a §7).

int _cancelIndex(List<LiquidNativeDialogAction> actions) => actions.indexWhere(
  (action) => action.style == LiquidNativeDialogActionStyle.cancel,
);

/// Whether an alert's actions sit side by side, as UIKit does: exactly
/// two, each label fitting in half the row at [textScaler].
bool alertActionsSideBySide({
  required List<String> labels,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double rowWidth,
}) {
  if (labels.length != 2) return false;
  final room = (rowWidth - kActionGap) / 2 - 2 * kActionLabelPadding;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: textScaler,
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width > room) return false;
  }
  return true;
}

/// The order an alert shows its actions in, as indices into [actions].
/// Side by side, the cancel action leads; stacked, it comes last.
List<int> alertDisplayOrder(
  List<LiquidNativeDialogAction> actions, {
  required bool sideBySide,
}) {
  final cancel = _cancelIndex(actions);
  final others = [
    for (var i = 0; i < actions.length; i++)
      if (i != cancel) i,
  ];
  if (cancel < 0) return others;
  return sideBySide ? [cancel, ...others] : [...others, cancel];
}

/// An action sheet's stacked actions and its cancel action, drawn apart.
({List<int> main, int? cancel}) sheetGroups(
  List<LiquidNativeDialogAction> actions,
) {
  final cancel = _cancelIndex(actions);
  return (
    main: [
      for (var i = 0; i < actions.length; i++)
        if (i != cancel) i,
    ],
    cancel: cancel < 0 ? null : cancel,
  );
}

/// The top-left corner of the regular-width action-sheet card: below
/// [anchor] if it fits, else above, centred on it, kept [kAnchorGap] inside
/// the safe area; the screen's centre without an anchor.
Offset anchoredCardOffset({
  required Size screen,
  required EdgeInsets padding,
  required Size card,
  required Rect? anchor,
}) {
  final left = padding.left + kAnchorGap;
  final right = math.max(
    left,
    screen.width - padding.right - kAnchorGap - card.width,
  );
  final top = padding.top + kAnchorGap;
  final bottom = math.max(
    top,
    screen.height - padding.bottom - kAnchorGap - card.height,
  );
  if (anchor == null) {
    return Offset(
      ((screen.width - card.width) / 2).clamp(left, right),
      ((screen.height - card.height) / 2).clamp(top, bottom),
    );
  }
  final x = (anchor.center.dx - card.width / 2).clamp(left, right);
  final below = anchor.bottom + kAnchorGap;
  final y = below <= bottom
      ? below
      : (anchor.top - kAnchorGap - card.height).clamp(top, bottom);
  return Offset(x, y);
}
