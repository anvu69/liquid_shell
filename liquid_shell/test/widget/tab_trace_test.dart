// The acceptance trace hook (spec VK-503 §17.4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
// The trace hook is test-only and stays out of the public API (spec §16).
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart' show debugTabTrace;

void main() {
  testWidgets('debugTabTrace receives one global sample per tick', (
    tester,
  ) async {
    final samples = <Map<String, double>>[];
    debugTabTrace = samples.add;
    addTearDown(() => debugTabTrace = null);
    // The app adopts the commit; otherwise the lens returns (spec §8.7).
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (context, setState) => LiquidTabBar(
                destinations: const [
                  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
                  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
                ],
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Explore'));
    await tester.pumpAndSettle();
    expect(samples, isNotEmpty);
    expect(
      samples.first.keys,
      containsAll(<String>[
        't',
        'x',
        'y',
        'w',
        'h',
        'engage',
        'scale',
        'glow',
        'glowD',
        'pop',
        'morph',
      ]),
    );
    final explore = tester.getCenter(find.bySemanticsLabel('Explore'));
    expect(samples.last['x'], closeTo(explore.dx, 0.5));
  });
}
