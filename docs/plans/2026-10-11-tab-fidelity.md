# liquid_shell VK-503: tab bar fidelity Implementation Plan

> **Approval:** the owner approves this plan together with the spec `docs/specs/2026-10-11-tab-fidelity-design.md`. Until the owner answers, this plan implements the recommended defaults of the spec's "Quyết định cần chủ sản phẩm xác nhận" table (Q1–Q22). A different answer changes only the tasks named in the "Owner defaults applied" table below.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter-drawn liquid tab bar so that it matches the iOS 26.5 native glass tab bar at rest and in motion, within the spec's numeric tolerances (VK-503). This covers:

- the native geometry;
- a selected lens drawn as a second `liquid_glass.frag` pass;
- tap, press and drag on the fitted springs;
- the icon tint, pop and magnify;
- the glow ripple and haptics;
- the minimize morph, also reused by the search tab;
- the landscape and iPad forms;
- all accessibility fallbacks.

**Architecture:** Geometry (`tab_geometry.dart`) and motion (`tab_springs.dart`, `lens_motion.dart`) are pure Dart, unit-tested against the research numbers. `GlassTabBar` is an internal widget that owns one `Ticker`. It feeds pointer events from `LensGestureRecognizer` into `LensMotion` and paints each `LensFrame`:

- the pill glass;
- the rest fill;
- the normal row with the lens punched out;
- `LiquidLens` (the second backdrop pass, in `lib/src/glass/`);
- the tinted row clipped to the lens;
- the glow;
- the trailing circle.

The public `LiquidTabBar` keeps its constructor and delegates to `GlassTabBar`. The shell uses `GlassTabBar` directly for the search morph and the guard.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12 (fvm), `flutter_test`, `integration_test`, Impeller tests (`flutter test --enable-impeller`), Xcode 27 with an iOS 26.5 simulator, `ffmpeg` (developer tool, for frame strips only).

## Global Constraints

- **Floor:** Flutter `>=3.44.0`, Dart `^3.12.0`, iOS deployment target `15.0`. fvm pins `3.44.6` (`.fvmrc`).
- **Analysis:** `very_good_analysis` pinned to `10.3.0`. `dart analyze --fatal-infos --fatal-warnings` must be clean. Never loosen `analysis_options.yaml`.
- **Runtime dependencies:** Flutter, our packages and `plugin_platform_interface`, plus `meta` in `liquid_shell_ios`. No new dependency anywhere, the example included (no `cupertino_icons`). `ffmpeg` is a developer tool that only `tool/tab_frames.sh` checks for.
- **Glass seam:** `BackdropFilter` and `ImageFilter.(blur|shader|compose)` appear only under `liquid_shell/lib/src/glass/` (`tool/check_glass_seam.sh`, part of `make provenance`).
- **Clean-room shader:** never open or copy another glass package's shader or glass code (`liquid_glass_renderer`, `liquid_glass_widgets`, `liquid_glass_easy`, …). `liquid_glass.frag` is not edited in this plan, unless R1's fallback is triggered, which needs the owner.
- **Numbers:** every metric and spring comes from the spec (§5, §8.1, §8.3) and `tabfid-research.md`. Do not invent values. Where the spec says "(assumption)", keep the stated value.
- **Native springs:** `fittedSpring(ζ, response)` = `SpringDescription.withDampingRatio(mass: 1, stiffness: (2π/response)², ratio: ζ)`. The table is in spec §8.1.
- **Public API:** the `LiquidTabBar` constructor is unchanged. The only new public members are `LiquidGlassTheme.selectionFill`, `tabForeground`, `badgeColor`, `tabIconSize` and `LiquidShellBreakpoints.compactHeight`.
- **TDD:** no production code without a test that failed first for the right reason. Run the single test, see it red, implement, see it green.
- **Commits:** `<type>(<scope>): <summary> (VK-503)`. Scopes are `shell glass platform ios android example docs ci`. The message ends with a blank line and then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Run `bash .githooks/pre-commit` by hand before every commit.
  - Stage by explicit path.
  - Never use `--no-verify`, never set `core.hooksPath`, never change git or flutter config.
  - No pushes, no remotes, no publishing.
- **Goldens:** only through `make goldens-update` on macOS + Flutter 3.44.6. Never edit images by hand. Review the diff of every regenerated image before committing it.
- **Simulators:** create your own (`xcrun simctl create "vk503 …"`) and delete them at the end. Never touch a physical device. Keep at least 10 GB free (`df -h /`).
- **Environment:** `rm` is aliased in this environment, so use `command rm`.
- **Worktrees:** work only in `/Users/invoker/Projects/tuvi/liquid_shell-vk503`. Never touch the other worktrees (`liquid_shell-vk491` in particular).
- **Version:** all four packages go from `0.1.0-dev.5` to `0.1.0-dev.6` (Task 13).

## Owner defaults applied

| Q | Default | Tasks |
|---|---|---|
| Q1 | Every slot draws `selectedIcon ?? icon`, `tabIconSize` 26, no new icon package | 6, 13 |
| Q2 | No SF Symbol rasterization (separate issue) | none |
| Q3 | iOS 26.5 look and springs | 2, 3, 4 |
| Q4 | Selected = `colorScheme.primary`; unselected #191919 / #F4F4F4; badge #FF383C | 4, 6 |
| Q5 | New material defaults for every glass surface | 4 |
| Q6 | `selectionClick` per slot crossing while dragging only | 7 |
| Q7 | Minimized expands on tap or on a selection change, not on forward scroll | 9 |
| Q8 | Landscape phones get the 44 pt bottom bar (`compactHeight` 500) | 11 |
| Q9 | iPad top bar: 48 pill, label-only 17 pt, row at safe top + 5.5 | 11 |
| Q10 | Sidebar gets the colour and icon tokens only | 6, 11 |
| Q11 | Reduce motion: 150 ms dissolve on tap, rest-size drag, instant minimize | 3, 7, 9 |
| Q12 | Programmatic changes jump; a rejected commit snaps back | 3, 7 |
| Q13 | Scroll-edge pocket approximation, liquid tier only | 12 |
| Q14–Q21 | Accepted limits, documented | 13 |
| Q22 | `0.1.0-dev.6` with CHANGELOG | 13 |

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `liquid_shell/lib/src/chrome/tab_geometry.dart` (new) | 1, 11 | `TabMetrics`, `TabBarForm`, `TabBarGeometry`, `compactTabGeometry`, `landscapeTabGeometry`, `topTabGeometry`, cell parts |
| `liquid_shell/lib/src/chrome/tab_springs.dart` (new) | 2 | `fittedSpring`, `TabSprings`, `SpringValue` |
| `liquid_shell/lib/src/chrome/lens_motion.dart` (new) | 3, 9 | `LensPhase`, `LensFrame`, `LensMotion`, `MinimizeMotion` |
| `liquid_shell/lib/src/glass/glass_theme.dart` | 4 | Four new fields, new defaults |
| `liquid_shell/lib/src/glass/liquid_optics.dart` | 4 | `LiquidOpticsParams.bezel` / `rimWidth` overrides |
| `liquid_shell/lib/src/glass/liquid_glass.dart` | 5 | `resolveGlassFor(context)`, `liquidGlassChanges` (shared with the lens) |
| `liquid_shell/lib/src/glass/liquid_lens.dart` (new) | 5 | `LiquidLens`, `kLensShadow` |
| `liquid_shell/lib/src/destinations/badge.dart` | 6 | Native badge metrics and `badgeColor` |
| `liquid_shell/lib/src/chrome/glass_tab_bar.dart` (new) | 6–11 | `GlassTabBar`, `TabDragTarget`, painters and clippers |
| `liquid_shell/lib/src/chrome/lens_gesture.dart` (new) | 7 | `LensGestureRecognizer` |
| `liquid_shell/lib/src/chrome/tab_bar.dart` | 6, 11 | `LiquidTabBar` → `GlassTabBar`; `LiquidActionCircle` kept |
| `liquid_shell/lib/src/chrome/sidebar.dart` | 11 | `tabForeground` for unselected rows |
| `liquid_shell/lib/src/shell/liquid_shell.dart` | 9, 10, 11, 12 | Margins, minimize rules, search morph wiring, forms, pocket |
| `liquid_shell/lib/src/shell/shell_layout.dart`, `breakpoints.dart` | 11 | `compactHeight`, `kTopBarGap` 5.5 |
| `liquid_shell/lib/src/search/search_layout.dart`, `search_chrome.dart` | 10 | Collapsed circle from the bar; ⌕ hover highlight |
| `liquid_shell/lib/src/glass/scroll_pocket.dart` (new) | 12 | `ScrollEdgePocket` |
| `liquid_shell/test/unit/{tab_geometry,tab_springs,lens_motion}_test.dart` (new) | 1–3, 9, 11 | Pure tests |
| `liquid_shell/test/helpers/settle.dart` (new) | 2 | `settleTime`, `referenceTrace` |
| `liquid_shell/test/widget/{glass_tab_bar,tab_gesture,lens_layer,minimize,search_morph,scroll_pocket}_test.dart` (new) | 5–12 | Widget tests |
| `liquid_shell/test/impeller/lens_pass_test.dart` (new) | 5 | The second pass samples the page (R1) |
| `liquid_shell/example/lib/cases/*.dart`, `README.md`, `doc/tab_bar.md` (new), `doc/liquid.md`, CHANGELOG ×4, pubspecs | 13 | Icons, docs, versions |
| `liquid_shell/example/integration_test/tab_fidelity_test.dart` (new), `docs/qa/vk503/native_reference.json` (new), `tool/tab_trace_compare.dart` (new), `tool/tab_frames.sh` (new), `tool/test/tab_trace_compare_test.dart` (new), `Makefile` | 14 | Acceptance tooling |
| `tool/tab_frames.sh`, `tool/tab_strips.dart`, `tool/test/tab_strips_test.dart`, `liquid_shell/example/ios/RunnerUITests/TabFidelityUITests.swift` (new), `liquid_shell/example/lib/main.dart` | 15 | 60 fps native vs Flutter strips |
| `docs/qa/vk503/acceptance.md` (new) | 16 | Trace table, strip index, owner verdict |

## Set up once (the controller, before Task 1)

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk503
git status            # clean, on VK-503-tab-fidelity
git log --oneline -1  # the docs commit of this plan, on top of 6c8414d
make get
make test             # green baseline
```

---

### Task 1: Native tab geometry (compact portrait)

**Files:**
- Create: `liquid_shell/lib/src/chrome/tab_geometry.dart`
- Test: `liquid_shell/test/unit/tab_geometry_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `abstract final class TabMetrics` (constants from spec §5);
  - `enum TabBarForm { compact, landscape, top }`;
  - `class TabBarGeometry`, with:
    - fields `form`, `size`, `pill`, `slots`, `trailing`, `minimized`, `minimizedTrailing`;
    - methods `centreOf(int)`, `slotNearest(double)`, `clampCentre(double)`, `restLensAt(double) → Size`;
  - `TabBarGeometry compactTabGeometry({required int count, required double maxWidth, required bool trailing, required TextDirection direction, double extent = TabMetrics.pillExtent})`;
  - `Rect tabIconFrame(Rect slot)`;
  - `Rect tabLabelBox(Rect slot, double lineHeight)`;
  - `Offset tabBadgeOrigin(Rect iconFrame, double badgeWidth, TextDirection direction)`.

  All rects are bar-local. Slots are in destination order, mirrored in RTL.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/unit/tab_geometry_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

/// Bar-local x → screen x on the 402 pt iPhone 17 Pro (21 pt row margin).
double screenX(double x) => x + TabMetrics.margin;

TabBarGeometry compact(
  int count, {
  double maxWidth = 360,
  bool trailing = false,
  TextDirection direction = TextDirection.ltr,
  double extent = TabMetrics.pillExtent,
}) => compactTabGeometry(
  count: count,
  maxWidth: maxWidth,
  trailing: trailing,
  direction: direction,
  extent: extent,
);

