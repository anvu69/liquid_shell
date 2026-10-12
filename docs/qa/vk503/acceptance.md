# VK-503 acceptance: tab bar fidelity, traces and strips

## 1. Run

- **Date:** 2026-10-12.
- **Simulators:** iPhone 17 Pro, iOS 26.5 (23F77), created and deleted by each script (`vk503-tabfid`, `vk348-compare-*`), plus the idb runs' own simulators. Android: an API 36 Pixel 9 emulator, created and deleted for `make compare-images`. Xcode 27, Flutter 3.44.6 (fvm).
- **Code:** `VK-503-tab-fidelity`.
  - Traces at 7564af9, after the flick fix.
  - Tool strips and compare images at 4ad207e. The only change between the two is the colour scenes, which moved to traces-only mode.
  - The dark idb strips at 14e8542, the dark lens falloff.
  - Verification at 14e8542.
- **Native reference:** `docs/qa/vk503/native_reference.json`. It holds the research's fits and per-frame UIKit layer traces (pure `UITabBarController`, iOS 26.5), plus native pixels from the example's own frame strips. Every row below says its kind:
  - **native**: independent native data, and the model can fail it;
  - **native, constant**: native data, but Flutter sets the value from a constant;
  - **fit**: Flutter against a fitted spring.

## 2. `make tab-traces`

