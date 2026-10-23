# VK-550 acceptance: the segmented control, traces and strips

## 1. Run

- **Date:** 2026-10-14 (Task 15), 2026-10-15 (the review round).
- **Simulators** (iOS 26.5, 23F77, and iOS 27.0, 24A434; each created for this run and deleted after it):
  - `vk550-segfid`, iPhone 17 Pro: created and deleted by `tool/segment_frames.sh` for every `make segment-traces` and `make segment-frames`;
  - `vk503-tabfid`, iPhone 17 Pro: created and deleted by `tool/tab_frames.sh` (`make tab-traces`);
  - Task 15: `vk550-t15-iphone`, `vk550-t15-ipad` (iPad Air 11-inch (M4)), `vk550-t15-promax` (iPhone 17 Pro Max) and `vk550-t15-holdout` (the spike's SegFid probe);
  - the review round: `vk550-t15b-native` (SegFid, the discriminating taps), `vk550-t15c-iphone` and `vk550-t15c-ipad` (iOS 26.5: `make ios-unit`, `make ios-ui`), `vk550-t15c-iphone27` and `vk550-t15c-ipad27` (iOS 27.0: the native scope bar).
- **Toolchain:** Xcode 27.0, Flutter 3.44.6 (fvm). The iOS 27.0 runtime is installed; Task 15's first report wrongly said it was not.
- **Code:** branch `VK-550-liquid-segmented-control`, from ecfdb4c:
  - 534f6f5 `fix(shell): a native scope index past the titles is ignored`;
  - 25f3c2c `fix(shell): the segment lens tuned against native`;
  - c949ba1 `test(shell): the segment model against a native tap holdout`;
  - 1da892f `docs(docs): the segment lens after Task 15's tuning round`;
  - 7ecbcd6 `docs(docs): VK-550 acceptance traces and strips`;
  - the review round: 4f63dba `test(ci): one tap gate for the device table and the model's tests`, f1a4cb8 `fix(shell): the tap lift follows the direction on screen`, c2e52eb `fix(shell): the segment lens squeezes the page as native's`, dd509b9 `docs(docs): the segment lens after the Task 15 review`;
  - this document's update.
- **Native reference:** `docs/qa/vk550/native_reference.json` (spike and Task 1 captures, plus `lens.look`, measured on the segment strips), `docs/qa/vk550/native_holdout.json` (Task 15's holdout, now a validation set) and `docs/qa/vk550/native_taps.json` (the review's discriminating taps: a fitting split and a holdout split). Kinds as spec §14.5:
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
| **Lens look** (retuned in §2b) | A milky core (white veil 0.90) and a thick black rim (golden metrics: core chroma 0.11 of the page's, ring p5 luma −106) | Clear glass, a thin rim: core chroma 0.969 / 0.970 of the page's (native 0.965 / 0.965), ring p5 luma −1.8 / 0.0 (native −8.0 / 0.0), light / dark | `LensLook.segment`: black veil 0.03, saturation 1, thickness 0.3 × 48 pt, dispersion 0.6, no blur, white rim 0.5 over 1 pt, bezel 9. The tab's thickness (1.6) bent rays 59 pt inward, past the 44 pt lens: the black rim. Gated in `liquid_test.dart` against `lens.look` (measured on native's strips the same way; native, fitted: in sample). The tab keeps `LensLook.tab`: its goldens are unchanged and `make tab-traces` is 99/100 as before |
| **Intrinsic width** (tracking narrowed to the system font in §2b) | 180 vs 177 (±1) | 177 | The labels track −0.08 pt, SF Pro's tracking at 13 pt, which UIKit applies and Flutter's text engine does not. Measured on the simulator: "Places" w500 41.27 without it, 40.79 with it (native 40.67); "All \| Recently played" 234 (native 234) |
| **Five-segment tap lift** | Peak h 48.6 vs 38.9 | 37.8 | Task 15 made it follow the distance; the review showed it follows the direction on screen (§2b, §4) |
| **Five-segment wobble** | w 69.9 vs 61.2 | 65.2 | As above |
| **`tap_3_1` w wobble** (−12 %) | 119.5 vs 136.1 | 143.4 (+5 %) | After the lift the lens keeps its area (native's w × h stays within 4 % of rest from +0.45 s): the side the lift stretched most returns on the wobble spring, the area on its own spring (0.80 / 0.36 s), the other side is area over it. Also lifts a one-segment tap's h wobble (28.6 → 30.4, native 31.4) |
| **First-engage dropped frame** (`tap_1_2 frames`) | 33–50 ms in every run | **Not measured** | The traces run a debug (JIT) build, and the driver now taps there and back before recording, so the first engage after launch is not in the table. Warming the lens pipeline did not remove the drop; a lens drawn at mount moved it to the release. A release build's first press is unverified: profile mode does not run on a simulator. The product warm-up was removed in the review (§2b). Single dropped frames still show under load (§3) |
| **Flick overshoot** | 2.77 / 2.96 / 3.11 vs 3.86 ±1 (one run failed) | 3.21 / 3.06 / 3.19 | Release spring 0.785 / 0.585 s (was 0.80 / 0.59). Native's overshoot barely changes with speed (4.04 at about 630 pt/s, 3.86 at about 450); a linear spring's does, so one spring shares the error: `flick` 4.40 (was 4.10, native 4.04, ±10 %), `flickLanding` driven as the simulator drives it, median 3.11 over the frame phases (2.71 to 3.65 by phase; was 2.85) |
| **Holdout** | None left (all five captures fitted) | 21 fresh native taps | §4 |
| **Task 10 review M6** | A native scope index past the titles was applied | Ignored | Tested |
| **Doc, "Wobble (Q-E)"** | Claimed every capture | States what still differs | `doc/segmented_control.md` |

## 2b. The review round (Task 15 review)

The review (`seg-task-15-review.md`) and the owner's approval of one shader uniform changed six things. Each was gated against native data, test first.

| Item | Before (Task 15) | After | How |
|---|---|---|---|
| **Lift rule** | By distance (148 pt wide, 247 pt tall), contradicted to the left by the Task 15 holdout | **By direction on screen**: right is wide, left is tall, whatever the distance or the target | 78 discriminating native taps (§4), split before looking. Every peak h passes on the 31 fitted taps and the 73 held out (which repeat the fitted sequences: repeatability, not new kinds of tap); the w swing after a long tap to the right on five segments still misses (+13 to +15 %). The wobble spring was refitted on the fitting set: 0.48 / 0.47 s, was 0.42 |
| **Gate logic** | Three copies (the device table, the model test, the holdout test) | One: `tool/segment_gate.dart` | The table is byte for byte the same on the final runs' responses; the model's tests re-export the module |
| **Squeeze** (owner approved) | The page passed 1:1 inside the ring | **Squeezed 1 / 1.226 across the height** (native 1 / 1.225 and 1 / 1.231) | One uniform, `uSqueeze` (float 27): a point at u from the spine reads the page at (1 + uSqueeze) u. 0, on every other surface, takes the old path byte for byte (the Impeller test shows that 0 equals the lens without the uniform byte for byte; that it also draws the old pixels is shown only within the comparator's 0.5 % tolerance (`TolerantGoldenComparator`) by the `tab_*` and `liquid_*` band goldens in `liquid_shell/example/test/goldens/bands/`: commit `c2e52eb`, which added the uniform, regenerated only the three `segment_lens_*` bands, and no later commit touches `bands/`). Only `LensLook.segment` sets it (0.22, times the refraction) |
| **Ring bend and fringe** | Thickness 0.3, dispersion 0.6 | Thickness 0.2, dispersion 1, veil 0.04: ring bend 3.1 / 3.0 pt (native 3.0 / 3.4) | The geometric numbers are measured on the native strips and gated under Impeller (`lens.look` `coreSqueeze`, `ringBend`): **native, fitted (in sample)**, since `LensLook.segment` was tuned to them, and `ringBend` includes the squeeze, so it checks the bezel's own bend only weakly and does not see the fringe. Native's fringe is still stronger |
| **Label tracking** | −0.08 pt on every font | **SF Pro's tracking for the drawn size, in the system font only** (`sfTracking`, Apple's table) | An app's own font keeps its spacing; the goldens' Inter labels are back to their pre-Task-15 pixels. `intrinsic3` stays 177 |
| **Product warm-up** | A 1 × 1 lens for one frame at mount, unmeasured | **Removed** | Profile mode does not run on a simulator (`flutter run --profile`: "Profilemode is not supported"), and physical devices were out of bounds, so nothing showed the warm-up helps. The trace driver's tap there and back stays, as a debug (JIT) artefact: the first engage after launch is not measured. A release build's first press is an owner check on a device |
| **Flick overshoot kind** | `native` | `native, fitted` | Task 15 fitted the release spring to it |

## 3. `make segment-traces`

Three consecutive runs at dd509b9, each on its own new simulator. The host was shared, and runs started while its load was over 300 dropped frames and drives; they were stopped and run again when it fell under 50.

| Run | Result | Failed |
|---|---|---|
| 1 | ✓ all 191 checks pass | |
| 2 | ✗ 2 of 191 failed | `tap_1_2 frames` (33.3 ms at +16.7 ms) and `tap_1_3_5seg frames` (33.3 ms at +100 ms): conditions, not comparisons; every motion row passed |
| 3 | ✓ all 191 checks pass | |

Each run has 18 native rows, 21 native but constant, 140 native but fitted to them and 12 conditions. `flick overshoot` is now native, fitted, and read 3.13, 3.08 and 3.37 against native's 3.86 ±1. In every run `intrinsic3` is 177 (native 177), the `tap_3_1` w wobble 136.14 (136.11) and the `tap_1_3_5seg` peak h 37.79 (38.93).

Run 3's table:

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
| tap_1_2 frames | condition | pass | longest 16.7 ms at +233.3 ms | at most 25.0 ms |  |
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
| tap_1_2 w wobble | native, fitted | pass | 112.93 | 108.22 | ±10 % |
| tap_1_2 h wobble | native, fitted | pass | 29.96 | 31.41 | ±10 % |
| tap_2_3 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_2_3 clock | condition | pass | -2.0 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_2_3 frames | condition | pass | longest 16.7 ms at +233.3 ms | at most 25.0 ms |  |
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
| tap_2_3 w wobble | native, fitted | pass | 112.93 | 109.11 | ±10 % |
| tap_2_3 h wobble | native, fitted | pass | 29.96 | 31.42 | ±10 % |
| tap_3_1 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_3_1 clock | condition | pass | -16.0 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_3_1 frames | condition | pass | longest 16.7 ms at +0.0 ms | at most 25.0 ms |  |
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
| tap_3_1 w wobble | native, fitted | pass | 136.14 | 136.11 | ±10 % |
| tap_3_1 h wobble | native, fitted | pass | 24.45 | 23.35 | ±10 % |
| dark.tap_1_2 engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| dark.tap_1_2 clock | condition | pass | -13.5 ms | x rows to 600ms, within ±16.5 ms |  |
| dark.tap_1_2 frames | condition | pass | longest 16.7 ms at +0.0 ms | at most 25.0 ms |  |
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
| dark.tap_1_2 w wobble | native, fitted | pass | 112.95 | 108.36 | ±10 % |
| dark.tap_1_2 h wobble | native, fitted | pass | 30.98 | 31.21 | ±10 % |
| tap_1_3_5seg engage onset | native | pass | 0.043 | 0.034 | ±0.017 |
| tap_1_3_5seg clock | condition | pass | -8.5 ms | x rows to 600ms, within ±16.5 ms |  |
| tap_1_3_5seg frames | condition | pass | longest 16.7 ms at +150.0 ms | at most 25.0 ms |  |
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
| tap_1_3_5seg w wobble | native, fitted | pass | 66.25 | 61.24 | ±10 % |
| tap_1_3_5seg h wobble | native, fitted | pass | 31.19 | 31.76 | ±10 % |
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
| flick drive | condition | pass | 0.551 s over 246.50 pt | 0.548 s over 246.50 pt (±1 frame, ±2 pt) |  |
| flick lands | native | pass | 61.67 | 61.50 | ±0.50 |
| flick overshoot | native, fitted | pass | 3.37 | 3.86 | ±1.00 |
| programmatic clock | condition | pass | first frame at 33.3 ms | within 250.0 ms of the write |  |
| programmatic x @0ms | native, fitted | pass | 92.50 | 92.50 | ±2.00 |
| programmatic x @50ms | native, fitted | pass | 99.62 | 100.08 | ±2.00 |
| programmatic x @100ms | native, fitted | pass | 151.24 | 152.42 | ±2.00 |
| programmatic x @150ms | native, fitted | pass | 206.16 | 206.69 | ±2.00 |
| programmatic x @200ms | native, fitted | pass | 244.52 | 243.89 | ±2.00 |
| programmatic x @250ms | native, fitted | pass | 265.95 | 264.56 | ±2.00 |
| programmatic x @300ms | native, fitted | pass | 275.72 | 274.19 | ±2.00 |
| programmatic x @350ms | native, fitted | pass | 279.07 | 277.80 | ±2.00 |
| programmatic x @400ms | native, fitted | pass | 279.53 | 278.65 | ±2.00 |
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
18 native, 21 native but constant, 140 native but fitted to them, 0 against fitted springs, 12 conditions
✓ all 191 checks pass
```

## 4. Holdouts

Every fixture capture had been used for fitting. Native taps were captured on my own simulators with the spike's SegFid probe: idb taps, the same extraction as the fixture, every touch delivered within 28.1 ms.

- **Task 15's holdout** (`native_holdout.json`, 21 taps): three repeats of each fixture tap, plus `dark.tap_2_1` and `tap_3_1_5seg`. It showed Task 15's distance rule wrong to the left (peak h 37.8 against 48.6–49.9) before any rule was chosen, so it is now a **validation** set.
- **The discriminating taps** (`native_taps.json`, 78 taps), captured for the review:
  - five segments: 1→2, 2→1, 1→3, 3→1, 1→5, 5→1, 1→4, 4→3, 3→5, 5→3, 3→2, 2→1;
  - three segments: 1→2, 2→3, 3→2, 2→1, 1→3, 3→1;
  - two segments: 1→2, 2→1;
  - three segments right to left: the same six.

  Each sequence ran three times. The split was fixed before any capture was looked at: pass 0 joins the **fitting set** (26 taps), passes 1 and 2 are the **holdout** (52 taps). The holdout repeats the fitted sequences, and UIKit repeats itself closely, so it shows repeatability, not that the model holds for new kinds of tap; the fitting set covers every kind of tap measured. The validation set shaped the lift rule.

What the data supports, with peak heights from the fitting split:

| Candidate rule | Prediction | Native |
|---|---|---|
| Distance (Task 15) | 74 pt left: wide | 5-segment 2→1, 4→3, 3→2 (74 pt left): **tall**, 47.9 |
| Lands on the first segment | 4→3, 3→2: wide; RTL 2→1 (to segment 1, to the right on screen): tall | 4→3, 3→2: **tall**, 47.9; RTL 2→1: **wide**, 39.2 |
| **Direction on screen** | right: wide; left: tall | **every tap**: right 38.1–39.9, left 47.9–51.0, from 74 to 296 pt, LTR and RTL |

The model now selects the shape by the direction on screen. There is no new continuous parameter; only the wobble spring was refitted, on the fitting set. `segment_holdout_test.dart` runs the shared gate on each held-out tap (x on the device table's clock, overshoot, settle, peak h, wobble extremes, tolerances unchanged):

| Set | Taps | Peak h (the lift's shape) | Misses, pinned exactly |
|---|---|---|---|
| Validation (Task 15's holdout) | 21 | all pass | none |
| Holdout split | 52 | all pass | 9 taps: 5-segment 1→5, 5→1 and 1→4 (×2 each): the overshoot (4.2–5.6 pt against native's 3.0–4.3), on 1→5 and 5→1 the slide's x at +0.2–0.5 s, and after 1→5 and 1→4 the w swing (66 against 57–59); two-segment 1→2 (×2): x at +0.25–0.3 s, 2.1 pt off; one 5-segment 3→2: x at +0.1–0.15 s, 4.4 pt off, on a clock 8 ms from its siblings' |

The fitting split misses the same kinds (`segment_motion_test.dart`, pinned): 1→5, 5→1, 1→4 and the two-segment 1→2. These are taps longer than any fixture capture on five segments, and a two-segment control. The slide (x) was fitted in Task 4 to 123–247 pt hops on three segments and was not refitted here: native's overshoot grows less than in proportion to the distance.

## 5. `make tab-traces` (the VK-503 table, refactor guard)

`✗ 1 of 100 failed` at dd509b9 (73 native, 14 native but constant, 13 against fitted springs): the name, kind and result columns are identical to Task 6's and Task 13's tables, and the one failure is the known one, value for value:

| colour lightFillPage | native | FAIL | 242/241/249 vs 242/240/254 (±4) |

The tab lens keeps `LensLook.tab` (pinned by `lens_profile_test.dart` and the unchanged `lens_layer_test.dart` uniforms); its goldens (`tab_lens_pressed`, `tab_lens_straddle`, `tab_lens_pressed_dark`, `tab_glow_release_dark`) and every other non-segment golden did not change in either `make goldens-update`, the shader's new uniform included.

## 6. Strips

`make segment-frames` ran at dd509b9. The strips are in `vankhan/.superpowers/sdd/vk550-strips/{light,dark}/frames_1..8.png`: native left, Flutter right, one row every 3 frames. Task 15's first strips moved to `task15-first/`.

Dark paired 8 against 8. In light, native's slow drag outlived its strip, so its landing counted as a 9th onset. Light strips 7 and 8 were re-paired by hand from the kept frames, with the tool's own `composeStrip`: the flick is native 1575 against Flutter 1099, the programmatic slide native 1824 against Flutter 1258.

| State | Light | Dark |
|---|---|---|
| Tap 1→2, 2→3 (strips 1, 2) | **Match in tint, rim, lift and timing.** Clear glass through the flight; the white thumb fades in on the same rows. Native's flying lens distorts the stripes more | **Match in tint, rim and timing.** No grey pop; the translucent thumb fades in alike. Native's flying lens distorts the stripes more |
| Tap 3→1 (strip 3) | **Match.** The tall lift, then the wide, flat landing. Flutter leads by about one row | As light |
| Press, held (strip 4) | **Match.** Clear glass, the track squeezed into a narrower band inside the lens as native's, straight stripes, a thin rim. Native's colour fringe at the stripe ends and the caps is stronger | As light |
| Release (strip 5) | **Match.** The lens shrinks and the white thumb fades in on about the same rows | **Match.** No grey pill: back to the translucent thumb in about 3 rows, as native's |
| Slow drag (strip 6) | **Match** in follow and pace, and in look as for the press | As light |
| Flick (strip 7) | **Match in path and look.** Flutter lands and fades about 2–3 rows sooner. Native's lens bends the labels it passes, and its interior distorts more in flight | As light; no grey pill at the end |
| Programmatic (strip 8) | **Match.** The thumb slides without a lens | **Match** |

What still differs, in every strip:

- Native's fringe is stronger: rainbow edges along the top and bottom of the ring and at the caps. Ours uses the full dispersion the shader allows, at a thickness that keeps the ring's bend native-sized.
- Native's lens bends the labels it passes over. Ours draws them above the lens.
- In flight, native's interior distorts more than ours.

## 7. Native scope bar

`make integration-ios-native` (`native_shell_test`, `native_dialogs_test`, `native_search_test`) passed on `vk550-t15-ipad` and `vk550-t15-iphone`; `native_search_test` alone passed on `vk550-t15-promax`, and in the review round on `vk550-t15c-iphone27` and `vk550-t15c-ipad27` (`✓ native shell integration passed`, every run). Screenshots, from `liquid_shell/example/build/integration_screenshots/`, are in `vankhan/.superpowers/sdd/vk550-strips/scopes/`:

| Device | Portrait | Landscape |
|---|---|---|
| iPhone 17 Pro, iOS 26.5 | `iphone17pro_scopes.png`: at the top, under the status bar, while the search is active | `iphone17pro_scopes_landscape.png`: at the top, centred, 426 pt wide; the results under it |
| iPhone 17 Pro Max, iOS 26.5 | `iphone17promax_scopes.png`: as the 17 Pro | `iphone17promax_scopes_landscape.png`: **not inline** (Task 10 review's question): at the top, centred, as on the 17 Pro; the test's "results under the bar" passes |
| iPad Air 11-inch (M4), iOS 26.5 | `ipadair11_scopes.png`: under the risen field | (rotation checked in `SearchUITests`, `make ios-ui`) |
| iPhone 17 Pro, iOS 27.0 | `iphone17pro_ios27_scopes.png`: at the top, iOS 27's glass capsule track and larger labels, the field at the bottom | `iphone17pro_ios27_scopes_landscape.png` |
| iPad Air 11-inch (M4), iOS 27.0 | `ipadair11_ios27_scopes.png`: under the risen field | |

In both iPhone landscape screenshots the field, riding above the keyboard, overlaps the first result row: the known landscape inset issue found in Task 11 (its own Plane item), not the scope bar.

## 8. Accepted limits (Q-A … Q-F)

| Q | What the run shows |
|---|---|
| Q-A (UIKit's scope bar, shown while the search is active) | Shown at the top on the iPhones and under the field on the iPad, while active (§7) |
| Q-B (flat track; glass only in the lens) | As native's; all 7 rest colours pass (±4) |
| Q-C (44 pt box, intrinsic segments ≥ 44) | `intrinsic3` 177 as native's; "A \| B \| C" stays 132 against 96 (intended) |
| Q-D (labels to ×2, ellipsis, large content viewer) | Unchanged by this task (`case_segments_ax2`) |
| Q-E (two-spring flight, wobble, squash; gated on peaks and settle) | Every gated row passes on every fixture capture; every peak h passes on the 104 native taps of the fitting set and the holdouts. The misses left are pinned (§4): long 5-segment slides and overshoots, a two-segment x row, the w swing after a long 5-segment tap to the right. Not identical frame by frame |
| Q-F (text segments only) | Unchanged |

## 9. Remaining visible differences

1. Native's colour fringe at the ring and the caps is stronger. Ours runs at the shader's full dispersion, at a thickness that keeps the ring's bend native-sized.
2. Native's lens bends the labels it passes over; ours draws them above the lens. In flight, native's interior distorts more.
3. On five segments, a tap over three or four segments slides with a larger overshoot (4.2–5.6 pt against 3.0–4.3) and, to the right, narrows more after its lift (66 pt against 57–59). On two segments the slide is 2.1 pt off at +0.25–0.3 s.
4. The flick's overshoot changes with speed here, where native's barely does: 4.40 against 4.04 at `flick`'s speed, and 3.08–3.37 against 3.86 at `flickLanding`'s (2.71–3.65 by frame phase).
5. Flutter lands the flick and the 3→1 tap about 1–3 rows (50–150 ms) sooner in the strips.
6. A dropped frame still shows now and then on the shared simulator (final run 2). The first engage after launch is not measured, and a release build's first press is unverified (§2).

## 10. Verification

All at dd509b9, on the review round's simulators.

| Gate | Result |
|---|---|
| `make verify` | `✓ verify passed`: format, analyze (no issues), provenance, glass seam, pigeon. Tests: liquid_shell +1120, platform_interface +48, ios +34, android +1, example +159, tool +113. Coverage 97.59 / 95.62 / 98.97 / 100 %. Impeller +19, goldens +36 and liquid +27, 19 snippets |
| `make test-impeller` | +19 (the squeeze test added), all passed |
| `make goldens-update` (review round) | Regenerated: the three `segment_lens_*` bands (the squeeze). The case images `case_segments_{light,dark,rtl,ax2}` and `case_search_{phone_active,phone_results,tablet_active}` are back to their pre-Task-15 pixels (0 different pixels against ecfdb4c), because the goldens' Inter now keeps its own spacing. Every image was reviewed; no other golden changed |
| `make segment-traces` ×3 | 191 / 191, 189 / 191, 191 / 191 (§3) |
| `make tab-traces` | 99 / 100: the known `colour lightFillPage`, columns identical (§5) |
| `make ios-unit` (`vk550-t15c-iphone`) | Passed: 153 tests, 137 passed, 16 skipped, 0 failed |
| `make ios-ui` (`vk550-t15c-iphone`) | Passed: 20 tests, 20 passed (its xcodebuild command with a result bundle, for the counts) |
| `make ios-ui` (`vk550-t15c-ipad`) | Passed: 20 tests, 16 passed, 4 skipped (iPhone only), 0 failed |
| `make integration-ios-native` | Passed on the iPad, the iPhone, the Pro Max and, for `native_search_test`, iOS 27.0 on the iPhone and the iPad (§7) |
| `make segment-frames` | Dark: 8 pairs. Light: 8 of 9 native onsets paired, re-paired by hand (§6) |
| `bash .githooks/pre-commit` | `✓ pre-commit passed` before the review round's commits and before this update |

## 11. Owner on device

- [ ] Haptics on drag (Q3): one selection click per segment crossed, none on a tap, a release or an app change.
- [ ] The native scope bar on an iPhone and an iPad (iOS 26+): shown while the search is active, a tap selects and puts the keyboard away; an iPhone Pro Max in landscape.
- [ ] The Flutter control with "Flutter liquid" forced, light and dark: the clear lens, no grey flash at the start or end of a press, the wide flat landing of a long tap, a short tap to the left (§4).
- [ ] No hitch on the first press after launch, in a release build: it could not be measured on a simulator, and no warm-up ships.
- [ ] A short tap to the left and to the right (tall against wide), and the squeezed page under a held lens.
