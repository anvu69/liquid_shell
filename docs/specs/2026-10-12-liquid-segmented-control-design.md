# liquid_shell: `LiquidSegmentedControl` and the liquid search scope bar

- **Plane:** VK-550
- **Date:** 2026-10-12
- **Status:** draft for the owner. The owner approves this spec and the plan `docs/plans/2026-10-12-liquid-segmented-control.md` together. Q1–Q5 of the brief are decided ("ok hết"); the new choices this spec raises are in the last section, "Quyết định cần chủ sản phẩm xác nhận", each with a recommended default. If the owner says nothing, the defaults apply.
- **Branch:** `VK-550-liquid-segmented-control`, from `VK-503-tab-fidelity` at `1c1eeb9` (Q4: stacked on VK-503; its own PR after PR #9 merges). Worktree `liquid_shell-vk550`.
- **Floor:** Flutter ≥ 3.44.0 / Dart ^3.12.0 (fvm pins 3.44.6), iOS deployment target 15.0, Android `flutter.minSdkVersion`, `very_good_analysis` 10.3.0, `pigeon` 27.3.0 (dev). No new runtime dependency.
- **Owner input (binding),** verbatim:

  > trang search là tab trên cùng (All, Songs, Places) cũng sẽ có hiệu ứng Liquid Glass

- **Owner decisions (binding, "ok hết"):**
  - **Q1.** Native mode on iOS 26+: the real native scope bar (`UISearchController.searchBar.scopeButtonTitles`, `selectedScopeButtonIndex`) on the native search tab's existing `searchController`, after a spike on our own iOS 26.5 and 27 simulators, iPhone and iPad. If placement or behaviour is wrong or unusable, the Flutter liquid control in native mode too, with the reason recorded. The bridge is one-way safe: native sends only user changes, Dart dedupes, nothing echoes.
  - **Q2.** A new public widget, `LiquidSegmentedControl`; `LiquidSearchScopeBar` becomes a thin wrapper around it, and it is reusable outside search.
  - **Q3.** Flutter fidelity at the tab-bar level: a tap moves the thumb with a spring; a press lifts the lens (refraction and the rainbow rim through the VK-503 shader veil falloff); drag and flick work across segments with `selectionClick` haptics on each crossing. Reuse the VK-503 lens engine (`tab_springs.dart`, `lens_motion.dart`, `liquid_lens.dart`, `lens_gesture.dart`, the shader), generalised where needed, never copied. Acceptance is side-by-side frame strips and trace rows against measured native data, never constants read back.
  - **Q4.** Stack on VK-503, own PR after PR #9.
  - **Q5.** Android and iOS < 26 use the Flutter liquid control, with the usual frosted/solid tier demotion.
- **Standing constraints (VK-503 spec):** clean room (no other package's glass code opened), no third-party glass dependency, every glass surface through `LiquidGlass` / `LiquidLens` (`tool/check_glass_seam.sh`), the barrel exports only public API (`test/unit/public_api_test.dart`).
- **Sources:**
  - The spike, `docs/qa/vk550/spike.md` ("spike §n"), with its evidence in vankhan `.superpowers/sdd/vk550-spike/`. Every number below comes from there unless marked **(assumption)**.
  - The VK-503 spec `docs/specs/2026-10-11-tab-fidelity-design.md` ("VK-503 §n"): the lens engine (§7, §8), the acceptance method (§17.4).
  - The P3b spec `docs/specs/2026-10-10-p3b-search-tab-design.md` §4.4 (`LiquidSearchScopeBar`), §7.4 (the one-way search bridge), Q5 (which chose a Flutter-drawn scope bar before native scope bars were measured).
  - The code at `1c1eeb9`.
- **Clean room.** No other package's liquid glass source was opened. Apple's private class names (`_UILiquidLensView`, `ContentLensingView`, `_UISearchBarScopeContainerView`) appear only because they come from the runtime dump of Apple's own views.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Spike Q1 (đã chạy trên 4 simulator riêng: iPhone/iPad × iOS 26.5/27):** thanh phạm vi native của `UISearchController` **dùng được**, nhưng **không** với cấu hình mặc định: mặc định (`.automatic`) nó không hiện ở cả 4 máy. Cách chạy được ở cả 4 máy, sáng và tối: `scopeBarActivation = .manual` và tự bật `setShowsScope(true)` khi search mở, tắt khi search đóng. Vị trí: **iPhone ở trên cùng ngay dưới thanh trạng thái** (ô tìm vẫn ở đáy), **iPad ngay dưới ô tìm, căn giữa** (rộng 426pt trên 26.5, 534pt trên 27). Đúng như video Apple Music của anh trên cả hai máy. Đặt lựa chọn bằng code không gọi delegate, nên cầu nối một chiều an toàn. ⇒ **Dùng native ở iOS 26+ chế độ native** (theo Q1), Flutter ở mọi nơi khác.
> - **`LiquidSegmentedControl` (mới, public):** đo đúng `UISegmentedControl` iOS 26.5: cao 32, viên chọn thụt 2pt (rộng = ô − 4, cao 28), chữ 13pt (Regular, ô chọn Medium), nền rãnh xám trong (#767680 12% sáng / 24% tối), viên chọn trắng (sáng) / #EBEBF5 30% (tối). iOS 27 giống hệt.
> - **Chuyển động đo từ native:** chạm thì chọn **khi nhấc tay**, viên trượt bằng lò xo ζ 0.87 / 0.41 s, hoá thấu kính kính trong, phồng (1 ô: cao ×1.35; 2 ô: cao ×1.79), vượt 2.5–5pt rồi rung nhẹ "thạch" ±10% và đứng sau ~0.85 s. Giữ: thấu kính lớn thêm +24 × +16 (119×28 → 143×44) trong 0.25 s. Kéo: thấu kính theo ngón (cùng lò xo kéo của thanh tab, trễ 6.8pt ở 82pt/s), chọn khi thả. Đổi bằng code: trượt êm, không phồng. Không có quầng sáng, không phồng cả thanh (khác thanh tab).
> - **Tái dùng động cơ thấu kính VK-503,** không chép: `LensMotion` nhận một "đường ray" (`LensTrack`: thanh tab hoặc các ô) và một "hồ sơ" (`LensProfile`: lò xo và hình dạng; thanh tab giữ nguyên số cũ, ô phân đoạn dùng số đo mới). `LiquidLens`, `LensGestureRecognizer`, shader dùng nguyên.
> - **Nghiệm thu bằng số đo native:** bảng vết (trace) Flutter so với bảng vết native đo từng khung hình, cộng ảnh từng khung hình native/Flutter đặt cạnh nhau. Không dò lại hằng số của chính mình.
> - **6 câu hỏi mới** ở bảng cuối (đều có mặc định): chấp nhận dáng native của thanh phạm vi (iPhone 26.5 nằm trên một dải nền phẳng), rãnh phẳng hay kính cho bản Flutter, hộp 44pt, cỡ chữ lớn, mô hình "thạch", chỉ chữ (chưa icon).

---

## 1. Goal

Two outcomes:

1. **The search tab's scope bar has Liquid Glass.**
   - On iOS 26+ with native chrome engaged, UIKit draws it: the real `UISearchBar` scope bar, with the native lens (Q1, §10).
   - Everywhere else (Android, iOS < 26, a forced glass tier, native chrome off), Flutter draws it with `LiquidSegmentedControl` (Q5, §11).
2. **`LiquidSegmentedControl`, a public, reusable control** that matches iOS 26.5's standalone `UISegmentedControl` at rest and in motion, within the numeric tolerances of §14 (Q2, Q3). It is used by the scope bar and can be used anywhere in an app.

## 2. Scope

### 2.1 In this item

| # | Item | Section |
|---|---|---|
| S1 | The native reference: the remaining captures after the spike, the fixture `docs/qa/vk550/native_reference.json` | §3, §14.4 |
| S2 | Generalise the lens engine: `LensTrack`, `LensProfile`, `LensTicker`, `LensClip` | §4 |
| S3 | Segment geometry (pure): full width, intrinsic, RTL, text scale, 44 pt targets | §5 |
| S4 | Rest appearance and theme tokens, light and dark | §6 |
| S5 | The segment lens: `LiquidLens` reused, tier-aware | §7 |
| S6 | Interaction: springs, flight shape, wobble, drag and flick, commit on release, programmatic slide, guard | §8 |
| S7 | Haptics | §9 |
| S8 | The native scope bar on iOS 26+: Pigeon, platform interface, `SearchBridge`, `ShellSearch` | §10 |
| S9 | `LiquidSearch.scopes`, `LiquidSearchScopeBar` as a wrapper, `LiquidShellScopeData.nativeSearchScopes` | §11 |
| S10 | Accessibility and fallbacks: semantics, reduce motion, RTL, text scaling, reduce transparency, tiers | §12 |
| S11 | Example updates: the search case, a new segments case, a native reference screen for the strips | §13 |
| S12 | Acceptance tooling: segment traces, frame strips, comparison | §14 |
| S13 | Docs, CHANGELOG ×4, version `0.1.0-dev.7` | §15 |

### 2.2 Non-goals

- **Image segments, per-segment widths (`apportionsSegmentWidthsByContent`), momentary mode.** `LiquidSegment` leaves room for them (Q-F).
- **An iOS 27 look for the Flutter control.** The standalone control measured identical on 27.0 at rest; its motion was not traced. The scope bar's iOS 27 variant (36 tall, 15 pt labels, glass track) is UIKit's own in native mode and is not imitated in Flutter mode (Q-B).
- **Native `UISegmentedControl` anywhere but the search scope bar.** There are no platform views in this package; a segmented control in app content is Flutter-drawn on every platform, iOS 26 included.
- **The iPad sidebar, dialogs and other surfaces.** Unchanged.

## 3. Reference behaviour (summary of the spike)

### 3.1 Q1: the native scope bar (spike §1)

| Setup | iPhone 26.5 | iPhone 27.0 | iPad 26.5 | iPad 27.0 |
|---|---|---|---|---|
| `scopeBarActivation = .automatic` (UIKit's default) | not shown | not shown | in the tree, not drawn | in the tree, not drawn |
| `.onSearchActivation` | top | **not shown** | under the field | under the field |
| `.manual` + `setShowsScope` toggled by `willPresent` / `willDismiss` | **top** | **top** | **under the field** | **under the field** |

- **Placement with the chosen setup.** iPhone: `16, 64, 370 × 32` (26.5) / `16, 62, 370 × 36` (27.0), under the status bar, while the field stays at the bottom and the large title is hidden. iPad: centred under the risen field, `426 × 32` (26.5) / `534 × 36` (27.0).
- **Against Apple Music** (the owner's P3b videos): Music shows its scope at the top on iPhone and under the field on iPad. The chosen setup matches both.
- **Bridge.** A user tap reports once, at touch-up; a drag reports once, at release. A programmatic `selectedScopeButtonIndex` does not call the delegate. Tapping a scope keeps the search active.

**Decision (Q1):** the native scope bar is used on iOS 26+ native chrome, with the `.manual` + toggle setup. The default setup is unusable on all four devices; the spike records why.

### 3.2 `UISegmentedControl`, iOS 26.5 (spike §2, §3)

| Topic | Native | Spike |
|---|---|---|
| Track | 32 tall, capsule; fill #767680 @ 0.12 (light) / @ 0.24 (dark) | §2 |
| Segments | equal widths; full width = the layout width; intrinsic = widest Medium label + 18, min 32 | §2 |
| Thumb at rest | `_UILiquidLensView`, inset 2: (segment − 4) × 28, radius 14; #FFFFFF / #EBEBF5 @ 0.30; no shadow | §2 |
| Labels | 13 pt, Regular / Medium selected, label colour, centred | §2 |
| Disabled | alpha 0.5 | §2 |
| Tap | commit at touch-up; x ζ 0.87, 0.41 s, +8 ms; engage within ≈ 50 ms; one-segment lift h ×1.33–1.40, two-segment lift h ×1.79; overshoot 2.5 / 4.9 pt; size wobble ±10 %, settled ≈ 0.85 s | §3 |
| Press | +24 × +16, critically damped 0.25 s, 24 ms delay | §3 |
| Release in place | critically damped 0.24 s, 16 ms delay | §3 |
| Drag | follows x; lag 6.77 pt at 82.2 pt/s (VK-503 `dragFollow` predicts 6.45) | §3 |
| Fast drag | squash: h ×1.13 of pressed, w −12 % at ≈ 800 pt/s | §3 |
| Drag release | commits the segment under the lens at release; overshoot then wobble | §3 |
| Programmatic | slides (ζ 0.82, 0.41 s), no engage, no resize, no `valueChanged` | §3 |
| No glow, no bulge, no lens highlight | no `LittleGlowView`; the control's layer never scales (a held unselected label fades, §8.3) | §2, Task 1 |
| Haptics | not observable on the simulator | §3 |

Still to capture (plan Task 1): a held press on an unselected segment, dark traces and the engaged lens's colours, label magnification under the lens, the refracting ring width, the flick landing, five segments, RTL, accessibility sizes. The spring of the lens after a drag release is not a capture: Task 4 fits it to the fixture's `slow_drag.release_rows` and `flick` rows (§8.2).

## 4. Architecture

```
lib/src/chrome/
  lens_track.dart        (new)  LensTrack: the slots a lens moves over (TabBarGeometry, SegmentGeometry)
  lens_profile.dart      (new)  LensProfile: springs + envelope; LensProfile.tab (= TabSprings), LensProfile.segment
  lens_motion.dart              LensMotion(track:, profile:): unchanged behaviour for the tab profile; up(canCommit:) skips disabled slots; follow(selected) accepts or shows the app's selection for both widgets
  lens_ticker.dart       (new)  LensTicker: the Ticker loop, crossings → selectionClick, accept / return, trace hook; lensTraceSample (both widgets' trace)
  lens_clip.dart         (new)  LensClip (moved from glass_tab_bar.dart's _LensClip)
  tab_springs.dart              unchanged; LensProfile.tab reads it
  tab_geometry.dart             TabBarGeometry implements LensTrack
  glass_tab_bar.dart            uses LensTicker and LensClip (refactor, no behaviour change)
  lens_gesture.dart             reused; + claimsDragAt (a horizontal scroller around a segmented control, §8.1)
  large_content_viewer.dart     reused; the icon becomes optional (a text segment has none)
  sized_layout_builder.dart     (new, Task 7 review) a LayoutBuilder that answers intrinsics, dry layout and the dry baseline from the geometry
lib/src/segmented/       (new)
  segment_geometry.dart         pure: SegmentMetrics, SegmentGeometry (implements LensTrack), segmentGeometry()
  segmented_control.dart        LiquidSegment, LiquidSegmentedControl (public); painters
lib/src/glass/
  liquid_lens.dart              + optional bezel (default kLensBezel); reused as is otherwise
  glass_theme.dart              + segmentTrack, segmentThumb, segmentLabelStyle
lib/src/search/
  scope_bar.dart                LiquidSearchScopeBar → LiquidSegmentedControl, or nothing when native shows the scopes
  search.dart                   + LiquidSearch.scopes
  shell_search.dart             + scope sync with the native bar
liquid_shell_platform_interface: LiquidNativeSearchConfig.scopes, setNativeSearchScope, LiquidNativeSearchScopeChanged
liquid_shell_ios: pigeon (scopes, setSearchScope, onSearchScopeChanged), SearchBridge (scope bar), mapping, platform
```

- **Generalise, don't copy (Q3).** `LensMotion` today takes a `TabBarGeometry` and reads `TabSprings` constants directly. It is changed to take any `LensTrack` and a `LensProfile`. `LensProfile.tab` carries exactly the `TabSprings` values, so the tab bar's behaviour does not change: `lens_motion_test.dart`, `tab_gesture_test.dart`, `glass_tab_bar_test.dart` and `make tab-traces` are the regression gate of that refactor. `LensProfile.segment` carries the spike's numbers.
- **One ticker loop.** `GlassTabBar`'s `_onTick` (advance, crossings → haptics, accept or return, trace) moves into `LensTicker`, used by both widgets. The tab bar keeps its minimize motion around it.
- **Pure first.** Segment geometry and the segment profile are pure Dart, unit-tested to the spike's numbers before any widget exists.
- **Seam.** The engaged thumb is a `LiquidLens` (in `lib/src/glass/`); the track and the rest thumb are plain fills (native's are fills, not glass, spike §2). `tool/check_glass_seam.sh` stays green.
- **Public API.** New: `LiquidSegmentedControl`, `LiquidSegment`, `LiquidSearch.scopes`, `LiquidShellScopeData.nativeSearchScopes`, three `LiquidGlassTheme` fields. `LiquidSearchScopeBar` keeps its constructor; `scopes` becomes optional. `LensTrack`, `LensProfile`, `LensTicker`, `SegmentGeometry` and the debug hooks stay in `src/` (§13).

## 5. Geometry (S3)

All values are logical points; "control-local" means the `LiquidSegmentedControl` box. Segments are listed in **index order**; in RTL their x positions are mirrored, so segment 0 is at the right (as `UISegmentedControl` under `semanticContentAttribute = .forceRightToLeft`; **measured in Task 1**: under a forced RTL launch segment 0 is drawn at the right, its thumb at 248, 2, 120 × 28 in a 370 control, and a tap at the left commits index 2).

| Quantity | Value |
|---|---|
| Track height `H` | **32** at text scale 1; `max(32, lineHeight + 16.33)` above it (§12.3) |
| Box height | **max(44, H)**: the track is centred in a 44 pt box, so every segment keeps a 44 pt target (owner rule; Q-C) |
| Track width `W` | `expand: true` (default): the incoming max width, always; below 44 pt per segment every segment shrinks equally to fit, as native's (owner decision, Task 7): no overflow, no clipping, labels ellipsize. `expand: false`: `n · s` with `s = max(44, ceil(widestMediumLabel) + 18)` (native min is 32; Q-C); in a parent narrower than that, the fill layout of the parent's width (segments shrink to fit, never cut off). Under an unbounded width either mode sizes to the labels. The control answers intrinsic sizes (`SizedLayoutBuilder`, not a bare `LayoutBuilder`, Task 7 review) |
| Segment `i` (visual) | `Rect(i · W/n, (box − H)/2, W/n, H)`, mirrored in RTL |
| Thumb `i` at rest (the lens track's slot) | segment `i` deflated by **2**: `(W/n − 4) × (H − 4)`, radius `(H − 4)/2` |
| Label box | centred in the segment, `lineHeight` tall, max width `W/n − 2·9` **(assumption: the 18 pt intrinsic padding)**, one line, ellipsis |
| Hit area of segment `i` | the full 44 pt box height × the segment's width; no gaps. Below 44 pt per segment (`expand: true` in a narrow width), hit targets follow the segment width |
| Pressed lens | thumb + **(24, 16)**, centred on the lens x (spike: 119 × 28 → 143 × 44; 181 → ≈ 205) |

Worked checks against spike §2 (iPhone 17 Pro, full width 370):

- 3 segments: segments at 0 / 123.33 / 246.67, thumbs 119.33 × 28 at x 2 / 125.33 / 248.67. Native rounds to 123 / 123 / 124 (thumbs 119 / 119 / 120): inside ±1.
- 2 segments: thumb 181 × 28. Native 181.
- 5 segments: thumb 70 × 28. Native 70.
- Intrinsic "All | Songs | Places": `s = max(44, ceil(40.67) + 18) = 59`, `W = 177`. Native 177. "All | Recently played": `ceil(97.7) + 18 = 116` against native 117 (±1). "A | B | C": 44 against native's 32 (the 44 pt rule, documented): the control is 132 wide where native's is 96 (`native_reference.json` `geometry.intrinsicABC`), an **intended difference** (Q-C, owner-approved).

`SegmentGeometry` implements `LensTrack` (§8): `slots` are the rest thumbs, `centreOf`, `slotNearest`, `clampCentre` (first to last thumb centre), `restLensAt(x)` (the thumb size; constant, since segments are equal).

## 6. Rest appearance (S4)

| Part | Light | Dark | Theme field |
|---|---|---|---|
| Track | #767680 @ 0.12 | #767680 @ 0.24 | `LiquidGlassTheme.segmentTrack` |
| Thumb at rest | #FFFFFF | #EBEBF5 @ 0.30 | `segmentThumb` |
| Labels | #000000, 13 pt, w400 (in the system font, UIKit's tracking: §6 below); selected and under the lens w500 | #FFFFFF | `segmentLabelStyle` (colour, size, weight of unselected) |
| Disabled control | the whole control at opacity 0.5 | same | none |
| Disabled segment | its label at opacity 0.5 **(assumption)**; not tappable, not a drag target | same | none |

- **Tracking (Task 15, review).** UIKit tracks its system font by size (Apple's SF Pro table: −6/1000 em at 13 pt, −0.078 pt); Flutter's text engine does not, so without it the labels measured about 0.1 pt per glyph wider than native's on the iOS 26.5 simulator ("Places" w500 41.27 against 40.67) and the intrinsic "All | Songs | Places" was 180 pt against 177. A label in the system font (an Apple platform, and the SF families or none) takes SF Pro's tracking for its drawn size (`sfTracking`, the table, so it follows the text scale, which Flutter does not apply to a `letterSpacing`); a `segmentLabelStyle.letterSpacing` wins; an app's own font, or Android's, keeps its spacing. With it: 177, and "All | Recently played" 234 (native 234).
- **Defaults** come from `LiquidGlassTheme.fromColorScheme(brightness)`; apps override them through `LiquidGlassTheme` (copyWith, lerp, `==` like the VK-503 fields).
- **The selected label.** As the tab bar's tinted copy (VK-503 §6.3), the row is drawn twice: a normal row (w400) with the lens punched out (`LensClip(inside: false)`), and a w500 row clipped to the lens (`LensClip(inside: true)`). At rest the lens sits on the selected segment, so its label reads w500; while a drag straddles two segments, each half shows its own weight, as native's `ContentLensingView` does. The w500 copy has no colour change (native labels stay label-coloured).
- **Magnification** of the w500 copy at full engage: **1.0** (measured in Task 1: the label's ink box is the same at rest and under the held lens, and no label or `ContentLensingView` layer scales; `native_reference.json` `lens.labelMagnify`).
- **No shadow, no rim** at rest (none in the native tree).
- **The track is not glass.** Native's standalone track is a translucent fill over the page; Q-B offers a glass track instead for the scope bar.

## 7. The segment lens (S5)

- **Liquid tier.** While `engage > 0`, the thumb is `LiquidLens(refraction:, engage:, restFill: segmentThumb, look: LensLook.segment)` over the lens rect: the VK-503 second glass pass with the segment's own optics (`LensProfile.segment.look`) and one uniform of its own, the squeeze (below). At `engage = 0` it is the rest thumb.
  - **Look (Task 15, review).** Native's held lens is clear glass: the page and the track pass with their colours (core chroma 0.965 of the page's, about 3 % darker, light and dark), squeezed to about 0.8 across the height, bent a few points at the ring with a colour fringe, under a 1 pt bright rim (`native_reference.json` `lens.look`, measured on the segment strips; the look is tuned to these numbers: native, fitted). `LensLook.segment`: a black veil at 0.04 with no falloff, saturation 1 (the shared 1.1 boosted the stripes), squeeze 0.22, thickness 0.2 × 48 pt, dispersion 1, no blur, a white rim at 0.5 over 1 pt, bezel 9. Rendered under Impeller (`liquid_test.dart`, against `lens.look`): core chroma 0.96 (native 0.965), squeeze 1.226 (1.225 / 1.231), ring bend 3.1 / 3.0 pt (3.0 / 3.4). The VK-503 tab look made a milky core (white veil 0.9) and a thick black rim: its thickness (1.6 × 48 pt) bends a ray up to 59 pt inward, past a 44 pt lens, where the backdrop holds nothing. The tab's look is unchanged (`LensLook.tab`, its goldens byte for byte).
  - **The squeeze (Task 15 review, owner approved).** Native's lens reads the page farther out than the point it covers: grid lines 15 and 45 px from the spine show at 12 and 36.5 (the spike's grid shot), a scale of about 1.23 across the height and almost none along it, out to the edge. The VK-503 shader can only bend inward inside its bezel (it magnifies), so it gains one uniform, `uSqueeze` (float 27, `LiquidOpticsParams.squeeze`): a point at u from the spine (the centre line of a capsule) reads the page at (1 + uSqueeze) u. 0 (every other surface) takes the old path, so their pixels are byte for byte as before (Impeller test). Only `LensLook.segment` sets it (0.22, scaled by the refraction). At the edge it reads the page 0.22 × the radius beyond the lens, as native's does; the strips show no artefact there.
  - **From clear glass (R8, Task 15).** The tab lens sits on the pill's glass, so at a low engage it is that glass. The segment lens sits on a flat track: faded from the tab pill's dark glass (#1C1C1C at 0.90) it was an opaque grey pill for about 200 ms at the start and end of every engagement in dark. It fades from clear, unrefracted glass, so at a low engage it is its rest fill over the page.
  - **One rest fill (R8, Task 15).** While the lens is drawn the control draws no rest thumb under it; the lens draws the rest fill (at `1 − engage`) in every tier. Before, the fill was drawn twice during the ≈ 50 ms engage and the 0.11 s release, once under the lens (captured and refracted) and once by it. Native cross-fades one thumb into the glass.
  - **First engage.** The first engaged lens after launch dropped a frame in the trace runs (33–50 ms). They are debug (JIT) builds: warming the lens pipeline did not remove it, and a lens drawn at mount moved it to the release, so the trace driver taps there and back once before recording, and the first engage after launch is not measured. Profile mode does not run on a simulator, so a release build's first engage is unmeasured; no product warm-up ships (an owner check on a device).
  - The control opens its own `BackdropGroup` (as a standalone `GlassTabBar` does), with one key for its life, so the lens samples the control and the page behind it, not an enclosing page's stale capture. No glass paints before the lens, so the group's one capture happens at the lens's first paint: it **includes the track** fill under the lens (and the fading rest thumb; the labels are clipped away). This is native's own look (`_UILiquidLensView` sits above the track inside `UISegmentedControl`, and UIKit glass samples what is beneath it): Task 15's strips and the spike's grid shot show the track through native's held lens, so it stays. Since Task 15 the fading rest thumb is not drawn under the lens (above), so it is not captured.
  - **Bezel.** VK-503's 14 pt ring is sized for a 70 pt-tall lens. The segment lens is 44 tall, so its bezel is **9 pt (assumption: 14 × 44/70 rounded)**; Task 1 measured native's ring at 8.3 (top) to 9.0 (bottom) pt, mean 8.7 (`lens.bezel`), which agrees with 9 within the spread; Task 15 kept 9 against the strips. `LiquidLens` takes a `look` (default `LensLook.tab`), which carries the bezel; the tab bar is unchanged.
- **Frosted and solid tiers.** `LiquidLens`'s own frosted and solid variants (VK-503 §7.3).
- **Reduce transparency / increase contrast.** The rest thumb only, no lens pass (VK-503 §13.3 rule).
- The lens is drawn above the track and the normal row, below the w500 row, inside the control's bounds widened by the lens overflow (the pressed lens is 44 tall over a 32 track: it overflows by 6 pt above and below, inside the 44 pt box).

## 8. Interaction (S6)

### 8.1 Engine reuse

- **Track.** `LensTrack` is the interface `LensMotion` needs from geometry: `slots`, `centreOf`, `slotNearest`, `clampCentre`, `restLensAt`, and `tapInflation` (the VK-503 iPad top bar's ×1.34 / ×1.375; null elsewhere). `TabBarGeometry` implements it unchanged.
- **Profile.** `LensProfile` holds every spring and envelope constant `LensMotion` reads today, plus the segment-only switches below. `LensProfile.tab` is built from `TabSprings` (identical values; a unit test pins each field).
- **Gestures.** `LensGestureRecognizer`, reused: eager on pointer down unless a vertical scroll view encloses the control or AX sizes are on, as in VK-503 §8.6.
- **Inside a horizontal scroller** (a `PageView`, a horizontal row of chips; Task 8 review, owner rule): native gives the control a drag that starts on the thumb, and any other drag scrolls the page. So under a horizontal `Scrollable` the recognizer claims a drag (and wins on touch-down) only when the touch comes down in the selected segment's column (`claimsDragAt`); a touch elsewhere waits for the up, so a horizontal drag goes to the scroller (the lens returns, nothing commits) and a tap still commits. With nothing selected there is no thumb: every drag scrolls. The tab bar passes no `claimsDragAt` and keeps VK-503's rule.

### 8.2 Springs (`LensProfile.segment`)

| Use | ζ | Response | Delay | Source |
|---|---|---|---|---|
| Lens x after a tap | two springs blended (Q-E): primary **0.751 / 0.577 s**, secondary **0.623 / 0.285 s** at a 0.286 share | | primary 14.4 ms, secondary 32 ms after the commit | Task 4, fitted to all five tap captures on the engage-aligned clock (§14.5): every row within 1.8 pt, overshoot within 0.55 pt, settled +0.70 s. The spike's single spring (0.87, 0.41 s, 8 ms) overshoots 0.5 / 1.0 pt where native does 2.5 / 5.0 |
| Lens x following the finger | 0.75 | 0.33 s | none | VK-503 `dragFollow`; spike lag within −5 % |
| Lens x after a drag release (and a flick) | **0.785** | **0.585 s** | none | Task 15, fitted to both native landings: `flick` overshoot 4.40 pt (native 4.04), lowest +0.229 s (0.221), settled +0.493 s (0.503); `flickLanding` as the simulator drives it, median overshoot 3.11 pt over the frame phases (native 3.86; 2.71 to 3.65 by phase). Native's overshoot barely changes with speed and a linear spring's does, so one spring shares the error; Task 8's 0.80 / 0.59 s put them at 4.10 and 2.85 (the device row on its ±1 pt edge). `slow_drag.release_rows` within 2 pt. Task 4's 0.64 / 0.31 s matched the overshoot but bottomed out 31 % and settled 47 % early |
| Programmatic slide | **0.82** | **0.41 s** | **30 ms** after the write | spike §3; Task 4 fits the delay to `programmatic_2seg` (every row within 1.6 pt) |
| Size, press (w and h) | **1.0** | **0.25 s** | **24 ms** after the down | spike §3 |
| Size, release in place | **1.0** | **0.24 s** | 16 ms | spike §3 |
| Size wobble after a landing | **0.48** | **0.47 s** | none | Task 4 fitted 0.42 with the lifts (§8.4); the Task 15 review refitted it with the direction rule on the fixture's taps and the fitting split of `native_taps.json` (31 taps): every peak h and wobble extreme within 10 % but the w swing after a long tap to the right on five segments (+13 to +15 %) |
| Lens area after a tap's lift | **0.80** | **0.36 s** | none | Task 15: the area wobble (§8.4), fitted to `tap_1_2`, `tap_3_1`, `tap_1_3_5seg` from +0.25 s |
| Engage in / out | 1.0 | 0.065 / 0.20 s | as VK-503 | spike: 0 → 1 within ≈ 50 ms; held 0.335 s after a tap's commit and 0.11 s after an up (Task 4, the tap and release rows) |

### 8.3 States and events

The state machine is VK-503's (§8.2: rest, pressed, dragging, flying, settling). Per event, for the segment profile:

| Event | Lens x | Size | engage / refraction | Commit |
|---|---|---|---|---|
| **down** at x | holds. On the selected segment the lens grows (next columns). On **another** segment nothing moves until the up (measured in Task 1, `pressOther`: no lens frame changes for the whole 2.16 s hold; the pressed segment's w400 label fades to opacity 0.2 over ≈ 0.45 s); the up then takes the tap path | selected segment: thumb + (24, 16) after 24 ms on the press spring; another segment: rest | selected segment: 1 / 1 after 24 ms; another segment: 0 | none |
| **move** beyond the slop | `clampCentre(x)` on `dragFollow` | pressed, plus the speed squash (§8.4) | 1 / 1 | none |
| **up, tap** (travel ≤ slop) | the segment under the finger, on the tap spring, 8 ms after the up | flight shape (§8.4) | 1 until 0.30 s after the commit, then out | **at the up** |
| **up after a drag** | the segment nearest the *lens* centre (as native and VK-503); after a flick (≥ 600 pt/s, VK-503's reading) the segment under the *finger* | release spring; a fast release lands with the wobble (§8.4: `flick` w ×1.10 / h ×0.88), a slow one without (`slow_drag`, within ±2 pt) | out 0.11 s after the up (Task 4, `release`, `slow_drag`, `flick`) | **at the up** |
| **cancel** | the committed segment, release spring | rest | out | none |
| **semantics tap** | the tap path without a press | flight shape | as a tap | at once |
| **programmatic** (`selectedIndex` changed by the app, no pending commit) | slides on the programmatic spring | rest | 0 | none (no `onChanged`) |
| **reduce motion** | §12.2 | | | |

- **Commit and guard** (VK-503 §8.7). The control is controlled: `onChanged(i)` fires at the commit, and the app is expected to rebuild with `selectedIndex: i`. When the lens settles and `selectedIndex` is still another value, the lens returns to it on the release spring (a refused change). A tap on the selected segment lifts and lands in place and calls nothing (native sends no `valueChanged`, measured in Task 1, `tapOnSelected`: the lens grows to ≈ 143 × 44 in place and is back at rest by ≈ 0.5 s).
- **Disabled segments.** A tap on one does nothing; a drag never commits it (the release picks the nearest enabled segment); the lens may pass over it.
- **No glow, no pill scale, no lens highlight, no pop** for the segment profile (spike §2): the profile's switches turn them off; `LensFrame` reports 0 / 1 for them.
- **The held label fades** (Task 1, `pressOther`; the one press feedback native shows outside the lens): while a finger holds an enabled, unselected segment and the lens stays at rest, that segment's w400 label fades to opacity **0.2** over **0.45 s** (ease in-out, assumption: the curve was not measured). It is back at 1 at once on the up, on a cancel, or when the press turns into a drag (assumption: native's return was not captured).

### 8.4 Flight shape, squash and wobble (model)

As VK-503 Q18, a two-spring model (width, height) matched at its peaks and settle, not frame by frame (Q-E):

- **Tap flight** (`age` from the commit): the height target is `rest.h · (1 + a)` until `t`, then rest; the width target is `rest.w · (1 + b)` over the same window. Task 4 fits two shapes to the spike's rows: wide (h ×1.37, w ×1.31 to +0.235 s) and tall (h ×1.78, w held to +0.215 s). **By direction on screen (Task 15 review):** the shape follows the direction the lens goes on screen and nothing else: to the right it is wide, to the left tall, whatever the distance (74 to 296 pt) or the target segment. `native_taps.json` (two, three and five segments, LTR and RTL; fitting split and holdout split fixed before looking) separates them: 5-segment taps 4→3 and 3→2 (left, not to the first segment) lift tall (47.9), RTL taps to segment 1 (to the right on screen) wide (39.2), RTL taps away from it tall. Task 15's first rule (by distance) was wrong to the left: its holdout showed it (`dark.tap_2_1`, `tap_3_1_5seg`).
- **Wobble.** After the lift the size heads back to rest; the native shape is w ×0.91 / h ×1.11 after a lift to the right and w ×1.14 / h ×0.83 after one to the left, settled by ≈ 0.85 s. **Area (Task 15):** native keeps the lens's area within 4 % of rest from +0.45 s, so a lens that narrows grows taller and one that flattens grows wider. The side the lift stretched most returns on the wobble spring; the area returns on its own spring (0.80 / 0.36 s); the other side is the area over the first. Task 4's two independent springs missed `tap_3_1`'s wide, flat landing (w 119.5 against 136.1, −12 %) and let a one-segment tap's height dip to 25.7 where native's stays at 31; now 136.1 (native 136.1) and 30.0 (31.4) on the device, with the wobble refitted to 0.48 (§8.2).
- **Landing after a fast drag release** (Task 8 review, owner Q-E): the same hand-off. Once the lens x passes its target, the size heads for rest × (1 + 0.16·s, 1 − 0.21·s) on the press spring for 0.2 s, then the wobble spring takes it back to rest. `s` is the drag squash's own speed scale at the up (0 below the 200 pt/s knee, 1 where the squash saturates), so a slow drag has no landing. Against `flick` (each within ±10 %, `segment_gesture_test.dart`; Task 15's release spring): overshoot 4.40 / 4.04 pt, lowest point +0.229 / +0.221 s, settled +0.493 / +0.503 s, w swell +9.9 % / +10.3 %, h dip −12.8 % / −12.3 %, both at +0.335 s as native's. `flickLanding` (another capture) bottoms out at +0.283 s; the fit follows `flick`, whose drag and landing the test replays.
- **Speed squash while dragging.** Height target `pressed.h · (1 + k·max(0, |v| − v0))`, width `pressed.w · (1 − k'·max(0, |v| − v0))`, clamped to ×1.13 / ×0.88 (spike: at ≈ 800 pt/s). Task 4 fits `k`, `k'`, `v0`.

These are the only tuning knobs (as VK-503 §8.3); every one is fitted in Task 4 against the fixture and pinned by `lens_motion_test.dart`.

### 8.5 Semantics

- Each segment is a node: `button: true`, `inMutuallyExclusiveGroup: true`, `selected: i == selectedIndex`, `enabled` per segment and control, `label: segment.semanticLabel ?? segment.label`, `onTap` (the semantics tap path) when enabled.
- The control is a container with an optional `semanticLabel`; the order is visual order in LTR and RTL.
- **Keyboard** (as the VK-503 tab bar after its keyboard fix): each enabled segment takes focus (Tab, Shift-Tab and the arrow keys, in visual order) and shows a 2 pt ring in the theme's primary colour around its thumb; Enter or Space activates it once, on the semantics tap path (nothing for the selected segment). Touches never reach these actions: they go to the control's one recognizer, and no touch moves the focus (a text field elsewhere keeps it).

## 9. Haptics (S7)

Q3 (owner): `HapticFeedback.selectionClick()` once per segment boundary the lens crosses **while dragging**; none on a tap, a release or a programmatic change. `LensMotion.takeCrossings()` already reports crossings; `LensTicker` plays them for both widgets. Native's own behaviour is not observable on the simulator (spike §3); the owner checks it on a device.

## 10. The native scope bar (S8, Q1)

### 10.1 Behaviour

- **When.** iOS 26+, native chrome engaged, a search destination, and `LiquidSearch.scopes` with ≥ 2 titles. Otherwise nothing changes natively.
- **UIKit setup** (`SearchBridge`): `searchBar.scopeButtonTitles = scopes`, `controller.scopeBarActivation = .manual`, and `searchBar.setShowsScope(true, animated: true)` in `willPresentSearchController`, `false` in `willDismissSearchController` (spike §1, the only setup drawn on all four devices). `nil` scopes clear `scopeButtonTitles` and hide the bar.
- **Selection.** `selectedScopeButtonIndex` is set from Dart's `scopeIndex` (clamped to the titles) on install, on a config change and on `setSearchScope`. A user change reports through `searchBar(_:selectedScopeButtonIndexDidChange:)`.
- **Insets.** The scope bar is part of the navigation bar (iPhone: under the status bar; iPad: under the field). The native host already re-reads the resting top of the search tab's page after the search presents (`rereadRestingTop(force: true)` in `onActive`); Task 11 checks that Flutter's `chromeInsets.top` then covers the scope bar on both devices, and adds a re-read after `setShowsScope` if it does not.

### 10.2 The one-way bridge

| Direction | Message | Rule |
|---|---|---|
| Dart → native | `NativeSearchConfig.scopes` (`List<String>?`) | in the chrome config, like the placeholder |
| Dart → native | `setSearchScope(int index)` | the app changed `scopeIndex` (`SearchDriver.scopeSetByApp`); also replayed when the search tab is entered natively (`ShellSearch.afterConfigSent`, as the text) |
| native → Dart | `onSearchScopeChanged(int index)` | only a user change: the delegate call, gated by `canReport` (the search tab is selected and Dart's config is not being applied) and deduped against the last index Dart wrote or native reported (`known`, as the text) |
| Dart | `ShellSearch.onNativeEvent(LiquidNativeSearchScopeChanged)` | ignored unless the search tab is selected; deduped against `controller.scopeIndex`; applied with `applySearchEdit` (the field's own edit: never goes back to the field) |

A programmatic `selectedScopeButtonIndex` does not call the delegate (spike §1), and the bridge dedupes anyway, so nothing echoes.

### 10.3 Flutter's scope bar in native mode

`LiquidShellScopeData.nativeSearchScopes` is true while native draws the scope bar (native chrome engaged, scopes given, iOS 26+). `LiquidSearchScopeBar` then builds nothing (`SizedBox.shrink`), so the app's page needs no branching. The native scope bar shows only while the search is active (UIKit, Music); an inactive search with a kept query shows no scope bar in native mode (Q-A).

## 11. `LiquidSearchScopeBar` and `LiquidSearch.scopes` (S9)

```dart
class LiquidSearch {
  const LiquidSearch({
    required this.controller,
    this.placeholder,
    this.scopes,          // new: ≥ 2 titles, or null
    this.onChanged,
    this.onSubmitted,
  });
  /// Scope titles ("All", "Songs", "Places"). Native chrome on iOS 26+ shows
  /// them in UIKit's scope bar while the search is active; elsewhere
  /// LiquidSearchScopeBar shows them. Bound to controller.scopeIndex.
  final List<String>? scopes;
}

class LiquidSearchScopeBar extends StatelessWidget {
  const LiquidSearchScopeBar({required this.controller, this.scopes, super.key});
  /// Titles; null reads the enclosing shell's LiquidSearch.scopes.
  final List<String>? scopes;
}
```

- **Flutter mode:** `LiquidSegmentedControl(segments: titles, selectedIndex: scopeIndex.clamp(…), onChanged: (i) => controller.scopeIndex = i, expand: true)`.
- **Native mode with scopes:** nothing (§10.3).
- `LiquidSearchScopeBar(scopes: …)` given explicitly keeps working (P3b API); when both are given they must be equal (debug assert).
- `LiquidSearchController.scopeIndex = i` now also tells the driver (`SearchDriver.scopeSetByApp`), so native follows the app.

## 12. Accessibility and fallbacks (S10)

### 12.1 Light, dark, RTL

- Light and dark come from §6's defaults per brightness; both are in the goldens and the strips.
- RTL mirrors the segments (§5), the drag direction and the crossings; the semantics order is visual.

### 12.2 Reduce motion

As VK-503 Q11: a tap dissolves the rest thumb from the old segment to the new one in 150 ms (`ghostFade`), no slide, no lift, no wobble; a drag moves a rest-size thumb with the finger (direct manipulation) on `reduced` and snaps to the segment on release; programmatic changes jump.

### 12.3 Text scaling (Q-D)

- Labels follow `MediaQuery.textScalerOf(context)`, capped at **2.0** for the control.
- The track grows: `H = max(32, lineHeight + 16.33)`; the thumb inset stays 2; the pressed lens stays `+ (24, 16)`.
- A label that does not fit ellipsizes. At AX sizes (`isAxTextScale`, scale ≥ 1.6 on 14 pt, `kAxTextScale`) a long press shows the label in VK-503's `LargeContentViewer`, and the gesture recognizer is not eager (§8.1).

### 12.4 Hit targets

Every segment's tap area is its full width × the 44 pt box (§5). Neither mode overflows: `expand: true` fills the width it is given, and `expand: false` sizes segments to the labels (≥ 44 wide) but, in a parent narrower than that, also shrinks every segment equally to fit (owner decision, Task 7). Below 44 pt per segment, in either mode, hit targets follow the segment width. `test/widget` checks it with `meetsGuideline(iOSTapTargetGuideline)` (44 × 44). Android's 48 dp guideline is not claimed (Q-C).

### 12.5 Tiers

Liquid: §7. Frosted and solid: the lens variants of `LiquidLens`; the track and rest thumb are fills on every tier. The frame guard's demotion applies as for any glass (Q5).

## 13. Public API changes

| Change | Kind |
|---|---|
| `LiquidSegmentedControl`, `LiquidSegment` (new `src/segmented/segmented_control.dart`, exported `show LiquidSegment, LiquidSegmentedControl`) | additive |
| `LiquidGlassTheme`: `segmentTrack`, `segmentThumb`, `segmentLabelStyle` | additive |
| `LiquidSearch.scopes` | additive |
| `LiquidSearchScopeBar.scopes` optional (null: the shell's `LiquidSearch.scopes`) | additive |
| `LiquidSearchScopeBar` look: the liquid segmented control instead of a `primaryContainer` pill | **behaviour change** |
| `LiquidShellScopeData.nativeSearchScopes` | additive |
| Native chrome on iOS 26+: the scope bar is UIKit's when `LiquidSearch.scopes` is set | **behaviour change** (opt-in through `scopes`) |
| Platform interface: `LiquidNativeSearchConfig.scopes`, `LiquidShellPlatform.setNativeSearchScope`, `LiquidNativeSearchScopeChanged` | additive |
| `liquid_shell_ios`: Pigeon `NativeSearchConfig.scopes`, `setSearchScope`, `onSearchScopeChanged` | additive (generated) |
| `LensTrack`, `LensProfile`, `LensTicker`, `LensClip`, `SegmentGeometry`, `debugSegmentTrace`, `debugSegmentLensPress` | internal, in `src/`, **not exported** (`public_api_test.dart` gains rows) |

The packages are at `0.1.0-dev.6`. This item ships as **`0.1.0-dev.7`** for all four, and the CHANGELOGs list the behaviour changes.

## 14. Testing and acceptance

### 14.1 Unit (pure, `make test`)

- **`lens_profile_test.dart`:** every `LensProfile.tab` field equals its `TabSprings` constant; `LensProfile.segment`'s springs equal §8.2.
- **`lens_motion_test.dart`** (existing, tab): unchanged and green after the generalisation.
- **`segment_geometry_test.dart`:** §5's worked checks (2, 3, 5 segments at 370; intrinsic "All | Songs | Places" = 177, "A | B | C" = 132); RTL mirroring; text scale height; `slotNearest`, `clampCentre`; 44 pt box.
- **`segment_motion_test.dart`** (60 fps `advance(1/60)`, against the fixture):
  - tap one segment: settle time (0.5 pt) within ±10 % of the native tap fit (ζ 0.87, 0.41 s, 8 ms); overshoot ±1 pt of 2.5; peak h ×1.33–1.40 ±10 %; wobble extremes ±10 %;
  - tap two segments: peak h ×1.79 ± 10 %; overshoot ±1 pt of 4.9;
  - press 1 s: lens 143 × 44 ± 1 (three segments at 370), engage 1, 0.25 s settle ±10 %, no glow, pill scale 1;
  - drag at 82 pt/s: steady lag 6.77 pt ± 10 %; one crossing per boundary;
  - release after a drag: commits the segment nearest the lens; after a flick, the finger's;
  - programmatic change: slides, settle ±10 % of (ζ 0.82, 0.41 s), engage stays 0;
  - reduce motion: no lift, 150 ms dissolve;
  - a disabled segment is never committed.
- **`glass_theme_test.dart`:** the three new fields, defaults per brightness, `copyWith`, `lerp`, `==`.
- **`shell_search_test.dart`:** scope events dedupe; an app write sends `setSearchScope` once; a native event never sends one back; replay on entering native.
- **`search_test.dart`:** `scopeIndex` setter calls `scopeSetByApp`; `LiquidSearch.scopes` asserts ≥ 2.

### 14.2 Widget (`make test`)

- `segmented_control_test.dart`: segment, thumb and label rects equal the geometry (±0.01); w500 copy clipped to the lens; no `InkWell`; disabled control at 0.5 opacity and ignoring taps; semantics flags; 44 pt guidelines; RTL; text scale.
- `segment_gesture_test.dart`: a tap commits on up; a drag across two segments commits the nearest on release with one `selectionClick` per crossing (recorded through `SystemChannels.platform`) and none on a tap; cancel commits nothing; a refused change returns; a programmatic change slides and calls nothing; a semantics tap commits; the ticker stops at rest.
- `segment_lens_test.dart`: `LiquidLens` exists only while engaged, with `bezel` 9 and the control's own `BackdropGroup`; frosted and solid variants per tier.
- `scope_bar_test.dart`: Flutter mode builds a `LiquidSegmentedControl` bound to the controller; with `nativeSearchScopes` it builds nothing; `scopes: null` reads the shell's.
- Refactor guards: the existing `tab_gesture_test`, `glass_tab_bar_test`, `tab_effects_test`, `tab_trace_test`, `lens_layer_test` stay green unchanged.

### 14.3 Native and integration

- **XCTest** (`RunnerTests`, `make ios-unit`): `SearchBridge` sets `scopeButtonTitles` and `.manual`; `willPresent` shows and `willDismiss` hides the scope bar; a user change reports once; a Dart write reports nothing; out-of-range indices clamp.
- **Integration** (`native_search_test.dart`, `make integration-ios-native`, iPhone and iPad, iOS 26.5): with `scopes`, activating the search shows the native scope bar (debug snapshot gains `scopeTitles`, `scopeShown`, `selectedScope`); Flutter's `LiquidSearchScopeBar` builds nothing; the content top inset covers the scope bar.
- **XCUITest** (`SearchUITests`, `make ios-ui`): a real tap on "Songs" changes Flutter's results (scope 1); a real drag "Songs" → "Places" commits "Places" on release; the app's "reset scope" writes 0 and the native bar follows without a second report.

### 14.4 Goldens

- New `case_segments` images (rest): 2, 3, 5 segments, intrinsic, disabled, in light, dark and RTL, at text scale 1 and 2.
- New `liquid_golden` band images: the engaged segment lens frozen through `debugSegmentLensPress` (pressed on segment 1; straddling segments 1–2).
- The search goldens (`case_search_phone_active`, …) change: the liquid control replaces the pill.

### 14.5 Acceptance (owner)

**Numeric gate**, kinds as VK-503 §17.4 (**native**: independent native data the model can fail; **native, constant**: native data that Flutter sets from a constant; **fit**: Flutter against a fitted spring), plus two (amended 2026-10-14, Task 13 review): **native, fitted**: the native rows the model's springs were fitted to (tap, press, release, programmatic; §8.2), in sample, so only the model's shape can fail them; **condition**: a precondition of other rows (the gesture against native's, the tap clock, dropped frames), not a comparison. A row that depends on a condition (named in its row) reads `n/a` when that condition fails: neither a pass nor a failure. A failed condition shows in its own row and leaves every other row as it was:

| Quantity | Reference | Tolerance | Kind |
|---|---|---|---|
| Track, segment and thumb rects (2, 3, 5 segments at 370; intrinsic 177) | spike §2 | ±1 pt | native |
| Tap x (five captures: `tap_1_2`, `tap_2_3`, `tap_3_1`, `dark.tap_1_2`, `tap_1_3_5seg`), from the commit on the engage-aligned clock (below) | the native per-frame rows | ±2 pt per row at 0.05 s steps to 0.6 s; settle ±10 % | native, fitted (reads `n/a` when its `clock` or `frames` condition fails) |
| Tap shape: one-segment peak h, two-segment peak h, wobble extremes | the native rows | ±10 % | native, fitted (`tap_3_1`'s late w swell, ×1.14, was −12 % in Task 4's model; Task 15's area wobble brings it to +5 %) |
| Overshoot (one, two segments) | 2.5 / 4.9 pt | ±1 pt | native, fitted |
| Press size at +0.033 / 0.067 / 0.1 / 0.133 / 0.2 / 0.25 s | the native rows | ±2 pt | native, fitted |
| Release size and engage at +0.033 … +0.2 s | the native rows | ±2 pt, ±0.12 | native, fitted |
| Drag lag at the drag's speed | 6.77 pt at 82.2 pt/s | ±10 % | native |
| Flick: lands on the finger's segment, overshoot | Task 1 (`flickLanding`) | ±0.5 pt, ±1 pt | native (landing); the overshoot is native, fitted (Task 15 fitted the release spring to it), and reads `n/a` when the `flick drive` condition fails (below) |
| Programmatic slide | the native rows | ±2 pt per row | native, fitted (reads `n/a` when its `programmatic clock` condition fails) |
| Rest colours over white and black (track, thumb, label) | spike §2 | ±4 / 255 | native (label: native, constant) |
| Engage in (taps and presses) | `engageOnset` at display-link resolution (taps 33.6–34.0 ms after `valueChanged`, presses 46–48 ms after the down) | ±1 frame | native |
| Conditions: `clock` (x shift within ±1 frame), `frames` (longest gap ≤ 1.5 frames), `flick drive` (±1 frame, ±2 pt of native's gesture), `programmatic clock` (ticker idle at the write) | below | as stated below | condition (not a comparison) |

Read-back rows (Flutter's own constants compared with themselves) are not allowed (Q3).

**Fitting set and holdouts (Task 15 review).** The model is fitted to the fixture's captures and the fitting split of `docs/qa/vk550/native_taps.json` (pass 0 of each sequence, 26 taps); its holdout split (passes 1 and 2, 52 taps) is the test, and Task 15's `native_holdout.json` (21 taps) is a validation set (it showed the first lift rule wrong before the rule was chosen). `segment_motion_test.dart` and `segment_holdout_test.dart` run the gate above on each, from one implementation with the device table (`tool/segment_gate.dart`), on the device table's clock. Every peak h passes everywhere; what still misses is pinned exactly (acceptance): the slide and its overshoot on 5-segment taps longer than any fixture capture (222 and 296 pt), a two-segment x row at +0.25–0.3 s (2.1 pt), the w swing after a long tap to the right on five segments, and one capture's x at +0.1 s on a clock 8 ms off its siblings.

**Tap clock alignment (amended 2026-10-14, Task 13 review; it replaces the Task 4 review's rule for the device table).** A tap capture's t0 is native's `valueChanged`, which lands up to a frame off the display link, and Flutter's t0 is the last frame before the up, which lands up to a frame off the commit; ±2 pt at the rows' speed (670–1525 pt/s from 50 to 150 ms) asks for ±1.3–3 ms. The Task 4 rule shifted each capture by the difference of the engage onsets, read linearly between rows. On the device that shift was noise, not signal: the native rows hold each display-link frame for 50 ms, so an onset read from them lands anywhere in that step (engage goes 0 → 1.0 within one row in `tap_3_1` and `dark.tap_1_2`), Flutter's onset moves by up to 2.6 ms with frame phase and the dropped frame at each commit, and 9 x rows flipped between consecutive runs of an engine that matched the model frame for frame. Rule now:
- **x clock:** each capture's x rows (every 0.05 s to 0.6 s) are compared at `t − shift`, where `shift` is the least-squares fit of Flutter's x to those rows, on a 0.5 ms grid bounded to ±1 frame (±16.5 ms). A shift at the bound fails its `clock` condition (the two are more than a frame apart). The settle, peak and wobble rows read the same clock.
- **Engage onset:** a latency row of its own, against native's onset at display-link resolution (`engageOnset` in the fixture, re-extracted from the raw CADisplayLink frames the rows were sampled from), ±1 frame. It no longer moves the x clock.
- **Dropped frames:** a `frames` condition per capture: the longest gap between Flutter frames from the commit to 0.6 s, at most 1.5 frames. Jank fails visibly and separately from the motion.
- The tolerances are unchanged. The native rows are never edited. The model tests (`segment_motion_test.dart`, `segment_holdout_test.dart`) read their rows on the same clock (Task 15 review: one implementation, `tool/segment_gate.dart`) and check the engage onset within a frame on its own.

**Flick drive (amended 2026-10-14, Task 13 review).** The overshoot depends on the release speed, so the flick is driven as native's `flickLanding` capture was made: its `release_at` (down to up) and its path, from the last segment's thumb centre to `landing`, both read from the fixture (`tool/segment_frames.sh` passes them to the Flutter run; the XCUITest reads the same file). A `flick drive` condition compares the gesture the Flutter run made (its driver's own clock, and the finger's travel) with native's, ±1 frame and ±2 pt; when it fails, the overshoot row reads `n/a`. The idb flick of the spike (`--duration 0.25`) took 0.465–0.548 s as delivered, which is why the fixture, not the idb argument, is the reference.

**Programmatic clock.** The slide is read on the ticker's own clock from 0, the rebuild that applied the app's write (a ticker started mid-frame takes that frame as its start). A `programmatic clock` condition checks that the ticker was idle at the write: its first frame within 0.25 s of 0 (a ticker already running would be a second or more in, the driver's rest; frames dropped at the rebuild do not move the origin). When not, the slide rows read `n/a`.

**Flutter traces.** `integration_test/segment_fidelity_test.dart` (iPhone 17 Pro, iOS 26.5, Flutter liquid forced) drives the spike's sequence on the example's segments case (tap 1→2, 2→3, 3→1, press-hold 2 s, slow drag 77 → 324 at ≈ 82 pt/s, the flick of `flickLanding` (above), a programmatic change) and records each frame through `debugSegmentTrace` (lens rect, engage, the engine's frame time). `tool/segment_trace_compare.dart` compares it with `docs/qa/vk550/native_reference.json` and prints the table above.

**Frame strips.** `tool/segment_frames.sh` creates its own iOS 26.5 iPhone 17 Pro simulator, records the native reference screen (§13, a `UISegmentedControl` in the example's Runner at the same frame over the same stripes, driven by XCUITest) and the Flutter case (driven by the integration test), extracts 60 fps frames with ffmpeg between both drivers' `SEGFID start` and `SEGFID end` markers, and composes `build/segfid/strips/{light,dark}/frames_<k>.png` with `tool/tab_strips.dart` (native left, Flutter right, one row every 3 frames). Both drivers make the same gestures: the Flutter touches go in on the binding's device path, so the test binding draws no pointer marker, and the native reference screen logs the touches UIKit delivered (an XCUITest velocity is a request). The owner reviews them as an artifact page, light and dark.

**On device.** The owner checks the OTA example on a real iPhone and iPad: the native scope bar (iOS 26+), the Flutter control with "Flutter liquid" forced, the haptics (Q3).

## 15. Docs and versions

- **`doc/segmented_control.md` (new):** the control, its API, geometry, theming, motion in plain words, accessibility, what is not identical to native (the Q-rows).
- **`doc/search.md`:** `LiquidSearch.scopes`, the native scope bar, `LiquidSearchScopeBar` in both modes.
- **README:** a "Segmented control" section with a snippet from the new example case (`make snippets`), and the search section's scope paragraph.
- **CHANGELOG ×4:** `0.1.0-dev.7`, with §13's behaviour changes.

## 16. Performance

| State | Passes | Ticker |
|---|---|---|
| rest | none (two fills and text) | off |
| press / drag / flight (≤ 0.9 s after release) | + one lens pass | on |
| programmatic slide | none (rest thumb) | on (≈ 0.5 s) |

A screen with many segmented controls costs nothing at rest: no `BackdropFilter` until a touch.

## 17. Risks

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| R1 | The generalisation changes the tab bar's motion | M / H | `LensProfile.tab` is pinned field by field to `TabSprings`; every VK-503 test and `make tab-traces` run unchanged before the first segment line is written (Task 2 is a pure refactor) |
| R2 | UIKit changes the scope bar's activation behaviour in a point release (the `.automatic` failure shows it is fragile) | M / M | XCUITest and the integration test pin "shown while active" on iPhone and iPad; the fallback is one switch: `nativeSearchScopes = false` makes Flutter draw the scope bar again |
| R3 | The scope bar changes the navigation bar height and Flutter's top inset lags a frame | M / L | Task 11 measures it; a forced `rereadRestingTop` after `setShowsScope` |
| R4 | The two-spring model misses native's in-between wobble frames | H / L | Q-E. The gate is on peaks and settle; the strips show the residual |
| R5 | A 44 tall lens with a 9 pt bezel looks different from native's ring | M / L | Task 1 measures the ring; Task 15 kept 9 and tuned the look against the strips (§7) |
| R6 | The host's load (other agents) drops `idb` touches, as in the spike | M / L | XCUITest drives native; the integration test drives Flutter; idb only for spot checks |
| R7 | The 44 pt box shifts layouts that expect a 32 pt control | L / L | Q-C; documented |
| R8 | The lens's interior over the track reads differently from native's, light or dark: the shared capture includes the track (§7), and while engaging (≈ 50 ms) and releasing (0.11 s) the rest fill is drawn twice, under the lens (captured and refracted) and as `LiquidLens.restFill` (as the tab bar's) | M / L | Task 15: the track stays (native's lens shows it); the rest fill is drawn once and the lens fades from clear glass (§7); checked against the strips, light and dark |

## 18. Process

1. Plane VK-550 moves to Todo with `spec:approved` once the owner answers.
2. Each `### Task N` of the plan becomes a sub-issue.
3. Each task is TDD, then reviewed.
4. Before the PR (after PR #9 merges, rebased on main): `make verify` green, plus `make test-impeller`, `make goldens`, `make ios-unit`, `make ios-ui`, `make integration-ios-native`, `make segment-traces`, `make tab-traces` (the refactor guard), outputs pasted.
5. Task 15 produces the strips and the trace table for the owner.

---

## Quyết định cần chủ sản phẩm xác nhận

Q1–Q5 của đề bài đã chốt ("ok hết"). Dưới đây là các điểm **mới** phát sinh từ spike và thiết kế. Mỗi dòng có đề xuất mặc định; "ok hết" là áp dụng toàn bộ.

| Q# | câu hỏi | đề xuất |
|---|---|---|
| Q-A | Thanh phạm vi native (iOS 26+): chấp nhận đúng dáng UIKit không? iPhone: nằm trên cùng dưới thanh trạng thái, tiêu đề lớn ẩn khi search mở; trên **26.5** nó nằm trên một **dải nền phẳng** (không phải kính), trên 27 là kính. iPad: dưới ô tìm, căn giữa, rộng cố định 426pt (26.5) / 534pt (27). Chỉ hiện **khi search đang mở** (giống Apple Music); search đóng mà còn chữ thì không có thanh phạm vi | **Chấp nhận nguyên dáng UIKit** (đó là native thật, khớp Apple Music). Không tự vẽ đè |
| Q-B | Bản Flutter (Android, iOS < 26): rãnh của `LiquidSegmentedControl` là **lớp màu trong phẳng** như `UISegmentedControl` thật, hay **kính** như thanh phạm vi iOS 27? | **Phẳng, đúng `UISegmentedControl`** (đo được). Hiệu ứng kính nằm ở viên chọn: khi chạm/giữ/kéo nó hoá thấu kính khúc xạ có viền cầu vồng. Muốn rãnh kính thì làm sau, thêm một cờ |
| Q-C | Native cao 32pt, ô tối thiểu 32pt. Luật của anh là vùng chạm ≥ 44pt. Làm sao? | **Hộp 44pt, rãnh 32pt nằm giữa** (thừa 6pt trên/dưới trong suốt, vẫn nhận chạm); chế độ co theo chữ thì mỗi ô ≥ 44pt. Hình nhìn vẫn 32pt như native; bố cục cao hơn 12pt. Ghi trong tài liệu |
| Q-D | Cỡ chữ lớn: `UISegmentedControl` native **không** phóng chữ theo Dynamic Type (cố định 13pt) | **Phóng theo cỡ chữ của máy, tối đa ×2**; rãnh cao lên theo chữ; chữ dài thì "…"; ở cỡ trợ năng giữ lâu để xem nhãn phóng to (như thanh tab) |
| Q-E | **(không thể 100%)** Viên chọn "rung thạch" sau khi đáp và co/giãn theo tốc độ kéo là mô hình vật mềm riêng của UIKit | **Mô hình hai lò xo (rộng/cao) như thanh tab:** khớp đỉnh, độ vượt và thời gian đứng trong ±10%, không khớp từng khung trung gian; ảnh từng khung đặt cạnh nhau cho thấy phần chênh |
| Q-F | Ô có icon (ảnh), độ rộng ô theo nội dung, chế độ "momentary" | **Không làm trong VK-550:** chỉ chữ (+ tắt từng ô). API `LiquidSegment` để sẵn chỗ thêm sau |
