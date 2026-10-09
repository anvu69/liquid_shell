// Host side of `flutter drive`. Saves every screenshot the device test takes
// to build/integration_screenshots/<name>.png. Written from the public
// integration_test documentation (spec §9).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/integration_screenshots/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
