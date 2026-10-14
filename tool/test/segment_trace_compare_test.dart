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

/// [rows] at [t], linear between rows, held at the ends.
List<double> _rowAt(List<List<double>> rows, double t) {
  if (t <= rows.first[0]) return rows.first;
  for (var i = 1; i < rows.length; i++) {
    final a = rows[i - 1];
    final b = rows[i];
    if (t <= b[0]) {
      final u = (t - a[0]) / (b[0] - a[0]);
      return [for (var c = 0; c < 5; c++) a[c] + (b[c] - a[c]) * u];
    }
  }
  return rows.last;
}

/// A tap as the Flutter run records it, on engine frames ([fps], 60 by
/// default): the finger held, the last frame before the up at the native
/// commit (row 0), then the native rows, linear between them, every frame.
/// [late] delays the whole motion by that many seconds; a delay off the
/// frame grid wants a dense [fps], or the rows' kinks fall between frames.
List<Map<String, double>> _tap(
  List<List<double>> rows,
  double left, {
  double late = 0,
  int fps = 60,
}) => [
  _sample(rows.first, -1 / fps, left: left, touch: true),
  _sample(rows.first, 0, left: left, touch: true),
  for (var f = 1; f / fps <= rows.last[0] + late; f++)
    _sample(_rowAt(rows, f / fps - late), f / fps, left: left, touch: false),
];

/// The flick drive the Flutter run reports: native's (`flickLanding`)
/// unless [seconds] says otherwise. Control-local.
Map<String, double> _drive(Map<String, dynamic> ref, {double? seconds}) {
  final landing = _map(ref, 'flickLanding');
  final from = _list((_map(ref, 'geometry')['thumbs3']! as List<dynamic>)[2]);
  return {
    'seconds': seconds ?? (landing['release_at']! as num).toDouble(),
    'from': from[0] + from[2] / 2,
    'to': (landing['landing']! as num).toDouble(),
  };
}

/// A Flutter response equal to the fixture: every trace is the native
/// rows, the geometry and the colours the native numbers. Decoded JSON, as
/// the tool reads it.
Map<String, dynamic> synthetic(Map<String, dynamic> ref) =>
    _copy(_synthetic(ref));

