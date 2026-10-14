import 'dart:convert';
import 'dart:io';

/// docs/qa/vk550/native_reference.json (spec VK-550 §14.5), read from the
/// package directory.
Map<String, dynamic> segmentReference() =>
    jsonDecode(
          File('../docs/qa/vk550/native_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// One native row: t, lens centre x, w, h, engage.
typedef NativeRow = ({double t, double x, double w, double h, double engage});

/// The rows of [key] (its [field]) in [ref].
List<NativeRow> rowsOf(
  Map<String, dynamic> ref,
  String key, {
  String field = 'rows',
}) => [
  for (final r in ((ref[key] as Map)[field] as List).cast<List<dynamic>>())
    (
      t: (r[0] as num).toDouble(),
      x: (r[1] as num).toDouble(),
      w: (r[2] as num).toDouble(),
      h: (r[3] as num).toDouble(),
      engage: (r[4] as num).toDouble(),
    ),
];
