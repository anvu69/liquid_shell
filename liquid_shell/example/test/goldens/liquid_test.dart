@Tags(['liquid_golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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

/// The segment lens look (spec VK-550 §7, Task 15), as
/// `native_reference.json` `lens.lookMethod` measures native's: [pressed]
/// has the lens pressed at [lens], [page] the same pixels without it. The
/// core is inside the 9 pt ring, the ring the 9 pt bands at the top and
/// bottom of the straight part, both without the 22 pt label column.
/// Chroma ratios are of p95 (max − min of RGB), lens over page; luma (ITU-R
/// 601) p5 and p95, lens minus page.
Map<String, double> _segmentLook(
  ByteData pressed,
  ByteData page,
  Rect lens, {
  required int width,
}) {
  const k = goldenPixelRatio;
  const bezel = 9.0;
  const column = 22.0;
  final r = lens.height / 2;
  final core = <int>[];
  final ring = <int>[];
  for (var py = (lens.top * k).floor(); py < (lens.bottom * k).ceil(); py++) {
    for (var px = (lens.left * k).floor(); px < (lens.right * k).ceil(); px++) {
      final x = (px + 0.5) / k;
      final y = (py + 0.5) / k;
      final c = x.clamp(lens.left + r, lens.right - r);
      final inside =
          (x - c) * (x - c) + (y - lens.center.dy) * (y - lens.center.dy) <=
          r * r;
      if (!inside || (x - lens.center.dx).abs() < column) continue;
      final i = (py * width + px) * 4;
      if (lens.deflate(bezel).contains(Offset(x, y))) {
        core.add(i);
      } else if (x >= lens.left + r &&
          x <= lens.right - r &&
          (y < lens.top + bezel || y > lens.bottom - bezel)) {
        ring.add(i);
      }
    }
  }
  int pct(List<num> v, double p) {
    final s = [...v]..sort();
    return s[(p * (s.length - 1)).floor()].round();
  }

  ({int chroma95, double luma5, double luma95}) stats(
    ByteData d,
    List<int> at,
  ) {
    final chroma = <int>[];
    final luma = <double>[];
    for (final i in at) {
      final rgb = [d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2)];
      chroma.add(rgb.reduce(math.max) - rgb.reduce(math.min));
      luma.add(0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]);
    }
    luma.sort();
    return (
      chroma95: pct(chroma, 0.95),
      luma5: luma[(0.05 * (luma.length - 1)).floor()],
      luma95: luma[(0.95 * (luma.length - 1)).floor()],
    );
  }

  final a = stats(pressed, core);
  final b = stats(page, core);
  final c = stats(pressed, ring);
  final d = stats(page, ring);
  double round(double v) => (v * 1000).round() / 1000;
  final geometry = _segmentGeometry(pressed, page, lens, width: width);
  return {
    'coreChromaRatio': round(a.chroma95 / b.chroma95),
    'coreLuma5': round(a.luma5 - b.luma5),
    'coreLuma95': round(a.luma95 - b.luma95),
    'ringChromaRatio': round(c.chroma95 / math.max(1, d.chroma95)),
    'ringLuma5': round(c.luma5 - d.luma5),
    'ringLuma95': round(c.luma95 - d.luma95),
    'coreSqueeze': round(geometry.squeeze),
    'ringBend': round(geometry.bend),
  };
}

