# liquid_shell: tab bar fidelity, the Flutter liquid tab bar matched to iOS 26 native

- **Plane:** VK-503
- **Date:** 2026-10-11
- **Status:** draft for the owner. The owner approves this spec and the plan `docs/plans/2026-10-11-tab-fidelity.md` together. Open choices are in the last section, "Quyết định cần chủ sản phẩm xác nhận". Every row has a recommended default, and if the owner says nothing the default applies.
- **Branch:** `VK-503-tab-fidelity`, from `main` at `6c8414d`. Main already has P2 (native iOS chrome), P3a (native alerts), the liquid tier (VK-348, the clean-room shader `liquid_glass.frag`) and P3b-1 (the search tab, VK-407).
- **Floor:** Flutter ≥ 3.44.0 / Dart ^3.12.0 (fvm pins 3.44.6), iOS deployment target 15.0, Android `flutter.minSdkVersion`, `very_good_analysis` 10.3.0. There are no new runtime dependencies.
- **Owner input (binding),** verbatim:

  > Ở chế độ flutter liquid thì vẫn là tab méo và xấu, đã làm được background xuyên qua, nhưng không có hiệu ứng vuốt trên tab, tab active cũng không có hiệu ứng. Chúng ta cần làm đến mức giả lập giống 100% với native.

- **Standing owner direction** (`ls-liquid-decisions.md`, L1–L6): liquid glass everywhere. Flutter draws liquid on iOS < 26 and on Android. Every glass surface goes through `LiquidGlass` (L3). Acceptance is side by side against iOS 26 native (L5).
- **Sources:**
  - vankhan `.superpowers/sdd/tabfid-research.md` and `tabfid-shots/`. These are per-frame layer traces of a pure-UIKit `UITabBarController` on iPhone 17 Pro (iOS 26.5 and 27.0) and iPad Pro 11" (iOS 26.5), with least-squares spring fits, plus 60 fps video strips. Cited as "research §n". Every number in this spec comes from there unless it is marked **(assumption)**.
  - The liquid tier spec `docs/specs/2026-10-10-liquid-tier-design.md`: the shader model (§4), the renderer and `RenderLiquidBackdrop` (§5), the tiers (§6), and the items it deferred, which are in its Q15 row and its §2.2 non-goals. The brief calls that list "B15"; the spec itself has no row named B15. Of that list, this spec takes in the moving selection lens, the press glow and flex, and the materialize-like engage of the lens. Device-motion light and adaptive tint stay deferred (§19). Continuous corners become the subject of Q15.
  - The P1 spec `docs/specs/2026-10-08-p1-foundation-design.md`: §5.3 geometry, §5.5 selection and the guard, §5.7 minimise on scroll, §5.10 accessibility.
  - The P3b spec `docs/specs/2026-10-10-p3b-search-tab-design.md`, §9.2: the compact search morph.
  - The code at `6c8414d`: `lib/src/chrome/tab_bar.dart`, `lib/src/glass/*`, `lib/src/search/search_layout.dart`, `lib/src/search/search_chrome.dart` and `lib/src/shell/liquid_shell.dart`.
- **Clean room.** No other package's liquid glass source was opened, for this spec or for the research. Apple's private class names (`_UILiquidLensView`, `ClearGlassView`, `LittleGlowView`, `DestOutView`) appear only because they come from the runtime dump of Apple's own views.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Vì sao tab "méo":** viên tab của mình co theo chữ (3 tab rộng 178pt), còn native cố định mỗi ô 86pt (rộng 274pt). Ô đang chọn của mình là quả trứng màu tím 47×54; native là viên xám 94×54 phủ kín ô. Icon của mình là icon viền 28pt; native là icon đặc ~24pt. Viền trắng và bóng đổ của mình đậm gấp đôi native.
> - **Sửa hình học:** viên tab theo đúng công thức native (`16 + 86·n`, lề 21, đệm 4, ô chọn `(p+8)×54`). Khi có nút ⌕ hoặc nút phụ, viên tab bám trái và nút tròn bám phải, không căn giữa cả cụm. Có thêm bản ngang 44pt cho iPhone xoay ngang và thanh trên cùng 48pt chỉ có chữ cho iPad.
> - **Thấu kính đang chọn:** khi đứng yên là viên xám như native. Khi chạm, giữ hoặc kéo thì nó hoá thành **thấu kính kính trong**, là lượt shader thứ hai của `liquid_glass.frag`, đọc đúng nền trang phía sau (không đọc viên tab). Thấu kính phồng ×1.17/×1.30, có viền cầu vồng ở mép và bóng nhẹ. Icon nằm dưới thấu kính đổi sang màu nhấn và phóng ×1.16. Khi thấu kính nằm giữa hai icon thì mỗi icon nửa xanh nửa đen, đúng như native.
> - **Chuyển động:** dùng đúng các lò xo đã đo, gồm chạm (ζ 0.79, 0.39 s), kéo theo ngón (ζ 0.75, 0.33 s) và thả về ô gần nhất (ζ 0.92, 0.35 s). Cả viên tab phình ×1.052 khi giữ. Có quầng sáng 93pt dưới ngón tay, khi thả thì loang ra ×4 rồi tắt. Icon đích nảy ×1.16. Tab được chọn **khi thả tay**, như native.
> - **Thu nhỏ khi cuộn:** viên tab co thành hình tròn 48pt ở lề trái, chỉ còn icon và huy hiệu. Nút ⌕ co từ 62 xuống 48 quanh tâm của nó. Chạm vào thì nở lại.
> - **Tab Tìm (P3b-1):** khi chọn Tìm, viên tab co bằng đúng phép thu nhỏ ở trên (một hình kính duy nhất), không còn mờ đi rồi hiện một nút tròn khác. Kéo thấu kính sang nút ⌕ thì ⌕ sáng lên và thả tay sẽ chọn Tìm.
> - **Không làm được 100%** (vật liệu riêng của Apple, kính tự đổi theo độ sáng nền, SF Symbols trên Android, rung, dải mờ cuối màn hình, nền platform view): mỗi mục đều có phương án gần nhất trong bảng câu hỏi.
> - **Nghiệm thu bằng số:** hình học sai ≤ ±1pt; thời gian ổn định lò xo sai ≤ ±10%; độ phồng, độ nảy và quầng sáng sai ≤ ±10%. Có quay video 60 fps native và Flutter đặt cạnh nhau từng khung hình, golden cho trạng thái tĩnh, và widget test cho cử chỉ và lò xo.
> - 22 câu hỏi có đề xuất mặc định ở bảng cuối.

---

## 1. Goal

When the Flutter liquid tab bar sits next to the iOS 26.5 native glass tab bar on the same simulator, with the same app, theme and destinations, it should be indistinguishable at rest and in motion within the numeric tolerances of §17. The only exceptions are the items the owner accepts in the Q table (the §8 limits of the research).

The bar has five parts:

1. **Native geometry.** This covers the compact portrait pill with the separate ⌕ or trailing circle, the compact landscape pill, and the regular-width (iPad) top pill. The sidebar is covered only where native has an equivalent (§12.3).
2. **The selected lens.** At rest it is a neutral capsule fill. When engaged it is a second pass of `liquid_glass.frag` that reads the page behind the bar.
3. **Interaction:**
   - tap, press-and-hold, and drag with snap-on-release, all on the fitted springs;
   - squash and stretch;
   - pill bulge;
   - highlight;
   - finger glow and ripple;
   - icon pop and magnification;
   - icon tint inside the lens by mask;
   - haptics.
4. **The minimize morph.** The bar collapses to a 48 pt icon-only circle and expands back, and the search tab's compact morph reuses it.
5. **Fallbacks:**
   - light and dark;
   - RTL;
   - reduce motion;
   - reduce transparency and increase contrast;
   - the frosted and solid tiers;
   - text scale and accessibility (AX) sizes.

## 2. Scope

### 2.1 In this item

| # | Item | Section |
|---|---|---|
| F1 | Pure geometry for the three forms (compact, landscape, top), the minimized circle, badges and the trailing circle | §5 |
| F2 | Rest appearance: icon and label metrics and colours, the selection fill, the material defaults (rim, shadow, pill dispersion) | §6 |
| F3 | `LiquidLens`, the selected lens as a second glass pass, tier-aware | §7 |
| F4 | The lens motion model: fitted springs, the state machine, squash and stretch, and the effects | §8 |
| F5 | The gesture recognizer, commit on release, the guard, programmatic changes, semantics, and the AX large content viewer | §8.6–§8.9 |
| F6 | Haptics | §9 |
| F7 | The minimize morph | §10 |
| F8 | The compact search morph from P3b-1, rebuilt on F1 and F7, including drag into ⌕ | §11 |
| F9 | Compact landscape (Q8), the iPad regular top bar (Q9), and the sidebar tokens | §12 |
| F10 | Accessibility and tier fallbacks | §13 |
| F11 | The icon strategy: API contract, docs and example icons | §14 |
| F12 | The scroll-edge pocket approximation (Q13) | §15 |
| F13 | Acceptance tooling: Flutter motion traces, the native reference fixture, 60 fps frame strips, numeric comparison | §17 |
| F14 | Docs, CHANGELOG ×4, version `0.1.0-dev.6` | §18 |