void main() {
  group('compact portrait (research §1.1)', () {
    test('3 tabs: a 274 pill centred at x 64 with 94 × 54 slots', () {
      final g = compact(3);
      expect(g.form, TabBarForm.compact);
      expect(g.size, const Size(360, 62));
      expect(screenX(g.pill.left), 64);
      expect(g.pill.size, const Size(274, 62));
      expect([for (final s in g.slots) screenX(s.left)], [68, 154, 240]);
      expect([for (final s in g.slots) screenX(s.center.dx)], [115, 201, 287]);
      for (final s in g.slots) {
        expect(s.size, const Size(94, 54));
        expect(s.top, 4);
      }
      expect(g.trailing, isNull);
      expect(g.minimizedTrailing, isNull);
    });

    test('neighbouring slots overlap by 8', () {
      final g = compact(4);
      for (var i = 1; i < g.slots.length; i++) {
        expect(g.slots[i - 1].right - g.slots[i].left, closeTo(8, 1e-9));
      }
    });

    test('4 tabs + trailing: pill pinned at the start, circle at the end', () {
      final g = compact(4, trailing: true);
      expect(g.pill, const Rect.fromLTWH(0, 0, 290, 62));
      // The research reads a 68.67 pitch; the formula gives 68.5 (±1 pt).
      expect(g.slots[1].left - g.slots[0].left, closeTo(68.67, 1));
      expect(g.trailing, const Rect.fromLTWH(298, 0, 62, 62));
      expect(screenX(g.trailing!.left), 319);
      expect(g.minimizedTrailing, Rect.fromCenter(
        center: const Offset(329, 31),
        width: 48,
        height: 48,
      ));
    });

    test('5 tabs fill the 360 maximum', () {
      final g = compact(5);
      expect(g.pill, const Rect.fromLTWH(0, 0, 360, 62));
      expect(g.slots.last.right, 356);
    });

    test('an unbounded width takes the natural 16 + 86·n (+ circle)', () {
      final g = compact(3, maxWidth: double.infinity, trailing: true);
      expect(g.size, const Size(274 + 8 + 62, 62));
      expect(g.pill.width, 274);
    });

    test('minimized: a 48 circle at row start + 7 (screen x 28)', () {
      final g = compact(3);
      expect(g.minimized, const Rect.fromLTWH(7, 7, 48, 48));
      expect(screenX(g.minimized.left), 28);
    });

    test('a taller extent grows the slots, not the pitch', () {
      final g = compact(3, extent: 70);
      expect(g.size.height, 70);
      expect(g.slots.first.size, const Size(94, 62));
      expect(g.minimized.top, 11);
    });

    test('RTL mirrors: slot 0 on the right, pill and circle swapped', () {
      final g = compact(3, trailing: true, direction: TextDirection.rtl);
      expect(g.pill, const Rect.fromLTWH(360 - 274, 0, 274, 62));
      expect(g.trailing, const Rect.fromLTWH(0, 0, 62, 62));
      expect(g.slots.first.center.dx, greaterThan(g.slots.last.center.dx));
      expect(g.minimized, const Rect.fromLTWH(360 - 7 - 48, 7, 48, 48));
    });

    test('no destinations: an empty 16 pt pill without slots', () {
      final g = compact(0);
      expect(g.slots, isEmpty);
      expect(g.pill.width, 16);
    });
  });

  group('queries', () {
    final g = compact(3);

    test('slotNearest picks the closest centre; ties keep the first', () {
      expect(g.slotNearest(94), 0);
      expect(g.slotNearest(136), 0);
      expect(g.slotNearest(138), 1);
      expect(g.slotNearest(-50), 0);
      expect(g.slotNearest(999), 2);
    });

    test('clampCentre stays between the first and last centres', () {
      expect(g.clampCentre(0), 94);
      expect(g.clampCentre(150), 150);
      expect(g.clampCentre(400), 266);
      final rtl = compact(3, direction: TextDirection.rtl);
      expect(rtl.clampCentre(0), 94);
      expect(rtl.clampCentre(400), 266);
    });

    test('restLensAt is the slot size (uniform slots)', () {
      expect(g.restLensAt(150), const Size(94, 54));
    });

    test('restLensAt interpolates between content-sized slots', () {
      const g2 = TabBarGeometry(
        form: TabBarForm.top,
        size: Size(200, 48),
        pill: Rect.fromLTWH(0, 0, 200, 48),
        slots: [Rect.fromLTWH(4, 4, 80, 40), Rect.fromLTWH(84, 4, 100, 40)],
        trailing: null,
        minimized: Rect.fromLTWH(0, 0, 200, 48),
        minimizedTrailing: null,
      );
      expect(g2.restLensAt(44), const Size(80, 40));
      expect(g2.restLensAt(89), const Size(90, 40));
      expect(g2.restLensAt(500), const Size(100, 40));
    });
  });

  group('cell parts', () {
    final slot = compact(3).slots.first;

    test('icon frame: 33 × 28, top 10 below the pill top, centred', () {
      final f = tabIconFrame(slot);
      expect(f.size, const Size(33, 28));
      expect(f.top, 10);
      expect(f.center.dx, slot.center.dx);
    });

    test('label box: top 39, slot width minus 8', () {
      final l = tabLabelBox(slot, 12);
      expect(l, Rect.fromLTWH(slot.left + 4, 39, 86, 12));
    });

    test('badge origin: icon frame right − 4, top − 4; mirrored in RTL', () {
      final f = tabIconFrame(slot);
      expect(
        tabBadgeOrigin(f, 21.33, TextDirection.ltr),
        Offset(f.right - 4, f.top - 4),
      );
      expect(
        tabBadgeOrigin(f, 21.33, TextDirection.rtl),
        Offset(f.left + 4 - 21.33, f.top - 4),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/tab_geometry_test.dart`
Expected: FAIL with `Error when reading 'lib/src/chrome/tab_geometry.dart': No such file`.

- [ ] **Step 3: Write the implementation**

```dart
// liquid_shell/lib/src/chrome/tab_geometry.dart
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
    final order = [...slots]..sort((a, b) => a.center.dx.compareTo(b.center.dx));
    if (x <= order.first.center.dx) return order.first.size;
    if (x >= order.last.center.dx) return order.last.size;
    for (var i = 0; i < order.length - 1; i++) {
      final a = order[i];
      final b = order[i + 1];
      if (x <= b.center.dx) {
        final t = (x - a.center.dx) / (b.center.dx - a.center.dx);
        return Size.lerp(a.size, b.size, t)!;
      }
    }
    return order.last.size;
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/unit/tab_geometry_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell/lib/src/chrome/tab_geometry.dart liquid_shell/test/unit/tab_geometry_test.dart
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/tab_geometry.dart liquid_shell/test/unit/tab_geometry_test.dart
git commit -m "feat(shell): native tab bar geometry for the compact form (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Fitted springs and the fixed-step spring value

**Files:**
- Create: `liquid_shell/lib/src/chrome/tab_springs.dart`
- Create: `liquid_shell/test/helpers/settle.dart`
- Test: `liquid_shell/test/unit/tab_springs_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `SpringDescription fittedSpring(double ratio, double response)`;
  - `abstract final class TabSprings`, with:
    - springs `tap`, `dragFollow`, `snap`, `heightIn`, `heightOut`, `widthIn`, `widthOut`, `scaleIn`, `scaleOut`, `effectIn`, `effectOut`, `highlightIn`, `engageIn`, `engageOut`, `glowIn`, `collapse`, `expand`, `reduced`;
    - the envelope constants used by Tasks 3 and 9;
  - `class SpringValue`, with:
    - `value`, `velocity`, `target`, `spring`;
    - `advance(double dt)`, `retarget(double, [SpringDescription?])`, `jump(double)`, `settled(double tolerance)`;
  - test helpers `settleTime(List<double>, double target, {double dt, double tolerance})` and `referenceTrace(SpringDescription, double from, double to, {double delay, double seconds, double dt, double velocity})`.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/helpers/settle.dart
import 'package:flutter/physics.dart';

/// The time after which [xs] (one sample per [dt]) stays within
/// [tolerance] of [target]: the end of the last frame outside it.
double settleTime(
  List<double> xs,
  double target, {
  double dt = 1 / 60,
  double tolerance = 0.5,
}) {
  var last = -1;
  for (var i = 0; i < xs.length; i++) {
    if ((xs[i] - target).abs() > tolerance) last = i;
  }
  return (last + 1) * dt;
}

/// [spring] from [from] to [to], sampled once per [dt] like the motion
/// model, held at [from] for [delay] seconds.
List<double> referenceTrace(
  SpringDescription spring,
  double from,
  double to, {
  double delay = 0,
  double seconds = 2,
  double dt = 1 / 60,
  double velocity = 0,
}) {
  final sim = SpringSimulation(spring, from, to, velocity);
  final frames = (seconds / dt).round();
  return [
    for (var f = 1; f <= frames; f++)
      f * dt < delay ? from : sim.x(f * dt - delay),
  ];
}
```

```dart
// liquid_shell/test/unit/tab_springs_test.dart
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

void main() {
  test('fittedSpring: mass 1, stiffness (2π/response)², damping 2ζ√k', () {
    final s = fittedSpring(0.79, 0.39);
    expect(s.mass, 1);
    expect(s.stiffness, closeTo(259.6, 0.1));
    expect(s.damping, closeTo(2 * 0.79 * math.sqrt(s.stiffness), 1e-9));
  });

  test('the research §7 table, stiffness per spring', () {
    expect(TabSprings.tap.stiffness, closeTo(260, 1));
    expect(TabSprings.snap.stiffness, closeTo(322, 1));
    expect(TabSprings.heightIn.stiffness, closeTo(342, 1));
    expect(TabSprings.widthIn.stiffness, closeTo(1094, 1));
    expect(TabSprings.scaleIn.stiffness, closeTo(411, 1));
    expect(TabSprings.scaleOut.stiffness, closeTo(322, 1));
    expect(TabSprings.effectIn.stiffness, closeTo(632, 1));
    expect(TabSprings.effectOut.stiffness, closeTo(158, 1));
    // Drag follow uses the primary fit, 0.33 s (spec §8.1).
    expect(TabSprings.dragFollow.stiffness, closeTo(362.5, 1));
  });

  for (final (name, spring) in [
    ('tap', TabSprings.tap),
    ('dragFollow', TabSprings.dragFollow),
    ('snap', TabSprings.snap),
    ('widthIn (overdamped)', TabSprings.widthIn),
    ('engageIn (stiff, critical)', TabSprings.engageIn),
  ]) {
    test('SpringValue follows SpringSimulation for $name within 0.05', () {
      final value = SpringValue(0, spring)..target = 86;
      final sim = SpringSimulation(spring, 0, 86, 0);
      for (var f = 1; f <= 90; f++) {
        value.advance(1 / 60);
        expect(value.value, closeTo(sim.x(f / 60), 0.05), reason: 'frame $f');
      }
    });
  }

  test('retarget keeps position and velocity (a moving target)', () {
    final value = SpringValue(0, TabSprings.dragFollow)..target = 100;
    value.advance(0.1);
    final x = value.value;
    final v = value.velocity;
    value.retarget(50);
    expect(value.value, x);
    expect(value.velocity, v);
    expect(value.target, 50);
  });

  test('retarget can swap the spring', () {
    final value = SpringValue(0, TabSprings.dragFollow)
      ..retarget(10, TabSprings.snap);
    expect(value.spring, same(TabSprings.snap));
  });

  test('settled: close to the target and nearly still', () {
    final value = SpringValue(0, TabSprings.snap)..target = 40;
    expect(value.settled(0.5), isFalse);
    for (var f = 0; f < 120; f++) {
      value.advance(1 / 60);
    }
    expect(value.settled(0.5), isTrue);
  });

  test('jump stops at the value', () {
    final value = SpringValue(0, TabSprings.tap)
      ..target = 10
      ..advance(0.05)
      ..jump(3);
    expect(value.value, 3);
    expect(value.target, 3);
    expect(value.velocity, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/tab_springs_test.dart`
Expected: FAIL, because `tab_springs.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// liquid_shell/lib/src/chrome/tab_springs.dart
import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// A spring from a least-squares fit: damping ratio [ratio] and undamped
/// period [response] in seconds (spec VK-503 §8.1).
SpringDescription fittedSpring(double ratio, double response) =>
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
      ratio: ratio,
    );

/// Springs and envelope constants of the tab lens (spec §8, research §3,
/// §4, §6, §7). The envelope constants are the only tuning knobs (§8.3).
abstract final class TabSprings {
  /// Lens x after a tap; icon pop.
  static final SpringDescription tap = fittedSpring(0.79, 0.39);

  /// Lens x following the finger.
  static final SpringDescription dragFollow = fittedSpring(0.75, 0.33);

  /// Lens x after a drag release, or back after a rejected commit.
  static final SpringDescription snap = fittedSpring(0.92, 0.35);

  /// Lens height growing.
  static final SpringDescription heightIn = fittedSpring(0.72, 0.34);

  /// Lens height shrinking.
  static final SpringDescription heightOut = fittedSpring(0.77, 0.36);

  /// Lens width growing.
  static final SpringDescription widthIn = fittedSpring(1.4, 0.19);

  /// Lens width shrinking.
  static final SpringDescription widthOut = fittedSpring(1.5, 0.16);

  /// Pill scale growing.
  static final SpringDescription scaleIn = fittedSpring(0.63, 0.31);

  /// Pill scale shrinking.
  static final SpringDescription scaleOut = fittedSpring(0.61, 0.35);

  /// Refraction in.
  static final SpringDescription effectIn = fittedSpring(1, 0.25);

  /// Refraction, highlight and glow out.
  static final SpringDescription effectOut = fittedSpring(1, 0.5);

  /// Pill highlight in (≈ 0.10 s).
  static final SpringDescription highlightIn = fittedSpring(1, 0.10);

  /// Lens engage in (≈ 60 ms, native `opacityPair`).
  static final SpringDescription engageIn = fittedSpring(1, 0.065);

  /// Lens engage out.
  static final SpringDescription engageOut = fittedSpring(1, 0.2);

  /// Finger glow in (≈ 0.08 s).
  static final SpringDescription glowIn = fittedSpring(1, 0.08);

  /// Minimize collapse.
  static final SpringDescription collapse = fittedSpring(0.8, 0.30);

  /// Minimize expand (small overshoot).
  static final SpringDescription expand = fittedSpring(0.7, 0.35);

  /// Reduce motion: the rest-size capsule following the finger.
  static final SpringDescription reduced = fittedSpring(1, 0.25);

  /// Delay between a tap and the lens leaving (research §3).
  static const double tapDelay = 0.025;

  /// The lens stays engaged this long after a tap.
  static const double flightHold = 0.35;

  /// Lift (one slot) and refraction last this long after a tap.
  static const double liftUntil = 0.25;

  /// The target icon pops this long.
  static const double popUntil = 0.22;

  /// The pill bulges this long after a tap.
  static const double bulgeUntil = 0.12;

  /// The tap highlight impulse lasts this long.
  static const double highlightUntil = 0.10;

  /// Pill scale during a tap bulge.
  static const double bulge = 1.022;

  /// Pressed lens width factor.
  static const double pressWidthFactor = 1.17;

  /// Pressed lens height factor.
  static const double pressHeightFactor = 1.30;

  /// Pressed pill scale.
  static const double pressScale = 1.052;

  /// Pill highlight while pressed.
  static const double highlightPress = 0.845;

  /// Pill highlight impulse on a tap.
  static const double highlightTap = 0.7;

  /// Finger glow opacity.
  static const double glowOpacity = 0.28;

  /// Finger glow diameter on touch-down.
  static const double glowDiameter = 93;

  /// Finger glow diameter while held.
  static const double glowHeldDiameter = 98;

  /// Ripple growth on release.
  static const double glowRipple = 4;

  /// Ripple duration.
  static const double glowFade = 0.5;

  /// Icon pop scale.
  static const double pop = 1.16;

  /// Magnification of the tinted copy at full engage.
  static const double magnify = 0.16;

  /// Flight width floor (one slot).
  static const double stretchFloor = 0.9;

  /// Lens speed above which the flight width stretches.
  static const double stretchKnee = 700;

  /// Width gain per pt/s above the knee.
  static const double stretchGain = 0.00090;

  /// Flight width ceiling.
  static const double stretchMax = 1.35;

  /// Flight height gain.
  static const double liftGain = 0.55;

  /// Lift gate for two or more slots.
  static const double liftGateFar = 0.45;

  /// Top bar tap inflation, width and height (research §1.3).
  static const double topTapWidth = 1.34;

  /// Top bar tap inflation, height.
  static const double topTapHeight = 1.375;

  /// Finger speed at release above which the finger's slot wins.
  static const double flickVelocity = 600;

  /// Reduce motion: tap dissolve duration.
  static const double ghostFade = 0.15;

  /// Delay before a scroll collapses the bar.
  static const double minimizeDelay = 0.24;

  /// Minimize dip depth (×0.96 at the midpoint).
  static const double dip = 0.04;

  /// Lens velocity → flight width factor (spec §8.3).
  static double stretchFor(double velocity) =>
      (stretchFloor + stretchGain * math.max(0, velocity.abs() - stretchKnee))
          .clamp(stretchFloor, stretchMax);
}

/// One value on a spring toward a target that may move every frame,
/// integrated with semi-implicit Euler in fixed 1 ms steps.
class SpringValue {
  /// Starts at rest at [value].
  SpringValue(double value, this.spring) : _value = value, target = value;

  /// The current spring.
  SpringDescription spring;

  /// Where the value is heading.
  double target;

  double _value;
  double _velocity = 0;

  /// The current value.
  double get value => _value;

  /// The current velocity per second.
  double get velocity => _velocity;

  /// Integration step.
  static const double step = 0.001;

  /// Moves [dt] seconds forward.
  void advance(double dt) {
    var left = dt;
    while (left > 1e-9) {
      final h = math.min(left, step);
      final force =
          -spring.stiffness * (_value - target) - spring.damping * _velocity;
      _velocity += force / spring.mass * h;
      _value += _velocity * h;
      left -= h;
    }
  }

  /// Sets a new [target] (and [newSpring]) without touching the motion.
  void retarget(double target, [SpringDescription? newSpring]) {
    this.target = target;
    if (newSpring != null) spring = newSpring;
  }

  /// Stops at [value].
  void jump(double value) {
    _value = value;
    target = value;
    _velocity = 0;
  }

  /// Within [tolerance] of the target and slower than 4 × tolerance per
  /// second.
  bool settled(double tolerance) =>
      (_value - target).abs() <= tolerance &&
      _velocity.abs() <= tolerance * 4;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/unit/tab_springs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell/lib/src/chrome/tab_springs.dart liquid_shell/test/unit/tab_springs_test.dart liquid_shell/test/helpers/settle.dart
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/tab_springs.dart liquid_shell/test/unit/tab_springs_test.dart liquid_shell/test/helpers/settle.dart
git commit -m "feat(shell): fitted tab springs and a fixed-step spring value (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The lens motion model

**Files:**
- Create: `liquid_shell/lib/src/chrome/lens_motion.dart`
- Test: `liquid_shell/test/unit/lens_motion_test.dart`

**Interfaces:**
- Consumes:
  - Task 1: `TabBarGeometry`, `TabBarForm`, `compactTabGeometry`;
  - Task 2: `TabSprings`, `SpringValue`.
- Produces:
  - `enum LensPhase { rest, pressed, dragging, flying, settling }`;
  - `class LensFrame`, with:
    - fields `lens`, `visible`, `engage`, `refraction`, `pillScale`, `highlight`, `glowCenter`, `glowDiameter`, `glowOpacity`, `popSlot`, `popScale`, `ghost`, `ghostOpacity`, `restOpacity`;
    - getter `magnify`;
    - `copyWith`;
  - `class LensMotion({required TabBarGeometry geometry, required int? selected, bool reduceMotion = false})`, with:
    - `geometry` (get and set), `reduceMotion`, `phase`, `committed`, `pending`, `interacting`;
    - `down(Offset)`, `move(Offset)`, `int? up(Offset, {double velocity = 0})`, `cancel()`;
    - `tapSlot(int)`, `show(int?)`, `accept()`, `returnTo(int?)`;
    - `bool advance(double dt)`, `List<int> takeCrossings()`, `LensFrame get frame`.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/unit/lens_motion_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

import '../helpers/settle.dart';

const dt = 1 / 60;
// Slot centres 94 / 180 / 266 bar-local = 115 / 201 / 287 on screen.
final g3 = compactTabGeometry(
  count: 3,
  maxWidth: 360,
  trailing: false,
  direction: TextDirection.ltr,
);

/// Advances [m] for [seconds], calling [each] after every frame with the
/// elapsed time; returns the frames.
List<LensFrame> run(
  LensMotion m,
  double seconds, {
  void Function(double t)? each,
}) {
  final frames = <LensFrame>[];
  final n = (seconds / dt).round();
  for (var f = 1; f <= n; f++) {
    m.advance(dt);
    frames.add(m.frame);
    each?.call(f * dt);
  }
  return frames;
}

double within(double reference, double fraction) => reference * fraction;

void main() {
  group('rest', () {
    test('the lens is the selected slot', () {
      final m = LensMotion(geometry: g3, selected: 1);
      expect(m.frame.lens, g3.slots[1]);
      expect(m.frame.visible, isTrue);
      expect(m.frame.engage, 0);
      expect(m.advance(dt), isFalse);
    });

    test('nothing selected: invisible', () {
      final m = LensMotion(geometry: g3, selected: null);
      expect(m.frame.visible, isFalse);
    });
  });

  group('tap (research §3)', () {
    test('one slot: settle matches the tap spring with a 25 ms delay', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      final xs = [for (final f in run(m, 1.5)) f.lens.center.dx];
      final ours = settleTime(xs, 180);
      final reference = settleTime(
        referenceTrace(TabSprings.tap, 94, 180, delay: TabSprings.tapDelay,
            seconds: 1.5),
        180,
      );
      expect(ours, closeTo(reference, within(reference, 0.10)));
      expect(m.committed, 1);
      expect(m.phase, LensPhase.rest);
    });

    test('one slot lifts: height ×1.55 ± 10 % at 0.15–0.30 s, width ≤ ×0.92',
        () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      var peak = 0.0;
      var narrowest = double.infinity;
      run(m, 0.6, each: (t) {
        final lens = m.frame.lens;
        if (t >= 0.15 && t <= 0.30 && lens.height > peak) peak = lens.height;
        if (lens.width < narrowest) narrowest = lens.width;
      });
      expect(peak / 54, closeTo(1.55, 0.155));
      expect(narrowest / 94, lessThanOrEqualTo(0.92));
    });

    test('two slots stretch: width ×1.33 ± 10 %', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      var widest = 0.0;
      run(m, 0.6, each: (_) {
        if (m.frame.lens.width > widest) widest = m.frame.lens.width;
      });
      expect(widest / 94, closeTo(1.33, 0.133));
    });

    test('engage holds 0.35 s, the target pops ×1.16, the pill bulges', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      var popPeak = 1.0;
      var scalePeak = 1.0;
      run(m, 0.3, each: (_) {
        final f = m.frame;
        if (f.popScale > popPeak) popPeak = f.popScale;
        if (f.pillScale > scalePeak) scalePeak = f.pillScale;
      });
      expect(m.frame.engage, greaterThan(0.95));
      expect(m.frame.popSlot, 1);
      expect(popPeak, closeTo(1.16, 0.02));
      expect(scalePeak, inInclusiveRange(1.010, 1.030));
      run(m, 1);
      expect(m.frame.engage, lessThan(0.01));
      expect(m.frame.popScale, closeTo(1, 0.002));
    });
  });

  group('press and hold (research §4.1)', () {
    test('lens 110 × 70, pill ×1.052, highlight 0.845, glow 0.28', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      run(m, 1);
      final f = m.frame;
      expect(f.lens.width, closeTo(110, 2));
      expect(f.lens.height, closeTo(70, 2));
      expect(f.pillScale, closeTo(1.052, 0.005));
      expect(f.engage, closeTo(1, 0.01));
      expect(f.highlight, closeTo(0.845, 0.02));
      expect(f.glowOpacity, closeTo(0.28, 0.02));
      expect(f.glowDiameter, closeTo(98, 1));
      expect(f.glowCenter, const Offset(94, 31));
      expect(f.magnify, closeTo(1.16, 0.002));
      expect(m.phase, LensPhase.pressed);
    });

    test('holding never selects', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(180, 31));
      run(m, 1);
      expect(m.committed, 0);
      expect(m.pending, isNull);
    });
  });

  group('drag (research §4.2)', () {
    test('lag at 90 pt/s equals the follow spring ramp lag ± 10 %', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      var finger = 94.0;
      run(m, 1, each: (t) {
        finger = 94 + 90 * t;
        m.move(Offset(finger, 31));
      });
      final s = TabSprings.dragFollow;
      final rampLag = 90 * s.damping / s.stiffness; // v·2ζ/ω
      expect(finger - m.frame.lens.center.dx,
          closeTo(rampLag, within(rampLag, 0.10)));
      expect(rampLag, closeTo(7.1, 0.1));
      expect(m.phase, LensPhase.dragging);
    });

    test('the lens is clamped to the first and last slot', () {
      final m = LensMotion(geometry: g3, selected: 1)
        ..down(const Offset(180, 31))
        ..move(const Offset(400, 31));
      run(m, 1);
      expect(m.frame.lens.center.dx, closeTo(266, 0.5));
      m.move(const Offset(-80, 31));
      run(m, 1);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
    });

    test('one crossing per slot boundary, in order', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      final crossings = <int>[];
      run(m, 3, each: (t) {
        m.move(Offset(94 + 60 * t, 31));
        crossings.addAll(m.takeCrossings());
      });
      expect(crossings, [1, 2]);
    });

    test('no crossing on a tap, even when the lens moves', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(266, 31));
      run(m, 0.3);
      expect(m.takeCrossings(), isEmpty);
    });
  });

  group('release (research §4.3)', () {
    test('commits the slot nearest the lens, not the finger', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(230, 31));
      while (m.frame.lens.center.dx < 215) {
        m.advance(dt);
      }
      expect(m.up(const Offset(230, 31), velocity: 90), 1);
      expect(m.pending, 1);
    });

    test('a flick commits the finger slot', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(230, 31));
      while (m.frame.lens.center.dx < 215) {
        m.advance(dt);
      }
      expect(m.up(const Offset(230, 31), velocity: 1500), 2);
    });

    test('settles on the snap spring ± 10 %', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(220, 31));
      run(m, 1.5);
      final from = m.frame.lens.center.dx;
      expect(m.up(const Offset(220, 31)), 1);
      final xs = [for (final f in run(m, 1.5)) f.lens.center.dx];
      final reference =
          settleTime(referenceTrace(TabSprings.snap, from, 180), 180);
      expect(settleTime(xs, 180), closeTo(reference, within(reference, 0.10)));
      expect(m.frame.lens.size, const Size(94, 54));
      expect(m.frame.pillScale, closeTo(1, 0.001));
    });

    test('the glow ripples ×4 and fades in 0.5 s', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      run(m, 0.5);
      final held = m.frame.glowDiameter;
      m.up(const Offset(94, 31));
      run(m, 0.25);
      expect(m.frame.glowDiameter, greaterThan(held * 2));
      run(m, 0.3);
      expect(m.frame.glowOpacity, 0);
      expect(m.frame.glowCenter, isNull);
    });

    test('a tap on the selected slot commits it again (reselect)', () {
      final m = LensMotion(geometry: g3, selected: 1)
        ..down(const Offset(180, 31));
      run(m, 0.05);
      expect(m.up(const Offset(180, 31)), 1);
    });

    test('cancel goes back to the committed slot', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(200, 31));
      run(m, 0.5);
      m.cancel();
      run(m, 1.5);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
      expect(m.committed, 0);
      expect(m.pending, isNull);
    });
  });

  group('commit bookkeeping (spec §8.7)', () {
    test('accept clears the pending commit', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      expect(m.pending, 2);
      m.accept();
      expect(m.pending, isNull);
      expect(m.committed, 2);
    });

    test('returnTo snaps back to the app selection', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      run(m, 1.5);
      m.returnTo(0);
      expect(m.pending, isNull);
      run(m, 1.5);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
    });

    test('show jumps without animation', () {
      final m = LensMotion(geometry: g3, selected: 0)..show(2);
      expect(m.frame.lens, g3.slots[2]);
      expect(m.advance(dt), isFalse);
    });

    test('a new geometry at rest moves the lens with it', () {
      final m = LensMotion(geometry: g3, selected: 1);
      final g4 = compactTabGeometry(
        count: 4,
        maxWidth: 360,
        trailing: true,
        direction: TextDirection.ltr,
      );
      m.geometry = g4;
      expect(m.frame.lens, g4.slots[1]);
    });
  });

  group('reduce motion (spec §13.2)', () {
    test('press: nothing inflates, nothing engages', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..down(const Offset(94, 31));
      run(m, 0.5);
      expect(m.frame.lens.size, const Size(94, 54));
      expect(m.frame.engage, 0);
      expect(m.frame.pillScale, 1);
      expect(m.frame.glowOpacity, 0);
    });

    test('tap: a 150 ms dissolve, no slide', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..tapSlot(2);
      expect(m.frame.lens, g3.slots[2]);
      expect(m.frame.ghost, g3.slots[0]);
      expect(m.frame.ghostOpacity, 1);
      expect(m.frame.restOpacity, 0);
      run(m, 0.2);
      expect(m.frame.ghost, isNull);
      expect(m.frame.restOpacity, 1);
      expect(m.frame.popScale, 1);
    });

    test('drag: the rest-size capsule follows the finger', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..down(const Offset(94, 31))
        ..move(const Offset(200, 31));
      run(m, 1);
      expect(m.frame.lens.center.dx, closeTo(200, 0.5));
      expect(m.frame.lens.size, const Size(94, 54));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/lens_motion_test.dart`
Expected: FAIL, because `lens_motion.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// liquid_shell/lib/src/chrome/lens_motion.dart
import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/painting.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

/// What the lens is doing (spec VK-503 §8.2).
enum LensPhase {
  /// At the committed slot, nothing moves.
  rest,

  /// Finger down, travel within the touch slop.
  pressed,

  /// Finger down and moved beyond the slop: the lens follows it.
  dragging,

  /// After a tap: the 0.35 s flight envelope.
  flying,

  /// Springs returning to rest.
  settling,
}

/// Everything the bar paints for one frame (spec §8.4). Bar-local.
@immutable
class LensFrame {
  /// Creates a frame.
  const LensFrame({
    required this.lens,
    this.visible = true,
    this.engage = 0,
    this.refraction = 0,
    this.pillScale = 1,
    this.highlight = 0,
    this.glowCenter,
    this.glowDiameter = 0,
    this.glowOpacity = 0,
    this.popSlot,
    this.popScale = 1,
    this.ghost,
    this.ghostOpacity = 0,
    this.restOpacity = 1,
  });

  /// The lens capsule.
  final Rect lens;

  /// Whether a lens is drawn at all (nothing selected and untouched: no).
  final bool visible;

  /// 0 = gray rest fill, 1 = clear glass (spec §7.1).
  final double engage;

  /// Lens refraction amount, 0–1.
  final double refraction;

  /// Pill scale about its centre.
  final double pillScale;

  /// Pill highlight amount, 0–1 (peak per brightness in the painter).
  final double highlight;

  /// Finger glow centre, or null.
  final Offset? glowCenter;

  /// Finger glow diameter.
  final double glowDiameter;

  /// Finger glow opacity.
  final double glowOpacity;

  /// The slot whose tinted content pops, or null.
  final int? popSlot;

  /// Its scale.
  final double popScale;

  /// Reduce motion: the outgoing rest fill, or null.
  final Rect? ghost;

  /// Its opacity.
  final double ghostOpacity;

  /// Opacity of the rest fill at [lens] (reduce motion fade-in).
  final double restOpacity;

  /// Scale of the tinted copy about the lens centre.
  double get magnify => 1 + TabSprings.magnify * engage;

  /// A copy with the given fields replaced (debug overrides and goldens).
  LensFrame copyWith({
    Rect? lens,
    double? engage,
    double? refraction,
    double? pillScale,
    double? highlight,
  }) => LensFrame(
    lens: lens ?? this.lens,
    visible: visible,
    engage: engage ?? this.engage,
    refraction: refraction ?? this.refraction,
    pillScale: pillScale ?? this.pillScale,
    highlight: highlight ?? this.highlight,
    glowCenter: glowCenter,
    glowDiameter: glowDiameter,
    glowOpacity: glowOpacity,
    popSlot: popSlot,
    popScale: popScale,
    ghost: ghost,
    ghostOpacity: ghostOpacity,
    restOpacity: restOpacity,
  );
}

/// The lens state machine (spec §8). Pure: the widget feeds it pointer
/// events in bar-local coordinates and calls [advance] once per frame.
class LensMotion {
  /// Starts at rest on [selected] (null: nothing highlighted).
  LensMotion({
    required TabBarGeometry geometry,
    required int? selected,
    this.reduceMotion = false,
  }) : _geometry = geometry,
       _committed = _valid(selected, geometry) {
    final rest = _restRect(_committed);
    _x = SpringValue(rest.center.dx, TabSprings.tap);
    _w = SpringValue(rest.width, TabSprings.widthOut);
    _h = SpringValue(rest.height, TabSprings.heightOut);
  }

  /// Reduce motion (spec §13.2).
  bool reduceMotion;

  TabBarGeometry _geometry;
  int? _committed;
  int? _pending;
  LensPhase _phase = LensPhase.rest;

  late final SpringValue _x;
  late final SpringValue _w;
  late final SpringValue _h;
  final SpringValue _scale = SpringValue(1, TabSprings.scaleOut);
  final SpringValue _engage = SpringValue(0, TabSprings.engageOut);
  final SpringValue _refraction = SpringValue(0, TabSprings.effectOut);
  final SpringValue _highlight = SpringValue(0, TabSprings.effectOut);
  final SpringValue _glowOpacity = SpringValue(0, TabSprings.glowIn);
  final SpringValue _glowDiameter = SpringValue(
    TabSprings.glowDiameter,
    TabSprings.glowIn,
  );
  final SpringValue _pop = SpringValue(1, TabSprings.tap);

  Offset? _glowCenter;
  double? _rippleAge;
  double _rippleOpacity = 0;
  double _rippleDiameter = TabSprings.glowDiameter;
  double _downX = 0;
  double _travel = 0;
  double _age = 0;
  int _flightSlots = 1;
  double _flightTarget = 0;
  int? _popSlot;
  int _lastSlot = 0;
  final List<int> _crossings = [];
  int? _ghostSlot;
  double _ghostAge = 0;
  double _fadeIn = 1;

  List<SpringValue> get _springs => [
    _x,
    _w,
    _h,
    _scale,
    _engage,
    _refraction,
    _highlight,
    _glowOpacity,
    _glowDiameter,
    _pop,
  ];

  static int? _valid(int? slot, TabBarGeometry g) =>
      slot != null && slot >= 0 && slot < g.slots.length ? slot : null;

  /// The geometry; a new one at rest moves the lens without animation.
  TabBarGeometry get geometry => _geometry;
  set geometry(TabBarGeometry value) {
    if (value == _geometry) return;
    _geometry = value;
    _committed = _valid(_committed, value);
    _pending = _valid(_pending, value);
    final committed = _committed;
    switch (_phase) {
      case LensPhase.rest:
        _jumpTo(committed);
      case LensPhase.flying:
        if (committed != null) _flightTarget = value.centreOf(committed);
      case LensPhase.settling:
        if (committed != null) _x.target = value.centreOf(committed);
      case LensPhase.pressed || LensPhase.dragging:
        _x.target = value.clampCentre(_x.target);
    }
  }

  /// The current phase.
  LensPhase get phase => _phase;

  /// The slot the lens belongs to.
  int? get committed => _committed;

  /// A commit the app has not confirmed yet (spec §8.7).
  int? get pending => _pending;

  /// A finger is down.
  bool get interacting =>
      _phase == LensPhase.pressed || _phase == LensPhase.dragging;

  Rect _restRect(int? slot) =>
      slot == null || slot >= _geometry.slots.length
      ? Rect.zero
      : _geometry.slots[slot];

  void _jumpTo(int? slot) {
    final r = _restRect(slot);
    _x.jump(r.center.dx);
    _w.jump(r.width);
    _h.jump(r.height);
    _scale.jump(1);
    _engage.jump(0);
    _refraction.jump(0);
    _highlight.jump(0);
    _glowOpacity.jump(0);
    _glowDiameter.jump(TabSprings.glowDiameter);
    _pop.jump(1);
    _glowCenter = null;
    _rippleAge = null;
    _ghostSlot = null;
    _fadeIn = 1;
    _popSlot = null;
    _phase = LensPhase.rest;
  }

  /// Finger down at [local].
  void down(Offset local) {
    if (_geometry.slots.isEmpty) return;
    if (_committed == null && !interacting) {
      final r = _geometry.slots[_geometry.slotNearest(local.dx)];
      _x.jump(_geometry.clampCentre(local.dx));
      _w.jump(r.width);
      _h.jump(r.height);
    }
    _phase = LensPhase.pressed;
    _downX = local.dx;
    _travel = 0;
    _lastSlot = _geometry.slotNearest(_x.value);
    _crossings.clear();
    _x.retarget(
      _geometry.clampCentre(local.dx),
      reduceMotion ? TabSprings.reduced : TabSprings.dragFollow,
    );
    if (!reduceMotion) {
      _glowCenter = local;
      _rippleAge = null;
      _glowDiameter.jump(TabSprings.glowDiameter);
    }
  }

  /// Finger moved to [local].
  void move(Offset local) {
    if (!interacting) return;
    _travel = math.max(_travel, (local.dx - _downX).abs());
    if (_travel > kTouchSlop) _phase = LensPhase.dragging;
    _x.target = _geometry.clampCentre(local.dx);
    if (!reduceMotion) _glowCenter = local;
  }

  /// Finger up at [local] with horizontal [velocity]; returns the committed
  /// slot (spec §8.2).
  int? up(Offset local, {double velocity = 0}) {
    if (!interacting) return null;
    final tap = _phase == LensPhase.pressed;
    final flick = velocity.abs() >= TabSprings.flickVelocity;
    final slot = _geometry.slotNearest(tap || flick ? local.dx : _x.value);
    _startRipple();
    _commit(slot, tap: tap);
    return slot;
  }

  /// The touch was taken away: back to the committed slot, no commit.
  void cancel() {
    if (!interacting) return;
    _startRipple();
    _settleBack();
  }

  /// A tap from semantics (or a test): the tap path without a press.
  void tapSlot(int slot) {
    if (slot < 0 || slot >= _geometry.slots.length) return;
    _commit(slot, tap: true);
  }

  /// A programmatic selection: jump (spec §8.7, Q12).
  void show(int? slot) {
    _pending = null;
    _committed = _valid(slot, _geometry);
    _jumpTo(_committed);
  }

  /// The app adopted the pending commit.
  void accept() => _pending = null;

  /// The app did not adopt it: snap back to [slot].
  void returnTo(int? slot) {
    _pending = null;
    _committed = _valid(slot, _geometry);
    if (_committed == null) {
      _jumpTo(null);
      return;
    }
    _settleBack();
  }

  /// Slots the lens entered while dragging since the last call.
  List<int> takeCrossings() {
    final out = List.of(_crossings);
    _crossings.clear();
    return out;
  }

  void _settleBack() {
    _phase = LensPhase.settling;
    final c = _committed;
    if (c == null) {
      _jumpTo(null);
      return;
    }
    _x.retarget(
      _geometry.centreOf(c),
      reduceMotion ? TabSprings.reduced : TabSprings.snap,
    );
  }

  void _startRipple() {
    if (reduceMotion || _glowCenter == null) return;
    _rippleAge = 0;
    _rippleOpacity = _glowOpacity.value;
    _rippleDiameter = _glowDiameter.value;
  }

  void _commit(int slot, {required bool tap}) {
    final from = _committed;
    _committed = slot;
    _pending = slot;
    if (reduceMotion) {
      if (tap) {
        if (from != null && from != slot) {
          _ghostSlot = from;
          _ghostAge = 0;
          _fadeIn = 0;
        }
        final r = _restRect(slot);
        _x.jump(r.center.dx);
        _w.jump(r.width);
        _h.jump(r.height);
        _phase = LensPhase.settling;
      } else {
        _settleBack();
      }
      return;
    }
    if (!tap) {
      _settleBack();
      return;
    }
    _phase = LensPhase.flying;
    _age = 0;
    _flightSlots = from == null ? 1 : math.max(1, (slot - from).abs());
    _flightTarget = _geometry.centreOf(slot);
    _x.spring = TabSprings.tap;
    _popSlot = slot;
    _pop.retarget(TabSprings.pop, TabSprings.tap);
  }

  /// Advances [dt] seconds; true while anything still moves.
  bool advance(double dt) {
    final rest = _geometry.restLensAt(_x.value);
    var w = rest.width;
    var h = rest.height;
    var scale = 1.0;
    var engage = 0.0;
    var refraction = 0.0;
    var highlight = 0.0;
    switch (_phase) {
      case LensPhase.pressed || LensPhase.dragging:
        if (!reduceMotion) {
          w *= TabSprings.pressWidthFactor;
          h *= TabSprings.pressHeightFactor;
          scale = TabSprings.pressScale;
          engage = 1;
          refraction = 1;
          highlight = TabSprings.highlightPress;
        }
      case LensPhase.flying:
        _age += dt;
        if (_age >= TabSprings.tapDelay) _x.target = _flightTarget;
        if (_geometry.form == TabBarForm.top) {
          if (_age < TabSprings.liftUntil) {
            w *= TabSprings.topTapWidth;
            h *= TabSprings.topTapHeight;
          }
        } else {
          w *= TabSprings.stretchFor(_x.velocity);
          if (_age < TabSprings.liftUntil) {
            final gate = _flightSlots == 1 ? 1.0 : TabSprings.liftGateFar;
            h *= 1 + TabSprings.liftGain * gate;
          }
        }
        scale = _age < TabSprings.bulgeUntil ? TabSprings.bulge : 1;
        engage = _age < TabSprings.flightHold ? 1 : 0;
        refraction = _age < TabSprings.liftUntil ? 1 : 0;
        highlight = _age < TabSprings.highlightUntil
            ? TabSprings.highlightTap
            : 0;
        if (_age >= TabSprings.popUntil) _pop.target = 1;
        if (_age >= TabSprings.flightHold) _phase = LensPhase.settling;
      case LensPhase.settling || LensPhase.rest:
        break;
    }
    _w.retarget(w, w >= _w.value ? TabSprings.widthIn : TabSprings.widthOut);
    _h.retarget(h, h >= _h.value ? TabSprings.heightIn : TabSprings.heightOut);
    _scale.retarget(
      scale,
      scale >= _scale.value ? TabSprings.scaleIn : TabSprings.scaleOut,
    );
    _engage.retarget(
      engage,
      engage >= _engage.value ? TabSprings.engageIn : TabSprings.engageOut,
    );
    _refraction.retarget(
      refraction,
      refraction >= _refraction.value
          ? TabSprings.effectIn
          : TabSprings.effectOut,
    );
    _highlight.retarget(
      highlight,
      highlight >= _highlight.value
          ? TabSprings.highlightIn
          : TabSprings.effectOut,
    );
    final holding = interacting && !reduceMotion;
    _glowOpacity.retarget(
      holding ? TabSprings.glowOpacity : 0,
      holding ? TabSprings.glowIn : TabSprings.effectOut,
    );
    if (holding) _glowDiameter.target = TabSprings.glowHeldDiameter;
    for (final s in _springs) {
      s.advance(dt);
    }
    _advanceRipple(dt);
    _advanceGhost(dt);
    if (_phase == LensPhase.dragging) _queueCrossing();
    final moving = _isMoving();
    if (!moving && _phase == LensPhase.settling) {
      for (final s in _springs) {
        s.jump(s.target);
      }
      _popSlot = null;
      _phase = LensPhase.rest;
    }
    return moving;
  }

  void _advanceRipple(double dt) {
    final age = _rippleAge;
    if (age == null) return;
    final next = age + dt;
    if (next >= TabSprings.glowFade) {
      _rippleAge = null;
      _glowCenter = null;
      _glowOpacity.jump(0);
      _glowDiameter.jump(TabSprings.glowDiameter);
    } else {
      _rippleAge = next;
    }
  }

  void _advanceGhost(double dt) {
    if (_ghostSlot == null && _fadeIn >= 1) return;
    _ghostAge += dt;
    _fadeIn = (_ghostAge / TabSprings.ghostFade).clamp(0.0, 1.0);
    if (_fadeIn >= 1) _ghostSlot = null;
  }

  void _queueCrossing() {
    final s = _geometry.slotNearest(_x.value);
    if (s == _lastSlot) return;
    _lastSlot = s;
    _crossings.add(s);
  }

  bool _isMoving() {
    if (interacting || _phase == LensPhase.flying) return true;
    if (_rippleAge != null || _ghostSlot != null || _fadeIn < 1) return true;
    return !(_x.settled(0.5) &&
        _w.settled(0.5) &&
        _h.settled(0.5) &&
        _scale.settled(0.001) &&
        _engage.settled(0.005) &&
        _refraction.settled(0.005) &&
        _highlight.settled(0.005) &&
        _glowOpacity.settled(0.005) &&
        _pop.settled(0.002));
  }

  /// The frame to paint now.
  LensFrame get frame {
    final cy = _geometry.slots.isEmpty
        ? _geometry.size.height / 2
        : _geometry.slots.first.center.dy;
    final age = _rippleAge;
    final ripple = age == null
        ? null
        : Curves.easeOutCubic.transform(
            (age / TabSprings.glowFade).clamp(0.0, 1.0),
          );
    return LensFrame(
      lens: Rect.fromCenter(
        center: Offset(_x.value, cy),
        width: _w.value,
        height: _h.value,
      ),
      visible: _committed != null || interacting,
      engage: _engage.value.clamp(0.0, 1.0),
      refraction: _refraction.value.clamp(0.0, 1.0),
      pillScale: _scale.value,
      highlight: _highlight.value.clamp(0.0, 1.0),
      glowCenter: _glowCenter,
      glowDiameter: ripple == null
          ? _glowDiameter.value
          : _rippleDiameter * (1 + (TabSprings.glowRipple - 1) * ripple),
      glowOpacity: ripple == null
          ? _glowOpacity.value.clamp(0.0, 1.0)
          : _rippleOpacity * (1 - ripple),
      popSlot: _popSlot,
      popScale: _pop.value,
      ghost: _ghostSlot == null ? null : _restRect(_ghostSlot),
      ghostOpacity: _ghostSlot == null ? 0 : 1 - _fadeIn,
      restOpacity: _fadeIn,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/unit/lens_motion_test.dart`
Expected: PASS.

If an envelope test (lift, stretch, bulge) misses its range, change **only** the `TabSprings` envelope constants named in spec §8.3:

- `stretchFloor`, `stretchKnee`, `stretchGain`;
- `liftGain`, `liftGateFar`;
- `bulge`, `bulgeUntil`.

Record the change in the commit message body. Never widen a test tolerance.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell/lib/src/chrome/lens_motion.dart liquid_shell/test/unit/lens_motion_test.dart
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/lens_motion.dart liquid_shell/test/unit/lens_motion_test.dart
git commit -m "feat(shell): the tab lens motion model on the fitted springs (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 4: Theme tokens, new material defaults, and lens optics overrides

**Files:**
- Modify: `liquid_shell/lib/src/glass/glass_theme.dart`
- Modify: `liquid_shell/lib/src/glass/liquid_optics.dart`
- Test: `liquid_shell/test/unit/glass_theme_test.dart`, `liquid_shell/test/unit/liquid_optics_test.dart`
- Regenerate: goldens (`make goldens-update`)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `LiquidGlassTheme.selectionFill` (`Color`), `tabForeground` (`Color`), `badgeColor` (`Color`), `tabIconSize` (`double`). Each is a constructor parameter with a default, and is part of `copyWith`, `lerp`, `==` and `hashCode`;
  - new `fromColorScheme` defaults for `rimHighlight`, `shadow`, `dispersion` and `labelStyle` (spec §6.4);
  - `LiquidOpticsParams({…, double? bezel, double? rimWidth})`, where null keeps `LiquidOptics.bezel` / `LiquidOptics.rimWidth`.

- [ ] **Step 1: Write the failing tests**

In `liquid_shell/test/unit/glass_theme_test.dart`, make three changes to the existing `fromColorScheme` group:

1. Replace the two `rimHighlight` expectations:
   - light: `const Color(0xFFFFFFFF).withValues(alpha: 0.12)`;
   - dark: `const Color(0xFFFFFFFF).withValues(alpha: 0.22)`.
2. Replace the `shared values` shadow and label expectations with:

```dart
        expect(
          theme.shadow,
          const BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 3),
            blurRadius: 20,
          ),
        );
        expect(theme.labelStyle.fontSize, 10);
        expect(theme.labelStyle.height, 1.2);
        expect(theme.labelStyle.fontWeight, FontWeight.w500);
        expect(theme.labelStyle.letterSpacing, 0);
        expect(theme.labelStyle.fontFamily, isNull);
        expect(theme.tabIconSize, 26);
```

3. Change `expect(light.dispersion, 0.3);` to `expect(light.dispersion, 0);`. In the `LiquidOpticsParams.fromTheme maps the fields` test, change `dispersion: 0.3` to `dispersion: 0`.

Then append this group inside `main()`:

```dart
  group('tab tokens (spec VK-503 §6.4)', () {
    test('light and dark defaults', () {
      final l = LiquidGlassTheme.fromColorScheme(light);
      final d = LiquidGlassTheme.fromColorScheme(dark);
      expect(l.selectionFill, const Color(0x14000000));
      expect(d.selectionFill, const Color(0x21FFFFFF));
      expect(l.tabForeground, const Color(0xFF191919));
      expect(d.tabForeground, const Color(0xFFF4F4F4));
      expect(l.badgeColor, const Color(0xFFFF383C));
      expect(d.badgeColor, const Color(0xFFFF4245));
    });

    test('constructor defaults', () {
      const t = LiquidGlassTheme(
        tint: Color(0x00000000),
        solid: Color(0xFFFFFFFF),
        border: Color(0x00000000),
        rimHighlight: Color(0x00000000),
        shadow: BoxShadow(),
        labelStyle: TextStyle(),
      );
      expect(t.selectionFill, const Color(0x14000000));
      expect(t.tabForeground, const Color(0xFF191919));
      expect(t.badgeColor, const Color(0xFFFF383C));
      expect(t.tabIconSize, 26);
    });

    test('copyWith, lerp, == and hashCode cover them', () {
      final base = LiquidGlassTheme.fromColorScheme(light);
      final other = base.copyWith(
        selectionFill: const Color(0x28000000),
        tabForeground: const Color(0xFF000000),
        badgeColor: const Color(0xFFFF0000),
        tabIconSize: 30,
      );
      expect(other.selectionFill, const Color(0x28000000));
      expect(other.tabForeground, const Color(0xFF000000));
      expect(other.badgeColor, const Color(0xFFFF0000));
      expect(other.tabIconSize, 30);
      expect(other, isNot(base));
      expect(other.hashCode, isNot(base.hashCode));
      final half = base.lerp(other, 0.5);
      expect(half.tabIconSize, 28);
      expect(half.selectionFill, Color.lerp(
        base.selectionFill,
        other.selectionFill,
        0.5,
      ));
      expect(base.copyWith(), base);
    });
  });
```

In `liquid_shell/test/unit/liquid_optics_test.dart` append:

```dart
  group('lens overrides (spec VK-503 §7.2)', () {
    const rect = Rect.fromLTWH(300, 2300, 330, 210);

    test('null overrides keep the floats byte-identical', () {
      const same = LiquidOpticsParams(
        tint: Color(0x38FFFFFF),
        rim: Color(0x80FFFFFF),
        refraction: 1,
        dispersion: 0.3,
        blurSigma: 3,
      );
      expect(_uniforms(rect, params: same), _uniforms(rect));
    });

    test('bezel replaces float 8, rimWidth float 22, in pass pixels', () {
      const lens = LiquidOpticsParams(
        tint: Color(0x38FFFFFF),
        rim: Color(0x80FFFFFF),
        refraction: 1,
        dispersion: 0.3,
        blurSigma: 3,
        bezel: 35,
        rimWidth: 1,
      );
      final base = _uniforms(rect);
      final over = _uniforms(rect, params: lens);
      expect(over[8], closeTo(35 * 3, 1e-4));
      expect(over[22], closeTo(3, 1e-4));
      for (var i = 0; i < base.length; i++) {
        if (i == 8 || i == 22) continue;
        expect(over[i], base[i], reason: 'float $i');
      }
    });

    test('a bezel override is still clamped to half the short side', () {
      const lens = LiquidOpticsParams(
        tint: Color(0x00000000),
        rim: Color(0x00000000),
        refraction: 1,
        dispersion: 0,
        blurSigma: 0,
        bezel: 500,
      );
      expect(_uniforms(rect, params: lens)[8], closeTo(105, 1e-4));
    });

    test('== and hashCode include the overrides', () {
      const a = LiquidOpticsParams(
        tint: Color(0x00000000),
        rim: Color(0x00000000),
        refraction: 1,
        dispersion: 0,
        blurSigma: 0,
        bezel: 10,
      );
      const b = LiquidOpticsParams(
        tint: Color(0x00000000),
        rim: Color(0x00000000),
        refraction: 1,
        dispersion: 0,
        blurSigma: 0,
        bezel: 11,
      );
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd liquid_shell && fvm flutter test test/unit/glass_theme_test.dart test/unit/liquid_optics_test.dart`
Expected: FAIL. The compile errors are `No named parameter with the name 'selectionFill'` and `… 'bezel'`.

- [ ] **Step 3: Implement**

In `liquid_shell/lib/src/glass/glass_theme.dart`:

(a) Add the constructor parameters after `this.liquidBlurSigma = 2,`:

```dart
    this.selectionFill = const Color(0x14000000),
    this.tabForeground = const Color(0xFF191919),
    this.badgeColor = const Color(0xFFFF383C),
    this.tabIconSize = 26,
```

(b) Replace the body of `fromColorScheme` with:

```dart
  factory LiquidGlassTheme.fromColorScheme(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    return LiquidGlassTheme(
      tint: scheme.surface.withValues(alpha: light ? 0.72 : 0.90),
      solid: scheme.surface,
      liquidTint: scheme.surface.withValues(alpha: light ? 0.40 : 0.45),
      border: light
          ? scheme.outline.withValues(alpha: 0.28)
          : scheme.onSurface.withValues(alpha: 0.18),
      // iOS 26.5: a barely visible top edge in light, ~1 pt in dark
      // (spec VK-503 §6.4, research §5).
      rimHighlight: const Color(
        0xFFFFFFFF,
      ).withValues(alpha: light ? 0.12 : 0.22),
      shadow: const BoxShadow(
        color: Color(0x12000000),
        offset: Offset(0, 3),
        blurRadius: 20,
      ),
      labelStyle: const TextStyle(
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      // Native shows a fringe only on the active lens (research §5).
      dispersion: 0,
      selectionFill: light
          ? const Color(0x14000000)
          : const Color(0x21FFFFFF),
      tabForeground: light
          ? const Color(0xFF191919)
          : const Color(0xFFF4F4F4),
      badgeColor: light ? const Color(0xFFFF383C) : const Color(0xFFFF4245),
    );
  }
```

(c) Add the fields after `liquidBlurSigma`:

```dart
  /// The selected tab lens at rest: a neutral fill over the pill (spec
  /// VK-503 §6.2).
  final Color selectionFill;

  /// Unselected tab icons and labels.
  final Color tabForeground;

  /// Tab bar badge capsule.
  final Color badgeColor;

  /// Tab bar icon size at text scale 1.
  final double tabIconSize;
```

(d) In `copyWith`:
- add the parameters `Color? selectionFill, Color? tabForeground, Color? badgeColor, double? tabIconSize`;
- pass `selectionFill: selectionFill ?? this.selectionFill`, `tabForeground: tabForeground ?? this.tabForeground`, `badgeColor: badgeColor ?? this.badgeColor` and `tabIconSize: tabIconSize ?? this.tabIconSize`.

(e) In `lerp` add:

```dart
      selectionFill: Color.lerp(selectionFill, other.selectionFill, t)!,
      tabForeground: Color.lerp(tabForeground, other.tabForeground, t)!,
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t)!,
      tabIconSize: lerpDouble(tabIconSize, other.tabIconSize, t)!,
```

(f) In `==`, add `other.selectionFill == selectionFill && other.tabForeground == tabForeground && other.badgeColor == badgeColor && other.tabIconSize == tabIconSize`.

(g) `Object.hash` takes at most 20 arguments, so replace `hashCode` with:

```dart
  @override
  int get hashCode => Object.hashAll([
    tint,
    solid,
    border,
    borderWidth,
    rimHighlight,
    shadow,
    blurSigma,
    borderRadius,
    labelStyle,
    liquidTint,
    refraction,
    dispersion,
    liquidBlurSigma,
    selectionFill,
    tabForeground,
    badgeColor,
    tabIconSize,
  ]);
```

(h) Update the doc of `dispersion`: `/// Liquid colour fringe in the bezel, 0 (off) to 1. Default 0: native shows a fringe only on the active tab lens, which sets its own.`

In `liquid_shell/lib/src/glass/liquid_optics.dart`:

(a) `LiquidOpticsParams` gains two optional fields:

```dart
  /// Creates a parameter set.
  const LiquidOpticsParams({
    required this.tint,
    required this.rim,
    required this.refraction,
    required this.dispersion,
    required this.blurSigma,
    this.bezel,
    this.rimWidth,
  });

  /// Bezel width override in logical pixels; null uses
  /// [LiquidOptics.bezel]. The tab lens curves its whole height (spec
  /// VK-503 §7.2).
  final double? bezel;

  /// Rim width override in logical pixels; null uses
  /// [LiquidOptics.rimWidth].
  final double? rimWidth;
```

(b) `==` adds `other.bezel == bezel && other.rimWidth == rimWidth`, and `hashCode` becomes `Object.hash(tint, rim, refraction, dispersion, blurSigma, bezel, rimWidth)`.

(c) In `liquidUniforms`:
- replace `(LiquidOptics.bezel * scale)` with `((params.bezel ?? LiquidOptics.bezel) * scale)`;
- replace `LiquidOptics.rimWidth * scale` with `(params.rimWidth ?? LiquidOptics.rimWidth) * scale`.

- [ ] **Step 4: Run the tests to verify they pass, then the whole suite**

```bash
cd liquid_shell && fvm flutter test test/unit/glass_theme_test.dart test/unit/liquid_optics_test.dart
cd .. && make test
```

Expected: PASS.

If another widget test asserts the old shadow, rim, label spacing or dispersion, update it to the new default with the exact §6.4 value. These are the only expected failures. Any other failure is a regression to fix in code. Candidates:

- `test/widget/glass_renderers_test.dart`;
- `test/widget/fit_label_test.dart` (the label height 1.4 → 1.2);
- `test/widget/liquid_backdrop_test.dart` (its own params, not the theme: it should not fail).

- [ ] **Step 5: Regenerate goldens, review, commit**

```bash
make goldens-update
git status --short liquid_shell/example/test/goldens liquid_shell/doc/images
```

Open three changed images and check that only the rim, shadow, label weight and spacing changed (no layout change):

- `liquid_shell/example/test/goldens/…/case_basic.png`;
- `hero_iphone_light.png`;
- one `liquid_*.png`.

Then:

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/glass_theme.dart liquid_shell/lib/src/glass/liquid_optics.dart liquid_shell/test liquid_shell/example/test/goldens liquid_shell/doc/images
git commit -m "feat(glass): native tab tokens and iOS 26.5 material defaults (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `LiquidLens`, the second glass pass

**Files:**
- Modify: `liquid_shell/lib/src/glass/liquid_glass.dart`
- Create: `liquid_shell/lib/src/glass/liquid_lens.dart`
- Test: `liquid_shell/test/widget/lens_layer_test.dart`, `liquid_shell/test/impeller/lens_pass_test.dart`

**Interfaces:**
- Consumes:
  - Task 4: `LiquidOpticsParams(bezel:, rimWidth:)`, `LiquidGlassTheme.selectionFill`;
  - existing: `LiquidBackdrop`, `RenderLiquidBackdrop.debugUniforms`, `LiquidShaderRenderer`, `LiquidShaderProgram`, `OutsideShadow`, `resolveGlassRenderer`.
- Produces:
  - `LiquidGlassRenderer resolveGlassFor(BuildContext context)`;
  - `Listenable liquidGlassChanges()`;
  - `class LiquidLens extends StatefulWidget { const LiquidLens({required double engage, required double refraction}) }`;
  - `const BoxShadow kLensShadow`.

- [ ] **Step 1: Write the failing tests**

```dart
// liquid_shell/test/widget/lens_layer_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';

Future<void> _liquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
}

Widget _lens({
  double engage = 1,
  double refraction = 1,
  LiquidGlassTier? forced,
  bool highContrast = false,
  ValueSetter<BackdropKey?>? onKey,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: LiquidGlassScope(
      policy: LiquidGlassPolicy(forcedTier: forced),
      child: BackdropGroup(
        child: Builder(
          builder: (context) {
            onKey?.call(BackdropGroup.of(context)?.backdropKey);
            return Center(
              child: SizedBox(
                width: 110,
                height: 70,
                child: LiquidLens(engage: engage, refraction: refraction),
              ),
            );
          },
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('liquid: clear glass, bezel h/2, 1 pt rim, shared backdrop', (
    tester,
  ) async {
    await _liquid(tester);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    BackdropKey? key;
    await tester.pumpWidget(_lens(onKey: (k) => key = k));
    await tester.pump();
    final render = tester.renderObject<RenderLiquidBackdrop>(
      find.byType(LiquidBackdrop),
    );
    expect(render.backdropKey, isNotNull);
    expect(render.backdropKey, key);
    final u = render.debugUniforms!;
    expect(u[8], closeTo(35 * 3, 1e-3)); // bezel = h/2
    expect(u[9], closeTo(48 * 1.6 * 3, 1e-3)); // thickness
    expect(u[11], closeTo(0.6, 1e-6)); // dispersion
    expect(u[15], 0); // tint alpha: clear glass
    expect(u[19], closeTo(0.35, 1e-3)); // rim alpha
    expect(u[22], closeTo(3, 1e-6)); // rim width 1 pt
  });

  testWidgets('refraction 0.5 halves thickness and dispersion; engage the '
      'rim', (tester) async {
    await _liquid(tester);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_lens(engage: 0.5, refraction: 0.5));
    await tester.pump();
    final u = tester
        .renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .debugUniforms!;
    expect(u[9], closeTo(48 * 0.8 * 3, 1e-3));
    expect(u[11], closeTo(0.3, 1e-6));
    expect(u[19], closeTo(0.175, 1e-3));
  });

  testWidgets('frosted: a grouped blur, no shader', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await tester.pumpWidget(_lens());
    expect(find.byType(LiquidBackdrop), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('solid: an opaque capsule, bordered under high contrast', (
    tester,
  ) async {
    await tester.pumpWidget(_lens(forced: LiquidGlassTier.solid));
    expect(find.byType(BackdropFilter), findsNothing);
    BoxDecoration deco() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
    expect(deco().color!.a, 1);
    expect(deco().border, isNull);
    await tester.pumpWidget(
      _lens(forced: LiquidGlassTier.solid, highContrast: true),
    );
    expect(deco().border, isNotNull);
  });

  testWidgets('the lens shadow fades with engage', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await tester.pumpWidget(_lens(engage: 0.5));
    final shadow = tester.widget<OutsideShadow>(find.byType(OutsideShadow));
    expect(shadow.shadow.color.a, closeTo(kLensShadow.color.a * 0.5, 1e-3));
  });
}
```

```dart
// liquid_shell/test/impeller/lens_pass_test.dart
@Tags(['impeller'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _scale = 2.0;
const _view = Size(400, 300);
const _pill = Rect.fromLTWH(50, 100, 300, 62);
const _lensRect = Rect.fromLTWH(100, 104, 94, 54);

ui.ImageFilter _filter(ui.FragmentProgram program, Rect r, Color tint) {
  final shader = program.fragmentShader();
  final floats = liquidUniforms(
    rect: Rect.fromLTRB(
      r.left * _scale,
      r.top * _scale,
      r.right * _scale,
      r.bottom * _scale,
    ),
    radii: BorderRadius.circular(r.height / 2),
    params: LiquidOpticsParams(
      tint: tint,
      rim: const Color(0x00000000),
      refraction: 0,
      dispersion: 0,
      blurSigma: 0,
    ),
    scale: _scale,
    pass: _view * _scale,
  );
  for (var i = 0; i < floats.length; i++) {
    shader.setFloat(LiquidOptics.firstIndex + i, floats[i]);
  }
  return ui.ImageFilter.shader(shader);
}

Widget _pass(ui.FragmentProgram p, Rect r, Color tint, {required bool grouped}) =>
    Positioned.fromRect(
      rect: r,
      child: ClipRect(
        child: grouped
            ? BackdropFilter.grouped(
                filter: _filter(p, r, tint),
                child: const SizedBox.expand(),
              )
            : BackdropFilter(
                filter: _filter(p, r, tint),
                child: const SizedBox.expand(),
              ),
      ),
    );

Future<List<int>> _lensCentre(WidgetTester tester, {required bool grouped}) async {
  final program = (await tester.runAsync(
    () => ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
  ))!;
  tester.view
    ..devicePixelRatio = _scale
    ..physicalSize = _view * _scale;
  addTearDown(tester.view.reset);
  final stack = Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF00FF00))),
      // The pill: an opaque red tint, so the lens would show red if it
      // sampled the pill.
      _pass(program, _pill, const Color(0xFFFF0000), grouped: grouped),
      // The lens: clear, no refraction, so it shows what it samples.
      _pass(program, _lensRect, const Color(0x00000000), grouped: grouped),
    ],
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: grouped ? BackdropGroup(child: stack) : stack,
    ),
  );
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
  final data = (await tester.runAsync(() => image!.toByteData()))!;
  final c = _lensRect.center;
  final i =
      ((c.dy * _scale).round() * (_view.width * _scale).round() +
          (c.dx * _scale).round()) *
      4;
  return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
}

void main() {
  testWidgets('in one BackdropGroup the lens samples the page (spec R1)', (
    tester,
  ) async {
    final rgb = await _lensCentre(tester, grouped: true);
    expect(rgb[1], greaterThan(200), reason: 'green page, got $rgb');
    expect(rgb[0], lessThan(60), reason: 'not the red pill, got $rgb');
  });

  testWidgets('control: ungrouped, the lens samples the pill', (tester) async {
    final rgb = await _lensCentre(tester, grouped: false);
    expect(rgb[0], greaterThan(200), reason: 'red pill, got $rgb');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd liquid_shell
fvm flutter test test/widget/lens_layer_test.dart
fvm flutter test --enable-impeller --tags impeller test/impeller/lens_pass_test.dart
```

Expected:
- the widget test FAILS with `liquid_lens.dart` not found;
- the Impeller test compiles (it uses no new code) and must already PASS. This is the R1 probe. If `in one BackdropGroup the lens samples the page` FAILS, **stop**: the second-pass design does not hold on this engine. Report to the controller with the pixel values. Spec R1's fallback (a one-pass two-shape shader) needs a plan change and the owner's go-ahead.

- [ ] **Step 3: Implement**

In `liquid_shell/lib/src/glass/liquid_glass.dart`, add the top-level functions and use them in `_LiquidGlassState`:

```dart
/// Everything that can change which renderer a glass uses (liquid tier
/// §5.5): platform signals, the shader program, the frame guard.
Listenable liquidGlassChanges() => Listenable.merge([
  LiquidSignalsController.instance,
  LiquidShaderProgram.instance,
  LiquidFrameGuard.instance,
]);

/// The renderer a glass at [context] uses now. `LiquidGlass` and
/// `LiquidLens` share it, so the tab pill and its lens never disagree
/// (spec VK-503 §7.3).
LiquidGlassRenderer resolveGlassFor(BuildContext context) {
  final platform = LiquidSignalsController.instance.value;
  return resolveGlassRenderer(
    LiquidGlassScope.policyOf(context),
    context,
    LiquidGlassSignals(
      reduceTransparency: platform.reduceTransparency,
      highContrast: MediaQuery.highContrastOf(context),
      powerSave: platform.powerSave,
      blurDisabled: platform.blurDisabled,
      lowEnd: platform.lowEnd,
      glesOnly: platform.glesOnly,
      slowFrames: LiquidFrameGuard.instance.value,
    ),
  );
}
```

In `_LiquidGlassState`:
- replace the `_changes` initializer with `late final Listenable _changes = liquidGlassChanges();`;
- in `builder`, replace the `platform`/`policy`/`resolveGlassRenderer(...)` block with `final renderer = resolveGlassFor(context);`.

The behaviour is unchanged: `liquid_glass_test.dart` must stay green.

```dart
// liquid_shell/lib/src/glass/liquid_lens.dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';
import 'package:liquid_shell/src/glass/liquid_renderer.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// The shadow under an engaged tab lens (spec VK-503 §7.2).
const BoxShadow kLensShadow = BoxShadow(
  color: Color(0x1A000000),
  offset: Offset(0, 2),
  blurRadius: 10,
);

/// The engaged tab lens: a second glass pass that refracts the page behind
/// the bar (spec VK-503 §7). It fills its box as a capsule. In the liquid
/// tier it shares the nearest `BackdropGroup`'s backdrop with the pill, so
/// it samples the page, not the pill.
class LiquidLens extends StatefulWidget {
  /// Creates a lens; [engage] scales the rim and shadow, [refraction] the
  /// thickness and dispersion.
  const LiquidLens({required this.engage, required this.refraction, super.key});

  /// 0–1.
  final double engage;

  /// 0–1.
  final double refraction;

  @override
  State<LiquidLens> createState() => _LiquidLensState();
}

class _LiquidLensState extends State<LiquidLens> {
  final LiquidSignalsController _signals = LiquidSignalsController.instance;
  late final Listenable _changes = liquidGlassChanges();

  @override
  void initState() {
    super.initState();
    _signals.acquire();
  }

  @override
  void dispose() {
    _signals.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.biggest.shortestSide;
        final radius = BorderRadius.all(Radius.circular(h / 2));
        final theme = LiquidGlassTheme.of(context);
        final renderer = resolveGlassFor(context);
        final engage = widget.engage.clamp(0.0, 1.0);
        final refraction = widget.refraction.clamp(0.0, 1.0);
        final rim = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * engage);
        final program = LiquidShaderProgram.instance.value;
        final Widget body;
        if (renderer is LiquidShaderRenderer && program != null) {
          body = ClipRRect(
            borderRadius: radius,
            child: LiquidBackdrop(
              program: program,
              borderRadius: radius,
              params: LiquidOpticsParams(
                tint: const Color(0x00000000),
                rim: rim,
                refraction: 1.6 * refraction,
                dispersion: 0.6 * refraction,
                blurSigma: 0,
                bezel: h / 2,
                rimWidth: 1,
              ),
            ),
          );
        } else if (renderer.tier == LiquidGlassTier.solid) {
          body = DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(theme.selectionFill, theme.solid),
              borderRadius: radius,
              border: MediaQuery.highContrastOf(context)
                  ? Border.all(color: theme.border, width: theme.borderWidth)
                  : null,
            ),
          );
        } else {
          body = ClipRRect(
            borderRadius: radius,
            child: BackdropFilter.grouped(
              filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withValues(
                    alpha: 0.10 * engage,
                  ),
                  borderRadius: radius,
                  border: Border.all(color: rim),
                ),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            body,
            // Above the lens, so the lens never samples its own shadow.
            OutsideShadow(
              borderRadius: radius,
              shadow: BoxShadow(
                color: kLensShadow.color.withValues(
                  alpha: kLensShadow.color.a * engage,
                ),
                offset: kLensShadow.offset,
                blurRadius: kLensShadow.blurRadius,
              ),
            ),
          ],
        );
      },
    ),
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd liquid_shell
fvm flutter test test/widget/lens_layer_test.dart test/widget/liquid_glass_test.dart
fvm flutter test --enable-impeller --tags impeller
cd .. && make provenance
```

Expected: PASS. `check_glass_seam.sh` prints `✓ glass seam clean`, because `liquid_lens.dart` is under `lib/src/glass/`.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell/lib/src/glass liquid_shell/test/widget/lens_layer_test.dart liquid_shell/test/impeller/lens_pass_test.dart
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/liquid_glass.dart liquid_shell/lib/src/glass/liquid_lens.dart liquid_shell/test/widget/lens_layer_test.dart liquid_shell/test/impeller/lens_pass_test.dart
git commit -m "feat(glass): LiquidLens, the tab lens as a second shared-backdrop pass (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `GlassTabBar` at rest: native slots, mask, filled icons, badges

**Files:**
- Create: `liquid_shell/lib/src/chrome/glass_tab_bar.dart`
- Modify: `liquid_shell/lib/src/chrome/tab_bar.dart` (the compact `LiquidTabBar` delegates; the top bar stays as is until Task 11)
- Modify: `liquid_shell/lib/src/destinations/badge.dart` (native badge metrics and colour)
- Test: `liquid_shell/test/widget/glass_tab_bar_test.dart` (new), `test/widget/tab_bar_test.dart`, `test/widget/badge_view_test.dart`, `test/widget/shell_chrome_test.dart`
- Regenerate: goldens

**Interfaces:**
- Consumes:
  - Task 1: `compactTabGeometry`, `tabIconFrame`, `tabLabelBox`, `TabMetrics`;
  - Task 3: `LensMotion`, `LensFrame`;
  - Task 4: the theme tokens.
- Produces:
  - `class GlassTabBar extends StatefulWidget`, with the parameters `destinations`, `selectedIndex`, `onSelect`, `trailing`, `minimized`, `onCollapsedTap`, `announceExpand`, `collapsedKey`, `strings`, `narrow`;
  - the keys `kTabPillKey`, `kTabNormalKey`, `kTabTintedKey`, `kTabTrailingKey`;
  - `@visibleForTesting LensFrame Function(LensFrame)? debugTabLensOverride`;
  - inside the state, `double get _morph` (0 or 1 here; animated in Task 9) and `void _select(int slot)` (replaced in Task 7).

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/widget/glass_tab_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _screen = Size(402, 874);
const _three = [
  LiquidDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  LiquidDestination(
    icon: Icon(Icons.map_outlined),
    selectedIcon: Icon(Icons.map),
    label: 'Explore',
    badge: LiquidBadge.count(3),
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0088FF));

Future<void> _pump(
  WidgetTester tester, {
  int selected = 0,
  ValueChanged<int>? onSelect,
  LiquidTabAction? trailing,
  bool minimized = false,
  VoidCallback? onExpand,
  TextDirection direction = TextDirection.ltr,
  List<LiquidDestination> destinations = _three,
  VoidCallback? onBody,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBody,
                ),
              ),
              Positioned(
                left: TabMetrics.margin,
                right: TabMetrics.margin,
                bottom: 21,
                child: LiquidTabBar(
                  destinations: destinations,
                  selectedIndex: selected,
                  onDestinationSelected: onSelect ?? (_) {},
                  trailing: trailing,
                  minimized: minimized,
                  onExpand: onExpand,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Screen rect of the semantics node labelled [label] (a slot).
Rect _slot(WidgetTester tester, String label) => tester.getRect(
  find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        (w.properties.label?.startsWith(label) ?? false) &&
        w.properties.button == true,
  ),
);

const _top = 874.0 - 21 - 62;

void main() {
  testWidgets('pill and slots match native geometry (research §1.1)', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getRect(find.byKey(kTabPillKey)),
      const Rect.fromLTWH(64, _top, 274, 62),
    );
    expect(_slot(tester, 'Home'), const Rect.fromLTWH(68, _top + 4, 94, 54));
    expect(
      _slot(tester, 'Explore'),
      const Rect.fromLTWH(154, _top + 4, 94, 54),
    );
    expect(
      _slot(tester, 'Settings'),
      const Rect.fromLTWH(240, _top + 4, 94, 54),
    );
  });

  testWidgets('every slot draws the filled icon, in both copies', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
    expect(find.byIcon(Icons.home), findsNWidgets(2));
  });

  testWidgets('colours: normal = tabForeground, tinted = primary w600', (
    tester,
  ) async {
    await _pump(tester);
    Color? iconColor(Key copy) => IconTheme.of(
      tester.element(
        find.descendant(of: find.byKey(copy), matching: find.byIcon(Icons.home)),
      ),
    ).color;
    expect(iconColor(kTabNormalKey), const Color(0xFF191919));
    expect(iconColor(kTabTintedKey), _scheme.primary);
    final tinted = tester.widget<Text>(
      find.descendant(of: find.byKey(kTabTintedKey), matching: find.text('Home')),
    );
    expect(tinted.style!.fontWeight, FontWeight.w600);
    expect(tinted.style!.fontSize, 10);
    expect(tinted.style!.letterSpacing, 0);
  });

  testWidgets('the tinted copy is clipped to the lens, the normal copy '
      'outside it', (tester) async {
    await _pump(tester, selected: 1);
    final size = tester.getSize(find.byKey(kTabNormalKey));
    final inside = tester
        .widget<ClipPath>(find.byKey(kTabTintedKey))
        .clipper!
        .getClip(size)
        .getBounds();
    // Pill-local slot 1: x 4 + 86 = 90, y 4, 94 × 54.
    expect(inside, const Rect.fromLTWH(90, 4, 94, 54));
    final outside = tester
        .widget<ClipPath>(find.byKey(kTabNormalKey))
        .clipper!
        .getClip(size);
    expect(outside.contains(const Offset(137, 31)), isFalse);
    expect(outside.contains(const Offset(40, 31)), isTrue);
  });

  testWidgets('no ink anywhere in the bar', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('badge at the icon frame trailing top, 4 in and 4 up', (
    tester,
  ) async {
    await _pump(tester);
    final frame = tabIconFrame(const Rect.fromLTWH(90, 4, 94, 54));
    expect(
      tester.getTopLeft(find.byType(LiquidBadgeView)),
      Offset(64 + frame.right - 4, _top + frame.top - 4),
    );
    expect(tester.getSize(find.byType(LiquidBadgeView)).height, 21.33);
  });

  testWidgets('the margins and the gaps pass touches to the body', (
    tester,
  ) async {
    var body = 0;
    await _pump(tester, onBody: () => body++);
    await tester.tapAt(const Offset(40, _top + 31));
    expect(body, 1);
  });

  testWidgets('a tap selects the full-list index', (tester) async {
    final taps = <int>[];
    await _pump(tester, onSelect: taps.add);
    await tester.tapAt(const Offset(287, _top + 31));
    await tester.pumpAndSettle();
    expect(taps, [2]);
  });

  testWidgets('trailing: pill pinned start, 62 circle at the end', (
    tester,
  ) async {
    await _pump(
      tester,
      trailing: LiquidTabAction(
        icon: const Icon(Icons.edit),
        semanticLabel: 'Compose',
        onPressed: () {},
      ),
    );
    expect(
      tester.getRect(find.byKey(kTabPillKey)),
      const Rect.fromLTWH(21, _top, 274, 62),
    );
    expect(
      tester.getRect(find.byKey(kTabTrailingKey)),
      const Rect.fromLTWH(319, _top, 62, 62),
    );
  });

  testWidgets('RTL: slot 0 on the right', (tester) async {
    await _pump(tester, direction: TextDirection.rtl);
    expect(
      _slot(tester, 'Home').left,
      greaterThan(_slot(tester, 'Settings').left),
    );
  });

  testWidgets('minimized: a 48 circle at x 28 with one node', (tester) async {
    var expanded = 0;
    await _pump(tester, minimized: true, onExpand: () => expanded++);
    expect(
      tester.getRect(find.byKey(kTabPillKey)),
      const Rect.fromLTWH(28, _top + 7, 48, 48),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.button == true,
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(52, _top + 31));
    expect(expanded, 1);
    // The old pill area passes touches through.
    await tester.tapAt(const Offset(200, _top + 31));
    expect(expanded, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/widget/glass_tab_bar_test.dart`
Expected: FAIL, because `glass_tab_bar.dart` does not exist.

- [ ] **Step 3: Implement `GlassTabBar`**

```dart
// liquid_shell/lib/src/chrome/glass_tab_bar.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:liquid_shell/src/chrome/fit_label.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/tab_bar.dart' show LiquidActionCircle;
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// The pill glass (tests).
const kTabPillKey = ValueKey<String>('liquid-tab-pill');

/// The normal copy's clip (tests).
const kTabNormalKey = ValueKey<String>('liquid-tab-normal');

/// The tinted copy's clip (tests).
const kTabTintedKey = ValueKey<String>('liquid-tab-tinted');

/// The trailing circle (tests).
const kTabTrailingKey = ValueKey<String>('liquid-tab-trailing');

const _capsule = BorderRadius.all(Radius.circular(999));

/// Rewrites every frame before it is painted: goldens of the engaged lens
/// (spec VK-503 §17.3). Reset it to null after use.
@visibleForTesting
LensFrame Function(LensFrame frame)? debugTabLensOverride;

/// The Flutter tab bar of spec VK-503. Internal: `LiquidTabBar` and the
/// shell build it. It fills the width it is given (the row between the
/// margins) and places its pill per spec §5; gaps pass touches through.
class GlassTabBar extends StatefulWidget {
  /// Creates the bar.
  const GlassTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.trailing,
    this.minimized = false,
    this.onCollapsedTap,
    this.announceExpand = true,
    this.collapsedKey,
    this.strings = const LiquidShellStrings(),
    this.narrow = false,
    super.key,
  });

  /// All destinations; only `everywhere` ones get a slot.
  final List<LiquidDestination> destinations;

  /// Index into [destinations]; a hidden one highlights nothing.
  final int selectedIndex;

  /// Called on commit with an index into [destinations].
  final ValueChanged<int> onSelect;

  /// The trailing circle's action.
  final LiquidTabAction? trailing;

  /// Collapsed to the 48 pt circle (spec §10).
  final bool minimized;

  /// Tap on the collapsed circle; null makes it inert.
  final VoidCallback? onCollapsedTap;

  /// Whether a collapsed tap announces `tabBarExpanded` and the node
  /// carries the expand hint (false for the search collapse, spec §11).
  final bool announceExpand;

  /// Key of the collapsed circle's node (`kSearchCollapsedKey`, spec §11).
  final Key? collapsedKey;

  /// Strings for hints, announcements and badges.
  final LiquidShellStrings strings;

  /// Narrow labels fit themselves (P1 Q18).
  final bool narrow;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar> {
  LensMotion? _motion;

  List<int> get _shown => [
    for (final (i, d) in widget.destinations.indexed)
      if (d.placement == LiquidPlacement.everywhere) i,
  ];

  int? _slotOf(int index) {
    final s = _shown.indexOf(index);
    return s < 0 ? null : s;
  }

  /// 0 = full bar, 1 = minimized circle. Task 9 animates it.
  double get _morph => widget.minimized ? 1 : 0;

  LensMotion _sync(TabBarGeometry g) {
    final selected = _slotOf(widget.selectedIndex);
    final m = _motion ??= LensMotion(geometry: g, selected: selected);
    m
      ..reduceMotion = MediaQuery.disableAnimationsOf(context)
      ..geometry = g;
    if (m.pending != null) {
      if (selected == m.pending) m.accept();
    } else if (selected != m.committed && !m.interacting) {
      m.show(selected);
    }
    return m;
  }

  void _select(int slot) => widget.onSelect(_shown[slot]);

  void _collapsedTap() {
    final tap = widget.onCollapsedTap;
    if (tap == null) return;
    tap();
    if (!widget.announceExpand) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.strings.tabBarExpanded,
        Directionality.of(context),
      ),
    );
  }

  TabBarGeometry _geometryFor(
    double maxWidth,
    TextDirection direction,
    double extent,
  ) => compactTabGeometry(
    count: _shown.length,
    maxWidth: maxWidth,
    trailing: widget.trailing != null,
    direction: direction,
    extent: extent,
  );

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final theme = LiquidGlassTheme.of(context);
    final ax = isAxTextScale(context);
    final style = theme.labelStyle;
    final lineHeight = ax
        ? TabMetrics.labelHeight
        : MediaQuery.textScalerOf(context).scale(style.fontSize ?? 10) *
              (style.height ?? 1.2);
    final extent =
        TabMetrics.pillExtent +
        math.max(0.0, lineHeight - TabMetrics.labelHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final g = _geometryFor(constraints.maxWidth, direction, extent);
        final motion = _sync(g);
        final override = debugTabLensOverride;
        final frame = override == null ? motion.frame : override(motion.frame);
        return Material(
          type: MaterialType.transparency,
          child: SizedBox.fromSize(
            size: g.size,
            child: _layers(context, g, frame, theme, lineHeight, ax),
          ),
        );
      },
    );
  }

  static Rect _scaleAbout(Rect r, double s) => Rect.fromCenter(
    center: r.center,
    width: r.width * s,
    height: r.height * s,
  );

  Widget _layers(
    BuildContext context,
    TabBarGeometry g,
    LensFrame frame,
    LiquidGlassTheme theme,
    double lineHeight,
    bool ax,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final direction = Directionality.of(context);
    final morph = _morph.clamp(0.0, 1.0);
    final fade = 1 - (morph / 0.4).clamp(0.0, 1.0);
    final dip = 1 - TabSprings.dip * math.sin(math.pi * morph);
    final glass = _scaleAbout(
      Rect.lerp(g.pill, g.minimized, morph)!,
      frame.pillScale * dip,
    );
    final origin = g.pill.topLeft;
    final slots = [for (final s in g.slots) s.shift(-origin)];
    final lens = frame.lens.shift(-origin);
    final shown = [for (final i in _shown) widget.destinations[i]];
    final selectedSlot = _slotOf(widget.selectedIndex);
    final collapsedSlot = selectedSlot ?? 0;
    final restOpacity = frame.visible
        ? frame.restOpacity * (1 - frame.engage)
        : 0.0;

    Widget cells({required bool tinted}) => _Cells(
      destinations: shown,
      slots: slots,
      color: tinted ? scheme.primary : theme.tabForeground,
      weight: tinted ? FontWeight.w600 : theme.labelStyle.fontWeight,
      lineHeight: lineHeight,
      ax: ax,
      narrow: widget.narrow,
      popSlot: tinted ? frame.popSlot : null,
      popScale: frame.popScale,
    );

    final children = <Widget>[
      // 1. The pill glass, alone: the content is not squashed by the morph.
      Positioned.fromRect(
        rect: glass,
        child: LiquidGlass(
          key: kTabPillKey,
          borderRadius: _capsule,
          child: const SizedBox.expand(),
        ),
      ),
      // 2. Content at the full pill rect, scaled with the pill, faded by
      //    the morph. Never takes touches.
      Positioned.fromRect(
        rect: g.pill,
        child: IgnorePointer(
          child: Transform.scale(
            scale: frame.pillScale * dip,
            child: Opacity(
              opacity: fade,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PillPainter(
                        lens: lens,
                        fill: theme.selectionFill,
                        fillOpacity: restOpacity,
                        ghost: frame.ghost?.shift(-origin),
                        ghostOpacity: frame.ghostOpacity,
                        highlight: frame.highlight * (dark ? 0.25 : 0.85),
                        glowCenter: frame.glowCenter?.translate(
                          -origin.dx,
                          -origin.dy,
                        ),
                        glowDiameter: frame.glowDiameter,
                        glowOpacity: frame.glowOpacity,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipPath(
                      key: kTabNormalKey,
                      clipper: _LensClip(frame.visible ? lens : Rect.zero,
                          inside: false),
                      child: cells(tinted: false),
                    ),
                  ),
                  // Task 8 inserts the engaged LiquidLens here.
                  Positioned.fill(
                    child: ClipPath(
                      key: kTabTintedKey,
                      clipper: _LensClip(frame.visible ? lens : Rect.zero,
                          inside: true),
                      child: Transform(
                        alignment: Alignment.topLeft,
                        transform: Matrix4.identity()
                          ..translateByDouble(lens.center.dx, lens.center.dy, 0, 1)
                          ..scaleByDouble(frame.magnify, frame.magnify, 1, 1)
                          ..translateByDouble(
                            -lens.center.dx,
                            -lens.center.dy,
                            0,
                            1,
                          ),
                        child: cells(tinted: true),
                      ),
                    ),
                  ),
                  _Badges(
                    destinations: shown,
                    slots: slots,
                    width: g.pill.width,
                    direction: direction,
                    ax: ax,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // 3. The collapsed icon moving into the circle.
      if (morph > 0 && shown.isNotEmpty)
        Positioned.fromRect(
          rect: Rect.lerp(
            tabIconFrame(g.slots[collapsedSlot]),
            Rect.fromCenter(
              center: g.minimized.center,
              width: TabMetrics.iconFrame.width,
              height: TabMetrics.iconFrame.height,
            ),
            morph,
          )!,
          child: IgnorePointer(
            child: Opacity(
              opacity: (morph / 0.4).clamp(0.0, 1.0),
              child: _CollapsedIcon(
                destination: shown[collapsedSlot],
                color: selectedSlot == null
                    ? theme.tabForeground
                    : scheme.primary,
              ),
            ),
          ),
        ),
      // 4. The trailing circle.
      if (widget.trailing case final action?)
        Positioned.fromRect(
          key: kTabTrailingKey,
          rect: Rect.lerp(g.trailing, g.minimizedTrailing, morph)!,
          child: LiquidActionCircle(action: action),
        ),
      // 5. Touches and semantics.
      if (morph < 0.5)
        Positioned.fromRect(
          rect: g.pill,
          child: Stack(
            children: [
              for (final (s, d) in shown.indexed)
                Positioned.fromRect(
                  rect: slots[s],
                  child: _slotNode(s, d, ax),
                ),
            ],
          ),
        )
      else if (shown.isNotEmpty)
        Positioned.fromRect(
          rect: glass,
          child: _collapsedNode(shown[collapsedSlot]),
        ),
    ];
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _slotNode(int slot, LiquidDestination d, bool ax) => Semantics(
    container: true,
    button: true,
    selected: _shown[slot] == widget.selectedIndex,
    label: badgeSemanticsLabel(d.label, d.badge, widget.strings),
    onTap: () => _select(slot),
    excludeSemantics: true,
    child: LargeContentViewer(
      icon: d.selectedIcon ?? d.icon,
      label: d.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(slot),
        child: const SizedBox.expand(),
      ),
    ),
  );

  Widget _collapsedNode(LiquidDestination d) {
    final expandable = widget.onCollapsedTap != null;
    // The key sits above the node, so finders can look for the label
    // inside it (P3b tests: `descendant(of: kSearchCollapsedKey, …)`).
    return KeyedSubtree(
      key: widget.collapsedKey,
      child: Semantics(
      container: true,
      button: true,
      label: badgeSemanticsLabel(d.label, d.badge, widget.strings),
      hint: expandable && widget.announceExpand
          ? widget.strings.expandTabBarHint
          : null,
      onTap: expandable ? _collapsedTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _collapsedTap,
        child: const SizedBox.expand(),
      ),
      ),
    );
  }
}

/// One copy of the row: icon and label per slot, pill-local.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.destinations,
    required this.slots,
    required this.color,
    required this.weight,
    required this.lineHeight,
    required this.ax,
    required this.narrow,
    this.popSlot,
    this.popScale = 1,
  });

  final List<LiquidDestination> destinations;
  final List<Rect> slots;
  final Color color;
  final FontWeight? weight;
  final double lineHeight;
  final bool ax;
  final bool narrow;
  final int? popSlot;
  final double popScale;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    final iconSize = ax
        ? axIconSize(context, theme.tabIconSize)
        : theme.tabIconSize;
    final style = theme.labelStyle.copyWith(color: color, fontWeight: weight);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (s, d) in destinations.indexed)
          Positioned.fromRect(
            rect: slots[s],
            child: Transform.scale(
              scale: s == popSlot ? popScale : 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(
                    rect: (ax ? slots[s] : tabIconFrame(slots[s])).shift(
                      -slots[s].topLeft,
                    ),
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(size: iconSize, color: color),
                        child: d.selectedIcon ?? d.icon,
                      ),
                    ),
                  ),
                  if (!ax)
                    Positioned.fromRect(
                      rect: tabLabelBox(
                        slots[s],
                        lineHeight,
                      ).shift(-slots[s].topLeft),
                      child: Center(
                        child: narrow
                            ? FitLabel(d.label, style: style)
                            : Text(
                                d.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: style,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Badges above both copies, never clipped or magnified.
class _Badges extends StatelessWidget {
  const _Badges({
    required this.destinations,
    required this.slots,
    required this.width,
    required this.direction,
    required this.ax,
  });

  final List<LiquidDestination> destinations;
  final List<Rect> slots;
  final double width;
  final TextDirection direction;
  final bool ax;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final (s, d) in destinations.indexed)
        if (badgeVisible(d.badge))
          () {
            final frame = ax ? slots[s].deflate(8) : tabIconFrame(slots[s]);
            final rtl = direction == TextDirection.rtl;
            return Positioned(
              left: rtl ? null : frame.right - TabMetrics.badgeOutset,
              right: rtl ? width - (frame.left + TabMetrics.badgeOutset) : null,
              top: frame.top - TabMetrics.badgeOutset,
              child: LiquidBadgeView(badge: d.badge!),
            );
          }(),
    ],
  );
}

class _CollapsedIcon extends StatelessWidget {
  const _CollapsedIcon({required this.destination, required this.color});

  final LiquidDestination destination;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: IconTheme.merge(
            data: IconThemeData(size: theme.tabIconSize, color: color),
            child: destination.selectedIcon ?? destination.icon,
          ),
        ),
        if (badgeVisible(destination.badge))
          PositionedDirectional(
            end: -TabMetrics.badgeOutset * 2,
            top: -TabMetrics.badgeOutset,
            child: LiquidBadgeView(badge: destination.badge!),
          ),
      ],
    );
  }
}

/// Inside or outside the lens capsule, pill-local.
class _LensClip extends CustomClipper<Path> {
  const _LensClip(this.lens, {required this.inside});

  final Rect lens;
  final bool inside;

  @override
  Path getClip(Size size) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(lens, Radius.circular(lens.shortestSide / 2)),
      );
    if (inside) return capsule;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(64)),
      capsule,
    );
  }

  @override
  bool shouldReclip(_LensClip oldClipper) =>
      oldClipper.lens != lens || oldClipper.inside != inside;
}

