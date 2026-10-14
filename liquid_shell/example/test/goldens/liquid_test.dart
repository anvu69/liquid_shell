@Tags(['liquid_golden'])
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
// The goldens hook is test-only and stays out of the public API (spec §16).
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart'
    show debugTabLensPress;
import 'package:liquid_shell/src/segmented/segmented_control.dart'
    show debugSegmentLensPress;
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/native_alerts.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/cases/segments.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';

import '../support/golden_harness.dart';

/// Changes one field of the default glass theme.
typedef _Adjust = LiquidGlassTheme Function(LiquidGlassTheme theme);

/// [child] under a theme whose glass is [adjust]ed.
Widget _themed(_Adjust adjust, Widget child) => Builder(
  builder: (context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: [
          adjust(LiquidGlassTheme.fromColorScheme(theme.colorScheme)),
        ],
      ),
      child: child,
    );
  },
);

/// Margin around the glass in a chrome-band image, in logical pixels.
const _bandMargin = 8.0;

/// The chrome band: every liquid surface on screen plus [_bandMargin].
Rect _chromeBand(WidgetTester tester) {
  Rect? band;
  for (final element
      in find
          .byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'LiquidBackdrop',
          )
          .evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    band = band?.expandToInclude(rect) ?? rect;
  }
  expect(band, isNotNull, reason: 'no liquid glass on screen');
  final screen = Offset.zero & tester.view.physicalSize / goldenPixelRatio;
  return band!.inflate(_bandMargin).intersect(screen);
}

/// Compares only the chrome band (or the band [around] one widget) with
/// `bands/<name>.png`, so the 0.5 % tolerance (Q12) is a share of the
/// glass, not of the whole screen: a change to the lens, the rim or the
/// dispersion fails it.
Future<void> _expectBand(
  WidgetTester tester,
  String name, {
  Finder? around,
}) async {
  final screen = Offset.zero & tester.view.physicalSize / goldenPixelRatio;
  final band = around == null
      ? _chromeBand(tester)
      : tester.getRect(around).inflate(_bandMargin).intersect(screen);
  final source = Rect.fromLTRB(
    (band.left * goldenPixelRatio).floorToDouble(),
    (band.top * goldenPixelRatio).floorToDouble(),
    (band.right * goldenPixelRatio).ceilToDouble(),
    (band.bottom * goldenPixelRatio).ceilToDouble(),
  );
  final cropped = await tester.runAsync(() async {
    final screen = await captureImage(tester.element(find.byType(MaterialApp)));
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      screen,
      source,
      Offset.zero & source.size,
      Paint(),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      source.width.toInt(),
      source.height.toInt(),
    );
    picture.dispose();
    screen.dispose();
    return image;
  });
  await expectLater(cropped, matchesGoldenFile('bands/$name.png'));
}

/// The pressed lens against native (spec §7.2 acceptance, from the Task 8
/// review): `coreStd` is the luminance spread of the flat core beside the
/// icon (inside the 14 pt ring, out of the icon column), `vivid` the share
/// of lens pixels with chroma above 60 and `p99` the 99th-percentile
/// chroma, the icon column excluded. Chroma is max − min of RGB; luminance
/// is ITU-R 601.
Future<
  ({
    double coreStd,
    double coreMean,
    double ringStd,
    double ringColour,
    double vivid,
    int p99,
  })
