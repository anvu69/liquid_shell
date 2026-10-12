import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// iOS 26.5 tab bar metrics in logical points (spec VK-503 §5, research
/// §1).
abstract final class TabMetrics {
  /// Compact pill height at text scale 1.
  static const double pillExtent = 62;

  /// Inset of the slots inside the pill, on every side.
  static const double inset = 4;

  /// Slot pitch while the pill is not width-limited.
  static const double pitch = 86;

  /// Neighbouring selection capsules overlap by this much.
  static const double overlap = 8;

  /// Bottom row margin at each side.
  static const double margin = 21;

  /// Row margin of a narrow shell (P1 Q17).
  static const double narrowMargin = 8;

  /// Gap between the pill and the trailing circle.
  static const double trailingGap = 8;

  /// Minimized circle diameter.
  static const double minimized = 48;

  /// Minimized circle offset from the row start.
  static const double minimizedInset = 7;

  /// Icon frame size.
  static const Size iconFrame = Size(33, 28);

  /// Icon frame top below the pill top.
  static const double iconTop = 10;

  /// Label box top below the pill top.
  static const double labelTop = 39;

  /// Label box height at text scale 1.
  static const double labelHeight = 12;

  /// Badge capsule height (and minimum width).
  static const double badgeExtent = 21.33;

  /// Badge offset from the icon frame's trailing top corner.
  static const double badgeOutset = 4;

  /// Landscape pill height.
  static const double landscapeExtent = 44;

  /// Landscape item height.
  static const double landscapeItemExtent = 36;

  /// Gap between landscape items.
  static const double landscapeGap = 4;

  /// Landscape item width = label width + this.
  static const double landscapeItemPadding = 49;

  /// Landscape row margin.
  static const double landscapeMargin = 38;

  /// Regular top pill height.
  static const double topExtent = 48;

  /// Regular top item height.
  static const double topItemExtent = 40;

  /// Regular top item horizontal padding per side.
  static const double topItemPadding = 15.5;

  /// Regular top icon-only (search) item width.
  static const double topIconItemWidth = 48.5;

  /// Regular top row: gap below the safe-area top.
  static const double topRowGap = 5.5;
}

/// The three bar forms (spec §5).
enum TabBarForm {
  /// Compact portrait: icon over label, 62 pt pill.
  compact,

  /// Compact landscape: icon beside label, 44 pt pill.
  landscape,

  /// Regular top bar: label only, 48 pt pill.
  top,
}

/// Where everything in one tab bar is, in bar-local coordinates.
@immutable
class TabBarGeometry {
  /// Creates a geometry.
  const TabBarGeometry({
    required this.form,
    required this.size,
    required this.pill,
    required this.slots,
    required this.trailing,
    required this.minimized,
    required this.minimizedTrailing,
  });

  /// The form this geometry is for.
  final TabBarForm form;

  /// The bar's own box: the row width and the pill extent.
  final Size size;

  /// The pill.
  final Rect pill;

  /// Selection and hit capsule per shown destination, in destination order
  /// (mirrored in RTL: slot 0 is at the right).
  final List<Rect> slots;

  /// The trailing circle, or null.
  final Rect? trailing;

  /// The minimized circle.
  final Rect minimized;

  /// The minimized trailing circle, or null.
  final Rect? minimizedTrailing;

  /// Centre x of [slot].
  double centreOf(int slot) => slots[slot].center.dx;