/// Highlight, rest fill (and the reduce-motion ghost), and the finger glow,
/// all pill-local and clipped to the pill capsule.
class _PillPainter extends CustomPainter {
  const _PillPainter({
    required this.lens,
    required this.fill,
    required this.fillOpacity,
    required this.ghost,
    required this.ghostOpacity,
    required this.highlight,
    required this.glowCenter,
    required this.glowDiameter,
    required this.glowOpacity,
  });

  final Rect lens;
  final Color fill;
  final double fillOpacity;
  final Rect? ghost;
  final double ghostOpacity;
  final double highlight;
  final Offset? glowCenter;
  final double glowDiameter;
  final double glowOpacity;

  static RRect _capsule(Rect r) =>
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2));

  @override
  void paint(Canvas canvas, Size size) {
    final pill = _capsule(Offset.zero & size);
    if (highlight > 0) {
      canvas.drawRRect(
        pill,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: highlight),
      );
    }
    final ghost = this.ghost;
    if (ghost != null && ghostOpacity > 0) {
      canvas.drawRRect(
        _capsule(ghost),
        Paint()..color = fill.withValues(alpha: fill.a * ghostOpacity),
      );
    }
    if (fillOpacity > 0) {
      canvas.drawRRect(
        _capsule(lens),
        Paint()..color = fill.withValues(alpha: fill.a * fillOpacity),
      );
    }
    final glow = glowCenter;
    if (glow != null && glowOpacity > 0 && glowDiameter > 0) {
      final circle = Rect.fromCircle(center: glow, radius: glowDiameter / 2);
      canvas
        ..save()
        ..clipRRect(pill)
        ..drawCircle(
          glow,
          glowDiameter / 2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: glowOpacity),
                const Color(0x00FFFFFF),
              ],
            ).createShader(circle),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.lens != lens ||
      old.fill != fill ||
      old.fillOpacity != fillOpacity ||
      old.ghost != ghost ||
      old.ghostOpacity != ghostOpacity ||
      old.highlight != highlight ||
      old.glowCenter != glowCenter ||
      old.glowDiameter != glowDiameter ||
      old.glowOpacity != glowOpacity;
}
```

> `tab_bar.dart` imports `glass_tab_bar.dart` and `glass_tab_bar.dart` imports `LiquidActionCircle` from `tab_bar.dart`. Dart allows this import cycle between libraries of one package.

In `liquid_shell/lib/src/chrome/tab_bar.dart`:

1. Rename the current `LiquidTabBar.build` body into a private `class _TopBar extends StatelessWidget`. It takes the same fields and keeps the existing code unchanged, including `_Cell` and `_BadgedIcon`. Task 11 replaces it.
2. Make `LiquidTabBar.build`:

```dart
  @override
  Widget build(BuildContext context) {
    assert(
      debugCheckHasDirectionality(context),
      'LiquidTabBar needs a Directionality ancestor.',
    );
    assert(
      debugCheckHasOverlay(context),
      'LiquidTabBar needs an Overlay ancestor.',
    );
    if (position == LiquidTabBarPosition.top) return _TopBar(bar: this);
    return GlassTabBar(
      destinations: destinations,
      selectedIndex: selectedIndex,
      onSelect: onDestinationSelected,
      trailing: trailing,
      minimized: minimized,
      onCollapsedTap: onExpand,
      strings: strings,
      narrow:
          narrow ?? MediaQuery.sizeOf(context).width < kLiquidNarrowWidth,
    );
  }