### 2.2 Non-goals

- **Native chrome.** iOS 26+ with native chrome engaged already *is* the reference. Nothing in `liquid_shell_ios` changes.
- **An iOS 27 look.** On iOS 27 native has a hairline rim, no shadow, a 0.32 s tap spring, a horizontal-only stretch, and on iPhone a Search tab inside the bar. The Flutter bar imitates 26.5 (Q3). A later item can add a 27 style.
- **iPad long-press tab customization** (research §1.3). This is a system editor, not chrome (Q21).
- **Device-motion light and luma-adaptive tint.** Both stay deferred from the liquid tier (Q14).
- **Rasterized SF Symbols** through the native channel on iOS < 26 (Q2). They would need a separate issue.
- **The sidebar's own selection style.** It was not measured in the research (§12.3, Q10).

## 3. Reference behaviour (summary of the research)

| Topic | Native iOS 26.5 | Research |
|---|---|---|
| Pill | 62 tall, capsule, bottom edge 21 above the screen bottom, side margin 21, `W = min(16 + 86·n, available)`, inner inset 4 | §1.1 |
| Slot | pitch `p = (W − 16)/n`, selection and hit capsule `(p + 8) × 54` at `x = 4 + i·p` (neighbours overlap 8) | §1.1 |
| Icon | filled glyph in a ≈ 33 × 28 frame whose top is 10 below the pill top | §1.1 |
| Label | 10 pt, Semibold selected / Medium otherwise, no tracking, 12 tall box at 39 below the pill top | §1.1 |
| Colours | selected = tint; unselected ≈ #191919 (light) / #F4F4F4 (dark) | §1.1 |
| Selection at rest | gray capsule: #ECECEC over the light pill, #3A3A3A over the dark pill, no rim, no shadow | §2 |
| Tinted icons | a tint-coloured Semibold copy of the whole row, masked to the lens; the normal copy has the lens punched out | §2 |
| Tap | lens slides (25 ms delay, ζ 0.79, 0.39 s), goes clear while moving, lifts (one slot) or stretches (two slots), pill bulges ×1.02, highlight to 0.7, finger glow ripples ×4, target icon pops ×1.16 | §3 |
| Press | lens 94×54 → 110×70, pill ×1.052, refraction on, highlight 0.845, glow 0.28 at 93 pt, icons under lens ×1.16 | §4.1 |
| Drag | lens follows x only (ζ 0.75, 0.33 s), clamped to the pill's slots, never enters ⌕; ⌕ highlights and becomes the release target | §4.2 |
| Release | commits the slot nearest the lens centre, snap spring ζ 0.92, 0.35 s | §4.3 |
| Haptics | not observable on the simulator | §4.4 |
| Material | near-opaque milky fill, almost no rim (light), soft shadow `black 7 %, (0, 3), blur 20`; dispersion only on the active lens | §5 |
| Minimize | after ≈ 0.24 s of scroll, collapses over ≈ 0.30 s to a 48 × 48 circle at start + 7 with a ×0.96 dip; ⌕ 62 → 48 about its centre; expand by tap in ≈ 0.35 s with small overshoot; a reverse scroll did not expand | §6 |
| Landscape | 44 pill, 36 items, inline icon + 12 pt label, content-sized (label + 49), 4 pt gaps | §1.2 |
| iPad regular | 48 top pill, 40 items, label only, 17 pt, padding 15.5, ⌕ a 48.5 icon item inside the pill | §1.3 |

## 4. Architecture

```
lib/src/chrome/
  tab_geometry.dart     pure: TabMetrics, TabBarGeometry, compact/landscape/top builders
  tab_springs.dart      pure: fittedSpring, TabSprings, SpringValue (1 ms integrator)
  lens_motion.dart      pure: LensMotion state machine → LensFrame per tick
  lens_gesture.dart     LensGestureRecognizer (claims on down; deferred at AX sizes)
  glass_tab_bar.dart    GlassTabBar: internal widget, Ticker → LensMotion → paint
  tab_bar.dart          LiquidTabBar (public, unchanged constructor) → GlassTabBar
lib/src/glass/
  scroll_pocket.dart    ScrollEdgePocket (Q13; seam rule: filters live here)
  liquid_lens.dart      LiquidLens: second glass pass, per tier (seam rule: filters live here)
  liquid_glass.dart     + resolveGlassFor(context) shared by LiquidGlass and LiquidLens
  liquid_optics.dart    + LiquidOpticsParams.bezel / rimWidth overrides
  glass_theme.dart      + selectionFill, tabForeground, badgeColor, tabIconSize; new defaults
```

- **Pure Dart first.** Geometry and motion are pure functions and classes with no `BuildContext`. They are unit-tested to the numbers in §5 and §8, so the springs can be checked against the research without a device.
- **One ticker.** `GlassTabBar` owns a `Ticker` that runs only while `LensMotion.advance` reports motion. At rest the bar costs what it costs today: one glass pass and no ticker.
- **Public API.** `LiquidTabBar`'s constructor does not change. The shell uses the internal `GlassTabBar` directly for the extra wiring it needs (the guard result, the search ⌕ target, the collapsed tap). The new public surface is four `LiquidGlassTheme` fields (§6.4) and `LiquidShellBreakpoints.compactHeight` (§12.1).
- **Seam.** The lens is drawn by `LiquidLens` in `lib/src/glass/`, so `tool/check_glass_seam.sh` stays green. Every glass shape (pill, lens, circles) is a `LiquidGlass` or a `LiquidLens`.

## 5. Geometry (F1)

All values are logical points. "Bar-local" means the `GlassTabBar` box, whose width is what the shell gives it (the row between its margins) and whose height is the pill extent. `TabBarGeometry` lists slots in **destination order**. In RTL their x positions are mirrored, so slot 0 is at the right.

### 5.1 Compact portrait

| Quantity | Formula / value |
|---|---|
| Row margin | **21** at each side (was 16). Narrow shells (`w < kLiquidNarrowWidth`, 340) keep **8** (P1 Q17) |
| Pill extent `E` | 62 at text scale 1; `62 + max(0, labelLineHeight − 12)` above it (the label grows, the icon frame does not) |
| Available for the pill | `A = width − (trailing ? E + 8 : 0)` |
| Pill width | `W = min(16 + 86·n, A)`; with an unbounded width, `W = 16 + 86·n` |
| Pill x | trailing present: `0` (start-pinned); otherwise centred `(width − W)/2` |
| Pitch | `p = (W − 16)/n` |
| Slot `i` (visual) | `Rect(pill.left + 4 + i·p, 4, p + 8, E − 8)` |
| Trailing circle | `E × E` at `width − E` (end-pinned), gap ≥ 8 |
| Minimized circle | `48 × 48` at `(7, (E − 48)/2)` from the row start |
| Minimized trailing | `48 × 48` with the same centre as the trailing circle |
| Icon frame | `33 × 28`, top at `10`, centred in the slot |
| Label box | top at `39`, `12` tall at scale 1, centred in the slot, width `p + 8 − 8` |
| Badge | count: red capsule, height **21.33**, radius 10.67, min width 21.33, text 12 pt w500 white, origin at `(iconFrame.right − 4, iconFrame.top − 4)`, mirrored in RTL; dot: the same capsule without text (as native draws an empty badge) |

Worked checks against research §1.1, on a 402 pt screen:

- 3 tabs, no trailing: `W = 274`, x = 64 on screen, slots at 68 / 154 / 240 (94 wide).
- 4 tabs + ⌕: `A = 360 − 70 = 290`, so `W = 290` and `p = 68.5`. The research reads 68.67, a 0.17 difference inside the ±1 tolerance.
- 5 tabs: `W = 360`.
- Narrow, 320 pt with 5 tabs and a trailing circle (margin 8): `W = 234`, pitch 43.6. Each hit capsule is `p + 8 = 51.6` wide, because native capsules overlap, so every tab keeps a ≥ 44 pt target (P1 Q17).
- Minimized: x = 21 + 7 = **28** on screen.

### 5.2 Compact landscape (Q8)

