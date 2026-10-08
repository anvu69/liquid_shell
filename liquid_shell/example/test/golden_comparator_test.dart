import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart';

/// A 100×100 white PNG with the first [dark] pixels black (10 000 pixels,
/// so 50 differing pixels are exactly 0.5%).
Future<Uint8List> _png(int dark) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      const ui.Rect.fromLTWH(0, 0, 100, 100),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  final black = ui.Paint()
    ..color = const ui.Color(0xFF000000)
    ..isAntiAlias = false;
  for (var i = 0; i < dark; i++) {
    final x = (i % 100).toDouble();
    final y = (i ~/ 100).toDouble();
    canvas.drawRect(ui.Rect.fromLTWH(x, y, 1, 1), black);
  }
  final image = await recorder.endRecording().toImage(100, 100);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  late Directory dir;
  late TolerantGoldenComparator comparator;
  final golden = Uri.parse('golden.png');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tolerant_comparator');
    File('${dir.path}/golden.png').writeAsBytesSync(await _png(0));
    comparator = TolerantGoldenComparator(
      Uri.file('${dir.path}/comparator_test.dart'),
    );
  });

  tearDown(() => dir.delete(recursive: true));

  test('the default tolerance is 0.5% of the pixels (Q11)', () {
    expect(comparator.tolerance, 0.005);
  });

  test('an identical image passes', () async {
    expect(await comparator.compare(await _png(0), golden), isTrue);
  });

  test('49 and 50 of 10 000 pixels (up to 0.5%) pass', () async {
    expect(await comparator.compare(await _png(49), golden), isTrue);
    expect(await comparator.compare(await _png(50), golden), isTrue);
  });

  test('51 of 10 000 pixels (just over 0.5%) fail with the diff output', () {
    expect(
      () async => comparator.compare(await _png(51), golden),
      throwsA(
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('0.51%'),
        ),
      ),
    );
  });
}
