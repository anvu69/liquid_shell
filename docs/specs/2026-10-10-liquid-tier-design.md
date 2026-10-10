# liquid_shell: core liquid glass tier design

- **Plane:** VK-348 (parent VK-343)
- **Date:** 2026-10-10
- **Status:** draft for the owner. The owner approves this spec and the plan `docs/plans/2026-10-10-liquid-tier.md` together. Open choices are in the last section, "Quyết định cần chủ sản phẩm xác nhận". Every row has a recommended default, and if the owner says nothing the default applies.
- **Branch:** `VK-348-liquid-tier`, from the P2 branch `VK-346-p2-native-ios` at `5e0a1e9`. P2 is not merged yet. This branch rebases onto `main` once P2 (with VK-405 and E2) merges, as owner decision L6 orders.
- **Floor:** Flutter ≥ 3.44.0 / Dart ^3.12.0 (fvm pins 3.44.6), iOS 15.0, Android `flutter.minSdkVersion`, `very_good_analysis` 10.3.0. There are no new runtime dependencies.
- **Binding decisions:** owner decisions L1–L6 of 2026-10-10 (`ls-liquid-decisions.md`, approved with "Ok hết"). This spec implements L1–L5. L6 sets the order.
- **Sources:**
  - P1 spec `docs/specs/2026-10-08-p1-foundation-design.md`. It defines the glass seam (`LiquidGlass`, `LiquidGlassRenderer`, `LiquidGlassPolicy`, `LiquidGlassSignals`, `LiquidGlassTier`, `LiquidGlassTheme`) in §4.7 and §5.8–5.9, and the signals in §6.
  - P2 spec `docs/specs/2026-10-09-p2-native-ios-design.md`. It covers native chrome engagement (§7.1, §14).
  - Research notes `vk343-android-glass-research.md` (Android glass, budget rule, API share) and `vk404-native-ios-research.md` (what can be native on iOS 26).
  - The spike of 2026-10-10 (§3.2). It was throwaway code in the session scratchpad and was not committed.
  - Public sources, cited inline as [S1]…[S21] and listed in §17.

> **Tóm tắt (cho chủ sản phẩm).** Thư viện tự vẽ kính lỏng (liquid glass) bằng một fragment shader viết mới hoàn toàn trong gói lõi `liquid_shell`, chạy qua `BackdropFilter` + `ImageFilter.shader` trên Impeller, không thêm thư viện ngoài nào. Hiệu ứng gồm: mép kính khúc xạ như thấu kính (nội dung sát mép bị "kéo" và phóng nhẹ), viền sáng phản chiếu, tán sắc màu rất nhẹ ở mép, lớp mờ nhẹ và màu phủ. Mọi bề mặt kính (thanh tab, ⌕, sidebar, nút sidebar, khung phóng chữ lớn) đều đi qua `LiquidGlass`, nên tự có liquid. Liquid là mặc định. Thư viện tự hạ xuống frosted khi: Android ≤ 9 (Skia, không có shader filter), máy không có Vulkan 1.1 ("chỉ GLES"), máy yếu (RAM ≤ 3 GB), bật tiết kiệm pin, khung hình thực tế bị chậm, hoặc kính nằm trong một `BackdropFilter` khác. Bật giảm trong suốt hoặc tăng tương phản thì hạ xuống solid. Spike đã chạy thật trên simulator iOS 26.5 (Metal) và emulator Android 36 (cả GLES lẫn Vulkan): shader khai báo trong gói, nạp bằng khoá `packages/liquid_shell/...`, đặt đúng vị trí kính theo toạ độ màn hình vật lý. Phát hiện quan trọng: `flutter test --enable-impeller` chạy được shader, nên golden **có** chụp được kính liquid (khác điều L5 giả định). Ví dụ có công tắc "Native / Flutter liquid" ở mọi case. Nghiệm thu bằng ảnh đặt cạnh nhau: iOS 26 native bên trái, Flutter liquid bên phải, trên iPhone, iPad và emulator Android. 16 câu hỏi còn mở có đề xuất mặc định ở bảng cuối.

---

## 1. Goal

The owner wants the library to be about liquid glass: it must draw liquid glass on iOS before 26 and on Android with Flutter, and it must look close to iOS 26's own glass (L1, and the owner's note in `ls-liquid-decisions.md`).

This phase delivers that look inside the core package. It has five parts:

1. **A clean-room fragment shader and a built-in liquid renderer** in `liquid_shell`. It runs through `BackdropFilter` + `ImageFilter.shader` on Impeller, with zero third-party dependencies (L1).
2. **Liquid as the default tier, with fallbacks.** Liquid is drawn wherever it works. It drops to frosted and to solid under the signals in L2.
3. **Every glass surface through `LiquidGlass`** (L3), with a gate that keeps it that way.
4. **A "Native / Flutter liquid" switch** in every example case (L4).
5. **Side-by-side screenshots against iOS 26 native** as the acceptance (L5). Impeller goldens back them up as a regression guard.

## 2. Scope

### 2.1 In this phase

| # | Item | Section |
|---|---|---|
| S1 | `liquid_shell/shaders/liquid_glass.frag`, declared in the package pubspec and loaded with `FragmentProgram.fromAsset` | §4, §5.1 |
| S2 | Built-in `LiquidShaderRenderer` (tier `liquid`). It has its own render object that places the shader from the screen rect at paint time and follows moving ancestors | §5 |
| S3 | `LiquidGlassTheme` gains `liquidTint`, `refraction`, `dispersion` and `liquidBlurSigma` (Q4) | §5.6 |
| S4 | Policy changes: liquid becomes the default. A new `prefersFrosted` rule covers battery saver, low-end, GLES-only and slow frames. Skia drops to frosted instead of solid, and battery saver moves from solid to frosted | §6 |
| S5 | New signals. On Android: `lowEnd` (RAM) and `glesOnly` (no Vulkan 1.1). On iOS: Low Power Mode as `powerSave` (Q8). In Dart: a frame-time guard, `slowFrames` (Q7) | §7 |
| S6 | Every glass surface goes through `LiquidGlass`. A gate script fails on a `BackdropFilter` or `ImageFilter` outside `lib/src/glass/`. Sidebar edges that lie on the screen edge get no rim | §8 |
| S7 | A forced glass tier turns native chrome off for shells under that scope (Q11). The example uses this for its switch | §9.1 |
| S8 | A "Native / Flutter liquid" switch in every example case, plus `LiquidGlass.precache()` in the example's `main` | §9 |
| S9 | Tests at three levels. Unit tests cover the uniform math, the policy table, the frame guard and the Kotlin classifier. Widget tests use an injected filter factory. Impeller goldens run with `flutter test --enable-impeller` | §10 |
| S10 | Side-by-side screenshots: an integration test captures native and Flutter-liquid shots, and `tool/side_by_side.dart` places them next to each other. These are the README images | §11 |
| S11 | CI: Impeller goldens and a liquid screenshot run on the iOS and Android integration jobs | §12 |
| S12 | Docs: `doc/tiers.md`, `doc/liquid.md` (new), README, CHANGELOG ×4, version `0.1.0-dev.3` | §12.3 |

### 2.2 Non-goals