>
_lensMetrics(
  WidgetTester tester,
) async {
  final lens = tester.getRect(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidLens'),
  );
  final data = (await tester.runAsync(() async {
    final screen = await captureImage(tester.element(find.byType(MaterialApp)));
    final bytes = await screen.toByteData();
    screen.dispose();
    return bytes;
  }))!;
  final width = tester.view.physicalSize.width.round();
  const k = goldenPixelRatio;
  // The icon and label column, and the 14 pt refracting ring.
  const column = 22.0;
  const ring = 14.0;
  final r = lens.height / 2;
  bool inCapsule(double x, double y) {
    final c = x.clamp(lens.left + r, lens.right - r);
    return (x - c) * (x - c) + (y - lens.center.dy) * (y - lens.center.dy) <=
        r * r;
  }

  final chroma = <int>[];
  final luma = <double>[];
  final ringLuma = <double>[];
  var coloured = 0;
  var colouredInRing = 0;
  for (var py = (lens.top * k).floor(); py < (lens.bottom * k).ceil(); py++) {
    for (var px = (lens.left * k).floor(); px < (lens.right * k).ceil(); px++) {
      final x = (px + 0.5) / k;
      final y = (py + 0.5) / k;
      if (!inCapsule(x, y) || (x - lens.center.dx).abs() < column) continue;
      final i = (py * width + px) * 4;
      final rgb = [
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      ];
      final c = rgb.reduce(math.max) - rgb.reduce(math.min);
      chroma.add(c);
      final l = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
      final inCore = lens.deflate(ring).contains(Offset(x, y));
      (inCore ? luma : ringLuma).add(l);
      if (c > 30) {
        coloured++;
        if (!inCore) colouredInRing++;
      }
    }
  }
  chroma.sort();
  double meanOf(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  double stdOf(List<double> v) {
    final m = meanOf(v);
    return math.sqrt(
      v.map((l) => (l - m) * (l - m)).reduce((a, b) => a + b) / v.length,
    );
  }

  return (
    coreStd: stdOf(luma),
    coreMean: meanOf(luma),
    ringStd: stdOf(ringLuma),
    ringColour: coloured == 0 ? 0.0 : colouredInRing / coloured,
    vivid: chroma.where((c) => c > 60).length / chroma.length,
    p99: chroma[(0.99 * (chroma.length - 1)).floor()],
  );
}

void main() {
  setUp(() {
    // These goldens are the liquid tier; a run without Impeller is a
    // misconfiguration, not a frosted image to record.
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
  });

  Future<void> liquid(
    WidgetTester tester,
    String name,
    Widget child, {
    GoldenDevice device = iphone,
    Brightness brightness = Brightness.light,
    Future<void> Function()? interact,
  }) async {
    await tester.runAsync(LiquidGlass.precache);
    await pumpGolden(tester, child, device: device, brightness: brightness);
    if (interact != null) {
      await interact();
      await tester.pumpAndSettle();
    }
    await expectDocImage(tester, name);
  }

  for (final device in [iphone, ipadLandscape, android]) {
    for (final brightness in Brightness.values) {
      final name = 'liquid_hero_${device.name}_${brightness.name}';
      testWidgets(name, (tester) async {
        await liquid(
          tester,
          name,
          const SidebarSlotsCase(),
          device: device,
          brightness: brightness,
        );
      });
    }
  }

  testWidgets('case_tier_liquid', (tester) async {
    await liquid(
      tester,
      'case_tier_liquid',
      const ForcedTierCase(initialTier: LiquidGlassTier.liquid),
    );
  });

  // The engaged tab lens, frozen pressed: on Home, and straddling Home and
  // Explore (research native265_slowdrag.png), in light and dark.
  for (final (name, shift, brightness) in [
    ('tab_lens_pressed', 0.0, Brightness.light),
    ('tab_lens_straddle', 43.0, Brightness.light),
    ('tab_lens_pressed_dark', 0.0, Brightness.dark),
  ]) {
    testWidgets(name, (tester) async {
      debugTabLensPress = shift;
      addTearDown(() => debugTabLensPress = null);
      await tester.runAsync(LiquidGlass.precache);
      await pumpGolden(
        tester,
        const BasicTabsCase(),
        device: iphone,
        brightness: brightness,
      );
      await _expectBand(tester, name);
      if (shift != 0) return;
      // Native's held lens over the example's page (spec §7.2; Task 16
      // part B, the idb press strips, the same measure): a milky, flat
      // core with the page text hidden; a clear ring that shows the page
      // bent (its luma spread); colour in the ring, p99 chroma 58-76.
      //
      // | measure | native light | native dark |
      // |---|---|---|
      // | core std / mean | 4.5 / 243 | 9.3 / 61 |
      // | ring std | 24 | 24 |
      // | chroma > 60 | 1.3-1.8 % | 0.9 % |
      // | p99 chroma | 65-76 | 58 |
      // | colour (> 30) in the ring | 97-98 % | 100 % |
      final m = await _lensMetrics(tester);
      final seen = 'measured $m';
      final dark = brightness == Brightness.dark;
      expect(m.coreStd, lessThanOrEqualTo(dark ? 12 : 6), reason: seen);
      expect(m.coreMean, closeTo(dark ? 61 : 243, 10), reason: seen);
      expect(m.ringStd, greaterThanOrEqualTo(12), reason: seen);
      expect(m.ringColour, greaterThanOrEqualTo(0.9), reason: seen);
      expect(m.vivid, lessThanOrEqualTo(0.03), reason: seen);
      expect(m.p99, inInclusiveRange(45, 90), reason: seen);
    });
  }

  // The engaged segment lens, frozen pressed on the first segment and
  // straddling the first two (spec VK-550 §14.4), on the full-width
  // three-segment control: (393 − 2 × 16) / 3 = 120.3 pt per segment, so
  // half of one moves the lens onto the boundary.
  //
  // KNOWN WRONG, regenerate in Task 15 (VK-550, spec R8): these images pin
  // the current look, not an approved one. Native's held lens is clear
  // glass with the stripes refracted and a thin rim; ours has a milky core
  // and a thick black rim at its top and bottom. Task 15 tunes the lens
  // against the segment strips (make segment-frames), then regenerates
  // both through make goldens-update and compares them with native's.
  for (final (name, shift) in [
    ('segment_lens_pressed', 0.0),
    ('segment_lens_straddle', (393 - 2 * 16) / 3 / 2),
  ]) {
    testWidgets(name, (tester) async {
      debugSegmentLensPress = shift;
      addTearDown(() => debugSegmentLensPress = null);
      await tester.runAsync(LiquidGlass.precache);
      await pumpGolden(tester, const SegmentsCase(), device: iphone);
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidLens'),
        findsWidgets,
        reason: 'the engaged lens',
      );
      await _expectBand(
        tester,
        name,
        around: find.byKey(const ValueKey('segments-full3')),
      );
    });
  }

  // The finger glow on release: 98 pt under the held finger, then ×4 and
  // fading (research §4.1); 128 ms after the release it spills past the
  // lens onto the pill. Dark, where a white glow reads.
  testWidgets('tab_glow_release_dark', (tester) async {
    await tester.runAsync(LiquidGlass.precache);
    await pumpGolden(
      tester,
      const BasicTabsCase(),
      device: iphone,
      brightness: Brightness.dark,
    );
    // The bar draws the filled selectedIcon in every slot (spec §6.1).
    final home = tester.getCenter(find.byIcon(Icons.home).first);
    final finger = await tester.startGesture(home);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _expectBand(tester, 'tab_glow_release_dark');
  });

  // The Flutter glass dialogs are LiquidGlass (owner decision L3): on the
  // default tier they are liquid, like the shell.
  testWidgets('case_alert', (tester) async {
    await liquid(
      tester,
      'case_alert',
      const NativeAlertsCase(),
      interact: () => tester.tap(find.text('Alert')),
    );
  });

  testWidgets('case_action_sheet', (tester) async {
    await liquid(
      tester,
      'case_action_sheet',
      const NativeAlertsCase(),
      device: ipadPortrait,
      interact: () => tester.tap(find.text('Action sheet')),
    );
  });

  // The search tab's glass (the collapsed circle, the field, the top field
  // and the back button) is LiquidGlass: on the default tier it is liquid.
  int liquidSurfaces() => find
      .byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidBackdrop')
      .evaluate()
      .length;

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('case_search_phone_selected_liquid', (tester) async {
    await liquid(
      tester,
      'case_search_phone_selected_liquid',
      const SearchCase(),
      interact: () => openSearch(tester),
    );
    // The collapsed circle and the field.
    expect(liquidSurfaces(), greaterThanOrEqualTo(2));
  });

  testWidgets('case_search_tablet_selected_liquid', (tester) async {
    await liquid(
      tester,
      'case_search_tablet_selected_liquid',
      const SearchCase(),
      device: ipadPortrait,
      interact: () => openSearch(tester),
    );
    // The top bar and the field under it.
    expect(liquidSurfaces(), greaterThanOrEqualTo(2));
  });

  testWidgets('case_search_detail_liquid', (tester) async {
    await liquid(
      tester,
      'case_search_detail_liquid',
      const SearchCase(),
      interact: () async {
        await openSearch(tester);
        await tester.tap(find.text('Hà Nội').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hồ Hoàn Kiếm'));
      },
    );
    expect(
      find.descendant(
        of: find.byType(LiquidBackButton),
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'LiquidBackdrop',
        ),
      ),
      findsOneWidget,
      reason: 'the glass back button is liquid',
    );
  });

  // The brand theme on the default tier: its liquidTint must show.
  testWidgets('case_custom_theme_liquid', (tester) async {
    await liquid(tester, 'case_custom_theme_liquid', const CustomThemeCase());
  });

  // BasicTabs on an iPhone, one theme field changed at a time: the doc
  // image of each, and its chrome band as the regression check.
  for (final (name, adjust, brightness) in <(String, _Adjust, Brightness)>[
    ('liquid_default', (t) => t, Brightness.light),
    ('liquid_default_dark', (t) => t, Brightness.dark),
    ('liquid_refraction_0', (t) => t.copyWith(refraction: 0), Brightness.light),
    ('liquid_refraction_2', (t) => t.copyWith(refraction: 2), Brightness.light),
    (
      'liquid_dispersion_03',
      (t) => t.copyWith(dispersion: 0.3),
      Brightness.light,
    ),
  ]) {
    testWidgets(name, (tester) async {
      await liquid(
        tester,
        name,
        _themed(adjust, const BasicTabsCase()),
        brightness: brightness,
      );
      await _expectBand(tester, name);
    });
  }
}
