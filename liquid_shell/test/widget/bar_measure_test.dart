import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/shell/bar_measure.dart';

void main() {
  testWidgets('reports a height only after two stable frames, once per '
      '(tag, height), never mid-change', (tester) async {
    final reports = <double>[];
    var height = 50.0;
    var width = 10.0;
    var tag = 'a';
    late StateSetter rebuild;
    await tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return BarMeasure(
              tag: tag,
              onHeight: reports.add,
              child: SizedBox(width: width, height: height),
            );
          },
        ),
      ),
    );
    expect(reports, isEmpty, reason: 'first frame only starts settling');
    await tester.pump();
    expect(reports, [50]);

    // A height that changes every frame is not reported until it holds.
    rebuild(() => height = 60);
    await tester.pump();
    rebuild(() => height = 70);
    await tester.pump();
    expect(reports, [50]);
    await tester.pump();
    expect(reports, [50, 70]);

    // No loop: nothing new while nothing changes.
    await tester.pump();
    await tester.pump();
    expect(reports, [50, 70]);

    // A relayout at the reported height does not even look again.
    rebuild(() => width = 20);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(reports, [50, 70]);

    // A new tag re-reports the unchanged height.
    rebuild(() => tag = 'b');
    await tester.pumpAndSettle();
    expect(reports, [50, 70, 70]);

    // Removed while settling: no report, no error.
    rebuild(() => height = 80);
    await tester.pump(Duration.zero, EnginePhase.layout);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(reports, [50, 70, 70]);
  });
}
