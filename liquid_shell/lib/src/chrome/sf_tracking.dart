import 'package:flutter/foundation.dart';

/// SF Pro's tracking by point size, in 1/1000 em: the tracking UIKit applies
/// to the system font and Flutter's text engine does not (Apple's Human
/// Interface Guidelines, Typography, "Tracking values", SF Pro, iOS).
const List<(double, int)> _sfTracking = [
  (6, 41),
  (7, 34),
  (8, 26),
  (9, 19),
  (10, 12),
  (11, 6),
  (12, 0),
  (13, -6),
  (14, -11),
  (15, -16),
  (16, -20),
  (17, -26),
  (18, -25),
  (19, -24),
  (20, -23),
  (21, -18),
  (22, -12),
  (23, -4),
  (24, 3),
  (25, 6),
  (26, 8),
  (27, 11),
  (28, 14),
  (29, 14),
  (30, 14),
  (31, 13),
  (32, 13),
  (33, 12),
  (34, 12),
  (35, 11),
  (36, 10),
  (37, 10),
  (38, 10),
  (39, 10),
  (40, 9),
  (41, 8),
  (42, 8),
  (43, 8),
  (44, 8),
  (45, 7),
  (46, 7),
  (47, 7),
  (48, 6),
  (49, 6),
  (50, 6),
  (51, 5),
  (52, 5),
  (53, 5),
  (54, 4),
  (56, 4),
  (58, 3),
  (60, 3),
  (62, 2),
  (64, 2),
  (66, 1),
  (68, 1),
  (70, 1),
  (72, 0),
  (80, 0),
];

/// UIKit's tracking of the system font at [size] points, in points (a
/// `letterSpacing`): Apple's table, linear between its sizes, its first and
/// last values held outside them.
double sfTracking(double size) {
  final first = _sfTracking.first;
  if (size <= first.$1) return first.$2 / 1000 * size;
  for (var i = 1; i < _sfTracking.length; i++) {
    final (s1, e1) = _sfTracking[i];
    if (size <= s1) {
      final (s0, e0) = _sfTracking[i - 1];
      final p0 = e0 / 1000 * s0;
      final p1 = e1 / 1000 * s1;
      return p0 + (p1 - p0) * (size - s0) / (s1 - s0);
    }
  }
  return _sfTracking.last.$2 / 1000 * size;
}

/// The system font's family names on Apple platforms (Flutter's and the
/// platform's own); null is the platform default.
const Set<String> _sfFamilies = {
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.SF UI Text',
  '.SF UI Display',
  '.SF Pro Text',
  '.SF Pro Display',
  '.AppleSystemUIFont',
  'SF Pro',
  'SF Pro Text',
  'SF Pro Display',
};

/// Whether text in [family] on [platform] draws in SF Pro, the font
/// [sfTracking] is for: an Apple platform, and its system family or none.
bool isAppleSystemFont(String? family, TargetPlatform platform) =>
    (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) &&
    (family == null || _sfFamilies.contains(family));
