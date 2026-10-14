import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/lens_clip.dart';
import 'package:liquid_shell/src/chrome/sf_tracking.dart';
import 'package:liquid_shell/src/chrome/sized_layout_builder.dart';
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
      // A new selectedIndex slides there (spec §8.3, programmatic).
      await tester.pumpAndSettle();
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

  testWidgets('tap targets: expand below 44 per segment shrinks the '
      'segments to fit, no overflow, every segment tappable (n = 5 at '
      '180)', (tester) async {
    final handle = tester.ensureSemantics();
    final calls = <int>[];
    const titles = ['One', 'Two', 'Three', 'Four', 'Five'];
    await _pump(
      tester,
      segments: _segments(titles),
      width: 180,
      onChanged: calls.add,
    );
    expect(tester.takeException(), isNull);
    final box = _box(tester);
    expect(box.size, const Size(180, 44));
    // Each hit box is its whole segment: equal, tiled, inside the control.
    var left = box.left;
    for (final t in titles) {
      final r = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == t,
        ),
      );
      expect(r.left, closeTo(left, 1e-9), reason: t);
      expect(r.width, closeTo(180 / 5, 1e-9), reason: t);
      expect(r.height, 44, reason: t);
      left = r.right;
    }
    expect(left, closeTo(box.right, 1e-9));
    for (final t in titles.skip(1)) {
      tester.semantics.tap(find.semantics.byLabel(t));
    }
    expect(calls, [1, 2, 3, 4]);
    // Labels wider than their segment ellipsize.
    final three = _paragraphs(
      tester,
      kSegmentNormalKey,
    ).firstWhere((p) => p.text.toPlainText() == 'Three');
    expect(three.didExceedMaxLines, isTrue);
    handle.dispose();
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
      // The paragraph: the lens copy is not a Text.
      final paragraph = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == label,
      );
      final o = find.ancestor(
        of: find.descendant(of: find.byKey(row), matching: paragraph),
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
    final s = _intrinsicSegment(_titles, theme.segmentLabelStyle);
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
  });

  test('asserts: a negative selectedIndex fails at the call site', () {
    expect(
      () => LiquidSegmentedControl(
        segments: _segments(),
        selectedIndex: -1,
        onChanged: null,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('expand: false in a parent narrower than the labels shrinks '
      'to fit like expand: every segment on screen and in semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final calls = <int>[];
    const titles = ['All', 'Recently played', 'Places'];
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(402, 874) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            child: Align(
              child: LiquidSegmentedControl(
                segments: _segments(titles),
                selectedIndex: 0,
                onChanged: calls.add,
                expand: false,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final box = _box(tester);
    expect(box.size, const Size(200, 44));
    var left = box.left;
    for (final t in titles) {
      final r = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == t,
        ),
      );
      expect(r.left, closeTo(left, 1e-9), reason: t);
      expect(r.width, closeTo(200 / 3, 1e-9), reason: t);
      left = r.right;
    }
    tester.semantics.tap(find.semantics.byLabel('Recently played'));
    tester.semantics.tap(find.semantics.byLabel('Places'));
    expect(calls, [1, 2]);
    handle.dispose();
  });

  testWidgets('expand: true under an unbounded width sizes to the labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            LiquidSegmentedControl(
              segments: _segments(),
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final theme = LiquidGlassTheme.of(
      tester.element(find.byType(LiquidSegmentedControl)),
    );
    final s = _intrinsicSegment(_titles, theme.segmentLabelStyle);
    expect(_box(tester).size, Size(3 * s, 44));
  });

  group('intrinsics (as fit_label.dart: no LayoutBuilder throw)', () {
    Future<void> pumpIn(WidgetTester tester, Widget Function(Widget) wrap) =>
        tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: wrap(
                LiquidSegmentedControl(
                  segments: _segments(),
                  selectedIndex: 1,
                  onChanged: (_) {},
                  expand: false,
                ),
              ),
            ),
          ),
        );

    double segment(WidgetTester tester) => _intrinsicSegment(
      _titles,
      LiquidGlassTheme.of(
        tester.element(find.byType(LiquidSegmentedControl)),
      ).segmentLabelStyle,
    );

    testWidgets('IntrinsicWidth in a Row: the width of the labels', (
      tester,
    ) async {
      await pumpIn(
        tester,
        (c) => Row(children: [IntrinsicWidth(child: c)]),
      );
      expect(tester.takeException(), isNull);
      expect(_box(tester).size, Size(3 * segment(tester), 44));
    });

    testWidgets('IntrinsicHeight around a Row: the 44 pt box', (tester) async {
      await pumpIn(
        tester,
        (c) => Center(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [c, const SizedBox(width: 8)],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_box(tester).height, 44);
      expect(
        tester.getSize(find.byType(IntrinsicHeight)).height,
        44,
      );
    });

    testWidgets('in an AlertDialog (IntrinsicWidth inside)', (tester) async {
      await pumpIn(tester, (c) => AlertDialog(content: c));
      expect(tester.takeException(), isNull);
      expect(_box(tester).size, Size(3 * segment(tester), 44));
    });

    testWidgets('dry layout: the geometry size under the constraints', (
      tester,
    ) async {
      await pumpIn(tester, (c) => Center(child: c));
      final box = tester.renderObject<RenderBox>(
        find.byType(LiquidSegmentedControl),
      );
      final s = segment(tester);
      expect(
        box.getDryLayout(const BoxConstraints(maxWidth: 1000)),
        Size(3 * s, 44),
      );
      // Narrower than the labels: shrunk to fit, never wider.
      expect(
        box.getDryLayout(const BoxConstraints(maxWidth: 100)),
        const Size(100, 44),
      );
      expect(box.getMinIntrinsicWidth(44), 3 * s);
      expect(box.getMaxIntrinsicHeight(100), 44);
    });

    testWidgets('dry baseline: no throw in debug, and the laid-out '
        "labels' baseline", (tester) async {
      await pumpIn(tester, (c) => Center(child: c));
      final box = tester.renderObject<RenderBox>(
        find.byType(LiquidSegmentedControl),
      );
      for (final baseline in TextBaseline.values) {
        expect(box.getDryBaseline(box.constraints, baseline), isNotNull);
      }
      // The laid-out one: Flutter's own check compares the dry and the
      // real baseline of every box. A baseline Row asks for it during its
      // own dry layout.
      debugCheckIntrinsicSizes = true;
      try {
        await pumpIn(
          tester,
          (c) => Center(
            child: IntrinsicWidth(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [const Text('Scope'), c],
              ),
            ),
          ),
        );
      } finally {
        debugCheckIntrinsicSizes = false;
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets("dry baseline edge cases: Flutter's dry-versus-real check "
        'passes for mixed scripts, AX text, RTL, a shrunk control, no '
        'selection and a disabled control', (tester) async {
      Widget baselineRow(Widget c) => Center(
        child: IntrinsicWidth(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Scope'),
              Flexible(child: c),
            ],
          ),
        ),
      );
      final cases = <String, Widget>{
        'mixed scripts': LiquidSegmentedControl(
          segments: _segments(['Tất cả', '🎵 Bài hát', 'Ệ', '']),
          selectedIndex: 1,
          onChanged: (_) {},
          expand: false,
        ),
        'AX text, RTL': MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: LiquidSegmentedControl(
              segments: _segments(),
              selectedIndex: 2,
              onChanged: (_) {},
              expand: false,
            ),
          ),
        ),
        'shrunk, no selection, disabled': SizedBox(
          width: 90,
          child: LiquidSegmentedControl(
            segments: _segments(['Everything', 'Recently played', 'Places']),
            selectedIndex: null,
            onChanged: null,
            expand: false,
          ),
        ),
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        debugCheckIntrinsicSizes = true;
        try {
          await tester.pumpWidget(
            MaterialApp(home: Material(child: baselineRow(value))),
          );
        } finally {
          debugCheckIntrinsicSizes = false;
        }
        expect(tester.takeException(), isNull, reason: key);
      }
    });

    testWidgets('RenderSizedLayout: a new baselineFor lays out again', (
      tester,
    ) async {
      await tester.pumpWidget(
        Center(
          child: SizedLayoutBuilder(
            sizeFor: (_) => const Size(10, 44),
            baselineFor: (_, _) => 10,
            builder: (_, _) => const SizedBox(width: 10, height: 44),
          ),
        ),
      );
      final box = tester.renderObject<RenderSizedLayout>(
        find.byType(SizedLayoutBuilder),
      );
      const loose = BoxConstraints(maxWidth: 100, maxHeight: 100);
      expect(box.getDryBaseline(loose, TextBaseline.alphabetic), 10);
      expect(box.debugNeedsLayout, isFalse);
      box.baselineFor = (_, _) => 12;
      expect(box.debugNeedsLayout, isTrue);
      expect(box.getDryBaseline(loose, TextBaseline.alphabetic), 12);
      await tester.pump();
    });

    testWidgets('expand: true at intrinsic width also sizes to the labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: IntrinsicWidth(
              child: LiquidSegmentedControl(
                segments: _segments(),
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_box(tester).size, Size(3 * segment(tester), 44));
    });
  });

  testWidgets('a theme label style without a height keeps the spec line '
      '(15.67 on 13 pt)', (tester) async {
    final base = LiquidGlassTheme.fromColorScheme(const ColorScheme.light());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            base.copyWith(
              segmentLabelStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF000000),
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
    expect(tester.getSize(find.byKey(kSegmentTrackKey)).height, 32);
    for (final p in _paragraphs(tester, kSegmentNormalKey)) {
      expect(p.size.height, closeTo(_line, 0.01));
    }
  });

  testWidgets('labels ignore the ambient text style (no Material above: '
      'no error underline, no inherited font)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
    // The error style's monospace stays out; the family is the theme's.
    final family = ThemeData().textTheme.labelLarge!.fontFamily;
    for (final p in _paragraphs(tester, kSegmentNormalKey)) {
      expect(p.text.style!.decoration, isNot(TextDecoration.underline));
      expect(p.text.style!.fontFamily, family);
      expect(p.text.style!.fontFamily, isNot('monospace'));
    }
  });

  group("labels use the app's font family (review I-1)", () {
    Future<void> pumpThemed(WidgetTester tester, ThemeData theme) =>
        tester.pumpWidget(
          MaterialApp(
            theme: theme,
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

    List<TextStyle> styles(WidgetTester tester) => [
      for (final row in [kSegmentNormalKey, kSegmentSelectedKey])
        for (final p in _paragraphs(tester, row)) p.text.style!,
    ];

    testWidgets("by default: ThemeData.fontFamily, the spec's metrics", (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ThemeData(fontFamily: 'AppFont', fontFamilyFallback: const ['Alt']),
      );
      final all = styles(tester);
      expect(all, hasLength(6));
      for (final style in all) {
        expect(style.fontFamily, 'AppFont');
        expect(style.fontFamilyFallback, ['Alt']);
        expect(style.fontSize, 13);
        expect(style.height, closeTo(_line / 13, 1e-9));
      }
      expect(all.map((s) => s.fontWeight).toSet(), {
        FontWeight.w400,
        FontWeight.w500,
      });
    });

    // Task 15 review: UIKit tracks its system font by size; Flutter's text
    // engine does not. The labels take SF Pro's tracking for their drawn
    // size when they are in the system font, and an app's own font keeps
    // its spacing.
    testWidgets("the system font tracks as UIKit's, by the drawn size", (
      tester,
    ) async {
      await pumpThemed(tester, ThemeData(platform: TargetPlatform.iOS));
      for (final style in styles(tester)) {
        expect(style.letterSpacing, closeTo(sfTracking(13), 1e-9));
      }
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
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
        ),
      );
      for (final style in styles(tester)) {
        expect(style.letterSpacing, closeTo(sfTracking(26), 1e-9));
      }
    });

    testWidgets("an app's own font, or Android's, keeps its spacing", (
      tester,
    ) async {
      await pumpThemed(
        tester,
        ThemeData(platform: TargetPlatform.iOS, fontFamily: 'AppFont'),
      );
      for (final style in styles(tester)) {
        expect(style.letterSpacing, isNull);
      }
      await pumpThemed(tester, ThemeData(platform: TargetPlatform.android));
      for (final style in styles(tester)) {
        expect(style.letterSpacing, isNull);
      }
    });

    testWidgets('segmentLabelStyle.fontFamily wins', (tester) async {
      final base = ThemeData(fontFamily: 'AppFont');
      final glass = LiquidGlassTheme.fromColorScheme(base.colorScheme);
      await pumpThemed(
        tester,
        base.copyWith(
          extensions: [
            glass.copyWith(
              segmentLabelStyle: glass.segmentLabelStyle.copyWith(
                fontFamily: 'Own',
              ),
            ),
          ],
        ),
      );
      for (final style in styles(tester)) {
        expect(style.fontFamily, 'Own');
      }
    });
  });

  testWidgets('find.text sees each title once: the lens copy is not a Text', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Songs'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(kSegmentNormalKey),
        matching: find.text('Songs'),
      ),
      findsOneWidget,
    );
    expect(_paragraphs(tester, kSegmentSelectedKey), hasLength(3));
  });

  test('LiquidSegment: a value with diagnostics', () {
    const a = LiquidSegment(label: 'A', semanticLabel: 'a');
    expect(a, const LiquidSegment(label: 'A', semanticLabel: 'a'));
    expect(
      a.hashCode,
      const LiquidSegment(label: 'A', semanticLabel: 'a').hashCode,
    );
    expect(a, isNot(const LiquidSegment(label: 'A', semanticLabel: 'b')));
    expect(a, isNot(const LiquidSegment(label: 'B', semanticLabel: 'a')));
    expect(
      a,
      isNot(
        const LiquidSegment(label: 'A', semanticLabel: 'a', enabled: false),
      ),
    );
    final text = a.toString();
    expect(text, contains('"A"'));
    expect(text, contains('semanticLabel: "a"'));
    expect(
      const LiquidSegment(label: 'B', enabled: false).toString(),
      contains('disabled'),
    );
  });

  test('LiquidSegmentedControl: diagnostics', () {
    final text = LiquidSegmentedControl(
      segments: _segments(),
      selectedIndex: 2,
      onChanged: null,
      expand: false,
      semanticLabel: 'Scope',
    ).toStringDeep();
    expect(text, contains('selectedIndex: 2'));
    expect(text, contains('disabled'));
    expect(text, contains('intrinsic'));
    expect(text, contains('semanticLabel: "Scope"'));
    expect(text, contains('"Songs"'));
  });
}

/// The intrinsic segment width (spec §5): the widest label in Medium plus
/// 18, at least 44; measured here with its own TextPainters.
double _intrinsicSegment(List<String> titles, TextStyle style) {
  var widest = 0.0;
  for (final t in titles) {
    final painter = TextPainter(
      text: TextSpan(
        text: t,
        style: style.copyWith(fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return math.max(44, widest.ceilToDouble() + 18);
}
