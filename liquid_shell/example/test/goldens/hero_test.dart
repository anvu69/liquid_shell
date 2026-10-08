@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';

import '../support/golden_harness.dart';

void main() {
  for (final device in [iphone, ipadLandscape, android]) {
    for (final brightness in Brightness.values) {
      final name = 'hero_${device.name}_${brightness.name}';
      testWidgets(name, (tester) async {
        await pumpGolden(
          tester,
          const SidebarSlotsCase(),
          device: device,
          brightness: brightness,
        );
        await expectLater(find.byType(MaterialApp), matchesDocImage(name));
      });
    }
  }
}
