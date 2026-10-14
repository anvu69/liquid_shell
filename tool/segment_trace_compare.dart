// Compares the Flutter segmented control traces (the integration_test
// reportData of liquid_shell/example/integration_test/
// segment_fidelity_test.dart) with the native fixture
// docs/qa/vk550/native_reference.json: the numeric gate of spec VK-550
// §14.5. Pure Dart.
//
// Usage: dart run tool/segment_trace_compare.dart <response.json> <reference.json>
//
// Every reference is the fixture's (owner Q3): the native column of a row
// is a fixture number, or a quantity of fixture numbers only (an
// overshoot, a settle time, an engage onset), printed with the fixture
// numbers it is made of. No row compares Flutter with Flutter.
//
// Kinds as tool/tab_trace_compare.dart's (spec VK-503 §17.4): `native`
// rows can fail on the model; `native, constant` rows compare a value
// Flutter takes from a constant typed in from the same native measurement
// (the 32 pt track, the 2 pt inset, the case's 16 pt margins, the fill
// colours), so only the plumbing can fail them.
//
// The response:
//   {'geometry': {id: {'track': [l, t, w, h], 'thumb' | 'thumbs': …}},
//    'sequences': {name: [{t, x, y, w, h, engage, touch, finger}, …]},
//    'colours': {name: [r, g, b]}}
// in screen points; the fixture's x is control-local (the track's left).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'trace_math.dart';

/// One row of the table: the Flutter value and the native reference as
/// printed.
typedef SegmentRow = ({
  String name,
  Kind kind,
  bool pass,
  String flutter,
  String native,
  String tolerance,
});

/// A trace: one sample per engine frame.
typedef Trace = List<Map<String, double>>;

/// One native row: `[t, x, w, h, engage]` (the fixture's `columns`).
typedef NativeRow = List<double>;

/// A tap capture: the table's name, the Flutter sequence, the fixture
/// block (a path of keys) and the control it ran on.
typedef _Capture = ({
  String name,
  String sequence,
  List<String> path,
  String control,
});

/// The five tap captures of spec §14.5 (light, dark, five segments).
const List<_Capture> _taps = [
  (name: 'tap_1_2', sequence: 'tap_1_2', path: ['tap_1_2'], control: 'full3'),
  (name: 'tap_2_3', sequence: 'tap_2_3', path: ['tap_2_3'], control: 'full3'),
  (name: 'tap_3_1', sequence: 'tap_3_1', path: ['tap_3_1'], control: 'full3'),
  (
    name: 'dark.tap_1_2',
    sequence: 'dark_tap_1_2',
    path: ['dark', 'tap_1_2'],
    control: 'full3',
  ),
  (
    name: 'tap_1_3_5seg',
    sequence: 'tap_1_3_5seg',
    path: ['tap_1_3_5seg'],
    control: 'full5',
  ),
];

/// Tap rows are compared every 0.05 s to here (spec §14.5).
const double _tapRowsTo = 0.6;

/// One display frame: the engage onset's tolerance and the most the tap
/// clock may be shifted (spec §14.5, tap clock alignment).
const double _frame = 1 / 60;

/// Row times are differences of fixture times: this absorbs their
/// rounding.
const double _eps = 1e-6;

/// Every spec §14.5 row for [response] (the Flutter reportData) against
/// [fixture]. A missing part of the response is one failed row.
List<SegmentRow> segmentRows(
  Map<String, dynamic> response,
  Map<String, dynamic> fixture,
) => _Table(response, fixture).rows();

/// Prints [rows] as a Markdown table, then the counts per kind and the
/// verdict, to [out]; returns how many failed.
int printSegmentTable(List<SegmentRow> rows, StringSink out) {
  out
    ..writeln('| check | kind | result | flutter | native | tolerance |')
    ..writeln('|---|---|---|---|---|---|');
  for (final r in rows) {
    out.writeln(
      '| ${r.name} | ${r.kind.label} | ${r.pass ? 'pass' : 'FAIL'} | '
      '${r.flutter} | ${r.native} | ${r.tolerance} |',
    );
  }
  return writeSummary(out, [for (final r in rows) (r.kind, r.pass)]);
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'usage: segment_trace_compare.dart <response.json> <reference.json>',
    );
    exit(64);
  }
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final failed = printSegmentTable(
    segmentRows(read(args[0]), read(args[1])),
    stdout,
  );
  exit(failed == 0 ? 0 : 1);
}

