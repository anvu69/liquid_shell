import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

Future<void> _pump(WidgetTester tester, LiquidBadge badge) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Center(child: LiquidBadgeView(badge: badge)),
  ),
);

void main() {
  testWidgets('count is a 21.33 capsule with 12/w500 white text in the '
      'theme badge colour (spec VK-503 §5.1)', (tester) async {
    await _pump(tester, const LiquidBadge.count(3));
    final text = tester.widget<Text>(find.text('3'));
    expect(text.style!.color, const Color(0xFFFFFFFF));
    expect(text.style!.fontSize, 12);
    expect(text.style!.fontWeight, FontWeight.w500);
    final box = tester.getSize(find.byType(LiquidBadgeView));
    expect(box.width, greaterThanOrEqualTo(21.33));
    expect(box.height, 21.33);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(LiquidBadgeView),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(
      decoration.color,
      LiquidGlassTheme.fromColorScheme(_scheme).badgeColor,
    );
  });

  testWidgets('overflow shows max+', (tester) async {
    await _pump(tester, const LiquidBadge.count(120));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('count 0 draws nothing', (tester) async {
    await _pump(tester, const LiquidBadge.count(0));
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(LiquidBadgeView)), Size.zero);
  });

  testWidgets('dot is the empty 21.33 capsule in the badge colour', (
    tester,
  ) async {
    await _pump(tester, const LiquidBadge.dot());
    expect(
      tester.getSize(find.byType(LiquidBadgeView)),
      const Size(21.33, 21.33),
    );
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(LiquidBadgeView),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(
      decoration.color,
      LiquidGlassTheme.fromColorScheme(_scheme).badgeColor,
    );
    expect(
      decoration.borderRadius,
      const BorderRadius.all(Radius.circular(21.33 / 2)),
    );
  });

  testWidgets('the badge adds no semantics node of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const LiquidBadge.count(3));
    expect(find.bySemanticsLabel('3'), findsNothing);
    handle.dispose();
  });
}