```

with `_TopBar({required this.bar})` reading `bar.destinations` and the other fields.

3. Update the `LiquidTabBar` class doc. The bottom bar now fills the width it is given and places a native-sized pill (spec VK-503 §5). Selection commits on release. Every slot draws `selectedIcon ?? icon`.

In `liquid_shell/lib/src/destinations/badge.dart`, give `LiquidBadgeView` the native metrics (spec §5.1) and the theme colour:

```dart
  @override
  Widget build(BuildContext context) {
    if (!badgeVisible(badge)) return const SizedBox.shrink();
    final color = LiquidGlassTheme.of(context).badgeColor;
    const extent = 21.33;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(extent / 2)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: extent,
            minHeight: extent,
            maxHeight: extent,
          ),
          child: switch (badge) {
            LiquidDotBadge() => const SizedBox(width: extent, height: extent),
            final LiquidCountBadge count => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  badgeText(count),
                  style: const TextStyle(
                    fontSize: 12,
                    height: extent / 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
```

Add `import 'package:liquid_shell/src/glass/glass_theme.dart';`. Update the class doc: "a red capsule 21.33 tall, 12/w500 white text; a dot is the empty capsule (as native draws an empty badge)".

- [ ] **Step 4: Run the new test, then fix the old ones**

Run: `cd liquid_shell && fvm flutter test test/widget/glass_tab_bar_test.dart`
Expected: PASS.

Then run `fvm flutter test test/widget/tab_bar_test.dart test/widget/badge_view_test.dart test/widget/shell_chrome_test.dart`. Update exactly these tests. Any other failure is a regression to fix in code.

**`tab_bar_test.dart`:**
- **Delete** these tests. The spec replaced their behaviour, and `glass_tab_bar_test.dart` covers the replacement:
  - `selected cell: primary on a primaryContainer chip`;
  - `AnimatedSize is removed under disableAnimations`;
  - `expanding animates the glass itself, so its rounded shape and …` (Task 9 tests the morph);
  - `a bottom cell is at most 88 wide`;
  - the group `narrow pill padding (Q17)`, because the pill inset is the fixed native 4.
- **Rewrite** `the selected cell draws selectedIcon, the others icon` as:

```dart
  testWidgets('every bottom slot draws selectedIcon ?? icon (spec VK-503 '
      '§6.1)', (tester) async {
    const destinations = [
      LiquidDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      LiquidDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
    ];
    await tester.pumpWidget(_host(destinations: destinations));
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.home), findsWidgets);
    expect(find.byIcon(Icons.inbox_outlined), findsWidgets);
  });
```

**`badge_view_test.dart`:** change the size expectations to height `21.33`, min width `21.33`, and the colour to `LiquidGlassTheme.fromColorScheme(scheme).badgeColor`. Change the count text style to 12 / w500 / white. The dot is a 21.33 square capsule.

**`shell_chrome_test.dart`, group "narrow (Q17)":**
- In the 320 test, the slots are now `(320 − 2×8 − 62 − 8 − 16) / 5 = 43.6` pitch. Each hit capsule is `43.6 + 8 = 51.6` wide, which is still ≥ 44 because native hit capsules overlap. Replace the cell-width assertion with:

```dart
      // Native slots (spec VK-503 §5.1): pitch 43.6, hit capsule 51.6.
      final home = tester.getRect(find.byWidgetPredicate(
        (w) => w is Semantics &&
            (w.properties.label?.startsWith('Home') ?? false),
      ));
      expect(home.width, closeTo(51.6, 0.01));
      expect(home.width, greaterThanOrEqualTo(44));
```

- In the 375 and 340 tests, keep the row and circle margin assertions: the shell margin changes in Task 10, not here. Replace their pill-padding and cell-width assertions with the same `home.width` check:
  - at 375: `(375 − 32 − 70 − 16)/5 + 8 = 59.4`;
  - at 340: `(340 − 32 − 70 − 16)/5 + 8 = 52.4`.

Run `make test` until it is green.

- [ ] **Step 5: Regenerate goldens, review, commit**

```bash
make goldens-update
```

Check `case_basic.png`, `case_badges.png`, `case_trailing.png`, `hero_iphone_light.png` and `liquid_*basic*`. Each should show:
- a 274-wide pill with a gray capsule behind the selected slot;
- filled icons;
- the selected slot's icon and label in primary;
- red 21 pt badges.

```bash
fvm dart format liquid_shell/lib/src/chrome liquid_shell/lib/src/destinations liquid_shell/test
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/glass_tab_bar.dart liquid_shell/lib/src/chrome/tab_bar.dart liquid_shell/lib/src/destinations/badge.dart liquid_shell/test liquid_shell/example/test/goldens liquid_shell/doc/images
git commit -m "feat(shell): GlassTabBar at rest with native slots, mask and filled icons (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 7: Gestures, the ticker, commit on release, guard, haptics

