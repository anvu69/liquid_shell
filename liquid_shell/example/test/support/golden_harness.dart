import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/main.dart';

/// A golden device: logical size, safe area, gesture area and platform.
typedef GoldenDevice = ({
  String name,
  Size size,
  EdgeInsets padding,
  double gestureBottom,
  TargetPlatform platform,
});

/// iPhone 393×852 (top 59, bottom 34).
const GoldenDevice iphone = (
  name: 'iphone',
  size: Size(393, 852),
  padding: EdgeInsets.only(top: 59, bottom: 34),
  gestureBottom: 34.0,
  platform: TargetPlatform.iOS,
);

/// iPad 11" portrait 834×1194 (top 24, bottom 20).
const GoldenDevice ipadPortrait = (
  name: 'ipad_portrait',
  size: Size(834, 1194),
  padding: EdgeInsets.only(top: 24, bottom: 20),
  gestureBottom: 20.0,
  platform: TargetPlatform.iOS,
);

/// iPad 11" landscape 1194×834 (top 24, bottom 20).
const GoldenDevice ipadLandscape = (
  name: 'ipad_landscape',
  size: Size(1194, 834),
  padding: EdgeInsets.only(top: 24, bottom: 20),
  gestureBottom: 20.0,
  platform: TargetPlatform.iOS,
);

/// Android phone 412×915 (top 24, gesture bottom 24).
const GoldenDevice android = (
  name: 'android',
  size: Size(412, 915),
  padding: EdgeInsets.only(top: 24, bottom: 24),
  gestureBottom: 24.0,
  platform: TargetPlatform.android,
);

/// Device pixel ratio of every golden.
const goldenPixelRatio = 2.0;

/// Loads Inter (OFL, `test/fonts`) as the theme font and MaterialIcons from
/// the Flutter SDK cache, so text and icons render as glyphs, not boxes.
///
/// Reads files, so it must run outside `testWidgets` (fake async): it is
/// called once from `flutter_test_config.dart`.
Future<void> loadGoldenFonts() async {
  final inter = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(_bytes('test/fonts/Inter-$weight.ttf'));
  }
  await inter.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is not set; run through `flutter test`.');
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      _bytes(
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

Future<ByteData> _bytes(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

/// The example theme with the Inter font.
ThemeData goldenTheme(Brightness brightness, TargetPlatform platform) =>
    ThemeData(
      colorSchemeSeed: kExampleSeed,
      brightness: brightness,
      fontFamily: 'Inter',
      platform: platform,
    );

/// Sets up [device] and pumps [child] as the home of a MaterialApp.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
}) async {
  FakeViewPadding physical(EdgeInsets p) => FakeViewPadding(
    left: p.left * goldenPixelRatio,
    top: p.top * goldenPixelRatio,
    right: p.right * goldenPixelRatio,
    bottom: p.bottom * goldenPixelRatio,
  );
  tester.view
    ..devicePixelRatio = goldenPixelRatio
    ..physicalSize = device.size * goldenPixelRatio
    ..padding = physical(device.padding)
    ..viewPadding = physical(device.padding)
    ..systemGestureInsets = physical(
      EdgeInsets.only(bottom: device.gestureBottom),
    );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: goldenTheme(brightness, device.platform),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Compares the app with the doc image `liquid_shell/doc/images/<name>.png`.
///
/// First fails when any [Text] is drawn in a fallback style (no `Material`
/// or `DefaultTextStyle` above it), so a regenerated golden cannot record
/// red, double-underlined text as the expected image.
Future<void> expectDocImage(WidgetTester tester, String name) async {
  final bad = <String>[
    for (final element in find.byType(Text, skipOffstage: false).evaluate())
      if (_isFallback(DefaultTextStyle.of(element).style))
        (element.widget as Text).data ?? '<rich text>',
  ];
  expect(bad, isEmpty, reason: 'Text drawn in the fallback style in $name');
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../../doc/images/$name.png'),
  );
}

/// The empty `DefaultTextStyle.fallback()` (no app at all) or MaterialApp's
/// red, double-underlined "fallback style" (no `Material`).
bool _isFallback(TextStyle style) =>
    style == const TextStyle() ||
    (style.debugLabel?.contains('fallback style') ?? false);