- **Motion effects.** There is no device-motion light (no sensor dependency), no "materialize" animation that grows the lensing in, and no press glow or jelly or flex. The light direction is fixed at top-left. The existing 200 ms tier cross-fade stays. These can come in a later phase.
- **A moving lens selection indicator** inside the tab bar (the iOS 26 magnifier over the selected tab). The selected chip stays P1's `primaryContainer` chip. The side-by-side screenshots will show the gap. It is a candidate for the next phase.
- **Continuous (superellipse) corners.** The shape stays `ClipRRect` with circular corners, so that it matches frosted, solid and the existing goldens.
- **Adaptive tint by backdrop luminance** (Apple's "dynamic range shift", [S8]). The tint is fixed per theme. Contrast is checked in the screenshots instead (§13).
- **Glass on list cells, sheets, dialogs and action sheets.** Dialogs are P3a (VK-406) and the back button and search field are P3. Under L3 they must use `LiquidGlass`, and the S6 gate enforces that once they exist.
- **A web or desktop liquid tier.** `isShaderFilterSupported` is false on web, so web gets frosted. macOS Impeller would get liquid by default, but nobody tests it and the docs say so.
- **Removing the `renderers` registration point.** An app can still register its own liquid renderer, and a registered renderer wins over the built-in one (§6.2).

## 3. Research findings

Confidence: **H** means verified in the 3.44.6 SDK source or by the spike. **M** means an official doc or a maintainer statement that we did not test. **L** means an inference.

### 3.1 The Flutter 3.44 API (H, read in `~/fvm/versions/3.44.6`)

| Fact | Where |
|---|---|
| `ImageFilter.shader(FragmentShader)` throws `UnsupportedError` unless Impeller is on. `ImageFilter.isShaderFilterSupported` is `_impellerEnabled` | `sky_engine/lib/ui/painting.dart:4479–4506` [S1] |
| The shader's **first uniform must be a `vec2`, which the engine sets to the input texture size**. It must also have at least one `sampler2D`, and the first sampler receives the filter input. If either is missing, `ImageFilter.shader` throws a `StateError`. Our own float uniforms therefore start at index 2 | same, and the docs [S2] |
| "When Impeller uses the OpenGL(ES) backend, the y-axis direction is reversed. Custom fragment shaders must invert the y-axis on GLES." The shader detects this with `#ifdef IMPELLER_TARGET_OPENGLES` | same; `shader_lib/impeller/*.glsl` |
| `FlutterFragCoord()` returns the `_fragCoord` varying under Impeller (`flutter/runtime_effect.glsl`) | `bin/cache/artifacts/engine/darwin-x64/shader_lib/flutter/runtime_effect.glsl` |
| Shader limits: no UBOs or SSBOs, `sampler2D` only, only the two-argument `texture`, no extra varyings, no unsigned ints or bools | [S2] |
| A package declares its shaders under `flutter: shaders:`. An app loads them as `packages/<pkg>/<path>` | [S2]; spike §3.2 |
| `BackdropFilter.grouped` takes the key of the nearest `BackdropGroup`. Filters that share a key share **one backdrop snapshot**: the engine caches it on the first filter with that id, and the later ones filter the cached copy. Overlapping filters must not share a key | `widgets/basic.dart:462–560`; `SceneBuilder.pushBackdropFilter` docs [S3] |
| `RenderBackdropFilter` pushes a layer **only when it has a child**, so a childless filter draws nothing | `rendering/proxy_box.dart:1329–1352` |
| `BackdropFilter(filterConfig:)` takes an `ImageFilterConfig`, which is resolved at paint time with `ImageFilterContext(bounds: offset & size)`. The bounds are in the **current layer's** coordinates, not the screen's | `rendering/image_filter_config.dart`; spike §3.2 |
| `ImageFilter.compose(outer: shader, inner: blur)` works. The bug where the shader saw a texture of changing size as the blur sigma moved (flutter#170820) was fixed by flutter#177687 in October 2025, so 3.44 has the fix | [S4]; spike case G |
| `RenderObject.getTransformTo(null)` stops below the `RenderView`, so it is **logical**. The root transform with the device pixel ratio is `RenderView.configuration.toMatrix()` | `rendering/object.dart:3674–3720`, `rendering/view.dart:269,334` |
| `flutter test --enable-impeller` exists in 3.44.6 | `flutter test --help` |

**Coordinates on Impeller.** `FlutterFragCoord()` is relative to the current render pass, not to the screen ([S5], public issue text). When an ancestor creates its own pass, the origin moves with it. PR flutter#193275, opened 2026-09-24 and not merged, would add `unclippedInput` or new content-coordinate built-ins. A reviewer pushed back and asked for coordinate uniforms instead [S6]. **3.44 has neither**, so the shader must receive the glass rect in pass pixels from Dart.

### 3.2 Spike, 2026-10-10 (H)

The spike was a throwaway local package with `flutter: shaders: [shaders/probe.frag]` and an app with six glass probes. It ran on an iOS 26.5 simulator (Metal) and on an Android API 36 emulator under both GLES (the default there) and Vulkan (forced with `io.flutter.embedding.android.ImpellerBackend=vulkan`). The simulator and emulator were deleted afterwards. The rect passed to the shader was the screen rect in physical pixels: `localToGlobal × devicePixelRatio`.

| Case | Result on iOS Metal, Android GLES and Android Vulkan |
|---|---|
| Asset key `packages/spike_glass/shaders/probe.frag` | Loads. The bare key `shaders/probe.frag` fails in an app |
| A. No clip | The whole screen is filtered. Origin is the screen's top-left and the size uniform is the screen in physical px |
| B. `ClipRRect` → `BackdropFilter` | **Screen origin and screen size.** The clip does not shrink the input on 3.44. The rect lands exactly on the glass |
| C. Two `.grouped` filters in one `BackdropGroup` | Screen origin. Correct |
| D. `Opacity(0.9)` ancestor | Screen origin. Correct |
| E. `Transform.translate` ancestor | Correct when the rect comes from the full transform |
| F. Item in a scrolled `ListView` | Correct once the rect is re-measured after scrolling. Measuring post-frame lags one frame |
| G. `compose(outer: shader, inner: blur 8)` | Works. The input is blurred and the size is unchanged |
| I. Glass **inside the child of another `BackdropFilter`** | **The origin moves to that filter's region, and the size becomes that region.** The rect lands off the glass. This matches public issue liquid_glass_widgets#333 [S5] |
| J. Glass partly off-screen | The size stays the screen. Correct |
| GLES y-flip | `FlutterFragCoord()` is top-left on GLES too, so the shape maths needs no flip. Only the **texture lookup** flips (`uv.y = 1 − uv.y`). Without the flip, text draws upside down |
| A custom `ImageFilterConfig` (`implements`) | Compiles and works, but `context.bounds` is relative to the layer (wrong under `Opacity` or a `RepaintBoundary`). It cannot place the shape |
| Android first frame | `MediaQuery.devicePixelRatio` read 1.0 on the first frame. Read the ratio from the `RenderView` at paint time |

**Also verified in `flutter test` (macOS, 3.44.6):**
- Without `--enable-impeller`, `isShaderFilterSupported` is false and `ImageFilter.shader` throws. `FragmentProgram.fromAsset('shaders/…')` still loads, because the package under test is the root package.
- **With `--enable-impeller`, `isShaderFilterSupported` is true and a `BackdropFilter(ImageFilter.shader)` renders into `matchesGoldenFile`.**
- A golden captured from a widget whose nearest repaint boundary is the root (the existing harness captures `MaterialApp`) is captured at the view's device pixel ratio (786×1704 for a 393×852 view at 2×). The physical-pixel uniforms line up exactly in it, at ratios 1 and 3.
- A capture from an inner `RepaintBoundary` is re-rendered at 1×, which breaks the physical-pixel rect. Liquid goldens must therefore capture from the root, as `expectDocImage` already does.

So L5's premise that "goldens cannot capture shaders" does not hold on 3.44. Side-by-side screenshots stay the acceptance gate (only a device or simulator shows the real native glass). Impeller goldens become the regression guard (Q12).

### 3.3 Performance (M)

- **One backdrop copy per shell.** Each `BackdropFilter` without a shared key snapshots the backdrop. With `BackdropFilter.grouped` under one `BackdropGroup`, the snapshot is taken once and every glass filters the cached copy [S3]. The shell already wraps its chrome in one `BackdropGroup` (P1 §5.8), and the liquid renderer keeps `.grouped`.
- **Measured costs.** On Windows Impeller, 36 grouped unbounded blurs cost 3.85 ms of raster time at p50, against 11.2 ms ungrouped. "Bounded" blur loses most of the grouping gain [S7]. A third-party liquid package measured about 115 mW for a backdrop copy, 165 mW for a σ 7 blur and 335 mW for full glass on a Pixel 10 (vk343 §1, M). The order of magnitude is what matters: the copy and the blur dominate, and the lens maths is cheap.
- **Blur in the shader or chained.** A blur inside the shader costs N taps per pixel per channel (25 or more for a usable σ), and dispersion triples that in the rim. Impeller's Gaussian is separable and downsamples above σ 4 [S7]. **The design chains the engine blur as the inner filter and runs the lens shader on the blurred texture.** The shader does 1 tap in the body and 3 in the rim band (dispersion). Default `liquidBlurSigma` is 2 (§3.6.1, tuned down from 6). Below σ 4 Impeller does not downsample, but the blur is small and only the clipped region is filtered.
- **Shader cost.** The lens maths is per pixel with no loops. A 360×64 pt tab bar at 3× is about 207 k fragments, roughly the cost of drawing a full-screen image (L).
- **GLES on Android.** Flutter 3.44 sends Adreno ≤ 650 devices to GLES even when they have Vulkan (`DriverInfoVK::IsKnownBadDriver`, [S9]), and some GLES drivers are slower and buggier [S10][S11]. The emulator also defaults to GLES (spike). The shader has a GLES path (the y-flip). The policy treats only devices **without Vulkan 1.1** as GLES-only (Q6). Slow GLES devices are caught by the RAM rule and the frame guard.

### 3.4 Detecting GLES and low-end devices on Android (H/M)

- Dart cannot read which Impeller backend is running. The embedding exposes only the `ImpellerBackend` meta-data flag (checked in `flutter_embedding_debug-1.0.0-83675ed…jar`), not the runtime choice.
- **Rejected: a backend probe by readback.** A 1×1 shader can branch on `IMPELLER_TARGET_OPENGLES` and be read back with `toImageSync` + `toByteData`. GLES readback has open crash and ANR bugs: SIGSEGV when rasterising a Picture without Vulkan [S11], and a deadlock in `glReadPixels` on Mali [S10]. Those are exactly the devices in question.
- **Rejected: the GPU name from an EGL probe.** It would need an offscreen EGL context in the plugin, and a copy of Flutter's driver denylist that changes from release to release (the 3.47 vendor-SDK gate [S12]).
- **Chosen (cheap, static, read once on listen):**
  - `glesOnly` = API ≥ 29 and `PackageManager.hasSystemFeature(FEATURE_VULKAN_HARDWARE_VERSION, 0x00401000)` is false. Impeller needs Vulkan 1.1 [S13]. API ≤ 28 runs Skia, where `isShaderFilterSupported` is already false.
  - `lowEnd` = `ActivityManager.isLowRamDevice()`, or `ActivityManager.MemoryInfo.totalMem` < 3 GiB (Q5) [S14]. `MEDIA_PERFORMANCE_CLASS` is 0 on most devices (only some flagships declare it), so it is not used [S15].
- **A runtime safety net:** the frame guard (§7.4) watches `FrameTiming.rasterDuration` while liquid glass is on screen and demotes to frosted for the rest of the session (Q7).

### 3.5 What Apple's glass does (M, public descriptions only)

From WWDC25 "Meet Liquid Glass" [S8] and the HIG [S16]:
- **Lensing.** The material "bends, shapes, and concentrates light", unlike earlier materials that scattered light.
- **Highlights.** They respond to geometry and to the light's position, and run around the silhouette.
- **Tint and adaptivity.** The tint and dynamic range shift for legibility. Larger glass looks thicker and refracts more.
- **Reduce Transparency** makes glass frostier. **Increase Contrast** makes elements black or white with a contrasting border. **Reduce Motion** turns down effects and disables elastic properties.

The maths below is derived from these descriptions and from textbook optics: a signed distance field, Snell's law and Fresnel-like rim falloff. The public rounded-box distance formula [S17] and the physical description of a convex bezel refracted with Snell's law at n ≈ 1.5 [S18] are the only references. **No source of `liquid_glass_renderer`, `liquid_glass_widgets`, `liquid_glass_easy` or any other glass package was opened** (clean room). The spike shader was written from scratch too.

### 3.6 First comparison with native (H, while writing this spec)

The validated shader ran through the real example in an Impeller golden (`flutter test --enable-impeller`, iPhone 393×852 at 2×). It was then placed next to P2's native iOS 26 doc image `native_iphone.png` with the plan's `tool/side_by_side.dart`. Two findings:

- **The lens, the rim and the screen-edge rule work as derived.** The sidebar on an iPad landscape golden bends the backdrop only at its inner edge.
- **The first tint (22 %) and blur (σ 3) were far too clear.** Labels from the list behind the bar read through the tab labels, while native glass reads as frosty white. **50 % (light) or 55 % (dark) tint with σ 6** comes visibly close to native, so these are the defaults (Q3, Q4). The remaining gaps are the bar's size and layout (P1 geometry, not this phase) and the selection lens (non-goal).
- **Superseded by the tuning round below.** That comparison used a single still doc image, and σ 6 + 50 % hid the lens.

#### 3.6.1 Tuning round against iOS 26 (VK-348, after Task 9)

Task 9's side-by-side pairs (iPhone 17 Pro, iOS 26.5 simulator) showed that the defaults above read as **frosted** glass: native visibly bends the content behind the bar, while σ 6 and a 50 % tint washed it out so the 12 pt lens had almost nothing to bend. The owner's direction is that the package draws Liquid Glass, and frosted is not an acceptable look. One tuning round (owner decision B1) changed the default **parameters and internal constants only**; the shader and its alpha handling are unchanged.

What native does, read off the pairs: the content behind the bar stays recognisable (a light blur and a light tint), and near the top and bottom edges the bar shows a **mirrored strip** of the text that lies further inside. That is what the §4.1 model gives once the displacement grows faster than the depth (`|dδ/dt| > 1`): the sample moves inward faster than the fragment moves inward, so the image flips. At bezel 12 pt and thickness 18 pt that band was a few points wide and blurred away; at **bezel 20 pt and thickness 48 pt** it spans about 2–11 pt in from the edge, with a peak shift of about 27 pt.

Rounds (light theme unless noted; `a` = card text across the bar's top edge, `b` = across its middle):

| Round | Tint L / D | σ | Bezel / thickness (pt) | Dispersion | Result |
|---|---|---|---|---|---|
| 0 (Task 9) | 0.50 / 0.55 | 6 | 12 / 18 | 0.3 | Frosted: near-opaque pill, lens visible only on the wallpaper discs |
| 1 | 0.20–0.35 / 0.25–0.40 | 1–3 | 12–20 / 18–36 (via `refraction` 1.5–2) | 0.3–0.4 | Text behind becomes visible; the lens still barely shows |
| 2 | 0.30–0.40 / — | 1.5–2.5 | 16–24 / 36–48 | 0.15–0.3 | Bezel ≥ 20 and thickness ≥ 48 produce native's mirrored strip at the top and bottom edges |
| 3 | 0.25–0.35 / — | 1–1.5 | 20–24 / 48 | 0.2–0.3 | σ 1 makes the text behind fight the tab labels; σ 1.5 is about native's softness |
| 4 (dark) | — / 0.35–0.55 | 1.5–2 | 20–24 / 48 | 0.3 | 0.55 hides the lens in dark too; 0.40 keeps labels clear and the strip visible |
| 5 | 0.35 / 0.40 | 1.5–2 | 20–24 / 48 | 0.15–0.3 | Bezel 20 / thickness 48 / dispersion 0.3 settled; 0.35 + σ 1.5 closest to native on the iPhone bar |
| 6 (iPad sidebar open) | 0.35–0.45 / 0.40–0.50 | 1.5–3 | 20 / 48 | 0.3 | The full-height sidebar is a large pane: at 0.35 + σ 1.5 the list behind fights the sidebar labels, native looks between 0.40 + σ 2 and 0.45 + σ 2.5 |
| 7 (iPhone, check) | 0.35–0.45 / — | 1.5–2.5 | 20 / 48 | 0.3 | 0.40 + σ 2 keeps the mirrored strip and the recognisable text on the bar; **chosen** |

**Defaults after the round:** `liquidTint` `surface` @ **0.40** (light) / **0.45** (dark), `liquidBlurSigma` **2**, `refraction` 1 and `dispersion` 0.3 unchanged; internal bezel **20 pt** and thickness **48 pt** (`refraction` 1 now means 48 pt). The tint and blur stay a little stronger than the clearest round (0.35, σ 1.5) because one theme serves both the small bar and the large sidebar, and native keeps its labels legible with vibrancy, which this package does not have. What still differs from native is in Task 9's report: bar geometry, the selection capsule, SF Symbols and label weight (P1), and native's sharper mirrored strip.

## 4. The shader

### 4.1 Model

The glass is a slab of thickness `T`. Seen from above, its footprint is the rounded rect. Across a bezel band of width `b` inside the edge, the top surface curves down to the edge. Below the slab lies the backdrop plane. A view ray goes straight down (`I = (0, 0, −1)`), refracts at the top surface with index `n`, and travels to the backdrop through the local glass height. Where it lands is the backdrop pixel shown.

All quantities are in **physical pixels of the pass**, and y points down.

1. **Signed distance.** Let `p` be the fragment position, `c` the rect centre, `h` the half-size, and `r` the corner radius of the quadrant `p` lies in (`tl`, `tr`, `br`, `bl`). Then `q = |p − c| − h + r` and `d = min(max(q.x, q.y), 0) + |max(q, 0)| − r`. `d < 0` is inside [S17].
2. **Outward normal (2D), analytic** (no `dFdx`):
   - If `q.x > 0` and `q.y > 0` (a corner arc): `n₂ = normalize(q) · sign(p − c)`.
   - Otherwise, if `q.x > q.y`: `n₂ = (sign(p.x − c.x), 0)`.
   - Otherwise: `n₂ = (0, sign(p.y − c.y))`.
3. **Bezel coordinate.** `t = −d` is the depth inside the edge, and `x = clamp(t / b, 0, 1)`.
4. **Height profile.** A convex quarter-superellipse, `η(x) = (1 − (1 − x)⁴)^¼`. It is 0 at the edge, 1 at the inner end of the bezel and flat beyond. Its slope is `η′(x) = (1 − x)³ · (1 − (1 − x)⁴)^−¾`, with `x` clamped to ≥ 0.02 so the slope stays finite.
5. **Surface normal (3D).** The surface descends toward the edge, so the normal tilts outward: `N = normalize(vec3(n₂ · s, 1))`, where `s = min(T / b · η′(x), 8)`.
6. **Refraction.** `R = refract(I, N, 1/n)`. Because `n > 1`, `R.xy` points **inward** (opposite `n₂`). This is the convex-lens case: rim pixels show backdrop from further in, so content near the edge is magnified and squeezed.
7. **Displacement.** `δ = R.xy · (T · η(x)) / max(−R.z, 0.2)`. It is 0 at the very edge, where the height is 0, peaks just inside the edge and falls to 0 where the bezel flattens. At the default `T = 48 pt`, `b = 20 pt` and `n = 1.5` (tuned in §3.6.1; the plan's Task 1 worked numbers used 18 / 12), the peak is about **27 pt** (27.3) at `x ≈ 0.06`, 26.1 pt at `x = 0.1` and 13.7 pt at `x = 0.3`. Between about `x = 0.1` and `0.55` the shift falls faster than the depth grows, so the band mirrors what lies inside. Dispersion at the default 0.3 moves red and blue by about ±1 pt at `x = 0.1`.
8. **Dispersion.** Inside the bezel only (`x < 1`), the red, green and blue channels are sampled with `n − 0.1·k`, `n` and `n + 0.1·k`, where `k` = `dispersion` (0–1, default 0.3, so ±0.03). Outside the bezel there is one tap.
9. **Sample.** `uv = (p + δ) / uSize`, clamped to [0, 1]. The y-flip applies only under `IMPELLER_TARGET_OPENGLES` (spike).
10. **Tint and vibrancy.** `rgb = mix(sample, tint.rgb, tint.a)`. Then `rgb = mix(vec3(luma(rgb)), rgb, sat)`, with `sat` = 1.1 (an internal constant). `luma` uses Rec. 709 weights.
11. **Specular rim.** `L = normalize(lightDir)`, with the light at the top-left `(−0.5, −0.85)`. The rim mask is `ρ = 1 − smoothstep(0, w, t)`, where `w` is the rim width (1.5 pt). Then `spec = ρ · (max(n₂·L, 0) + 0.4 · max(−n₂·L, 0))`, which gives a strong highlight on the lit edge and a weaker one opposite, as light passing through. The bezel glow is `g = 0.25 · (1 − η(x))`. Finally `rgb += rim.rgb · rim.a · (spec + g)`.
12. **Output.** `fragColor = vec4(rgb, 1)`. The `ClipRRect` around the filter cuts the shape with anti-aliasing, so the shader never handles the outside.

### 4.2 Uniform layout

Floats are listed by index. Indices 0–1 are set by the engine. `setFloat` indices do not count the sampler [S2].

| Index | Name | Meaning (physical px unless noted) |
|---|---|---|
| 0–1 | `uSize` | Pass size (engine) |
| 2–5 | `uRect` | Glass left, top, width, height in the pass |
| 6–9 | `uRadii` | Corner radii tl, tr, br, bl |
| 10–13 | `uOptics` | Bezel `b`, thickness `T`, index `n`, dispersion `k` (0–1) |
| 14–17 | `uTint` | Tint r, g, b, a (straight alpha, 0–1) |
| 18–21 | `uRim` | Rim r, g, b, a |
| 22–25 | `uLight` | Light x, y, rim width `w`, saturation `sat` |
| sampler 0 | `uBackdrop` | The filter input (engine) |

`liquidUniforms(...)` is a pure Dart function. It returns these 24 floats, for indices 2–25, from logical inputs and a pixel scale, and is unit-tested with exact values (§10.1). It applies four rules:

- `b` is clamped to `[1 px, 0.5 · min(width, height)]`.
- Each radius is clamped to `0.5 · min(width, height)` (a pill with 999 pt radii becomes a stadium).
- `T = 48 pt · refraction` (§3.6.1).
- **Screen-edge rule.** A side that lies within 0.5 px of the pass edge is pushed out by `b + max radius + 2 px`, so the sidebar's outer edges, which sit flush with the screen, get no bezel and no rim. The rect stays the drawn one for clipping, and only the SDF rect is extended.

### 4.3 File and declaration

The shader lives at `liquid_shell/shaders/liquid_glass.frag`. In `liquid_shell/pubspec.yaml` it sits next to the existing `plugin:` key:

```yaml
flutter:
  plugin:
    platforms: …            # unchanged
  shaders:
    - shaders/liquid_glass.frag
```

impellerc compiles it during the asset build: `flutter test`, `flutter build` and `flutter run`. A compile error fails `make test`, which makes the shader's compile check free. `pana` and `publish --dry-run` must accept the `shaders/` folder (checked in the plan, Task 1).

### 4.4 Reference source

The plan's Task 1 holds the full GLSL. It is short (about 110 lines) and has no loops. It uses `#version 460 core`, `precision highp float` (positions reach about 3000 px, which is beyond `mediump`), `#include <flutter/runtime_effect.glsl>`, and the uniforms of §4.2.

## 5. The liquid renderer

### 5.1 Loading the program

`LiquidShaderProgram` is internal and process-wide. It holds a `ValueNotifier<ui.FragmentProgram?>`.

- `load()` is idempotent and is started by the first `LiquidGlass` that mounts while shader filters are supported. It tries the key `packages/liquid_shell/shaders/liquid_glass.frag`, then `shaders/liquid_glass.frag`. The second key covers this package's own tests, where `liquid_shell` is the root package and only the bare key exists (spike §3.2). If both fail, it logs once in debug and the program stays null, so the glass stays frosted forever. It never throws.
- `LiquidGlass.precache()` is a new public static method that returns `Future<void>`. An app can await it in `main` after `WidgetsFlutterBinding.ensureInitialized()`, so the first frame is already liquid. Without it, the first one or two frames are frosted, and the 200 ms tier cross-fade then brings in liquid, a short "materialize" effect.
- `@visibleForTesting debugResetLiquidShaderProgram()` clears it. The existing `debugResetLiquidGlassSignals()` calls it.

### 5.2 `LiquidShaderRenderer`

It extends `LiquidGlassRenderer`. It is internal: `LiquidGlassPolicy` uses it as the built-in liquid renderer, the way it already uses frosted and solid.

- **`tier`:** `liquid`.
- **`isSupported(context)`** is true only when all three hold:
  - `liquidGlassCanRefract()`, which is `debugLiquidGlassCanRefractOverride ?? ui.ImageFilter.isShaderFilterSupported`;
  - the program is loaded;
  - there is no ancestor `BackdropFilter` widget (`context.findAncestorWidgetOfExactType<BackdropFilter>() == null`, which also covers `BackdropFilter.grouped`). This is spike case I (Q10). A `LiquidGlass` inside another `LiquidGlass`'s *child* is fine, because a glass background and its child are siblings, not ancestor and descendant.
- **`buildBackground`** is a `Stack(fit: expand)` with two children:
  - `ClipRRect(borderRadius)`, holding a `LiquidBackdrop` (the render object of §5.3), which holds `SizedBox.expand()`;
  - `OutsideShadow` (P1's), drawn above the filter so the filter never samples the shadow.

  There is no `DecoratedBox` tint or border: the shader draws the tint, and the rim replaces the hairline border.

### 5.3 `LiquidBackdrop` and `RenderLiquidBackdrop`

`RenderLiquidBackdrop` extends `RenderProxyBox`. It does what `RenderBackdropFilter` does, but builds its filter at paint time. Its inputs come from the widget: `backdropKey` (from `BackdropGroup.of`), `borderRadius` and `textDirection`, `LiquidOpticsParams` (from the theme: `liquidTint`, `rimHighlight`, `refraction`, `dispersion`, `liquidBlurSigma`), the program, and a `LiquidFilterFactory`.

In `paint(context, offset)`:

1. Find the root `RenderView`: `owner!.rootNode! as RenderView`. Let `m = view.configuration.toMatrix() × getTransformTo(null)`. This is the logical → pass-pixel transform, and it includes every ancestor `Transform`, scroll offset and the device pixel ratio.
2. Compute `rect = MatrixUtils.transformRect(m, Offset.zero & size)` and `scale = view.configuration.devicePixelRatio`. Also get the pass size in px, `view.size × scale`, for the screen-edge rule.
3. Compute `uniforms = liquidUniforms(rect, radii, params, scale, passSize)`. If they differ from the last ones, take a **fresh** `FragmentShader` from the program, set the uniforms on it, build a new filter with `factory(shader, liquidBlurSigma)`, and only then dispose the previous shader. A fresh shader is used because `ImageFilter.shader` equality compares the shader object: mutating the shader that the current filter wraps could make the new filter compare equal and skip the layer update. The engine keeps its own reference, so disposing the old Dart handle is safe. The default factory returns `compose(outer: ImageFilter.shader(shader), inner: ImageFilter.blur(σ))`, or just the shader when σ is 0. σ stays **logical**: like the frosted blur, the engine scales a layer's blur by the current transform (seen in the validation render: σ 3 at 3× blurs about 9 px). Only the shader's own uniforms are in pass pixels.
4. Push a `BackdropFilterLayer` with that filter, `BlendMode.srcOver` and the `backdropKey`, then paint the child. `alwaysNeedsCompositing` is `child != null`, as in `RenderBackdropFilter`.
5. Record `rect` as `_paintedRect`.

**Following ancestors that move without repainting us.** Paint-time placement is exact when the glass repaints. It goes stale when only an ancestor *layer* moves: during a route transition, in a scrolled list, or for a `RepaintBoundary` subtree under an animated transform (liquid_glass_easy#21 describes this public bug class [S19]). There are three mechanisms:

- **Route animations, same frame.** `LiquidBackdrop`'s state listens to `ModalRoute.of(context)?.animation` and `secondaryAnimation` and calls `markNeedsPaint`. Animation listeners run in the transient-callback phase, before paint, so the rect is right in the same frame as the transition's transform.
- **Scrolling, same frame.** It also listens to `Scrollable.maybeOf(context)?.position`.
- **Drift guard, one frame late, catch-all.** A process-wide registry of attached `RenderLiquidBackdrop`s runs one post-frame callback while the registry is not empty. It re-registers only when a frame actually ran, so an idle app does no work. For each entry it recomputes the rect. If the rect moved more than 0.5 px from `_paintedRect`, it calls `markNeedsPaint`, which schedules the next frame. The cost is about one `getTransformTo` per glass per frame (a few dozen matrix multiplies). Tests cover each path (§10.2).

### 5.4 Pixel scale in tests and goldens

The scale comes from the `RenderView`, never from `MediaQuery`. The spike showed `MediaQuery.devicePixelRatio` reading 1.0 on Android's first frame. Goldens captured from the root (the existing `expectDocImage`) use the same root transform, so liquid goldens line up (§3.2).

### 5.5 Tier transitions

Nothing changes from P1. `LiquidGlass` cross-fades the background over 200 ms, or instantly under reduce motion, and never rebuilds the child. `LiquidGlass` now also listens to the program notifier, the frame guard and the signals controller. All three are merged into one `Listenable` for the `ValueListenableBuilder`, and they decide the tier together.

### 5.6 Theme fields (Q4)

`LiquidGlassTheme` gains four fields. Each has a default, `copyWith`, `lerp`, `==` and `hashCode`.

| Field | Type | Light default | Dark default | Meaning |
|---|---|---|---|---|
| `liquidTint` | `Color` | `surface` @ 0.40 | `surface` @ 0.45 | Tint inside the shader (lighter than frosted's 0.72 / 0.90; tuned in §3.6.1) |
| `refraction` | `double` | 1.0 | 1.0 | Scales thickness `T` = 48 pt × refraction. 0 means flat glass (blur and tint only) |
| `dispersion` | `double` | 0.3 | 0.3 | 0–1, the colour fringe in the bezel. 0 turns it off |
| `liquidBlurSigma` | `double` | 2 | 2 | Logical σ of the chained blur. 0 means none (tuned in §3.6.1) |

The bezel width (20 pt, §3.6.1), the rim width (1.5 pt), the index (1.5), the saturation (1.1) and the light direction stay internal constants (`liquid_optics.dart`), so they can change without breaking the API. `rimHighlight` (P1) colours the specular rim.

## 6. Tier policy

### 6.1 Signals

`LiquidGlassSignals`, public and breaking (Q13):

| Field | Source | Effect |
|---|---|---|
| `reduceTransparency` | platform (P1) | solid |
| `highContrast` | `MediaQuery.highContrastOf` (P1) | solid |
| `blurDisabled` | Android 12+ cross-window blur off (P1) | **solid only when `powerSave` is off.** Battery saver also turns cross-window blur off, so P1's rule would have made battery saver solid, against L2 (Q9) |
| `powerSave` | Android battery saver (P1); **iOS Low Power Mode (new, Q8)** | **frosted** (was solid) |
| `lowEnd` (new) | Android RAM rule (§7.1) | frosted |
| `glesOnly` (new) | Android, no Vulkan 1.1 on API ≥ 29 (§7.1) | frosted |
| `slowFrames` (new) | frame guard (§7.4) | frosted |
| ~~`canBlur`~~ | **Removed.** Skia (Android ≤ 9) drops to frosted through the renderer's `isSupported`, not to solid (L2; P1 Q6 changes) | — |

- `prefersSolid` = `reduceTransparency || highContrast || (blurDisabled && !powerSave)`.
- `prefersFrosted` = `powerSave || lowEnd || glesOnly || slowFrames`.
- `debugLiquidGlassCanBlurOverride` is renamed to `debugLiquidGlassCanRefractOverride` and now feeds only `liquidGlassCanRefract()` (Q13).

### 6.2 `LiquidGlassPolicy.resolve`, new default

1. `forcedTier != null` → that tier, stepping down liquid → frosted → solid when it has no supported renderer (P1, unchanged). A forced tier still wins over every signal. That is how the example's "Flutter liquid" switch shows liquid even on a GLES emulator, and how the owner checks liquid on a real iPhone and iPad (L5).
2. `signals.prefersSolid` → solid.
3. `signals.prefersFrosted` → `rendererFor(frosted).tier`.
4. Otherwise `rendererFor(liquid).tier`.

`rendererFor(liquid)` tries, in order:
- the first registered liquid renderer that is supported (P1);
- else the built-in `LiquidShaderRenderer` when it is supported;
- else `rendererFor(frosted)`.

The step-down log, memoised `isSupported`, `==` with `runtimeType` and overriding `resolve` are all unchanged from P1.

### 6.3 Resulting matrix (defaults)

| Situation | Tier |
|---|---|
| iOS 15–25, any iPhone or iPad (Impeller Metal) | liquid |
| iOS 26 with native chrome engaged | native chrome. `LiquidGlass` surfaces that are not chrome (the large content viewer) are liquid |
| iOS Low Power Mode | frosted |
| Android 10+ with Vulkan 1.1, RAM ≥ 3 GiB | liquid (Vulkan, or GLES when Flutter denylists the driver, Q6) |
| Android 10+ without Vulkan 1.1 | frosted |
| Android with RAM < 3 GiB or `isLowRamDevice` | frosted |
| Android ≤ 9 (Skia) | frosted |
| Battery saver | frosted |
| Raster p90 over budget for 3 windows | frosted for the session |
| Inside another `BackdropFilter` | frosted for that surface |
| Shader asset failed to load | frosted (logged once in debug) |
| Reduce transparency / high contrast | solid |
| Blur disabled with no battery saver (developer switch, or a GPU that cannot blur) | solid |
| Web | frosted (no shader filters) |
| `flutter test` without `--enable-impeller` | frosted (the existing widget tests are unchanged) |

## 7. Platform signals

### 7.1 Android (`SignalReader.kt`, `LiquidShellPlugin.kt`)

`RawSignals` gains four nullable fields, `isLowRamDevice`, `totalMemBytes`, `vulkan11` and (unchanged) `apiLevel`. They are read in `read()` and wrapped in the existing `attempt { }`:

- `isLowRamDevice`: `ActivityManager.isLowRamDevice()`.
- `totalMemBytes`: `ActivityManager.MemoryInfo().also(am::getMemoryInfo).totalMem`.
- `vulkan11`: `packageManager.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_VERSION, 0x00401000)`.

These facts never change while the process runs. They are read on every `send()` because they are cheap, but they need no observer.

`SignalReader.toPayload` adds two keys:
- `"lowEnd"` = `isLowRamDevice == true || (totalMemBytes != null && totalMemBytes < LOW_END_BYTES)`, with `LOW_END_BYTES = 3L * 1024 * 1024 * 1024` (Q5).
- `"glesOnly"` = `apiLevel >= 29 && vulkan11 == false`. Unknown (null) counts as false.

JVM unit tests in `SignalReaderTest` cover each value, and the two `null` cases.

### 7.2 iOS (`LiquidShellPlugin.swift`)

`powerSave` = `ProcessInfo.processInfo.isLowPowerModeEnabled` (Q8). The plugin observes `Notification.Name.NSProcessInfoPowerStateDidChange`. That notification arrives on an arbitrary queue, so it uses `queue: .main`. The observer is added and removed with the existing reduce-transparency observer. `lowEnd` and `glesOnly` are always false on iOS: Metal is always present, and the frame guard covers slow iPhones.

### 7.3 Platform interface

`LiquidPlatformSignals` gains `lowEnd` and `glesOnly`. Both default to false, are decoded leniently in `fromMap`, and are included in `==`, `hashCode` and `toString`. This is additive for implementers, because the constructor parameters have defaults. The package versions bump to `0.1.0-dev.3`.

### 7.4 Frame guard (Dart, internal, Q7)

`LiquidFrameGuard` is process-wide and reference-counted like the signals controller:

- **Who holds it:** every attached `RenderLiquidBackdrop` holds a reference (acquired in `attach`, released in `detach`), so the guard only measures frames while liquid glass is actually on screen.
- **Subscription:** while at least one is held, it subscribes with `SchedulerBinding.instance.addTimingsCallback`.
- **Windows:** it groups `FrameTiming.rasterDuration` into windows of 60 frames.
- **The rule:** a window is slow when its p90 is above `1.25 × budget`, where `budget = max(1 s / refreshRate, 16.667 ms)` (`PlatformDispatcher.views.first.display.refreshRate`, default 60). The 60 Hz floor matters on 120 Hz ProMotion panels: an app capped at 60 Hz there still reports 120 Hz, and an 8.3 ms budget would demote it for frames that are on time. After **3 consecutive** slow windows, `slowFrames` becomes true for the rest of the process. It logs once in debug.
- **Pure decision:** `bool liquidFramesTooSlow(List<Duration> windowP90s, Duration budget)` and `Duration p90(List<Duration>)` are pure and unit-tested.
- **When it runs:** only in profile and release (`kProfileMode || kReleaseMode`), or when `@visibleForTesting debugLiquidFrameGuardEnabled = true`. A debug build's raster times would demote every developer's emulator.
- **Why it never flips back:** demotion is sticky. Once on frosted, raster time drops, and switching back would oscillate.

## 8. Every glass surface through `LiquidGlass` (L3)

The surfaces as of today (`grep LiquidGlass( lib/src`):

| Surface | File | Shape | Liquid notes |
|---|---|---|---|
| Compact tab-bar pill | `chrome/tab_bar.dart:181` | pill | the `AnimatedSize` inside the glass relayouts, so the rect updates each frame |
| Trailing ⌕ circle | `chrome/tab_bar.dart:397` | circle (pill radius on a square) | |
| Sidebar | `chrome/sidebar.dart:125` | `BorderRadius.zero`, flush with three screen edges | screen-edge rule: only the inner edge gets a bezel and rim (§4.2). In RTL the inner edge is the left one, and the rule handles it with no special case |
| Sidebar toggle | `chrome/sidebar_toggle.dart:28` | circle | |
| Large content viewer | `chrome/large_content_viewer.dart:103` | rounded panel | centred, so a plain liquid panel |

There are **no** other `BackdropFilter`s in `lib/` apart from the shell's `BackdropGroup`. The future dialogs, action sheets, back button and search field (P3, P3a) must use `LiquidGlass`, under L3.

**Gate.** `tool/check_glass_seam.sh` runs inside `make provenance`, so the pre-commit hook and CI already run it. It fails when `BackdropFilter`, `ImageFilter.blur`, `ImageFilter.shader` or `ImageFilter.compose` appears in `liquid_shell/lib` outside `lib/src/glass/`. The shell's `BackdropGroup` is allowed, because it reads nothing.

## 9. Example

### 9.1 A forced tier turns native chrome off (Q11)

`nativeChromePossible` gains one condition: `!glassTierForced`. `LiquidShell` passes `LiquidGlassScope.policyOf(context).forcedTier != null`.

The rationale: an app that forces a glass tier is asking for Flutter glass drawn that way. Native chrome would silently ignore that request, the same reasoning as P2's Q6 for `chromeBuilder`. The rule needs no new API, and it gives the example a clean switch.

It is documented in `doc/native_chrome.md` ("When the native chrome is used") and in the `forcedTier` dartdoc. With E1 (VK-405), `forced_tier` is already a Flutter-only case.

### 9.2 The switch (L4)

- **State.** `example/lib/support/chrome_mode.dart` holds `enum ExampleChromeMode { native, flutterLiquid }` and `ChromeModeScope`, an `InheritedNotifier<ValueNotifier<ExampleChromeMode>>`. The scope sits above the `MaterialApp`'s navigator, so every case and every pushed page shares it.
- **Applying it.** `CaseFrame` wraps each case page where `CaseList` pushes it, always in a `LiquidGlassScope`. In `flutterLiquid` that scope forces `LiquidGlassTier.liquid`; in `native` it forces nothing. Because the scope is always present, switching never rebuilds the case or loses its state. **No case's shell code and no README snippet change**, except the forced-tier case's one line of text (§9.2, last bullet).
- **Where the switch is.** `DemoPage` draws a `SegmentedButton` row under its title when a `ChromeModeScope` is above it. It is inside the scrolling body, so it never sits under the Flutter or native chrome (a top-corner overlay was tried and covered the regular-width top bar). The form factors case, which has no `DemoPage`, shows the switch as the first row of its list. It has two segments:
  - The first segment is labelled "Native" where native chrome can engage (iOS 26), and "Auto" elsewhere, with the tooltip "Native chrome needs iOS 26; here the library picks the tier". In this mode the library behaves by default: native chrome where it engages, otherwise the automatic tier.
  - "Flutter liquid" forces the liquid tier, which also turns native chrome off (§9.1).
- **"Flutter by nature" cases.** These come from E1: custom chrome, forced tier, custom theme, standalone widgets, form factors and narrow width. They keep the switch, so liquid can still be forced. E1's "drawn by Flutter" note stays. In the forced-tier case the case's own tier segment wins, because it is the inner scope.
- **Semantics.** The switch has the label "Chrome: native or Flutter liquid".
- **Startup.** `main()` calls `WidgetsFlutterBinding.ensureInitialized()` and then `await LiquidGlass.precache()`, so screenshots never catch the startup cross-fade.
- **The forced-tier case** no longer says "No liquid renderer is registered: drawing frosted". Its liquid segment shows the built-in liquid tier where supported.

## 10. Testing

### 10.1 Unit tests (pure, `make test`)

- **`liquid_optics_test.dart`:** `liquidUniforms` with exact float lists for a pill, a circle, the sidebar (screen-edge rule on three sides, and in RTL), per-corner radii, the bezel and radius clamps, `refraction` 0 and 2, `dispersion` 0, and scales 1, 2 and 3. It also checks `liquidDisplacement(x)`, a Dart mirror of steps 4–7 that exists for tests and docs: peak about 27 pt near the edge, 0 at the edge and for `x ≥ 1`.
- **`glass_policy_test.dart`, rewritten for the new table:**
  - each signal alone → its tier;
  - `blurDisabled` with `powerSave` → frosted, and `blurDisabled` alone → solid;
  - forced liquid wins over `glesOnly`, `lowEnd` and `powerSave`;
  - a registered liquid renderer wins over the built-in one;
  - built-in unsupported → frosted.
- **`frame_guard_test.dart`:** `p90`, `liquidFramesTooSlow` (2 slow windows → false, 3 → true, a fast window resets the run), the 120 Hz display keeping the 16.667 ms floor, and that it is off in debug unless the flag is set.
- **Platform interface:** `fromMap` with and without the new keys; `==` and `toString`.
- **Kotlin `SignalReaderTest`:** `lowEnd` (low-RAM flag, 2.9 GiB, 3 GiB exactly → false, null), `glesOnly` (API 28 → false, API 29 without Vulkan → true, with Vulkan → false, null → false).

### 10.2 Widget tests (no Impeller, `make test`)

`ImageFilter.shader` throws without Impeller. So `RenderLiquidBackdrop` takes a `LiquidFilterFactory`, and tests inject `(shader, sigma) => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)` while recording the uniforms. The program loads with `tester.runAsync` (proven in `flutter test`). With `debugLiquidGlassCanRefractOverride = true`, the tests cover:

- **Default tier:** liquid is the default when supported. The tree has a `LiquidBackdrop` under a `ClipRRect`, with the `BackdropGroup` key.
- **Recorded uniforms:** they equal `liquidUniforms(...)` for the laid-out rect at view ratio 3.
- **Route push:** pushing a route moves the glass, and the uniforms follow on the same pumped frame.
- **Scrolling:** a glass inside a `ListView` follows the scroll on the same frame.
- **Drift guard:** a glass under a `RepaintBoundary` moved by a layer-only `Transform` change is corrected on the next frame.
- **Nesting:** a glass inside `BackdropFilter(child: …)` resolves to frosted, while a glass inside another `LiquidGlass`'s child stays liquid.
- **Program state:** with the program not loaded the glass is frosted, and once loaded it cross-fades to liquid without rebuilding its child (P1's state-survival test, reused).
- **Teardown:** detach disposes the shader and removes the drift-guard entry.
- **`precache`:** completes, and a second call reuses the program.

The global test config resets `debugLiquidGlassCanRefractOverride` to `null` after each test. It does not set it to `false`: without `--enable-impeller` the probe already returns false, so every existing P1 and P2 widget test keeps drawing frosted unchanged, and a `false` would pin frosted in the `--enable-impeller` runs too (`make test-impeller`, the liquid goldens), so they could never draw liquid.

### 10.3 Impeller goldens (`make goldens`)

- **Tag.** A new tag, `liquid_golden`, run with `flutter test --enable-impeller --tags liquid_golden`. The existing `golden` tag still runs without Impeller, so its images stay byte-identical.
- **What is captured.** The cases in liquid on iPhone, iPad landscape and Android, light and dark. They are captured from the root through `expectDocImage` (§3.2).
- **Output.** They write doc images `liquid_*.png`, regenerated only by `make goldens-update`, which gains an Impeller pass.
- **Blocking or not (Q12).** They block on macOS + 3.44.x with the existing 0.5 % tolerance. Task 1 runs them twice on the CI runner before they are made blocking. If the CI macOS runner and the local machine differ by more than the tolerance, `liquid_golden` becomes non-blocking (`continue-on-error`), and the side-by-side screenshots stay the gate.
- **Liquid probe tests.** In the `liquid_shell` package, `test/impeller/liquid_shader_test.dart` (tag `impeller`, run by `make test-impeller`) renders the real shader over a test pattern. It asserts four pixel facts:
  - the sampled pixel 2 pt inside the left edge comes from further in (lensing);
  - the top edge is brighter than the bottom edge (specular);
  - the centre equals tint over blurred backdrop within a tolerance;
  - the outer sides of a sidebar on the screen edge show no rim.

  These assertions read raw pixels, so they are less brittle than whole-image goldens.

### 10.4 Integration (simulator and emulator)

- **Signals.** `signals_test.dart` is updated: battery saver → frosted, and blur disabled alone → solid. It adds `EXPECT_LOW_END` and `EXPECT_GLES_ONLY`, which `tool/integration_android.sh` computes from the device: `adb shell pm has-feature android.hardware.vulkan.version 4198400`, and `MemTotal` from `/proc/meminfo`. With no signals and Impeller, it asserts that `LiquidBackdrop` is in the tree, after `await LiquidGlass.precache()`.
- **New: `liquid_compare_test.dart`.**
  - For each case in `kCompareCases`, it opens the case, scrolls the demo list to a fixed offset (the wallpaper and the cards make a busy backdrop), and takes `binding.takeScreenshot('<platform>_<device>_<case>_<mode>')`. On iOS 26 it does this in both modes, and on Android in `flutterLiquid`.
  - `kCompareCases` is the E1 native cases: basic, badges, sidebar-only, sidebar slots, trailing, guard, hide chrome and native chrome.
  - On iOS it also asserts the mode took effect: native chrome is engaged in `native`, and `LiquidBackdrop` is present in `flutterLiquid`.
- **Composition.** `tool/side_by_side.dart` is pure Dart and reuses the PNG decode and encode of `tool/compress_pngs.dart`. It places native on the left and Flutter liquid on the right with a 24 px gap. For Android it pairs the iPhone native shot with the Android liquid shot, scaled to the same height with bilinear sampling. The output goes to `build/compare/` and to `doc/images/compare_*.png` for the README subset (`make compare-images`). There are no text labels. Captions live in the README.

## 11. Acceptance (L5)

1. **On simulators and the emulator**, run `make compare-images`:
   - iPhone 17 Pro and iPad Air 11" (M4) on iOS 26.5, each simulator created and deleted by the script;
   - the Android API 36 emulator (`google_apis` arm64, created by the developer and passed in as `ANDROID_SERIAL`).

   This produces `build/compare/*.png`. The owner reviews the set as an artifact page or the CI artifacts.
2. **The owner then checks a real iPad and iPhone** with "Flutter liquid" selected, using the OTA build of the example. Nobody else touches physical devices.
3. **Pass criteria**, judged by eye, case by case:
   - the lens edge reads as glass, not as a border;
   - the highlight sits on the top and leading edges;
   - text and icons on the glass stay legible over the wallpaper in light and dark;
   - nothing is misplaced while pushing and popping a case or while scrolling.

   The plan records the owner's verdict on VK-348.

## 12. CI, docs, versions

### 12.1 Make targets

| Target | What |
|---|---|
| `make test` | It now excludes the tags `golden`, `liquid_golden` and `impeller`, so it is unchanged in speed and needs no Impeller |
| `make test-impeller` (new) | `flutter test --enable-impeller --tags impeller` in `liquid_shell` |
| `make goldens` | Runs the `golden` tag as now, then `--enable-impeller --tags liquid_golden` |
| `make goldens-update` | The same two passes with `--update-goldens`, then `compress_pngs` |
| `make compare-images` (new) | `tool/compare_ios.sh` and `tool/compare_android.sh` (simulators, emulator), then `tool/side_by_side.dart` and `compress_pngs` |
| `make verify` | Adds `test-impeller`. It is macOS-only like `goldens`, and Linux CI skips it with a message |

### 12.2 CI jobs (`.github/workflows/ci.yaml`)

- The `goldens` job (macOS) runs `make goldens`, which now includes `liquid_golden` (Q12), and adds `make test-impeller`.
- `integration-android` runs the updated `signals_test` and `liquid_compare_test` in `flutterLiquid` (API 34 `google_apis` x86_64, as now). It uploads `build/integration_screenshots/`.
- `integration-ios-native` (iPad and iPhone legs) runs `liquid_compare_test` after `native_shell_test`, uploads the screenshots, and runs `tool/side_by_side.dart` on the leg's pairs.
- Nothing is added to the Linux `checks` job: shader compilation is already covered by `make test`'s asset build.

### 12.3 Docs and versions

- **`doc/tiers.md`:** the new table, the new signals and `prefersFrosted`, the changed P1 rules (Skia → frosted, battery saver → frosted, Low Power Mode), and the frame guard.
- **`doc/liquid.md` (new):** what the shader does in plain words, the theme fields with images (`refraction` 0, 1 and 2, `dispersion` 0 and 0.3, from goldens), `precache`, the nesting limit, performance notes and the budget rule, and why the shader is clean-room.
- **`doc/native_chrome.md`:** a forced tier turns native chrome off.
- **README:** a "Liquid glass" section with the hero comparison images and a link to `doc/liquid.md`. The "Tiers" section is updated.
- **CHANGELOG** for all four packages, at `0.1.0-dev.3`. Breaking: `canBlur` is removed, `debugLiquidGlassCanBlurOverride` is renamed, battery saver now gives frosted, and liquid is the default.
- **`CLAUDE.md` and `CONTRIBUTING.md`:** the new commands, and the rule "the shader is clean-room; never open other glass packages' shaders".

## 13. Accessibility

| Setting | Behaviour | Why |
|---|---|---|
| Reduce Transparency (iOS); animator scale 0 or high contrast (Android, P1) | solid | L2. Apple makes glass "frostier", while L2 chose solid for maximum legibility |
| Increase Contrast (iOS `highContrast`) | solid, with the P1 border | Apple: "predominantly black or white … contrasting border" [S8] |
| Reduce Motion (`disableAnimations`) | the tier change is instant (P1). The shader is static, with no motion to reduce | Apple: "disables any elastic properties" |
| Bold Text, text scale | unchanged (P1 §5.10). The glass is a background only | — |
| VoiceOver and TalkBack | unchanged. The shader layer adds no semantics, because `LiquidBackdrop` has no semantics and its child is an empty `SizedBox` | — |
| Legibility on liquid glass | Liquid is clearer than frosted, so contrast gets worse over busy backdrops. Mitigations: `liquidTint` alpha (0.40 light, 0.45 dark), a σ 2 blur (both tuned against native in §3.6.1; clearer than the first σ 6 / 50 %, which read as frosted), and the side-by-side review over the busiest backdrop. The owner can raise `liquidTint` alpha in the theme. A later phase can add adaptive dimming (non-goal) | WCAG 1.4.3 on labels is checked by eye in the review; a pixel-contrast checker is out of scope |

The example's switch is a labelled `SegmentedButton`, so it is reachable with switch control and screen readers.

## 14. Error handling

| Case | Debug | Release |
|---|---|---|
| Shader asset missing or fails to compile | log once: "liquid_shell: liquid glass shader failed to load (…); drawing frosted" | frosted |
| `ImageFilter.shader` throws (an engine changed under us) | `FlutterError.reportError` once; the render object switches to its blur-only filter and reports unsupported on the next build | frosted |
| No `RenderView` above, which is unexpected | assert; the rect falls back to `localToGlobal × 1` | best effort |
| Frame guard demotes | log once with the measured p90 | frosted |
| Forced liquid unsupported | P1's step-down log | frosted |

## 15. Risks

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| **The shader is placed from the screen rect** and goes wrong under an ancestor that creates its own pass (a nested `BackdropFilter`), or goes stale when an ancestor layer moves without repaint | M / H: misplaced lens during transitions | §5.3: route and scroll listeners (same frame), drift guard (next frame), nested → frosted (§5.2). Widget tests for each path, and screenshots during push and pop |
| Pixel scale or origin differs on some device or an iPad windowed mode | L / H | Taken from `RenderView` at paint time. The iPad multitasking and Stage Manager window is still one pass (same as the spike's full screen). The integration test covers an iPad in a narrow window through P2's existing window tests |
| Flutter changes `FlutterFragCoord` semantics (flutter#193275 or a successor) | M over a year / H | `liquidUniforms` is the only place that knows the origin. A new `FlutterContentCoord` would simplify it. `liquid_golden` and the stable CI leg catch a change early |
| GLES driver bugs on Android | M / M | GLES-only → frosted, low-end → frosted, the frame guard, `isSupported` failing safe, and the GLES path tested on the emulator (its default backend) |
| Impeller goldens differ between the local Mac and the CI runner | M / L | Q12: measure in Task 1; non-blocking if so. The screenshots remain the gate |
| **The look misses iOS 26 on the owner's review** (subjective) | M / M | Theme knobs (Q4), and constants grouped in `liquid_optics.dart`. Task 6 includes one tuning round after the owner's review, and the screenshots make the gap concrete. The selection lens and motion are listed as next-phase items |
| Breaking changes for P1 users (`canBlur`, battery saver) | certain / L | `0.1.0-dev`, CHANGELOG. The only user is vankhan, which migrates in P5 |
| Conflicts with P2, VK-405 and P3a (VK-406), which also touch the example and signals | H / L | Rebase after P2 merges (L6). The example changes are confined to `support/` and `main.dart`. Signals are additive |
| Battery cost of liquid (an extra shader pass over the blur) | M / M | One backdrop copy per shell, a small blur σ, no shader work outside the clip, battery saver → frosted, and the frame guard |

## 16. Process

Plane VK-348 has state Todo with label `spec:approved` once the owner answers. Each `### Task N` of the plan becomes a sub-issue. Work is TDD per task, followed by a review, and `make verify` (with the macOS-only targets on a Mac) must be green before the PR. This phase runs in parallel with P3a (VK-406), as L6 orders.

## 17. Sources

- [S1] Flutter 3.44.6 `sky_engine/lib/ui/painting.dart`, `ImageFilter.shader` and `isShaderFilterSupported` (local SDK). Online: https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html
- [S2] Writing and using fragment shaders: https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- [S3] `SceneBuilder.pushBackdropFilter` (backdropId): https://api.flutter.dev/flutter/dart-ui/SceneBuilder/pushBackdropFilter.html, and `BackdropGroup`: https://api.flutter.dev/flutter/widgets/BackdropGroup-class.html
- [S4] flutter#170820, `ImageFilter.blur` breaks `ImageFilter.shader` in a `BackdropFilter` (fixed by #177687): https://github.com/flutter/flutter/issues/170820
- [S5] liquid_glass_widgets#333, public issue text only (`FlutterFragCoord` is pass-relative inside a backdrop-reading ancestor): https://github.com/sdegenaar/liquid_glass_widgets/issues/333
- [S6] flutter#193275, `unclippedInput` for `ImageFilter.shader` (open, design pushback): https://github.com/flutter/flutter/pull/193275
- [S7] flutter#191207, BackdropFilter raster cost, grouped vs bounded: https://github.com/flutter/flutter/issues/191207
- [S8] WWDC25 "Meet Liquid Glass": https://developer.apple.com/videos/play/wwdc2025/219/
- [S9] flutter#193502, Adreno ≤ 650 falls back to GLES on 3.44 (`IsKnownBadDriver`): https://github.com/flutter/flutter/issues/193502
- [S10] flutter#193428, Mali GLES fallback freeze in `glReadPixels`: https://github.com/flutter/flutter/issues/193428
- [S11] flutter#193899, GLES SIGSEGV when rasterising a Picture without Vulkan: https://github.com/flutter/flutter/issues/193899
- [S12] flutter#193148, vendor-SDK Vulkan gate on 3.47: https://github.com/flutter/flutter/issues/193148
- [S13] Impeller rendering engine (Vulkan 1.1 requirement, GLES fallback): https://docs.flutter.dev/perf/impeller
- [S14] `ActivityManager.isLowRamDevice`: https://developer.android.com/reference/android/app/ActivityManager#isLowRamDevice()
- [S15] Android performance class: https://android-developers.googleblog.com/2022/03/using-performance-class-to-optimize.html
- [S16] Apple HIG, Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- [S17] Rounded-box signed distance, public maths (Inigo Quilez, "2D distance functions"): https://iquilezles.org/articles/distfunctions2d/
- [S18] Public description of convex-bezel refraction with Snell's law at n = 1.5 (prose only): https://github.com/eirasmx/webglass (README), https://dev.to/maxgeris/recreating-apples-liquid-glass-effect-on-the-web-with-css-svg-and-physics-based-refraction-5cek
- [S19] liquid_glass_easy#21, public issue text only (lens desyncs from its clip when an ancestor moves it): https://github.com/AhmeedGamil/liquid_glass_easy/issues/21
- [S20] flutter#136083, a clip offsetting backdrop image filters (closed): https://github.com/flutter/flutter/issues/136083
- [S21] Android `PackageManager.FEATURE_VULKAN_HARDWARE_VERSION`: https://developer.android.com/reference/android/content/pm/PackageManager#FEATURE_VULKAN_HARDWARE_VERSION

## Quyết định cần chủ sản phẩm xác nhận

> **Chủ sản phẩm chấp nhận toàn bộ đề xuất (10/10/2026: "chốt làm cả 3 việc đi").** Riêng Q16 → 0.1.0-dev.3 hoặc dev.4 tuỳ phần nào merge trước.

Mỗi dòng có đề xuất mặc định. Chủ sản phẩm trả lời "Ok hết" thì áp dụng toàn bộ đề xuất.

| Q# | câu hỏi | đề xuất |
|---|---|---|
| Q1 | Độ khúc xạ mặc định của mép kính bao nhiêu? | **Dải mép (bezel) 12pt, độ dày 18pt, chiết suất 1.5.** Nội dung sát mép bị kéo vào tối đa ~9pt, ở 1/3 dải còn ~3pt, giữa kính phẳng. **Sau vòng chỉnh (§3.6.1): dải mép 20pt, độ dày 48pt** — kéo vào tối đa ~27pt, dải mép hiện lại chữ bên trong bị lật ngược như kính iOS 26. Đèn cố định góc trên-trái, không dùng cảm biến nghiêng máy. Sau buổi duyệt ảnh đặt cạnh nhau được chỉnh một vòng (Task 6) |
| Q2 | Tán sắc màu (dispersion) mặc định? | **Bật, mức 0.3** (chiết suất R/B lệch ±0.03): viền màu rất nhẹ, chỉ ở dải mép, đúng chữ "nhẹ" của L1. Đặt `dispersion: 0` để tắt |
| Q3 | Lớp liquid có làm mờ nền không, mờ bao nhiêu? | **Có, σ = 6** (frosted đang là 10), dùng blur của engine nối trước shader (`compose`), không tự blur trong shader. Rẻ hơn nhiều mà đẹp hơn. Đã so với ảnh tab bar native iOS 26 của P2: σ 3 quá trong, σ 6 gần native (§3.6). **Sau vòng chỉnh (§3.6.1): σ = 2** — σ 6 làm kính thành kính mờ (frosted), không thấy thấu kính |
| Q4 | `LiquidGlassTheme` có mở tham số shader cho app chỉnh không? | **Mở 4 trường:** `liquidTint` (màu phủ, sáng 50% / tối 55% màu surface; 22% thử trước đó quá trong, chữ phía sau đọc lẫn vào nhãn tab; **sau vòng chỉnh §3.6.1: sáng 40% / tối 45%**), `refraction` (0–2, mặc định 1), `dispersion` (0–1, mặc định 0.3), `liquidBlurSigma` (mặc định 6; **sau vòng chỉnh: 2**). Còn lại (dải mép, viền sáng, chiết suất, hướng đèn) là hằng nội bộ, đổi được mà không vỡ API |
| Q5 | Ngưỡng "máy yếu" trên Android? | **`isLowRamDevice` hoặc RAM < 3 GiB** (máy 3 GB trở xuống) → frosted. Máy 4 GB trở lên được liquid; nếu thực tế giật thì bộ canh khung hình (Q7) tự hạ |
| Q6 | Android 10+ chạy GLES thì liquid hay frosted? | **Máy không có Vulkan 1.1 (đúng nghĩa "chỉ GLES") → frosted.** Máy có Vulkan nhưng Flutter 3.44 vẫn đẩy sang GLES (Adreno ≤ 650, ví dụ Snapdragon 865 trở xuống) → **vẫn liquid**, shader có nhánh GLES đã chạy thử trên emulator, và có bộ canh khung hình đỡ. Không dò tên GPU (phải tạo ngữ cảnh EGL và chép danh sách đen của Flutter, đổi theo từng bản) |
| Q7 | Có tự hạ xuống frosted khi khung hình thực tế chậm không? | **Có.** Khi đang hiện liquid, nếu 3 cửa sổ liên tiếp (mỗi cửa sổ 60 khung) có p90 thời gian raster > 1.25 × ngân sách khung (16.7ms ở 60Hz) thì hạ frosted đến hết phiên. Chỉ chạy ở bản profile/release |
| Q8 | iOS bật Chế độ nguồn điện thấp (Low Power Mode) có hạ frosted không? | **Có**, coi như "tiết kiệm pin" của L2 (đổi quyết định P1 Q8 vốn bỏ qua). Kính liquid là shader của mình nên tốn pin của mình. Kính native iOS 26 không bị ảnh hưởng |
| Q9 | Tiết kiệm pin, Skia và "tắt hiệu ứng mờ" của hệ thống xử lý thế nào? | **Tiết kiệm pin → frosted** (L2; P1 từng cho solid). Android ≤ 9 (Skia) → **frosted** (P1 từng cho solid, Skia vẫn blur tốt). Riêng "tắt blur" của hệ thống mà **không** bật tiết kiệm pin (công tắc nhà phát triển, GPU không blur được, "Giảm hiệu ứng mờ" của Android 16) → **vẫn solid** như P1 |
| Q10 | Kính nằm bên trong một `BackdropFilter` khác (ví dụ trong `CupertinoNavigationBar` hay khung mờ tự làm của app) thì sao? | **Bề mặt đó vẽ frosted.** Spike cho thấy toạ độ shader bị lệch theo vùng của filter cha (Flutter 3.44 chưa có cách sửa). Kính lồng trong *nội dung* của một `LiquidGlass` khác thì vẫn liquid (không phải lồng filter) |
| Q11 | Ép tầng kính (`forcedTier`) có tắt khung native không? | **Có.** App đã ép tầng kính là muốn kính Flutter vẽ theo cách đó, cùng lý do với `chromeBuilder` (P2 Q6). Công tắc "Native / Flutter liquid" của ví dụ dùng đúng cơ chế này, không cần API mới |
| Q12 | Golden có chụp kính liquid và có chặn CI không? | **Có chụp và có chặn** (macOS + Flutter 3.44.x, sai số 0.5% như golden hiện tại), chạy bằng `flutter test --enable-impeller`. Task 1 chạy thử 2 lần trên máy CI; nếu lệch quá sai số giữa máy CI và máy local thì chuyển golden liquid sang không chặn. Ảnh đặt cạnh nhau với iOS 26 native vẫn là cổng nghiệm thu chính |
| Q13 | Có chấp nhận đổi API (breaking) không? | **Có**, vì đang ở `0.1.0-dev`: bỏ `LiquidGlassSignals.canBlur`, đổi `debugLiquidGlassCanBlurOverride` → `debugLiquidGlassCanRefractOverride`, thêm `lowEnd`, `glesOnly`, `slowFrames`, `prefersFrosted`, `LiquidGlass.precache()`, 4 trường theme. Ghi rõ trong CHANGELOG. Văn Khấn chuyển sang ở P5 |
| Q14 | Sidebar dính sát mép màn hình thì vẽ mép kính thế nào? | **Chỉ mép trong (mép giáp nội dung) có khúc xạ và viền sáng;** ba mép dính màn hình thì không, tự động theo quy tắc "mép trùng mép màn hình" (RTL tự đúng). Không đổi sidebar thành tấm nổi bo góc (để phase sau nếu muốn giống iPadOS 26 hơn) |
| Q15 | Những gì của iOS 26 chưa làm ở phase này? | **Để phase sau:** thấu kính chạy theo tab đang chọn, ánh sáng theo cảm biến nghiêng, hiệu ứng "hiện dần" khi kính xuất hiện, co giãn khi chạm, góc bo liên tục (superellipse), màu phủ tự đổi theo độ sáng nền. Phase này chỉ làm phần kính tĩnh (khúc xạ, viền sáng, tán sắc, mờ, màu phủ) |
| Q16 | Phiên bản? | **`0.1.0-dev.3`** cho cả 4 gói, có mục CHANGELOG; không publish |
