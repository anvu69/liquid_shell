# VK-550 acceptance: the segmented control, traces and strips

## 1. Run

- **Date:** 2026-10-14.
- **Simulators** (iOS 26.5, 23F77; each created for this run and deleted after it):
  - `vk550-segfid`, iPhone 17 Pro: created and deleted by `tool/segment_frames.sh` for every `make segment-traces` and `make segment-frames`;
  - `vk503-tabfid`, iPhone 17 Pro: created and deleted by `tool/tab_frames.sh` (`make tab-traces`);
  - `vk550-t15-iphone`, iPhone 17 Pro: the label width probe, `make ios-unit`, `make ios-ui`, `make integration-ios-native`;
  - `vk550-t15-ipad`, iPad Air 11-inch (M4): `make ios-ui`, `make integration-ios-native`;
  - `vk550-t15-promax`, iPhone 17 Pro Max: the landscape scope bar check;
  - `vk550-t15-holdout`, iPhone 17 Pro: the native holdout (the spike's SegFid probe, touches by idb).
- **Toolchain:** Xcode 27.0, Flutter 3.44.6 (fvm), the iOS 27 runtime is not installed on the host.
- **Code:** branch `VK-550-liquid-segmented-control`, from ecfdb4c:
  - 534f6f5 `fix(shell): a native scope index past the titles is ignored`;
  - 25f3c2c `fix(shell): the segment lens tuned against native`;
  - c949ba1 `test(shell): the segment model against a native tap holdout`;
  - 1da892f `docs(docs): the segment lens after Task 15's tuning round`;
  - this document's commit.
- **Native reference:** `docs/qa/vk550/native_reference.json` (spike and Task 1 captures, plus Task 15's `lens.look`, measured on the segment strips) and `docs/qa/vk550/native_holdout.json` (Task 15, never fitted). Kinds as spec §14.5:
  - **native**: independent native data the model can fail;
  - **native, constant**: native data that Flutter sets from a constant;
  - **native, fitted**: native rows the model's springs were fitted to (in sample);
  - **condition**: a precondition of other rows, not a comparison.

## 2. The tuning round (Task 15)

One round, each change gated against native data. Before is Task 13's last run (de6e443, run 3); after is this run.

| Item | Before | After | How |
|---|---|---|---|
| **R8, dark grey pop** | The lens was an opaque grey pill for about 200 ms at the start and end of every engagement (dark strips) | Gone (dark strips 1–7) | The segment lens fades from clear glass, not from the tab pill's dark glass (#1C1C1C at 0.90). `LensLook.overGlass` is false for it |
| **R8, rest fill drawn twice** | Under the lens (captured and refracted) and by the lens, during the engage and the release | Once | While the lens is drawn the control draws no rest thumb; the lens draws the rest fill in every tier |
| **R8, the track in the lens's backdrop** | Captured | Kept | Native's held lens shows the track (the strips; the spike's grid shot), so the capture stays |
| **Lens look** | A milky core (white veil 0.90) and a thick black rim (golden metrics: core chroma 0.11 of the page's, ring p5 luma −106) | Clear glass, a thin rim: core chroma 0.969 / 0.970 of the page's (native 0.965 / 0.965), ring p5 luma −1.8 / 0.0 (native −8.0 / 0.0), light / dark | `LensLook.segment`: black veil 0.03, saturation 1, thickness 0.3 × 48 pt, dispersion 0.6, no blur, white rim 0.5 over 1 pt, bezel 9. The tab's thickness (1.6) bent rays 59 pt inward, past the 44 pt lens: the black rim. Gated in `liquid_test.dart` against `lens.look` (measured on native's strips the same way). The tab keeps `LensLook.tab`: its goldens are unchanged and `make tab-traces` is 99/100 as before |
| **Intrinsic width** | 180 vs 177 (±1) | 177 | The labels track −0.08 pt, SF Pro's tracking at 13 pt, which UIKit applies and Flutter's text engine does not. Measured on the simulator: "Places" w500 41.27 without it, 40.79 with it (native 40.67); "All \| Recently played" 234 (native 234) |
| **Five-segment tap lift** | Peak h 48.6 vs 38.9 | 37.8 | The lift follows the tap's distance: up to 148 pt the near shape, from 246.7 pt the far one (see §4 for what the holdout says) |
| **Five-segment wobble** | w 69.9 vs 61.2 | 65.2 | As above |
| **`tap_3_1` w wobble** (−12 %) | 119.5 vs 136.1 | 143.4 (+5 %) | After the lift the lens keeps its area (native's w × h stays within 4 % of rest from +0.45 s): the side the lift stretched most returns on the wobble spring, the area on its own spring (0.80 / 0.36 s), the other side is area over it. Also lifts a one-segment tap's h wobble (28.6 → 30.4, native 31.4) |
| **First-engage dropped frame** (`tap_1_2 frames`) | 33–50 ms in every run | Pass in 2 of 3 final runs | Two causes. The trace runs a debug (JIT) build: warming the lens pipeline did not remove the drop, and a lens drawn at mount moved it from the engage to the release, so the driver now taps there and back once before recording. And a 1 × 1 clear lens is drawn for one frame at the first control's mount (its clip, pass, shadow and signals), for the release build's first press. Run 1 still dropped one frame at the first two taps (§3) |
| **Flick overshoot** | 2.77 / 2.96 / 3.11 vs 3.86 ±1 (one run failed) | 3.21 / 3.06 / 3.19 | Release spring 0.785 / 0.585 s (was 0.80 / 0.59). Native's overshoot barely changes with speed (4.04 at about 630 pt/s, 3.86 at about 450); a linear spring's does, so one spring shares the error: `flick` 4.40 (was 4.10, native 4.04, ±10 %), `flickLanding` driven as the simulator drives it, median 3.11 over the frame phases (2.71 to 3.65 by phase; was 2.85) |
| **Holdout** | None left (all five captures fitted) | 21 fresh native taps | §4 |
| **Task 10 review M6** | A native scope index past the titles was applied | Ignored | Tested |
| **Doc, "Wobble (Q-E)"** | Claimed every capture | States what still differs | `doc/segmented_control.md` |

## 3. `make segment-traces`

Three consecutive runs at 1da892f, each on its own new simulator:

| Run | Result | Failed |
|---|---|---|
| 1 | ✗ 2 of 191 failed | `tap_1_2 frames`, `tap_2_3 frames`: one dropped frame (33.3 ms) at +16.7 ms. Conditions, not comparisons; every motion row passed |
| 2 | ✓ all 191 checks pass | |
| 3 | ✓ all 191 checks pass | |

Each run: 19 native, 21 native but constant, 139 native but fitted to them, 12 conditions. The flick overshoot read 3.21 / 3.06 / 3.19 (native 3.86 ±1). Run 3's table:

| check | kind | result | flutter | native | tolerance |
|---|---|---|---|---|---|
| full3 track width | native, constant | pass | 370.00 | 370.00 | ±1.00 |
| full3 track height | native, constant | pass | 32.00 | 32.00 | ±1.00 |
| full2 track width | native, constant | pass | 370.00 | 370.00 | ±1.00 |
| full2 track height | native, constant | pass | 32.00 | 32.00 | ±1.00 |
| full5 track width | native, constant | pass | 370.00 | 370.00 | ±1.00 |
| full5 track height | native, constant | pass | 32.00 | 32.00 | ±1.00 |
| thumb0 x | native | pass | 2.00 | 2.00 | ±1.00 |
| thumb0 y | native, constant | pass | 2.00 | 2.00 | ±1.00 |
| thumb0 w | native | pass | 119.33 | 119.00 | ±1.00 |
| thumb0 h | native, constant | pass | 28.00 | 28.00 | ±1.00 |
| thumb1 x | native | pass | 125.33 | 125.00 | ±1.00 |
| thumb1 y | native, constant | pass | 2.00 | 2.00 | ±1.00 |
| thumb1 w | native | pass | 119.33 | 119.00 | ±1.00 |
| thumb1 h | native, constant | pass | 28.00 | 28.00 | ±1.00 |
| thumb2 x | native | pass | 248.67 | 248.00 | ±1.00 |
| thumb2 y | native, constant | pass | 2.00 | 2.00 | ±1.00 |
| thumb2 w | native | pass | 119.33 | 120.00 | ±1.00 |
| thumb2 h | native, constant | pass | 28.00 | 28.00 | ±1.00 |
| full2 thumb w | native | pass | 181.00 | 181.00 | ±1.00 |
| full2 thumb h | native, constant | pass | 28.00 | 28.00 | ±1.00 |
| full5 thumb w | native | pass | 70.00 | 70.00 | ±1.00 |
| full5 thumb h | native, constant | pass | 28.00 | 28.00 | ±1.00 |
| intrinsic3 width | native | pass | 177.00 | 177.00 | ±1.00 |
| tap_1_2 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_1_2 clock | condition | pass | -2.0 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_1_2 frames | condition | pass | longest 16.7 ms at +133.3 ms | at most 25.0 ms |  |
| tap_1_2 x @0ms | native, fitted | pass | 61.67 | 61.50 | ±2.00 |
| tap_1_2 x @50ms | native, fitted | pass | 70.67 | 70.53 | ±2.00 |
| tap_1_2 x @100ms | native, fitted | pass | 106.54 | 107.19 | ±2.00 |
| tap_1_2 x @150ms | native, fitted | pass | 140.56 | 140.75 | ±2.00 |
| tap_1_2 x @200ms | native, fitted | pass | 162.47 | 162.00 | ±2.00 |
| tap_1_2 x @250ms | native, fitted | pass | 174.68 | 173.50 | ±2.00 |
| tap_1_2 x @300ms | native, fitted | pass | 181.34 | 180.06 | ±2.00 |
| tap_1_2 x @350ms | native, fitted | pass | 184.98 | 184.04 | ±2.00 |
| tap_1_2 x @400ms | native, fitted | pass | 186.77 | 186.16 | ±2.00 |
| tap_1_2 x @450ms | native, fitted | pass | 187.33 | 186.94 | ±2.00 |
| tap_1_2 x @500ms | native, fitted | pass | 187.16 | 186.91 | ±2.00 |
| tap_1_2 x @550ms | native, fitted | pass | 186.65 | 186.46 | ±2.00 |
| tap_1_2 x @600ms | native, fitted | pass | 186.08 | 185.79 | ±2.00 |
| tap_1_2 overshoot | native, fitted | pass | 2.34 | 2.54 (peak 186.94, rest 184.40) | ±1.00 |
| tap_1_2 settle | native, fitted | pass | 0.700 | 0.700 s (x within 0.5 of 184.40) | ±10 % |
| tap_1_2 peak h | native, fitted | pass | 37.71 | 39.18 | ±10 % |
| tap_1_2 w wobble | native, fitted | pass | 110.98 | 108.22 | ±10 % |
| tap_1_2 h wobble | native, fitted | pass | 30.43 | 31.41 | ±10 % |
| tap_2_3 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_2_3 clock | condition | pass | -2.0 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_2_3 frames | condition | pass | longest 16.7 ms at +216.7 ms | at most 25.0 ms |  |
| tap_2_3 x @0ms | native, fitted | pass | 185.00 | 184.50 | ±2.00 |
| tap_2_3 x @50ms | native, fitted | pass | 194.00 | 193.57 | ±2.00 |
| tap_2_3 x @100ms | native, fitted | pass | 229.88 | 230.37 | ±2.00 |
| tap_2_3 x @150ms | native, fitted | pass | 263.89 | 264.07 | ±2.00 |
| tap_2_3 x @200ms | native, fitted | pass | 285.81 | 285.40 | ±2.00 |
| tap_2_3 x @250ms | native, fitted | pass | 298.02 | 296.94 | ±2.00 |
| tap_2_3 x @300ms | native, fitted | pass | 304.67 | 303.52 | ±2.00 |
| tap_2_3 x @350ms | native, fitted | pass | 308.31 | 307.53 | ±2.00 |
| tap_2_3 x @400ms | native, fitted | pass | 310.10 | 309.66 | ±2.00 |
| tap_2_3 x @450ms | native, fitted | pass | 310.67 | 310.45 | ±2.00 |
| tap_2_3 x @500ms | native, fitted | pass | 310.49 | 310.43 | ±2.00 |
| tap_2_3 x @550ms | native, fitted | pass | 309.98 | 309.99 | ±2.00 |
| tap_2_3 x @600ms | native, fitted | pass | 309.41 | 309.30 | ±2.00 |
| tap_2_3 overshoot | native, fitted | pass | 2.34 | 2.55 (peak 310.45, rest 307.90) | ±1.00 |
| tap_2_3 settle | native, fitted | pass | 0.700 | 0.700 s (x within 0.5 of 307.90) | ±10 % |
| tap_2_3 peak h | native, fitted | pass | 37.71 | 39.18 | ±10 % |
| tap_2_3 w wobble | native, fitted | pass | 110.98 | 109.11 | ±10 % |
| tap_2_3 h wobble | native, fitted | pass | 30.43 | 31.42 | ±10 % |
| tap_3_1 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_3_1 clock | condition | pass | -16.0 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_3_1 frames | condition | pass | longest 16.7 ms at +383.3 ms | at most 25.0 ms |  |
| tap_3_1 x @0ms | native, fitted | pass | 308.28 | 308.00 | ±2.00 |
| tap_3_1 x @50ms | native, fitted | pass | 273.14 | 273.80 | ±2.00 |
| tap_3_1 x @100ms | native, fitted | pass | 197.39 | 197.53 | ±2.00 |
| tap_3_1 x @150ms | native, fitted | pass | 135.74 | 135.02 | ±2.00 |
| tap_3_1 x @200ms | native, fitted | pass | 98.26 | 96.45 | ±2.00 |
| tap_3_1 x @250ms | native, fitted | pass | 77.71 | 76.23 | ±2.00 |
| tap_3_1 x @300ms | native, fitted | pass | 66.46 | 66.17 | ±2.00 |
| tap_3_1 x @350ms | native, fitted | pass | 60.39 | 60.85 | ±2.00 |
| tap_3_1 x @400ms | native, fitted | pass | 57.61 | 57.91 | ±2.00 |
| tap_3_1 x @450ms | native, fitted | pass | 56.99 | 56.68 | ±2.00 |
| tap_3_1 x @500ms | native, fitted | pass | 57.60 | 56.81 | ±2.00 |
| tap_3_1 x @550ms | native, fitted | pass | 58.70 | 57.78 | ±2.00 |
| tap_3_1 x @600ms | native, fitted | pass | 59.80 | 59.12 | ±2.00 |
| tap_3_1 overshoot | native, fitted | pass | 4.68 | 5.00 (peak 56.68, rest 61.68) | ±1.00 |
| tap_3_1 settle | native, fitted | pass | 0.700 | 0.750 s (x within 0.5 of 61.68) | ±10 % |
| tap_3_1 peak h | native, fitted | pass | 48.81 | 49.51 | ±10 % |
| tap_3_1 w wobble | native, fitted | pass | 143.38 | 136.11 | ±10 % |
| tap_3_1 h wobble | native, fitted | pass | 23.22 | 23.35 | ±10 % |
| dark.tap_1_2 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| dark.tap_1_2 clock | condition | pass | -13.5 ms | x rows to 600ms, within ±16.5 ms |  |
| dark.tap_1_2 frames | condition | pass | longest 16.7 ms at +316.7 ms | at most 25.0 ms |  |
| dark.tap_1_2 x @0ms | native, fitted | pass | 61.69 | 61.50 | ±2.00 |
| dark.tap_1_2 x @50ms | native, fitted | pass | 77.73 | 77.77 | ±2.00 |
| dark.tap_1_2 x @100ms | native, fitted | pass | 115.25 | 115.74 | ±2.00 |
| dark.tap_1_2 x @150ms | native, fitted | pass | 146.64 | 146.68 | ±2.00 |
| dark.tap_1_2 x @200ms | native, fitted | pass | 165.95 | 165.29 | ±2.00 |
| dark.tap_1_2 x @250ms | native, fitted | pass | 176.57 | 175.33 | ±2.00 |
| dark.tap_1_2 x @300ms | native, fitted | pass | 182.38 | 181.21 | ±2.00 |
| dark.tap_1_2 x @350ms | native, fitted | pass | 185.52 | 184.71 | ±2.00 |
| dark.tap_1_2 x @400ms | native, fitted | pass | 186.98 | 186.44 | ±2.00 |
| dark.tap_1_2 x @450ms | native, fitted | pass | 187.34 | 187.00 | ±2.00 |
| dark.tap_1_2 x @500ms | native, fitted | pass | 187.06 | 186.84 | ±2.00 |
| dark.tap_1_2 x @550ms | native, fitted | pass | 186.51 | 186.18 | ±2.00 |
| dark.tap_1_2 x @600ms | native, fitted | pass | 185.96 | 185.67 | ±2.00 |
| dark.tap_1_2 overshoot | native, fitted | pass | 2.34 | 2.60 (peak 187.00, rest 184.40) | ±1.00 |
| dark.tap_1_2 settle | native, fitted | pass | 0.700 | 0.700 s (x within 0.5 of 184.40) | ±10 % |
| dark.tap_1_2 peak h | native, fitted | pass | 37.85 | 39.15 | ±10 % |
| dark.tap_1_2 w wobble | native, fitted | pass | 111.15 | 108.36 | ±10 % |
| dark.tap_1_2 h wobble | native, fitted | pass | 31.28 | 31.21 | ±10 % |
| tap_1_3_5seg engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_1_3_5seg clock | condition | pass | -8.5 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_1_3_5seg frames | condition | pass | longest 16.7 ms at +133.3 ms | at most 25.0 ms |  |
| tap_1_3_5seg x @0ms | native, fitted | pass | 37.02 | 37.00 | ±2.00 |
| tap_1_3_5seg x @50ms | native, fitted | pass | 52.59 | 51.48 | ±2.00 |
| tap_1_3_5seg x @100ms | native, fitted | pass | 96.76 | 96.63 | ±2.00 |
| tap_1_3_5seg x @150ms | native, fitted | pass | 135.80 | 136.25 | ±2.00 |
| tap_1_3_5seg x @200ms | native, fitted | pass | 160.32 | 161.18 | ±2.00 |
| tap_1_3_5seg x @250ms | native, fitted | pass | 173.90 | 174.48 | ±2.00 |
| tap_1_3_5seg x @300ms | native, fitted | pass | 181.31 | 181.49 | ±2.00 |
| tap_1_3_5seg x @350ms | native, fitted | pass | 185.34 | 185.14 | ±2.00 |
| tap_1_3_5seg x @400ms | native, fitted | pass | 187.27 | 186.75 | ±2.00 |
| tap_1_3_5seg x @450ms | native, fitted | pass | 187.80 | 187.19 | ±2.00 |
| tap_1_3_5seg x @500ms | native, fitted | pass | 187.52 | 187.04 | ±2.00 |
| tap_1_3_5seg x @550ms | native, fitted | pass | 186.88 | 186.61 | ±2.00 |
| tap_1_3_5seg x @600ms | native, fitted | pass | 186.21 | 186.00 | ±2.00 |
| tap_1_3_5seg overshoot | native, fitted | pass | 2.81 | 2.27 (peak 187.19, rest 184.92) | ±1.00 |
| tap_1_3_5seg settle | native, fitted | pass | 0.700 | 0.700 s (x within 0.5 of 184.92) | ±10 % |
| tap_1_3_5seg peak h | native, fitted | pass | 37.79 | 38.93 | ±10 % |
| tap_1_3_5seg w wobble | native, fitted | pass | 65.16 | 61.24 | ±10 % |
| tap_1_3_5seg h wobble | native, fitted | pass | 31.46 | 31.76 | ±10 % |
| press w @33ms | native, fitted | pass | 119.89 | 119.00 | ±2.00 |
| press h @33ms | native, fitted | pass | 28.37 | 28.00 | ±2.00 |
| press w @67ms | native, fitted | pass | 126.38 | 125.16 | ±2.00 |
| press h @67ms | native, fitted | pass | 32.70 | 32.11 | ±2.00 |
| press w @100ms | native, fitted | pass | 132.99 | 132.01 | ±2.00 |
| press h @100ms | native, fitted | pass | 37.11 | 36.68 | ±2.00 |
| press w @133ms | native, fitted | pass | 137.53 | 136.83 | ±2.00 |
| press h @133ms | native, fitted | pass | 40.13 | 39.89 | ±2.00 |
| press w @167ms | native, fitted | pass | 140.30 | 139.72 | ±2.00 |
| press h @167ms | native, fitted | pass | 41.98 | 41.81 | ±2.00 |
| press w @200ms | native, fitted | pass | 141.77 | 141.32 | ±2.00 |
| press h @200ms | native, fitted | pass | 42.96 | 42.88 | ±2.00 |
| press w @233ms | native, fitted | pass | 142.55 | 142.16 | ±2.00 |
| press h @233ms | native, fitted | pass | 43.48 | 43.44 | ±2.00 |
| press w @266ms | native, fitted | pass | 142.94 | 142.59 | ±2.00 |
| press h @266ms | native, fitted | pass | 43.74 | 43.72 | ±2.00 |
| press w @300ms | native, fitted | pass | 143.15 | 143.00 | ±2.00 |
| press h @300ms | native, fitted | pass | 43.88 | 44.00 | ±2.00 |
| press engage onset | native | pass | 0.043 | 0.048 | ±0.017 |
| dark.press engage onset | native | pass | 0.043 | 0.046 | ±0.017 |
| release w @+33ms | native, fitted | pass | 141.53 | 141.21 | ±2.00 |
| release h @+33ms | native, fitted | pass | 42.80 | 42.80 | ±2.00 |
| release engage @+33ms | native, fitted | pass | 1.00 | 1.00 | ±0.12 |
| release w @+67ms | native, fitted | pass | 134.08 | 134.17 | ±2.00 |
| release h @+67ms | native, fitted | pass | 37.83 | 38.11 | ±2.00 |
| release engage @+67ms | native, fitted | pass | 1.00 | 1.00 | ±0.12 |
| release w @+100ms | native, fitted | pass | 127.85 | 127.97 | ±2.00 |
| release h @+100ms | native, fitted | pass | 33.68 | 33.98 | ±2.00 |
| release engage @+100ms | native, fitted | pass | 1.00 | 1.00 | ±0.12 |
| release w @+133ms | native, fitted | pass | 123.90 | 123.92 | ±2.00 |
| release h @+133ms | native, fitted | pass | 31.04 | 31.28 | ±2.00 |
| release engage @+133ms | native, fitted | pass | 0.84 | 0.82 | ±0.12 |
| release w @+167ms | native, fitted | pass | 121.62 | 121.58 | ±2.00 |
| release h @+167ms | native, fitted | pass | 29.52 | 29.72 | ±2.00 |
| release engage @+167ms | native, fitted | pass | 0.47 | 0.43 | ±0.12 |
| release w @+200ms | native, fitted | pass | 120.46 | 120.31 | ±2.00 |
| release h @+200ms | native, fitted | pass | 28.75 | 28.87 | ±2.00 |
| release engage @+200ms | native, fitted | pass | 0.23 | 0.22 | ±0.12 |
| drag lag | native | pass | 6.48 (6.46 at 82.0 pt/s) | 6.77 at 82.2 pt/s | ±10 % |
| flick drive | condition | pass | 0.548 s over 246.50 pt | 0.548 s over 246.50 pt (±1 frame, ±2 pt) |  |
| flick lands | native | pass | 61.67 | 61.50 | ±0.50 |
| flick overshoot | native | pass | 3.19 | 3.86 | ±1.00 |
| programmatic clock | condition | pass | first frame at 16.7 ms | within 250.0 ms of the write |  |
| programmatic x @0ms | native, fitted | pass | 92.50 | 92.50 | ±2.00 |
| programmatic x @50ms | native, fitted | pass | 99.84 | 100.08 | ±2.00 |
| programmatic x @100ms | native, fitted | pass | 151.40 | 152.42 | ±2.00 |
| programmatic x @150ms | native, fitted | pass | 206.25 | 206.69 | ±2.00 |
| programmatic x @200ms | native, fitted | pass | 244.56 | 243.89 | ±2.00 |
| programmatic x @250ms | native, fitted | pass | 265.96 | 264.56 | ±2.00 |
| programmatic x @300ms | native, fitted | pass | 275.73 | 274.19 | ±2.00 |
| programmatic x @350ms | native, fitted | pass | 279.07 | 277.80 | ±2.00 |
| programmatic x @400ms | native, fitted | pass | 279.52 | 278.65 | ±2.00 |
| programmatic x @450ms | native, fitted | pass | 279.01 | 278.50 | ±2.00 |
| programmatic x @500ms | native, fitted | pass | 278.38 | 278.14 | ±2.00 |
| programmatic x @550ms | native, fitted | pass | 277.92 | 277.84 | ±2.00 |
| programmatic x @600ms | native, fitted | pass | 277.66 | 277.50 | ±2.00 |
| colour lightTrackOverWhite | native, constant | pass | 238/238/240 | 238/238/239 | ±4 |
| colour lightThumb | native, constant | pass | 255/255/255 | 255/255/255 | ±4 |
| colour lightLabel | native, constant | pass | 0/0/0 | 0/0/0 | ±4 |
| colour lightDisabledTrack | native, constant | pass | 246/246/248 | 246/246/247 | ±4 |
| colour darkTrackOverBlack | native, constant | pass | 28/28/31 | 28/28/31 | ±4 |
| colour darkThumbOverTrack | native, constant | pass | 91/91/96 | 90/90/95 | ±4 |
| colour darkLabel | native, constant | pass | 255/255/255 | 255/255/255 | ±4 |

```
19 native, 21 native but constant, 139 native but fitted to them, 0 against fitted springs, 12 conditions
✓ all 191 checks pass
```

## 4. Holdout

Every native tap capture had been used to fit the model (Task 4, Task 15), so Task 15 captured fresh repeats after the last fit and did not fit to them: `docs/qa/vk550/native_holdout.json`, 21 taps (the spike's SegFid probe, the same extraction as the fixture; every touch delivered within 17.3 ms). `liquid_shell/test/unit/segment_holdout_test.dart` runs the model through the tap gate on each: x ±2 pt per row to +0.6 s on the device table's clock, overshoot ±1 pt, settle ±10 %, peak h and wobble extremes ±10 %.

| Capture | Repeats | Result |
|---|---|---|
| `tap_1_2`, `tap_2_3`, `tap_3_1`, `dark.tap_1_2`, `tap_1_3_5seg` | 3 each | **All 15 pass every check** |
| `dark.tap_2_1` (3 segments, one to the left, 123 pt) | 3 | Fail peak h (37.8 vs 49.3) and the h wobble (27.5 vs 25.0) |
| `tap_3_1_5seg` (5 segments, two to the left, 148 pt) | 3 | Fail peak h (37.8 vs 48.6–49.9); one repeat also the h wobble |

The two new kinds show that native's lift follows the **direction** (to the right: wide; to the left: tall), not the distance Task 15 read from the fitted captures (every fitted capture fits both rules). Not refitted: the test pins exactly these failures as a known residual, so a direction rule, checked against a further holdout, is the follow-up.

## 5. `make tab-traces` (the VK-503 table, refactor guard)

`✗ 1 of 100 failed` (73 native, 14 native but constant, 13 against fitted springs): the name, kind and result columns are identical to Task 6's and Task 13's tables, and the one failure is the known one, value for value:

| colour lightFillPage | native | FAIL | 242/241/249 vs 242/240/254 (±4) |

The tab lens keeps `LensLook.tab` (pinned by `lens_profile_test.dart` and the unchanged `lens_layer_test.dart` uniforms); its goldens (`tab_lens_pressed`, `tab_lens_straddle`, `tab_lens_pressed_dark`, `tab_glow_release_dark`) did not change in `make goldens-update`.

## 6. Strips

`make segment-frames` at 1da892f; the strips are in `vankhan/.superpowers/sdd/vk550-strips/{light,dark}/frames_1..8.png` (native left, Flutter right, one row every 3 frames). Dark paired 8 against 8. Light found a 9th native onset: native's slow drag outlived its strip, so its landing counted as an onset. Strips 7 and 8 were re-paired by hand from the kept frames (native 1568 / Flutter 1113 for the flick, 1811 / 1285 for the programmatic slide), with the tool's own `composeStrip`.

| State | Light | Dark |
|---|---|---|
| Tap 1→2, 2→3 (strips 1, 2) | **Match.** Clear glass on both sides through the flight, the lift and the landing, then the white thumb fades in on the same rows | **Match.** No grey pop; the translucent thumb fades in alike. Native's lens shows the stripes a little brighter inside |
| Tap 3→1 (strip 3) | **The wide, flat landing now shows** on both sides. Flutter leads by about one row | As light |
| Press, held (strip 4) | **Match.** Clear glass, the track seen through it, a thin rim, the stripes bent at the ends | **Match.** As light; native's rim is a little dimmer |
| Release (strip 5) | **Match.** The lens shrinks and the white thumb fades in on about the same rows | **Match.** No grey pill: the lens returns to the translucent thumb in about 3 rows, as native's |
| Slow drag (strip 6) | **Match** in follow and pace; the look as for the press | As light |
| Flick (strip 7) | Same path; Flutter lands and turns white about 2 rows sooner. Native's lens also bends the labels it passes over (ours draws them above it) | As light, with no grey pill at the end |
| Programmatic (strip 8) | **Match.** The thumb slides without a lens | **Match** |

What still differs, in every strip: native's lens shrinks the page behind it about 0.8 times vertically (measured on the spike's grid shot: grid lines 30 / 60 / 90 / 120 px show at 38.5 / 63 / 86.5 / 111.5 under the held lens), and this one passes it as it is inside its ring.

## 7. Native scope bar

`make integration-ios-native` (`native_shell_test`, `native_dialogs_test`, `native_search_test`) passed on `vk550-t15-ipad` and `vk550-t15-iphone`; `native_search_test` alone passed on `vk550-t15-promax` (`✓ native shell integration passed`, both runs). Screenshots, from `liquid_shell/example/build/integration_screenshots/`, are in `vankhan/.superpowers/sdd/vk550-strips/scopes/`:

| Device | Portrait | Landscape |
|---|---|---|
| iPhone 17 Pro, iOS 26.5 | `iphone17pro_scopes.png`: at the top, under the status bar, while the search is active | `iphone17pro_scopes_landscape.png`: at the top, centred, 426 pt wide; the results under it |
| iPhone 17 Pro Max, iOS 26.5 | `iphone17promax_scopes.png`: as the 17 Pro | `iphone17promax_scopes_landscape.png`: **not inline** (Task 10 review's question): at the top, centred, as on the 17 Pro; the test's "results under the bar" passes |
| iPad Air 11-inch (M4), iOS 26.5 | `ipadair11_scopes.png`: under the risen field | (rotation checked in `SearchUITests`, `make ios-ui`) |
| iOS 27 | not captured: the runtime is not installed on this host | |

In both iPhone landscape screenshots the field, riding above the keyboard, overlaps the first result row: the known landscape inset issue found in Task 11 (its own Plane item), not the scope bar.

## 8. Accepted limits (Q-A … Q-F)

| Q | What the run shows |
|---|---|
| Q-A (UIKit's scope bar, shown while the search is active) | Shown at the top on the iPhones and under the field on the iPad, while active (§7) |
| Q-B (flat track; glass only in the lens) | As native's; all 7 rest colours pass (±4) |
| Q-C (44 pt box, intrinsic segments ≥ 44) | `intrinsic3` 177 as native's; "A \| B \| C" stays 132 against 96 (intended) |
| Q-D (labels to ×2, ellipsis, large content viewer) | Unchanged by this task (`case_segments_ax2`) |
| Q-E (two-spring flight, wobble, squash; gated on peaks and settle) | Every gated row passes on every capture and on the 15 fitted-kind holdout repeats. Not identical frame by frame; short taps to the left lift 38 pt where native's lift about 49 (§4); the five-segment lift is 91 pt wide at its peak against native's 104 (not gated) |
| Q-F (text segments only) | Unchanged |

## 9. Remaining visible differences

1. Short taps to the left (one segment of three, two of five) lift less than native's (37.8 against about 49 pt tall): §4.
2. Native's lens shrinks the page about 0.8 times vertically and bends the labels it passes over; ours passes the page 1:1 inside the ring and draws the labels above the lens.
3. The flick's overshoot changes with speed here where native's barely does: 4.40 against 4.04 at `flick`'s speed; 3.06–3.21 against 3.86 at `flickLanding`'s, by frame phase 2.71–3.65 (a run can still land under 2.86).
4. The five-segment tap lifts 91 pt wide at its peak against native's 104 (−13 %, not a gated row).
5. Flutter lands the flick and the 3→1 tap about 1–2 rows (50–100 ms) sooner in the strips.
6. A dropped frame still shows now and then on the shared simulator (run 1: the first two taps); the driver warms the debug build's code first.

## 10. Verification

| Gate | Result |
|---|---|
| `make verify` | `✓ verify passed`: format, analyze (no issues), provenance, glass seam, pigeon, tests (liquid_shell +1042, platform_interface +48, ios +34, android +1, example +159, tool +113), coverage 97.59 / 96.44 / 98.97 / 100 %, Impeller +18, goldens +36 and liquid +27, 19 snippets |
| `make test-impeller` | +18, all passed |
| `make goldens-update` | regenerated: `segment_lens_pressed`, `segment_lens_straddle` and the new `segment_lens_pressed_dark` (the look); `case_segments_{light,dark,rtl,ax2}` and `case_search_{phone_active,phone_results,tablet_active}` (the label tracking: 0.02–0.8 % of their pixels). Every image reviewed; the tab goldens are unchanged |
| `make segment-traces` ×3 | 189 / 191, 191 / 191, 191 / 191 (§3) |
| `make tab-traces` | 99 / 100, the known `colour lightFillPage` (§5) |
| `make ios-unit` (`vk550-t15-iphone`) | Passed: 153 tests, 137 passed, 16 skipped, 0 failed |
| `make ios-ui` (`vk550-t15-iphone`) | exit 0, 412 s (`-quiet` prints failures only) |
| `make ios-ui` (`vk550-t15-ipad`) | exit 0, 330 s |
| `make integration-ios-native` | passed on the iPad, the iPhone and the Pro Max (§7) |
| `make segment-frames` | dark 8 pairs; light 8 of 9 native onsets paired, re-paired by hand (§6) |
| `bash .githooks/pre-commit` | `✓ pre-commit passed`: before the first commit, with the whole change in the tree, and before this document's commit |

## 11. Owner on device

- [ ] Haptics on drag (Q3): one selection click per segment crossed, none on a tap, a release or an app change.
- [ ] The native scope bar on an iPhone and an iPad (iOS 26+): shown while the search is active, a tap selects and puts the keyboard away; an iPhone Pro Max in landscape.
- [ ] The Flutter control with "Flutter liquid" forced, light and dark: the clear lens, no grey flash at the start or end of a press, the wide flat landing of a long tap, a short tap to the left (§4).
- [ ] No hitch on the first press after launch (a release build: the lens is built at the first control's mount).