| check | kind | result | detail |
|---|---|---|---|
| pill3[0] | native | pass | 64.000 vs 64.000 (±1.000) |
| pill3[1] | native | pass | 791.000 vs 791.000 (±1.000) |
| pill3[2] | native | pass | 274.000 vs 274.000 (±1.000) |
| pill3[3] | native | pass | 62.000 vs 62.000 (±1.000) |
| minimized[0] | native | pass | 28.000 vs 28.000 (±1.000) |
| minimized[1] | native | pass | 798.000 vs 798.000 (±1.000) |
| minimized[2] | native | pass | 48.000 vs 48.000 (±1.000) |
| minimized[3] | native | pass | 48.000 vs 48.000 (±1.000) |
| tap_1_2 settle | fit | pass | 0.467 vs 0.467 (±0.047) |
| tap_1_2 overshoot | fit | pass | 1.492 vs 1.492 (±1.000) |
| tap_1_2 delay | fit | pass | 0.025 vs 0.025 (±0.017) |
| tap_2_3 settle | fit | pass | 0.467 vs 0.467 (±0.047) |
| tap_2_3 overshoot | fit | pass | 1.492 vs 1.492 (±1.000) |
| tap_2_3 delay | fit | pass | 0.025 vs 0.025 (±0.017) |
| tap_3_1 settle | fit | pass | 0.517 vs 0.517 (±0.052) |
| tap_3_1 overshoot | fit | pass | 2.985 vs 2.985 (±1.000) |
| tap_3_1 delay | fit | pass | 0.025 vs 0.025 (±0.017) |
| tap_held no brake | fit | pass | 0 speed dips |
| slot0 rect | native | pass | 68.0, 795.0, 94.0, 54.0 vs 68, 795, 94, 54 (±1.0) |
| slot1 rect | native | pass | 154.0, 795.0, 94.0, 54.0 vs 154, 795, 94, 54 (±1.0) |
| slot2 rect | native | pass | 240.0, 795.0, 94.0, 54.0 vs 240, 795, 94, 54 (±1.0) |
| one-slot lift | native | pass | 1.516 vs 1.550 (±0.155) |
| two-slot stretch | native | pass | 1.334 vs 1.330 (±0.133) |
| icon pop | native, constant | pass | 1.158 vs 1.160 (±0.020) |
| oneSlot w @69ms | native | pass | 99.534 vs 94.700 (±9.470) |
| oneSlot h @69ms | native | pass | 57.583 vs 59.200 (±5.920) |
| oneSlot w @165ms | native | pass | 88.935 vs 85.100 (±8.510) |
| oneSlot h @165ms | native | pass | 75.328 vs 78.300 (±7.830) |
| oneSlot w @198ms | native | pass | 86.145 vs 83.600 (±8.360) |
| oneSlot h @198ms | native | pass | 79.987 vs 80.600 (±8.060) |
| oneSlot w @265ms | native | pass | 88.121 vs 91.700 (±9.170) |
| oneSlot h @265ms | native | pass | 77.394 vs 77.800 (±7.780) |
| oneSlot w @298ms | native | pass | 90.244 vs 94.700 (±9.470) |
| oneSlot h @298ms | native | pass | 70.547 vs 70.800 (±7.080) |
| twoSlot w @68ms | native | pass | 99.405 vs 101.100 (±10.110) |
| twoSlot h @68ms | native | pass | 57.451 vs 57.700 (±5.770) |
| twoSlot w @149ms | native | pass | 117.117 vs 121.300 (±12.130) |
| twoSlot h @149ms | native | pass | 60.853 vs 55.600 (±5.560) |
| twoSlot w @182ms | native | pass | 122.079 vs 124.900 (±12.490) |
| twoSlot h @182ms | native | pass | 59.090 vs 54.700 (±5.470) |
| twoSlot w @249ms | native | pass | 116.916 vs 120.200 (±12.020) |
| twoSlot h @249ms | native | pass | 57.538 vs 61.200 (±6.120) |
| twoSlot w @282ms | native | pass | 108.124 vs 114.600 (±11.460) |
| twoSlot h @282ms | native | pass | 60.010 vs 66.000 (±6.600) |
| press w @33ms | native | pass | 94.464 vs 94.700 (±2.500) |
| press h @33ms | native | pass | 54.175 vs 54.700 (±2.500) |
| press w @67ms | native | pass | 99.275 vs 99.200 (±2.500) |
| press h @67ms | native | pass | 57.319 vs 59.300 (±2.500) |
| press w @100ms | native | pass | 103.145 vs 103.400 (±2.500) |
| press h @100ms | native | pass | 61.702 vs 63.600 (±2.500) |
| press w @133ms | native | pass | 105.651 vs 106.200 (±2.500) |
| press h @133ms | native | pass | 65.561 vs 66.600 (±2.500) |
| press w @200ms | native | pass | 108.275 vs 108.400 (±2.500) |
| press h @200ms | native | pass | 69.904 vs 69.700 (±2.500) |
| press w @250ms | native | pass | 109.129 vs 109.300 (±2.500) |
| press h @250ms | native | pass | 70.776 vs 70.700 (±2.500) |
| press scale @49ms | native | pass | 1.005 vs 1.007 (±0.005) |
| press scale @83ms | native | pass | 1.021 vs 1.023 (±0.005) |
| press scale @116ms | native | pass | 1.037 vs 1.038 (±0.005) |
| press scale @149ms | native | pass | 1.048 vs 1.049 (±0.005) |
| press glow @33ms | native | pass | 0.038 vs 0.059 (±0.050) |
| press glow @66ms | native | pass | 0.232 vs 0.225 (±0.050) |
| press glow @99ms | native | pass | 0.274 vs 0.273 (±0.050) |
| release w @+33ms | native | pass | 108.117 vs 109.500 (±2.500) |
| release h @+33ms | native | pass | 69.622 vs 69.500 (±2.500) |
| release engage @+33ms | native | pass | 1.000 vs 1.000 (±0.120) |
| release w @+67ms | native | pass | 102.783 vs 105.100 (±2.500) |
| release h @+67ms | native | pass | 66.260 vs 65.100 (±2.500) |
| release engage @+67ms | native | pass | 1.000 vs 1.000 (±0.120) |
| release w @+100ms | native | pass | 99.360 vs 100.700 (±2.500) |
| release h @+100ms | native | pass | 62.275 vs 60.700 (±2.500) |
| release engage @+100ms | native | pass | 1.000 vs 1.000 (±0.120) |
| release w @+133ms | native | pass | 97.270 vs 97.900 (±2.500) |
| release h @+133ms | native | pass | 58.865 vs 57.600 (±2.500) |
| release engage @+133ms | native | pass | 0.904 vs 0.930 (±0.120) |
| release w @+167ms | native | pass | 95.963 vs 96.300 (±2.500) |
| release h @+167ms | native | pass | 56.359 vs 55.700 (±2.500) |
| release engage @+167ms | native | pass | 0.531 vs 0.490 (±0.120) |
| ripple scale @+83ms | native | pass | 1.498 vs 1.540 (±0.154) |
| ripple opacity @+83ms | native | pass | 0.234 vs 0.233 (±0.030) |
| ripple scale @+149ms | native | pass | 2.384 vs 2.430 (±0.243) |
| ripple opacity @+149ms | native | pass | 0.151 vs 0.149 (±0.030) |
| ripple scale @+250ms | native | pass | 3.321 vs 3.340 (±0.334) |
| ripple opacity @+250ms | native | pass | 0.063 vs 0.063 (±0.030) |
| ripple scale @+316ms | native | pass | 3.639 vs 3.650 (±0.365) |
| ripple opacity @+316ms | native | pass | 0.034 vs 0.033 (±0.030) |
| drag lag | fit | pass | 7.089 vs 7.090 (±0.709) |
| flick lands under the finger | native | pass | 115.000 vs 115.000 (±0.500) |
| flick short of Home @+115ms | native | pass | 7.122 vs 5.100 (±6.000) |
| flick clear @+200ms | native | pass | 1.000 vs 1.000 (±0.050) |
| flick overshoot | native | pass | 0.000 vs 0.000 (±1.000) |
| collapse settle | fit | pass | 0.567 vs 0.600 (±0.060) |
| expand settle | fit | pass | 0.417 vs 0.400 (±0.040) |
| expand overshoot | native | pass | 3.973 vs 4.000 (±1.000) |
| colour lightFillPage | native | FAIL | 242/241/249 vs 242/240/254 (±4) |
| colour lightCapsule | native | pass | 235/235/235 vs 236/236/236 (±4) |
| colour lightLabel | native, constant | pass | 25/25/25 vs 25/25/25 (±4) |
| colour darkFill | native | pass | 25/25/25 vs 25/25/25 (±4) |
| colour darkCapsule | native | pass | 55/55/55 vs 58/58/58 (±4) |
| colour darkLabel | native, constant | pass | 244/244/244 vs 244/244/244 (±4) |
84 native, 3 native but constant, 13 against fitted springs
✗ 1 of 100 failed

