import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

Future<void> _pump(WidgetTester tester, LiquidBadge badge) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Center(child: LiquidBadgeView(badge: badge)),
  ),
);

void main() {
  testWidgets('count is a capsule with onError text on error', (tester) async {
    await _pump(tester, const LiquidBadge.count(3));
    final text = tester.widget<Text>(find.text('3'));
    expect(text.style!.color, _scheme.onError);
    expect(text.style!.fontSize, 11);
    expect(text.style!.fontWeight, FontWeight.w600);
    final box = tester.getSize(find.byType(LiquidBadgeView));
    expect(box.width, greaterThanOrEqualTo(16));
    expect(box.height, greaterThanOrEqualTo(16));
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
    expect(decoration.color, _scheme.error);
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

  testWidgets('dot is 8×8 in the error colour', (tester) async {
    await _pump(tester, const LiquidBadge.dot());
    expect(tester.getSize(find.byType(LiquidBadgeView)), const Size(8, 8));
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
    expect(decoration.color, _scheme.error);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('the badge adds no semantics node of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const LiquidBadge.count(3));
    expect(find.bySemanticsLabel('3'), findsNothing);
    handle.dispose();
  });
}
