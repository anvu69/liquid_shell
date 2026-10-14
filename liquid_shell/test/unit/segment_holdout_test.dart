// The segment model against native taps it was never fitted to (spec VK-550
// §14.5): the tap gate (tool/segment_gate.dart, the device table's own) on
// - `native_holdout.json`, Task 15's 21 taps: a validation set now, since
//   it showed the lift rule wrong (the lift follows the direction on
//   screen, not the distance) before the rule was chosen;
// - the holdout split of `native_taps.json` (passes 1 and 2, 52 taps),
//   split before any capture was looked at: the true test.
// Every check on the device table's clock, tolerances unchanged.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/segment_gate.dart';

void main() {
  final validation = nativeTaps('native_holdout.json');
  final holdout = [
    for (final c in segmentTaps())
      if (c.split == 'holdout') c,
  ];

  test('the holdouts repeat every fitted tap and every new kind', () {
    for (final key in [
      'tap_1_2',
      'tap_2_3',
      'tap_3_1',
      'dark.tap_1_2',
      'tap_1_3_5seg',
    ]) {
      expect(validation.where((c) => c.key == key), hasLength(3), reason: key);
    }
    expect(holdout, hasLength(52));
    expect({for (final c in holdout) c.repeat}, {1, 2});
  });

  // What still fails, and nothing else: the slide (x) and its overshoot on
  // taps longer than any fitted one on a 5-segment control (222 and 296
  // pt: native overshoots 3.0 to 4.3 pt, the model 4.2 to 5.6), the
  // two-segment control's x at +0.25–0.3 s (2.1 pt off), and the w swing
  // after a long tap to the right on five segments (66 against 57–59; the
  // model's lift is a share of the rest width, native's about +38 pt). One
  // capture, `tap_3_2_5seg` #1, reads 4.4 pt off at +0.1 s on a clock 8 ms
  // from its siblings'. Docs/qa/vk550/acceptance.md.
  const known = {
    'tap_1_5_5seg #1': {
      'x @200ms',
      'x @250ms',
      'x @450ms',
      'overshoot',
      'w wobble',
    },
    'tap_1_5_5seg #2': {
      'x @50ms',
      'x @200ms',
      'x @250ms',
      'x @450ms',
      'x @500ms',
      'overshoot',
      'w wobble',
    },
    'tap_5_1_5seg #1': {'x @200ms', 'x @250ms', 'overshoot'},
    'tap_5_1_5seg #2': {
      'x @50ms',
      'x @200ms',
      'x @250ms',
      'x @300ms',
      'overshoot',
    },
    'tap_1_4_5seg #1': {'overshoot', 'w wobble'},
    'tap_1_4_5seg #2': {'overshoot', 'w wobble'},
    'tap_3_2_5seg #1': {'x @100ms', 'x @150ms'},
    'tap_1_2_2seg #1': {'x @250ms', 'x @300ms'},
    'tap_1_2_2seg #2': {'x @250ms', 'x @300ms'},
  };

  for (final (set, captures) in [
    ('validation', validation),
    ('holdout', holdout),
  ]) {
    for (final (i, c) in captures.indexed) {
      final id = '${c.key} #${c.repeat}';
      test('$set $i, $id: the tap gate, only the known misses', () {
        final m = ModelTap(
          c.segments,
          c.from,
          c.to,
          direction: c.rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(m.committed, c.to);
        final shift = tapClock(c.rows, m.ours);
        expect(tapClockPinned(shift), isFalse, reason: 'clock $shift');
        final rows = m.gate(c.rows, shift: shift);
        final failed = {
          for (final r in rows)
            if (!gatePasses(r)) r.name,
        };
        expect(
          failed,
          set == 'holdout' ? known[id] ?? const <String>{} : const <String>{},
          reason: '$rows',
        );
      });
    }
  }
}
