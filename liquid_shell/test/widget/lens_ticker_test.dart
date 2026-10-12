import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_ticker.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';

/// The smallest lens widget: a [LensTicker] over a 3-slot compact track.
/// [adopt]: the app takes every commit as its selection.
class _Harness extends StatefulWidget {
  const _Harness({required this.adopt});

  final bool adopt;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  final TabBarGeometry geometry = compactTabGeometry(
    count: 3,
    maxWidth: 400,
    trailing: false,
    direction: TextDirection.ltr,
  );
  late final LensMotion motion = LensMotion(geometry: geometry, selected: 0);
  int? selected = 0;
  late final LensTicker ticker = LensTicker(
    vsync: this,
    motion: () => motion,
    selected: () => selected,
    onFrame: () => setState(() {}),
  );

  Offset at(int slot) =>
      Offset(geometry.centreOf(slot), geometry.slots[0].center.dy);

  void down(Offset p) {
    motion.down(p);
    ticker.kick();
  }

  void up(Offset p) {
    final slot = motion.up(p);
    if (widget.adopt) selected = slot;
    ticker.kick();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// Down on slot 0, a drag to slot 2 in 4 pt steps (one 16 ms frame each),
/// a beat for the lens to catch up, then the release.
Future<void> _dragAcross(WidgetTester tester, _HarnessState s) async {
  final from = s.at(0);
  final to = s.at(2);
  s.down(from);
  await tester.pump(const Duration(milliseconds: 16));
  for (var x = from.dx; x < to.dx; x += 4) {
    s.motion.move(Offset(x, from.dy));
    await tester.pump(const Duration(milliseconds: 16));
  }
  s.motion.move(to);
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  s.up(to);
}

/// Pumps 16 ms frames for [seconds]: no pumpAndSettle, so a ticker that
/// never stops shows as a scheduled frame instead of a timeout.
Future<void> _frames(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.016) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('one selection click per slot crossing while dragging', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    await tester.pumpWidget(const _Harness(adopt: true));
    final s = tester.state<_HarnessState>(find.byType(_Harness));
    await _dragAcross(tester, s);
    await _frames(tester, 3);
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(s.motion.committed, 2);
  });

  testWidgets('the ticker stops once nothing moves', (tester) async {
    await tester.pumpWidget(const _Harness(adopt: true));
    final s = tester.state<_HarnessState>(find.byType(_Harness));
    await _dragAcross(tester, s);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await _frames(tester, 3);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(s.motion.pending, isNull);
  });

  testWidgets('a commit the app does not adopt returns the lens', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(adopt: false));
    final s = tester.state<_HarnessState>(find.byType(_Harness));
    await _dragAcross(tester, s);
    expect(s.motion.committed, 2);
    await _frames(tester, 3);
    expect(s.motion.committed, 0);
    expect(s.motion.pending, isNull);
    expect(s.motion.frame.lens.center.dx, closeTo(s.at(0).dx, 0.5));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
