import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/search/search_controller.dart';

/// Gap between the search field and the keyboard or a neighbour (iOS 26).
const double kSearchFieldGap = 8;

/// The index of the search destination, or null. The first one wins in
/// release builds (debug asserts there is at most one).
int? searchIndexOf(List<LiquidDestination> destinations) {
  for (final (i, d) in destinations.indexed) {
    if (d.role == LiquidDestinationRole.search) return i;
  }
  return null;
}

/// The search phase for a selection and the controller's focus.
LiquidSearchPhase searchPhaseFor({
  required int selected,
  required int? searchIndex,
  required bool active,
}) {
  if (searchIndex == null || selected != searchIndex) {
    return LiquidSearchPhase.idle;
  }
  return active ? LiquidSearchPhase.active : LiquidSearchPhase.selected;
}

/// The bottom inset that keeps content clear of the native search field
/// (spec P3b §4.6). Only a field in the lower half counts (the iPhone's
/// tab-hosted field); a stacked field at the top is in the top padding.
/// Active: down to the field's top, or the keyboard plus the field and its
/// gaps while Flutter's keyboard inset is still animating.
double nativeSearchBottomInset({
  required Rect field,
  required Size size,
  required EdgeInsets padding,
  required EdgeInsets viewInsets,
  required bool active,
}) {
  if (field.isEmpty || field.center.dy < size.height / 2) return 0;
  if (!active) return padding.bottom;
  return [
    padding.bottom,
    size.height - field.top,
    viewInsets.bottom + field.height + 2 * kSearchFieldGap,
  ].reduce(math.max);
}