String _n(double? v, [int digits = 2]) =>
    v == null || v.isNaN ? 'none' : v.toStringAsFixed(digits);

double _d(Object? v) => (v! as num).toDouble();

List<double> _list(Object? v) => [
  for (final e in v! as List<dynamic>) (e as num).toDouble(),
];

class _Table {
  _Table(this._response, this._fixture);

  final Map<String, dynamic> _response;
  final Map<String, dynamic> _fixture;
  final List<SegmentRow> _rows = [];

  List<SegmentRow> rows() {
    _geometry();
    _taps.forEach(_tap);
    _press();
    _drag();
    _flick();
    _programmatic();
    _colours();
    return _rows;
  }

  /// [value] against [reference] within [abs] or [rel]; [note] follows
  /// the reference (the fixture numbers a derived one is made of).
  void _add(
    String name,
    Kind kind,
    double? value,
    double? reference, {
    double? abs,
    double? rel,
    int digits = 2,
    String note = '',
  }) {
    final ok =
        value != null &&
        reference != null &&
        near(value, reference, band(reference, abs: abs, rel: rel));
    _rows.add((
      name: name,
      kind: kind,
      pass: ok,
      flutter: _n(value, digits),
      native: '${_n(reference, digits)}$note',
      tolerance: abs != null
          ? '±${_n(abs, digits)}'
          : '±${(rel! * 100).round()} %',
    ));
  }

  /// A part of the response that is not there: one failed row.
  void _missing(String name) => _rows.add((
    name: name,
    kind: Kind.native,
    pass: false,
    flutter: 'missing',
    native: 'recorded',
    tolerance: '',
  ));

  Map<String, dynamic> _fix(List<String> path) => path.fold(
    _fixture,
    (m, key) => m[key]! as Map<String, dynamic>,
  );

  /// The rows of a fixture block (its [key]).
  List<NativeRow> _native(List<String> path, [String key = 'rows']) => [
    for (final r in _fix(path)[key]! as List<dynamic>) _list(r),
  ];

  /// Each row's time from the block's first (its t0: the commit, the
  /// touch-down or the touch-up, as the fixture's `source` says).
  static List<double> _times(List<NativeRow> rows) => [
    for (final r in rows) r[0] - rows.first[0],
  ];

  static String _ms(double t) => '${(t * 1000).round()}ms';

  /// The response's geometry of control [id], or null.
  Map<String, dynamic>? _control(String id) =>
      (_response['geometry'] as Map<String, dynamic>?)?[id]
          as Map<String, dynamic>?;

  /// The track rect of control [id]: left, top, width, height.
  List<double>? _track(String id) {
    final c = _control(id);
    return c == null ? null : _list(c['track']);
  }

  /// The Flutter trace [name], x and finger made control-local (the
  /// fixture's frame) on [control]'s track; null and a failed row when it
  /// is not there.
  Trace? _trace(String name, String control) {
    final raw =
        (_response['sequences'] as Map<String, dynamic>?)?[name]
            as List<dynamic>?;
    if (raw == null || raw.isEmpty) {
      _missing('$name trace');
      return null;
    }
    final left = _track(control)?[0] ?? 0;
    return [
      for (final s in raw)
        (s as Map<String, dynamic>).map((k, v) {
          final value = (v as num).toDouble();
          return MapEntry(k, k == 'x' || k == 'finger' ? value - left : value);
        }),
    ];
  }

