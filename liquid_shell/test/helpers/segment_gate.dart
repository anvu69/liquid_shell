// The tap gate (spec VK-550 §14.5) for the model's tests: the one
// implementation the device table uses (tool/segment_gate.dart), and the
// model tapped as a capture was.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

import '../../../tool/segment_gate.dart';

export '../../../tool/segment_gate.dart';
export '../../../tool/trace_math.dart' show onset;

/// The rows of [key] (its `rows`) in [ref] as the gate reads them:
/// t, x, w, h, engage.
List<TapRow> tapRowsOf(Map<String, dynamic> ref, String key) => [
  for (final r in ((ref[key] as Map)['rows'] as List).cast<List<dynamic>>())
    [for (final v in r) (v as num).toDouble()],
];

/// One native tap of a file of captures (`native_taps.json`,
/// `native_holdout.json`).
typedef NativeTap = ({
  String key,
  int repeat,
  String split,
  int segments,
  bool rtl,
  int from,
  int to,
  List<TapRow> rows,
});

/// The captures of [file] in docs/qa/vk550 (read from the package
/// directory). A file whose captures carry no `split` needs [split].
List<NativeTap> nativeTaps(String file, {String? split}) => nativeTapsOf(
  jsonDecode(File('../docs/qa/vk550/$file').readAsStringSync())
      as Map<String, dynamic>,
  split: split,
);

/// The captures of an already decoded file: each one's own `split`, else
/// [split], else a [FormatException]. A capture never lands in a split by
/// default: a missing key must not turn a fit tap into a held-out one.
List<NativeTap> nativeTapsOf(Map<String, dynamic> json, {String? split}) => [
  for (final c in (json['captures'] as List).cast<Map<String, dynamic>>())
    (
      key: c['key'] as String,
      repeat: (c['pass'] ?? c['repeat']) as int,
      split:
          (c['split'] as String?) ??
          split ??
          (throw FormatException('capture ${c['key']} has no split')),
      segments: c['segments'] as int,
      rtl: (c['rtl'] ?? false) as bool,
      from: c['from'] as int,
      to: c['to'] as int,
      rows: tapRowsOf({'c': c}, 'c'),
    ),
];

/// The discriminating taps (Task 15 review): `native_taps.json`.
List<NativeTap> segmentTaps() => nativeTaps('native_taps.json');

/// The model's tap, as a capture was made: a press on the target, the up
/// one frame later, then every millisecond from the commit to +1.5 s.
final class ModelTap {
  /// Taps the model from segment [from] to [to] of a [count]-segment
  /// control 370 wide (the fixture's, spike §2).
  factory ModelTap(
    int count,
    int from,
    int to, {
    TextDirection direction = TextDirection.ltr,
    LensProfile? profile,
  }) {
    final g = segmentGeometry(
      count: count,
      maxWidth: 370,
      lineHeight: 15.67,
      direction: direction,
    );
    final m = LensMotion(
      geometry: g,
      selected: from,
      profile: profile ?? LensProfile.segment,
    );
    final finger = Offset(g.centreOf(to), g.size.height / 2);
    m
      ..down(finger)
      ..advance(1 / 60);
    final committed = m.up(finger);
    final frames = [m.frame];
    for (var i = 1; i <= 1500; i++) {
      m.advance(0.001);
      frames.add(m.frame);
    }
    return ModelTap._(frames, committed, g.centreOf(to));
  }

  ModelTap._(this.frames, this.committed, this.rest);

  /// The frames, every millisecond from the commit.
  final List<LensFrame> frames;

  /// What the up committed.
  final int? committed;

  /// The lens x at rest on the target.
  final double rest;

  LensFrame _at(double t) =>
      frames[(t / 0.001).round().clamp(0, frames.length - 1)];

  /// The gate's sampler: `x`, `w` or `h` at [t] seconds after the commit.
  double ours(double t, String key) {
    final lens = _at(t).lens;
    return switch (key) {
      'x' => lens.center.dx,
      'w' => lens.width,
      'h' => lens.height,
      _ => throw ArgumentError.value(key, 'key'),
    };
  }

  /// Every x from the commit on.
  List<double> get xs => [for (final f in frames) f.lens.center.dx];

  /// The engage of every frame.
  List<double> get engage => [for (final f in frames) f.engage];

  /// The gate's rows against [native] read at `t − shift`.
  List<GateRow> gate(List<TapRow> native, {required double shift}) =>
      tapGateRows(
        native,
        ours,
        shift: shift,
        ourXs: xs,
        ourFrom: xs.first,
        ourRest: rest,
      );
}
