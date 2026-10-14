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
// overshoot, a settle time), printed with the fixture numbers it is made
// of. No row compares Flutter with Flutter.
//
// Kinds as tool/tab_trace_compare.dart's (spec VK-503 §17.4), plus two:
// - `native`: independent native data the model can fail;
// - `native, constant`: Flutter takes the value from a constant typed in
//   from the same measurement (the 32 pt track, the 2 pt inset, the
//   case's 16 pt margins, the fill colours): only the plumbing can fail;
// - `native, fitted`: the rows the model's springs were fitted to (the
//   tap, press, release and programmatic rows, spec §8.2): in sample, so
//   only the model's shape can fail them;
// - `condition`: a precondition of other rows (the gesture against
//   native's, the tap clock, dropped frames), not a comparison. A row
//   whose condition fails is `n/a`, neither a pass nor a failure.
//
// The response:
//   {'geometry': {id: {'track': [l, t, w, h], 'thumb' | 'thumbs': …}},
//    'sequences': {name: [{t, x, y, w, h, engage, touch, finger}, …]},
//    'drives': {'flick': {'seconds', 'from', 'to'}},
//    'colours': {name: [r, g, b]}}
// in screen points (drives control-local); the fixture's x is
// control-local (the track's left).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'trace_math.dart';