| Quantity | Value |
|---|---|
| When | the shell is compact by width, or it is landscape with height below `compactHeight` (§12.1) |
| Pill | **44** tall, radius 22, row margin **38**, bottom gap 20 (`bottomGapFor` keeps 21 on iOS: the difference is 1, inside tolerance) |
| Items | **36** tall, inset 4, **4** gaps, width `labelWidth + 49`, icon at `x + 6`, label after it |
| Label | **12** pt, w600 selected / w400 otherwise |
| Trailing / ⌕ | `44 × 44`, gap 8, end-pinned |
| Minimized | `44 × 44` at the row start **(assumption: not captured)** |

### 5.3 Regular top bar (iPad, Q9)

| Quantity | Value |
|---|---|
| Pill | **48** tall, radius 24, centred, top at `padding.top + 5.5` (research: y = 29.5 under a 24 pt status bar) |
| Items | **40** tall, radius 20, inset 4, no gap, **label only**, 17 pt, w600 selected / w500 otherwise, horizontal padding **15.5** (`width = label + 31`) |
| Search destination | an icon-only item **48.5** wide inside the pill |
| Trailing action | `48 × 48` circle, gap 8, after the pill (unchanged rule) |
| Lens on tap | inflates to ≈ **105 × 55** from 78.5 × 40 (×1.34 w, ×1.375 h) |
| AX sizes | the icon replaces the label (P1 §5.10 rule), and the large content viewer shows on a long press |

### 5.4 Hit testing

The bar's box is the whole row. Only the pill (or the minimized circle) and the trailing circle take touches. The gaps between them, and the margins, pass touches to the body. The gesture layer covers the pill rect inflated by 0 at rest. While the minimize morph runs, it covers the current animated rect.

## 6. Rest appearance (F2)

### 6.1 Cells

- **Icon.** Every slot draws `selectedIcon ?? icon`, whether or not it is selected, because native draws filled glyphs in every slot (Q1). Size: `LiquidGlassTheme.tabIconSize`, default **26**. Material Symbols' optical box at 26 is ≈ 21.7 pt, against SF's 21.3–24 pt. The icon is centred in the 33 × 28 frame.
- **Label.** `LiquidGlassTheme.labelStyle` with a new default: `TextStyle(fontSize: 10, height: 1.2, fontWeight: w500, letterSpacing: 0)`. The bar applies w600 to the tinted (selected) copy. On iOS the platform font is SF Pro; elsewhere it is the theme's font.
- **Colours.**
  - Unselected: `LiquidGlassTheme.tabForeground`. The default is the measured **#191919** (light) / **#F4F4F4** (dark) (Q4).
  - Selected (the tinted copy): `ColorScheme.primary`, the same colour P2 passes to native as `tintArgb`, so native and Flutter use the same tint in the same app.
- **No ink.** There is no `InkWell` and no splash. Feedback is the lens.

### 6.2 The selection at rest

- One capsule at the lens rect, filled with `LiquidGlassTheme.selectionFill`, drawn above the pill glass and under the row.
- Light default `Color(0x14000000)`: over the milky pill this gives #ECECEC.
- Dark default `Color(0x21FFFFFF)`: over the dark pill this gives #3A3A3A.
- No rim, no shadow, no tint colour.

### 6.3 The two copies of the row (mask)

1. **The normal copy.** Icons in `tabForeground` with w500 labels. It is clipped to the pill *minus* the lens rrect (`Path.combine(difference)`).
2. **The tinted copy.** Icons in `primary` with w600 labels. It is clipped *to* the lens rrect and scaled by `magnify = 1 + 0.16·engage` about the lens centre. The popping slot is additionally scaled by `popScale`.

While the lens straddles two slots, each icon is half tinted and half plain (research `native265_slowdrag.png`). The mask gives this for free.

### 6.4 Theme changes (Q5)

`LiquidGlassTheme` gains four fields. Each has `copyWith`, `lerp`, `==` and `hashCode`, and `fromColorScheme` sets its default.