  /// The slot whose centre is nearest [x]; the first one on a tie.
  int slotNearest(double x) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < slots.length; i++) {
      final d = (slots[i].center.dx - x).abs();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  /// [x] clamped between the outermost slot centres.
  double clampCentre(double x) {
    if (slots.isEmpty) return pill.center.dx;
    final a = slots.first.center.dx;
    final b = slots.last.center.dx;
    return x.clamp(math.min(a, b), math.max(a, b));
  }

  /// The lens size at rest with its centre at [x]: the slot size, or the
  /// two neighbouring slots' sizes interpolated (content-sized forms).
  Size restLensAt(double x) {
    if (slots.isEmpty) return Size.zero;
    final order = [...slots]
      ..sort((a, b) => a.center.dx.compareTo(b.center.dx));
    if (x <= order.first.center.dx) return order.first.size;
    if (x >= order.last.center.dx) return order.last.size;
    // first < x < last, so a later centre is >= x and i + 1 stays in range.
    var i = 0;
    while (x > order[i + 1].center.dx) {
      i++;
    }
    final a = order[i];
    final b = order[i + 1];
    final t = (x - a.center.dx) / (b.center.dx - a.center.dx);
    return Size.lerp(a.size, b.size, t)!;
  }

  @override
  bool operator ==(Object other) =>
      other is TabBarGeometry &&
      other.form == form &&
      other.size == size &&
      other.pill == pill &&
      listEquals(other.slots, slots) &&
      other.trailing == trailing &&
      other.minimized == minimized &&
      other.minimizedTrailing == minimizedTrailing;

  @override
  int get hashCode => Object.hash(
    form,
    size,
    pill,
    Object.hashAll(slots),
    trailing,
    minimized,
    minimizedTrailing,
  );
}

Rect _mirror(Rect r, double width, TextDirection direction) =>
    direction == TextDirection.rtl
    ? Rect.fromLTRB(width - r.right, r.top, width - r.left, r.bottom)
    : r;

/// Compact portrait geometry (spec §5.1). [maxWidth] is the row between
/// its margins; infinite means "as wide as the content".
TabBarGeometry compactTabGeometry({
  required int count,
  required double maxWidth,
  required bool trailing,
  required TextDirection direction,
  double extent = TabMetrics.pillExtent,
}) {
  const edge = 2 * TabMetrics.inset + TabMetrics.overlap;
  final natural = edge + TabMetrics.pitch * count;
  final reserve = trailing ? extent + TabMetrics.trailingGap : 0.0;
  final width = maxWidth.isFinite ? maxWidth : natural + reserve;
  final pillWidth = math.max(edge, math.min(natural, width - reserve));
  final left = trailing ? 0.0 : (width - pillWidth) / 2;
  final pitch = count == 0 ? 0.0 : (pillWidth - edge) / count;
  final lensHeight = extent - 2 * TabMetrics.inset;
  Rect m(Rect r) => _mirror(r, width, direction);
  final trailingRect = trailing
      ? Rect.fromLTWH(width - extent, 0, extent, extent)
      : null;
  return TabBarGeometry(
    form: TabBarForm.compact,
    size: Size(width, extent),
    pill: m(Rect.fromLTWH(left, 0, pillWidth, extent)),
    slots: [
      for (var i = 0; i < count; i++)
        m(
          Rect.fromLTWH(
            left + TabMetrics.inset + i * pitch,
            TabMetrics.inset,
            pitch + TabMetrics.overlap,
            lensHeight,
          ),
        ),
    ],
    trailing: trailingRect == null ? null : m(trailingRect),
    minimized: m(
      Rect.fromLTWH(
        TabMetrics.minimizedInset,
        (extent - TabMetrics.minimized) / 2,
        TabMetrics.minimized,
        TabMetrics.minimized,
      ),
    ),
    minimizedTrailing: trailingRect == null
        ? null
        : m(
            Rect.fromCenter(
              center: trailingRect.center,
              width: TabMetrics.minimized,
              height: TabMetrics.minimized,
            ),
          ),
  );
}

/// Compact landscape geometry (spec §5.2): content-sized items of label
/// width + 49, squeezed proportionally when the row is too narrow.
TabBarGeometry landscapeTabGeometry({
  required List<double> labelWidths,
  required double maxWidth,
  required bool trailing,
  required TextDirection direction,
}) {
  const extent = TabMetrics.landscapeExtent;
  const inset = TabMetrics.inset;
  final items = [
    for (final w in labelWidths) w + TabMetrics.landscapeItemPadding,
  ];
  final gaps = TabMetrics.landscapeGap * math.max(0, items.length - 1);
  final sum = items.fold<double>(0, (a, b) => a + b);
  final natural = 2 * inset + sum + gaps;
  final reserve = trailing ? extent + TabMetrics.trailingGap : 0.0;
  final width = maxWidth.isFinite ? maxWidth : natural + reserve;
  final pillWidth = math.max(2 * inset, math.min(natural, width - reserve));
  final squeeze = sum == 0
      ? 1.0
      : math.min<double>(1, (pillWidth - 2 * inset - gaps) / sum);
  final left = trailing ? 0.0 : (width - pillWidth) / 2;
  Rect m(Rect r) => _mirror(r, width, direction);
  final slots = <Rect>[];
  var x = left + inset;
  for (final w in items) {
    final ww = w * squeeze;
    slots.add(
      m(Rect.fromLTWH(x, inset, ww, TabMetrics.landscapeItemExtent)),
    );
    x += ww + TabMetrics.landscapeGap;
  }
  final trailingRect = trailing
      ? m(Rect.fromLTWH(width - extent, 0, extent, extent))
      : null;
  return TabBarGeometry(
    form: TabBarForm.landscape,
    size: Size(width, extent),
    pill: m(Rect.fromLTWH(left, 0, pillWidth, extent)),
    slots: slots,
    trailing: trailingRect,
    // Not captured (spec §5.2): a pill-high circle at the row start.
    minimized: m(const Rect.fromLTWH(0, 0, extent, extent)),
    minimizedTrailing: trailingRect,
  );
}