  /// Track, segment and thumb rects (spec §14.5, ±`geometry.tolerance`):
  /// two, three and five segments at full width, and the intrinsic width.
  void _geometry() {
    final g = _fix(['geometry']);
    final tol = _d(g['tolerance']);
    void add(String name, Kind kind, double value, Object? reference) =>
        _add(name, kind, value, _d(reference), abs: tol);
    for (final id in ['full3', 'full2', 'full5', 'intrinsic3']) {
      if (_control(id) == null) _missing('$id geometry');
    }
    // The case lays the full-width controls between 16 pt margins and the
    // track is 32 pt (SegmentMetrics), both typed in from native.
    for (final id in ['full3', 'full2', 'full5']) {
      final track = _track(id);
      if (track == null) continue;
      add('$id track width', Kind.constant, track[2], g['width']);
      add('$id track height', Kind.constant, track[3], g['height']);
    }
    // x and w are the equal split of the track, W/n − 4 (spec §5), which
    // native rounds to whole points: the model can fail them. y and h are
    // the 2 pt inset of the 32 pt track: constants.
    final full3 = _control('full3');
    final track3 = _track('full3');
    if (full3 != null && track3 != null) {
      final thumbs = full3['thumbs']! as List<dynamic>;
      final want = g['thumbs3']! as List<dynamic>;
      for (var i = 0; i < 3; i++) {
        final got = _list(thumbs[i]);
        final ref = _list(want[i]);
        add('thumb$i x', Kind.native, got[0] - track3[0], ref[0]);
        add('thumb$i y', Kind.constant, got[1] - track3[1], ref[1]);
        add('thumb$i w', Kind.native, got[2], ref[2]);
        add('thumb$i h', Kind.constant, got[3], ref[3]);
      }
    }
    for (final (id, key) in [('full2', 'thumb2'), ('full5', 'thumb5')]) {
      final c = _control(id);
      if (c == null) continue;
      final got = _list(c['thumb']);
      final ref = _list(g[key]);
      add('$id thumb w', Kind.native, got[2], ref[0]);
      add('$id thumb h', Kind.constant, got[3], ref[1]);
    }
    // Sized to the labels: the widest Medium label (measured by the
    // engine's font) + 18 (spec §5), three times.
    final intrinsic = _track('intrinsic3');
    if (intrinsic != null) {
      add('intrinsic3 width', Kind.native, intrinsic[2], g['intrinsic3']);
    }
  }

  /// A tap capture (spec §14.5): the engage onset, x every 0.05 s to
  /// 0.6 s on the engage-aligned clock, the overshoot, the settle time, the
  /// peak height and the wobble's extremes. The model's tap springs were
  /// fitted to these rows (spec §8.2, Task 4): with two springs, a blend
  /// and two delays for 65 rows, it can still fail them.
  void _tap(_Capture c) {
    final trace = _trace(c.sequence, c.control);
    if (trace == null) return;
    final native = _native(c.path);
    final lift = liftIndex(trace);
    if (lift == 0) {
      _missing('${c.sequence} lift');
      return;
    }
    // Flutter's t0 is the last frame before the up: the next frame
    // advances the commit over the whole frame, as the engine's own clock
    // (segment_motion_test.dart). Native's is valueChanged.
    final t0 = trace[lift - 1]['t']!;
    final after = trace.sublist(lift - 1);
    final ts = _times(native);
    final ourOnset = onset(
      [for (final s in after) s['t']! - t0],
      [
        for (final s in after) s['engage']!,
      ],
    );
    final nativeOnset = onset(ts, [for (final r in native) r[4]]);
    _add(
      '${c.name} engage onset',
      Kind.native,
      ourOnset,
      nativeOnset,
      abs: _frame,
      digits: 3,
    );
    // The tap clock alignment (spec §14.5): each capture's rows are read
    // at t − shift, the onsets' difference, which the row above holds to
    // one frame.
    final shift = ourOnset != null && nativeOnset != null
        ? nativeOnset - ourOnset
        : 0.0;
    double at(double t, String key) => valueAt(after, t - shift, key, zero: t0);

    for (var i = 0; i < native.length; i++) {
      if (ts[i] > _tapRowsTo + _eps) continue;
      _add(
        '${c.name} x @${_ms(ts[i])}',
        Kind.native,
        at(ts[i], 'x'),
        native[i][1],
        abs: 2,
      );
    }

    final from = native.first[1];
    final rest = native.last[1];
    final xs = [for (final r in native) r[1]];
    final sign = (rest - from).sign;
    final peak = xs.reduce(sign > 0 ? math.max : math.min);
    final ourRest = after.last['x']!;
    _add(
      '${c.name} overshoot',
      Kind.native,
      overshoot([for (final s in after) s['x']!], after.first['x']!, ourRest),
      overshoot(xs, from, rest),
      abs: 1,
      note: ' (peak ${_n(peak)}, rest ${_n(rest)})',
    );
    _add(
      '${c.name} settle',
      Kind.native,
      settle([for (final t in ts) at(t, 'x')], ourRest, ts: ts),
      settle(xs, rest, ts: ts),
      rel: 0.10,
      digits: 3,
      note: ' s (x within 0.5 of ${_n(rest)})',
    );
    _add(
      '${c.name} peak h',
      Kind.native,
      [for (final t in ts) at(t, 'h')].reduce(math.max),
      [for (final r in native) r[3]].reduce(math.max),
      rel: 0.10,
    );
    // The wobble (spec §8.4): once x passes its rest, the size swings
    // past its own; the extreme of each, against native's at the same
    // rows.
    final past = native.indexWhere((r) => (r[1] - rest) * sign > 0);
    for (final (key, column) in [('w', 2), ('h', 3)]) {
      final restValue = native.last[column];
      final nativeValues = [
        for (final r in native.skip(math.max(past, 0))) r[column],
      ];
      final extreme = nativeValues.reduce(
        (a, b) => (b - restValue).abs() > (a - restValue).abs() ? b : a,
      );
      final ourValues = [
        for (var i = math.max(past, 0); i < native.length; i++) at(ts[i], key),
      ];
      _add(
        '${c.name} $key wobble',
        Kind.native,
        ourValues.reduce(extreme < restValue ? math.min : math.max),
        extreme,
        rel: 0.10,
      );
    }
  }

