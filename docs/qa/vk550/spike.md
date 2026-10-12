# VK-550 spike: the native scope bar and `UISegmentedControl`, measured

- **Date:** 2026-10-12. Xcode 27.0, simctl, `idb` 1.x for touches.
- **Simulators** (created for this spike, deleted at its end):
  `vk550-iphone265` (iPhone 17 Pro, iOS 26.5, 402 × 874 pt @3x),
  `vk550-ipad265` (iPad Pro 11-inch (M5), iOS 26.5, 834 × 1210 pt @2x),
  `vk550-iphone27` (iPhone 17 Pro, iOS 27.0), `vk550-ipad27` (iPad Pro
  11-inch (M5), iOS 27.0).
- **Subject.** A pure-UIKit probe app (`SegFid`), outside the repository:
  - `-mode seg`: five `UISegmentedControl`s (intrinsic "All | Songs | Places",
    full width 3, 2 and 5 segments, disabled) plus two intrinsic ones
    ("A | B | C", "All | Recently played") over a plain or striped page;
  - `-mode search`: `UITabBarController(tabs:)` with Home, Library and a
    `UISearchTab` whose root's `navigationItem.searchController` has
    `scopeButtonTitles = ["All", "Songs", "Places"]`, configured as the
    shell's search tab is (`SearchMath.style`: iPhone `.automatic` placement
    and `.inline` title, iOS 27 prominent search tab; iPad `.stacked`,
    `hidesSearchBarWhenScrolling = false`), `automaticallyActivatesSearch =
    false`.
  - The probe dumps the view and layer tree (frames, corner radii, fills,
    fonts) and traces every layer's presentation frame and the lens's
    `opacityPair` amount on each `CADisplayLink` tick, with every `UITouch`,
    `valueChanged` and `selectedScopeButtonIndexDidChange` timestamped.
- **Clean room.** The only private names below come from the runtime dump of
  Apple's own views. No other package's glass code was opened.
- **Load.** The host ran at load average 200–800 during the spike (other
  agents). Two early `idb` runs lost or merged touches and are discarded; the
  numbers below come from the clean run (every touch delivered within 25 ms).
- **Evidence** (images, the probe source, the per-frame trace) is outside the
  repository: vankhan `.superpowers/sdd/vk550-spike/`.

## 1. Q1: the native scope bar in the shell's search tab

| Setup | iPhone 26.5 | iPhone 27.0 | iPad 26.5 (stacked) | iPad 27.0 (stacked) |
|---|---|---|---|---|
| Default (`scopeBarActivation = .automatic`), search active (programmatic or a real tap on the field) | **Not shown** (no `UISegmentedControl` in the tree) | **Not shown** | In the tree (y 91, alpha −3.4), **not drawn** | In the tree, **not drawn** |
| `.onSearchActivation` | Shown at the top, y 64 | **Not shown** after a real tap (alpha 0) | Shown under the field | Shown under the field |
| `showsScopeBar = true` from launch | Shown at the top even while inactive | Shown at the top | Shown under the field even while inactive | Same |
| `.manual` + `setShowsScope(true)` in `willPresentSearchController`, `false` in `willDismiss` (**chosen**) | **Shown while active**, light and dark | **Shown while active** | **Shown while active** | **Shown while active**, light and dark |

Placement with the chosen setup:

| Device | Field | Scope bar (`UISegmentedControl` frame) | Look |
|---|---|---|---|
| iPhone 26.5 | bottom, above the keyboard | 16, 64, 370 × 32: under the status bar; the large title is gone | UIKit's bar band behind it (not glass); 13 pt labels |
| iPhone 27.0 | bottom | 16, 62, 370 × **36** | glass capsule track; 15 pt labels |
| iPad 26.5 | rises to y 38 | 204, 93, **426** × 32, centred under the field | glass capsule track |
| iPad 27.0 | rises to y 32 | 150, 86, **534** × 36, centred under the field | glass capsule track |

Against the owner's Apple Music videos (`vk407/frames`): Music shows its
"Apple Music | Library" scope **at the top of the screen on iPhone** while the
field sits at the bottom, and **under the field on iPad**. The chosen setup
reproduces both. Settings has no scope bar.

