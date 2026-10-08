import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/narrow_width.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

void main() {
  testWidgets('the wallpaper does not clip, so its discs reach under a '
      'tiled sidebar and show through its glass (owner 2A)', (tester) async {
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
    expect(paint, paints..circle());
    expect(paint, isNot(paints..clipRect()));
  });

  testWidgets('only the narrow case clips, at its 320pt shell: the shell '
      'stands for a narrow window', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: NarrowWidthCase()));
    final clip = find.ancestor(
      of: find.byType(LiquidShell),
      matching: find.descendant(
        of: find.byType(NarrowWidthCase),
        matching: find.byType(ClipRect),
      ),
    );
    expect(clip, findsOneWidget);
    expect(
      tester.getRect(clip),
      tester.getRect(find.byType(LiquidShell)),
    );
    expect(tester.getSize(clip).width, kNarrowShellWidth);
  });
}
