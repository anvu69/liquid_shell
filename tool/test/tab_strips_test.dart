import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../side_by_side.dart' show encodeRgbaPng;
import '../tab_strips.dart';

Rgba _frame(int value) => (
  width: 4,
  height: 4,
  pixels: Uint8List(64)..fillRange(0, 64, value),
);

void main() {
  test('nextOnset finds the first change after a still run', () {
    final frames = [
      for (var i = 0; i < 40; i++) _frame(10),
      for (var i = 0; i < 10; i++) _frame(10 + 20 * (i + 1)),
      for (var i = 0; i < 40; i++) _frame(210),
      for (var i = 0; i < 5; i++) _frame(100),
    ];
    final first = nextOnset(frames, 0, threshold: 4);
    expect(first, 40);
    final second = nextOnset(frames, first! + 1, threshold: 4);
    expect(second, 90);
    expect(nextOnset(frames, second! + 1, threshold: 4), isNull);
  });

  test('a strip stacks [rows] pairs, one per [every] frames', () {
    final native = [for (var i = 0; i < 60; i++) _frame(i)];
    final flutter = [for (var i = 0; i < 60; i++) _frame(255 - i)];
    final strip = composeStrip(
      native,
      0,
      flutter,
      0,
      rows: 4,
      gap: 2,
    );
    expect(strip.width, 4 + 2 + 4);
    expect(strip.height, 4 * 4 + 3 * 2);
  });

  test('loadFrames crops the band and decodes a frame only when read', () {
    final dir = Directory.systemTemp.createTempSync('tab_strips_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final (i, value) in [(1, 7), (2, 9)]) {
      final rows = Uint8List(4 * 6 * 4);
      for (var y = 0; y < 6; y++) {
        rows.fillRange(y * 16, (y + 1) * 16, y < 2 ? 0 : value);
      }
      File(
        '${dir.path}/0000$i.png',
      ).writeAsBytesSync(encodeRgbaPng((width: 4, height: 6, pixels: rows)));
    }
    // Not a PNG: reading it throws, listing it does not.
    File('${dir.path}/00003.png').writeAsStringSync('broken');
    final frames = loadFrames(dir.path, 2, 3);
    expect(frames, hasLength(3));
    expect(frames[1].height, 3);
    expect(frames[1].pixels.toSet(), {9});
    expect(frames[0].pixels.toSet(), {7});
    expect(() => frames[2], throwsFormatException);
  });

  test('loadFrames still reads a frame after the cache evicted it', () {
    final dir = Directory.systemTemp.createTempSync('tab_strips_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (var i = 0; i < 6; i++) {
      File('${dir.path}/0000$i.png').writeAsBytesSync(
        encodeRgbaPng((
          width: 2,
          height: 2,
          pixels: Uint8List(16)..fillRange(0, 16, 10 * i),
        )),
      );
    }
    final frames = loadFrames(dir.path, 0, 2);
    for (var i = 0; i < 6; i++) {
      expect(frames[i].pixels.first, 10 * i);
    }
    expect(frames[0].pixels.toSet(), {0});
  });

  group('onsets and pairing', () {
    // Three moves, each 10 frames after 40 still ones.
    final frames = [
      for (var m = 0; m < 3; m++) ...[
        for (var i = 0; i < 40; i++) _frame(m * 60),
        for (var i = 0; i < 10; i++) _frame(m * 60 + 5 * (i + 1)),
      ],
      for (var i = 0; i < 40; i++) _frame(180),
    ];

    test('onsetsOf lists every onset after the frames a strip covers', () {
      expect(onsetsOf(frames, threshold: 2, skip: 0), [40, 90, 140]);
      // A strip of 60 frames from 40 covers the onset at 90.
      expect(onsetsOf(frames, threshold: 2, skip: 60), [40, 140]);
    });

    test('pairOnsets pairs the k-th onset of each side', () {
      expect(pairOnsets([40, 90], [12, 70]), [(40, 12), (90, 70)]);
    });

    test('pairOnsets fails loudly on unequal counts', () {
      expect(
        () => pairOnsets([40, 90, 140], [12, 70]),
        throwsA(
          isA<OnsetMismatch>()
              .having((e) => e.pairs, 'pairs', [(40, 12), (90, 70)])
              .having((e) => '$e', 'message', contains('3 native')),
        ),
      );
    });

    test('pairOnsets fails loudly on empty input', () {
      expect(() => pairOnsets([], []), throwsA(isA<OnsetMismatch>()));
      expect(() => pairOnsets([40], []), throwsA(isA<OnsetMismatch>()));
    });
  });
}