**Files:**
- Create: `liquid_shell/lib/src/chrome/lens_gesture.dart`
- Modify: `liquid_shell/lib/src/chrome/glass_tab_bar.dart`
- Test: `liquid_shell/test/widget/tab_gesture_test.dart`

**Interfaces:**
- Consumes:
  - Task 3: `LensMotion.down/move/up/cancel/tapSlot/returnTo/advance/takeCrossings/pending/committed`;
  - Task 6: `GlassTabBar`, `_slotNode`, `_layers`.
- Produces:
  - `class LensGestureRecognizer extends OneSequenceGestureRecognizer`, with `eager` and the callbacks `onDown(Offset)`, `onMove(Offset)`, `onUp(Offset, double velocityX)` and `onCancel()`. All positions are local to the detector;
  - `_GlassTabBarState` with a `Ticker`, `_kick()`, `_onTick(Duration)` and the handlers `_down/_move/_up/_cancel`. `_select(int slot)` now animates.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/widget/tab_gesture_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _screen = Size(402, 874);
const _y = 874.0 - 21 - 31;
const _home = Offset(115, _y);
const _explore = Offset(201, _y);
const _settings = Offset(287, _y);

const _three = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

/// Owns the selection like an app; [adopt] false ignores every call (a
/// guard that says no).
class _Harness extends StatefulWidget {
  const _Harness({required this.log, this.adopt = true, this.textScale = 1});
  final List<int> log;
  final bool adopt;
  final double textScale;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;
  void select(int i) => setState(() => index = i);
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(widget.textScale),
    ),
    child: Stack(
      children: [
        Positioned(
          left: TabMetrics.margin,
          right: TabMetrics.margin,
          bottom: 21,
          child: LiquidTabBar(
            destinations: _three,
            selectedIndex: index,
            onDestinationSelected: (i) {
              widget.log.add(i);
              if (widget.adopt) setState(() => index = i);
            },
          ),
        ),
      ],
    ),
  );
}

Future<GlobalKey<_HarnessState>> _pump(
  WidgetTester tester,
  List<int> log, {
  bool adopt = true,
  double textScale = 1,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Harness(key: key, log: log, adopt: adopt, textScale: textScale),
      ),
    ),
  );
  return key;
}

/// The tinted clip's bounds (the lens), pill-local.
Rect _lens(WidgetTester tester) => tester
    .widget<ClipPath>(find.byKey(kTabTintedKey))
    .clipper!
    .getClip(tester.getSize(find.byKey(kTabTintedKey)))
    .getBounds();

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  testWidgets('a tap commits on up, not on down, without haptics', (
    tester,
  ) async {
    final log = <int>[];
    final haptics = _haptics(tester);
    await _pump(tester, log);
    final g = await tester.startGesture(_settings);
    await tester.pump(const Duration(milliseconds: 50));
    expect(log, isEmpty);
    await g.up();
    await tester.pump();
    expect(log, [2]);
    await tester.pumpAndSettle();
    expect(_lens(tester).center.dx, closeTo(266, 0.5));
    expect(haptics, isEmpty);
  });

  testWidgets('a slow drag commits the nearest slot on release, one click '
      'per crossing', (tester) async {
    final log = <int>[];
    final haptics = _haptics(tester);
    await _pump(tester, log);
    final g = await tester.startGesture(_home);
    for (var x = _home.dx; x < _settings.dx; x += 3) {
      await g.moveTo(Offset(x, _y));
      await tester.pump(const Duration(milliseconds: 16));
      expect(log, isEmpty, reason: 'moving never selects');
    }
    await g.moveTo(_settings);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  testWidgets('a cancelled touch commits nothing and returns', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final g = await tester.startGesture(_home);
    await g.moveTo(_settings);
    await tester.pump(const Duration(milliseconds: 300));
    await g.cancel();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_lens(tester).center.dx, closeTo(94, 0.5));
  });

  testWidgets('a rejected commit snaps back after the motion settles', (
    tester,
  ) async {
    final log = <int>[];
    await _pump(tester, log, adopt: false);
    await tester.tapAt(_settings);
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(_lens(tester).center.dx, closeTo(94, 0.5));
  });

  testWidgets('a programmatic change jumps in one frame', (tester) async {
    final key = await _pump(tester, <int>[]);
    key.currentState!.select(2);
    await tester.pump();
    expect(_lens(tester).center.dx, closeTo(266, 0.01));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a semantics tap animates and commits', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    tester
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Explore',
          ),
        )
        .properties
        .onTap!();
    await tester.pump();
    expect(log, [1]);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(_lens(tester).center.dx, closeTo(180, 0.5));
  });

  testWidgets('AX text: a long press shows the large content card; a drag '
      'still commits', (tester) async {
    final log = <int>[];
    await _pump(tester, log, textScale: 2);
    final g = await tester.startGesture(_explore);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(log, isEmpty, reason: 'lifting after the card does not select');
    final drag = await tester.startGesture(_home);
    await drag.moveTo(_settings);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(log, [2]);
  });

  testWidgets('the ticker stops at rest', (tester) async {
    await _pump(tester, <int>[]);
    await tester.tapAt(_explore);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/widget/tab_gesture_test.dart`
Expected: FAIL. With Task 6's per-slot `GestureDetector`:
- `a tap commits on up, not on down` passes;
- the drag test fails with `Expected: [2] Actual: []`;
- the AX test fails because the drag does not commit;
- the haptics list is empty.

- [ ] **Step 3: Implement**

```dart
// liquid_shell/lib/src/chrome/lens_gesture.dart
import 'package:flutter/gestures.dart';

/// The tab lens's one-finger recognizer (spec VK-503 §8.6). Eager: it
/// wins the arena on pointer down, so the lens engages at touch-down.
/// Not eager (AX text sizes): it wins on a move beyond the touch slop or
/// on pointer up, so the large content viewer's long press can win first.
class LensGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Creates the recognizer.
  LensGestureRecognizer({super.debugOwner, this.eager = true});

  /// Accept on pointer down.
  bool eager;

  /// Finger down, local to the detector.
  void Function(Offset local)? onDown;

  /// Finger moved.
  void Function(Offset local)? onMove;

  /// Finger up with its horizontal velocity (pt/s).
  void Function(Offset local, double velocityX)? onUp;

  /// The touch was lost (arena, cancel).
  VoidCallback? onCancel;

  int? _pointer;
  Offset _downGlobal = Offset.zero;
  bool _accepted = false;
  VelocityTracker? _tracker;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _downGlobal = event.position;
    _accepted = false;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    if (eager) resolve(GestureDisposition.accepted);
    invokeCallback<void>('onDown', () => onDown?.call(event.localPosition));
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _tracker?.addPosition(event.timeStamp, event.localPosition);
    if (event is PointerMoveEvent) {
      if (!_accepted && (event.position - _downGlobal).distance > kTouchSlop) {
        resolve(GestureDisposition.accepted);
      }
      invokeCallback<void>('onMove', () => onMove?.call(event.localPosition));
    } else if (event is PointerUpEvent) {
      if (!_accepted) resolve(GestureDisposition.accepted);
      final v = _tracker?.getVelocity().pixelsPerSecond.dx ?? 0;
      invokeCallback<void>('onUp', () => onUp?.call(event.localPosition, v));
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      invokeCallback<void>('onCancel', () => onCancel?.call());
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) => _accepted = true;

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    invokeCallback<void>('onCancel', () => onCancel?.call());
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _tracker = null;
    _accepted = false;
  }

  @override
  String get debugDescription => 'liquid tab lens';
}
```

In `glass_tab_bar.dart`:

(a) Add imports: `package:flutter/scheduler.dart`, `package:flutter/services.dart`, `package:liquid_shell/src/chrome/lens_gesture.dart`.

(b) Make the state `with SingleTickerProviderStateMixin` and add:

```dart
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _kick() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    unawaited(_ticker.start());
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    final m = _motion;
    if (m == null) return;
    var moving = m.advance(dt);
    for (final _ in m.takeCrossings()) {
      // Spec §9 / Q6: one selection click per slot crossing while dragging.
      unawaited(HapticFeedback.selectionClick());
    }
    if (!moving) {
      final selected = _slotOf(widget.selectedIndex);
      if (m.pending != null && m.pending != selected) {
        // The app did not adopt the commit (spec §8.7).
        m.returnTo(selected);
        moving = true;
      } else {
        m.accept();
        _ticker.stop();
      }
    }
    setState(() {});
  }

  void _down(Offset p) {
    _motion?.down(p);
    _kick();
  }

  void _move(Offset p) => _motion?.move(p);

  void _up(Offset p, double velocity) {
    final slot = _motion?.up(p, velocity: velocity);
    _kick();
    if (slot != null) widget.onSelect(_shown[slot]);
  }

  void _cancel() {
    _motion?.cancel();
    _kick();
  }
```

(c) Replace `_select` (used by semantics) with:

```dart
  void _select(int slot) {
    _motion?.tapSlot(slot);
    _kick();
    widget.onSelect(_shown[slot]);
  }
```

(d) In `_slotNode`, drop the `GestureDetector`. The `LargeContentViewer` child becomes `const SizedBox.expand()`, because touches go to the detector below.

(e) In `_layers`, replace the slot-node layer (`if (morph < 0.5) Positioned.fromRect(rect: g.pill, child: Stack(...))`) with:

```dart
      if (morph < 0.5)
        Positioned.fromRect(
          rect: g.pill,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              LensGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<LensGestureRecognizer>(
                    () => LensGestureRecognizer(debugOwner: this),
                    (r) => r
                      ..eager = !ax
                      ..onDown = ((p) => _down(p + g.pill.topLeft))
                      ..onMove = ((p) => _move(p + g.pill.topLeft))
                      ..onUp = ((p, v) => _up(p + g.pill.topLeft, v))
                      ..onCancel = _cancel,
                  ),
            },
            child: Stack(
              children: [
                for (final (s, d) in shown.indexed)
                  Positioned.fromRect(
                    rect: slots[s],
                    child: _slotNode(s, d, ax),
                  ),
              ],
            ),
          ),
        )
```

(f) In `_sync`, kick the ticker when a returned commit or a programmatic change needs animation. `show` jumps, so only `accept` is new: no kick needed there. Leave `_sync` as is.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd liquid_shell
fvm flutter test test/widget/tab_gesture_test.dart test/widget/glass_tab_bar_test.dart test/widget/tab_bar_test.dart
cd .. && make test
```

Expected: PASS. `glass_tab_bar_test`'s `a tap selects the full-list index` still passes, because a tap commits on up.

If a shell or search test taps a tab and expects the selection after a single `pump()`, it still works: the commit happens on pointer up, which `tester.tap` sends. A test that expects **no animation** frames after a tap (`hasScheduledFrame` false right after) is updated to `pumpAndSettle()` first.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell/lib/src/chrome liquid_shell/test/widget/tab_gesture_test.dart
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/lens_gesture.dart liquid_shell/lib/src/chrome/glass_tab_bar.dart liquid_shell/test
git commit -m "feat(shell): tab lens gestures, commit on release, guard return, haptics (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The engaged lens on screen: second pass, bulge, magnify, glow

**Files:**
- Modify: `liquid_shell/lib/src/chrome/glass_tab_bar.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart` (export `debugTabLensPress`)
- Modify: `liquid_shell/example/test/goldens/liquid_test.dart`
- Test: `liquid_shell/test/widget/tab_effects_test.dart` (new)
- Regenerate: the liquid goldens (`make goldens-update`)

**Interfaces:**
- Consumes:
  - Task 5: `LiquidLens`;
  - Task 6: `debugTabLensOverride`;
  - Task 7: the ticker.
- Produces:
  - a `LiquidLens` placed at the lens rect while `engage > 0`, between the normal and tinted copies;
  - the exported `@visibleForTesting double? debugTabLensPress`;
  - the liquid goldens `bands/tab_lens_pressed.png` and `bands/tab_lens_straddle.png`.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/widget/tab_effects_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';

const _screen = Size(402, 874);
const _y = 874.0 - 21 - 31;
const _three = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

Future<void> _pump(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BackdropGroup(
          child: Stack(
            children: [
              Positioned(
                left: TabMetrics.margin,
                right: TabMetrics.margin,
                bottom: 21,
                child: LiquidTabBar(
                  destinations: _three,
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('at rest: no lens pass, one backdrop (the pill)', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(LiquidLens), findsNothing);
    expect(find.byType(LiquidBackdrop), findsOneWidget);
  });

  testWidgets('held: the lens pass engages, the pill bulges ×1.052', (
    tester,
  ) async {
    await _pump(tester);
    final g = await tester.startGesture(const Offset(115, _y));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final lens = tester.widget<LiquidLens>(find.byType(LiquidLens));
    expect(lens.engage, closeTo(1, 0.01));
    expect(lens.refraction, closeTo(1, 0.01));
    expect(find.byType(LiquidBackdrop), findsNWidgets(2));
    final lensRect = tester.getRect(find.byType(LiquidLens));
    expect(lensRect.width, closeTo(110 * 1.052, 3));
    expect(lensRect.height, closeTo(70 * 1.052, 3));
    expect(tester.getRect(find.byKey(kTabPillKey)).width,
        closeTo(274 * 1.052, 0.5));
    // Both lens backdrops share the shell's group key (spec §7.2).
    final keys = tester
        .renderObjectList<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .map((r) => r.backdropKey)
        .toSet();
    expect(keys, hasLength(1));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidLens), findsNothing);
    expect(tester.getRect(find.byKey(kTabPillKey)).width, closeTo(274, 0.01));
  });

  testWidgets('a tap: the lens engages in flight and is gone after 0.85 s', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tapAt(const Offset(201, _y));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LiquidLens), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidLens), findsNothing);
  });

  testWidgets('debugTabLensOverride freezes an engaged frame', (tester) async {
    debugTabLensOverride = (f) => f.copyWith(engage: 1, refraction: 1);
    addTearDown(() => debugTabLensOverride = null);
    await _pump(tester);
    expect(find.byType(LiquidLens), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/widget/tab_effects_test.dart`
Expected: FAIL on `find.byType(LiquidLens)` (found nothing) in the held, tap and override tests.

- [ ] **Step 3: Implement**

In `glass_tab_bar.dart`, import `package:liquid_shell/src/glass/liquid_lens.dart`. In `_layers`, replace the comment `// Task 8 inserts the engaged LiquidLens here.` with:

```dart
                  if (frame.visible && frame.engage > 0.001)
                    Positioned.fromRect(
                      rect: lens,
                      child: Opacity(
                        opacity: frame.engage,
                        child: LiquidLens(
                          engage: frame.engage,
                          refraction: frame.refraction,
                        ),
                      ),
                    ),
```

The pill glass rect already includes `frame.pillScale` (Task 6, `_scaleAbout`). The content transform, the highlight, the glow and the magnify were wired in Task 6 and are driven by the frame since Task 7.

The example's goldens cannot import `src/` (`implementation_imports`). Add a primitive, exported debug hook next to `debugTabLensOverride` in `glass_tab_bar.dart`:

```dart
/// Goldens: when non-null, every tab bar draws its lens pressed (×1.17 /
/// ×1.30, engaged, pill ×1.052, highlight 0.845) and shifted by this many
/// points in x. Reset it to null after use.
@visibleForTesting
double? debugTabLensPress;
```

In `build`, after `debugTabLensOverride` is applied:

```dart
        var shown = override == null ? motion.frame : override(motion.frame);
        final press = debugTabLensPress;
        if (press != null) {
          shown = shown.copyWith(
            engage: 1,
            refraction: 1,
            pillScale: TabSprings.pressScale,
            highlight: TabSprings.highlightPress,
            lens: Rect.fromCenter(
              center: shown.lens.center.translate(press, 0),
              width: shown.lens.width * TabSprings.pressWidthFactor,
              height: shown.lens.height * TabSprings.pressHeightFactor,
            ),
          );
        }
```

Pass `shown` (instead of `frame`) to `_layers`. Export it from `liquid_shell/lib/liquid_shell.dart`, the same way the existing debug override is exported:

```dart
export 'src/chrome/glass_tab_bar.dart' show debugTabLensPress;
```

Add a widget test to `tab_effects_test.dart`:

```dart
  testWidgets('debugTabLensPress draws the pressed lens', (tester) async {
    debugTabLensPress = 0;
    addTearDown(() => debugTabLensPress = null);
    await _pump(tester);
    final lens = tester.getRect(find.byType(LiquidLens));
    expect(lens.width, closeTo(110 * 1.052, 1));
  });
```

Add two band goldens to `liquid_shell/example/test/goldens/liquid_test.dart`, inside `main()` after `case_tier_liquid`. They use the file's `_expectBand` and the harness's `pumpGolden`:

```dart
  for (final (name, shift) in [
    ('tab_lens_pressed', 0.0),
    ('tab_lens_straddle', 43.0),
  ]) {
    testWidgets(name, (tester) async {
      debugTabLensPress = shift;
      addTearDown(() => debugTabLensPress = null);
      await tester.runAsync(LiquidGlass.precache);
      await pumpGolden(tester, const BasicTabsCase());
      await _expectBand(tester, name);
    });
  }
```

- [ ] **Step 4: Run the tests, then the Impeller goldens**

```bash
cd liquid_shell && fvm flutter test test/widget/tab_effects_test.dart && cd ..
make test
make goldens-update
```

Expected: PASS.

Open `bands/tab_lens_pressed.png`. The lens is clear glass, taller than the pill, with a rainbow rim at its top edge, and the Home icon is blue and magnified.

Open `bands/tab_lens_straddle.png`. The Home and Explore icons are each half blue and half dark, as in research `native265_slowdrag.png`.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/glass_tab_bar.dart liquid_shell/lib/liquid_shell.dart liquid_shell/test/widget/tab_effects_test.dart liquid_shell/example/test/goldens
git commit -m "feat(shell): the engaged tab lens as a second glass pass with bulge and magnify (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Trailing drag target and the minimize morph

**Files:**
- Modify: `liquid_shell/lib/src/chrome/lens_motion.dart` (add `MinimizeMotion`)
- Modify: `liquid_shell/lib/src/chrome/glass_tab_bar.dart` (add `TabDragTarget`, `externalTarget`, `reserveTrailing`, `collapseDelay`, the morph and the hover highlight)
- Modify: `liquid_shell/lib/src/chrome/tab_bar.dart` (`LiquidActionCircle`: a press highlight instead of `InkWell`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (no expand on forward scroll; expand on a selection change)
- Test: `liquid_shell/test/unit/lens_motion_test.dart` (add a group), `liquid_shell/test/widget/minimize_test.dart` (new), `test/widget/shell_behaviour_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 6 and 7.
- Produces:
  - `class MinimizeMotion({required bool minimized})`, with `reduceMotion`, `value`, `minimized`, `set(bool, {bool delayed = true})`, `bool advance(double dt)` and `double get dip`;
  - `class TabDragTarget({required Rect Function() rect, required VoidCallback onRelease})`, with `hovered` (`ValueNotifier<bool>`) and `dispose()`;
  - the `GlassTabBar` parameters `externalTarget` (`TabDragTarget?`), `reserveTrailing` (`bool`, default false) and `collapseDelay` (`bool`, default true).

- [ ] **Step 1: Write the failing tests**

Append to `liquid_shell/test/unit/lens_motion_test.dart`:

```dart
  group('minimize (research §6)', () {
    test('collapse waits 0.24 s, then settles on the collapse spring ± 10 %',
        () {
      final m = MinimizeMotion(minimized: false)..set(true);
      final values = <double>[];
      for (var f = 0; f < 120; f++) {
        m.advance(dt);
        values.add(m.value);
      }
      expect(values[(0.2 / dt).floor()], 0);
      final ours = settleTime(values, 1, tolerance: 0.005);
      final reference = settleTime(
        referenceTrace(TabSprings.collapse, 0, 1,
            delay: TabSprings.minimizeDelay),
        1,
        tolerance: 0.005,
      );
      expect(ours, closeTo(reference, reference * 0.10));
    });

    test('the dip reaches ×0.96 at the midpoint', () {
      final m = MinimizeMotion(minimized: false)..set(true, delayed: false);
      var lowest = 1.0;
      for (var f = 0; f < 60; f++) {
        m.advance(dt);
        if (m.dip < lowest) lowest = m.dip;
      }
      expect(lowest, closeTo(0.96, 0.005));
    });

    test('expand overshoots slightly below 0, then rests at 0', () {
      final m = MinimizeMotion(minimized: true)..set(false);
      var lowest = 1.0;
      for (var f = 0; f < 90; f++) {
        m.advance(dt);
        if (m.value < lowest) lowest = m.value;
      }
      expect(lowest, lessThan(0));
      expect(m.value, 0);
      expect(m.advance(dt), isFalse);
    });

    test('a quick reverse during the delay never collapses', () {
      final m = MinimizeMotion(minimized: false)..set(true);
      m
        ..advance(0.1)
        ..set(false);
      for (var f = 0; f < 60; f++) {
        m.advance(dt);
      }
      expect(m.value, 0);
    });

    test('reduce motion: instant', () {
      final m = MinimizeMotion(minimized: false)
        ..reduceMotion = true
        ..set(true);
      expect(m.value, 1);
      expect(m.advance(dt), isFalse);
    });
  });
```

```dart
// liquid_shell/test/widget/minimize_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

const _screen = Size(402, 874);
const _top = 874.0 - 21 - 62;
const _three = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

Future<StateSetter> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  VoidCallback? onTrailing,
  List<int>? log,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  var minimized = false;
  late StateSetter set;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: _screen, disableAnimations: reduceMotion),
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              set = (fn) => setState(() {
                fn();
                minimized = !minimized;
              });
              return Stack(
                children: [
                  Positioned(
                    left: TabMetrics.margin,
                    right: TabMetrics.margin,
                    bottom: 21,
                    child: LiquidTabBar(
                      destinations: _three,
                      selectedIndex: 0,
                      onDestinationSelected: (i) => log?.add(i),
                      minimized: minimized,
                      onExpand: () => setState(() => minimized = false),
                      trailing: LiquidTabAction(
                        icon: const Icon(Icons.edit),
                        semanticLabel: 'Compose',
                        onPressed: onTrailing ?? () {},
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  return set;
}

Rect _pill(WidgetTester tester) => tester.getRect(find.byKey(kTabPillKey));

void main() {
  testWidgets('collapse starts after 240 ms and ends at the 48 circle', (
    tester,
  ) async {
    final toggle = await _pump(tester);
    toggle(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_pill(tester), const Rect.fromLTWH(21, _top, 274, 62));
    await tester.pumpAndSettle();
    expect(_pill(tester), const Rect.fromLTWH(28, _top + 7, 48, 48));
    // The trailing circle shrank about its own centre.
    final trailing = tester.getRect(find.byKey(kTabTrailingKey));
    expect(trailing.size, const Size(48, 48));
    expect(trailing.center, const Offset(350, _top + 31));
  });

  testWidgets('a tap on the circle expands', (tester) async {
    final toggle = await _pump(tester);
    toggle(() {});
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(52, _top + 31));
    await tester.pumpAndSettle();
    expect(_pill(tester), const Rect.fromLTWH(21, _top, 274, 62));
  });

  testWidgets('reduce motion: instant, no delay', (tester) async {
    final toggle = await _pump(tester, reduceMotion: true);
    toggle(() {});
    await tester.pump();
    expect(_pill(tester), const Rect.fromLTWH(28, _top + 7, 48, 48));
  });

  testWidgets('drag onto the trailing circle: hover, release fires it, no '
      'commit', (tester) async {
    var fired = 0;
    final log = <int>[];
    await _pump(tester, onTrailing: () => fired++, log: log);
    final g = await tester.startGesture(const Offset(115, _top + 31));
    await g.moveTo(const Offset(350, _top + 31));
    await tester.pump(const Duration(milliseconds: 100));
    final highlight = tester.widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kTabTrailingKey),
        matching: find.byType(TabHoverHighlight),
      ),
    );
    expect(highlight.hovered.value, isTrue);
    await g.up();
    await tester.pumpAndSettle();
    expect(fired, 1);
    expect(log, isEmpty);
  });
}
```

In `liquid_shell/test/widget/shell_behaviour_test.dart`, replace the test `reverse minimises, forward expands` with:

```dart
    testWidgets('reverse minimises; forward does not expand; a tap does '
        '(spec VK-503 §10, Q7)', (tester) async {
      await pumpShell(tester, const TestShell());
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byKey(kTabPillKey), findsOneWidget);
      expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
      await tester.drag(list, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
      await tester.tap(find.byKey(kTabPillKey));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(kTabPillKey)).height, 62);
    });

    testWidgets('a selection change expands the minimized bar', (
      tester,
    ) async {
      await pumpShell(tester, const TestShell());
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
      tester.state<TestShellState>(find.byType(TestShell)).select(3);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(kTabPillKey)).height, 62);
    });
```

`pumpShell`, `TestShell` and `TestShellState.select` come from `test/helpers/shell_harness.dart`. Add `import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';` to the test.

In `liquid_shell/test/widget/tab_bar_test.dart`, the minimized bar is now icon only (research §6). Rewrite `minimised: only the selected cell, trailing kept` as follows:

```dart
  testWidgets('minimised: the selected icon only, in a 48 circle; trailing '
      'kept (spec VK-503 §10)', (tester) async {
    await tester.pumpWidget(
      _host(
        selectedIndex: 1,
        minimized: true,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.edit),
          semanticLabel: 'Compose',
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Inbox')), findsOneWidget);
    expect(find.bySemanticsLabel('Compose'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd liquid_shell
fvm flutter test test/unit/lens_motion_test.dart test/widget/minimize_test.dart test/widget/shell_behaviour_test.dart
```

Expected: FAIL:
- `MinimizeMotion` is undefined;
- the morph is instant (`collapse starts after 240 ms …` sees the 48 rect at 200 ms);
- `TabHoverHighlight` is missing;
- the forward scroll still expands.

- [ ] **Step 3: Implement**

Append to `lens_motion.dart`:

```dart
/// The minimize morph scalar: 0 = full bar, 1 = circle (spec VK-503 §10).
class MinimizeMotion {
  /// Starts at rest.
  MinimizeMotion({required bool minimized})
    : _target = minimized,
      _value = SpringValue(minimized ? 1 : 0, TabSprings.collapse);

  /// Reduce motion: every change is instant.
  bool reduceMotion = false;

  bool _target;
  final SpringValue _value;
  double _wait = 0;

  /// The morph amount (it overshoots below 0 on expand).
  double get value => _value.value;

  /// The requested state.
  bool get minimized => _target;

  /// Requests [minimized]; a collapse waits [TabSprings.minimizeDelay]
  /// when [delayed].
  void set(bool minimized, {bool delayed = true}) {
    if (minimized == _target) return;
    _target = minimized;
    final end = minimized ? 1.0 : 0.0;
    if (reduceMotion) {
      _wait = 0;
      _value.jump(end);
      return;
    }
    _value.spring = minimized ? TabSprings.collapse : TabSprings.expand;
    _wait = minimized && delayed ? TabSprings.minimizeDelay : 0;
    if (_wait == 0) _value.target = end;
  }

  /// Advances [dt]; true while moving or waiting.
  bool advance(double dt) {
    if (_wait > 0) {
      _wait -= dt;
      if (_wait > 0) return true;
      _value.target = _target ? 1 : 0;
    }
    _value.advance(dt);
    if (_value.settled(0.005)) {
      _value.jump(_value.target);
      return false;
    }
    return true;
  }

  /// The ×0.96 dip at the midpoint.
  double get dip =>
      1 - TabSprings.dip * math.sin(math.pi * value.clamp(0.0, 1.0));
}
```

In `glass_tab_bar.dart`:

(a) Add the target class:

```dart
/// A drop target for the lens drag (spec VK-503 §8.8): the trailing circle
/// or the search ⌕. The lens stays clamped to the pill; a release while
/// [hovered] fires [onRelease] instead of committing a slot.
class TabDragTarget {
  /// Creates a target whose [rect] is bar-local.
  TabDragTarget({required this.rect, required this.onRelease});

  /// Where it is now, bar-local.
  final Rect Function() rect;

  /// Released over it.
  final VoidCallback onRelease;

  /// The finger is over it.
  final ValueNotifier<bool> hovered = ValueNotifier(false);

  /// Releases [hovered].
  void dispose() => hovered.dispose();
}
```

(b) Add three widget parameters:

```dart
  /// A drop target the shell owns (the search ⌕), bar-local.
  final TabDragTarget? externalTarget;

  /// Lay out as if a trailing circle were there (the search ⌕ is drawn by
  /// the shell, spec §11).
  final bool reserveTrailing;

  /// A collapse waits 0.24 s (scroll); false for the search collapse.
  final bool collapseDelay;
```

