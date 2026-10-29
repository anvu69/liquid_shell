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
