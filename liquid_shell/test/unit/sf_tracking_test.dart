import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/sf_tracking.dart';

void main() {
  // Apple's Human Interface Guidelines, Typography, "Tracking values" for
  // SF Pro (iOS): the tracking UIKit applies to the system font, in 1/1000
  // em, at each point size.
  test("SF Pro's tracking at the label's sizes, as Apple's table gives it", () {
    for (final (size, milliEm) in [
      (12.0, 0),
      (13.0, -6),
      (14.0, -11),
      (15.0, -16),
      (16.0, -20),
      (17.0, -26),
      (20.0, -23),
      (22.0, -12),
      (24.0, 3),
      (26.0, 8),
    ]) {
      expect(
        sfTracking(size),
        closeTo(milliEm / 1000 * size, 1e-9),
        reason: '$size pt',
      );
    }
  });

  test('between two sizes it is linear; outside the table it holds', () {
    expect(
      sfTracking(13.5),
      closeTo((sfTracking(13) + sfTracking(14)) / 2, 1e-9),
    );
    expect(sfTracking(4), closeTo(sfTracking(6) / 6 * 4, 1e-9));
    expect(sfTracking(200), closeTo(0, 1e-9));
  });

  test('the system font: Apple platforms, the SF families or none', () {
    for (final family in [
      null,
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF UI Text',
      '.AppleSystemUIFont',
      'SF Pro',
    ]) {
      expect(
        isAppleSystemFont(family, TargetPlatform.iOS),
        isTrue,
        reason: '$family',
      );
      expect(
        isAppleSystemFont(family, TargetPlatform.macOS),
        isTrue,
        reason: '$family',
      );
      expect(
        isAppleSystemFont(family, TargetPlatform.android),
        isFalse,
        reason: '$family',
      );
    }
    for (final family in ['Roboto', 'Inter', 'AppFont']) {
      expect(
        isAppleSystemFont(family, TargetPlatform.iOS),
        isFalse,
        reason: family,
      );
    }
  });
}