/// One row of the table: the Flutter value and the native reference as
/// printed. A row that is not `comparable` (its condition failed) does not
/// `pass` and does not fail.
typedef SegmentRow = ({
  String name,
  Kind kind,
  bool pass,
  bool comparable,
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

/// One display frame: the engage onset's tolerance, the flick drive's.
const double _frame = 1 / 60;

/// The tap clock's grid (0.5 ms) and its bound, the last grid step within
/// one frame (spec §14.5, amended 2026-10-14).
const double _clockStep = 0.0005;
const int _clockSteps = 33;

/// The longest gap between two frames a tap may have after its commit:
/// one and a half frames (spec §14.5, amended 2026-10-14).
const double _maxGap = 1.5 / 60;

/// The app's change must find the ticker idle. A ticker already running
/// would show its time since its own start, at least the second the driver
/// rests before each sequence; frames dropped at the rebuild (50 ms seen
/// under load) do not move the clock's origin.
const double _maxTickerStart = 0.25;

/// Row times are differences of fixture times: this absorbs their
/// rounding.
const double _eps = 1e-6;

/// Every spec §14.5 row for [response] (the Flutter reportData) against
/// [fixture]. A missing part of the response is one failed row.
List<SegmentRow> segmentRows(
  Map<String, dynamic> response,
  Map<String, dynamic> fixture,
) => _Table(response, fixture).rows();

/// Prints [rows] as a Markdown table, then the counts per kind, the rows
/// that could not be compared and the verdict, to [out]; returns how many
/// failed.
int printSegmentTable(List<SegmentRow> rows, StringSink out) {
  out
    ..writeln('| check | kind | result | flutter | native | tolerance |')
    ..writeln('|---|---|---|---|---|---|');
  for (final r in rows) {
    final result = !r.comparable
        ? 'n/a'
        : r.pass
        ? 'pass'
        : 'FAIL';
    out.writeln(
      '| ${r.name} | ${r.kind.label} | $result | '
      '${r.flutter} | ${r.native} | ${r.tolerance} |',
    );
  }
  return writeSummary(
    out,
    [
      for (final r in rows)
        if (r.comparable) (r.kind, r.pass),
    ],
    notComparable: [
      for (final r in rows)
        if (!r.comparable) r.name,
    ],
  );
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

String _msOf(double seconds) => '${(seconds * 1000).toStringAsFixed(1)} ms';

double _d(Object? v) => (v! as num).toDouble();

double? _maybe(Object? v) => (v as num?)?.toDouble();

List<double> _list(Object? v) => [
  for (final e in v! as List<dynamic>) (e as num).toDouble(),
];

/// [v] as a list of numbers, or null when it is not one.
List<double>? _numbers(Object? v) =>
    v is List<dynamic> && v.every((e) => e is num) ? _list(v) : null;

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
  /// the reference (the fixture numbers a derived one is made of). Not
  /// [comparable]: printed, neither passed nor failed.
  void _add(
    String name,
    Kind kind,
    double? value,
    double? reference, {
    double? abs,
    double? rel,
    int digits = 2,
    String note = '',
    bool comparable = true,
  }) {
    final ok =
        comparable &&
        value != null &&
        reference != null &&
        near(value, reference, band(reference, abs: abs, rel: rel));
    _rows.add((
      name: name,
      kind: kind,
      pass: ok,
      comparable: comparable,
      flutter: _n(value, digits),
      native: '${_n(reference, digits)}$note',
      tolerance: abs != null
          ? '±${_n(abs, digits)}'
          : '±${(rel! * 100).round()} %',
    ));
  }

  /// A condition: [pass] or not, both columns as printed.
  void _condition(
    String name, {
    required bool pass,
    required String flutter,
    required String native,
  }) => _rows.add((
    name: name,
    kind: Kind.condition,
    pass: pass,
    comparable: true,
    flutter: flutter,
    native: native,
    tolerance: '',
  ));

  /// A part of the response that is not there: one failed row.
  void _missing(String name, {Kind kind = Kind.native}) => _rows.add((
    name: name,
    kind: kind,
    pass: false,
    comparable: true,
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
  List<double>? _track(String id) => _numbers(_control(id)?['track']);

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
      if (_track(id) == null) _missing('$id geometry');
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
    final track3 = _track('full3');
    if (track3 != null) {
      final thumbs = _control('full3')?['thumbs'];
      final got = thumbs is List<dynamic> && thumbs.length == 3
          ? [for (final t in thumbs) _numbers(t)]
          : null;
      if (got == null || got.contains(null)) {
        _missing('full3 thumbs');
      } else {
        final want = g['thumbs3']! as List<dynamic>;
        for (var i = 0; i < 3; i++) {
          final rect = got[i]!;
          final ref = _list(want[i]);
          add('thumb$i x', Kind.native, rect[0] - track3[0], ref[0]);
          add('thumb$i y', Kind.constant, rect[1] - track3[1], ref[1]);
          add('thumb$i w', Kind.native, rect[2], ref[2]);
          add('thumb$i h', Kind.constant, rect[3], ref[3]);
        }
      }
    }
    for (final (id, key) in [('full2', 'thumb2'), ('full5', 'thumb5')]) {
      if (_track(id) == null) continue;
      final got = _numbers(_control(id)?['thumb']);
      if (got == null) {
        _missing('$id thumb');
        continue;
      }
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

  /// A tap capture (spec §14.5, amended 2026-10-14):
  /// - `engage onset`: a latency row against native's onset at
  ///   display-link resolution (`engageOnset`), ±1 frame;
  /// - `clock`: the shift, within ±1 frame on a 0.5 ms grid, that best
  ///   fits Flutter's x to the native rows (least squares to 0.6 s); a
  ///   shift at the bound fails: more than a frame apart;
  /// - `frames`: the longest gap between Flutter frames from the commit
  ///   to 0.6 s, at most 1.5 frames;
  /// - x every 0.05 s to 0.6 s on that clock, the overshoot, the settle
  ///   time, the peak height and the wobble's extremes: the rows the
  ///   model's tap springs were fitted to (spec §8.2, Task 4), in sample.
  void _tap(_Capture c) {
    final trace = _trace(c.sequence, c.control);
    if (trace == null) return;
    final block = _fix(c.path);
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
    final ourTs = [for (final s in after) s['t']! - t0];
    final ts = _times(native);
    _add(
      '${c.name} engage onset',
      Kind.native,
      onset(ourTs, [for (final s in after) s['engage']!]),
      _maybe(block['engageOnset']),
      abs: _frame,
      digits: 3,
    );

    final rows = [
      for (var i = 0; i < native.length; i++)
        if (ts[i] <= _tapRowsTo + _eps) i,
    ];
    double at(double shift, double t, String key) =>
        valueAt(after, t - shift, key, zero: t0);
    final shift = bestShift(
      (s) => rows.fold(
        0,
        (sum, i) => sum + math.pow(at(s, ts[i], 'x') - native[i][1], 2),
      ),
      from: -_clockSteps,
      steps: 2 * _clockSteps,
      step: _clockStep,
    );
    _condition(
      '${c.name} clock',
      pass: shift.abs() < _clockSteps * _clockStep - _eps,
      flutter: _msOf(shift),
      native:
          'x rows to ${_ms(_tapRowsTo)}, '
          'within ±${_msOf(_clockSteps * _clockStep)}',
    );
    final gap = longestGap([
      for (final t in ourTs)
        if (t <= _tapRowsTo + _eps) t,
    ]);
    _condition(
      '${c.name} frames',
      pass: gap.gap <= _maxGap + _eps,
      flutter: 'longest ${_msOf(gap.gap)} at +${_msOf(gap.at)}',
      native: 'at most ${_msOf(_maxGap)}',
    );

    for (final i in rows) {
      _add(
        '${c.name} x @${_ms(ts[i])}',
        Kind.fitted,
        at(shift, ts[i], 'x'),
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
      Kind.fitted,
      overshoot([for (final s in after) s['x']!], after.first['x']!, ourRest),
      overshoot(xs, from, rest),
      abs: 1,
      note: ' (peak ${_n(peak)}, rest ${_n(rest)})',
    );
    _add(
      '${c.name} settle',
      Kind.fitted,
      settle([for (final t in ts) at(shift, t, 'x')], ourRest, ts: ts),
      settle(xs, rest, ts: ts),
      rel: 0.10,
      digits: 3,
      note: ' s (x within 0.5 of ${_n(rest)})',
    );
    _add(
      '${c.name} peak h',
      Kind.fitted,
      [for (final t in ts) at(shift, t, 'h')].reduce(math.max),
      [for (final r in native) r[3]].reduce(math.max),
      rel: 0.10,
    );
    // The wobble (spec §8.4): once x passes its rest, the size swings
    // past its own; the extreme of each, against native's at the same
    // rows.
    final past = math.max(
      0,
      native.indexWhere((r) => (r[1] - rest) * sign > 0),
    );
    for (final (key, column) in [('w', 2), ('h', 3)]) {
      final restValue = native.last[column];
      final nativeValues = [for (final r in native.skip(past)) r[column]];
      final extreme = nativeValues.reduce(
        (a, b) => (b - restValue).abs() > (a - restValue).abs() ? b : a,
      );
      final ourValues = [
        for (var i = past; i < native.length; i++) at(shift, ts[i], key),
      ];
      _add(
        '${c.name} $key wobble',
        Kind.fitted,
        ourValues.reduce(extreme < restValue ? math.min : math.max),
        extreme,
        rel: 0.10,
      );
    }
  }

  /// The press on the selected segment held 2 s, then its release in
  /// place (spec §14.5): size every native row (±2 pt), engage onset
  /// against the light and dark captures' onsets at display-link
  /// resolution (±1 frame), then the release's size and engage to +0.2 s
  /// (±2 pt, ±0.12). The press and release springs were fitted to these
  /// rows (spike §3, Task 4): in sample.
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
          Kind.fitted,
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
      _add(
        '$name engage onset',
        Kind.native,
        ours,
        _maybe(_fix(path)['engageOnset']),
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
          Kind.fitted,
          valueAt(lifted, rts[i], key, zero: up),
          release[i][column],
          abs: tol,
        );
      }
    }
  }

  /// The slow drag's steady lag (spec §14.5, ±10 %): Flutter's, scaled
  /// from its own finger speed to native's (a spring's ramp lag is
  /// proportional to the speed), against native's. Out of sample: the
  /// follow spring is VK-503's.
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
      comparable: true,
      flutter: '${_n(scaled)} (${_n(ours)} at ${_n(ourSpeed, 1)} pt/s)',
      native: '${_n(reference)} at ${_n(speed, 1)} pt/s',
      tolerance: '±10 %',
    ));
  }

  /// The flick (spec §14.5) against native's `flickLanding` capture:
  /// - `flick drive`: the gesture the Flutter run made (its driver's own
  ///   clock, down to up, and the finger's travel) against native's
  ///   (`release_at`; from segment 3's thumb centre to `landing`), ±1
  ///   frame and ±2 pt. The overshoot depends on the release speed: when
  ///   the drive differs, the overshoot row is not comparable;
  /// - `flick lands` on the finger's segment (±0.5 pt);
  /// - `flick overshoot` past it, as native's landing (±1 pt). Out of
  ///   sample: the release spring was fitted to the other capture,
  ///   `flick`.
  void _flick() {
    final trace = _trace('flick', 'full3');
    final landing = _fix(['flickLanding']);
    final g = _fix(['geometry']);
    final thumb = _list((g['thumbs3']! as List<dynamic>)[2]);
    final seconds = _d(landing['release_at']);
    final travel = thumb[0] + thumb[2] / 2 - _d(landing['landing']);
    final drive =
        (_response['drives'] as Map<String, dynamic>?)?['flick']
            as Map<String, dynamic>?;
    final ourSeconds = _maybe(drive?['seconds']);
    final ourFrom = _maybe(drive?['from']);
    final ourTo = _maybe(drive?['to']);
    var driven = false;
    if (ourSeconds == null || ourFrom == null || ourTo == null) {
      _missing('flick drive', kind: Kind.condition);
    } else {
      driven =
          near(ourSeconds, seconds, _frame) && near(ourFrom - ourTo, travel, 2);
      _condition(
        'flick drive',
        pass: driven,
        flutter: '${_n(ourSeconds, 3)} s over ${_n(ourFrom - ourTo)} pt',
        native:
            '${_n(seconds, 3)} s over ${_n(travel)} pt '
            '(±1 frame, ±2 pt)',
      );
    }
    if (trace == null) return;
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
      comparable: driven,
    );
  }

  /// The app's own change (spec §14.5, ±2 pt per row). Native's capture
  /// is a two-segment control (185 pt of travel), the Flutter case's
  /// "Next segment" moves the three-segment one (123 pt): a spring's path
  /// scales with its distance, so the Flutter x is mapped onto native's
  /// from and to. The programmatic spring was fitted to these rows (spike
  /// §3, Task 4): in sample.
  ///
  /// t is the ticker's own clock, 0 at the rebuild that applied the app's
  /// write: the control starts its ticker during that frame's layout, and
  /// a ticker started mid-frame takes that frame as its start, so its
  /// first sample is already a frame in (and a frame advanced). That holds
  /// only when the ticker was idle at the write: `programmatic clock`
  /// checks that the first sample is within 0.25 s of 0 (a running ticker
  /// would be a second or more in), and the rows are not comparable when
  /// it is not. The write itself lands up to a
  /// frame before that rebuild; native's t0 is the write.
  void _programmatic() {
    final trace = _trace('programmatic', 'full3');
    if (trace == null) return;
    final start = trace.first['t']!;
    final idle = start <= _maxTickerStart + _eps;
    _condition(
      'programmatic clock',
      pass: idle,
      flutter: 'first frame at ${_msOf(start)}',
      native: 'within ${_msOf(_maxTickerStart)} of the write',
    );
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
        Kind.fitted,
        from + (x - ourFrom) / (ourTo - ourFrom) * (to - from),
        native[i][1],
        abs: 2,
        comparable: idle,
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
      final got = _numbers(sampled[name]);
      if (got == null) {
        _missing('colour $name');
        continue;
      }
      final ref = _list(want[name]);
      _rows.add((
        name: 'colour $name',
        kind: Kind.constant,
        pass: colourCheck(got, ref, tol).pass,
        comparable: true,
        flutter: rgb(got),
        native: rgb(ref),
        tolerance: '±${tol.round()}',
      ));
    }
  }
}