  /// The press on the selected segment held 2 s, then its release in
  /// place (spec §14.5): size every native row (±2 pt), engage onset
  /// against the light and dark captures (±1 frame), then the release's
  /// size and engage to +0.2 s (±2 pt, ±0.12).
  void _press() {
    final trace = _trace('press', 'full3');
    if (trace == null) return;
    final down = trace.indexWhere((s) => s['touch'] == 1);
    final lift = liftIndex(trace);
    if (down < 0 || lift == 0) {
      _missing('press touch');
      return;
    }
    // t0: the first frame after the down (the ticker starts there, with
    // nothing advanced yet). Native's t0 is the touch-down.
    final held = trace.sublist(down);
    final t0 = held.first['t']!;
    final press = _native(['press']);
    final ts = _times(press);
    for (var i = 0; i < press.length; i++) {
      if (ts[i] <= _eps) continue;
      for (final (key, column) in [('w', 2), ('h', 3)]) {
        _add(
          'press $key @${_ms(ts[i])}',
          Kind.native,
          valueAt(held, ts[i], key, zero: t0),
          press[i][column],
          abs: 2,
        );
      }
    }
    final ours = onset(
      [for (final s in held) s['t']! - t0],
      [
        for (final s in held) s['engage']!,
      ],
    );
    for (final (name, path) in [
      ('press', ['press']),
      ('dark.press', ['dark', 'press']),
    ]) {
      final rows = _native(path);
      _add(
        '$name engage onset',
        Kind.native,
        ours,
        onset(_times(rows), [for (final r in rows) r[4]]),
        abs: _frame,
        digits: 3,
      );
    }

    final up = trace[lift - 1]['t']!;
    final lifted = trace.sublist(lift - 1);
    final release = _native(['release']);
    final rts = _times(release);
    for (var i = 0; i < release.length; i++) {
      if (rts[i] <= _eps || rts[i] > 0.2 + _eps) continue;
      for (final (key, column, tol) in [
        ('w', 2, 2.0),
        ('h', 3, 2.0),
        ('engage', 4, 0.12),
      ]) {
        _add(
          'release $key @+${_ms(rts[i])}',
          Kind.native,
          valueAt(lifted, rts[i], key, zero: up),
          release[i][column],
          abs: tol,
        );
      }
    }
  }

