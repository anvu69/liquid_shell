import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/narrow_width.dart';

import 'support/golden_harness.dart';

/// The narrow case as the doc image draws it (Inter, iPhone, a 320pt shell):
/// every tab label fits untruncated at 10pt or more (Q18).
void main() {
  Finder label(String text) => find.descendant(
    of: find.byType(LiquidTabBar),
    matching: find.text(text),
  );

  void expectFits(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(label(text));
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$text ellipsized');
    // The label style is 10pt; a shrunk label is painted scaled.
    final scale =
        tester.getRect(label(text)).width / tester.getSize(label(text)).width;
    // Rects go through the paint transform: allow float noise.
    expect(10 * scale, greaterThanOrEqualTo(10 - 1e-9), reason: text);
  }

  testWidgets('at 320 every label of the narrow case fits at 10pt or more, '
      'selected or not', (tester) async {
    await pumpGolden(tester, const NarrowWidthCase(), device: iphone);
    final labels = [
      for (final d
          in tester.widget<LiquidShell>(find.byType(LiquidShell)).destinations)
        d.label,
    ];
    expect(labels, ['Home', 'Explore', 'Inbox', 'Saved', 'Settings']);
    for (final text in labels) {
      expectFits(tester, text);
    }
    for (final text in labels.reversed) {
      await tester.tap(label(text));
      await tester.pumpAndSettle();
      expectFits(tester, text);
    }
    expect(tester.takeException(), isNull);
  });
}
