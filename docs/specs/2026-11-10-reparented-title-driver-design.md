# A scroll view moved out of the page never drives its large title (VK-826)

Status: approved by the owner on 2026-11-10 ("duyệt").

## 1. Problem

A `LiquidPage`'s large title follows the page's first vertical scroll view on
screen (`_drivesLargeTitle` in `liquid_shell/lib/src/pages/liquid_page.dart`).
Two of its checks walk up from a scroll view's notification context and stop
at the page: `isOnScreenUnder(origin, context)` (in
`lib/src/shell/branch_navigators.dart`) and `_isPageScrollView(origin)`. When
the walk never meets the page, both answer yes.

A `GlobalKey` can move a scroll view out of the page while it stays mounted.
Found in the B3 round-3 review (VK-445, m-2).

- **Keep.** The driver moved out of the page. It is still mounted and still
  "on screen", so it keeps the title, and the page's own lists cannot take it
  over until the moved one is disposed or hidden. That has been true since the
  rule was introduced.
- **Take.** A scroll view reports during a build (the report is held until
  after the frame, `_reportsInFrame`), it moves out of the page in that same
  build, and the current driver goes away. After the frame, the moved scroll
  view takes the title. This needs another widget to jump that list during a
  build, so it is rare.

## 2. Decision

`_LiquidPageState` gets one private helper, `_isInPage(BuildContext element)`.
It walks `element`'s ancestors and returns true only when it meets the page's
own element (`context`). `_drivesLargeTitle` uses it:

1. First, `if (!_isInPage(origin)) return false;`. A scroll view outside the
   page never takes the title and never keeps it, the driver included. This
   check comes before `identical(origin, driver)`, which fixes both Keep and
   Take for the origin.
2. The driver keeps the title only while `driver.mounted &&
   _isInPage(driver) && isOnScreenUnder(driver, context)`. A driver that
   moved out is released, and the page's next qualifying scroll view takes the
   title at its next report.

`isOnScreenUnder` is unchanged. `liquid_shell.dart:906` and `:1247` also use
it, with different meanings, so changing its answer is out of scope.

Cost: one more ancestor walk per vertical scroll report. `isOnScreenUnder`
already does the same walk.

The dartdoc of `_drivesLargeTitle` gains one sentence: "A scroll view that a
`GlobalKey` moved out of the page neither takes the title nor keeps it."

## 3. Tests (`liquid_shell/test/widget/liquid_page_test.dart`)

1. **Keep.** A page has list A (with a `GlobalKey`) and list B under an
   `IndexedStack`. Scroll A so that it drives the title. Move A out of the page
   with its key, for example into a sibling of the shell under the same
   `MaterialApp`, still mounted. Show B and scroll it. The title follows B.
   This is red on main, where the title stays at A's offset.
2. **Take.** A list reports during a build. For example, a widget calls
   `jumpTo` from `build`, or a `LayoutBuilder` changes its extent. In the same
   build the list moves out of the page by its `GlobalKey`, and the driver is
   removed. After the frame, the title has not taken the moved list's offset.
   The implementer shows it red on main. If no reachable setup makes it red
   (all three conditions in one build), the implementer says so, does not ship
   the test, and leaves case 1 to guard the shared check.

## 4. Changelog

Add to `liquid_shell/CHANGELOG.md` under `## 0.1.0-dev.12`: "A scroll view that
a `GlobalKey` moves out of a `LiquidPage` no longer drives, or keeps, that
page's large title."

## 5. Verification

- The new tests are red on main and green with the fix.
- `.githooks/pre-commit` exits 0. It runs format, analyze and every Dart test,
  the goldens included.
- No Swift changes and no XCTest run: the native bar gets its offset from the
  same `_handle?.scrolled`.
