// tool/tab_strips.dart
// Native vs Flutter liquid tab bar frame strips (spec VK-503 §17.4).
// Each recording is a folder of 60 fps PNG frames (ffmpeg). The k-th
// motion onset in the bar band of one recording is paired with the k-th
// in the other; each strip shows [rows] pairs, one every [every] frames,
// native on the left. Pure Dart: reuses compress_pngs.dart.
//
// Usage: dart run tool/tab_strips.dart <native> <flutter> <out>
//          --band <top>:<height> [--every 3] [--rows 18] [--threshold 3]
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'compress_pngs.dart' show decodePng;
import 'side_by_side.dart' show Rgba, encodeRgbaPng, scaleToHeight;

export 'side_by_side.dart' show Rgba;

/// Mean absolute difference per channel between two equal-size frames.
double frameDiff(Rgba a, Rgba b) {
  var sum = 0;
  for (var i = 0; i < a.pixels.length; i++) {
    sum += (a.pixels[i] - b.pixels[i]).abs();
  }
  return sum / a.pixels.length;
}

/// The first frame at or after [from] that differs from its predecessor
/// by more than [threshold], after at least [still] unchanged frames.
int? nextOnset(
  List<Rgba> frames,
  int from, {
  double threshold = 3,
  int still = 30,
}) {
  var calm = 0;
  for (var i = from == 0 ? 1 : from; i < frames.length; i++) {
    final moving = frameDiff(frames[i - 1], frames[i]) > threshold;
    if (moving && calm >= still) return i;
    calm = moving ? 0 : calm + 1;
  }
  return null;
}

/// [rows] pairs (native left, Flutter right) from the two onsets, one every
/// [every] frames, separated by [gap] white pixels.
Rgba composeStrip(
  List<Rgba> native,
  int nativeStart,
  List<Rgba> flutter,
  int flutterStart, {
  int every = 3,
  int rows = 18,
  int gap = 8,
}) {
  final left = native[nativeStart];
  final rowHeight = left.height;
  final pairs = <(Rgba, Rgba)>[];
  for (var r = 0; r < rows; r++) {
    final n = native[(nativeStart + r * every).clamp(0, native.length - 1)];
    final f = scaleToHeight(
      flutter[(flutterStart + r * every).clamp(0, flutter.length - 1)],
      rowHeight,
    );
    pairs.add((n, f));
  }
  final width = left.width + gap + pairs.first.$2.width;
  final height = rows * rowHeight + (rows - 1) * gap;
  final out = Uint8List(width * height * 4)
    ..fillRange(0, width * height * 4, 255);
  for (final (r, (n, f)) in pairs.indexed) {
    final top = r * (rowHeight + gap);
    for (var y = 0; y < rowHeight; y++) {
      final row = (top + y) * width * 4;
      out.setRange(row, row + n.width * 4, n.pixels, y * n.width * 4);
      final fx = row + (n.width + gap) * 4;
      out.setRange(fx, fx + f.width * 4, f.pixels, y * f.width * 4);
    }
  }
  return (width: width, height: height, pixels: out);
}

Rgba _crop(Rgba image, int top, int height) {
  final h = height.clamp(0, image.height - top);
  final out = Uint8List(image.width * h * 4);
  out.setRange(0, out.length, image.pixels, top * image.width * 4);
  return (width: image.width, height: h, pixels: out);
}

/// The PNG frames in [dir], in name order, each cropped to [height] rows
/// from [top]. A frame is decoded only when read, and only the last few
/// stay decoded: a minute of 60 fps video would not fit in memory.
List<Rgba> loadFrames(String dir, int top, int height) => _LazyFrames(
  Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path)),
  top,
  height,
);

class _LazyFrames extends ListBase<Rgba> {
  _LazyFrames(this._files, this._top, this._height);

  final List<File> _files;
  final int _top;
  final int _height;
  final Map<int, Rgba> _cache = {};

  @override
  int get length => _files.length;

  @override
  set length(int value) => throw UnsupportedError('read-only');

  @override
  Rgba operator [](int index) {
    final hit = _cache.remove(index);
    if (hit != null) return _cache[index] = hit;
    final png = decodePng(_files[index].readAsBytesSync());
    final frame = _crop(
      (width: png.width, height: png.height, pixels: png.rgba),
      _top,
      _height,
    );
    if (_cache.length >= 4) _cache.remove(_cache.keys.first);
    return _cache[index] = frame;
  }

  @override
  void operator []=(int index, Rgba value) =>
      throw UnsupportedError('read-only');
}

void main(List<String> args) {
  if (args.length < 5 || args[3] != '--band') {
    stderr.writeln(
      'usage: tab_strips.dart <native> <flutter> <out> '
      '--band <top>:<height> [--every N] [--rows N] [--threshold D]',
    );
    exit(64);
  }
  final band = args[4].split(':').map(int.parse).toList();
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 ? null : args[i + 1];
  }

  final every = int.parse(opt('--every') ?? '3');
  final rows = int.parse(opt('--rows') ?? '18');
  // The mean change over the whole band: a lens moving in a 160 pt band
  // changes about 0.5 % of it, far below the default.
  final threshold = double.parse(opt('--threshold') ?? '3');
  final native = loadFrames(args[0], band[0], band[1]);
  final flutter = loadFrames(args[1], band[0], band[1]);
  Directory(args[2]).createSync(recursive: true);
  var n = 0;
  var f = 0;
  for (var k = 1; ; k++) {
    final a = nextOnset(native, n, threshold: threshold);
    final b = nextOnset(flutter, f, threshold: threshold);
    if (a == null || b == null) break;
    final strip = composeStrip(native, a, flutter, b, every: every, rows: rows);
    File('${args[2]}/frames_$k.png').writeAsBytesSync(encodeRgbaPng(strip));
    stdout.writeln('frames_$k.png: native @$a, flutter @$b');
    n = a + every * rows;
    f = b + every * rows;
  }
}
