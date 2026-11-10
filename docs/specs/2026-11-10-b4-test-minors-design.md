# B4 test-only follow-ups (VK-924)

Status: approved by the owner on 2026-11-10 ("duyệt").

## 1. Problem

The B4 reviews (VK-443, page actions, PR #32) left Minor findings that were
deferred to one follow-up. Several were closed later. As of main 42df6f0:

| Finding | State on main |
|---|---|
| T6: the disabled-tap test does not assert that `InkWell.onTap` is null | Open. `test/widget/liquid_page_test.dart:1682` checks only the taps list and semantics. |
| T7 M1: no test reaches the `index >= actions.length` drop with an index below `maxActions` | Closed by 1f0a588. |
| T7 RR1: `!_routeCurrent` alone, under a root `showDialog` | Closed by bc61727 (final review I-2). |
| T7 M2: an exception thrown by `onPressed` after a native tap escapes into the event-stream listener; a Flutter-bar tap reports it through `FlutterError` | Open (production code, see §2). |
| T8: `PagesUITests.swift:99` finds the row with `descendants(matching: .any)` and `label CONTAINS "A favourite"` | Open. |
| T8: `example/test/cases_smoke_test.dart:219` calls `tester.widget<InkWell>` on a descendant finder | Open. If the circle changes shape it throws "Bad state: No element" or "Too many elements" instead of failing with a reason. |

## 2. Decisions

1. **T6.** In `liquid_page_test.dart`, the disabled-tap test also finds the one
   `InkWell` under the `Delete` tooltip and asserts that its `onTap` is null.
2. **T7 M2.** Not changed. The listener error goes to the zone's uncaught-error
   handler, which in Flutter reaches `PlatformDispatcher.onError`. The event
   subscription stays alive, so only the reporting path differs. Wrapping
   would change production code under a test-only item.
3. **T8 predicate.** It becomes `app.staticTexts` or `app.otherElements`
   with `label ENDSWITH "A favourite"` (the label is "Shared 0 times, A favourite").
   The implementer checks the actual element type in the accessibility tree
   and uses the narrowest one that matches.
4. **T8 smoke.** Before `tester.widget`, the test asserts the descendant finder
   with `findsOneWidget` and a `reason`.

## 3. Out of scope

- T7 M3 (tap identity after pop and push at the same depth): a known limit.
- T6 disabled-icon contrast: a device check.
- Production code. There is no CHANGELOG line, because the tests are not shipped.

## 4. Verification

- Each new assertion is red when the guarded behaviour is broken by hand.
  For T6, give `Delete` an `onPressed`. For T8 smoke, wrap the circle in a
  second `InkWell` locally. Revert both.
- `.githooks/pre-commit` exits 0.
- `PagesUITests` passes on a freshly created iPhone 17 Pro (iOS 26.5) simulator,
  which is deleted afterwards.
