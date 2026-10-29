# P3b-2 B2 measurements (VK-441, VK-442)

Spec `docs/specs/2026-10-28-p3b2-page-bars-design.md` §8.2 scope 1. Each
measurement picks the main design or its fall-back; the probes are
throwaway and live in the plan
(`docs/plans/2026-10-28-native-bar-every-tab.md`, Tasks 1–3).

Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5 (23F77) and
27.0 (24A434), Xcode 27.1. Date: 2026-10-29.

## M1: a pushed page's bar beside the iPad's tab bar and sidebar

A plain `.tabSidebar` controller with two production `ShellNavController`
tabs; Home shows `[Home, Detail]`. Frames in window points. The probe
(`M1PageBarLayoutProbe`) passed 3 of 3 on each OS.

| State | OS | Back circle | Title | Tab items / sidebar | Navigation bar |
|---|---|---|---|---|---|
| Top bar, portrait 820 × 1180 | 26.5 | (10, 32) 44 × 44 | (387, 99.5) | Home (376.75, 41.5), Inbox (455.75, 41.5) | y 32–144 (two rows) |
| Top bar | 27.0 | (10, 32) 44 × 44 | (387, 99.5) | the same | y 32–144 |
| Tiled sidebar, landscape 1180 × 820 | 26.5 | (300, 32) | (712, 41.5) | sidebar (10, 32) 270 × 778, to x 280 | y 32–86 |
| Tiled sidebar | 27.0 | (290, 32) | (707, 41.5) | sidebar (0, 0) 280 × 820, to x 280 | y 32–86 |
| Overlay, portrait | 26.5, 27.0 | (10, 32), under the sidebar | (387, 99.5) | sidebar to x 280 (26.5: 270 × 1138 at x 10; 27.0: 280 × 1180 at x 0) | y 32–144 |

The page's safe-area insets: top 144 under the top bar and the overlay,
top 86 and left 280 beside the tiled sidebar, on both OSes.

**Decision: the main design.** The back circle shares the top tab bar's
row at its leading end; the title moves to a second row; nothing overlaps.
Beside a tiled sidebar the bar lays out right of it. Screenshots:
`m1_<os>_<state>.png`.

## M4: `isTiled` on a navigation tree

`ShellMath.isTiled` from the navigation controller's view and from its top
page: equal at rest, and in every one of 32 samples during an animated
push (left inset 280), on 26.5 and 27.0. Recorded only: `isTiled` reads
the top page's view (Task 7), the view whose insets reach Flutter.

## M2: the tab bar's minimize on a pushed page

Real swipes (XCUITest) on the example's `tabs` demo with a probe build:
every plain tab in a navigation controller, a second tab host pushed by a
native button, its proxy carrying the tab's offset over (as Dart's resend
after a stack change does). iPhone 17 Pro, iOS 26.5 and 27.0.

| Step | 26.5 | 27.0 |
|---|---|---|
| A swipe on the pushed host minimizes | yes | yes |
| A pop while minimized keeps the circle | yes | yes |
| A push while minimized keeps the circle | yes | yes |
| A fling to the top on the pushed host expands | yes | yes |

**Decision: the main design.** UIKit's tab bar follows the top page's
`.bottom` proxy; pushed pages minimize, and a push or a pop keeps the
bar's form. Not measured on iPad: the regular top bar never minimizes.

## M3: `setTabBarHidden` in the tab sidebar mode (Q16)

UIKit's `setTabBarHidden(_:animated:)` on today's shell (`.tabSidebar`),
the search tab with a pushed page standing in for a plain tab's. All four
simulators.

| Row of spec §6.6 | iPhone 26.5 | iPad 26.5 | iPhone 27.0 | iPad 27.0 |
|---|---|---|---|---|
| 1. A touch where the tab bar was, and beside the navigation bar, reaches Flutter; the back circle stays native | yes | yes | yes | yes |
| 2. Flutter's top stays; its bottom becomes the window's | 116 → 116; 83 → 34 | 86 → 86; 77 → 20 | as 26.5 | as 26.5 |
| 3. A tiled sidebar comes back tiled, start inset 280 | n/a | yes | n/a | yes |
| 4. The tab bar comes back at its frame (unit test) | yes | yes | yes | yes |
| 5. Hidden through a push, a pop, two size-class changes | yes | yes | yes | yes |

`setTabBarHidden` alone leaves a tiled sidebar shown (the left inset stays
280): the shell hides it and puts it back (Task 8).

**Decision: the main design** (`tabBarHidden`), pending Task 8's gate:
`MinimizeUITests` and the whole `RunnerTests` and `RunnerUITests` on the
finished tree.

### The UI half of the gate (Task 16)

`RunnerUITests` on iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5:
30/30 and 20/20, no failure; `MinimizeUITests`
on an iPhone 17 (iOS 26.5): 7/7. The main design stands.

## M5: a large title that turns on on screen (VK-441)

Found while Task 15 ran: Library's root (`largeTitle: true`) was drawn
collapsed at rest on iOS 26.5, a small centred title on the iPhone and
none on the iPad. Probes at `c46f0e6` in `RunnerTests` on the iPhone 17
Pro and the iPad Air 11-inch (M4), iOS 26.5 and 27.0, settled 1 s. The
navigation bar's height in points, iPhone / iPad, the same on both OS
versions unless the row says otherwise:

| Probe | Sequence | Bar |
|---|---|---|
| P1 | `.always` applied to the shown tab's root (Library's pages arrive once its tab shows) | 54 / 54, collapsed |
| P1 + offset 0 | then Flutter's offset 0 (the proxy's base was learned collapsed) | 54 / 54 |
| P2 | the same pages applied while another tab is selected, then the tab selected | 106 / 106, expanded |
| P3–P7, P9, P10, P12, P13 | the minimize proxy out of the way; the proxy pre-set to rest; unhide and mode in either order; the scroll view registered again; a relayout | 54 / 54 |
| P11 | P1, then the proxy pulled 60 pt past rest and released | 106 / 106 |
| P14 | P1 with no content scroll view | 106 / 106 |
| P15 | an iPad search root on screen, `largeTitle` false → true | 114 → 114 (26.5), 108 → 108 (27.0) |
| P16 (27.0) | pages sent with the selection; or 10, 100, 500 ms after it | 106; 54 |
| P17a (iPhone) | P1, then lay out, pull 100 pt past rest, back to rest on the next turn; then offsets 400 → 0 | 106; 54; 106 |
| P18 (iPhone) | a plain `UIScrollView` as the `.top` content scroll view | 54 |

Cause: with a `.top` content scroll view at rest, UIKit keeps a visible
bar's large title collapsed when the mode becomes `.always` or the bar
shows with it; only a pull past rest brings it out. The difference between
26.5 and 27.0 in the integration run is ordering (P16), not UIKit. The
iPad's missing title is the same collapsed bar: at regular width a
collapsed root bar draws no inline title.

**Decision: fix A** (owner, 2026-10-29), in this branch before the
release task. `PageHostController.revealLargeTitle(after:)` pulls the
proxy `largeTitlePull` (100 pt) past rest and puts it back on the next
run-loop turn, for a plain root (`ShellNavController.applyPages`) and the
search root (`applySearchStyle`); the proxy's base is not learned
meanwhile. Unit tests: `NativeTabsTests.testALargeTitleThatTurnsOnOnScreenIsDrawnOut`
and the two after it, green on all four simulators. The Library
screenshots are taken again after the fix (Task 20).
