# iPhone Duo: Flutter's top follows the search field after a fold on a scrolled page (VK-1024)

Status: approved by the owner on 2026-11-09 (decisions 1–4: "ok hết").
Source: the VK-979 whole-branch review, Minor 4.

## 1. Problem

`ShellNavController.flutterTop` holds the top inset while the page is scrolled:
`SearchMath.heldTop(current:resting:scrolled:)` returns `max(current, resting)`.
That stops Flutter's content from jumping while UIKit collapses a large title
under the finger. `restingTop` is read again only at rest (`offset <= 0`), or with
`force` when a search starts or ends.

`NativeTabsController.verticalBarChanged()` (VK-979) writes the search root's
`hidesSearchBarWhenScrolling` when the iPhone Duo's vertical bar comes or goes.
While the bar is shown the field sits under the title row and the inset is 54pt
taller. When the bar goes away, the write is `true` and the field leaves that row,
so the inset shrinks. If the page is scrolled at that moment, nothing re-reads
`restingTop`, and Flutter keeps the old, larger top until the page scrolls back to 0.

Both paths do this:

- **Immediate:** an unfold while no search is active. The write happens at once
  and the page is scrolled.
- **Deferred:** an unfold during a search. `onActive(false)` force-reads
  `restingTop` *before* it calls `verticalBarChanged()`, so the force-read sees the
  field still under the title row. Then the write shrinks the inset while the page
  is scrolled.

This was found by reading the code and has not been measured on a device:
`simctl` cannot change the posture.

## 2. Decision

**Approach A.** When `verticalBarChanged()` actually writes
`hidesSearchBarWhenScrolling`, it lays out the search tab's navigation controller,
force-reads the root host's resting top, and syncs Flutter. The field moving is a
change to the chrome's structure, not a scroll. That is the same reason a search's
start and end already force the read.

Rejected:

- **B, reorder `onActive`:** call `verticalBarChanged()` before the force-read. This
  depends on UIKit applying the inset at once, and it does not fix the immediate path.
- **C, BACKLOG only:** the stale inset is visible, and the fix is three lines.

## 3. Behaviour

- After a write in `verticalBarChanged()`:
  1. `nav.view.layoutIfNeeded()`
  2. `nav.rootHost.rereadRestingTop(force: true)`
  3. `syncFlutter()`
- Without a write (the same presence, an iPad, or an active search) nothing
  changes. The VK-979 rule stands: a focused field is never moved or re-styled.
- A forced read on a scrolled page moves Flutter's content by the inset change
  (54pt) once. The same thing already happens when a search starts or ends on a
  scrolled page.

## 4. Scope

In scope: the search tab's root host, on both paths.

Out of scope: other tabs. When the vertical bar comes or goes, their navigation bar
changes too (58pt beside the bar), and a held inset may also go stale there. This is
not measured, because the simulator has no posture. The PR lists it as not verified.

## 5. Tests (XCTest, `RunnerTests.swift`)

The presence of the vertical bar is injected through `readVerticalBar`, and
`verticalBarChanged()` is called directly, as in the VK-979 wiring tests. The setup
puts the field under the title row on any iPhone: on a non-Duo device it injects the
bar first. Then it scrolls the search root to 400, and then the bar goes away.

1. Immediate: assert `flutter.view.safeAreaInsets.top == host.view.safeAreaInsets.top`
   (accuracy 0.5).
2. Deferred: the search is active when the bar goes away, then Cancel. Same assertion.

Both tests must fail before the fix. Run the full suite on the iPhone Duo (iOS 27.1)
and on the iPhone 17 Pro (iOS 26.5), each on a freshly created simulator.

## 6. Docs

Add one line to the `liquid_shell_ios/CHANGELOG.md` `0.1.0-dev.12` VK-979 entry.