Bridge behaviour:

- A user tap on a scope calls `searchBar(_:selectedScopeButtonIndexDidChange:)`
  once, at touch-up. A drag across scopes calls it once, at release.
- A programmatic `selectedScopeButtonIndex = 2` does **not** call the
  delegate (26.5 and 27.0). The bridge is one-way safe by construction; it
  still dedupes.
- Tapping a scope keeps the search active and the keyboard up.

**Verdict:** use the native scope bar on iOS 26+ native chrome, with
`.manual` activation toggled by the search controller's delegate. The default
`.automatic` is unusable (never drawn on any of the four). See spec
2026-10-12 §3, §10.

## 2. `UISegmentedControl` (iOS 26.5, standalone), the Flutter reference

Identical on iOS 27.0 (frames and rest colours) and on iPad 26.5 (height).

| Item | Native |
|---|---|
| Height | **32**, capsule (radius 16, continuous) |
| Full width | the layout margins (16 iPhone, 20 iPad); segments equal: 370 → 123 / 123 / 124 |
| Intrinsic width | equal segments, each ≈ widest **Medium** label + 18–19, min 32: "Places" 41 → 59 (×3 = 177); "Recently played" ≈ 97.7 → 117 (×2 = 234); "A" → 32 (×3 = 96) |
| Thumb at rest (`_UILiquidLensView`) | inset **2** on every side: (segment − 4) × **28**, radius 14 |
| Track fill | light rgb 238/238/239 over white (≈ #767680 @ 0.12); dark 28/28/31 over black (≈ #767680 @ 0.24) |
| Thumb fill | light #FFFFFF; dark #EBEBF5 @ 0.30 (90/90/95 over the dark track); no shadow |
| Labels | SF 13: **Regular** unselected, **Medium** selected; label colour (black / white); line box 15.67, centred (top 8.33) |
| Disabled | the whole control at alpha **0.5** (light track 246, labels grey) |
| No glow, no bulge | no `LittleGlowView` in the tree; the control's own layer never scales |
| Under the engaged lens | labels drawn Medium (`ContentLensingView`); magnification 1.0 (§4) |

## 3. Motion (iPhone 26.5, full width 3 segments, 123 pt pitch; times from `valueChanged` for taps, from touch-down for presses)

| Gesture | Native |
|---|---|
| Tap commit | `valueChanged` at **touch-up** |
| Tap slide | x on **ζ 0.87, response 0.41 s, 8 ms** after the commit (least squares over 1.2 s, three taps: 1→2, 2→3, 3→1; rms 0.9 / 1.0 / 1.6 pt) |
| Tap engage | `opacityPair` 0 → 1 within ≈ 50 ms of the commit, holds to ≈ +0.30 s, ≈ 0 by +0.60 s |
| Tap shape, one segment | lens peaks ≈ 136–160 × 37–39 (w ×1.14–1.34, h ×1.33–1.40), lands with **2.5 pt** overshoot, then wobbles: w ×0.91, h ×1.11 at ≈ +0.68 s, settled ≈ +0.85 s |
| Tap shape, two segments | h peaks **50.0** (×1.79) at ≈ +0.32 s, w 116–132; overshoot **4.9 pt**; wobble w ×1.14, h ×0.83 at ≈ +0.58 s; settled ≈ +0.88 s |
| Press | lens grows by **+24 × +16** (119 × 28 → 143 × 44; two segments 181 → ≈ 205): critically damped, response **0.25 s**, **24 ms** delay (rms 0.08 pt); engage 0 → 1 in ≈ 50 ms |
| Release in place | back to rest: ζ 1.0, response **0.24 s**, 16 ms delay; engage ≈ 0.6 at +0.10 s, 0 by +0.30 s |
| Drag | the pressed lens follows the finger in x; lag **6.77 pt at 82.2 pt/s**: the VK-503 `dragFollow` spring (ζ 0.75, 0.33 s) predicts 6.45 pt (−5 %) |
| Fast drag | the lens squashes with speed: h up to 49.7 (×1.13 of pressed), w −12 % at ≈ 800 pt/s |
| Drag release | commits the segment under the lens at **release**; 2–4 pt overshoot, then the wobble |
| Programmatic `selectedSegmentIndex` | **animated** slide, no engage, no resize: ζ 0.82, response 0.41 s (rms 0.67 pt). Does not send `valueChanged` |
| Haptics | no feedback-generator call seen on the simulator (as VK-503 research §4.4) |

## 4. Measured in Task 1

- **Setup.** Same probe (rebuilt from `segfid_probe_main.swift`), a fresh
  `vk550-t1-iphone265` (iPhone 17 Pro, iOS 26.5 23F77, deleted afterwards),
  `-mode seg -bg plain` unless noted, the same `idb` gestures. The host ran at
  load average 300–450; runs with a touch delivered more than 30 ms late are
  discarded (two taps of the first light run). Every number below is in
  `docs/qa/vk550/native_reference.json`, which merges the spike's rows with
  these.
- **Light tap 1 → 2, re-captured.** The spike's row had `valueChanged`
  160 ms after touch-up (other taps: 4–16 ms), a main-thread stall. Its x
  matches, but its size and engage do not reproduce: four clean repeats
  (two light, two dark) agree with each other, not with it. The fixture's
  `tap_1_2` is the Task 1 re-capture: peak w 159.2 (×1.34) at +0.25 s,
  h 39.2 (×1.40) at +0.15 s, overshoot 2.44 pt, engage ≥ 0.99 from +0.10 to
  +0.35 s. The spike's tap fit (x only) stands.

| Item | Native |
|---|---|
| Dark rest | track 28/28/31 over black, thumb 90/90/95 (the spike's values) |
| Dark tap 1 → 2 | as light: x on the same path (repeats, light or dark, differ by up to 8 pt at +0.05 s, under 1 pt from +0.35 s); peak w 156.2 (×1.31), h 39.1 (×1.40); overshoot 2.50 pt; engage ≥ 0.99 +0.05 to +0.30 s |
| Dark press | as light: 119 × 28 → 143 × 44 by +0.30 s (+0.067 s: 126.1 × 32.8 dark, 125.2 × 32.1 light) |
| Five segments, tap 1 → 3 (74 pt pitch, 148 pt) | x 37 → 185; overshoot **2.19 pt**; peak w 103.9 (×1.48), h 38.9 (×1.39); settled ≈ +0.85 s. The lift follows the distance, not the segment count (3 segments, 246 pt: h ×1.79) |
| Flick landing (3 → 1, released at +0.55 s) | lands on the finger's segment (61.5), overshoots to 57.64: **3.86 pt** at +0.83 s from the down; at rest ≈ +1.13 s |
| RTL (`-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`) | **segment 0 at the right**: "All" at x 316, its thumb 248, 2, 120 × 28 (control-local); a tap at the left commits index 2 |
| Tap on the selected segment | **no `valueChanged`**; the lens grows in place to ≈ 143 × 44 (engage 1) and is back at rest by ≈ +0.50 s |
| Held press on an unselected segment (2.16 s) | **the lens does not move or grow before the release** (no lens frame changes); the pressed segment's label fades to opacity **0.20** over ≈ 0.45 s. At the up: `valueChanged`, then the tap slide |
| Label magnification under the held lens | **1.0**: the label's ink box is 43 × 29 px at rest and under the lens; every `UISegmentLabel` and `ContentLensingView` layer keeps scale 1.00. The lens content is two portals at rest size; `ContentLensingView` carries `displacementMap.inputAmount` 0 → −11 with the press |
| Refracting ring (held lens over `-bg grid`) | grid-line contrast is back to the interior level **8.3 pt** below the top edge and **9.0 pt** above the bottom one (fixture `bezel` 8.7); chromatic fringing spans 7.3 / 7.7 pt. Inside, the backdrop is pulled toward the centre (≈ 0.5 pt across, ≈ 1 pt vertically at mid-height, up to 1.5–2.6 pt near the rim) |

Still not measured: accessibility text sizes, iOS 27 motion, the engaged
lens's colours in dark, and a spring fit of the lens after a drag release
(the release starts with the lens moving; the fixture keeps the rows).
