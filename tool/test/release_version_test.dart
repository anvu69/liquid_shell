import 'dart:io';

import 'package:test/test.dart';

/// The four published packages, in publish order.
const packages = [
  'liquid_shell_platform_interface',
  'liquid_shell_ios',
  'liquid_shell_android',
  'liquid_shell',
];

/// Every pubspec that may depend on a sibling: the packages and both examples.
final List<String> pubspecs = [
  for (final p in packages) '$p/pubspec.yaml',
  'liquid_shell/example/pubspec.yaml',
  'liquid_shell/example_go_router/pubspec.yaml',
];

const podspec = 'liquid_shell_ios/ios/liquid_shell_ios.podspec';

/// `RELEASE_VERSION=0.1.0-dev.9 dart test tool/test/release_version_test.dart`
/// also pins the shared version, so a release bump can be run red first.
final String? expected = Platform.environment['RELEASE_VERSION'];

String read(String path) => File(path).readAsStringSync();

String pubspecVersion(String path) {
  final m = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(read(path));
  if (m == null) throw StateError('$path has no version: line');
  return m.group(1)!;
}

/// `0.1.0-dev.9` -> (`0.1.0-dev`, 9); null when it is not a dev version.
(String, int)? devParts(String v) {
  final m = RegExp(r'^(.+-dev)\.(\d+)$').firstMatch(v);
  return m == null ? null : (m.group(1)!, int.parse(m.group(2)!));
}

void main() {
  final version = pubspecVersion('liquid_shell/pubspec.yaml');

  test('the four packages share one version', () {
    for (final p in packages) {
      expect(pubspecVersion('$p/pubspec.yaml'), version, reason: p);
    }
  });

  test('the iOS podspec carries the same version', () {
    final m = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(read(podspec));
    expect(m, isNotNull, reason: '$podspec has no s.version');
    expect(m!.group(1), version);
  });

  test('every sibling constraint is ^<version>, in packages and examples', () {
    var seen = 0;
    for (final path in pubspecs) {
      for (final p in packages) {
        final m = RegExp(
          '^\\s+${RegExp.escape(p)}:\\s*(\\S+)\\s*\$',
          multiLine: true,
        ).firstMatch(read(path));
        if (m == null) continue;
        seen++;
        expect(m.group(1), '^$version', reason: '$path -> $p');
      }
    }
    // 5 in the packages (3 + 1 + 1), 3 in example, 1 in example_go_router.
    expect(seen, 9);
  });

  test('each CHANGELOG has a heading for the version, nothing older above', () {
    for (final p in packages) {
      final headings = RegExp(
        r'^## (\S+)\s*$',
        multiLine: true,
      ).allMatches(read('$p/CHANGELOG.md')).map((m) => m.group(1)!).toList();
      final at = headings.indexOf(version);
      expect(at, isNonNegative, reason: '$p/CHANGELOG.md lacks "## $version"');
      // Unreleased work may sit above it, under a newer dev heading.
      final mine = devParts(version);
      for (final above in headings.take(at)) {
        final theirs = devParts(above);
        expect(
          mine != null &&
              theirs != null &&
              theirs.$1 == mine.$1 &&
              theirs.$2 > mine.$2,
          isTrue,
          reason: '$p/CHANGELOG.md: "## $above" above "## $version"',
        );
      }
    }
  });

  test(
    'RELEASE_VERSION, when set, is the shared version',
    () {
      if (expected == null) return;
      expect(version, expected);
    },
    skip: expected == null ? 'RELEASE_VERSION not set' : false,
  );
}