Defaults: `this.externalTarget`, `this.reserveTrailing = false`, `this.collapseDelay = true`.

(c) In the state:

```dart
  late final MinimizeMotion _minimize = MinimizeMotion(
    minimized: widget.minimized,
  );
  TabBarGeometry? _geometry;
  TabDragTarget? _ownTarget;

  TabDragTarget? get _target => widget.externalTarget ?? _ownTarget;

  @override
  void initState() {
    super.initState();
    _syncOwnTarget();
  }

  void _syncOwnTarget() {
    final action = widget.trailing;
    if (action == null) {
      _ownTarget?.dispose();
      _ownTarget = null;
    } else {
      _ownTarget ??= TabDragTarget(
        rect: () => _geometry?.trailing ?? Rect.zero,
        onRelease: () => widget.trailing?.onPressed(),
      );
    }
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOwnTarget();
    if (oldWidget.minimized != widget.minimized) {
      _minimize
        ..reduceMotion = MediaQuery.disableAnimationsOf(context)
        ..set(widget.minimized, delayed: widget.collapseDelay);
      _kick();
    }
  }
```

Extend `dispose` with `_ownTarget?.dispose();` before `_ticker.dispose()`.

(d) Replace `double get _morph => widget.minimized ? 1 : 0;` with `double get _morph => _minimize.value;`. In `_layers`, use `final morph = _morph;`, which is no longer clamped: the expand overshoot extrapolates the rect. Keep `fade` and `dip` clamped as written, but take the dip from `_minimize.dip`.

(e) In `build`, set `_geometry = g;` after computing it. In `_geometryFor` pass `trailing: widget.trailing != null || widget.reserveTrailing`.

(f) In `_onTick`:
- advance both motions: `var moving = m.advance(dt); if (_minimize.advance(dt)) moving = true;`;
- stop the ticker only when neither moves (the code in Task 7 already stops on `!moving`).

(g) Hover and release:

```dart
  void _move(Offset p) {
    _motion?.move(p);
    final t = _target;
    if (t != null) t.hovered.value = t.rect().inflate(4).contains(p);
  }

  void _up(Offset p, double velocity) {
    final t = _target;
    if (t != null && t.hovered.value) {
      t.hovered.value = false;
      _motion?.cancel();
      _kick();
      t.onRelease();
      return;
    }
    final slot = _motion?.up(p, velocity: velocity);
    _kick();
    if (slot != null) widget.onSelect(_shown[slot]);
  }

  void _cancel() {
    _target?.hovered.value = false;
    _motion?.cancel();
    _kick();
  }
```

(h) Wrap the trailing circle in the hover highlight:

```dart
      if (widget.trailing case final action?)
        Positioned.fromRect(
          key: kTabTrailingKey,
          rect: Rect.lerp(g.trailing, g.minimizedTrailing, morph)!,
          child: TabHoverHighlight(
            hovered: _ownTarget!.hovered,
            child: LiquidActionCircle(action: action),
          ),
        ),
```

with the shared widget (also used by the search ⌕ in Task 10):

```dart
/// The white press/hover overlay on a glass circle (spec §8.8): 0.85 in
/// light, 0.25 in dark.
class TabHoverHighlight extends StatelessWidget {
  /// Creates the overlay over [child].
  const TabHoverHighlight({
    required this.hovered,
    required this.child,
    super.key,
  });

  /// When true, the overlay shows.
  final ValueListenable<bool> hovered;

  /// The circle.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: ValueListenableBuilder<bool>(
            valueListenable: hovered,
            builder: (context, on, _) => AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFFFFF).withValues(
                    alpha: dark ? 0.25 : 0.85,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

(i) Build the content group only while it is visible. In `_layers`, write `if (fade > 0) Positioned.fromRect(rect: g.pill, child: IgnorePointer(...))`, so that a fully minimized bar holds no labels.

In `tab_bar.dart`, make `LiquidActionCircle` a `StatefulWidget`. Its `_pressed` is a `ValueNotifier<bool>`, set by a `GestureDetector` (`onTapDown` true, `onTapUp`/`onTapCancel` false, `onTap: action.onPressed`). It wraps the `LiquidGlass` in `TabHoverHighlight(hovered: _pressed, …)`. Remove the `InkWell`. The icon colour becomes `LiquidGlassTheme.of(context).tabForeground`, at size `LiquidGlassTheme.of(context).tabIconSize`. Keep its `Semantics` and `Tooltip` unchanged.

In `liquid_shell/lib/src/shell/liquid_shell.dart`:
- in `_onScroll`, change `case ScrollDirection.forward: _minimized.value = false;` to `case ScrollDirection.forward: break; // Q7: native stays minimized`;
- in `didUpdateWidget` add `if (oldWidget.selectedIndex != widget.selectedIndex) _minimized.value = false;`. Look up the `selectedIndex` field name of `LiquidShell` in the file and use it.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd liquid_shell
fvm flutter test test/unit/lens_motion_test.dart test/widget/minimize_test.dart test/widget/shell_behaviour_test.dart test/widget/tab_bar_test.dart
cd .. && make test
```

Expected: PASS. The P1 minimise tests in `tab_bar_test.dart` (`minimised: only the selected cell, trailing kept`, `minimised tap expands, keeps the tab and announces`) pass after `pumpAndSettle()`: they assert the end state.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell
bash .githooks/pre-commit
git add liquid_shell/lib liquid_shell/test
git commit -m "feat(shell): minimize morph to the 48 pt circle and drag onto the trailing circle (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The search tab's compact morph on the new bar

**Files:**
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (bottom margin 21; the search row builds `GlassTabBar`)
- Modify: `liquid_shell/lib/src/search/search_chrome.dart` (`CompactSearchChrome` loses its own collapsed circle; `SearchFieldGlass` gets `highlight`)
- Modify: `liquid_shell/lib/src/search/search_layout.dart` (`circle` at `margin + 7`; the selected field after it)
- Test: `liquid_shell/test/widget/search_morph_test.dart` (new), `test/widget/search_fallback_test.dart`, `test/unit/search_test.dart`, `test/widget/shell_chrome_test.dart`

**Interfaces:**
- Consumes:
  - Task 9: `GlassTabBar(externalTarget:, reserveTrailing:, collapseDelay:, collapsedKey:, announceExpand:)`, `TabDragTarget`, `TabHoverHighlight`;
  - Task 1: `TabMetrics.margin`, `TabMetrics.minimizedInset`.
- Produces:
  - `CompactSearchChrome({phase, rects, pill, field, onCancel, strings})`, without `previous`/`onPrevious`;
  - `SearchFieldGlass({…, ValueListenable<bool>? highlight})`;
  - `compactSearchRects(...)`, where `circle.left == margin + 7`.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/widget/search_morph_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/search/search_chrome.dart';

import '../helpers/shell_harness.dart';

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.library_music), label: 'Library'),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

// kPhone is 393 × 852; the row bottom is 852 − 21.
const _rowBottom = 852.0 - 21;

Future<LiquidSearchController> _pump(WidgetTester tester) async {
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      search: LiquidSearch(controller: controller),
    ),
  );
  return controller;
}

void main() {
  testWidgets('idle: pill pinned at 21, ⌕ circle at the end', (tester) async {
    await _pump(tester);
    expect(tester.getRect(find.byKey(kTabPillKey)).left, 21);
    expect(
      tester.getRect(find.byKey(kSearchFieldKey)),
      const Rect.fromLTWH(393 - 21 - 62, _rowBottom - 62, 62, 62),
    );
  });

  testWidgets('selected: the bar itself collapses to the 48 circle at 28',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    final circle = tester.getRect(find.byKey(kSearchCollapsedKey));
    expect(circle, const Rect.fromLTWH(28, _rowBottom - 55, 48, 48));
    expect(tester.getRect(find.byKey(kTabPillKey)), circle);
    expect(
      find.descendant(
        of: find.byKey(kSearchCollapsedKey),
        matching: find.bySemanticsLabel('Home'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(kSearchCollapsedKey));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(kTabPillKey)).height, 62);
  });

  testWidgets('drag from Home onto ⌕: highlight, release selects search', (
    tester,
  ) async {
    await _pump(tester);
    final home = tester.getCenter(find.bySemanticsLabel('Home'));
    final search = tester.getCenter(find.byKey(kSearchFieldKey));
    final g = await tester.startGesture(home);
    await g.moveTo(search);
    await tester.pump(const Duration(milliseconds: 100));
    final highlight = tester.widget<TabHoverHighlight>(
      find.descendant(
        of: find.byKey(kSearchFieldKey),
        matching: find.byType(TabHoverHighlight),
      ),
    );
    expect(highlight.hovered.value, isTrue);
    await g.up();
    await tester.pumpAndSettle();
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
  });
}
```

`pumpShell`, `TestShell(search:)` and `scopeOf` are existing helpers in `test/helpers/shell_harness.dart`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/widget/search_morph_test.dart`
Expected: FAIL:
- the pill left is 16, or centred;
- `kSearchCollapsedKey` is a separate circle, not the bar;
- there is no `TabHoverHighlight` in the ⌕.

- [ ] **Step 3: Implement**

In `search_layout.dart`, `compactSearchRects`, replace the `circle` and `selectedField` definitions:

```dart
  final circle = Rect.fromLTWH(
    margin + TabMetrics.minimizedInset,
    top,
    kSearchCompactExtent,
    kSearchCompactExtent,
  );
  final selectedField = Rect.fromLTRB(
    circle.right + kSearchSelectedGap,
    top,
    width - kSearchSelectedMargin,
    top + kSearchCompactExtent,
  );
```

Import `package:liquid_shell/src/chrome/tab_geometry.dart`. At margin 21 the circle is at 28 and the field at 88, unchanged from P3b.

In `search_chrome.dart`:

(a) Add `this.highlight` to `SearchFieldGlass`:

```dart
  /// Lens drag over the idle ⌕ (spec VK-503 §8.8).
  final ValueListenable<bool>? highlight;
