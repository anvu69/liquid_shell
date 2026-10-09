import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/fit_label.dart';

const _style = TextStyle(fontSize: 10);

Widget _host({
  required double maxWidth,
  String text = 'Home',
  double textScale = 1.3,
  double slack = 16,
  VoidCallback? onTap,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GestureDetector(
          onTap: onTap,
          child: FitLabel(text, style: _style, slack: slack),
        ),
      ),
    ),
  ),
);

RenderFitLabel _box(WidgetTester tester) =>
    tester.renderObject<RenderFitLabel>(find.byType(FitLabelBox));

RenderParagraph _text(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.text('Home'));

void main() {
  // 'Home' at 13pt (10pt × 1.3) in the test font.
  late double natural;

  setUp(() => natural = 0);

  Future<void> measure(WidgetTester tester) async {
    await tester.pumpWidget(_host(maxWidth: 1000));
    natural = _text(tester).size.width;
    expect(natural, greaterThan(40));
  }

  testWidgets('the four steps: slack kept, slack given up, shrunk, '
      'ellipsized at the minimum; dry layout agrees', (tester) async {
    await measure(tester);
    const minScale = 10 / 13;
    final cases = <(double, double, double, bool)>[
      // (max width, expected width, expected scale, ellipsized)
      (natural + 20, natural + 16, 1, false),
      (natural + 8, natural + 8, 1, false),
      (natural * 0.9, natural * 0.9, 0.9, false),
      (natural * 0.5, natural * 0.5, minScale, true),
    ];
    for (final (maxWidth, width, scale, ellipsized) in cases) {
      await tester.pumpWidget(_host(maxWidth: maxWidth));
      final box = _box(tester);
      expect(box.size.width, moreOrLessEquals(width), reason: '$maxWidth');
      expect(box.scale, moreOrLessEquals(scale), reason: '$maxWidth');
      expect(_text(tester).didExceedMaxLines, ellipsized, reason: '$maxWidth');
      expect(
        box.getDryLayout(BoxConstraints(maxWidth: maxWidth)),
        box.size,
        reason: '$maxWidth',
      );
      // The line height stays the unscaled one.
      expect(box.size.height, _text(tester).size.height);
      // Drawn inside the box, centred.
      final drawn = tester.getRect(find.text('Home'));
      final rect = tester.getRect(find.byType(FitLabelBox));
      expect(drawn.width, lessThanOrEqualTo(rect.width + 1e-9));
      expect(drawn.center.dx, moreOrLessEquals(rect.center.dx));
      expect(drawn.center.dy, moreOrLessEquals(rect.center.dy));
    }
  });

  testWidgets('intrinsics: max width adds the slack, min width scales, the '
      'height is one line whatever the width', (tester) async {
    await measure(tester);
    final box = _box(tester);
    final text = _text(tester);
    expect(box.getMaxIntrinsicWidth(double.infinity), natural + 16);
    expect(
      box.getMinIntrinsicWidth(double.infinity),
      moreOrLessEquals(text.getMinIntrinsicWidth(double.infinity) * 10 / 13),
    );
    for (final width in [1.0, 20.0, double.infinity]) {
      expect(box.getMinIntrinsicHeight(width), text.size.height);
      expect(box.getMaxIntrinsicHeight(width), text.size.height);
    }
  });

  testWidgets('the minimum follows the text scale and never enlarges', (
    tester,
  ) async {
    await tester.pumpWidget(_host(maxWidth: 10));
    expect(_box(tester).minScale, moreOrLessEquals(10 / 13));
    await tester.pumpWidget(_host(maxWidth: 10, textScale: 2, slack: 4));
    expect(_box(tester).minScale, moreOrLessEquals(10 / 20));
    expect(_box(tester).slack, 4);
    await tester.pumpWidget(_host(maxWidth: 10, textScale: 0.8));
    expect(_box(tester).minScale, 1);
    expect(_box(tester).scale, 1);
  });

  testWidgets('a tap on a shrunk label hits through the transform', (
    tester,
  ) async {
    await measure(tester);
    var taps = 0;
    await tester.pumpWidget(
      _host(maxWidth: natural * 0.9, onTap: () => taps++),
    );
    await tester.tap(find.text('Home'));
    expect(taps, 1);
  });
}
