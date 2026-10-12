import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/lens_clip.dart';
import 'package:liquid_shell/src/segmented/segmented_control.dart';

import '../helpers/native_rows.dart';

const _titles = ['All', 'Songs', 'Places'];

/// The spec's label line at text scale 1 (spec VK-550 §5: 13 pt, 15.67).
const double _line = 15.67;

List<LiquidSegment> _segments([List<String> titles = _titles]) => [
  for (final t in titles) LiquidSegment(label: t),
];

Future<void> _pump(
  WidgetTester tester, {
  List<LiquidSegment>? segments,
  int? selected = 0,
  ValueChanged<int>? onChanged,
  bool disabled = false,
  bool expand = true,
  double width = 370,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  String? semanticLabel,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(402, 874) * 3;
  addTearDown(tester.view.reset);
  final control = LiquidSegmentedControl(
    segments: segments ?? _segments(),
    selectedIndex: selected,
    onChanged: disabled ? null : (onChanged ?? (_) {}),
    expand: expand,
    semanticLabel: semanticLabel,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      // A new brightness applies at once, not over AnimatedTheme's 200 ms.
      themeAnimationDuration: Duration.zero,
      home: LiquidGlassScope(
        // No shader in widget tests (as glass_tab_bar_test.dart).
        policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid),
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(402, 874),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: direction,
            child: Center(
              child: expand ? SizedBox(width: width, child: control) : control,
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _box(WidgetTester tester) =>
    tester.getRect(find.byType(LiquidSegmentedControl));

/// [r] (control-local) in global coordinates.
Rect _global(WidgetTester tester, Rect r) => r.shift(_box(tester).topLeft);

ClipPath _clip(WidgetTester tester, Key key) =>
    tester.widget<ClipPath>(find.byKey(key));

Color _fill(WidgetTester tester, Key key) =>
    (tester.widget<DecoratedBox>(find.byKey(key)).decoration as BoxDecoration)
        .color!;

/// [c] composited over the opaque [under], 0–255 channels.
List<int> _over(Color c, Color under) {
  final o = Color.alphaBlend(c, under);
  return [
    for (final v in [o.r, o.g, o.b]) (v * 255).round(),
  ];
}

void _closeRgb(List<int> actual, List<dynamic> native, num tolerance) {
  for (var i = 0; i < 3; i++) {
    expect(actual[i], closeTo(native[i] as num, tolerance), reason: '$i');
  }
}

Iterable<RenderParagraph> _paragraphs(WidgetTester tester, Key row) =>
    tester.renderObjectList<RenderParagraph>(
      find.descendant(of: find.byKey(row), matching: find.byType(RichText)),
    );

SemanticsNode _node(WidgetTester tester, String label) => tester.getSemantics(
  find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.label == label &&
        (w.properties.inMutuallyExclusiveGroup ?? false),
  ),
);

void main() {
  final ref = segmentReference();
  final geometry = ref['geometry'] as Map<String, dynamic>;
  final colors = ref['colors'] as Map<String, dynamic>;

  testWidgets('geometry: box 370 × 44, the 32 pt track centred, thumbs '
      'within ±1 of native (spike §2)', (tester) async {
    await _pump(tester);
    final box = _box(tester);
    expect(box.size, const Size(370, 44));
    // Spec §5 / Q-C: the 32 pt native track centred in the 44 pt box.
    final trackTop = (44 - (geometry['height'] as num)) / 2;
    expect(
      tester.getRect(find.byKey(kSegmentTrackKey)),
      _global(tester, Rect.fromLTWH(0, trackTop, 370, 32)),
    );
    final thumbs = (geometry['thumbs3'] as List).cast<List<dynamic>>();
    final tolerance = geometry['tolerance'] as num;
    for (var i = 0; i < 3; i++) {
      await _pump(tester, selected: i);
      final thumb = tester
          .getRect(find.byKey(kSegmentThumbKey))
          .shift(-_box(tester).topLeft);
      final native = thumbs[i];
      expect(thumb.left, closeTo(native[0] as num, tolerance), reason: '$i');
      expect(thumb.top, closeTo(trackTop + (native[1] as num), 1e-9));
      expect(thumb.width, closeTo(native[2] as num, tolerance), reason: '$i');
      expect(thumb.height, closeTo(native[3] as num, 1e-9));
    }
  });

  testWidgets('labels: unselected w400, selected copy w500 clipped to the '
      'thumb', (tester) async {
    await _pump(tester, selected: 1);
    final thumb = tester
        .getRect(find.byKey(kSegmentThumbKey))
        .shift(-_box(tester).topLeft);
    final normal = _clip(tester, kSegmentNormalKey).clipper! as LensClip;
    final selected = _clip(tester, kSegmentSelectedKey).clipper! as LensClip;
    expect(normal.inside, isFalse);
    expect(selected.inside, isTrue);
    // The clips fill the box, so their lens is the thumb, box-local.
    expect(normal.lens, rectMoreOrLessEquals(thumb));
    expect(selected.lens, rectMoreOrLessEquals(thumb));
    for (final p in _paragraphs(tester, kSegmentNormalKey)) {
      expect(p.text.style!.fontWeight, FontWeight.w400);
      expect(p.text.style!.fontSize, 13);
    }
    for (final p in _paragraphs(tester, kSegmentSelectedKey)) {
      expect(p.text.style!.fontWeight, FontWeight.w500);
      expect(p.text.style!.fontSize, 13);
    }
    // Every label is in both rows, once.
    expect(_paragraphs(tester, kSegmentNormalKey), hasLength(3));
    expect(_paragraphs(tester, kSegmentSelectedKey), hasLength(3));
  });

  testWidgets('labels: centred in their segment, label-coloured (spike §2)', (
    tester,
  ) async {
    await _pump(tester);
    final box = _box(tester);
    final songs = tester.getRect(
      find.descendant(
        of: find.byKey(kSegmentNormalKey),
        matching: find.text('Songs'),
      ),
    );
    expect(songs.center.dx, closeTo(box.left + 370 / 2, 1e-6));
    expect(songs.center.dy, closeTo(box.center.dy, 1e-6));
    expect(songs.height, closeTo(_line, 0.01));
    final label = (colors['lightLabel'] as List).cast<num>();
    final c = _paragraphs(tester, kSegmentNormalKey).first.text.style!.color!;
    _closeRgb(_over(c, const Color(0xFFFFFFFF)), label, 0);
  });

  testWidgets('colours: track and thumb match native, light and dark', (
    tester,
  ) async {
    final tolerance = colors['tolerance'] as num;
    await _pump(tester);
    _closeRgb(
      _over(_fill(tester, kSegmentTrackKey), const Color(0xFFFFFFFF)),
      colors['lightTrackOverWhite'] as List,
      tolerance,
    );
    _closeRgb(
      _over(
        _fill(tester, kSegmentThumbKey),
        Color.alphaBlend(
          _fill(tester, kSegmentTrackKey),
          const Color(0xFFFFFFFF),
        ),
      ),
      colors['lightThumb'] as List,
      tolerance,
    );
    final light = LiquidGlassTheme.of(
      tester.element(find.byType(LiquidSegmentedControl)),
    );
    expect(_fill(tester, kSegmentTrackKey), light.segmentTrack);
    expect(_fill(tester, kSegmentThumbKey), light.segmentThumb);

    await _pump(tester, brightness: Brightness.dark);
    final darkTrack = Color.alphaBlend(
      _fill(tester, kSegmentTrackKey),
      const Color(0xFF000000),
    );
    _closeRgb(
      _over(_fill(tester, kSegmentTrackKey), const Color(0xFF000000)),
      colors['darkTrackOverBlack'] as List,
      tolerance,
    );
    _closeRgb(
      _over(_fill(tester, kSegmentThumbKey), darkTrack),
      colors['darkThumbOverTrack'] as List,
      tolerance,
    );
    final c = _paragraphs(tester, kSegmentNormalKey).first.text.style!.color!;
    _closeRgb(
      _over(c, const Color(0xFF000000)),
      colors['darkLabel'] as List,
      0,
    );
    final dark = LiquidGlassTheme.of(
      tester.element(find.byType(LiquidSegmentedControl)),
    );
    expect(_fill(tester, kSegmentTrackKey), dark.segmentTrack);
    expect(_fill(tester, kSegmentThumbKey), dark.segmentThumb);
  });

  testWidgets('colours: an app theme overrides the track, thumb and labels', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(402, 874) * 3;
    addTearDown(tester.view.reset);
    final base = LiquidGlassTheme.fromColorScheme(const ColorScheme.light());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            base.copyWith(
              segmentTrack: const Color(0x33FF0000),
              segmentThumb: const Color(0xFF00FF00),
              segmentLabelStyle: base.segmentLabelStyle.copyWith(
                color: const Color(0xFF0000FF),
              ),
            ),
          ],
        ),
        home: Center(
          child: SizedBox(
            width: 370,
            child: LiquidSegmentedControl(
              segments: _segments(),
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(_fill(tester, kSegmentTrackKey), const Color(0x33FF0000));
    expect(_fill(tester, kSegmentThumbKey), const Color(0xFF00FF00));
    for (final row in [kSegmentNormalKey, kSegmentSelectedKey]) {
      for (final p in _paragraphs(tester, row)) {
        expect(p.text.style!.color, const Color(0xFF0000FF));
      }
    }
  });

  testWidgets('no selection: no thumb, every label w400', (tester) async {
    await _pump(tester, selected: null);
    expect(find.byKey(kSegmentThumbKey), findsNothing);
    expect(find.byKey(kSegmentSelectedKey), findsNothing);
    expect(_paragraphs(tester, kSegmentNormalKey), hasLength(3));
    expect(
      _node(tester, 'All'),
      matchesSemantics(
        label: 'All',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('semantics: one button per segment in a mutually exclusive '
      'group, the selected one selected (spec §8.5)', (tester) async {
    final handle = tester.ensureSemantics();
    final calls = <int>[];
    await _pump(
      tester,
      segments: const [
        LiquidSegment(label: 'All'),
        LiquidSegment(label: 'Songs', semanticLabel: 'All songs'),
        LiquidSegment(label: 'Places', enabled: false),
      ],
      onChanged: calls.add,
      semanticLabel: 'Search scope',
    );
    expect(
      _node(tester, 'All'),
      matchesSemantics(
        label: 'All',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      _node(tester, 'All songs'),
      matchesSemantics(
        label: 'All songs',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      _node(tester, 'Places'),
      matchesSemantics(
        label: 'Places',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasEnabledState: true,
      ),
    );
    // The container carries the control's label; the labels drawn in the
    // two rows add no nodes of their own.
    expect(find.bySemanticsLabel('Search scope'), findsOneWidget);
    expect(find.bySemanticsLabel('Songs'), findsNothing);

    // A semantics tap on another segment commits it, on the selected one
    // calls nothing (native sends no valueChanged, Task 1 tapOnSelected).
    tester.semantics.tap(find.semantics.byLabel('All songs'));
    tester.semantics.tap(find.semantics.byLabel('All'));
    expect(calls, [1]);
    handle.dispose();
  });

  testWidgets('tap targets: every segment is a 44 × 44 target or larger '
      '(spec §12.4)', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    // The hit area is the whole 44 pt box height, segment-wide, no gaps.
    final box = _box(tester);
    var left = box.left;
    for (final t in _titles) {
      final r = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == t,
        ),
      );
      expect(r.top, box.top);
      expect(r.height, 44);
      expect(r.left, closeTo(left, 1e-9));
      left = r.right;
    }
    expect(left, closeTo(box.right, 1e-9));
    handle.dispose();
  });

  testWidgets('tap targets: intrinsic single letters stay 44 wide (Q-C)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, segments: _segments(['A', 'B', 'C']), expand: false);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(_box(tester).size, const Size(3 * 44, 44));
    handle.dispose();
  });

  testWidgets('tap targets: expand in a slot narrower than 44 per segment '
      'keeps 44 pt segments and reports the overflow (Q-C)', (tester) async {
    await _pump(
      tester,
      segments: _segments(['1', '2', '3', '4', '5']),
      width: 200,
    );
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('220'));
    // Every segment's hit area is still 44 wide; the control is clipped to
    // the 200 pt slot.
    for (final t in ['1', '2', '3', '4']) {
      final r = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == t,
        ),
      );
      expect(r.width, closeTo(44, 1e-9), reason: t);
    }
  });

  testWidgets('disabled: onChanged null → opacity 0.5, no tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, disabled: true);
    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(LiquidSegmentedControl),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 0.5);
    for (final t in _titles) {
      expect(
        _node(tester, t),
        matchesSemantics(
          label: t,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: t == 'All',
          hasEnabledState: true,
        ),
      );
    }
    handle.dispose();
  });

  testWidgets('disabled segment: its labels at 0.5, a semantics tap calls '
      'nothing', (tester) async {
    final handle = tester.ensureSemantics();
    final calls = <int>[];
    await _pump(
      tester,
      segments: const [
        LiquidSegment(label: 'All'),
        LiquidSegment(label: 'Songs', enabled: false),
        LiquidSegment(label: 'Places'),
      ],
      onChanged: calls.add,
    );
    double opacityOf(Key row, String label) {
      final o = find.ancestor(
        of: find.descendant(of: find.byKey(row), matching: find.text(label)),
        matching: find.byType(Opacity),
      );
      return tester.widgetList<Opacity>(o).fold(1, (a, w) => a * w.opacity);
    }

    for (final row in [kSegmentNormalKey, kSegmentSelectedKey]) {
      expect(opacityOf(row, 'Songs'), 0.5);
      expect(opacityOf(row, 'Places'), 1);
    }
    tester.binding.rootPipelineOwner.semanticsOwner!.performAction(
      _node(tester, 'Songs').id,
      SemanticsAction.tap,
    );
    expect(calls, isEmpty);
    handle.dispose();
  });

  testWidgets('RTL: segment 0 at the right, native thumb; semantics in '
      'visual order', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, direction: TextDirection.rtl);
    final box = _box(tester);
    final all = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'All',
      ),
    );
    expect(all.right, closeTo(box.right, 1e-9));
    expect(ref['rtl'], containsPair('segment0Right', true));
    final native = ((ref['rtl'] as Map)['thumb0'] as List).cast<num>();
    final thumb = tester
        .getRect(find.byKey(kSegmentThumbKey))
        .shift(
          -box.topLeft,
        );
    expect(thumb.left, closeTo(native[0], geometry['tolerance'] as num));
    expect(thumb.width, closeTo(native[2], geometry['tolerance'] as num));
    // Traversal: right to left, so index order (the visual order in RTL).
    final container = _node(tester, 'All').parent!;
    final order = [
      for (final n in container.debugListChildrenInOrder(
        DebugSemanticsDumpOrder.traversalOrder,
      ))
        n.label,
    ];
    expect(order, _titles);
    handle.dispose();
  });

  testWidgets('text scale 2: track 2 × 15.67 + 16.33 tall; labels ellipsize '
      '(spec §12.3)', (tester) async {
    await _pump(tester, textScale: 3);
    // Capped at 2 (Q-D).
    final track = tester.getRect(find.byKey(kSegmentTrackKey));
    expect(track.height, closeTo(2 * _line + 16.33, 0.01));
    expect(_box(tester).height, closeTo(track.height, 0.01));
    final thumb = tester.getRect(find.byKey(kSegmentThumbKey));
    expect(thumb.height, closeTo(track.height - 4, 0.01));
    final places = _paragraphs(
      tester,
      kSegmentNormalKey,
    ).firstWhere((p) => p.text.toPlainText() == 'Places');
    expect(places.textScaler, const TextScaler.linear(2));
    expect(places.didExceedMaxLines, isTrue);
    expect(places.size.width, closeTo(370 / 3 - 18, 1e-6));
  });

  testWidgets('expand: false sizes to the widest Medium label + 18 per '
      'segment (spec §5)', (tester) async {
    await _pump(tester, expand: false);
    final theme = LiquidGlassTheme.of(
      tester.element(find.byType(LiquidSegmentedControl)),
    );
    // Measured here, in the spec's Medium weight; native's own widths
    // (16 / 39 / 40.67 → 177) are pinned in segment_geometry_test.dart.
    final widest = _titles
        .map(
          (t) => (TextPainter(
            text: TextSpan(
              text: t,
              style: theme.segmentLabelStyle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout()).width,
        )
        .reduce(math.max);
    final s = math.max<double>(44, widest.ceilToDouble() + 18);
    expect(_box(tester).size, Size(3 * s, 44));
  });

  testWidgets('no InkWell, no Material ink anywhere', (tester) async {
    await _pump(tester);
    final inside = find.descendant(
      of: find.byType(LiquidSegmentedControl),
      matching: find.byWidgetPredicate(
        (w) => w is InkWell || w is InkResponse || w is Material,
      ),
    );
    expect(inside, findsNothing);
  });

  testWidgets('asserts: fewer than 2 segments', (tester) async {
    await _pump(tester, segments: _segments(['Only']));
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('asserts: selectedIndex out of range', (tester) async {
    await _pump(tester, selected: 3);
    expect(tester.takeException(), isA<AssertionError>());
    await _pump(tester, selected: -1);
    expect(tester.takeException(), isA<AssertionError>());
  });
}