/// Regular top geometry (spec §5.3): label-only items of label + 31,
/// icon-only items of 48.5, the pill and its trailing circle centred as a
/// group.
TabBarGeometry topTabGeometry({
  required List<double> labelWidths,
  required List<bool> iconOnly,
  required double maxWidth,
  required bool trailing,
  required TextDirection direction,
}) {
  const extent = TabMetrics.topExtent;
  const inset = TabMetrics.inset;
  final items = [
    for (final (i, w) in labelWidths.indexed)
      if (iconOnly[i])
        TabMetrics.topIconItemWidth
      else
        w + 2 * TabMetrics.topItemPadding,
  ];
  final sum = items.fold<double>(0, (a, b) => a + b);
  final natural = 2 * inset + sum;
  final reserve = trailing ? extent + TabMetrics.trailingGap : 0.0;
  final width = maxWidth.isFinite ? maxWidth : natural + reserve;
  final pillWidth = math.max(2 * inset, math.min(natural, width - reserve));
  final squeeze = sum == 0
      ? 1.0
      : math.min<double>(1, (pillWidth - 2 * inset) / sum);
  final left = (width - pillWidth - reserve) / 2;
  Rect m(Rect r) => _mirror(r, width, direction);
  final slots = <Rect>[];
  var x = left + inset;
  for (final w in items) {
    final ww = w * squeeze;
    slots.add(m(Rect.fromLTWH(x, inset, ww, TabMetrics.topItemExtent)));
    x += ww;
  }
  final pill = m(Rect.fromLTWH(left, 0, pillWidth, extent));
  final trailingRect = trailing
      ? m(
          Rect.fromLTWH(
            left + pillWidth + TabMetrics.trailingGap,
            0,
            extent,
            extent,
          ),
        )
      : null;
  return TabBarGeometry(
    form: TabBarForm.top,
    size: Size(width, extent),
    pill: pill,
    slots: slots,
    trailing: trailingRect,
    minimized: pill,
    minimizedTrailing: trailingRect,
  );
}

/// The 33 × 28 icon frame of a compact [slot], 10 below the pill top.
Rect tabIconFrame(Rect slot) => Rect.fromLTWH(
  slot.center.dx - TabMetrics.iconFrame.width / 2,
  TabMetrics.iconTop,
  TabMetrics.iconFrame.width,
  TabMetrics.iconFrame.height,
);

/// The label box of a compact [slot] for a [lineHeight] line.
Rect tabLabelBox(Rect slot, double lineHeight) => Rect.fromLTWH(
  slot.left + 4,
  TabMetrics.labelTop,
  slot.width - 8,
  lineHeight,
);

/// Top-left of a badge [badgeWidth] wide: at the icon frame's trailing top
/// corner, 4 inward and 4 up (research §1.1).
Offset tabBadgeOrigin(
  Rect iconFrame,
  double badgeWidth,
  TextDirection direction,
) => direction == TextDirection.rtl
    ? Offset(
        iconFrame.left + TabMetrics.badgeOutset - badgeWidth,
        iconFrame.top - TabMetrics.badgeOutset,
      )
    : Offset(
        iconFrame.right - TabMetrics.badgeOutset,
        iconFrame.top - TabMetrics.badgeOutset,
      );