The one failure is real, and it is a known gap:
- Over the example's page, the native light glass is bluer than ours (254 against 249). Native's material boosts the backdrop's colour (vibrancy). Ours mixes a neutral white tint at the 0.55 cap.
- Matching it would take a saturation of about 1.8 on every glass surface (the liquid tier constant is 1.1), and the light tint cap. Both are owner decisions (Q14, Q16).

## 3. Strips

The strips are in `vankhan/.superpowers/sdd/tab-strips-v2/`; native is on the left. Rows are 3 frames (50 ms) apart in `tool/` and `idb/`, and 2 frames in `extra/`.

| Strip | Matches | Differs |
|---|---|---|
| tool/frames_1–3 (taps) | The swell, the flight and the lift; gray on the same row as native | Flutter starts about 1 row later: the integration taps are instant |
| tool/frames_4 (press) | The lens size and the pill swell. The milky core with a clear, refracting rim that shows the page | The Flutter rim fringe runs all round; native's is strongest at the left end and the bottom |
| tool/frames_5 (slow drag) | The lens follows; the size | The native drag starts several rows later (XCUITest), so the lag cannot be judged from the strip |
| tool/frames_6 (flick) | It lands on Home with a clear, lifted lens, then turns gray | It lands earlier than native (the integration flick is faster) |
| tool/frames_7, 8 | none | The native example has no minimize: strip 7 is a scroll, strip 8 is invalid by design |
| idb/light_1–3, dark_1–3 (taps) | Motion in step with native row by row (tap 2→3); no lit pill in dark | In flight the Flutter lens is milky (a light-grey disc in dark), while native's flying lens is clearer than its held one |
| idb/light_4, dark_4 (press) | The milky core (light 250 against 244; dark 61 against 60), the clear ring, the fringe, the dark lens no longer a black disc | The ring is a little less busy (std 17 against 25); in dark the fringe is stronger (p99 85 against 64) |
| idb/*_5 (slow drag) | Follows; the lens look | The start differs by driver |
| idb/*_6 (flick) | Lands on Home, clear and lifted, no overshoot | About 2 to 4 rows before native: the example's native tab is a refused tap plus a programmatic select. Against the pure-UIKit trace it is within a frame |
| extra/search_open, search_close | The field and the bar on one clock; the field grows from and shrinks into the ⌕ | About 1 row of curve shape in rows 1–4 |

## 4. Accepted limits (Q14–Q21)

| Q | What the strips show |
|---|---|
| Q14 (material, no luma adaptation) | Matched by measurement at rest (within 3 luma). Native's glass carries the backdrop's hue: +6 blue in dark, and blue on the light page (row `colour lightFillPage`) |
| Q15 (circular, not continuous, corners) | Not visible at strip scale on a capsule |
| Q16 (no vibrancy on labels and icons) | The labels are solid #191919 / #F4F4F4 |
| Q17 (no SF Symbols) | The glyph shapes differ: Material filled against SF |
| Q18 (two-spring squash and stretch) | The tap shape is within ±10 % of native at 10 frames; the in-between frames differ by up to 6 pt |
| Q19 (platform views) | Not in these strips |
| Q20 (narrow iPad window, iOS 27) | Not captured |
| Q21 (iPad long-press customization) | Not built: a long press swells the lens |

## 5. Owner on device

- [ ] Haptics on drag (Q6): one selection click per slot crossed, none on a tap.
- [ ] The overall feel on a real iPhone and iPad, with "Flutter liquid" forced in the example: tap, hold, drag, flick, minimize and search.
- [ ] The engaged lens: a milky core, a clear rim with its fringe, and the dark lens.
- [ ] The landscape phone bar (44 pt, the 128.8 pt pocket).
- [ ] Decide the light glass blue and vibrancy gap (section 2) and the dark tint's reach (#1C1C1C @ 0.90 on every dark glass surface).
