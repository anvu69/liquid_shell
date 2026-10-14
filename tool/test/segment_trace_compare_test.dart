import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../segment_trace_compare.dart';
import '../trace_math.dart';

/// docs/qa/vk550/native_reference.json, read fresh for each use.
Map<String, dynamic> fixture() =>
    jsonDecode(File('docs/qa/vk550/native_reference.json').readAsStringSync())
        as Map<String, dynamic>;

/// [m]'s child map at [key].
Map<String, dynamic> _map(Map<String, dynamic> m, String key) =>
    m[key]! as Map<String, dynamic>;

/// The rows of a fixture block: `[t, x, w, h, engage]` each.
List<List<double>> _rows(Map<String, dynamic> block, [String key = 'rows']) => [
  for (final r in block[key]! as List<dynamic>)
    [for (final v in r as List<dynamic>) (v as num).toDouble()],
];

List<double> _list(Object? v) => [
  for (final e in v! as List<dynamic>) (e as num).toDouble(),
];

/// The tracks of the example's segments case (lib/cases/segments.dart):
/// left and top in screen points.
const ({double left, double top}) _full3 = (left: 16, top: 240);
const ({double left, double top}) _full5 = (left: 16, top: 400);

/// The trace clock of a synthetic sequence: a ticker started long before.
const _clock = 5.0;

/// A Flutter sample of a native row, on a track at [left].
Map<String, double> _sample(
  List<double> row,
  double t, {
  required double left,
  required bool touch,
}) => {
  't': _clock + t,
  'x': row[1] + left,
  'y': 256,
  'w': row[2],
  'h': row[3],
  'engage': row[4],
  'touch': touch ? 1 : 0,
  'finger': row[1] + left,
};

/// A tap as the Flutter run records it: the finger held, the last frame
/// before the up at the native commit (row 0), then the native rows.
List<Map<String, double>> _tap(List<List<double>> rows, double left) => [
  _sample(rows.first, -0.05, left: left, touch: true),
  _sample(rows.first, 0, left: left, touch: true),
  for (final r in rows.skip(1)) _sample(r, r[0], left: left, touch: false),
];

/// A Flutter response equal to the fixture: every trace is the native
/// rows, the geometry and the colours the native numbers.
Map<String, dynamic> synthetic(Map<String, dynamic> ref) {
  final geometry = _map(ref, 'geometry');
  final width = (geometry['width']! as num).toDouble();
  final height = (geometry['height']! as num).toDouble();
  final thumbs3 = [
    for (final t in geometry['thumbs3']! as List<dynamic>) _list(t),
  ];
  List<double> offset(List<double> rect, double left, double top) => [
    rect[0] + left,
    rect[1] + top,
    rect[2],
    rect[3],
  ];
  List<double> thumb(Object? size, double top) {
    final [w, h] = _list(size);
    return [_full3.left + 2, top + 2, w, h];
  }

  final dark = _map(ref, 'dark');
  final press = _rows(_map(ref, 'press'));
  final release = _rows(_map(ref, 'release'));
  final flick = _map(ref, 'flick');
  final releaseAt = (flick['release_at']! as num).toDouble();
  final lag = _map(_map(ref, 'fits'), 'dragLag');
  final speed = (lag['speed']! as num).toDouble();
  final lagPt = (lag['lag']! as num).toDouble();

  // The press held 2 s, then its release: one sequence, as the Flutter
  // run's (the release rows start at the last touching sample).
  final held = [
    for (final r in press) _sample(r, r[0], left: _full3.left, touch: true),
    for (var t = 0.35; t < 2; t += 0.05)
      _sample(press.last, t, left: _full3.left, touch: true),
    _sample(release.first, 2, left: _full3.left, touch: true),
    for (final r in release.skip(1))
      _sample(r, 2 + r[0], left: _full3.left, touch: false),
  ];

  // A drag at the native speed, the lens the native lag behind the
  // finger as a sampled spring shows it (half a frame of finger travel
  // ahead of the continuous ramp: steadyLag's correction).
  final drag = <Map<String, double>>[
    for (var f = 0; f <= 180; f++)
      () {
        final t = f / 60;
        final finger = 77 + speed * t;
        final x = finger - lagPt + speed / 60 / 2;
        return {
          't': _clock + t,
          'x': x,
          'y': 256.0,
          'w': 143.0,
          'h': 44.0,
          'engage': 1.0,
          'touch': 1.0,
          'finger': finger,
        };
      }(),
  ];

  return {
    'geometry': {
      'intrinsic3': {
        'track': [
          (402 - (geometry['intrinsic3']! as num)) / 2,
          160,
          (geometry['intrinsic3']! as num).toDouble(),
          height,
        ],
      },
      'full3': {
        'track': [_full3.left, _full3.top, width, height],
        'thumbs': [for (final t in thumbs3) offset(t, _full3.left, 240)],
      },
      'full2': {
        'track': [_full3.left, 320, width, height],
        'thumb': thumb(geometry['thumb2'], 320),
      },
      'full5': {
        'track': [_full5.left, _full5.top, width, height],
        'thumb': thumb(geometry['thumb5'], _full5.top),
      },
    },
    'sequences': {
      for (final key in ['tap_1_2', 'tap_2_3', 'tap_3_1'])
        key: _tap(_rows(_map(ref, key)), _full3.left),
      'dark_tap_1_2': _tap(_rows(_map(dark, 'tap_1_2')), _full3.left),
      'tap_1_3_5seg': _tap(_rows(_map(ref, 'tap_1_3_5seg')), _full5.left),
      'press': held,
      'slow_drag': drag,
      'flick': [
        for (final r in _rows(flick))
          _sample(r, r[0], left: _full3.left, touch: r[0] < releaseAt),
      ],
      // The app's change starts its own ticker run: its clock is 0 at the
      // rebuild that applied the change.
      'programmatic': [
        for (final r in _rows(_map(ref, 'programmatic_2seg')))
          {..._sample(r, r[0], left: _full3.left, touch: false), 't': r[0]},
      ],
    },
    'colours': {
      for (final e in _map(ref, 'colors').entries)
        if (e.key != 'tolerance') e.key: _list(e.value),
    },
  };
}