| Field | Type | Light | Dark | Meaning |
|---|---|---|---|---|
| `selectionFill` | `Color` | `0x14000000` | `0x21FFFFFF` | The lens at rest (§6.2) |
| `tabForeground` | `Color` | `0xFF191919` | `0xFFF4F4F4` | Unselected icons and labels in the bar |
| `badgeColor` | `Color` | `0xFFFF383C` | `0xFFFF4245` (iOS dark systemRed; the owner accepted it as the dark reading of Q4, whose #FF383C is the light value) | Badge capsule in the bar |
| `tabIconSize` | `double` | 26 | 26 | Bar icon size at text scale 1 |

These existing defaults change in `fromColorScheme`, for every glass surface (Q5):

| Field | Was | Becomes | Research |
|---|---|---|---|
| `rimHighlight` | white @ 0.50 (light) / 0.18 (dark) | white @ **0.12** (light) / **0.22** (dark) | §5: ⅓ pt barely visible in light; ≈ 1 pt brighter rim in dark |
| `shadow` | `0x24000000`, (0, 6), blur 20, spread −2 | `0x12000000` (7 %), **(0, 3)**, blur **20**, spread **0** | §5 drop shadow, light |
| `dispersion` | 0.3 | **0** | §5: fringe only on the active lens; the lens sets its own (§7.2) |
| `labelStyle` | 10 / 1.4 / w600 / 0.4 | 10 / **1.2** / **w500** / **0** | §1.1 |

`liquidTint` keeps the tuned 0.40 / 0.45 from the liquid tier §3.6.1. The research shows the native fill as *milky over white*, which is what a light tint over a white page also gives. The side-by-side capture in §17 decides whether a final tint round is needed. A tuning round is part of Task 16, and it changes defaults only.

## 7. The selected lens (F3)

### 7.1 Two modes, one scalar

The lens has one scalar, `engage ∈ [0, 1]` (native `opacityPair`).

- **engage = 0 (rest).** Only the §6.2 fill is drawn. There is no extra pass, so the cost at rest is unchanged.
- **engage > 0 (press, drag, tap flight).** The fill fades as `1 − engage`, and a `LiquidLens` is drawn at the lens rect with opacity `engage`. It is clear glass that refracts the page behind the bar.

### 7.2 `LiquidLens` (liquid tier)

`LiquidLens` is a `RenderLiquidBackdrop` (liquid tier §5.3) with lens parameters. It reads the **same backdrop as the pill** through the enclosing `BackdropGroup` key, so it refracts the page, not the pill. That is native's behaviour (the `CABackdropLayer` of `_UITabSelectionView` sees the content behind the bar). `GlassTabBar` wraps itself in a `BackdropGroup` when there is none above it (standalone use). In the shell it uses the shell's group.

Parameters, where `r` is the refraction spring value (§8.4) and `h` the lens height:

| Uniform (liquid tier §4.2) | Value |
|---|---|
| `uRect`, `uRadii` | the lens rect in pass pixels, radius `h/2` |
| bezel | **14 pt**: a refracting ring around a flat core. This is passed through the new `LiquidOpticsParams.bezel` override |
| thickness | `48 · 1.6 · r` pt (native `inputAmount` peaks at −17.5, against the pill's equivalent ≈ −11) |
| index | 1.5 (unchanged) |
| dispersion | `0.3 · r`: a faint rainbow rim on the active lens only |
| tint | white @ **0.85** (light). Dark: `colorScheme.surface` @ 0.85 *(assumption: the dark press was not captured)* |
| rim | white @ **0.35**, rim width **1 pt** (new `LiquidOpticsParams.rimWidth` override) |
| saturation | 1.1 (unchanged) |
| blur before the shader | **σ 2 pt** |

*Amended after the Task 8 review (`tab-task-8-review.md`, "Visual fidelity").* The first values (tint transparent, blur 0, bezel `h/2`, dispersion `0.6·r`) gave a clear lens with a rainbow all round. Native's pressed lens (`sbs_press.png` t = 1.00, `native265_rest_vs_pressed_zoom.png`) has a milky core:

- **Tint.** On saturated stripes about 15 % of the backdrop passes (chroma 13 against 88), so the tint is 0.85. That equals the pressed-pill highlight 0.845 (research §4.1).
- **Bezel.** The measured refracting ring is 13–14 pt wide, then the core is flat. Hence 14 pt.
- **Blur.** σ 2 pt is native's selection recipe `gaussianBlur r = 2` (research §2) and the pill's `liquidBlurSigma`. On the light page the interior is flat (L 241–248), with the text behind invisible.
- **Dispersion.** `0.3·r` is the pill's former always-on value (research §5). Under the veil the fringe stays within native's 10–37 chroma at the top and bottom.

**Acceptance** for the pressed band golden (Impeller, the same measures as the review):

- interior luminance std ≤ 4 beside the icon on the light page;
- chroma (max − min of RGB) > 60 on ≤ 3 % of the lens, icon columns excluded;
- p99 chroma ≤ 80.

Native measures interior L 241–248, 1.1 % and p99 62.

The shader file does not change. Only the Dart side gains two optional overrides in `LiquidOpticsParams` (`bezel`, `rimWidth`). Null keeps the internal constants, so every existing glass and its goldens are unaffected.

A lens shadow, `BoxShadow(black 10 %, offset (0, 2), blur 10)`, is drawn with `OutsideShadow` while `engage > 0`.

**One fade.** The shader writes alpha 1, so the lens pass cannot fade itself. `GlassTabBar` draws the whole `LiquidLens` (body, rim and shadow) under `Opacity(engage)` (§7.1, §19). Inside, `LiquidLens` is engage-agnostic: its rim, shadow and fills are constants. Fading in both places would give `engage²`.

### 7.3 Other tiers

| Tier | Engaged lens |
|---|---|
| frosted | `BackdropFilter.grouped(blur σ 1)` clipped to the capsule, white fill @ 0.10, a 1 pt white rim @ 0.35, the lens shadow (all faded once by the `Opacity(engage)` of §7.2) |
| solid | an opaque capsule `Color.alphaBlend(selectionFill, theme.solid)`, the theme border when `highContrast`, the lens shadow |
| registered custom liquid renderer | frosted lens (the custom renderer has no lens API) |

The tier is resolved by the same function as `LiquidGlass` (`resolveGlassFor`, factored out of `_LiquidGlassState`), so the pill and the lens never disagree.

### 7.4 Why the lens is a separate pass

The lens pokes outside the pill while pressed (73.6 pt tall against a 65.2 pt pill), and it needs its own optics: a full-lens bezel, high dispersion and no tint. A second `BackdropFilter` that shares the group's backdrop gives both. Task 4 proves on Impeller that the second pass samples the page and not the pill. If it does not, the fallback (Risk R1) is a one-pass shader with two SDF shapes.

## 8. Interaction (F4, F5)

### 8.1 Springs

`SpringDescription.withDampingRatio(mass: 1, stiffness: (2π/response)², ratio: ζ)`, integrated by a fixed-step (1 ms) RK4 `SpringValue`. The targets move every frame, so a closed-form `SpringSimulation` cannot be reused across frames. RK4 replaced the first choice, semi-implicit Euler, because Euler's O(h) phase lag missed the 0.05 pt bound against `SpringSimulation` (§17.1): it was off by 0.18–2.3 pt at the first frame of an 86 pt move. RK4 stays within 5e-5 pt.

| Name | ζ | Response | Use |
|---|---|---|---|
| `tap` | 0.79 | 0.39 s | lens x after a tap; icon pop |
| `dragFollow` | 0.75 | **0.33 s** | lens x following the finger (the primary fit, rms 0.31 pt) |
| `snap` | 0.92 | 0.35 s | lens x after a drag release; return after a rejected commit |
| `pressHeight` / `releaseHeight` | 0.72 / 0.77 | 0.34 / 0.36 s | lens height |
| `pressWidth` / `releaseWidth` | 1.4 / 1.5 | 0.19 / 0.16 s | lens width |
| `pressScale` / `releaseScale` | 0.63 / 0.61 | 0.31 / 0.35 s | pill scale |
| `effectIn` / `effectOut` | 1.0 / 1.0 | 0.25 / 0.50 s | refraction, highlight |
| `engageIn` / `engageOut` | 1.0 / 1.0 | 0.065 / 0.20 s | engage (≈ 60 ms in, research §3) |
| `collapse` / `expand` | 0.80 / 0.70 | 0.30 / 0.35 s | minimize morph |

### 8.2 States

```
rest ──down──▶ pressed ──move>slop──▶ dragging
  ▲              │ up (travel ≤ slop)      │ up
  │              ▼                         ▼
  └──settled── flying (tap)          settling (snap)
                 cancel ─▶ settling back to the committed slot
```

| Event | Lens x target | Size targets | Pill scale | engage / refraction / highlight | Glow |
|---|---|---|---|---|---|
| **down** at x | `clampCentre(x)` on `dragFollow` | ×1.17 w, ×1.30 h | 1.052 | 1 / 1 / 0.845 | on at the finger, 0.28, 93 → 98 pt |
| **move** | `clampCentre(x)` on `dragFollow` | as pressed | 1.052 | as pressed | follows the finger |
| **up after a drag** | the nearest slot to the *lens* centre, on `snap` from the current velocity. After a flick (finger speed ≥ **600 pt/s** at release, **(assumption)** between research §4.2's 90 pt/s slow drag, which snapped to the lens's slot, and its 1500 pt/s flick, which shot to the finger's slot) the slot under the *finger* | rest, release springs | 1 | 0 / 0 / 0 (out springs) | ripple: ×4 and fade over 0.5 s |
| **up after a tap** (travel ≤ `kTouchSlop`) | the slot under the *finger*, on `tap` after a 25 ms delay | flight envelope (§8.3) | 1.022 for 0.12 s, then 1 | engage held at 1 until 0.35 s, then out; refraction out after 0.25 s; highlight impulse 0.7, then out | ripple |
| **cancel** | the committed slot, on `snap` | rest | 1 | out | fade |
| **semantics tap / programmatic** | §8.7 | | | | none |

`clampCentre` clamps to [first slot centre, last slot centre]. The lens never enters the trailing circle (research §4.2).

### 8.3 Squash and stretch (model, Q18)

These are the targets during a tap flight (`age` = time since the commit, `d` = slots travelled, `v` = lens x velocity):

- width = `rest.w · clamp(0.9 + 0.005·max(0, |v| − 700), 0.9, 1.46)`
- height = `rest.h · (1 + 0.55·g)` while `age < 0.25 s`, then rest, where `g = 1` for `d = 1` and `g = 0.45` for `d ≥ 2`

This reproduces the measured peaks:

- one slot: the width falls to ≈ 84 (×0.9) and the height rises to ×1.5–1.6 at 0.20–0.25 s;
- two slots: the width reaches ≈ 125 (×1.33) and the height ≈ ×1.24. The `tap` spring's peak lens velocity is ≈ 592 pt/s over one slot (below the 700 knee, so the width stays at ×0.9; the minimum is ×0.901) and ≈ 1184 pt/s over two.

**Amended in Task 3: gain 0.00090 → 0.005, clamp 1.35 → 1.46.**

*Why the first values were wrong.* The first draft took the width target at peak velocity (×1.335) as the peak width, but the width follows its target on `widthIn` (ζ 1.4, 0.19 s, overdamped), which lags. With gain 0.00090 the two-slot peak was only ×1.150. With the clamp at 1.35, no gain or knee gets past ×1.253 without also stretching the one-slot flight.

*The new values.*
- At gain 0.005 the target saturates by 790 pt/s, so the stretch is effectively a step at the knee, and the gain is no longer a meaningful knob.
- With the clamp at 1.46, the simulated two-slot peak is ×1.331, and `lens_motion_test` pins it at ±0.005.
- `widthIn` is unchanged: it is the measured press spring, and the press test pins its 110 pt.

*Known residual.* The width peaks about 80 ms after the lens velocity (0.167 s against 0.083 s), while native peaks at peak velocity. If the frame comparison flags this, the fix is a dedicated flight width spring fitted from the native tap strips, not a guessed one.

*Research §7.4* gives `0.9 + 0.00045·|v|` with no knee. This section supersedes it.

It is a model, not UIKit's soft body. It matches peaks and timing within ±10 %, not every intermediate frame (research §8). The constants (`0.9`, `700`, `0.005`, the clamp `1.46`) and `0.55 / 0.45` live in `TabSprings` and are the only tuning knobs.

### 8.4 Effects per frame (`LensFrame`)

| Field | Meaning |
|---|---|
| `lens` | bar-local `Rect`: centre x from the x spring, centre y = slot centre y, size from the w/h springs |
| `engage` | 0–1 (§7.1) |
| `refraction` | 0–1, drives the lens thickness and dispersion |
| `pillScale` | about the pill centre. Applied by inflating the pill *rect* (so the glass radii stay exact) and scaling the row content with a `Transform` |
| `highlight` | white overlay on the pill. Light: `0.85·highlight`. Dark: `0.25·highlight` **(assumption: not captured)** |
| `glowCenter`, `glowDiameter`, `glowOpacity` | radial gradient (white at the centre → transparent at the edge), drawn above the pill and under the tinted copy |
| `magnify` | `1 + 0.16·engage` on the tinted copy |
| `popSlot`, `popScale` | the target slot's tinted content: on a tap the target is 1.16, and from `age` 0.22 s it is 1, on `tap`, which peaks at ≈ ×1.16 near 0.25 s and is back within 0.5 s (research §3) |
| `ghost`, `ghostOpacity` | reduce motion only (§13.2) |

### 8.5 Slot crossing

During a drag, whenever `slotNearest(lens.centre.x)` changes, `LensMotion` queues a crossing. The bar drains it each tick and plays the haptic (§9).

### 8.6 The gesture recognizer

`LensGestureRecognizer extends OneSequenceGestureRecognizer`:

- **Default.** It accepts on pointer down (`resolve(accepted)`). The pill is chrome: there is no scroll under it to yield to, and the lens must engage from touch-down (research §4.2).
- **At AX text sizes.** It accepts on the first move beyond `kTouchSlop` (a drag) or on pointer up (a tap). Until then the `LargeContentViewer` long press can win the arena, so the P1 large content card still works.
- **Events.** It reports `onDown(Offset)`, `onMove(Offset)`, `onUp()` and `onCancel()` in bar-local coordinates. It tracks one pointer: a second finger is ignored.
- **The trailing circle.** It keeps its own tap. A drag that starts on the pill and ends over the circle releases onto the circle (§8.8).

### 8.7 Commit, guard and programmatic changes

- **Commit on release.** `onDestinationSelected` (or the shell's `_onSelect`) is called once, on release, with the destination of the committed slot. A tap on the already selected slot also commits (P1 §5.5 rule 5, reselect). Move events never select.
- **Pending commit.** After a commit the lens stays at the committed slot. If `selectedIndex` becomes that slot, the commit is done.
- **Rejected commit.** If the motion settles and `selectedIndex` still differs (the guard said no, or the app ignored the call), the lens returns to `selectedIndex` on `snap`. This matches native propose-accept: UIKit refuses, then selects programmatically on accept.
- **Programmatic change** (no pending commit, a new `selectedIndex`): the lens **jumps**, with no animation, as UIKit's `selectedIndex` setter does (Q12).
- **Semantics tap** (VoiceOver or TalkBack `onTap` on a slot node): the tap path with the same animation, because a screen reader user activating a tab is a tap. Under reduce motion it uses §13.2.

### 8.8 The trailing circle and ⌕ as a drag target

The bar knows its trailing target as a `TabDragTarget`, which has three parts:

- a rect in bar-local coordinates;
- `hovered`, a `ValueNotifier<bool>`;
- `onRelease`, a `VoidCallback`.

The target has two possible sources:

- the bar's own trailing circle (`LiquidTabAction`): its rect is in the geometry;
- the search shell's ⌕ (P3b-1 idle phase): the shell passes the ⌕ rect converted to bar-local coordinates (§11).

While the finger is inside the target rect, inflated by 4:

- `hovered` is true, and the circle draws a highlight. This is the same white overlay as the pill highlight, at 0.85 (light) or 0.25 (dark).
- The lens stays clamped to the pill at the last slot.

Release while hovered calls `onRelease` and does not commit a slot. The lens returns to `selectedIndex`.

### 8.9 Semantics

The bar keeps one `Semantics(container, button, selected, label + badge, hint, onTap)` node per slot, positioned at the slot rect, with the row content excluded. The minimized circle keeps P1's hint and expand announcement. The search collapsed circle uses the previous destination's label (P3b §9.2). Glow, lens and highlight add no semantics.

## 9. Haptics (F6, Q6)

`HapticFeedback.selectionClick()`, from the Flutter SDK, with no new dependency:

- once per slot crossing during a drag (§8.5);
- **not** on a plain tap;
- **not** on commit.

On iOS, `selectionClick` is a `UISelectionFeedbackGenerator`, which UIKit's own selection controls use. On Android it maps to the system "clock tick" constant.

The research could not observe tab bar haptics on the simulator (§4.4). The owner confirms the pattern on a real device during acceptance (§17.4). Nobody else touches devices. A change after that check is a one-line change in `GlassTabBar._onTick`.

## 10. Minimize morph (F7)

- **Trigger.** It is unchanged in the shell: `UserScrollNotification` `reverse` sets `_minimized`, but only when `minimizeOnScroll` is on and the chrome is `bottomBar`. The **expand on `forward` scroll is removed** (Q7: native stayed minimized during a 200 pt reverse scroll). A tap expands. The shell also expands when the selected destination changes, so that a programmatic switch never leaves a collapsed bar.
- **Collapse.** The bar starts its collapse **240 ms** after `minimized` becomes true, if it is still true then. A `morph` scalar goes 0 → 1 on `collapse`.
  - **The glass rect.** It is `lerpRect(pill, minimized, morph)`, scaled about its centre by `1 − 0.04·sin(π·morph)` (the ×0.96 dip).
  - **The row.** The labels and the non-selected cells fade with `1 − clamp(morph/0.4, 0, 1)`.
  - **The selected icon** moves from its slot's icon frame to the circle centre. It is drawn in the selected colour, with its badge.
  - **The lens fill** fades with the labels. The minimized circle shows no selection capsule.
  - **The trailing circle** lerps from its `E × E` rect to its `48 × 48` rect about the same centre.
- **Expand.** A tap on the circle sets `minimized` false (the shell's `onExpand`). `morph` goes 1 → 0 on `expand` (ζ 0.70 gives a small overshoot), with no delay.
- **Hit test.** It is the current glass rect only.
- **Reduce motion.** Instant: no delay, no spring, no dip.
- **Implementation.** It is one glass shape (`LiquidGlass` positioned at the animated rect), not two cross-faded shapes. The research suggests a smooth-min SDF for a gooey merge of the pill and ⌕, but native swaps visibility during the dip, so one moving rect plus the ⌕ shrinking about its own centre reads the same (research §6).

## 11. The search tab's compact morph (F8, P3b-1)

P3b-1's `CompactSearchChrome` keeps its three phases and its single `SearchFieldGlass` (focus safety, P3b §9.4). These parts change:

| Part | P3b-1 today | VK-503 |
|---|---|---|
| Row margin | 16 | 21 (narrow 8), the same as §5.1 |
| Idle pill | `LiquidTabBar` between `margin` and `margin + E + 8` from the end, faded by `AnimatedOpacity` | `GlassTabBar` start-pinned (§5.1), with the ⌕ as its external `TabDragTarget` |
| Selected / active: previous tab | the pill fades out, and a separate `kSearchCollapsedKey` circle fades in at start 28 | the bar **minimizes** with the §10 morph (`morph` → 1, no 240 ms delay). Its circle shows `previous`'s icon and is the collapsed circle: it carries `kSearchCollapsedKey`, the previous label in semantics, and tap → `_onSelect(previous)`. Native shows the same 48 circle at x = 28 (research §1.1, §6) |
| Back to idle | the circle fades out, the pill fades in | the bar expands with the §10 morph |
| ⌕ circle in idle | 62 square at `width − margin − E` | unchanged size; it is the drag target; `hovered` draws its highlight |
| Field morph | 350 ms `easeOutCubic` | unchanged (P3b Q12). Only the collapsed circle moved to the bar |
| `minimizeOnScroll` while search is selected | suspended | suspended (unchanged). The minimized look is driven by the phase, not by `_minimized` |

`compactSearchRects` keeps its signature. Only its `margin` argument becomes 21. Its `circle` rect equals the bar's `minimized` rect in screen coordinates, which a test pins.

## 12. Other forms and the sidebar (F9)

### 12.1 Compact landscape (Q8)

`LiquidShellBreakpoints` gains `compactHeight` (default **500**). `presentationFor` returns `compact` when the width is below `regular`, **or** when `width > height` and `height < compactHeight`. An iPhone in landscape (874 × 402, 932 × 430) then gets the bottom bar in its §5.2 landscape form, as native does. Before this change it got P1's regular overlay with the top bar.

Tablets are never under 500 tall in landscape, so they are unaffected. `sidebarOnly` destinations on a landscape phone follow P1 §5.5 rule 6: the `onSelectedDestinationHidden` callback.

### 12.2 Regular top bar (Q9)

- The geometry is §5.3, with the same `LensMotion`, the lens and the tap envelope.
- The press and drag rules of §8 apply with the top bar's slots.
- The lens on a tap inflates to ×1.34 / ×1.375 (§5.3), instead of the compact lift model.
- The row top moves from `padding.top + 20` to `padding.top + 5.5`. `chromeInsetsFor` and `regularSearchFieldTop` follow through the existing `kTopBarGap` constant, which becomes **5.5**. The sidebar toggle stays at its P1 position, re-centred on the 48 pt row.

### 12.3 Sidebar (Q10)

The research did not measure the iPadOS 26 sidebar, and native has no lens there. In this item the sidebar takes only:

- the shared icon rule (§14);
- `tabForeground` for unselected rows;
- `badgeColor` for its badges.

Its selected row stays P1's chip. Matching the native sidebar exactly needs its own measurement pass, proposed as a follow-up issue.

## 13. Accessibility and fallbacks (F10)

### 13.1 Light, dark, RTL, text scale

- **Light and dark.** Every colour in §6.4 has both values. The lens tiers follow the theme brightness.
- **RTL.**
  - Slots are mirrored, so slot 0 is at the right.
  - The pill is pinned to the start (right) and the circle to the end (left). The minimized circle sits at start + 7 (right).
  - Badges use `PositionedDirectional`.
  - The drag reads the finger's x directly in screen space, so dragging left moves the lens left in both directions.
- **Text scale.**
  - Below the AX threshold, the label grows and so does the pill (`E`, §5.1). Narrow labels keep P1 Q18's fit (`FitLabel`).
  - At the AX threshold and above, cells are icon-only (P1 §5.10). The icon size is `axIconSize(context, tabIconSize)`, the recognizer defers (§8.6), and the large content viewer works.
- **Bold Text.** The labels follow `MediaQuery.boldTextOf` through Flutter's `Text` (bold weight), as every other label in the package does.

### 13.2 Reduce motion (Q11)

When `MediaQuery.disableAnimationsOf` is true:

- **Tap.** The lens does not slide. The old fill fades out (`ghost`) and the new one fades in over **150 ms**, linear. There is no engage, refraction, bulge, highlight, pop, glow or lift.
- **Drag.** The rest-sized capsule follows the finger on a critically damped spring (ζ 1, 0.25 s). Direct manipulation stays, but nothing inflates. The release snaps on the same spring.
- **Minimize.** Instant.
- **Search morph.** P3b's rule (instant).

### 13.3 Reduce transparency and increase contrast

These come from tier resolution (liquid tier §6), unchanged:

- **Reduce transparency → solid.** The pill and lens are opaque (§7.3). The motion, glow and haptics stay: they carry no transparency.
- **Increase contrast → solid with the border.** The lens at rest draws `selectionFill` blended opaque, plus a 1 pt border in `theme.border`. Labels keep their colours (#191919 on the solid surface passes 4.5:1).

### 13.4 Tiers

- **Frosted** (battery saver, low-end, GLES-only, slow frames): the full motion, with the frosted lens of §7.3.
- **Solid:** as §13.3.

The frame guard (liquid tier §7.4) is unchanged. During interaction the extra pass is short-lived, and the guard's p90 window absorbs it.

## 14. Icon strategy (F11, Q1, Q2)

SF Symbols cannot be drawn by Flutter:

- the font cannot be bundled outside Apple platforms;
- on iOS it is not exposed to Flutter text.

The strategy has four parts:

1. **The contract (docs).** `icon` is the outline glyph and `selectedIcon` the filled glyph. The Flutter tab bar draws `selectedIcon ?? icon` in **every** slot, as native draws filled symbols in every slot. The sidebar keeps outline/filled by selection (P1). The README and `doc/tab_bar.md` show a destination table with `Icons.home_outlined` / `Icons.home`, and say that a filled pair is what gives the native look.
2. **Box size.** The default `tabIconSize` is 26. Material and Material Symbols glyphs draw their ink at about 20/24 of the box, so 26 gives the ≈ 21–22 pt ink box of the SF tab glyphs. Apps using other icon fonts tune `tabIconSize` in the theme.
3. **The example.** Every case gives filled `selectedIcon`s chosen to read like the SF Symbol it sets in `sfSymbol`:

   | Destination | `icon` | `selectedIcon` | `sfSymbol` |
   |---|---|---|---|
   | Home | `home_outlined` | `home` | `house` |
   | Explore | `map_outlined` | `map` | `map` |
   | Settings | `settings_outlined` | `settings` | `gear` |
   | Inbox | `inbox_outlined` | `inbox` | `tray` |

4. **No new dependency.** `cupertino_icons` is a separate package, and the dependency rule forbids it. Apps can pass `CupertinoIcons` themselves.

On iOS < 26 the exact glyphs would be available by rasterizing `UIImage(systemName:)` on the native side. That is Q2, recommended as a separate issue.

## 15. Scroll-edge pocket (F12, Q13)

Native puts a 147.8 pt progressive blur and dim under the bar (research §5). Flutter has no variable-radius backdrop blur. The approximation, liquid tier only, has two parts:

- **Three blur bands**, each a `BackdropFilter.grouped` with a `ClipRect`:
  - the bottom 148 pt split into three bands of 49.3 pt;
  - σ 0.5, 1.0 and 1.6 from top to bottom.
- **A dim gradient** from transparent to `black 1.2 %` (light) or `black 8 %` (dark) over the same 148 pt (§5: the band reads 252, not 255).

`ScrollEdgePocket` lives in `lib/src/glass/scroll_pocket.dart` (seam rule) and is placed by the shell between the body and the bar. It is drawn only:

- when the bar is a `bottomBar`;
- when the resolved tier is liquid;
- when the theme's `liquidBlurSigma > 0`.

Frosted and solid get no pocket. It adds three backdrop passes over 148 pt of height, so the frame guard covers it. Under reduce transparency there is no pocket.

## 16. Public API changes

| Change | Kind |
|---|---|
| `LiquidGlassTheme`: `selectionFill`, `tabForeground`, `badgeColor`, `tabIconSize` | additive |
| `LiquidGlassTheme.fromColorScheme`: new `rimHighlight`, `shadow`, `dispersion`, `labelStyle` defaults (§6.4) | **behaviour change**: visuals of every glass surface |
| `LiquidShellBreakpoints.compactHeight` (default 500) | additive. **Behaviour change** for landscape phones (§12.1) |
| `LiquidTabBar`: same constructor. Selection now commits on release with animation; all slots draw `selectedIcon ?? icon`; no ink | **behaviour change** |
| Minimize no longer expands on forward scroll (§10) | **behaviour change** |
| `kTopBarGap` 20 → 5.5 (internal), so regular `chromeInsets.top` shrinks by 14.5 | **behaviour change** |
| `debugTabLensPress` (goldens) and `debugTabTrace` (acceptance traces): `@visibleForTesting` in `src/`, **not exported** (the public-API constraint). The example's goldens import them from `src/` under a scoped `// ignore: implementation_imports` | none |

The packages are at `0.1.0-dev.5`. This item ships as `0.1.0-dev.6`, and the CHANGELOG lists every behaviour change (Q22).

## 17. Testing and acceptance

### 17.1 Unit (pure, `make test`)

- **`tab_geometry_test.dart`:**
  - the worked checks of §5.1 (3, 4 + ⌕, 5 tabs; unbounded width; narrow);
  - RTL mirroring;
  - slot overlap 8;
  - the minimized and trailing rects;
  - the badge origin;
  - landscape (content-sized items, gaps);
  - the top bar (274 for Home/Explore/Settings with the measured label widths, and the 48.5 search item);
  - `slotNearest`, `clampCentre`.
- **`tab_springs_test.dart`:**
  - `fittedSpring` stiffness (0.39 s → 259.6);
  - `SpringValue` against Flutter's own `SpringSimulation` for the same spring: positions within 0.05 pt over 1 s;
  - settle detection.
- **`lens_motion_test.dart`.** Everything runs at 60 fps with `advance(1/60)`, against the native numbers:
  - tap one slot: settle time (0.5 pt) within ±10 % of the reference spring with a 25 ms delay; overshoot within ±1 pt of the reference; peak height ×1.55 ± 10 % between 0.15 and 0.30 s; min width ≤ ×0.92;
  - tap two slots: peak width ×1.33 ± 10 %;
  - press and hold for 1 s: lens 110 × 70 ± 2, pill scale 1.052 ± 0.005, engage 1, highlight 0.845 ± 0.02, glow 0.28 ± 0.02;
  - drag at 90 pt/s: steady lag equals the `dragFollow` spring's ramp lag `v·2ζ/ω` ± 10 % (7.1 pt); clamped at the slot ends; a crossing is queued once per slot boundary;
  - release after a drag: commits the slot nearest the lens, not the finger (research §4.3: finger at 244, lens at 237.8 → the slot at 201); after a flick, the finger's slot; settles on `snap` ± 10 %;
  - cancel returns to the committed slot;
  - reduce motion: no inflate, ghost dissolve of 150 ms;
  - the minimize morph: 0.30 s settle ± 10 %; the dip minimum 0.96 ± 0.005.
- **`glass_theme_test.dart`:** the new fields, the defaults per brightness, `copyWith`, `lerp`, `==`.
- **`liquid_optics_test.dart`:** the `bezel` and `rimWidth` overrides change exactly floats 8 and 22; null keeps the old lists byte-identical.

### 17.2 Widget (`make test`, filter factory injected)

- `glass_tab_bar_test.dart`:
  - the pill rect, slot rects and trailing rect equal the geometry within 0.01;
  - all slots draw `selectedIcon ?? icon`;
  - the tinted copy is clipped to the lens;
  - there is no `InkWell` in the bar;
  - the badge position;
  - hit testing passes through the margins.
- `tab_gesture_test.dart`:
  - a tap commits on up, not on down;
  - a drag across 2 slots commits the nearest slot on release, with one `selectionClick` per crossing (recorded through `SystemChannels.platform`);
  - a cancel commits nothing;
  - a guard rejection animates back after settle;
  - a programmatic change jumps;
  - a semantics tap animates and commits;
  - at AX scale a long press opens the large content card and a drag still works;
  - the ticker stops at rest (`tester.binding.hasScheduledFrame` false after settle).
- `lens_layer_test.dart`, with the liquid override on:
  - `LiquidLens` exists only while engaged;
  - it shares the shell's `BackdropGroup` key;
  - its uniforms carry `bezel = 14 pt`, tint white 0.85, blur σ 2 and rim width 1 at the view scale;
  - frosted and solid lens variants appear per tier.
- `minimize_test.dart`:
  - the collapse starts at 240 ms and ends at the 48 rect (±0.5);
  - the trailing shrinks about its centre;
  - forward scroll does not expand, a tap does;
  - reduce motion is instant.
- `search_morph_test.dart` (P3b-1 regression plus the new rules):
  - selected → the bar's circle carries `kSearchCollapsedKey` at the `compactSearchRects.circle` rect;
  - a drag into ⌕ highlights it, and release selects search;
  - the field keeps focus across phases.
- The existing `tab_bar_test.dart`, `shell_chrome_test.dart` and `search_fallback_test.dart` are updated where they assert P1 geometry (62 pill kept, width rules changed), ink or immediate selection on tap.

### 17.3 Goldens

- **`golden` (non-Impeller) images** are regenerated with `make goldens-update`. Every case image changes: the geometry, icons, colours, shadow and rim.
- **New `case_tab_states` goldens** cover rest states only, because motion is covered by tests:
  - 3 tabs;
  - 4 tabs + ⌕;
  - badges;
  - trailing;
  - minimized;
  - landscape;
  - the iPad top bar;
  - in light, dark and RTL.
- **New `liquid_golden` band images** add the engaged lens frozen at `engage = 1` through a `@visibleForTesting` hook in `src/` (`debugTabLensPress`, the x shift of a pressed lens):
  - pressed on slot 1;
  - straddling slots 1–2 (the half-tinted icons).

### 17.4 Acceptance (owner)

**Numeric gate.** The tolerances:

| Quantity | Reference | Tolerance |
|---|---|---|
| Rest geometry: pill, slots, trailing, minimized, icon frame top, label top, badge origin | §5 | **±1 pt** |
| Spring settle (0.5 pt) for tap, drag follow, snap, press, release, collapse, expand | the §8.1 reference spring over the same distance | **±10 %** |
| Tap delay | 25 ms | ±1 frame (16.7 ms) |
| Press lens size, pill scale | 110 × 70, 1.052 | ±2 pt, ±0.005 |
| Flight peaks (one slot height, two slot width) | ×1.55, ×1.33 | ±10 % |
| Icon pop, magnify | ×1.16 | ±0.02 |
| Glow | 93 pt, 0.28, ×4 over 0.5 s | ±2 pt, ±0.03, ±10 % |
| Rest colours (lens fill, labels) | #ECECEC / #3A3A3A / #191919 / #F4F4F4 | ±4 / 255 per channel at the sampled pixel, over a white or black page |

**Flutter traces.** `integration_test/tab_fidelity_test.dart` runs on the iOS 26.5 iPhone 17 Pro simulator, with Flutter liquid forced. It drives the scripted sequences of the research:

- tap 1 → 2;
- tap 2 → 3;
- tap 3 → 1;
- press-hold 1 s;
- slow drag 115 → 287 at 90 pt/s;
- fast flick;
- minimize and expand.

Each frame it records the `LensFrame` (from a debug-only listener) with the engine's frame timestamp. `binding.reportData` writes it as JSON. `tool/tab_trace_compare.dart` compares it with `docs/qa/vk503/native_reference.json` (the research fits and peaks, typed in once) and prints a pass/fail table. The native traces themselves stay in the vankhan scratchpad. Only the fitted numbers enter the repository.

**Frame strips.** `tool/tab_frames.sh` creates its own iPhone 17 Pro iOS 26.5 simulator and runs the example's basic case twice, in "Native" and in "Flutter liquid". It drives the same sequences in each mode:

- native: XCUITest `press(forDuration:thenDragTo:)`, through the existing `RunnerUITests` target;
- Flutter: `idb`-free `flutter drive` gestures from the integration test.

It records each run with `xcrun simctl io recordVideo` and extracts 60 fps frames with `ffmpeg`, a developer tool that the script checks for. `tool/tab_strips.dart` then aligns the k-th motion onset in the bar band of one recording with the k-th in the other, and composes `build/tabfid/strips/frames_<k>.png`: native on the left, Flutter on the right, one row every 3 frames for 0.9 s. The owner reviews them as an artifact page.

**On device.** The owner checks the OTA example on a real iPhone and iPad with Flutter liquid forced. This confirms the haptics (Q6) and the overall feel. Nobody else touches physical devices.

## 18. Docs and versions

- **`doc/tab_bar.md` (new):**
  - the geometry, the lens and the motion in plain words;
  - the icon strategy (§14);
  - what is not identical to native (the accepted Q rows);
  - the reduce-motion behaviour.
- **README:** the tab bar section with the new compare images, and the icon pair advice.
- **`doc/liquid.md`:** the lens pass, the pocket, the new theme defaults.
- **CHANGELOG ×4:** `0.1.0-dev.6`, with the behaviour changes of §16.

## 19. Performance

| State | Passes | Ticker |
|---|---|---|
| rest | pill (1) + circle (1) + pocket (3, liquid only) | off |
| press / drag / tap flight (≤ 0.85 s after release) | + lens (1), under an `Opacity` save layer while `engage < 1` | on |
| minimize morph | the same passes, the glass rect animates | on (0.3–0.35 s) |

During motion the lens needs a fresh `FragmentShader` per frame, because its uniforms change (liquid tier §5.3). That is one small allocation per frame for under a second.

## 20. Risks

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| R1 | A second `BackdropFilter` sharing the group's key samples the pill, not the page, on some backend (Metal / Vulkan / GLES) | M / H: the lens would show the milky pill | Task 4 proves it on Impeller (macOS Metal) and the integration run on the Android emulator (GLES + Vulkan) checks a pixel. Fallback: one pass with a second SDF shape in `liquid_glass.frag` (`uLens` rrect + lens optics), the lens drawn inside the pill pass and the pill clip widened to the union. This is a new shader uniform block, so it would be a plan change reported to the owner |
| R2 | `Opacity` over a `BackdropFilter` layer costs a save layer per frame | M / M | Only while `0 < engage < 1` (≈ 60 ms in, 200 ms out). The frame guard demotes to frosted on slow devices |
| R3 | The squash and stretch model misses native frames between peaks | H / L | Accepted in Q18. The gate is on peaks and settle, and the frame strips make the residual visible |
| R4 | Landscape `compactHeight` changes P1 behaviour for apps that relied on the top bar on landscape phones | M / M | `compactHeight: 0` restores P1. CHANGELOG |
| R5 | Commit on release changes timing for apps that react to `onDestinationSelected` | L / L | Native does the same. Taps still commit on up, as `InkWell` did |
| R6 | The new theme defaults make other glass (dialogs, sidebar) look different from P3a's reviewed images | M / L | Q5. Goldens regenerate. The owner reviews them in the same pass |
| R7 | Simulator `recordVideo` drops frames, so the strips are not true 60 fps | M / L | The numeric gate uses engine traces (Flutter) and the research's CADisplayLink fits (native). The strips are visual only |
| R8 | Glyph mismatch on Android (Material vs SF) stays visible | certain / M | Q1, Q2. Documented in `doc/tab_bar.md` |

## 21. Process

1. Plane VK-503 moves to Todo with the label `spec:approved` once the owner answers.
2. Each `### Task N` of the plan becomes a sub-issue.
3. Each task is TDD, followed by a review.
4. Before the PR, `make verify` is green, plus `make test-impeller` and `make goldens` on macOS 3.44.6, with the outputs pasted.
5. Task 16 produces the acceptance strips and the trace table for the owner.

---

## Quyết định cần chủ sản phẩm xác nhận

> **Chủ sản phẩm chấp nhận toàn bộ đề xuất Q1–Q22 (11/10/2026: "tiếp tục đi. ok hết").** Q22: số phiên bản theo thứ tự merge thực tế (main hiện là dev.5).

Mỗi dòng có đề xuất mặc định. Nếu chủ sản phẩm trả lời "Ok hết" thì áp dụng toàn bộ đề xuất. Các dòng Q14–Q21 là những điểm **không thể giống 100%** (mục §8 của nghiên cứu); mỗi dòng ghi phương án gần nhất có thể làm.

| Q# | câu hỏi | đề xuất |
|---|---|---|
| Q1 | Icon trên Android và iOS < 26 (không có SF Symbols) xử lý thế nào? | **Mọi ô tab vẽ icon đặc** (`selectedIcon ?? icon`), vì native vẽ biểu tượng đặc ở mọi ô. Kích thước mặc định 26pt: nét icon Material khi đó rộng ~22pt, bằng SF. App tự đưa cặp icon viền/đặc; tài liệu và ví dụ dùng `Icons.home_outlined`/`Icons.home`… Không thêm `cupertino_icons` (luật không thêm phụ thuộc); app muốn dùng `CupertinoIcons` thì tự truyền vào. Chỉnh được bằng `LiquidGlassTheme.tabIconSize` |
| Q2 | Trên iOS < 26 có lấy đúng ảnh SF Symbol từ phía native (`UIImage(systemName:)` → ảnh bitmap qua kênh) không? | **Không làm trong VK-503; tách thành issue riêng.** Làm được và cho icon giống hệt trên iOS 15–25, nhưng cần thêm API kênh, bộ nhớ đệm ảnh và xử lý khi đổi cỡ chữ. Android vẫn dùng icon Material đặc (Q1) |
| Q3 | Bắt chước giao diện iOS 26.5 hay iOS 27? | **iOS 26.5:** không viền mảnh, có bóng đổ nhẹ, lò xo chạm 0.39 s, thấu kính "nhấc" lên khi chạm sang 1 ô, nút ⌕ tách rời trên iPhone. Số đo 26.5 tin cậy hơn (vết khung hình 27 bị hụt, sai ±20%). Kiểu 27 làm sau nếu cần |
| Q4 | Màu chữ/icon trong thanh tab lấy từ đâu? | **Ô đang chọn = `colorScheme.primary`** (đúng màu P2 đang truyền cho native làm `tintColor`, nên native và Flutter cùng màu nhấn trong cùng app). **Ô không chọn = số đo native** #191919 (sáng) / #F4F4F4 (tối). Huy hiệu đỏ #FF383C. Cả ba là trường theme đổi được |
| Q5 | Đổi vật liệu kính mặc định (viền sáng nhạt đi, bóng 7% lệch 3pt, tắt tán sắc trên viên tab) cho **mọi** bề mặt kính hay chỉ thanh tab? | **Mọi bề mặt** (sidebar, ⌕, hộp thoại, nút back): native dùng chung một vật liệu. Tán sắc chỉ còn trên thấu kính đang chạm, như native. Golden đổi hết, chủ sản phẩm xem lại một lượt |
| Q6 | Rung (haptics) thế nào? Simulator không đo được | **`selectionClick` mỗi lần thấu kính đi qua một ô khi kéo; chạm thường và lúc thả không rung.** Chủ sản phẩm kiểm tra trên máy thật khi nghiệm thu, sai thì sửa một dòng |
| Q7 | Thanh tab thu nhỏ có tự nở ra khi cuộn ngược lên không? | **Không, giống native:** chỉ chạm vào hình tròn mới nở (native cuộn ngược 200pt vẫn thu nhỏ). Đổi tab bằng code cũng làm thanh nở ra. Đây là thay đổi so với P1 §5.7, ghi trong CHANGELOG |
| Q8 | iPhone xoay ngang: giữ thanh trên cùng của P1 hay đổi sang thanh đáy 44pt như native? | **Thanh đáy 44pt như native** (icon cạnh chữ 12pt, ô theo độ dài chữ). Thêm `LiquidShellBreakpoints.compactHeight` = 500: màn ngang thấp hơn 500 thì dùng thanh đáy. Đặt `compactHeight: 0` để giữ cách cũ |
| Q9 | Thanh trên cùng của iPad: đổi theo native (cao 48, chỉ có chữ 17pt, sát mép trên hơn) không? | **Có:** viên cao 48, ô cao 40 chỉ có chữ, đệm 15.5, ⌕ là ô icon 48.5 nằm trong viên, hàng đặt ở `safe top + 5.5` (native y = 29.5). Vùng nội dung phía trên vì thế rộng thêm 14.5pt |
| Q10 | Sidebar iPad có làm giống native trong VK-503 không? | **Chỉ dùng chung màu chữ, màu huy hiệu và quy tắc icon.** Native không có thấu kính ở sidebar, và nghiên cứu chưa đo sidebar. Đo và chỉnh sidebar để thành issue tiếp theo |
| Q11 | Bật "Giảm chuyển động" (Reduce Motion) thì sao? | **Chạm: ô xám mờ đi ở ô cũ và hiện ở ô mới trong 150ms**, không trượt, không phồng, không nảy, không quầng sáng. **Kéo: viên xám vẫn chạy theo ngón** (thao tác trực tiếp) nhưng không phồng. Thu nhỏ và nở ra tức thì |
| Q12 | App đổi `selectedIndex` bằng code (deep link, guard đồng ý muộn) thì thấu kính có trượt không? | **Nhảy ngay, không hoạt ảnh**, như UIKit khi đặt `selectedIndex`. Nếu guard từ chối thì thấu kính trượt về ô cũ bằng lò xo "snap" |
| Q13 | Có làm dải mờ dần ở đáy màn hình (scroll-edge pocket, native cao 148pt) không? | **Có, bản xấp xỉ:** 3 dải mờ (σ 0.5 / 1.0 / 1.6) và một lớp tối rất nhẹ, chỉ ở tầng liquid. Flutter không có blur biến thiên, nên không giống từng điểm ảnh. Tầng frosted/solid và "Giảm trong suốt" không có dải này |
| Q14 | **(không thể 100%)** Vật liệu kính riêng của Apple (`glassBackground`) và kính tự đổi sáng/tối theo nền (`tracksLuma`) | **Khớp theo số đo:** màu nền, viền, bóng, khúc xạ mép. Kính tự đổi theo độ sáng nền để sau (cần thêm một lượt đo độ sáng, tốn pin). Màu phủ cố định theo theme sáng/tối |
| Q15 | **(không thể 100%)** Góc bo "liên tục" (continuous/superellipse) của Apple | **Giữ bo tròn thường cho viên hình con nhộng:** với viên con nhộng, chênh lệch dưới 1pt, nằm trong sai số ±1pt. Không đổi shader |
| Q16 | **(không thể 100%)** Chữ và icon "vibrant" (pha màu theo nền phía sau) | **Dùng màu đặc đúng số đo** (#191919/#F4F4F4, màu nhấn). Trên nền rất sặc sỡ, native ngả màu nhẹ theo nền còn Flutter thì không |
| Q17 | **(không thể 100%)** SF Symbols | Xem Q1, Q2. **Gần nhất trên Android: icon Material/Material Symbols đặc, cỡ 26.** Hình dạng icon vẫn khác SF |
| Q18 | **(không thể 100%)** Thấu kính co giãn (squash/stretch) theo mô hình vật thể mềm riêng của UIKit | **Mô hình hai lò xo (rộng, cao):** khớp đỉnh và thời gian trong ±10%, không khớp từng khung trung gian. Ảnh từng khung đặt cạnh nhau cho thấy phần chênh |
| Q19 | **(không thể 100%)** Kính nằm trên platform view (bản đồ, web view) | **Không sửa được** (`BackdropFilter` không thấy platform view). Ghi rõ trong tài liệu, khuyên app ép `frosted` hoặc `solid` ở trang có bản đồ/web view |
| Q20 | **(không thể 100%)** Thanh đáy iPad khi cửa sổ hẹp, và thời gian lò xo iOS 27: chưa đo được | **Dùng số đo iPhone cho thanh đáy iPad hẹp** (cùng lớp `_UITabBarPlatterView`); không làm kiểu 27 (Q3). Đo bổ sung khi có cách mở cửa sổ hẹp trên simulator |
| Q21 | **(không thể 100%)** iPad: giữ lâu một tab để sắp xếp lại các tab (chế độ tuỳ biến của hệ thống) | **Không làm** (đó là trình chỉnh sửa của hệ thống, không phải chrome). Trên iPad, giữ lâu trong bản Flutter chỉ phồng thấu kính như iPhone |
| Q22 | Phiên bản và thay đổi hành vi? | **`0.1.0-dev.6` cho cả 4 gói,** CHANGELOG liệt kê: chọn tab khi thả tay, mọi ô vẽ icon đặc, mặc định vật liệu mới, thanh đáy khi iPhone xoay ngang, thu nhỏ không tự nở khi cuộn, thanh trên iPad sát hơn 14.5pt. Không publish |
