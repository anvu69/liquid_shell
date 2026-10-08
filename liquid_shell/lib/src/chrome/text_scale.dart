import 'package:flutter/widgets.dart';

/// Accessibility text-scale threshold (about iOS AX1). From here bar cells
/// become icon-only and the label moves to semantics.
const double kAxTextScale = 1.6;

/// Largest icon size at accessibility text scales.
const double kAxMaxIconSize = 36;

/// Whether the ambient text scale is at or above [kAxTextScale], measured
/// on 14pt text because the system scaler can be non-linear.
bool isAxTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14 >= kAxTextScale;

/// [base] scaled with the text, never below [base], capped at
/// [kAxMaxIconSize].
double axIconSize(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base).clamp(base, kAxMaxIconSize);