/// [json] with [f] applied to every number in it.
Object? mapNumbers(Object? json, num Function(num) f) => switch (json) {
  final num n => f(n),
  final List<dynamic> l => [for (final e in l) mapNumbers(e, f)],
  final Map<String, dynamic> m => {
    for (final e in m.entries) e.key: mapNumbers(e.value, f),
  },
  _ => json,
};

/// [response] with tap_1_2's lens moved [dx] pt.
Map<String, dynamic> shiftTap(Map<String, dynamic> response, double dx) {
  final copy = jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
  final seqs = _map(copy, 'sequences');
  seqs['tap_1_2'] = [
    for (final s in seqs['tap_1_2']! as List<dynamic>)
      {...s as Map<String, dynamic>, 'x': (s['x']! as num) + dx},
  ];
  return copy;
}

void main() {
  test('(a) a Flutter trace equal to the native rows passes every row', () {
    final ref = fixture();
    final rows = segmentRows(synthetic(ref), ref);
    final failed = [
      for (final r in rows)
        if (!r.pass) '${r.name}: ${r.flutter} vs ${r.native}',
    ];
    expect(failed, isEmpty);
    // Every spec §14.5 group is there.
    final names = rows.map((r) => r.name).join('\n');
    for (final group in [
      'full3 track width',
      'thumb1 x',
      'full2 thumb w',
      'full5 thumb w',
      'intrinsic3 width',
      'tap_1_2 x @',
      'tap_3_1 overshoot',
      'tap_2_3 settle',
      'dark.tap_1_2 x @',
      'tap_1_3_5seg x @',
      'tap_1_2 peak h',
      'tap_3_1 w wobble',
      'tap_1_2 engage onset',
      'press w @',
      'press engage onset',
      'dark.press engage onset',
      'release engage @',
      'drag lag',
      'flick lands',
      'flick overshoot',
      'programmatic x @',
      'colour lightTrackOverWhite',
      'colour darkLabel',
      'colour lightDisabledTrack',
    ]) {
      expect(names, contains(group));
    }
  });

  test('every row is native or native, constant: none is a fit', () {
    final ref = fixture();
    final kinds = segmentRows(synthetic(ref), ref).map((r) => r.kind).toSet();
    expect(kinds, {Kind.native, Kind.constant});
  });

  test('(b) one tap trace 3 pt off fails exactly its x rows', () {
    final ref = fixture();
    final rows = segmentRows(shiftTap(synthetic(ref), 3), ref);
    final failed = {
      for (final r in rows)
        if (!r.pass) r.name,
    };
    final xRows = {
      for (final r in rows)
        if (r.name.startsWith('tap_1_2 x @')) r.name,
    };
    expect(xRows, hasLength(13), reason: 'every 0.05 s to 0.6 s');
    expect(failed, xRows);
  });

  test('a tap off by 1.5 pt still passes its ±2 pt rows', () {
    final ref = fixture();
    final rows = segmentRows(shiftTap(synthetic(ref), 1.5), ref);
    expect([
      for (final r in rows)
        if (!r.pass) r.name,
    ], isEmpty);
  });

  test("the app's change is read on its ticker clock from 0: a ticker "
      'started mid-frame (its first sample a frame late) shifts nothing', () {
    final ref = fixture();
    final response = synthetic(ref);
    final slide = _map(response, 'sequences')['programmatic']! as List<dynamic>;
    (slide.first as Map<String, dynamic>)['t'] = 1 / 60;
    expect([
      for (final r in segmentRows(response, ref))
        if (!r.pass) '${r.name}: ${r.flutter} vs ${r.native}',
    ], isEmpty);
  });

  test('a missing sequence is a failed row, not a crash', () {
    final ref = fixture();
    final response = synthetic(ref);
    _map(response, 'sequences').remove('flick');
    final failed = [
      for (final r in segmentRows(response, ref))
        if (!r.pass) r.name,
    ];
    expect(failed, ['flick trace']);
  });

  test('(c) the tool exits 1 with a missing sequence, 0 on the fixture', () {
    final dir = Directory.systemTemp.createTempSync('segment_trace_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final ref = fixture();
    ProcessResult run(Map<String, dynamic> response) {
      final file = File('${dir.path}/response.json')
        ..writeAsStringSync(jsonEncode(response));
      return Process.runSync(Platform.resolvedExecutable, [
        'run',
        'tool/segment_trace_compare.dart',
        file.path,
        'docs/qa/vk550/native_reference.json',
      ]);
    }

    final ok = run(synthetic(ref));
    expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
    expect(ok.stdout as String, contains('| check | kind | result |'));
    final response = synthetic(ref);
    _map(response, 'sequences').remove('press');
    final missing = run(response);
    expect(missing.exitCode, 1, reason: '${missing.stdout}${missing.stderr}');
    expect(missing.stdout as String, contains('| press trace | native | FAIL'));
  });

  test('(d) every reference comes from the fixture: +1000 on every fixture '
      "number changes every row's native column", () {
    final ref = fixture();
    final response = synthetic(ref);
    final base = segmentRows(response, ref);
    final moved = segmentRows(
      response,
      mapNumbers(ref, (n) => n + 1000)! as Map<String, dynamic>,
    );
    expect([for (final r in moved) r.name], [for (final r in base) r.name]);
    final unchanged = [
      for (var i = 0; i < base.length; i++)
        if (base[i].native == moved[i].native)
          '${base[i].name}: ${base[i].native}',
    ];
    expect(unchanged, isEmpty);
  });

  test('(d) …and none from the Flutter side: a different Flutter run leaves '
      'every native column as it was', () {
    final ref = fixture();
    final base = segmentRows(synthetic(ref), ref);
    final other = segmentRows(
      // Every Flutter number but the clock and the touch flags moves.
      _otherRun(synthetic(ref)),
      ref,
    );
    expect([for (final r in other) r.name], [for (final r in base) r.name]);
    for (var i = 0; i < base.length; i++) {
      expect(other[i].native, base[i].native, reason: base[i].name);
    }
    // The Flutter column did move.
    expect(
      [
        for (var i = 0; i < base.length; i++)
          if (other[i].flutter != base[i].flutter) i,
      ],
      isNotEmpty,
    );
  });

  test('the table: a header, one line per row, the counts and a verdict', () {
    final ref = fixture();
    final rows = segmentRows(shiftTap(synthetic(ref), 3), ref);
    final out = StringBuffer();
    final failed = printSegmentTable(rows, out);
    final lines = out.toString().trimRight().split('\n');
    expect(failed, 13);
    expect(
      lines.first,
      '| check | kind | result | flutter | native | '
      'tolerance |',
    );
    expect(lines, contains(startsWith('| tap_1_2 x @100ms | native | FAIL |')));
    expect(lines.length, rows.length + 4);
    expect(lines.last, '✗ 13 of ${rows.length} failed');
  });
}

/// [response] as another Flutter run might give it: positions, sizes,
/// engage and colours all moved, the times and touches kept.
Map<String, dynamic> _otherRun(Map<String, dynamic> response) {
  final copy = jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
  final seqs = _map(copy, 'sequences');
  for (final key in seqs.keys.toList()) {
    seqs[key] = [
      for (final s in seqs[key]! as List<dynamic>)
        {
          for (final e in (s as Map<String, dynamic>).entries)
            e.key: e.key == 't' || e.key == 'touch'
                ? e.value
                : (e.value as num) * 1.1 + 0.7,
        },
    ];
  }
  copy['geometry'] = mapNumbers(copy['geometry'], (n) => n + 0.4);
  copy['colours'] = mapNumbers(copy['colours'], (n) => n + 2);
  return copy;
}