  /// The slow drag's steady lag (spec §14.5, ±10 %): Flutter's, scaled
  /// from its own finger speed to native's (a spring's ramp lag is
  /// proportional to the speed), against native's.
  void _drag() {
    final trace = _trace('slow_drag', 'full3');
    if (trace == null) return;
    final touching = [
      for (final s in trace)
        if (s['touch'] == 1) s,
    ];
    if (touching.length < 6) {
      _missing('slow_drag touch');
      return;
    }
    final fit = _fix(['fits', 'dragLag']);
    final speed = _d(fit['speed']);
    final reference = _d(fit['lag']);
    final ourSpeed = rampSpeed(touching);
    final ours = steadyLag(touching);
    final scaled = ours * speed / ourSpeed;
    _rows.add((
      name: 'drag lag',
      kind: Kind.native,
      pass: near(scaled, reference, band(reference, rel: 0.10)),
      flutter: '${_n(scaled)} (${_n(ours)} at ${_n(ourSpeed, 1)} pt/s)',
      native: '${_n(reference)} at ${_n(speed, 1)} pt/s',
      tolerance: '±10 %',
    ));
  }

  /// The flick (spec §14.5): it lands on the finger's segment (±0.5 pt)
  /// and overshoots it as native's landing does (±1 pt).
  void _flick() {
    final trace = _trace('flick', 'full3');
    if (trace == null) return;
    final landing = _fix(['flickLanding']);
    final lift = liftIndex(trace);
    final after = trace.sublist(lift == 0 ? 0 : lift - 1);
    final rest = trace.last['x']!;
    _add(
      'flick lands',
      Kind.native,
      rest,
      _d(landing['landing']),
      abs: 0.5,
    );
    _add(
      'flick overshoot',
      Kind.native,
      overshoot([for (final s in after) s['x']!], after.first['x']!, rest),
      _d(landing['overshoot']),
      abs: 1,
    );
  }

  /// The app's own change (spec §14.5, ±2 pt per row). Native's capture
  /// is a two-segment control (185 pt of travel), the Flutter case's
  /// "Next segment" moves the three-segment one (123 pt): a spring's path
  /// scales with its distance, so the Flutter x is mapped onto native's
  /// from and to.
  ///
  /// t is the ticker's own clock, 0 at the rebuild that applied the app's
  /// write: the control starts its ticker during that frame's layout, and
  /// a ticker started mid-frame takes that frame as its start, so its
  /// first sample is already a frame in (and a frame advanced). The write
  /// itself lands up to a frame before that rebuild; native's t0 is the
  /// write.
  void _programmatic() {
    final trace = _trace('programmatic', 'full3');
    if (trace == null) return;
    final native = _native(['programmatic_2seg']);
    final ts = _times(native);
    final from = native.first[1];
    final to = native.last[1];
    final ourFrom = trace.first['x']!;
    final ourTo = trace.last['x']!;
    for (var i = 0; i < native.length; i++) {
      final x = valueAt(trace, ts[i], 'x', zero: 0);
      _add(
        'programmatic x @${_ms(ts[i])}',
        Kind.native,
        from + (x - ourFrom) / (ourTo - ourFrom) * (to - from),
        native[i][1],
        abs: 2,
      );
    }
  }

  /// Rest colours over white and black (spec §14.5, ±`colors.tolerance`
  /// per channel). Every one is a flat fill or a text colour typed in from
  /// the native measurement (spec §6: #767680 @ 0.12 / 0.24, #FFFFFF,
  /// #EBEBF5 @ 0.30, black and white labels, the disabled control at 0.5):
  /// native, constant.
  void _colours() {
    final sampled = _response['colours'] as Map<String, dynamic>?;
    if (sampled == null) {
      _missing('colours');
      return;
    }
    final want = _fix(['colors']);
    final tol = _d(want['tolerance']);
    String rgb(List<double> c) => c.map((v) => v.round()).join('/');
    for (final name in [
      'lightTrackOverWhite',
      'lightThumb',
      'lightLabel',
      'lightDisabledTrack',
      'darkTrackOverBlack',
      'darkThumbOverTrack',
      'darkLabel',
    ]) {
      if (sampled[name] == null) {
        _missing('colour $name');
        continue;
      }
      final got = _list(sampled[name]);
      final ref = _list(want[name]);
      _rows.add((
        name: 'colour $name',
        kind: Kind.constant,
        pass: colourCheck(got, ref, tol).pass,
        flutter: rgb(got),
        native: rgb(ref),
        tolerance: '±${tol.round()}',
      ));
    }
  }
}
