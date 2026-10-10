# P2 spike: iPadOS window controls (VK-346 Task 1)

Device: a real iPad Air 11-inch (M3), iPadOS 27, measured 2026-10-09 while the
owner resized the window by hand (full screen, windowed at many widths, split,
moved). Probe: the Flutter view's
`directionalEdgeInsets(for: .safeArea(cornerAdaptation:))` against its
`safeAreaInsets`, logged twice a second (plan Task 1, step 1; not committed).

## Raw probe lines

Each line: how many reads gave it, then the read.

```
  58 window={{0, 0}, {1180, 820}} safe={32, 0, 20, 0} h.leading=9.5 v.top=32.0
   1 window={{0, 0}, {1092, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {950, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
  11 window={{0, 0}, {835, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {956, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   9 window={{0, 0}, {1180, 820}} safe={32, 0, 20, 0} h.leading=5.5 v.top=32.0
   1 window={{0, 0}, {1006, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   3 window={{0, 0}, {929, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {788, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {710, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
  17 window={{0, 0}, {692, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {456, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
  12 window={{0, 0}, {375, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {375, 820}} safe={10, 0, 20, 0} h.leading=66.0 v.top=53.0
  17 window={{0, 0}, {375, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
  13 window={{0, 0}, {1180, 820}} safe={32, 0, 20, 0} h.leading=5.5 v.top=32.0
   1 window={{0, 0}, {971, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   5 window={{0, 0}, {541, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
   1 window={{0, 0}, {534, 590}} safe={10, 0, 10, 0} h.leading=66.0 v.top=53.0
   1 window={{0, 0}, {543, 523}} safe={10, 0, 10, 0} h.leading=66.0 v.top=53.0
  30 window={{0, 0}, {508, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
  53 window={{0, 0}, {585, 820}} safe={32, 0, 20, 0} h.leading=66.0 v.top=75.0
```

## Measurements

`leading delta = h.leading − safe.left`, `top delta = v.top − safe.top`.

| State | window (pt) | leading delta | top delta | reads |
|---|---|---|---|---|
| Full screen, landscape | 1180 × 820 | 9.5 | 0 | 58 |
| Full screen, landscape (after a windowed spell) | 1180 × 820 | 5.5 | 0 | 22 |
| Windowed, wide | 835–1092 × 820 | 66 | 43 | 19 |
| Windowed, medium | 692–788 × 820 | 66 | 43 | 19 |
| Windowed, narrow | 375–585 × 820 | 66 | 43 | 118 |
| Windowed, short (safe.top 10) | 534 × 590, 543 × 523, 375 × 820 | 66 | 43 | 3 |

Every windowed read, at every size and position, gave the same cluster:
66 pt wide, 43 pt tall. No windowed read reported a top delta of 0, and no
intermediate value appeared while resizing. Full screen portrait was not
measured (the owner kept the device in landscape).

## Decision

- Full screen: the leading delta (5.5–9.5 pt) is the display's rounded
  corner, not a cluster. It is below `ShellMath.minimumClusterLeading` (24 pt)
  with no vertical delta, so it reads as `{leading: 0, top: 0}`. **Keep 24.**
- Windowed: `{leading: 66, top: 43}` straight from the corner deltas. The
  vertical adaptation was always present, so `ShellMath.fallbackClusterTop`
  (44 pt, used only when the vertical delta is 0) never applied; it stays at
  least the measured cluster height (43 pt). **Keep 44.**
- Pass bars (plan Task 1): windowed leading 66 is within 40–120 and stable;
  full screen leading is below 24 with top delta 0. **Met.**

Task 3's `ShellMathTests` carry these values as a test case
(safe.top 32, v.top 75, h.leading 66 → `{66, 43}`; full screen 9.5 → 0).
