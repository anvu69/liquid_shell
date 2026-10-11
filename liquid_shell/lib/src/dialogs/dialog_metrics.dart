import 'package:flutter/painting.dart';

// Geometry of the Flutter glass dialogs (spec P3a §7), measured from the
// native iOS 26.5 alert and action sheet (docs/qa/p3a/metrics.md). Tests
// read these constants, so a re-measure moves code and tests together.

/// Widest alert card.
const double kAlertWidth = 320;

/// Alert card corner radius.
const double kAlertRadius = 34;

/// Inner padding of the alert card: around the actions, and above the
/// header.
const EdgeInsets kAlertPadding = EdgeInsets.fromLTRB(16, 24, 16, 16);

/// Extra horizontal inset of the title and message, inside [kAlertPadding]
/// (UIKit's labels sit 30pt from the card edge, its actions 16pt).
const double kAlertHeaderInset = 14;

/// Smallest gap between a dialog and the screen edge.
const double kDialogMargin = 16;

/// Tallest a dialog may be, as a fraction of the screen height.
const double kDialogMaxHeightFraction = 0.8;

/// Title size.
const double kTitleFontSize = 17;

/// Message size.
const double kMessageFontSize = 15;

/// Gap between title and message.
const double kTitleMessageGap = 7;

/// Gap between the header and the actions.
const double kHeaderGap = 19;

/// Action label size.
const double kActionFontSize = 17;

/// Height of one action capsule.
const double kActionHeight = 48;

/// Gap between action capsules.
const double kActionGap = 8;

/// Horizontal padding inside an action capsule.
const double kActionLabelPadding = 12;

/// Fill of a plain action capsule, as `onSurface` alpha.
const double kActionFillAlpha = 0.12;

/// Dim colour behind a dialog.
const Color kDialogBarrier = Color(0x33000000);

/// Widest compact action sheet.
const double kSheetMaxWidth = 420;

/// Width of the regular-width anchored action-sheet card.
const double kSheetPopoverWidth = 288;

/// Corner radius of a sheet group and of the anchored card.
const double kSheetRadius = 32;

/// Inner padding of a sheet group.
const double kSheetGroupPadding = 16;

/// Padding around a sheet's title and message, inside [kSheetGroupPadding].
const EdgeInsets kSheetHeaderPadding = EdgeInsets.fromLTRB(
  kAlertHeaderInset,
  8,
  kAlertHeaderInset,
  kHeaderGap,
);

/// Side and bottom margin of a compact sheet.
const double kSheetSideMargin = 8;

/// Gap between the anchored card and its anchor or the screen edge.
const double kAnchorGap = 8;

/// Alert entrance length.
const Duration kAlertDuration = Duration(milliseconds: 250);

/// Sheet entrance length.
const Duration kSheetDuration = Duration(milliseconds: 300);

/// Scale an alert grows from.
const double kAlertScaleFrom = 1.08;

/// Scale the anchored card grows from.
const double kCardScaleFrom = 0.95;
