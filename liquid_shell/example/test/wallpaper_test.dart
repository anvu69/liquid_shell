import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

void main() {
  testWidgets('the wallpaper paints inside its own bounds', (tester) async {
    // A box narrower than the window, as in the narrow case: the discs must
    // not spill into the window around it.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 120, height: 200, child: Wallpaper()),
        ),
      ),
    );
    final paint = tester.renderObject(
      find.descendant(
        of: find.byType(Wallpaper),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint, paints..clipRect(rect: Offset.zero & const Size(120, 200)));
  });
}
