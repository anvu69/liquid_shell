import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final file = File('docs/qa/vk550/native_reference.json');

  test('the segment fixture exists and has every key the gate reads', () {
    expect(file.existsSync(), isTrue);
    final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final key in [
      'geometry',
      'colors',
      'fits',
      'tap_1_2',
      'tap_2_3',
      'tap_3_1',
      'press',
      'release',
      'slow_drag',
      'flick',
      'programmatic_2seg',
      'dark',
      'tap_1_3_5seg',
      'lens',
      'rtl',
      'tapOnSelected',
      'flickLanding',
    ]) {
      expect(j, contains(key), reason: key);
    }
    expect(j['columns'], ['t', 'x', 'w', 'h', 'engage']);
  });

  test('every tap and press block has its engage onset at display-link '
      'resolution, with the method', () {
    final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(j['engageOnsetMethod'], isA<String>());
    final dark = j['dark'] as Map<String, dynamic>;
    for (final (key, block) in [
      ('tap_1_2', j['tap_1_2']),
      ('tap_2_3', j['tap_2_3']),
      ('tap_3_1', j['tap_3_1']),
      ('tap_1_3_5seg', j['tap_1_3_5seg']),
      ('dark.tap_1_2', dark['tap_1_2']),
      ('press', j['press']),
      ('dark.press', dark['press']),
    ]) {
      final onset = (block as Map<String, dynamic>)['engageOnset'];
      expect(onset, isA<num>(), reason: key);
      expect(onset as num, inExclusiveRange(0, 0.1), reason: key);
    }
  });

  test('every row has five numbers and rising time', () {
    final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final key in ['tap_1_2', 'tap_2_3', 'tap_3_1', 'press', 'release']) {
      final rows = (j[key] as Map)['rows'] as List;
      expect(rows, isNotEmpty, reason: key);
      var last = -1.0;
      for (final r in rows.cast<List<dynamic>>()) {
        expect(r, hasLength(5), reason: key);
        final t = (r[0] as num).toDouble();
        expect(t, greaterThan(last), reason: key);
        last = t;
      }
    }
  });
}