```

In idle, wrap the existing idle `Positioned.fill(child: Semantics(...))` child in `TabHoverHighlight(hovered: highlight ?? const AlwaysStoppedAnimation(false) as ValueListenable<bool>, child: …)`. To avoid the cast, make the field non-null with `this.highlight = const _Off()`, where:

```dart
class _Off implements ValueListenable<bool> {
  const _Off();
  @override
  bool get value => false;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
```

(b) In `CompactSearchChrome`:
- remove the fields `previous` and `onPrevious`;
- remove the `part(kSearchCollapsedKey, …)` child;
- keep the `circle(...)` helper for the × only.

Update its doc to: "the pill (built by the shell, which also collapses into the previous tab's circle, spec VK-503 §11), the field and ×".

In `liquid_shell.dart`:

(a) Add `const double _kBottomBarMargin = TabMetrics.margin;` beside `_kBarMargin`. Use it for the bottom bar: `final barMargin = narrow ? _kNarrowBarMargin : _kBottomBarMargin;`. The top bar keeps `_kBarMargin`.

(b) Add a search drag target to the state:

```dart
  Rect _searchTargetRect = Rect.zero;
  late final TabDragTarget _searchTarget = TabDragTarget(
    rect: () => _searchTargetRect,
    onRelease: _selectSearch,
  );
```

Dispose it in `dispose()` (`_searchTarget.dispose();`).

(c) In the compact search branch, replace the whole `pill: PositionedDirectional(...)` argument with the following, and delete the `previous:` and `onPrevious:` arguments:

```dart
              pill: Positioned(
                left: margin,
                right: margin,
                bottom: bottomGap,
                child: IgnorePointer(
                  ignoring: phase == LiquidSearchPhase.active,
                  child: AnimatedOpacity(
                    opacity: phase == LiquidSearchPhase.active ? 0 : 1,
                    duration: morph,
                    curve: kSearchMorphCurve,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 1,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _minimized,
                        builder: (context, minimized, _) {
                          final scrolled =
                              widget.minimizeOnScroll && minimized && idle;
                          final collapsed = scrolled || !idle;
                          return measured(
                            slot(
                              details(
                                LiquidChromeSlot.tabBar,
                                minimized: collapsed,
                              ),
                              GlassTabBar(
                                destinations: widget.destinations.sublist(
                                  0,
                                  searchIndex,
                                ),
                                selectedIndex: idle ? selected : _previousIndex,
                                onSelect: _onSelect,
                                minimized: collapsed,
                                collapseDelay: idle,
                                onCollapsedTap: idle
                                    ? _expand
                                    : () => _onSelect(_previousIndex),
                                announceExpand: idle,
                                collapsedKey: idle ? null : kSearchCollapsedKey,
                                reserveTrailing: true,
                                externalTarget: idle ? _searchTarget : null,
                                strings: widget.strings,
                                narrow: narrow,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
```

(d) Before `children.add(CompactSearchChrome(...))`, set the bar-local ⌕ rect. The bar's top-left is `(margin, size.height − bottomGap − rowExtent)`:

```dart
          _searchTargetRect = compactRects.field.shift(
            Offset(-margin, -(size.height - bottomGap - rowExtent)),
          );
```

(e) Pass `highlight: _searchTarget.hovered` to `SearchFieldGlass` in `searchField(...)`.

Update the existing tests:

**`test/unit/search_test.dart`, `compactSearchRects` group:**
- change the helper's `margin: 16` to `margin: 21`;
- in `idle: the ⌕ circle at the trailing end of the row`, change every `16` that is the row margin to `21`.

The selected and active expectations do not change (circle 28, field 88..365).

**`test/widget/search_fallback_test.dart`:**
- line with `393 - 16 - 62`: change it to `393 - 21 - 62`;
- in `RTL idle: the pill clears the ⌕ circle on the left`, change `expect(circle.left, 16);` to `expect(circle.left, 21);` and change the pill finder to the glass:

```dart
    final pill = tester.getRect(find.byKey(kTabPillKey));
    expect(pill.left, greaterThanOrEqualTo(circle.right + 8));
    expect(pill.right, lessThanOrEqualTo(393 - 21));
```

- replace the `.previous.label` check of `CompactSearchChrome` with:

```dart
      expect(
        find.descendant(
          of: find.byKey(kSearchCollapsedKey),
          matching: find.bySemanticsLabel('Home'),
        ),
        findsOneWidget,
      );
```

  It first needs `await tester.pumpAndSettle();` so the bar has collapsed.

**`test/widget/shell_chrome_test.dart`, the narrow group's 375 and 340 tests:** the row margin is now 21:
- `expect(row(tester).left, 21)`, `expect(row(tester).right, 375 - 21)`, `expect(circle(tester).right, 375 - 21)`;
- the same at 340;
- the cell math becomes `(375 − 42 − 70 − 16)/5 + 8 = 57.4` and `(340 − 42 − 70 − 16)/5 + 8 = 50.4`.

  The 320 test (narrow margin 8) is unchanged.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd liquid_shell
fvm flutter test test/widget/search_morph_test.dart test/widget/search_fallback_test.dart test/unit/search_test.dart test/widget/shell_chrome_test.dart
cd .. && make test
```

Expected: PASS. P3b's focus-safety tests are unchanged and green: the field is still the same `SearchFieldGlass` in one chain.

- [ ] **Step 5: Regenerate goldens, commit**

```bash
make goldens-update   # search_* and every bottom-bar image move by the 21 pt margin
fvm dart format liquid_shell
bash .githooks/pre-commit
git add liquid_shell/lib liquid_shell/test liquid_shell/example/test/goldens liquid_shell/doc/images
git commit -m "feat(shell): search tab collapses with the tab bar morph, drag onto ⌕ (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 11: Landscape phones, the iPad top bar, the sidebar tokens

**Files:**
- Modify: `liquid_shell/lib/src/chrome/tab_geometry.dart` (`landscapeTabGeometry`, `topTabGeometry`)
- Modify: `liquid_shell/lib/src/chrome/glass_tab_bar.dart` (`form`, label measuring, per-form cell parts)
- Modify: `liquid_shell/lib/src/chrome/tab_bar.dart` (the top position → `GlassTabBar(form: top)`; the bottom position picks landscape; delete `_TopBar`, `_Cell`, `_BadgedIcon`)
- Modify: `liquid_shell/lib/src/shell/breakpoints.dart` (`compactHeight`)
- Modify: `liquid_shell/lib/src/shell/shell_layout.dart` (`presentationFor`, `kTopBarGap` 5.5, `kTopPillExtent` 48)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (the landscape bottom bar with margin 38)
- Modify: `liquid_shell/lib/src/chrome/sidebar.dart` (unselected rows in `tabForeground`)
- Test: `test/unit/tab_geometry_test.dart`, `test/unit/shell_layout_test.dart`, `test/widget/glass_tab_bar_test.dart`, `test/widget/sidebar_test.dart`, `test/helpers/shell_harness.dart`, plus the existing tests that used P1's landscape overlay
- Regenerate: goldens

**Interfaces:**
- Consumes: Tasks 1, 6–10.
- Produces:
  - `TabBarGeometry landscapeTabGeometry({required List<double> labelWidths, required double maxWidth, required bool trailing, required TextDirection direction})`;
  - `TabBarGeometry topTabGeometry({required List<double> labelWidths, required List<bool> iconOnly, required double maxWidth, required bool trailing, required TextDirection direction})`;
  - `GlassTabBar(form: TabBarForm)`;
  - `LiquidShellBreakpoints({double regular = 700, double tiledSidebar = 1024, double compactHeight = 500})`;
  - `const double kLiquidCompactHeight = 500` (internal; `LiquidTabBar` uses it standalone).

- [ ] **Step 1: Write the failing tests**

Append to `tab_geometry_test.dart`:

```dart
  group('landscape (research §1.2)', () {
    // Home 83.7, Explore 90, Settings 94.7, Inbox 81 = label + 49.
    const labels = [34.7, 41, 45.7, 32];

    test('44 pill, 36 items, 4 gaps, content-sized', () {
      final g = landscapeTabGeometry(
        labelWidths: labels,
        maxWidth: 874 - 2 * TabMetrics.landscapeMargin,
        trailing: true,
        direction: TextDirection.ltr,
      );
      expect(g.form, TabBarForm.landscape);
      expect(g.size.height, 44);
      expect(g.pill.left, 0);
      expect(
        [for (final s in g.slots) s.width],
        [for (final w in labels) closeTo(w + 49, 1e-9)],
      );
      for (final s in g.slots) {
        expect(s.height, 36);
        expect(s.top, 4);
      }
      expect(g.slots[1].left - g.slots[0].right, closeTo(4, 1e-9));
      expect(g.pill.width, closeTo(8 + 349.4 + 12, 1e-9));
      expect(g.trailing!.size, const Size(44, 44));
    });

    test('squeezed proportionally when the row is too narrow', () {
      final g = landscapeTabGeometry(
        labelWidths: labels,
        maxWidth: 300,
        trailing: false,
        direction: TextDirection.ltr,
      );
      expect(g.pill.width, 300);
      expect(g.slots.last.right, closeTo(296, 1e-9));
    });
  });

  group('regular top (research §1.3)', () {
    test('3 tabs: 274 wide, 48 tall, label + 31 items', () {
      final g = topTabGeometry(
        labelWidths: const [47.5, 59.5, 66],
        iconOnly: const [false, false, false],
        maxWidth: 800,
        trailing: false,
        direction: TextDirection.ltr,
      );
      expect(g.form, TabBarForm.top);
      expect(g.pill.size, const Size(274, 48));
      expect(g.pill.left, (800 - 274) / 2);
      expect([for (final s in g.slots) s.width], [78.5, 90.5, 97]);
      for (final s in g.slots) {
        expect(s.height, 40);
      }
    });

    test('4 tabs + search item: 397.5 wide, search 48.5', () {
      final g = topTabGeometry(
        labelWidths: const [47.5, 59.5, 66, 44, 0],
        iconOnly: const [false, false, false, false, true],
        maxWidth: 800,
        trailing: false,
        direction: TextDirection.ltr,
      );
      expect(g.pill.width, 397.5);
      expect(g.slots.last.width, 48.5);
    });

    test('trailing circle 48, gap 8, the group centred', () {
      final g = topTabGeometry(
        labelWidths: const [47.5, 59.5, 66],
        iconOnly: const [false, false, false],
        maxWidth: 800,
        trailing: true,
        direction: TextDirection.ltr,
      );
      expect(g.pill.left, (800 - 274 - 56) / 2);
      expect(g.trailing, Rect.fromLTWH(g.pill.right + 8, 0, 48, 48));
    });
  });
```

In `shell_layout_test.dart`:

(a) In `reference devices (spec §5.1)`, change the Pro Max landscape line to `expect(of(932, 430), ShellPresentation.compact); // Pro Max landscape (VK-503 Q8)`.

(b) Add:

```dart
    test('compactHeight (spec VK-503 §12.1)', () {
      expect(of(874, 402), ShellPresentation.compact);
      expect(of(1194, 834), ShellPresentation.tiled);
      expect(of(834, 1194), ShellPresentation.overlay);
      const p1 = LiquidShellBreakpoints(compactHeight: 0);
      expect(presentationFor(const Size(932, 430), p1), ShellPresentation.overlay);
    });

    test('breakpoints: compactHeight in ==, hashCode, toString, asserts', () {
      expect(const LiquidShellBreakpoints().compactHeight, 500);
      expect(
        const LiquidShellBreakpoints(),
        isNot(const LiquidShellBreakpoints(compactHeight: 0)),
      );
      expect(
        '${const LiquidShellBreakpoints()}',
        'LiquidShellBreakpoints(regular: 700.0, tiledSidebar: 1024.0, '
        'compactHeight: 500.0)',
      );
      expect(
        () => LiquidShellBreakpoints(compactHeight: -1),
        throwsAssertionError,
      );
    });
```

(c) Update the existing `toString names both thresholds` expectation to `'LiquidShellBreakpoints(regular: 600.0, tiledSidebar: 1200.0, compactHeight: 500.0)'`. In `topBar and sidebarOverlay: pad.top + 20 + pill, +72 before …`, use the constants: `pad.top + kTopBarGap + (measured ?? kTopPillExtent)`. The numbers become `+ 5.5` and `+ 53.5` before measurement.

Append to `glass_tab_bar_test.dart`:

```dart
  testWidgets('top form: 48 pill, label-only 17 pt cells, icon-only search', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(834, 1210) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: LiquidTabBar(
              position: LiquidTabBarPosition.top,
              destinations: const [
                ..._three,
                LiquidDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                  role: LiquidDestinationRole.search,
                ),
              ],
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(kTabPillKey)).height, 48);
    expect(find.byIcon(Icons.home), findsNothing);
    expect(find.byIcon(Icons.search), findsNWidgets(2));
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(kTabTintedKey),
        matching: find.text('Home'),
      ),
    );
    expect(label.style!.fontSize, 17);
    expect(label.style!.fontWeight, FontWeight.w600);
  });

  testWidgets('landscape form: 44 pill, icon beside a 12 pt label', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(874, 402) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: TabMetrics.landscapeMargin,
                right: TabMetrics.landscapeMargin,
                bottom: 20,
                child: LiquidTabBar(
                  destinations: _three,
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(kTabPillKey)).height, 44);
    final icon = tester.getRect(
      find
          .descendant(
            of: find.byKey(kTabNormalKey),
            matching: find.byIcon(Icons.map),
          )
          .first,
    );
    final label = tester.getRect(
      find.descendant(of: find.byKey(kTabNormalKey), matching: find.text('Explore')),
    );
    expect(label.left, greaterThan(icon.right));
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(kTabNormalKey),
              matching: find.text('Explore'),
            ),
          )
          .style!
          .fontSize,
      12,
    );
  });
```

Append to `sidebar_test.dart`:

```dart
  testWidgets('unselected rows use tabForeground (spec VK-503 §12.3)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidSidebar(
            destinations: const [
              LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
              LiquidDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    final context = tester.element(find.text('Inbox'));
    expect(
      DefaultTextStyle.of(context).style.color ??
          tester.widget<Text>(find.text('Inbox')).style?.color,
      LiquidGlassTheme.of(context).tabForeground,
    );
  });
```

In `test/helpers/shell_harness.dart`, add a `breakpoints` field (`final LiquidShellBreakpoints breakpoints;`, default `const LiquidShellBreakpoints()`) to `TestShell` and pass it to `LiquidShell(breakpoints: …)`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd liquid_shell && fvm flutter test test/unit/tab_geometry_test.dart test/unit/shell_layout_test.dart test/widget/glass_tab_bar_test.dart test/widget/sidebar_test.dart`
Expected: FAIL. The new geometry functions and `compactHeight` are undefined, the top form still has the P1 52 pt pill, and the sidebar row is `onSurface`.

- [ ] **Step 3: Implement**

Append to `tab_geometry.dart`:

```dart
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
      : math.min(1.0, (pillWidth - 2 * inset - gaps) / sum);
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
      iconOnly[i]
          ? TabMetrics.topIconItemWidth
          : w + 2 * TabMetrics.topItemPadding,
  ];
  final sum = items.fold<double>(0, (a, b) => a + b);
  final natural = 2 * inset + sum;
  final reserve = trailing ? extent + TabMetrics.trailingGap : 0.0;
  final width = maxWidth.isFinite ? maxWidth : natural + reserve;
  final pillWidth = math.max(2 * inset, math.min(natural, width - reserve));
  final squeeze = sum == 0 ? 1.0 : math.min(1.0, (pillWidth - 2 * inset) / sum);
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
```

In `glass_tab_bar.dart`:

(a) Add `this.form = TabBarForm.compact` and its field doc (`/// Compact, landscape or top (spec §5).`).

(b) Add label measuring and form-aware geometry:

```dart
  TextStyle _labelStyle(LiquidGlassTheme theme, {required bool tinted}) =>
      switch (widget.form) {
        TabBarForm.compact => theme.labelStyle.copyWith(
          fontWeight: tinted ? FontWeight.w600 : theme.labelStyle.fontWeight,
        ),
        TabBarForm.landscape => theme.labelStyle.copyWith(
          fontSize: 12,
          fontWeight: tinted ? FontWeight.w600 : FontWeight.w400,
        ),
        TabBarForm.top => theme.labelStyle.copyWith(
          fontSize: 17,
          fontWeight: tinted ? FontWeight.w600 : FontWeight.w500,
        ),
      };

  /// Label widths in the tinted (widest) weight, so the slots never move
  /// when the selection does.
  List<double> _labelWidths(BuildContext context, TextStyle style) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return [
      for (final i in _shown)
        () {
          final painter = TextPainter(
            text: TextSpan(text: widget.destinations[i].label, style: base),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }(),
    ];
  }
```

Replace `_geometryFor` with:

```dart
  TabBarGeometry _geometryFor(
    BuildContext context,
    double maxWidth,
    TextDirection direction,
    double extent,
  ) {
    final theme = LiquidGlassTheme.of(context);
    final trailing = widget.trailing != null || widget.reserveTrailing;
    return switch (widget.form) {
      TabBarForm.compact => compactTabGeometry(
        count: _shown.length,
        maxWidth: maxWidth,
        trailing: trailing,
        direction: direction,
        extent: extent,
      ),
      TabBarForm.landscape => landscapeTabGeometry(
        labelWidths: _labelWidths(context, _labelStyle(theme, tinted: true)),
        maxWidth: maxWidth,
        trailing: trailing,
        direction: direction,
      ),
      TabBarForm.top => topTabGeometry(
        labelWidths: _labelWidths(context, _labelStyle(theme, tinted: true)),
        iconOnly: [
          for (final i in _shown)
            widget.destinations[i].role == LiquidDestinationRole.search ||
                isAxTextScale(context),
        ],
        maxWidth: maxWidth,
        trailing: trailing,
        direction: direction,
      ),
    };
  }
```

and call it as `_geometryFor(context, constraints.maxWidth, direction, extent)`.

(c) Pass `form` and the two styles into `_Cells`. Replace the cell part placement in `_Cells.build` with a per-form helper:

```dart
  /// Icon and label rects inside [slot], slot-local (spec §5.1–§5.3).
  (Rect?, Rect?) _parts(Rect slot, bool iconOnly) {
    final local = Offset.zero & slot.size;
    if (ax || iconOnly) return (local, null);
    return switch (form) {
      TabBarForm.compact => (
        tabIconFrame(slot).shift(-slot.topLeft),
        tabLabelBox(slot, lineHeight).shift(-slot.topLeft),
      ),
      TabBarForm.landscape => (
        Rect.fromLTWH(6, (slot.height - 25) / 2, 25, 25),
        Rect.fromLTWH(37, 0, math.max(0, slot.width - 49), slot.height),
      ),
      TabBarForm.top => (null, local),
    };
  }
```

`iconOnly` is `d.role == LiquidDestinationRole.search` for `TabBarForm.top`, and false otherwise. The icon size is `theme.tabIconSize` (compact), `22` (landscape and top). The label is centred in compact and top, and start-aligned (`Alignment.centerLeft`, mirrored by `AlignmentDirectional.centerStart`) in landscape. For RTL landscape, mirror the two part rects inside the slot: `Rect.fromLTRB(slot.width - r.right, r.top, slot.width - r.left, r.bottom)`.

(d) The badge frame for the non-compact forms is the icon rect when there is one, otherwise the label rect deflated to the text. Use `(iconRect ?? labelRect.deflate(8))` in `_Badges`.

In `tab_bar.dart`:

(a) Add `const double kLiquidCompactHeight = 500;` (the `LiquidShellBreakpoints.compactHeight` default).

(b) `LiquidTabBar.build` becomes:

```dart
    final size = MediaQuery.sizeOf(context);
    final form = position == LiquidTabBarPosition.top
        ? TabBarForm.top
        : size.width > size.height && size.height < kLiquidCompactHeight
        ? TabBarForm.landscape
        : TabBarForm.compact;
    return GlassTabBar(
      form: form,
      destinations: destinations,
      selectedIndex: selectedIndex,
      onSelect: onDestinationSelected,
      trailing: trailing,
      minimized: minimized && form != TabBarForm.top,
      onCollapsedTap: onExpand,
      strings: strings,
      narrow: narrow ?? size.width < kLiquidNarrowWidth,
    );
```

(c) Delete `_TopBar`, `_Cell`, `_BadgedIcon` and `_cellSidePadding`. Update the `LiquidTabBarPosition.top` doc to `Regular: floating at the top, label-only cells, 48 pt pill.`

In `breakpoints.dart`:
- add `this.compactHeight = 500` with `assert(compactHeight >= 0, 'compactHeight must not be negative')`, and the field doc (`/// A landscape shell lower than this is compact (phones in landscape get the bottom bar, spec VK-503 §12.1). 0 restores P1.`);
- add it to `==`, `hashCode` and `toString`: `'LiquidShellBreakpoints(regular: $regular, tiledSidebar: $tiledSidebar, compactHeight: $compactHeight)'`.

In `shell_layout.dart`:

```dart
const double kTopBarGap = TabMetrics.topRowGap;

const double kTopPillExtent = TabMetrics.topExtent;

ShellPresentation presentationFor(
  Size size,
  LiquidShellBreakpoints breakpoints,
) {
  final lowLandscape =
      size.width > size.height && size.height < breakpoints.compactHeight;
  if (breakpoints.sizeClassOf(size.width) == LiquidSizeClass.compact ||
      lowLandscape) {
    return ShellPresentation.compact;
  }
  return size.width >= breakpoints.tiledSidebar && size.width > size.height
      ? ShellPresentation.tiled
      : ShellPresentation.overlay;
}
```

Add `import 'package:liquid_shell/src/chrome/tab_geometry.dart';` and update the doc comments of both constants to cite spec VK-503 §5.3.

In `liquid_shell.dart`, bottom branch (non-search):
- `final landscape = size.width > size.height;`;
- the margin becomes `narrow ? _kNarrowBarMargin : landscape ? TabMetrics.landscapeMargin : _kBottomBarMargin`;
- the bar is `GlassTabBar(form: landscape ? TabBarForm.landscape : TabBarForm.compact, …)` with the same arguments the `LiquidTabBar` had (`onSelect: _onSelect`, `onCollapsedTap: _expand`).

The search branch keeps the compact form: the P3b morph is portrait geometry, and the compact search rects assume a 48 circle in a 62 row. In landscape the search row uses `TabBarForm.landscape` for the pill and leaves `compactSearchRects` as is. This is a known approximation: native landscape search was not captured.

In `sidebar.dart` line ~195:

```dart
    final color = isSelected
        ? scheme.onPrimaryContainer
        : LiquidGlassTheme.of(context).tabForeground;
```

(add the `glass_theme.dart` import if it is missing).

- [ ] **Step 4: Run the tests, then fix the P1 landscape and top-bar tests**

```bash
cd liquid_shell && fvm flutter test test/unit test/widget
```

Expected:
- the new tests PASS;
- tests that used `kPhoneLandscape` (932 × 430) to exercise the **overlay sidebar** now see a compact shell. In `shell_chrome_test.dart` and `native_chrome_test.dart`, pass `breakpoints: const LiquidShellBreakpoints(compactHeight: 0)` to `TestShell` in every test that asserts an overlay, top bar or sidebar at `kPhoneLandscape`, so they keep testing P1's overlay;
- tests that assert the top bar row at `pad.top + 20` or a 52 pt pill: replace the literal with `kTopBarGap` / `kTopPillExtent`.

Add one new test to `shell_chrome_test.dart`:

```dart
  testWidgets('landscape phone: the 44 pt bottom bar at margin 38 (VK-503 '
      'Q8)', (tester) async {
    await pumpShell(tester, const TestShell(), size: kPhoneLandscape);
    expect(scopeOf(tester).sizeClass, LiquidSizeClass.compact);
    final pill = tester.getRect(find.byKey(kTabPillKey));
    expect(pill.height, 44);
    expect(pill.left, greaterThanOrEqualTo(38));
  });
```

Run `make test` until it is green.

- [ ] **Step 5: Regenerate goldens, review, commit**

```bash
make goldens-update
```

Check `ff_ipad_*`, `hero_ipad_*` (48 pt label-only top pill, closer to the top), `case_search_tablet_*` and `ff_iphone`. No landscape-phone golden exists. If `form_factors` shows a landscape phone frame, check it shows the 44 pt bottom bar.

```bash
fvm dart format liquid_shell
bash .githooks/pre-commit
git add liquid_shell/lib liquid_shell/test liquid_shell/example/test/goldens liquid_shell/doc/images
git commit -m "feat(shell): landscape bottom bar, native iPad top bar, sidebar tokens (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: The scroll-edge pocket

**Files:**
- Create: `liquid_shell/lib/src/glass/scroll_pocket.dart`
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart`
- Test: `liquid_shell/test/widget/scroll_pocket_test.dart`

**Interfaces:**
- Consumes: Task 5 (`resolveGlassFor`, `liquidGlassChanges`).
- Produces: `const double kScrollPocketExtent = 148`, `class ScrollEdgePocket extends StatefulWidget` and `const kScrollPocketKey`.

- [ ] **Step 1: Write the failing test**

```dart
// liquid_shell/test/widget/scroll_pocket_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/scroll_pocket.dart';

import '../helpers/shell_harness.dart';

Future<void> _liquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
}

Finder get _bands => find.descendant(
  of: find.byKey(kScrollPocketKey),
  matching: find.byType(BackdropFilter),
);

void main() {
  testWidgets('liquid bottom bar: three blur bands over the bottom 148', (
    tester,
  ) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    expect(_bands, findsNWidgets(3));
    final rect = tester.getRect(find.byKey(kScrollPocketKey));
    expect(rect.height, kScrollPocketExtent);
    expect(rect.bottom, kPhone.height);
    final sigmas = tester
        .widgetList<BackdropFilter>(_bands)
        .map((b) => b.filter.toString())
        .toList();
    expect(sigmas.join(), allOf(contains('0.5'), contains('1.0'), contains('1.6')));
  });

  testWidgets('frosted: no pocket', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await pumpShell(tester, const TestShell());
    expect(_bands, findsNothing);
  });

  testWidgets('top bar: no pocket', (tester) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell(), size: kTabletPortrait);
    expect(find.byKey(kScrollPocketKey), findsNothing);
  });

  testWidgets('it never takes touches', (tester) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    expect(
      find.ancestor(
        of: _bands.first,
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('the pill and the pocket share one backdrop key', (
    tester,
  ) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    final pill = tester
        .renderObjectList<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .first;
    expect(pill.backdropKey, isNotNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/widget/scroll_pocket_test.dart`
Expected: FAIL, because `scroll_pocket.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// liquid_shell/lib/src/glass/scroll_pocket.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Height of the scroll-edge pocket (research §5: 147.8 pt).
const double kScrollPocketExtent = 148;

/// The pocket (tests).
const kScrollPocketKey = ValueKey<String>('liquid-scroll-pocket');

/// An approximation of iOS 26's scroll-edge pocket under the bottom bar
/// (spec VK-503 §15, Q13): three blur bands (σ 0.5, 1.0, 1.6, top to
/// bottom) and a faint dim. Flutter has no progressive backdrop blur, so
/// it is banded. Liquid tier only; it draws nothing in frosted and solid.
class ScrollEdgePocket extends StatefulWidget {
  /// Creates the pocket; the shell sizes it to [kScrollPocketExtent].
  const ScrollEdgePocket({super.key});

  @override
  State<ScrollEdgePocket> createState() => _ScrollEdgePocketState();
}

class _ScrollEdgePocketState extends State<ScrollEdgePocket> {
  final LiquidSignalsController _signals = LiquidSignalsController.instance;
  late final Listenable _changes = liquidGlassChanges();

  @override
  void initState() {
    super.initState();
    _signals.acquire();
  }

  @override
  void dispose() {
    _signals.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      final theme = LiquidGlassTheme.of(context);
      if (resolveGlassFor(context).tier != LiquidGlassTier.liquid ||
          theme.liquidBlurSigma <= 0) {
        return const SizedBox.shrink();
      }
      final dark = Theme.of(context).brightness == Brightness.dark;
      return IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                for (final sigma in const [0.5, 1.0, 1.6])
                  Expanded(
                    child: ClipRect(
                      child: BackdropFilter.grouped(
                        filter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
              ],
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x00000000),
                    // Research §5: the band reads 252, not 255 (light).
                    dark ? const Color(0x14000000) : const Color(0x03000000),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

In `liquid_shell.dart`, right after the body child is added to `children` and before the `switch (kind)`:

```dart
    // Spec VK-503 §15: the pocket under the default bottom bar.
    if (kind == LiquidChromeKind.bottomBar && widget.chromeBuilder == null) {
      children.add(
        const Positioned(
          key: kScrollPocketKey,
          left: 0,
          right: 0,
          bottom: 0,
          height: kScrollPocketExtent,
          child: ScrollEdgePocket(),
        ),
      );
    }
```

The pocket is a later sibling of the body, inside the shell's `BackdropGroup`. The body chain stays the first child, and its wrappers are unchanged.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd liquid_shell && fvm flutter test test/widget/scroll_pocket_test.dart && cd ..
make test && make provenance
```

Expected: PASS, with the glass seam clean (the file is under `lib/src/glass/`).

- [ ] **Step 5: Regenerate goldens, commit**

```bash
make goldens-update   # liquid_* bottom-bar images gain the pocket
fvm dart format liquid_shell
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/scroll_pocket.dart liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/test/widget/scroll_pocket_test.dart liquid_shell/example/test/goldens liquid_shell/doc/images
git commit -m "feat(glass): banded scroll-edge pocket under the liquid bottom bar (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Example icons, docs, CHANGELOG, version 0.1.0-dev.6

**Files:**
- Modify: `liquid_shell/example/lib/cases/{basic_tabs,badges,native_chrome,narrow_width,sidebar_only,trailing_action,native_alerts,form_factors}.dart` (filled `selectedIcon`s)
- Modify: `liquid_shell/README.md`, `liquid_shell/doc/liquid.md`, `liquid_shell/doc/theming.md`
- Create: `liquid_shell/doc/tab_bar.md`
- Modify: `CHANGELOG.md` in all four packages, every `pubspec.yaml` version and constraint, `liquid_shell_ios/ios/liquid_shell_ios.podspec`
- Test: `liquid_shell/example/test/cases_smoke_test.dart` (icon check), `make snippets`

**Interfaces:**
- Consumes: everything before.
- Produces: the docs and version.

- [ ] **Step 1: Write the failing test**

Append to `liquid_shell/example/test/cases_smoke_test.dart`:

```dart
  testWidgets('every case destination has a filled selectedIcon (spec '
      'VK-503 §14)', (tester) async {
    for (final entry in kCases) {
      await tester.pumpWidget(MaterialApp(home: entry.page));
      await tester.pump();
      final shells = tester.widgetList<LiquidShell>(find.byType(LiquidShell));
      for (final shell in shells) {
        for (final d in shell.destinations) {
          if (d.role == LiquidDestinationRole.search) continue;
          expect(
            d.selectedIcon,
            isNotNull,
            reason: '${entry.id}: ${d.label} needs a filled selectedIcon',
          );
        }
      }
    }
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd liquid_shell/example && fvm flutter test test/cases_smoke_test.dart`
Expected: FAIL, for example `basic: Home needs a filled selectedIcon`.

- [ ] **Step 3: Implement**

**Example.** Give every destination a filled `selectedIcon`, using the spec §14 pairs. Where a case's `icon` is not in this list, use the Material icon without `_outlined`:

| `icon` | `selectedIcon` |
|---|---|
| `Icons.home_outlined` | `Icons.home` |
| `Icons.explore_outlined` (sfSymbol `map`) | change `icon` to `Icons.map_outlined`, `selectedIcon: Icon(Icons.map)` |
| `Icons.settings_outlined` | `Icons.settings` |
| `Icons.inbox_outlined` | `Icons.inbox` |
| `Icons.forum_outlined` | `Icons.forum` |
| `Icons.notifications_outlined` | `Icons.notifications` |
| `Icons.archive_outlined` | `Icons.archive` |
| `Icons.bar_chart` | `Icons.bar_chart` (already filled) |

For example, in `basic_tabs.dart` inside `#docregion readme`:

```dart
        LiquidDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
          sfSymbol: 'house',
        ),
        LiquidDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Explore',
          sfSymbol: 'map',
        ),
        LiquidDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
          sfSymbol: 'gear',
        ),
```

Copy the changed `#docregion` blocks into `README.md` (`make snippets` checks that they are identical).

**`liquid_shell/doc/tab_bar.md` (new):**

```markdown
# The Flutter tab bar

On iOS 26 with native chrome, UIKit draws the tab bar. Everywhere else
(iOS 15–25, Android, or a forced glass tier) `liquid_shell` draws its own,
measured against iOS 26.5 and built to match it.

## Geometry

- **Compact (phones, portrait).** A 62 pt pill, 21 pt from the screen
  edges and bottom. Each tab gets an 86 pt slot until the pill reaches the
  row width (`16 + 86 × tabs`). The selection capsule is the slot plus
  8 pt, so neighbours overlap. With a trailing action or the search ⌕,
  the pill sits at the start and the circle at the end.
- **Landscape phones.** A 44 pt pill, icon beside a 12 pt label, each tab
  as wide as its label plus 49 pt.
- **Regular (iPad).** A 48 pt pill at the top, label only (17 pt), the
  search tab as an icon.

## The lens

At rest the selected tab sits in a soft gray capsule. Touch the bar and
the capsule turns into a clear glass lens:

- it bends the page behind it, with a rainbow fringe at its edge;
- it follows your finger;
- it magnifies and tints the icons under it;
- it snaps to the nearest tab when you lift your finger.

The tab is selected when you lift your finger, as on iOS. A tap slides the
lens across with the springs measured from iOS 26.5. The whole bar swells
slightly while you hold it, and a soft glow follows your finger and
ripples out when you let go.

## Icons

iOS draws a filled SF Symbol in every tab. Flutter cannot draw SF
Symbols, so give each destination a filled `selectedIcon`. The tab bar
draws `selectedIcon ?? icon` in every slot, and the sidebar draws
`icon` / `selectedIcon` by selection:

    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    )

`LiquidGlassTheme.tabIconSize` (26 by default) sizes Material icons to
SF's optical size. Tune it for other icon fonts.

## Minimize on scroll

Scrolling down shrinks the bar to a 48 pt circle with the current tab's
icon. Tap it to bring the bar back. Scrolling up does not, as on iOS 26.

## Accessibility

- **Reduce Motion.** No sliding, swelling or glow. A tap cross-fades the
  selection, and a drag moves a plain capsule.
- **Reduce Transparency, Increase Contrast.** The solid tier: opaque bar
  and lens, a border under Increase Contrast.
- **Large text.** Tabs become icon-only, and a long press shows the large
  content viewer.
- **VoiceOver and TalkBack.** One button per tab, with its badge in the
  label.

## Haptics

A selection click each time the lens crosses into another tab while you
drag. Plain taps are silent.

## What is not identical to iOS

- The glass material is matched by measurement, not by Apple's private
  filter, and it does not re-tint by the brightness behind it.
- Icons are your icon font, not SF Symbols.
- Labels and icons use solid colours, not iOS's vibrancy.
- The lens's squash and stretch is a two-spring model: the peaks and timing
  match, some in-between frames do not.
- The scroll-edge pocket is three blur bands, not a continuous blur.
- Glass over a platform view (map, web view) cannot see it. Force
  `frosted` or `solid` on such pages.
- No iPad tab customization on long press.
```

**`doc/liquid.md`:** add the section "The tab lens and the pocket" (one paragraph each, as in spec §7 and §15), and a "Defaults changed in 0.1.0-dev.6" table copied from spec §6.4.

**`doc/theming.md`:** document `selectionFill`, `tabForeground`, `badgeColor` and `tabIconSize`.

**`README.md`:** in "Features", replace the tab bar bullet with "A floating glass tab bar measured against iOS 26: native slot geometry, a liquid lens that follows your finger, minimize on scroll". Link `doc/tab_bar.md` under "More". Add the "Icons" advice (filled `selectedIcon`) to "Quickstart". Under "Roadmap", add "VK-503 (0.1.0-dev.6): tab bar fidelity".

**CHANGELOG** (all four packages; the three platform packages say "No changes; versioned with `liquid_shell`."). `liquid_shell/CHANGELOG.md` gets this entry at the top:

```markdown
## 0.1.0-dev.6

- **Tab bar fidelity (VK-503).** The Flutter tab bar matches iOS 26.5:
  native slot geometry (86 pt slots, 21 pt margins, the pill pinned at
  the start beside a trailing circle), a liquid lens that engages on touch,
  follows a drag and snaps on release (the measured springs), tinted and
  magnified icons under the lens, a pill swell, a highlight and a finger
  glow, an icon pop on tap, and selection clicks while dragging.
- **Behaviour changes.**
  - A tab is selected on release, not on touch.
  - Every tab slot draws `selectedIcon ?? icon`.
  - There is no ink splash.
  - The minimized bar is a 48 pt icon-only circle that expands on tap or
    on a selection change, not on a forward scroll.
  - Landscape phones get the 44 pt bottom bar (`compactHeight`).
  - The iPad top bar is 48 pt, label only, 5.5 pt below the safe area.
  - The bottom bar margin is 21 pt.
- **New:** `LiquidGlassTheme.selectionFill`, `tabForeground`,
  `badgeColor`, `tabIconSize`; `LiquidShellBreakpoints.compactHeight`; a
  scroll-edge pocket under the liquid bottom bar.
- **Defaults changed:** `rimHighlight` 0.12 / 0.22, `shadow` 7 % (0, 3)
  blur 20, `dispersion` 0 (the lens adds its own), `labelStyle` 10 / 1.2 /
  w500 / no tracking. Badges are the native 21 pt red capsule.
```

**Versions:**

```bash
for f in liquid_shell/pubspec.yaml liquid_shell_android/pubspec.yaml liquid_shell_ios/pubspec.yaml liquid_shell_platform_interface/pubspec.yaml liquid_shell/example/pubspec.yaml liquid_shell_ios/ios/liquid_shell_ios.podspec; do
  sed -i '' 's/0\.1\.0-dev\.5/0.1.0-dev.6/g' "$f"
done
git grep -n "0.1.0-dev.5" -- '*.yaml' '*.podspec'   # expect no output
```

- [ ] **Step 4: Run the tests and the snippet and doc checks**

```bash
make get
cd liquid_shell/example && fvm flutter test test/cases_smoke_test.dart && cd ../..
make snippets && make test && make provenance
make goldens-update   # the example icons changed
```

Expected: PASS. `make snippets` prints that the README matches.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell
bash .githooks/pre-commit
git add liquid_shell/example/lib liquid_shell/example/test liquid_shell/example/pubspec.yaml liquid_shell/README.md liquid_shell/doc liquid_shell/CHANGELOG.md liquid_shell_android liquid_shell_ios/pubspec.yaml liquid_shell_ios/CHANGELOG.md liquid_shell_ios/ios/liquid_shell_ios.podspec liquid_shell_platform_interface liquid_shell/pubspec.yaml
git commit -m "docs(docs): tab bar guide, filled example icons, 0.1.0-dev.6 (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Acceptance traces: the reference fixture, the Flutter trace, the comparison tool

**Files:**
- Create: `docs/qa/vk503/native_reference.json`
- Modify: `liquid_shell/lib/src/chrome/glass_tab_bar.dart` (export the `debugTabTrace` hook)
- Modify: `liquid_shell/lib/liquid_shell.dart` (export `debugTabTrace`)
- Create: `liquid_shell/example/integration_test/tab_fidelity_test.dart`
- Create: `tool/tab_trace_compare.dart`, `tool/test/tab_trace_compare_test.dart`
- Modify: `Makefile` (target `tab-traces`)
- Test: `liquid_shell/test/widget/tab_trace_test.dart`, `tool/test/tab_trace_compare_test.dart`

**Interfaces:**
- Consumes: the motion and the bar (Tasks 3–9).
- Produces:
  - `@visibleForTesting void Function(Map<String, double> sample)? debugTabTrace`. It is called once per bar tick with the keys `t` (s, ticker time), `x`/`y` (global lens centre), `w`, `h`, `engage`, `scale`, `glow`, `glowD`, `pop` and `morph`;
  - `dart run tool/tab_trace_compare.dart <response.json> <reference.json>`, which prints a table and exits 1 on a failure;
  - `make tab-traces`.

- [ ] **Step 1: Write the failing tests**

```dart
// liquid_shell/test/widget/tab_trace_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

void main() {
  testWidgets('debugTabTrace receives one global sample per tick', (
    tester,
  ) async {
    final samples = <Map<String, double>>[];
    debugTabTrace = samples.add;
    addTearDown(() => debugTabTrace = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LiquidTabBar(
              destinations: const [
                LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
                LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
              ],
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Explore'));
    await tester.pumpAndSettle();
    expect(samples, isNotEmpty);
    expect(
      samples.first.keys,
      containsAll(<String>[
        't', 'x', 'y', 'w', 'h', 'engage', 'scale', 'glow', 'glowD', 'pop',
        'morph',
      ]),
    );
    final explore = tester.getCenter(find.bySemanticsLabel('Explore'));
    expect(samples.last['x'], closeTo(explore.dx, 0.5));
  });
}
```

```dart
// tool/test/tab_trace_compare_test.dart
import 'dart:math' as math;

import 'package:test/test.dart';

import '../tab_trace_compare.dart';

/// A synthetic tap trace on the reference spring: 60 fps, from [from] to
/// [to], held for [delay].
List<Map<String, double>> spring(
  double from,
  double to, {
  double zeta = 0.79,
  double response = 0.39,
  double delay = 0.025,
  double slow = 1,
}) {
  final out = <Map<String, double>>[];
  for (var f = 0; f < 90; f++) {
    final t = f / 60;
    final x = t < delay
        ? from
        : springAt(to - from, zeta, response * slow, t - delay) + from;
    out.add({
      't': t, 'x': x, 'y': 0, 'w': 94, 'h': 54, 'engage': 0, 'scale': 1,
      'glow': 0, 'glowD': 93, 'pop': 1, 'morph': 0,
    });
  }
  return out;
}

void main() {
  test('springAt is the closed-form step response', () {
    expect(springAt(86, 0.79, 0.39, 0), 0);
    expect(springAt(86, 0.79, 0.39, 3), closeTo(86, 1e-3));
    // Critically damped and overdamped branches.
    expect(springAt(1, 1, 0.25, 2), closeTo(1, 1e-3));
    expect(springAt(1, 1.4, 0.19, 2), closeTo(1, 1e-3));
  });

  test('settle: last frame outside 0.5 pt', () {
    final xs = [0.0, 50, 85, 86.6, 86.2, 86];
    expect(settle(xs, 86, dt: 1), 4);
  });

  test('a trace on the reference spring passes the tap check', () {
    final r = checkTap(spring(115, 201), from: 115, to: 201,
        zeta: 0.79, response: 0.39, delay: 0.025);
    expect(r.pass, isTrue, reason: r.detail);
  });

  test('a 20 % slower spring fails it', () {
    final r = checkTap(spring(115, 201, slow: 1.2), from: 115, to: 201,
        zeta: 0.79, response: 0.39, delay: 0.025);
    expect(r.pass, isFalse);
  });

  test('ramp lag of the drag spring', () {
    expect(rampLag(90, 0.75, 0.33), closeTo(90 * 2 * 0.75 / (2 * math.pi / 0.33), 1e-9));
  });

  test('range checks', () {
    expect(within(1.16, 1.16, abs: 0.02).pass, isTrue);
    expect(within(1.19, 1.16, abs: 0.02).pass, isFalse);
    expect(within(0.33, 0.30, rel: 0.10).pass, isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd liquid_shell && fvm flutter test test/widget/tab_trace_test.dart; cd ..
fvm dart test tool/test/tab_trace_compare_test.dart
```

Expected: FAIL, because `debugTabTrace` and `tab_trace_compare.dart` are undefined.

- [ ] **Step 3: Implement**

In `glass_tab_bar.dart`:

```dart
/// Acceptance traces (spec VK-503 §17.4): called once per bar tick with
/// the global lens centre and the frame's scalars. Reset to null after use.
@visibleForTesting
void Function(Map<String, double> sample)? debugTabTrace;
```

At the end of `_onTick`, before `setState`:

```dart
    final trace = debugTabTrace;
    if (trace != null && mounted) {
      final box = context.findRenderObject() as RenderBox?;
      final f = m.frame;
      final centre = box == null
          ? f.lens.center
          : box.localToGlobal(f.lens.center);
      trace({
        't': elapsed.inMicroseconds / 1e6,
        'x': centre.dx,
        'y': centre.dy,
        'w': f.lens.width,
        'h': f.lens.height,
        'engage': f.engage,
        'scale': f.pillScale,
        'glow': f.glowOpacity,
        'glowD': f.glowDiameter,
        'pop': f.popScale,
        'morph': _minimize.value,
      });
    }
```

Export it: `export 'src/chrome/glass_tab_bar.dart' show debugTabLensPress, debugTabTrace;`.

```json
// docs/qa/vk503/native_reference.json  (JSON has no comments: omit this line)
{
  "source": "vankhan .superpowers/sdd/tabfid-research.md, iPhone 17 Pro iOS 26.5 (402 x 874 pt), CADisplayLink layer traces and least-squares fits",
  "geometry": {
    "pill3": [64, 791, 274, 62],
    "slots3": [[68, 795, 94, 54], [154, 795, 94, 54], [240, 795, 94, 54]],
    "minimized": [28, 798, 48, 48],
    "tolerance": 1
  },
  "springs": {
    "tap": {"zeta": 0.79, "response": 0.39, "delay": 0.025},
    "dragFollow": {"zeta": 0.75, "response": 0.33},
    "snap": {"zeta": 0.92, "response": 0.35},
    "collapse": {"zeta": 0.80, "response": 0.30, "delay": 0.24},
    "expand": {"zeta": 0.70, "response": 0.35},
    "tolerance": 0.10
  },
  "press": {"w": 110, "h": 70, "scale": 1.052, "glow": 0.28},
  "flight": {"oneSlotHeight": 1.55, "twoSlotWidth": 1.33, "pop": 1.16},
  "glow": {"diameter": 93, "opacity": 0.28, "ripple": 4, "fade": 0.5},
  "colors": {"lensOverWhite": [236, 236, 236], "tolerance": 4}
}
```

```dart
// tool/tab_trace_compare.dart
// Compares Flutter tab bar traces (integration_test reportData) with the
// native reference fits (spec VK-503 §17.4). Pure Dart.
//
// Usage: dart run tool/tab_trace_compare.dart <response.json> <reference.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// One check's outcome.
typedef Check = ({bool pass, String detail});

/// Closed-form step response of a unit-mass spring of damping ratio
/// [zeta] and period [response], from 0 toward [distance], at [t].
double springAt(double distance, double zeta, double response, double t) {
  if (t <= 0) return 0;
  final w = 2 * math.pi / response;
  if (zeta < 1) {
    final wd = w * math.sqrt(1 - zeta * zeta);
    final e = math.exp(-zeta * w * t);
    return distance *
        (1 - e * (math.cos(wd * t) + zeta * w / wd * math.sin(wd * t)));
  }
  if (zeta == 1) {
    return distance * (1 - math.exp(-w * t) * (1 + w * t));
  }
  final s = math.sqrt(zeta * zeta - 1);
  final r1 = -w * (zeta - s);
  final r2 = -w * (zeta + s);
  final c2 = r1 / (r2 - r1);
  final c1 = -1 - c2;
  return distance * (1 + c1 * math.exp(r1 * t) + c2 * math.exp(r2 * t));
}

/// Time (one sample per [dt]) after which [xs] stays within [tol] of
/// [target].
double settle(List<double> xs, double target, {double dt = 1 / 60, double tol = 0.5}) {
  var last = -1;
  for (var i = 0; i < xs.length; i++) {
    if ((xs[i] - target).abs() > tol) last = i;
  }
  return (last + 1) * dt;
}

/// Steady lag of a spring following a ramp of [speed].
double rampLag(double speed, double zeta, double response) =>
    speed * 2 * zeta / (2 * math.pi / response);

/// [value] against [reference] within [abs] or [rel].
Check within(double value, double reference, {double? abs, double? rel}) {
  final tol = abs ?? (rel! * reference.abs());
  final ok = (value - reference).abs() <= tol;
  return (
    pass: ok,
    detail: '${value.toStringAsFixed(3)} vs ${reference.toStringAsFixed(3)} '
        '(±${tol.toStringAsFixed(3)})',
  );
}

/// The settle time of a tap trace against the reference spring ±10 %.
Check checkTap(
  List<Map<String, double>> trace, {
  required double from,
  required double to,
  required double zeta,
  required double response,
  required double delay,
}) {
  final xs = [for (final s in trace) s['x']!];
  final ref = [
    for (final s in trace)
      s['t']! < delay
          ? from
          : from + springAt(to - from, zeta, response, s['t']! - delay),
  ];
  return within(settle(xs, to), settle(ref, to), rel: 0.10);
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: tab_trace_compare.dart <response.json> <reference.json>');
    exit(64);
  }
  final response = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final reference = jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final data = response['tabfid']! as Map<String, dynamic>;
  final seqs = (data['sequences']! as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, [
      for (final s in v as List<dynamic>)
        (s as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
    ]),
  );
  final springs = reference['springs']! as Map<String, dynamic>;
  Map<String, dynamic> spring(String name) => springs[name]! as Map<String, dynamic>;
  double d(Map<String, dynamic> m, String k) => (m[k]! as num).toDouble();
  final rows = <(String, Check)>[];

  // Geometry (±1 pt).
  final geometry = reference['geometry']! as Map<String, dynamic>;
  final measured = data['geometry']! as Map<String, dynamic>;
  for (final key in ['pill3', 'minimized']) {
    final want = [for (final v in geometry[key]! as List<dynamic>) (v as num).toDouble()];
    final got = [for (final v in measured[key]! as List<dynamic>) (v as num).toDouble()];
    for (var i = 0; i < 4; i++) {
      rows.add(('$key[$i]', within(got[i], want[i], abs: d(geometry, 'tolerance'))));
    }
  }

  // Taps (settle ±10 %).
  final tap = spring('tap');
  for (final (name, from, to) in [
    ('tap_1_2', 115.0, 201.0),
    ('tap_2_3', 201.0, 287.0),
    ('tap_3_1', 287.0, 115.0),
  ]) {
    final trace = seqs[name]!;
    final t0 = trace.first['t']!;
    final shifted = [for (final s in trace) {...s, 't': s['t']! - t0}];
    rows.add((
      '$name settle',
      checkTap(shifted, from: from, to: to, zeta: d(tap, 'zeta'),
          response: d(tap, 'response'), delay: d(tap, 'delay')),
    ));
  }

  // Flight peaks (±10 %).
  final flight = reference['flight']! as Map<String, dynamic>;
  final oneSlot = seqs['tap_1_2']!;
  rows.add((
    'one-slot lift',
    within(oneSlot.map((s) => s['h']! / 54).reduce(math.max),
        d(flight, 'oneSlotHeight'), rel: 0.10),
  ));
  rows.add((
    'two-slot stretch',
    within(seqs['tap_3_1']!.map((s) => s['w']! / 94).reduce(math.max),
        d(flight, 'twoSlotWidth'), rel: 0.10),
  ));
  rows.add((
    'icon pop',
    within(oneSlot.map((s) => s['pop']!).reduce(math.max), d(flight, 'pop'),
        abs: 0.02),
  ));

  // Press and hold.
  final press = reference['press']! as Map<String, dynamic>;
  final held = seqs['press_hold']!.last;
  rows
    ..add(('press width', within(held['w']!, d(press, 'w'), abs: 2)))
    ..add(('press height', within(held['h']!, d(press, 'h'), abs: 2)))
    ..add(('press scale', within(held['scale']!, d(press, 'scale'), abs: 0.005)))
    ..add(('press glow', within(held['glow']!, d(press, 'glow'), abs: 0.03)));

  // Drag lag at 90 pt/s (±10 % of the follow spring's ramp lag).
  final drag = seqs['slow_drag']!;
  final follow = spring('dragFollow');
  final mid = drag[drag.length ~/ 2];
  rows.add((
    'drag lag',
    within(mid['finger']! - mid['x']!,
        rampLag(90, d(follow, 'zeta'), d(follow, 'response')), rel: 0.10),
  ));

  // Minimize (settle ±10 %).
  final collapse = spring('collapse');
  final morph = seqs['minimize']!;
  final m0 = morph.first['t']!;
  final ms = [for (final s in morph) s['morph']!];
  final mref = [
    for (final s in morph)
      s['t']! - m0 < d(collapse, 'delay')
          ? 0.0
          : springAt(1, d(collapse, 'zeta'), d(collapse, 'response'),
              s['t']! - m0 - d(collapse, 'delay')),
  ];
  rows.add((
    'collapse settle',
    within(settle(ms, 1, tol: 0.005), settle(mref, 1, tol: 0.005), rel: 0.10),
  ));

  var failed = 0;
  stdout.writeln('| check | result | detail |\n|---|---|---|');
  for (final (name, check) in rows) {
    if (!check.pass) failed++;
    stdout.writeln('| $name | ${check.pass ? 'pass' : 'FAIL'} | ${check.detail} |');
  }
  stdout.writeln(failed == 0 ? '✓ all ${rows.length} checks pass' : '✗ $failed of ${rows.length} failed');
  exit(failed == 0 ? 0 : 1);
}
```

```dart
// liquid_shell/example/integration_test/tab_fidelity_test.dart
// Flutter liquid tab bar traces for the acceptance (spec VK-503 §17.4).
// tool/tab_frames.sh runs it on an iOS 26.5 iPhone 17 Pro simulator;
// tool/tab_trace_compare.dart reads build/integration_response_data.json.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';

const _y = 874.0 - 21 - 31;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('tab bar traces', (tester) async {
    await LiquidGlass.precache();
    await tester.pumpWidget(
      const MaterialApp(
        home: LiquidGlassScope(
          policy: LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid),
          child: BasicTabsCase(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sequences = <String, List<Map<String, double>>>{};
    var current = <Map<String, double>>[];
    var finger = 0.0;
    debugTabTrace = (s) => current.add({...s, 'finger': finger});
    addTearDown(() => debugTabTrace = null);

    Future<void> idle() => tester.pump(const Duration(seconds: 1));
    Future<void> record(String name, Future<void> Function() body) async {
      await idle();
      current = [];
      await body();
      await tester.pumpAndSettle();
      sequences[name] = current;
    }

    final pill = tester.getRect(find.byKey(const ValueKey('liquid-tab-pill')));
    final geometry = <String, List<double>>{
      'pill3': [pill.left, pill.top, pill.width, pill.height],
    };

    Future<void> tap(double x) async {
      finger = x;
      await tester.tapAt(Offset(x, _y));
    }

    await record('tap_1_2', () => tap(201));
    await record('tap_2_3', () => tap(287));
    await record('tap_3_1', () => tap(115));
    await record('press_hold', () async {
      finger = 115;
      final g = await tester.startGesture(const Offset(115, _y));
      await tester.pump(const Duration(seconds: 1));
      sequences['press_hold_snapshot'] = List.of(current);
      await g.up();
    });
    // The "held" sample is the last one before the release.
    sequences['press_hold'] = sequences.remove('press_hold_snapshot')!;
    await record('slow_drag', () async {
      finger = 115;
      final g = await tester.startGesture(const Offset(115, _y));
      for (var i = 1; i <= 115; i++) {
        finger = 115 + 90 * i / 60;
        await g.moveTo(Offset(finger, _y));
        await tester.pump(const Duration(milliseconds: 16, microseconds: 667));
      }
      await g.up();
    });
    await record('fast_flick', () async {
      finger = 287;
      final g = await tester.startGesture(const Offset(287, _y));
      for (var i = 1; i <= 7; i++) {
        finger = 287 - 172 * i / 7;
        await g.moveTo(Offset(finger, _y));
        await tester.pump(const Duration(milliseconds: 16, microseconds: 667));
      }
      await g.up();
    });
    await record('minimize', () async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    });
    final circle = tester.getRect(find.byKey(const ValueKey('liquid-tab-pill')));
    geometry['minimized'] = [circle.left, circle.top, circle.width, circle.height];
    await record('expand', () => tester.tapAt(circle.center));

    binding.reportData = {
      'tabfid': {'geometry': geometry, 'sequences': sequences},
    };
  });
}
```

The literal keys `ValueKey('liquid-tab-pill')` equal `kTabPillKey`, which is internal. The example cannot import `src/`.

In the `Makefile` (add `tab-traces` to `.PHONY`):

```make
tab-traces: ## Flutter tab traces on an iOS 26.5 iPhone 17 Pro simulator vs the native reference (spec VK-503 §17.4)
	FLUTTER="$(FLUTTER)" DART="$(DART)" TRACES_ONLY=1 tool/tab_frames.sh
	$(DART) run tool/tab_trace_compare.dart $(EXAMPLE)/build/integration_response_data.json docs/qa/vk503/native_reference.json
```

`tool/tab_frames.sh` comes in Task 15. Until then `make tab-traces` is not runnable, and Step 4 does not call it.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd liquid_shell && fvm flutter test test/widget/tab_trace_test.dart && cd ..
fvm dart test tool/test/tab_trace_compare_test.dart
make test && make analyze
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
fvm dart format liquid_shell tool
bash .githooks/pre-commit
git add liquid_shell/lib liquid_shell/test/widget/tab_trace_test.dart liquid_shell/example/integration_test/tab_fidelity_test.dart tool/tab_trace_compare.dart tool/test/tab_trace_compare_test.dart docs/qa/vk503/native_reference.json Makefile
git commit -m "ci(ci): tab trace capture and comparison against the native fits (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: 60 fps frame strips: native vs Flutter liquid

**Files:**
- Create: `tool/tab_frames.sh`
- Create: `tool/tab_strips.dart`, `tool/test/tab_strips_test.dart`
- Create: `liquid_shell/example/ios/RunnerUITests/TabFidelityUITests.swift`
- Modify: `liquid_shell/example/lib/main.dart` (demos `tabs` and `tabs-liquid`)
- Modify: `Makefile` (target `tab-frames`)

**Interfaces:**
- Consumes:
  - Task 14 (the integration test, which prints a `TABFID <name>` marker line at each sequence start);
  - the existing `tool/compress_pngs.dart` (PNG decode/encode) and `tool/side_by_side.dart` (`scaleToHeight`).
- Produces:
  - `dart run tool/tab_strips.dart <nativeFramesDir> <flutterFramesDir> <outDir> --band <topPx>:<heightPx> --every 3 --rows 18`;
  - `int? nextOnset(List<Rgba> frames, int from, {double threshold, int still})`;
  - `make tab-frames`.

- [ ] **Step 1: Write the failing test**

```dart
// tool/test/tab_strips_test.dart
import 'dart:typed_data';

import 'package:test/test.dart';

import '../tab_strips.dart';

Rgba _frame(int value) => (
  width: 4,
  height: 4,
  pixels: Uint8List(64)..fillRange(0, 64, value),
);

void main() {
  test('nextOnset finds the first change after a still run', () {
    final frames = [
      for (var i = 0; i < 40; i++) _frame(10),
      for (var i = 0; i < 10; i++) _frame(10 + 20 * (i + 1)),
      for (var i = 0; i < 40; i++) _frame(210),
      for (var i = 0; i < 5; i++) _frame(100),
    ];
    final first = nextOnset(frames, 0, threshold: 4, still: 30);
    expect(first, 40);
    final second = nextOnset(frames, first! + 1, threshold: 4, still: 30);
    expect(second, 90);
    expect(nextOnset(frames, second! + 1, threshold: 4, still: 30), isNull);
  });

  test('a strip stacks [rows] pairs, one per [every] frames', () {
    final native = [for (var i = 0; i < 60; i++) _frame(i)];
    final flutter = [for (var i = 0; i < 60; i++) _frame(255 - i)];
    final strip = composeStrip(
      native, 0, flutter, 0,
      every: 3, rows: 4, gap: 2,
    );
    expect(strip.width, 4 + 2 + 4);
    expect(strip.height, 4 * 4 + 3 * 2);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm dart test tool/test/tab_strips_test.dart`
Expected: FAIL, because `tab_strips.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// tool/tab_strips.dart
// Native vs Flutter liquid tab bar frame strips (spec VK-503 §17.4).
// Each recording is a folder of 60 fps PNG frames (ffmpeg). The k-th
// motion onset in the bar band of one recording is paired with the k-th
// in the other; each strip shows [rows] pairs, one every [every] frames,
// native on the left. Pure Dart: reuses compress_pngs.dart.
//
// Usage: dart run tool/tab_strips.dart <native> <flutter> <out>
//          --band <top>:<height> [--every 3] [--rows 18]
import 'dart:io';
import 'dart:typed_data';

import 'compress_pngs.dart' show decodePng;
import 'side_by_side.dart' show Rgba, encodeRgbaPng, scaleToHeight;

export 'side_by_side.dart' show Rgba;

/// Mean absolute difference per channel between two equal-size frames.
double frameDiff(Rgba a, Rgba b) {
  var sum = 0;
  for (var i = 0; i < a.pixels.length; i++) {
    sum += (a.pixels[i] - b.pixels[i]).abs();
  }
  return sum / a.pixels.length;
}

/// The first frame at or after [from] that differs from its predecessor
/// by more than [threshold], after at least [still] unchanged frames.
int? nextOnset(
  List<Rgba> frames,
  int from, {
  double threshold = 3,
  int still = 30,
}) {
  var calm = 0;
  for (var i = from == 0 ? 1 : from; i < frames.length; i++) {
    final moving = frameDiff(frames[i - 1], frames[i]) > threshold;
    if (moving && calm >= still) return i;
    calm = moving ? 0 : calm + 1;
  }
  return null;
}

/// [rows] pairs (native left, Flutter right) from the two onsets, one every
/// [every] frames, separated by [gap] white pixels.
Rgba composeStrip(
  List<Rgba> native,
  int nativeStart,
  List<Rgba> flutter,
  int flutterStart, {
  int every = 3,
  int rows = 18,
  int gap = 8,
}) {
  final left = native[nativeStart];
  final rowHeight = left.height;
  final pairs = <(Rgba, Rgba)>[];
  for (var r = 0; r < rows; r++) {
    final n = native[(nativeStart + r * every).clamp(0, native.length - 1)];
    final f = scaleToHeight(
      flutter[(flutterStart + r * every).clamp(0, flutter.length - 1)],
      rowHeight,
    );
    pairs.add((n, f));
  }
  final width = left.width + gap + pairs.first.$2.width;
  final height = rows * rowHeight + (rows - 1) * gap;
  final out = Uint8List(width * height * 4)..fillRange(0, width * height * 4, 255);
  for (final (r, (n, f)) in pairs.indexed) {
    final top = r * (rowHeight + gap);
    for (var y = 0; y < rowHeight; y++) {
      final row = (top + y) * width * 4;
      out.setRange(row, row + n.width * 4, n.pixels, y * n.width * 4);
      final fx = row + (n.width + gap) * 4;
      out.setRange(fx, fx + f.width * 4, f.pixels, y * f.width * 4);
    }
  }
  return (width: width, height: height, pixels: out);
}

Rgba _crop(Rgba image, int top, int height) {
  final h = height.clamp(0, image.height - top);
  final out = Uint8List(image.width * h * 4);
  out.setRange(0, out.length, image.pixels, top * image.width * 4);
  return (width: image.width, height: h, pixels: out);
}

List<Rgba> _load(String dir, int top, int height) {
  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      () {
        final png = decodePng(f.readAsBytesSync());
        return _crop(
          (width: png.width, height: png.height, pixels: png.rgba),
          top,
          height,
        );
      }(),
  ];
}

void main(List<String> args) {
  if (args.length < 5 || args[3] != '--band') {
    stderr.writeln('usage: tab_strips.dart <native> <flutter> <out> --band <top>:<height> [--every N] [--rows N]');
    exit(64);
  }
  final band = args[4].split(':').map(int.parse).toList();
  int opt(String name, int fallback) {
    final i = args.indexOf(name);
    return i < 0 ? fallback : int.parse(args[i + 1]);
  }
  final every = opt('--every', 3);
  final rows = opt('--rows', 18);
  final native = _load(args[0], band[0], band[1]);
  final flutter = _load(args[1], band[0], band[1]);
  Directory(args[2]).createSync(recursive: true);
  var n = 0;
  var f = 0;
  for (var k = 1;; k++) {
    final a = nextOnset(native, n);
    final b = nextOnset(flutter, f);
    if (a == null || b == null) break;
    final strip = composeStrip(native, a, flutter, b, every: every, rows: rows);
    File('${args[2]}/frames_$k.png').writeAsBytesSync(encodeRgbaPng(strip));
    stdout.writeln('frames_$k.png: native @$a, flutter @$b');
    n = a + every * rows;
    f = b + every * rows;
  }
}
```

```swift
// liquid_shell/example/ios/RunnerUITests/TabFidelityUITests.swift
import XCTest

/// Drives the native tab bar through the acceptance sequences of spec
/// VK-503 §17.4 while tool/tab_frames.sh records the screen. Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=tabs (the basic case, native chrome).
/// Coordinates are in points on the iPhone 17 Pro (402 × 874).
final class TabFidelityUITests: XCTestCase {
  private let y: CGFloat = 874 - 21 - 31

  private func point(_ app: XCUIApplication, _ x: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: x, dy: y))
  }

  private func idle() { Thread.sleep(forTimeInterval: 1.0) }

  func testSequences() {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "tabs"
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60))
    idle(); idle()
    // tap_1_2, tap_2_3, tap_3_1
    for x: CGFloat in [201, 287, 115] { point(app, x).tap(); idle() }
    // press_hold
    point(app, 115).press(forDuration: 1.0); idle()
    // slow_drag: 115 → 287 at 90 pt/s
    point(app, 115).press(
      forDuration: 0.05, thenDragTo: point(app, 287),
      withVelocity: XCUIGestureVelocity(90), thenHoldForDuration: 0.3)
    idle()
    // fast_flick: 287 → 115 at 1500 pt/s
    point(app, 287).press(
      forDuration: 0.05, thenDragTo: point(app, 115),
      withVelocity: XCUIGestureVelocity(1500), thenHoldForDuration: 0)
    idle()
    // minimize, then expand by a tap on the circle
    app.swipeUp(); idle()
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 52, dy: 822)).tap()
    idle()
  }
}
```

In `liquid_shell/example/lib/main.dart`, extend the `switch (demo)`:

```dart
      'tabs' || 'tabs-liquid' => const CaseFrame(child: BasicTabsCase()),
```

In `initState` of the app state (where `_mode` is created), set `_mode.value = ExampleChromeMode.flutterLiquid` when `widget.demo == 'tabs-liquid'`. Import `cases/basic_tabs.dart`. In `tab_fidelity_test.dart` (Task 14), add `debugPrint('TABFID $name');` as the first line inside `record`. The script uses these markers only for its log: strip alignment is by motion onset.

```bash
#!/usr/bin/env bash
# tool/tab_frames.sh — native vs Flutter liquid tab bar, 60 fps frame
# strips and traces (spec VK-503 §17.4). Creates its own iOS 26.5 iPhone
# 17 Pro simulator and deletes it. Needs ffmpeg (brew install ffmpeg).
#
# TRACES_ONLY=1  only the Flutter traces (make tab-traces)
# IOS_RUNTIME    simctl runtime (default iOS 26.5)
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IOS_RUNTIME=${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}
command -v ffmpeg >/dev/null || [ "${TRACES_ONLY:-}" = 1 ] || {
  echo "✗ tab_frames.sh needs ffmpeg (brew install ffmpeg)" >&2; exit 1; }

udid=$(xcrun simctl create "vk503-tabfid" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$IOS_RUNTIME")
cleanup() { xcrun simctl delete "$udid" || true; }
trap cleanup EXIT
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl ui "$udid" appearance light

out=build/tabfid
command rm -rf "$out"
mkdir -p "$out"/native "$out"/flutter

record() { # <name> <command...>
  local name=$1; shift
  xcrun simctl io "$udid" recordVideo --codec=h264 --force "$out/$name.mp4" &
  local rec=$!
  sleep 2
  "$@"
  sleep 1
  kill -INT "$rec"; wait "$rec" || true
}

# shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
flutter_run() { "$tool_dir/with_timeout.sh" 1800 $FLUTTER drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/tab_fidelity_test.dart -d "$udid"; }

if [ "${TRACES_ONLY:-}" = 1 ]; then
  flutter_run
  echo "✓ traces in liquid_shell/example/build/integration_response_data.json"
  exit 0
fi

record flutter flutter_run

# The native run: the example's RunnerUITests on the same simulator.
$FLUTTER build ios --simulator --debug
record native xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination "id=$udid" -only-testing:RunnerUITests/TabFidelityUITests \
  -parallel-testing-enabled NO

for mode in native flutter; do
  ffmpeg -loglevel error -i "$out/$mode.mp4" -vf fps=60 "$out/$mode/%05d.png"
done
# The bar band: the bottom 160 pt at @3x.
$DART run "$tool_dir/tab_strips.dart" "$out/native" "$out/flutter" \
  "$out/strips" --band $(( (874 - 160) * 3 )):$(( 160 * 3 )) --every 3 --rows 18
echo "✓ strips in liquid_shell/example/build/tabfid/strips/"
```

In the `Makefile` (add `tab-frames` to `.PHONY`):

```make
tab-frames: ## Native vs Flutter liquid tab bar strips at 60 fps on an iOS 26.5 simulator (needs ffmpeg)
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/tab_frames.sh
```

`chmod +x tool/tab_frames.sh`.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm dart test tool/test/tab_strips_test.dart
make analyze
bash -n tool/tab_frames.sh
```

Expected: PASS. The script itself runs in Task 16, because it needs a simulator.

- [ ] **Step 5: Commit**

```bash
fvm dart format tool liquid_shell/example
bash .githooks/pre-commit
git add tool/tab_frames.sh tool/tab_strips.dart tool/test/tab_strips_test.dart liquid_shell/example/ios/RunnerUITests/TabFidelityUITests.swift liquid_shell/example/lib/main.dart liquid_shell/example/integration_test/tab_fidelity_test.dart Makefile
git commit -m "ci(ci): 60 fps native vs Flutter liquid tab bar frame strips (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

> If the new Swift file is not part of the `RunnerUITests` target, `xcodebuild -only-testing:RunnerUITests/TabFidelityUITests` runs zero tests and the native video shows nothing. Check it in `ios/Runner.xcodeproj/project.pbxproj`: the `SearchUITests.swift` entries show the four places a file is listed. Add `TabFidelityUITests.swift` the same way, and commit the `.pbxproj` with this task.

---

### Task 16: Acceptance run, one tuning round, final verification

**Files:**
- Create: `docs/qa/vk503/acceptance.md`
- Possibly modify: `liquid_shell/lib/src/chrome/tab_springs.dart` (envelope constants only), `liquid_shell/lib/src/glass/glass_theme.dart` (`liquidTint` / `selectionFill` defaults only)

**Interfaces:**
- Consumes: everything.
- Produces: the evidence for the owner and the PR body.

- [ ] **Step 1: Run the traces and the strips**

```bash
df -h /                       # ≥ 10 GB free
make tab-traces | tee /tmp/vk503-traces.txt
make tab-frames
```

Expected:
- `make tab-traces` ends with `✓ all N checks pass`, or lists the failures;
- `make tab-frames` writes `liquid_shell/example/build/tabfid/strips/frames_1.png …` (one per sequence: three taps, press, slow drag, flick, minimize, expand).

- [ ] **Step 2: If a trace check fails, tune once (no tolerance changes)**

These are the only permitted fixes:

| Failing check | Change |
|---|---|
| tap settle, collapse settle | none. These use the fitted springs verbatim. A failure means a bug in `LensMotion` or `MinimizeMotion`: debug with `superpowers:systematic-debugging` |
| one-slot lift, two-slot stretch | `TabSprings.liftGain`, `liftGateFar`, `stretchGain`, `stretchKnee` |
| icon pop | `TabSprings.popUntil` |
| press glow, press size | none (constants from research §4.1); debug |
| geometry | none; debug |

Re-run `make test` (the unit envelopes must still pass) and `make tab-traces`. Commit any change as `fix(shell): tune tab lens envelope against the native traces (VK-503)`, with the before/after table in the body.

- [ ] **Step 3: Review the strips against the native frames, and write the acceptance page**

Open each strip next to `vankhan/.superpowers/sdd/tabfid-shots/strips/native265_*.png`. Check:

- **Lens size and shape** at the same frame offsets.
- **Lens appearance.** The rest fill is gray. While moving, the lens is clear glass with a rainbow edge.
- **The icons.** The half-tinted icons while straddling, and the pop.
- **The bar.** The pill swell and the glow ripple.
- **Minimize.** The circle lands at x 28, and ⌕ shrinks about its centre.

If the rest pill in Flutter is visibly more transparent than native over the busy backdrop (research §5), do **one** tint round: change `liquidTint` alpha in `fromColorScheme` in steps of 0.05, never above 0.55. Re-run `make goldens-update` and `make tab-frames`. Commit as `fix(glass): liquid tint tuned against the native tab bar (VK-503)`.

Write `docs/qa/vk503/acceptance.md` with:
1. the date, the simulator and runtime, and the commit;
2. the `make tab-traces` table, pasted;
3. the strip list, with one line per strip saying what matches and what differs;
4. the Q rows the owner accepted as "not 100 %" (Q14–Q21), each with one line on what is visible in the strips;
5. an "Owner on device" checklist: haptics on drag (Q6), the overall feel on a real iPhone and iPad with "Flutter liquid" forced, and the landscape phone bar.

- [ ] **Step 4: Final verification**

```bash
make verify 2>&1 | tail -40
```

Expected: `✓ verify passed`. Paste the output into the PR body (CLAUDE.md "Evidence").

- [ ] **Step 5: Commit, and hand the review package to the owner**

```bash
bash .githooks/pre-commit
git add docs/qa/vk503/acceptance.md
git commit -m "docs(docs): VK-503 acceptance traces and strips (VK-503)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

The controller publishes the strips and the table as an artifact page for the owner. Strips are build output, so they stay out of the repository except for the README subset regenerated by `make compare-images`. The OTA example build goes to the owner's devices through the vankhan OTA script, which the owner runs: nobody else touches devices. The owner's verdict is recorded on Plane VK-503. Then `superpowers:finishing-a-development-branch`.

---

## Self-review notes (plan author)

**Spec coverage.**

| Spec section | Task(s) |
|---|---|
| §5.1 compact | 1, 6 |
| §5.2 landscape | 11 |
| §5.3 top | 11 |
| §5.4 hit testing | 6 (test) |
| §6.1–6.3 cells, rest fill, mask | 6 |
| §6.4 theme | 4 |
| §7 lens | 5, 8 |
| §8.1–8.5 motion | 2, 3 |
| §8.6 recognizer | 7 |
| §8.7 commit, guard | 3, 7 |
| §8.8 drag targets | 9, 10 |
| §8.9 semantics | 6, 7 |
| §9 haptics | 7 |
| §10 minimize | 9 |
| §11 search | 10 |
| §12.1 compactHeight | 11 |
| §12.2 top row | 11 |
| §12.3 sidebar | 11 (and the badges in 6) |
| §13 accessibility | 3 (reduce motion), 5 (tiers), 6 (RTL), 7 (AX), 9 (reduce motion morph) |
| §14 icons | 6, 13 |
| §15 pocket | 12 |
| §16 API | 4, 11, 13 |
| §17 tests and acceptance | every task, plus 14–16 |
| §18 docs | 13 |

**Known judgement calls an implementer may hit.**

1. **Task 8's band goldens** depend on the liquid golden harness's existing `pumpGolden`.
2. **Task 11's landscape search row** keeps the portrait search rects. This is documented in the task, and native was not captured.
3. **Task 15's Swift file** must be added to the Xcode target (the note in the task).
4. **Task 5's Impeller probe** is the gate for R1. If it fails, stop and report: do not continue to Task 6.
