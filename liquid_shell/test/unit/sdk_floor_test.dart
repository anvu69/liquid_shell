// Risk probe (spec §14, plan Task 1): the Flutter 3.44 floor must provide
// every engine/framework API the glass and the minimised tab bar rely on.
// This file only compiles if they exist, so CI's 3.44.x job guards the floor.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImageFilter.isShaderFilterSupported is a bool getter', () {
    expect(ui.ImageFilter.isShaderFilterSupported, isA<bool>());
  });

  test('SemanticsService.sendAnnouncement exists', () {
    expect(SemanticsService.sendAnnouncement, isA<Function>());
  });

  testWidgets('BackdropFilter.grouped renders inside a BackdropGroup', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BackdropGroup(
          child: Stack(
            children: [
              const ColoredBox(color: Color(0xFF2196F3)),
              BackdropFilter.grouped(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const SizedBox.square(dimension: 40),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      BackdropGroup.of(tester.element(find.byType(BackdropFilter))),
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