/// Where the lens reads the page (`native_reference.json`
/// `lens.lookGeometryMethod`): the example's stripes run at 45°, so a row
/// read from a page row higher or lower shows them shifted sideways. The
/// shift of rows 4–12 pt from the spine over their distance gives how
/// much farther out the page is read (`squeeze`, 1.22 for native's lens);
/// the mean shift of rows 1.5–6 pt in from the edges, the ring's `bend`.
({double squeeze, double bend}) _segmentGeometry(
  ByteData pressed,
  ByteData page,
  Rect lens, {
  required int width,
}) {
  const k = goldenPixelRatio;
  const column = 14.0;
  const window = 18.0;
  final r = lens.height / 2;
  final windows = <(int, int)>[
    for (final (from, to) in [
      (lens.left + r + 2, lens.center.dx - column),
      (lens.center.dx + column, lens.right - r - 2),
    ])
      for (var x = from; x + window <= to + 1e-6; x += window)
        ((x * k).floor(), ((x + window) * k).floor()),
  ];
  // The sideways shift (whole pixels) that best matches row [y] of the
  // lens to the same row of the page, over [x0, x1).
  double shift(int y, int x0, int x1) {
    var best = double.infinity;
    var at = 0;
    for (var dx = -40; dx <= 40; dx++) {
      var sum = 0.0;
      var n = 0;
      for (var x = x0; x < x1; x++) {
        final xx = x + dx;
        if (xx < 0 || xx >= width) continue;
        for (var c = 0; c < 3; c++) {
          final d =
              pressed.getUint8((y * width + x) * 4 + c) -
              page.getUint8((y * width + xx) * 4 + c);
          sum += d * d;
        }
        n++;
      }
      final mean = sum / math.max(n, 1);
      if (mean < best) {
        best = mean;
        at = dx;
      }
    }
    return at / k;
  }

  var sxy = 0.0;
  var sxx = 0.0;
  for (final off in [-12, -10, -8, -6, -4, 4, 6, 8, 10, 12]) {
    final y = ((lens.center.dy + off) * k).floor();
    for (final (x0, x1) in windows) {
      sxy += off * shift(y, x0, x1);
      sxx += off * off;
    }
  }
  final bends = <double>[
    for (final depth in [1.5, 3.0, 4.5, 6.0])
      for (final y in [
        ((lens.top + depth) * k).floor(),
        ((lens.bottom - depth) * k).floor(),
      ])
        for (final (x0, x1) in windows) shift(y, x0, x1).abs(),
  ];
  return (
    squeeze: 1 - sxy / sxx,
    bend: bends.reduce((a, b) => a + b) / bends.length,
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
  // half of one moves the lens onto the boundary. Clear glass, as native's
  // (Task 15; the look is gated against native below).
  const segment = (393 - 2 * 16) / 3;
  for (final (name, shift, brightness) in [
    ('segment_lens_pressed', 0.0, Brightness.light),
    ('segment_lens_straddle', segment / 2, Brightness.light),
    ('segment_lens_pressed_dark', 0.0, Brightness.dark),
  ]) {
    testWidgets(name, (tester) async {
      debugSegmentLensPress = shift;
      addTearDown(() => debugSegmentLensPress = null);
      await tester.runAsync(LiquidGlass.precache);
      await pumpGolden(
        tester,
        const SegmentsCase(),
        device: iphone,
        brightness: brightness,
      );
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

  // The held segment lens against native's (spec VK-550 §7, Task 15;
  // `native_reference.json` `lens.look`, measured the same way on the
  // native segment strips): the page passes almost as is, a thin rim,
  // and no dark ring. The lens pressed on segment 0, then the same pixels
  // with the lens on segment 2 as the page. Native, fitted (in sample):
  // `LensLook.segment` was tuned to these numbers, so this gate pins the
  // fit; `ringBend` includes the squeeze, so it checks the bezel's own
  // bend only weakly and does not see the fringe.
  for (final brightness in Brightness.values) {
    testWidgets('segment lens look against native (fitted, in sample), '
        '${brightness.name}', (
      tester,
    ) async {
      final reference =
          jsonDecode(
                File(
                  '../../docs/qa/vk550/native_reference.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final native =
          ((reference['lens'] as Map)['look'] as Map)[brightness.name] as Map;
      addTearDown(() => debugSegmentLensPress = null);
      await tester.runAsync(LiquidGlass.precache);
      final full3 = find.byKey(const ValueKey('segments-full3'));
      final lensFinder = find.descendant(
        of: full3,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'LiquidLens',
        ),
      );
      Future<ByteData> shot(double shift) async {
        debugSegmentLensPress = shift;
        await tester.pumpWidget(const SizedBox());
        await pumpGolden(
          tester,
          const SegmentsCase(),
          device: iphone,
          brightness: brightness,
        );
        return (await tester.runAsync(() async {
          final screen = await captureImage(
            tester.element(find.byType(MaterialApp)),
          );
          final bytes = await screen.toByteData();
          screen.dispose();
          return bytes;
        }))!;
      }

      final pressed = await shot(0);
      final lens = tester.getRect(lensFinder);
      final page = await shot(2 * segment);
      final m = _segmentLook(
        pressed,
        page,
        lens,
        width: tester.view.physicalSize.width.round(),
      );
      final seen = 'measured $m, native $native';
      for (final key in ['coreChromaRatio', 'ringChromaRatio']) {
        expect(
          m[key],
          closeTo((native[key] as num).toDouble(), 0.08),
          reason: '$key: $seen',
        );
      }
      for (final key in [
        'coreLuma5',
        'coreLuma95',
        'ringLuma5',
        'ringLuma95',
      ]) {
        expect(
          m[key],
          closeTo((native[key] as num).toDouble(), 12),
          reason: '$key: $seen',
        );
      }
      // Where it reads the page (Task 15 review): squeezed about 0.8 across
      // the height, bent a few points at the ring.
      expect(
        m['coreSqueeze'],
        closeTo((native['coreSqueeze'] as num).toDouble(), 0.05),
        reason: 'coreSqueeze: $seen',
      );
      expect(
        m['ringBend'],
        closeTo((native['ringBend'] as num).toDouble(), 1),
        reason: 'ringBend: $seen',
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
