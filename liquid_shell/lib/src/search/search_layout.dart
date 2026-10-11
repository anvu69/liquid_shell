import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';

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

/// The fallback morph (Q12).
const Duration kSearchMorphDuration = Duration(milliseconds: 350);

/// The fallback morph's curve (Q12).
const Curve kSearchMorphCurve = Curves.easeOutCubic;

/// The compact collapsed circle, field and × height (iOS 26: 48).
const double kSearchCompactExtent = 48;

/// Selected: the collapsed circle's start and the field's end margin.
const double kSearchSelectedMargin = 28;

/// Selected: the gap between the collapsed circle and the field.
const double kSearchSelectedGap = 12;

/// The regular field's height (iPad: 44).
const double kRegularSearchFieldExtent = 44;

/// The regular field's side margins (iPad: 20).
const double kRegularSearchMargin = 20;

/// Where the compact search parts are (spec P3b §9.2).
@immutable
class CompactSearchRects {
  /// Creates the rects.
  const CompactSearchRects({
    required this.circle,
    required this.field,
    required this.cancel,
  });

  /// The collapsed circle (previous tab).
  final Rect circle;

  /// The ⌕ circle (idle) or the field.
  final Rect field;

  /// The × circle.
  final Rect cancel;

  @override
  bool operator ==(Object other) =>
      other is CompactSearchRects &&
      other.circle == circle &&
      other.field == field &&
      other.cancel == cancel;

  @override
  int get hashCode => Object.hash(circle, field, cancel);
}

/// The compact parts for [phase]: the bottom row ends at [rowBottom] and is
/// [rowExtent] tall (P1's pill); [keyboard] is the software keyboard's
/// height (0 with a hardware keyboard).
CompactSearchRects compactSearchRects({
  required LiquidSearchPhase phase,
  required Size size,
  required double rowBottom,
  required double rowExtent,
  required double margin,
  required double keyboard,
  required TextDirection direction,
}) {
  final width = size.width;
  final rowTop = rowBottom - rowExtent;
  final top = rowTop + (rowExtent - kSearchCompactExtent) / 2;
  final circle = Rect.fromLTWH(
    kSearchSelectedMargin,
    top,
    kSearchCompactExtent,
    kSearchCompactExtent,
  );
  final selectedField = Rect.fromLTRB(
    kSearchSelectedMargin + kSearchCompactExtent + kSearchSelectedGap,
    top,
    width - kSearchSelectedMargin,
    top + kSearchCompactExtent,
  );
  final activeBottom = keyboard > 0
      ? size.height - keyboard - kSearchFieldGap
      : top + kSearchCompactExtent;
  final (collapsed, field, cancel) = switch (phase) {
    LiquidSearchPhase.idle => (
      Rect.fromLTWH(margin, top, kSearchCompactExtent, kSearchCompactExtent),
      Rect.fromLTWH(width - margin - rowExtent, rowTop, rowExtent, rowExtent),
      Rect.fromLTWH(
        width - margin - kSearchCompactExtent,
        top,
        kSearchCompactExtent,
        kSearchCompactExtent,
      ),
    ),
    LiquidSearchPhase.selected => (
      circle,
      selectedField,
      Rect.fromLTWH(
        selectedField.right - kSearchCompactExtent,
        top,
        kSearchCompactExtent,
        kSearchCompactExtent,
      ),
    ),
    LiquidSearchPhase.active => (
      circle,
      Rect.fromLTRB(
        kSearchFieldGap,
        activeBottom - kSearchCompactExtent,
        width - 2 * kSearchFieldGap - kSearchCompactExtent,
        activeBottom,
      ),
      Rect.fromLTWH(
        width - kSearchFieldGap - kSearchCompactExtent,
        activeBottom - kSearchCompactExtent,
        kSearchCompactExtent,
        kSearchCompactExtent,
      ),
    ),
  };
  Rect place(Rect r) => direction == TextDirection.rtl
      ? Rect.fromLTRB(width - r.right, r.top, width - r.left, r.bottom)
      : r;
  return CompactSearchRects(
    circle: place(collapsed),
    field: place(field),
    cancel: place(cancel),
  );
}

/// The regular field's top (spec P3b §9.3): one row below the Flutter top
/// bar (or 54pt below the safe top beside a tiled sidebar); active, the bar
/// row itself.
double regularSearchFieldTop({
  required LiquidSearchPhase phase,
  required double paddingTop,
  required double barExtent,
  required bool tiled,
}) {
  final active = phase == LiquidSearchPhase.active;
  if (tiled) return paddingTop + (active ? 5 : 54);
  return active
      ? paddingTop + kTopBarGap
      : paddingTop + kTopBarGap + barExtent + kSearchFieldGap;
}