Map<String, dynamic> _synthetic(Map<String, dynamic> ref) {
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
    'drives': {'flick': _drive(ref)},
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

/// A deep copy of [response].
Map<String, dynamic> _copy(Map<String, dynamic> response) =>
    jsonDecode(jsonEncode(response)) as Map<String, dynamic>;

/// [response] with tap_1_2's lens moved [dx] pt.
Map<String, dynamic> shiftTap(Map<String, dynamic> response, double dx) {
  final copy = _copy(response);
  final seqs = _map(copy, 'sequences');
  seqs['tap_1_2'] = [
    for (final s in seqs['tap_1_2']! as List<dynamic>)
      {...s as Map<String, dynamic>, 'x': (s['x']! as num) + dx},
  ];
  return copy;
}

/// The rows that failed (a row not comparable is neither).
List<String> failed(List<SegmentRow> rows) => [
  for (final r in rows)
    if (r.comparable && !r.pass) r.name,
];

/// The row of [rows] named [name].
SegmentRow row(List<SegmentRow> rows, String name) =>
    rows.singleWhere((r) => r.name == name);

void main() {
  test('(a) a Flutter trace equal to the native rows passes every row', () {
    final ref = fixture();
    final rows = segmentRows(synthetic(ref), ref);
    expect([
      for (final r in rows)
        if (!r.pass || !r.comparable) '${r.name}: ${r.flutter} vs ${r.native}',
    ], isEmpty);
    // Every spec §14.5 group is there.
    final names = rows.map((r) => r.name).join('\n');
    for (final group in [
      'full3 track width',
      'thumb1 x',
      'full2 thumb w',
      'full5 thumb w',
      'intrinsic3 width',
      'tap_1_2 clock',
      'tap_1_2 frames',
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
      'flick drive',
      'flick lands',
      'flick overshoot',
      'programmatic clock',
      'programmatic x @',
      'colour lightTrackOverWhite',
      'colour darkLabel',
      'colour lightDisabledTrack',
    ]) {
      expect(names, contains(group));
    }
  });

  test('kinds: native, native-constant, native-fitted (in sample), and the '
      'conditions; none against a fitted spring', () {
    final ref = fixture();
    final rows = segmentRows(synthetic(ref), ref);
    expect(rows.map((r) => r.kind).toSet(), {
      Kind.native,
      Kind.constant,
      Kind.fitted,
      Kind.condition,
    });
    // The model's springs were fitted to the tap, press, release and
    // programmatic rows (spec §8.2), and since Task 15 the release spring
    // to the flick landing's overshoot too; the onsets and the drag lag are
    // out of sample.
    expect(row(rows, 'tap_1_2 x @100ms').kind, Kind.fitted);
    expect(row(rows, 'press w @100ms').kind, Kind.fitted);
    expect(row(rows, 'programmatic x @100ms').kind, Kind.fitted);
    expect(row(rows, 'flick overshoot').kind, Kind.fitted);
    expect(row(rows, 'tap_1_2 engage onset').kind, Kind.native);
    expect(row(rows, 'drag lag').kind, Kind.native);
    expect(row(rows, 'flick drive').kind, Kind.condition);
  });

  test('(b) one tap trace 3 pt off fails its x rows and nothing else; the '
      'clock may lean a frame toward it, so the rows at rest fail', () {
    final ref = fixture();
    final rows = segmentRows(shiftTap(synthetic(ref), 3), ref);
    final bad = failed(rows);
    expect(bad, isNotEmpty);
    for (final name in bad) {
      expect(name, anyOf(startsWith('tap_1_2 x @'), 'tap_1_2 clock'));
    }
    // At rest no clock shift helps.
    expect(bad, containsAll(['tap_1_2 x @0ms', 'tap_1_2 x @600ms']));
  });

  test('a tap off by 1.5 pt still passes its ±2 pt rows', () {
    final ref = fixture();
    expect(failed(segmentRows(shiftTap(synthetic(ref), 1.5), ref)), isEmpty);
  });

  group('the tap clock: x aligned by least squares within ±1 frame', () {
    Map<String, dynamic> late(double seconds) {
      final ref = fixture();
      final response = synthetic(ref);
      _map(response, 'sequences')['tap_3_1'] = _tap(
        _rows(_map(ref, 'tap_3_1')),
        _full3.left,
        late: seconds,
        fps: 600,
      );
      return response;
    }

    test('a tap 10 ms late is aligned: its clock reads −10 ms and every x '
        'row passes', () {
      final ref = fixture();
      final rows = segmentRows(late(0.010), ref);
      expect(failed(rows), isEmpty);
      expect(row(rows, 'tap_3_1 clock').flutter, '-10.0 ms');
    });

    test('a tap 25 ms late is more than a frame: the clock fails at its '
        'bound', () {
      final ref = fixture();
      final rows = segmentRows(late(0.025), ref);
      expect(failed(rows), contains('tap_3_1 clock'));
      expect(row(rows, 'tap_3_1 clock').flutter, '-16.5 ms');
    });

    test('the clock fits x alone: a tap whose engage is a frame early but '
        'whose x is on time is not shifted', () {
      final ref = fixture();
      final response = synthetic(ref);
      final seqs = _map(response, 'sequences');
      seqs['tap_2_3'] = [
        for (final s in seqs['tap_2_3']! as List<dynamic>)
          {
            ...s as Map<String, dynamic>,
            'engage': _rowAt(
              _rows(_map(ref, 'tap_2_3')),
              (s['t']! as num) - _clock + 1 / 60,
            )[4],
          },
      ];
      final rows = segmentRows(response, ref);
      expect(row(rows, 'tap_2_3 clock').flutter, '0.0 ms');
    });
  });

  test('the engage onset is a latency row against the fixture onset at '
      'display-link resolution', () {
    final ref = fixture();
    final rows = segmentRows(synthetic(ref), ref);
    expect(
      row(rows, 'tap_3_1 engage onset').native,
      (_map(ref, 'tap_3_1')['engageOnset']! as num).toStringAsFixed(3),
    );
    expect(
      row(rows, 'dark.press engage onset').native,
      (_map(_map(ref, 'dark'), 'press')['engageOnset']! as num).toStringAsFixed(
        3,
      ),
    );
  });

  test('a dropped frame after the commit fails the frames row alone', () {
    final ref = fixture();
    final response = synthetic(ref);
    final seqs = _map(response, 'sequences');
    // The frame at +83 ms is gone: 33 ms between two frames, inside one
    // native row step, where the synthetic trace is linear.
    seqs['tap_1_2'] = [
      for (final s in seqs['tap_1_2']! as List<dynamic>)
        if ((((s as Map<String, dynamic>)['t']! as num) - _clock - 5 / 60)
                .abs() >
            1e-6)
          s,
    ];
    final rows = segmentRows(response, ref);
    expect(failed(rows), ['tap_1_2 frames']);
    expect(row(rows, 'tap_1_2 frames').flutter, contains('33.3 ms'));
  });

  group('the flick drive gates the overshoot', () {
    test('a drive of 0.25 s against native 0.548 s fails the drive row, and '
        'the overshoot is not comparable', () {
      final ref = fixture();
      final response = synthetic(ref);
      _map(response, 'drives')['flick'] = _drive(ref, seconds: 0.25);
      final rows = segmentRows(response, ref);
      expect(failed(rows), ['flick drive']);
      final overshoot = row(rows, 'flick overshoot');
      expect(overshoot.comparable, isFalse);
      expect(overshoot.pass, isFalse);
      expect(row(rows, 'flick lands').comparable, isTrue);
    });

    test('a run without its drive is a failed row, the overshoot not '
        'comparable', () {
      final ref = fixture();
      final response = synthetic(ref)..remove('drives');
      final rows = segmentRows(response, ref);
      expect(failed(rows), ['flick drive']);
      expect(row(rows, 'flick overshoot').comparable, isFalse);
    });
  });

  test("the app's change is read on its ticker clock from 0: a ticker "
      'started mid-frame (its first sample a frame late) shifts nothing', () {
    final ref = fixture();
    final response = synthetic(ref);
    final slide = _map(response, 'sequences')['programmatic']! as List<dynamic>;
    (slide.first as Map<String, dynamic>)['t'] = 1 / 60;
    expect(failed(segmentRows(response, ref)), isEmpty);
  });

  test('frames dropped at the rebuild (a first frame 50 ms in) do not move '
      "the ticker clock's origin: the slide is still comparable", () {
    final ref = fixture();
    final response = synthetic(ref);
    final slide = _map(response, 'sequences')['programmatic']! as List<dynamic>;
    // Rows at 0 and 0.05 s: the first frame 50 ms in, at rest still.
    (slide.first as Map<String, dynamic>)['t'] = 0.05;
    final rows = segmentRows(response, ref);
    expect(row(rows, 'programmatic clock').pass, isTrue);
    expect(
      rows
          .where((r) => r.name.startsWith('programmatic x @'))
          .every((r) => r.comparable),
      isTrue,
    );
  });

  test('a ticker already running at the write (its clock a second in, the '
      "driver's rest) fails the programmatic clock and its rows are not "
      'comparable', () {
    final ref = fixture();
    final response = synthetic(ref);
    final seqs = _map(response, 'sequences');
    seqs['programmatic'] = [
      for (final s in seqs['programmatic']! as List<dynamic>)
        {...s as Map<String, dynamic>, 't': (s['t']! as num) + 1.0},
    ];
    final rows = segmentRows(response, ref);
    expect(failed(rows), ['programmatic clock']);
    expect(
      rows
          .where((r) => r.name.startsWith('programmatic x @'))
          .every((r) => !r.comparable),
      isTrue,
    );
  });

  test('a missing sequence is a failed row, not a crash', () {
    final ref = fixture();
    final response = synthetic(ref);
    _map(response, 'sequences').remove('flick');
    expect(failed(segmentRows(response, ref)), ['flick trace']);
  });

  test('missing full3 thumbs is a failed row, not a crash', () {
    final ref = fixture();
    final response = synthetic(ref);
    _map(_map(response, 'geometry'), 'full3').remove('thumbs');
    expect(failed(segmentRows(response, ref)), ['full3 thumbs']);
    _map(_map(response, 'geometry'), 'full3')['thumbs'] = [null, null, null];
    expect(failed(segmentRows(response, ref)), ['full3 thumbs']);
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
      "number changes every comparison row's native column", () {
    final ref = fixture();
    final response = synthetic(ref);
    final base = segmentRows(response, ref);
    final moved = segmentRows(
      response,
      mapNumbers(ref, (n) => n + 1000)! as Map<String, dynamic>,
    );
    expect([for (final r in moved) r.name], [for (final r in base) r.name]);
    // Conditions are not comparisons with native: the clock and frame
    // bounds are the spec's (§14.5), not measurements.
    final unchanged = [
      for (var i = 0; i < base.length; i++)
        if (base[i].kind != Kind.condition && base[i].native == moved[i].native)
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

  test('the table: a header, one line per row, the counts, what is not '
      'comparable and a verdict', () {
    final ref = fixture();
    final response = synthetic(ref);
    _map(response, 'drives')['flick'] = _drive(ref, seconds: 0.25);
    final rows = segmentRows(response, ref);
    final out = StringBuffer();
    final count = printSegmentTable(rows, out);
    final lines = out.toString().trimRight().split('\n');
    expect(count, 1);
    expect(
      lines.first,
      '| check | kind | result | flutter | native | tolerance |',
    );
    expect(lines, contains(startsWith('| flick drive | condition | FAIL |')));
    expect(
      lines,
      contains(startsWith('| flick overshoot | native, fitted | n/a |')),
    );
    expect(lines.length, rows.length + 5);
    expect(lines[lines.length - 2], '1 not comparable: flick overshoot');
    expect(lines.last, '✗ 1 of ${rows.length - 1} failed');
  });
}

/// [response] as another Flutter run might give it: positions, sizes,
/// engage and colours all moved, the times and touches kept.
Map<String, dynamic> _otherRun(Map<String, dynamic> response) {
  final copy = _copy(response);
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
  copy['drives'] = mapNumbers(copy['drives'], (n) => n * 1.1);
  return copy;
}
