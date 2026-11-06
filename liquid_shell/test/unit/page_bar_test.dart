// The title model of the page bars and the Flutter bar's collapse curve
// (spec 2026-10-28-p3b2-page-bars §4.2, §8.3). The native bar's suite
// (PageTitleMath in RunnerTests.swift) carries the same table, row by row.
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_title.dart';

/// The title table, one record per row, each cell as the spec's table
/// writes it: (page, largeTitle, size class, actions, mode).
const _titleTable = <(String, String, String, String, String)>[
  ('pushed', 'any', 'any', 'any', 'inline'),
  ('root', 'true', 'any', 'any', 'largeCollapsing'),
  ('root', 'null', 'compact', 'any', 'largeInRow'),
  ('root', 'null', 'regular', 'none', 'hidden'),
  ('root', 'false', 'any', 'none', 'hidden'),
  ('root', 'null (regular) or false', 'as left', '≥ 1', 'inline'),
];

typedef _Case = ({
  bool root,
  bool? largeTitle,
  LiquidSizeClass sizeClass,
  bool hasActions,
});

/// Every concrete case a row of [_titleTable] covers.
List<_Case> _casesOf((String, String, String, String, String) row) {
  final (page, largeTitle, sizeClass, actions, _) = row;
  final root = switch (page) {
    'pushed' => false,
    'root' => true,
    _ => throw ArgumentError.value(page, 'page'),
  };
  final titlesAndSizes = switch ((largeTitle, sizeClass)) {
    ('null (regular) or false', 'as left') => const [
      (null, LiquidSizeClass.regular),
      (false, LiquidSizeClass.compact),
      (false, LiquidSizeClass.regular),
    ],
    _ => [
      for (final title in _largeTitles(largeTitle))
        for (final size in _sizeClasses(sizeClass)) (title, size),
    ],
  };
  final withActions = switch (actions) {
    'any' => const [false, true],
    'none' => const [false],
    '≥ 1' => const [true],
    _ => throw ArgumentError.value(actions, 'actions'),
  };
  return [
    for (final (title, size) in titlesAndSizes)
      for (final hasActions in withActions)
        (
          root: root,
          largeTitle: title,
          sizeClass: size,
          hasActions: hasActions,
        ),
  ];
}

List<bool?> _largeTitles(String cell) => switch (cell) {
  'any' => const [true, null, false],
  'true' => const [true],
  'null' => const [null],
  'false' => const [false],
  _ => throw ArgumentError.value(cell, 'largeTitle'),
};

List<LiquidSizeClass> _sizeClasses(String cell) => switch (cell) {
  'any' => LiquidSizeClass.values,
  'compact' => const [LiquidSizeClass.compact],
  'regular' => const [LiquidSizeClass.regular],
  _ => throw ArgumentError.value(cell, 'size class'),
};

void main() {
  group('pageTitleModeFor: the title table', () {
    for (final (i, row) in _titleTable.indexed) {
      test('row ${i + 1}: $row', () {
        final mode = PageTitleMode.values.byName(row.$5);
        final cases = _casesOf(row);
        expect(cases, isNotEmpty);
        for (final c in cases) {
          expect(
            pageTitleModeFor(
              root: c.root,
              largeTitle: c.largeTitle,
              sizeClass: c.sizeClass,
              hasActions: c.hasActions,
            ),
            mode,
            reason: '$c',
          );
        }
      });
    }

    test('the rows cover every case exactly once', () {
      final all = [for (final row in _titleTable) ..._casesOf(row)];
      // page × largeTitle × size class × actions
      expect(all, hasLength(2 * 3 * 2 * 2));
      expect(all.toSet(), hasLength(all.length));
    });

    test('a page without actions by default', () {
      expect(
        pageTitleModeFor(
          root: true,
          largeTitle: false,
          sizeClass: LiquidSizeClass.compact,
        ),
        PageTitleMode.hidden,
      );
    });
  });

  group('pageBarCollapse', () {
    for (final (offset, shift, opacity) in const <(double, double, double)>[
      (-30, 0, 0),
      (0, 0, 0),
      (26, 26, 0),
      (39, 39, 0.5),
      (52, 52, 1),
      (200, 52, 1),
    ]) {
      test('offset $offset: shift $shift, inline opacity $opacity', () {
        final collapse = pageBarCollapse(offset);
        expect(collapse.largeShift, shift);
        expect(collapse.inlineOpacity, opacity);
      });
    }

    test('follows its extent', () {
      final collapse = pageBarCollapse(30, extent: 40);
      expect(collapse.largeShift, 30);
      expect(collapse.inlineOpacity, 0.5);
    });
  });
}
