# liquid_shell: core liquid glass tier Implementation Plan

> **Owner approval:** pending. The owner approves this plan together with the spec `docs/specs/2026-10-10-liquid-tier-design.md`. The spec's table "Quyết định cần chủ sản phẩm xác nhận" lists Q1–Q16, and this plan implements every recommended default. If the owner changes a row, the tasks that row names change with it.
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a clean-room liquid glass tier in the core `liquid_shell` package, make it the default with frosted and solid fallbacks, route every glass surface through it, add a "Native / Flutter liquid" switch to the example, and accept the result with side-by-side screenshots against iOS 26 native (spec `docs/specs/2026-10-10-liquid-tier-design.md`, owner decisions L1–L5).

**Architecture:**
- **The lens.** A fragment shader declared in `liquid_shell/pubspec.yaml` draws it. It runs as the outer half of `ImageFilter.compose(outer: shader, inner: blur)` inside a custom `RenderLiquidBackdrop`.
- **Placement.** At paint time, that render object computes the glass rect in the render pass's physical pixels (`RenderView.configuration.toMatrix() × getTransformTo(null)`). It follows ancestors that move without repainting it through route and scroll listeners plus a post-frame drift guard.
- **Tier choice.** A built-in `LiquidShaderRenderer` becomes the default liquid renderer behind P1's `LiquidGlassPolicy`. New signals (`lowEnd`, `glesOnly`, iOS Low Power Mode, a frame guard) send devices to frosted under owner decision L2.

**Tech Stack:**
- Flutter 3.44.6 and Dart 3.12 (fvm), with Impeller fragment shaders (GLSL 460 core, compiled by impellerc during the asset build);
- `flutter_test`, `flutter test --enable-impeller` and `integration_test`;
- Kotlin (Android plugin, JVM unit tests) and Swift (iOS plugin);
- pure Dart tooling under `tool/`.

## Global Constraints

- **Floor.** Flutter `>=3.44.0`, Dart `^3.12.0`, iOS deployment target `15.0`; fvm pins `3.44.6` (`.fvmrc`).
- **Lints.** `very_good_analysis` is pinned to `10.3.0`, and `dart analyze --fatal-infos --fatal-warnings` must be clean. Never loosen `analysis_options.yaml`.
- **Dependencies.** Runtime dependencies stay Flutter + our packages + `plugin_platform_interface`, plus `meta` in `liquid_shell_ios`. **No new dependency of any kind**, dev or runtime. `pigeon: 27.3.0` stays as it is.
- **Clean room (L1).** The shader and every line of glass maths are written from the spec's §4 derivation. **Never open, search or copy the source of `liquid_glass_renderer`, `liquid_glass_widgets`, `liquid_glass_easy`, `oc_liquid_glass` or any other glass package**, including in the pub cache.
- **Shader asset.** It is declared as `flutter: shaders: - shaders/liquid_glass.frag` in `liquid_shell/pubspec.yaml` and loaded as `packages/liquid_shell/shaders/liquid_glass.frag`, then `shaders/liquid_glass.frag`.
- **Shader uniforms.** Float indices 0–1 are the engine's size, our floats are indices 2–25 (spec §4.2), and sampler 0 is the backdrop. On GLES only the texture lookup flips y (`#ifdef IMPELLER_TARGET_OPENGLES`).
- **Tier rules (spec §6).**
  - `prefersSolid = reduceTransparency || highContrast || (blurDisabled && !powerSave)`.
  - `prefersFrosted = powerSave || lowEnd || glesOnly || slowFrames`.
  - A forced tier wins over every signal.
  - The built-in liquid renderer is supported only with shader filters, a loaded program, and no ancestor `RenderBackdropFilter`.
- **Thresholds.** `lowEnd` = `isLowRamDevice || totalMem < 3 GiB` (3 × 1024³ bytes). `glesOnly` = API ≥ 29 and no `FEATURE_VULKAN_HARDWARE_VERSION` ≥ `0x00401000`. The frame guard demotes after 3 consecutive 60-frame windows whose raster p90 is above 1.25 × (1 s / refresh rate). It is sticky, and runs in profile and release only.
- **Theme defaults (Q3, Q4).** `liquidTint` = surface @ 0.50 (light) or 0.55 (dark); `refraction` 1.0; `dispersion` 0.3; `liquidBlurSigma` 6. These values were tuned against P2's native iPhone screenshot (spec §3.6).
- **Optics constants (Q1).** Bezel 12 pt, thickness 18 pt × refraction, index 1.5, rim width 1.5 pt, saturation 1.1, light direction (−0.5, −0.85).
- **Breaking changes (Q13).**
  - `LiquidGlassSignals.canBlur` is removed.
  - `debugLiquidGlassCanBlurOverride` becomes `debugLiquidGlassCanRefractOverride`.
  - `liquidGlassCanBlur()` becomes `liquidGlassCanRefract()`.
  - Versions become `0.1.0-dev.3` (Task 9).
- **Tests.**
  - Test configs set no tier override. Without `--enable-impeller` there are no shader filters, so glass is frosted, which keeps every existing widget test and frosted golden byte-identical (checked in the dry run). Liquid widget tests opt in with `debugLiquidGlassCanRefractOverride = true` and `debugLiquidFilterFactory`.
  - `make test` excludes the tags `golden`, `liquid_golden` and `impeller`.
  - Impeller-only tests use tag `impeller` (package) or `liquid_golden` (example). They run with `--enable-impeller` on macOS only.
  - Liquid goldens are captured from the root (`expectDocImage`), never from an inner `RepaintBoundary`.
- **Provenance.** Do not write `vankhan`, `Văn Khấn`, `LocaleKeys`, `easy_localization`, `AppColors` or `GetIt` outside `docs/`. Do not write `go_router` outside `*.md` (`make provenance`). The new glass seam gate also runs in `make provenance`.
- **Commits.**
  - Format: `<type>(<scope>): <summary> (VK-348)`, with scopes `shell glass platform ios android example docs ci`. End with a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Run `bash .githooks/pre-commit` by hand before every commit, and stage by explicit path.
  - Never use `--no-verify`, never set `core.hooksPath`, and never change git or flutter config. No pushes and no PR without the owner.
- **Devices.**
  - Create your own simulators (`xcrun simctl create`) and your own AVD from `system-images;android-36;google_apis;arm64-v8a`. Delete them when done.
  - Never touch other AVDs, other running emulators or physical devices.
  - Keep ≥ 10 GB disk free, and delete `build/` output you created.
- **Shell.** `rm` is aliased in this environment, so use `command rm`.
- **Other worktrees.** Do not touch `liquid_shell-vk346` or `liquid_shell-vk406`. After P2 merges, rebase this branch onto `main` before Task 8 (owner decision L6).

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `liquid_shell/shaders/liquid_glass.frag` | 1 | The lens shader (spec §4) |
| `liquid_shell/pubspec.yaml` | 1 | `flutter: shaders:` |
| `liquid_shell/lib/src/glass/liquid_optics.dart` | 1 | Constants, `LiquidOpticsParams`, `liquidUniforms`, `liquidDisplacement` |
| `liquid_shell/test/unit/liquid_optics_test.dart` | 1 | Exact uniform and displacement tests |
| `liquid_shell/test/impeller/liquid_shader_test.dart` | 1 | Pixel facts of the real shader (tag `impeller`) |
| `liquid_shell/dart_test.yaml`, `Makefile` | 1 | Tags, `test-impeller`, test exclusions |
| `liquid_shell/lib/src/glass/glass_theme.dart` | 2 | `liquidTint`, `refraction`, `dispersion`, `liquidBlurSigma` |
| `liquid_shell/lib/src/glass/shader_program.dart` | 2 | `LiquidShaderProgram` loader |
| `liquid_shell/lib/src/glass/liquid_glass.dart` | 2, 4 | `LiquidGlass.precache`; listens to program, signals, frame guard |
| `liquid_shell/lib/src/glass/liquid_backdrop.dart` | 3 | `LiquidBackdrop`, `RenderLiquidBackdrop`, filter factory |
| `liquid_shell/lib/src/glass/drift_guard.dart` | 3 | Post-frame re-check of attached backdrops |
| `liquid_shell/lib/src/glass/liquid_renderer.dart` | 4 | `LiquidShaderRenderer` |
| `liquid_shell/lib/src/glass/policy.dart`, `signals_controller.dart`, `tier.dart`, `lib/liquid_shell.dart` | 4 | New signals, `prefersFrosted`, built-in liquid, renames, exports |
| `liquid_shell_platform_interface/lib/src/platform_signals.dart` | 4 | `lowEnd`, `glesOnly` |
| `liquid_shell_android/android/src/main/kotlin/.../SignalReader.kt`, `LiquidShellPlugin.kt`, `SignalReaderTest.kt` | 5 | RAM and Vulkan facts |
| `liquid_shell_ios/.../LiquidShellPlugin.swift` | 5 | Low Power Mode |
| `liquid_shell/example/integration_test/signals_test.dart`, `tool/integration_android.sh` | 5 | New expectations |
| `liquid_shell/lib/src/glass/frame_guard.dart` | 6 | `LiquidFrameGuard`, `p90`, `liquidFramesTooSlow` |
| `tool/check_glass_seam.sh`, `tool/test/check_glass_seam_test.dart`, `tool/check_provenance.sh` | 7 | Gate: no backdrop filters outside `lib/src/glass/` |
| `liquid_shell/lib/src/native/native_layout.dart`, `shell/liquid_shell.dart` | 7 | A forced tier turns native chrome off |
| `liquid_shell/example/lib/support/chrome_mode.dart`, `support/demo_page.dart`, `main.dart`, `cases/forced_tier.dart` | 8 | The switch, `CaseFrame`, `precache` |
| `liquid_shell/example/test/chrome_mode_test.dart` | 8 | Switch behaviour |
| `liquid_shell/example/test/goldens/liquid_test.dart`, `test/flutter_test_config.dart`, `test/support/golden_harness.dart`, `dart_test.yaml` | 9 | Impeller goldens |
| `liquid_shell/example/integration_test/liquid_compare_test.dart` | 9 | Native and liquid screenshots |
| `tool/side_by_side.dart`, `tool/test/side_by_side_test.dart`, `tool/compare_ios.sh`, `tool/compare_android.sh`, `tool/update_goldens.sh` | 9 | Composition and scripts |
| `liquid_shell/doc/liquid.md`, `doc/tiers.md`, `doc/native_chrome.md`, `README.md`, `CHANGELOG.md` ×4, pubspecs | 9 | Docs and versions |
| `.github/workflows/ci.yaml`, `CLAUDE.md`, `CONTRIBUTING.md` | 10 | CI and contributor docs |

Tasks:
- **1** Shader and optics maths
- **2** Theme fields and the program loader
- **3** `RenderLiquidBackdrop` and following moving ancestors
- **4** The built-in liquid renderer and the tier policy
- **5** Native signals (Android RAM/Vulkan, iOS Low Power Mode)
- **6** Frame guard
- **7** Every surface through `LiquidGlass`; a forced tier turns native off
- **8** Example switch
- **9** Impeller goldens, side-by-side screenshots and docs
- **10** CI, verification, owner review and one tuning round

Tasks 1–4 are sequential. Tasks 5, 6 and 7 depend on 4 and are independent of each other. Task 8 needs 4 and 7. Task 9 needs 8. Task 10 is last.

Set up once (the controller, before Task 1):

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk348   # branch VK-348-liquid-tier
make get
fvm flutter --version | head -1   # Flutter 3.44.6
```

---

### Task 1: The shader and the optics maths

**Files:**
- Create: `liquid_shell/shaders/liquid_glass.frag`
- Create: `liquid_shell/lib/src/glass/liquid_optics.dart`
- Create: `liquid_shell/test/unit/liquid_optics_test.dart`
- Create: `liquid_shell/test/impeller/liquid_shader_test.dart`
- Modify: `liquid_shell/pubspec.yaml` (the `flutter:` block)
- Modify: `liquid_shell/dart_test.yaml`
- Modify: `Makefile` (`test`, `coverage`, new `test-impeller`, `verify`)

**Interfaces:**
- Produces:
  - `abstract final class LiquidOptics` with these static consts:
    - `double bezel = 12`
    - `double thickness = 18`
    - `double index = 1.5`
    - `double rimWidth = 1.5`
    - `double saturation = 1.1`
    - `Offset light = Offset(-0.5, -0.85)`
    - `int firstIndex = 2`
    - `int floatCount = 24`
  - `@immutable class LiquidOpticsParams({required Color tint, required Color rim, required double refraction, required double dispersion, required double blurSigma})`, with `==` and `hashCode`;
  - `Float32List liquidUniforms({required Rect rect, required BorderRadius radii, required LiquidOpticsParams params, required double scale, required Size pass})`;
  - `double liquidDisplacement(double x, {double bezel = LiquidOptics.bezel, double thickness = LiquidOptics.thickness, double index = LiquidOptics.index})`, which returns the signed inward displacement in the same unit as `bezel` and `thickness` (negative means inward);
  - the asset `packages/liquid_shell/shaders/liquid_glass.frag`.

- [ ] **Step 1: Write the failing unit test**

`liquid_shell/test/unit/liquid_optics_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _params = LiquidOpticsParams(
  tint: Color(0x38FFFFFF),
  rim: Color(0x80FFFFFF),
  refraction: 1,
  dispersion: 0.3,
  blurSigma: 3,
);

List<double> _uniforms(
  Rect rect, {
  BorderRadius radii = BorderRadius.zero,
  LiquidOpticsParams params = _params,
  double scale = 3,
  Size pass = const Size(1179, 2556),
}) => liquidUniforms(
  rect: rect,
  radii: radii,
  params: params,
  scale: scale,
  pass: pass,
).toList();

Matcher _floats(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (a, b) => (a - b).abs() < 1e-4,
  'within 1e-4 of',
);

void main() {
  group('liquidDisplacement (spec §4.1 steps 4-7)', () {
    test('zero at the edge and once the bezel is flat', () {
      expect(liquidDisplacement(0), 0);
      expect(liquidDisplacement(1), 0);
      expect(liquidDisplacement(1.5), 0);
    });

    test('inward (negative), peaking about 9 near the edge', () {
      expect(liquidDisplacement(0.037), closeTo(-8.987, 0.01));
      expect(liquidDisplacement(0.05), closeTo(-8.894, 0.01));
      expect(liquidDisplacement(0.1), closeTo(-7.830, 0.01));
      expect(liquidDisplacement(0.3), closeTo(-3.398, 0.01));
      expect(liquidDisplacement(0.5), closeTo(-1.157, 0.01));
    });

    test('scales with thickness and vanishes without it', () {
      expect(liquidDisplacement(0.1, thickness: 36), closeTo(-21.250, 0.01));
      expect(liquidDisplacement(0.1, thickness: 0), 0);
    });

    test('dispersion: a higher index bends more', () {
      expect(liquidDisplacement(0.1, index: 1.47), closeTo(-7.539, 0.01));
      expect(liquidDisplacement(0.1, index: 1.53), closeTo(-8.111, 0.01));
    });
  });

  group('liquidUniforms (spec §4.2)', () {
    test('a pill in the middle of the screen, at 3x', () {
      // 320x64 pt at (40, 700) pt; radius 999 clamps to half the height.
      const rect = Rect.fromLTWH(120, 2100, 960, 192);
      expect(
        _uniforms(rect, radii: BorderRadius.circular(999)),
        _floats([
          120, 2100, 960, 192, // rect
          96, 96, 96, 96, // radii: min(999*3, 192/2)
          36, 54, 1.5, 0.3, // bezel 12*3, thickness 18*3, index, dispersion
          1, 1, 1, 0x38 / 255, // tint
          1, 1, 1, 0x80 / 255, // rim
          -0.5, -0.85, 4.5, 1.1, // light, rim width 1.5*3, saturation
        ]),
      );
    });

    test('per-corner radii keep their order tl, tr, br, bl', () {
      const rect = Rect.fromLTWH(300, 300, 600, 300);
      final u = _uniforms(
        rect,
        radii: const BorderRadius.only(
          topLeft: Radius.circular(1),
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(3),
          bottomLeft: Radius.circular(4),
        ),
      );
      expect(u.sublist(4, 8), _floats([3, 6, 9, 12]));
    });

    test('the bezel never exceeds half the short side', () {
      final u = _uniforms(const Rect.fromLTWH(300, 300, 600, 40));
      expect(u[8], 20);
    });

    test('refraction and dispersion feed thickness and spread', () {
      final flat = _uniforms(
        const Rect.fromLTWH(300, 300, 600, 300),
        params: const LiquidOpticsParams(
          tint: Color(0x00000000),
          rim: Color(0x00000000),
          refraction: 0,
          dispersion: 2, // clamps to 1
          blurSigma: 0,
        ),
      );
      expect(flat[9], 0);
      expect(flat[11], 1);
    });

    test('screen-edge rule: a sidebar flush left, top and bottom', () {
      // 320 pt sidebar on an 834x1194 pt iPad at 2x.
      const pass = Size(1668, 2388);
      const rect = Rect.fromLTWH(0, 0, 640, 2388);
      final u = _uniforms(rect, scale: 2, pass: pass);
      // reach = bezel 24 + max radius 0 + 2 = 26 on the left, top, bottom.
      expect(u.sublist(0, 4), _floats([-26, -26, 666, 2440]));
    });

    test('screen-edge rule in RTL: flush right, top and bottom', () {
      const pass = Size(1668, 2388);
      const rect = Rect.fromLTWH(1028, 0, 640, 2388);
      final u = _uniforms(rect, scale: 2, pass: pass);
      expect(u.sublist(0, 4), _floats([1028, -26, 666, 2440]));
    });

    test('scale 1 keeps logical numbers', () {
      final u = _uniforms(
        const Rect.fromLTWH(10, 10, 100, 50),
        scale: 1,
        pass: const Size(400, 800),
      );
      expect(u.sublist(8, 10), _floats([12, 18]));
      // List index k is shader float k + 2: index 22 is the rim width.
      expect(u[22], 1.5);
    });

    test('returns LiquidOptics.floatCount floats', () {
      expect(
        _uniforms(const Rect.fromLTWH(300, 300, 600, 300)),
        hasLength(LiquidOptics.floatCount),
      );
    });
  });

  test('LiquidOpticsParams equality', () {
    expect(_params, _params.copyWithForTest());
    expect(_params.hashCode, _params.copyWithForTest().hashCode);
    expect(
      _params,
      isNot(
        const LiquidOpticsParams(
          tint: Color(0x38FFFFFF),
          rim: Color(0x80FFFFFF),
          refraction: 1,
          dispersion: 0.31,
          blurSigma: 3,
        ),
      ),
    );
  });
}

extension on LiquidOpticsParams {
  LiquidOpticsParams copyWithForTest() => LiquidOpticsParams(
    tint: tint,
    rim: rim,
    refraction: refraction,
    dispersion: dispersion,
    blurSigma: blurSigma,
  );
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/liquid_optics_test.dart`
Expected: FAIL. It does not compile, with "Target of URI doesn't exist: 'package:liquid_shell/src/glass/liquid_optics.dart'".

- [ ] **Step 3: Implement `liquid_optics.dart`**

`liquid_shell/lib/src/glass/liquid_optics.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Internal optics of the liquid tier (spec §4, §5.6). Lengths are logical
/// pixels; [liquidUniforms] scales them to pass pixels.
abstract final class LiquidOptics {
  /// Width of the curved band inside the edge.
  static const double bezel = 12;

  /// Glass thickness at `refraction` 1.
  static const double thickness = 18;

  /// Refractive index (crown glass).
  static const double index = 1.5;

  /// Width of the specular rim.
  static const double rimWidth = 1.5;

  /// Vibrancy: 1 keeps the colours, above 1 saturates.
  static const double saturation = 1.1;

  /// Direction toward the light, y down (top-left).
  static const Offset light = Offset(-0.5, -0.85);

  /// Shader float index of the first value [liquidUniforms] returns
  /// (0 and 1 are the engine's size uniform).
  static const int firstIndex = 2;

  /// Number of floats [liquidUniforms] returns.
  static const int floatCount = 24;
}

/// What the shader needs besides the geometry, from `LiquidGlassTheme`.
@immutable
class LiquidOpticsParams {
  /// Creates a parameter set.
  const LiquidOpticsParams({
    required this.tint,
    required this.rim,
    required this.refraction,
    required this.dispersion,
    required this.blurSigma,
  });

  /// Tint mixed over the refracted backdrop (alpha = amount).
  final Color tint;

  /// Specular rim colour (alpha = strength).
  final Color rim;

  /// Thickness multiplier; 0 is flat glass.
  final double refraction;

  /// Colour fringe in the bezel, 0–1.
  final double dispersion;

  /// Logical sigma of the blur chained before the shader.
  final double blurSigma;

  @override
  bool operator ==(Object other) =>
      other is LiquidOpticsParams &&
      other.tint == tint &&
      other.rim == rim &&
      other.refraction == refraction &&
      other.dispersion == dispersion &&
      other.blurSigma == blurSigma;

  @override
  int get hashCode => Object.hash(tint, rim, refraction, dispersion, blurSigma);
}

/// The floats for shader indices 2–25 (spec §4.2), in pass pixels.
///
/// [rect] is the glass in pass pixels and [radii] its drawn corners in
/// logical pixels. [scale] is pass pixels per logical pixel, and [pass] the
/// pass size in pixels. A side within half a pixel of the pass edge is
/// pushed out of the pass so it gets no bezel and no rim (screen-edge rule).
Float32List liquidUniforms({
  required Rect rect,
  required BorderRadius radii,
  required LiquidOpticsParams params,
  required double scale,
  required Size pass,
}) {
  final half = math.min(rect.width, rect.height) / 2;
  double corner(Radius r) => math.min(r.x * scale, half);
  final tl = corner(radii.topLeft);
  final tr = corner(radii.topRight);
  final br = corner(radii.bottomRight);
  final bl = corner(radii.bottomLeft);
  final bezel = (LiquidOptics.bezel * scale)
      .clamp(1.0, math.max(1.0, half))
      .toDouble();

  final reach = bezel + math.max(math.max(tl, tr), math.max(br, bl)) + 2;
  const edge = 0.5;
  final left = rect.left <= edge ? rect.left - reach : rect.left;
  final top = rect.top <= edge ? rect.top - reach : rect.top;
  final right = rect.right >= pass.width - edge
      ? rect.right + reach
      : rect.right;
  final bottom = rect.bottom >= pass.height - edge
      ? rect.bottom + reach
      : rect.bottom;

  return Float32List.fromList([
    left,
    top,
    right - left,
    bottom - top,
    tl,
    tr,
    br,
    bl,
    bezel,
    LiquidOptics.thickness * params.refraction * scale,
    LiquidOptics.index,
    params.dispersion.clamp(0.0, 1.0),
    params.tint.r,
    params.tint.g,
    params.tint.b,
    params.tint.a,
    params.rim.r,
    params.rim.g,
    params.rim.b,
    params.rim.a,
    LiquidOptics.light.dx,
    LiquidOptics.light.dy,
    LiquidOptics.rimWidth * scale,
    LiquidOptics.saturation,
  ]);
}

/// Signed inward displacement at bezel coordinate [x] (0 at the edge, 1
/// where the bezel flattens), in the unit of [bezel] and [thickness].
///
/// The Dart mirror of the shader's `displacement` along the normal (spec
/// §4.1 steps 4–7), for tests and docs. Negative means inward.
double liquidDisplacement(
  double x, {
  double bezel = LiquidOptics.bezel,
  double thickness = LiquidOptics.thickness,
  double index = LiquidOptics.index,
}) {
  if (x >= 1 || thickness <= 0) return 0;
  double height(double x) {
    final u = 1 - x;
    return math.pow(math.max(1 - u * u * u * u, 0), 0.25).toDouble();
  }

  final xc = math.max(x, 0.02);
  final u = 1 - xc;
  final inner = math.max(1 - u * u * u * u, 1e-4);
  final bezelSlope = u * u * u * math.pow(inner, -0.75);
  final s = math.min<double>(thickness / bezel * bezelSlope, 8);
  final length = math.sqrt(s * s + 1);
  final nx = s / length;
  final nz = 1 / length;
  // refract(I = (0, 0, -1), N, 1 / index), as GLSL defines it.
  final eta = 1 / index;
  final cosI = nz;
  final k = 1 - eta * eta * (1 - cosI * cosI);
  if (k < 0) return 0;
  final coef = eta * cosI - math.sqrt(k);
  final rx = coef * nx;
  final rz = -eta + coef * nz;
  return rx * thickness * height(x) / math.max(-rz, 0.2);
}
```

- [ ] **Step 4: Run the unit test to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/unit/liquid_optics_test.dart`
Expected: PASS, all tests.

- [ ] **Step 5: Write the shader and declare it**

`liquid_shell/shaders/liquid_glass.frag`. This exact source was compiled and rendered under `flutter test --enable-impeller` on 3.44.6 while the spec was written:

```glsl
// liquid_shell: liquid glass lens. Clean-room (spec 2026-10-10 §4).
//
// A slab of glass whose top surface curves down across a bezel band at the
// edge. A straight-down view ray refracts (Snell, index n) and lands on the
// backdrop displaced inward, so content near the edge is magnified. All
// lengths are physical pixels of the render pass; y points down.
#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;    // 0-1: pass size, set by the engine
uniform vec4 uRect;    // 2-5: left, top, width, height
uniform vec4 uRadii;   // 6-9: tl, tr, br, bl
uniform vec4 uOptics;  // 10-13: bezel, thickness, index, dispersion
uniform vec4 uTint;    // 14-17: rgba, straight alpha
uniform vec4 uRim;     // 18-21: rgba
uniform vec4 uLight;   // 22-25: light x, light y, rim width, saturation

uniform sampler2D uBackdrop;

out vec4 fragColor;

// Signed distance to the rounded rect (negative inside) and the outward
// unit normal of the nearest edge.
float roundedBox(vec2 p, out vec2 normal) {
  vec2 half_size = uRect.zw * 0.5;
  vec2 rel = p - (uRect.xy + half_size);
  float r = rel.x < 0.0 ? (rel.y < 0.0 ? uRadii.x : uRadii.w)
                        : (rel.y < 0.0 ? uRadii.y : uRadii.z);
  vec2 q = abs(rel) - half_size + vec2(r);
  vec2 side = vec2(rel.x < 0.0 ? -1.0 : 1.0, rel.y < 0.0 ? -1.0 : 1.0);
  if (q.x > 0.0 && q.y > 0.0) {
    normal = normalize(q) * side;
  } else if (q.x > q.y) {
    normal = vec2(side.x, 0.0);
  } else {
    normal = vec2(0.0, side.y);
  }
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Height of the bezel at x in [0, 1] (0 at the edge) and its slope.
float bezelHeight(float x) {
  float u = 1.0 - x;
  return pow(max(1.0 - u * u * u * u, 0.0), 0.25);
}

float bezelSlope(float x) {
  float xc = max(x, 0.02);
  float u = 1.0 - xc;
  float inner = max(1.0 - u * u * u * u, 1e-4);
  return u * u * u * pow(inner, -0.75);
}

// Inward displacement of the backdrop sample for refractive index n.
vec2 displacement(vec2 n2, float x, float n) {
  float bezel = uOptics.x;
  float thickness = uOptics.y;
  float slope = min(thickness / bezel * bezelSlope(x), 8.0);
  vec3 normal = normalize(vec3(n2 * slope, 1.0));
  vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / n);
  float depth = thickness * bezelHeight(x);
  return ray.xy * depth / max(-ray.z, 0.2);
}

vec3 sampleBackdrop(vec2 p) {
  vec2 uv = clamp(p / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv).rgb;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 n2;
  float d = roundedBox(p, n2);
  float t = max(-d, 0.0);
  float x = clamp(t / uOptics.x, 0.0, 1.0);

  vec3 color;
  if (x < 1.0 && uOptics.y > 0.0) {
    float n = uOptics.z;
    float spread = 0.1 * uOptics.w;
    if (spread > 0.0) {
      color = vec3(
          sampleBackdrop(p + displacement(n2, x, n - spread)).r,
          sampleBackdrop(p + displacement(n2, x, n)).g,
          sampleBackdrop(p + displacement(n2, x, n + spread)).b);
    } else {
      color = sampleBackdrop(p + displacement(n2, x, n));
    }
  } else {
    color = sampleBackdrop(p);
  }

  color = mix(color, uTint.rgb, uTint.a);
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, uLight.w);

  vec2 light = normalize(uLight.xy);
  float facing = dot(n2, light);
  float rim = 1.0 - smoothstep(0.0, uLight.z, t);
  float spec = rim * (max(facing, 0.0) + 0.4 * max(-facing, 0.0));
  float glow = 0.25 * (1.0 - bezelHeight(x));
  color += uRim.rgb * uRim.a * (spec + glow);

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
```

In `liquid_shell/pubspec.yaml`, extend the `flutter:` block (keep `plugin:` as it is):

```yaml
flutter:
  plugin:
    platforms:
      ios:
        default_package: liquid_shell_ios
      android:
        default_package: liquid_shell_android
  # The liquid tier's lens (spec 2026-10-10 §4). Apps load it as
  # packages/liquid_shell/shaders/liquid_glass.frag.
  shaders:
    - shaders/liquid_glass.frag
```

`liquid_shell/dart_test.yaml`:

```yaml
tags:
  golden:
  # Needs `flutter test --enable-impeller` (shader filters). macOS only.
  impeller:
```

- [ ] **Step 6: Write the failing Impeller pixel test**

`liquid_shell/test/impeller/liquid_shader_test.dart`:

```dart
@Tags(['impeller'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _scale = 2.0;
const _view = Size(400, 300);

/// Stripes 8 pt wide, alternating pure red and pure blue, so a sample's
/// source column is readable from its colour.
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 16) {
      canvas
        ..drawRect(
          Rect.fromLTWH(x, 0, 8, size.height),
          Paint()..color = const Color(0xFFFF0000),
        )
        ..drawRect(
          Rect.fromLTWH(x + 8, 0, 8, size.height),
          Paint()..color = const Color(0xFF0000FF),
        );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

Future<ui.FragmentProgram> _program(WidgetTester tester) async =>
    (await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
    ))!;

ui.ImageFilter _lens(
  ui.FragmentProgram program,
  Rect logical, {
  BorderRadius radii = BorderRadius.zero,
  LiquidOpticsParams params = const LiquidOpticsParams(
    tint: Color(0x00000000),
    rim: Color(0x00000000),
    refraction: 1,
    dispersion: 0,
    blurSigma: 0,
  ),
}) {
  final shader = program.fragmentShader();
  final floats = liquidUniforms(
    rect: Rect.fromLTRB(
      logical.left * _scale,
      logical.top * _scale,
      logical.right * _scale,
      logical.bottom * _scale,
    ),
    radii: radii,
    params: params,
    scale: _scale,
    pass: _view * _scale,
  );
  for (var i = 0; i < floats.length; i++) {
    shader.setFloat(LiquidOptics.firstIndex + i, floats[i]);
  }
  return ui.ImageFilter.shader(shader);
}

Future<ByteData> _render(WidgetTester tester, Widget glass) async {
  tester.view
    ..devicePixelRatio = _scale
    ..physicalSize = _view * _scale;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _Stripes())),
          glass,
        ],
      ),
    ),
  );
  // Capture from the root, at the view's pixel ratio (spec §3.2), as
  // matchesGoldenFile does for a widget with no repaint boundary of its own.
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
  return (await tester.runAsync(() => image!.toByteData()))!;
}

/// RGBA of the pixel at logical [p].
List<int> _pixel(ByteData data, Offset p) {
  final x = (p.dx * _scale).round();
  final y = (p.dy * _scale).round();
  final i = (y * (_view.width * _scale).round() + x) * 4;
  return [
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
    data.getUint8(i + 3),
  ];
}

void main() {
  test('runs with Impeller only', () {
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
  });

  testWidgets('the bezel samples from further in (lensing)', (tester) async {
    final program = await _program(tester);
    // Stripes: red on [16k, 16k + 8), blue on [16k + 8, 16k + 16).
    // About 1 pt inside the left edge (bezel x ~ 0.1) the sample comes from
    // about 7.8 pt further in: 101 + 7.8 = 108.8 is blue [104, 112), while
    // the unbent backdrop at 101 is red [96, 104).
    const glass = Rect.fromLTWH(100, 100, 200, 100);
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(program, glass),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final edge = _pixel(data, const Offset(100.75, 150));
    expect(edge[2], greaterThan(edge[0]), reason: 'blue sampled: $edge');
    // The body is not bent: 204 lies in blue [200, 208).
    final centre = _pixel(data, const Offset(204, 150));
    expect(centre[2], greaterThan(200), reason: 'centre is the backdrop');
  });

  testWidgets('the specular rim lights the top more than the bottom', (
    tester,
  ) async {
    final program = await _program(tester);
    const glass = Rect.fromLTWH(100, 100, 200, 100);
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(
              program,
              glass,
              params: const LiquidOpticsParams(
                tint: Color(0x00000000),
                rim: Color(0xFFFFFFFF),
                refraction: 0,
                dispersion: 0,
                blurSigma: 0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    int brightness(List<int> p) => p[0] + p[1] + p[2];
    final top = _pixel(data, const Offset(204, 100.25));
    final bottom = _pixel(data, const Offset(204, 199.5));
    expect(brightness(top), greaterThan(brightness(bottom)));
  });

  testWidgets('a full tint replaces the backdrop in the body', (tester) async {
    final program = await _program(tester);
    const glass = Rect.fromLTWH(100, 100, 200, 100);
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(
              program,
              glass,
              params: const LiquidOpticsParams(
                tint: Color(0xFF00FF00),
                rim: Color(0x00000000),
                refraction: 1,
                dispersion: 0,
                blurSigma: 0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final centre = _pixel(data, const Offset(200, 150));
    expect(centre[1], greaterThan(240));
    expect(centre[0], lessThan(15));
  });

  testWidgets('screen-edge rule: no rim on a side flush with the screen', (
    tester,
  ) async {
    final program = await _program(tester);
    const glass = Rect.fromLTWH(0, 0, 120, 300); // a sidebar
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(
              program,
              glass,
              params: const LiquidOpticsParams(
                tint: Color(0x00000000),
                rim: Color(0xFFFFFFFF),
                refraction: 0,
                dispersion: 0,
                blurSigma: 0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    int brightness(List<int> p) => p[0] + p[1] + p[2];
    // Every probe sits in a red stripe: [0, 8) and [112, 120).
    final body = brightness(_pixel(data, const Offset(114, 150)));
    // Left side, flush with the screen: no rim, same as the body.
    expect(brightness(_pixel(data, const Offset(0.25, 150))), body);
    // Inner (right) side: the rim adds light.
    expect(
      brightness(_pixel(data, const Offset(119.5, 150))),
      greaterThan(body + 100),
    );
  });
}
```

> The two comments in the first test record how the stripe arithmetic was checked. The backdrop stripes are red on [16k, 16k + 8) and blue on [16k + 8, 16k + 16), so x = 196 lies in [192, 200), which is blue. Keep the assertions exactly as written, and when you touch the test, replace the comment with the one-line arithmetic only.

- [ ] **Step 7: Run it with Impeller to verify it passes, and confirm the plain run skips it**

Run:

```bash
cd liquid_shell
fvm flutter test --enable-impeller --tags impeller test/impeller/liquid_shader_test.dart
fvm flutter test --exclude-tags golden,impeller,liquid_golden 2>&1 | tail -1
```

Expected:
- The first command passes all 5 tests. This exact test passed on 3.44.6 while the plan was written; without `--enable-impeller` its 4 render tests fail, which is why it is tagged.
- The second command shows `All tests passed!`, and the impeller file is not among the tests that ran.
- If the lensing test fails, print `edge` and check the sign in `displacement` against spec §4.1 step 6: it must be inward.

- [ ] **Step 8: Wire the Makefile**

In `Makefile`:
1. Add `test-impeller` to `.PHONY`.
2. Change `--exclude-tags golden` in the `test` and `coverage` targets to `--exclude-tags golden,impeller,liquid_golden`.
3. Add:

```make
test-impeller: ## Shader tests under Impeller (macOS + Flutter 3.44.x only)
	@if [ "$$(uname)" != Darwin ]; then echo "▸ test-impeller runs on macOS only"; exit 0; fi
	cd liquid_shell && $(FLUTTER) test --enable-impeller --tags impeller
```

4. Change `verify:` to `verify: format-check analyze provenance pigeon-check test test-impeller coverage goldens snippets`.

Run: `make test-impeller`
Expected: `All tests passed!`

- [ ] **Step 9: Prove the package still publishes with a `shaders/` folder**

Run: `cd liquid_shell && fvm flutter pub publish --dry-run 2>&1 | tail -5`
Expected:
- the archive listing contains `shaders/liquid_glass.frag`;
- the only warnings are the ones `main` already has (the unpublished interface dependency);
- no new warning names `shaders`.

- [ ] **Step 10: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/shaders/liquid_glass.frag liquid_shell/pubspec.yaml \
  liquid_shell/lib/src/glass/liquid_optics.dart \
  liquid_shell/test/unit/liquid_optics_test.dart \
  liquid_shell/test/impeller/liquid_shader_test.dart \
  liquid_shell/dart_test.yaml Makefile
git commit -m "feat(glass): clean-room liquid lens shader and optics maths (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Theme fields and the program loader

**Files:**
- Modify: `liquid_shell/lib/src/glass/glass_theme.dart`
- Create: `liquid_shell/lib/src/glass/shader_program.dart`
- Modify: `liquid_shell/lib/src/glass/liquid_glass.dart` (static `precache`)
- Modify: `liquid_shell/lib/src/glass/liquid_optics.dart` (`LiquidOpticsParams.fromTheme`)
- Modify: `liquid_shell/lib/src/glass/signals_controller.dart` (the reset hook calls the loader reset)
- Test: `liquid_shell/test/unit/glass_theme_test.dart`, `liquid_shell/test/unit/shader_program_test.dart`

**Interfaces:**
- Consumes: `LiquidOpticsParams` (Task 1).
- Produces:
  - `LiquidGlassTheme.liquidTint: Color`, `.refraction: double` (default 1), `.dispersion: double` (default 0.3) and `.liquidBlurSigma: double` (default 6). They are constructor parameters, with `liquidTint` required in the constructor and derived in `fromColorScheme`.
  - `LiquidOpticsParams.fromTheme(LiquidGlassTheme theme)`.
  - `class LiquidShaderProgram extends ValueNotifier<ui.FragmentProgram?>`, with `static final instance`, `static const List<String> assetKeys`, `Future<void> load()` and `@visibleForTesting void debugReset()`.
  - `static Future<void> LiquidGlass.precache()`.

- [ ] **Step 1: Write the failing theme test**

Append to `liquid_shell/test/unit/glass_theme_test.dart`, inside `main()`:

```dart
  group('liquid fields (spec §5.6)', () {
    final light = LiquidGlassTheme.fromColorScheme(
      ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
    );
    final dark = LiquidGlassTheme.fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3366CC),
        brightness: Brightness.dark,
      ),
    );

    test('defaults', () {
      expect(light.liquidTint.a, closeTo(0.5, 1e-3));
      expect(dark.liquidTint.a, closeTo(0.55, 1e-3));
      expect(light.refraction, 1);
      expect(light.dispersion, 0.3);
      expect(light.liquidBlurSigma, 6);
    });

    test('copyWith, lerp and equality cover them', () {
      final changed = light.copyWith(
        liquidTint: const Color(0x11223344),
        refraction: 2,
        dispersion: 0,
        liquidBlurSigma: 0,
      );
      expect(changed.liquidTint, const Color(0x11223344));
      expect(changed.refraction, 2);
      expect(changed.dispersion, 0);
      expect(changed.liquidBlurSigma, 0);
      expect(changed, isNot(light));
      expect(light.copyWith(), light);
      expect(light.copyWith().hashCode, light.hashCode);
      final half = light.lerp(changed, 0.5);
      expect(half.refraction, 1.5);
      expect(half.dispersion, closeTo(0.15, 1e-9));
      expect(half.liquidBlurSigma, 3);
    });

    test('LiquidOpticsParams.fromTheme maps the fields', () {
      expect(
        LiquidOpticsParams.fromTheme(light),
        LiquidOpticsParams(
          tint: light.liquidTint,
          rim: light.rimHighlight,
          refraction: 1,
          dispersion: 0.3,
          blurSigma: 6,
        ),
      );
    });
  });
```

Add `import 'package:liquid_shell/src/glass/liquid_optics.dart';` at the top.

- [ ] **Step 2: Run it to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/glass_theme_test.dart`
Expected: FAIL with "The getter 'liquidTint' isn't defined for the type 'LiquidGlassTheme'".

- [ ] **Step 3: Add the fields**

In `liquid_shell/lib/src/glass/glass_theme.dart`:

1. Constructor: add `required this.liquidTint,` after `required this.labelStyle,`, and add `this.refraction = 1, this.dispersion = 0.3, this.liquidBlurSigma = 6,` after `this.borderRadius = …`.
2. `fromColorScheme`: add `liquidTint: scheme.surface.withValues(alpha: light ? 0.5 : 0.55),` after `solid:`.
3. Add the fields after `labelStyle`:

```dart
  /// Tint inside the liquid lens; lighter than [tint] (spec §5.6).
  final Color liquidTint;

  /// Liquid lens thickness multiplier: 0 is flat glass, 1 the default.
  final double refraction;

  /// Liquid colour fringe in the bezel, 0 (off) to 1. Default 0.3.
  final double dispersion;

  /// Logical sigma of the blur under the liquid lens. 0 turns it off.
  final double liquidBlurSigma;
```

4. Extend `copyWith`: add the four parameters and `liquidTint: liquidTint ?? this.liquidTint,`, `refraction: refraction ?? this.refraction,`, `dispersion: dispersion ?? this.dispersion,`, `liquidBlurSigma: liquidBlurSigma ?? this.liquidBlurSigma,`.
5. Extend `lerp`:

```dart
      liquidTint: Color.lerp(liquidTint, other.liquidTint, t)!,
      refraction: lerpDouble(refraction, other.refraction, t)!,
      dispersion: lerpDouble(dispersion, other.dispersion, t)!,
      liquidBlurSigma: lerpDouble(liquidBlurSigma, other.liquidBlurSigma, t)!,
```

6. Extend `==` with the four comparisons and `hashCode` with the four fields. There are now 13 values, which is still within `Object.hash`'s 20-argument limit.

In `liquid_shell/lib/src/glass/liquid_optics.dart`, add `import 'package:liquid_shell/src/glass/glass_theme.dart';` and, inside `LiquidOpticsParams`:

```dart
  /// The liquid fields of [theme]; the rim uses `rimHighlight`.
  factory LiquidOpticsParams.fromTheme(LiquidGlassTheme theme) =>
      LiquidOpticsParams(
        tint: theme.liquidTint,
        rim: theme.rimHighlight,
        refraction: theme.refraction,
        dispersion: theme.dispersion,
        blurSigma: theme.liquidBlurSigma,
      );
```

Check that nothing else calls the constructor directly. When the plan was written, only `glass_theme.dart` did (the example's custom theme uses `copyWith`):

```bash
grep -rn "LiquidGlassTheme(" liquid_shell | grep -v "lib/src/glass/glass_theme.dart"
```

Expected: no output. If a new caller appears, add `liquidTint:` to it.

- [ ] **Step 4: Run it to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/unit/glass_theme_test.dart && cd example && fvm flutter test --exclude-tags golden test/`
Expected: PASS. The example compiles with the new required field.

- [ ] **Step 5: Write the failing loader test**

`liquid_shell/test/unit/shader_program_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';

void main() {
  tearDown(LiquidShaderProgram.instance.debugReset);

  test('tries the package key first, then the root-package key', () {
    expect(LiquidShaderProgram.assetKeys, [
      'packages/liquid_shell/shaders/liquid_glass.frag',
      'shaders/liquid_glass.frag',
    ]);
  });

  testWidgets('precache loads the program once', (tester) async {
    expect(LiquidShaderProgram.instance.value, isNull);
    await tester.runAsync(LiquidGlass.precache);
    final first = LiquidShaderProgram.instance.value;
    expect(first, isNotNull);
    await tester.runAsync(LiquidGlass.precache);
    expect(LiquidShaderProgram.instance.value, same(first));
  });

  testWidgets('a missing asset leaves it null and logs once', (tester) async {
    final logs = <String>[];
    LiquidShaderProgram.debugAssetKeysOverride = ['shaders/nope.frag'];
    addTearDown(() => LiquidShaderProgram.debugAssetKeysOverride = null);
    // Restored before the test ends: testWidgets checks foundation hooks.
    final saved = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.runAsync(LiquidShaderProgram.instance.load);
      await tester.runAsync(LiquidShaderProgram.instance.load);
    } finally {
      debugPrint = saved;
    }
    expect(LiquidShaderProgram.instance.value, isNull);
    expect(
      logs.where((l) => l.contains('liquid glass shader failed to load')),
      hasLength(1),
    );
  });

  testWidgets('notifies listeners when loaded', (tester) async {
    var notified = 0;
    void listener() => notified++;
    LiquidShaderProgram.instance.addListener(listener);
    addTearDown(() => LiquidShaderProgram.instance.removeListener(listener));
    await tester.runAsync(LiquidShaderProgram.instance.load);
    expect(notified, 1);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/shader_program_test.dart`
Expected: FAIL. It does not compile, with "Target of URI doesn't exist: 'package:liquid_shell/src/glass/shader_program.dart'".

- [ ] **Step 7: Implement the loader and `precache`**

`liquid_shell/lib/src/glass/shader_program.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The liquid lens program, loaded once per process (spec §5.1).
///
/// `null` until loaded, and forever if both asset keys fail; glass then
/// stays frosted. Never throws.
class LiquidShaderProgram extends ValueNotifier<ui.FragmentProgram?> {
  LiquidShaderProgram._() : super(null);

  /// The single instance.
  static final instance = LiquidShaderProgram._();

  /// Asset keys tried in order: an app loads a package's shader under
  /// `packages/<name>/`; this package's own tests only know the bare key.
  static const assetKeys = [
    'packages/liquid_shell/shaders/liquid_glass.frag',
    'shaders/liquid_glass.frag',
  ];

  /// Test hook replacing [assetKeys].
  @visibleForTesting
  static List<String>? debugAssetKeysOverride;

  Future<void>? _loading;
  bool _logged = false;

  /// Loads the program; later calls return the same future.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    Object? failure;
    for (final key in debugAssetKeysOverride ?? assetKeys) {
      try {
        value = await ui.FragmentProgram.fromAsset(key);
        return;
      } on Object catch (error) {
        failure = error;
      }
    }
    if (kDebugMode && !_logged) {
      _logged = true;
      debugPrint(
        'liquid_shell: liquid glass shader failed to load ($failure); '
        'drawing frosted.',
      );
    }
  }

  /// Test hook: forgets the program, so the next test loads it again.
  /// Called by `debugResetLiquidGlassSignals` (not annotated
  /// `@visibleForTesting`, because that function lives in `lib/`).
  void debugReset() {
    _loading = null;
    _logged = false;
    value = null;
  }
}
```

In `liquid_shell/lib/src/glass/liquid_glass.dart`, add the import of `shader_program.dart` and, inside `class LiquidGlass`:

```dart
  /// Loads the liquid lens shader now, so the first frame can already be
  /// liquid. Optional: without it the first frame or two are frosted and
  /// then cross-fade. Safe to call more than once; never throws.
  ///
  /// ```dart
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await LiquidGlass.precache();
  ///   runApp(const MyApp());
  /// }
  /// ```
  static Future<void> precache() => LiquidShaderProgram.instance.load();
```

In `liquid_shell/lib/src/glass/signals_controller.dart`, inside `debugResetLiquidGlassSignals()`, add `LiquidShaderProgram.instance.debugReset();` with its import.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd liquid_shell && fvm flutter test test/unit/shader_program_test.dart test/unit/glass_theme_test.dart`
Expected: PASS. The `precache` test proves that `FragmentProgram.fromAsset('shaders/liquid_glass.frag')` loads in `flutter test` without Impeller (spec §3.2).

- [ ] **Step 9: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/glass_theme.dart liquid_shell/lib/src/glass/liquid_optics.dart \
  liquid_shell/lib/src/glass/shader_program.dart liquid_shell/lib/src/glass/liquid_glass.dart \
  liquid_shell/lib/src/glass/signals_controller.dart \
  liquid_shell/test/unit/glass_theme_test.dart liquid_shell/test/unit/shader_program_test.dart
# plus every file the grep in Step 3 changed, by explicit path
git commit -m "feat(glass): liquid theme fields and shader program loader (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 3: `RenderLiquidBackdrop`, and following ancestors that move

**Files:**
- Create: `liquid_shell/lib/src/glass/liquid_backdrop.dart`
- Create: `liquid_shell/lib/src/glass/drift_guard.dart`
- Test: `liquid_shell/test/widget/liquid_backdrop_test.dart`

**Interfaces:**
- Consumes:
  - `liquidUniforms`, `LiquidOptics.firstIndex` and `LiquidOpticsParams` (Task 1);
  - the program from `LiquidShaderProgram.instance.value` (Task 2).
- Produces:
  - `typedef LiquidFilterFactory = ui.ImageFilter Function(ui.FragmentShader shader, double blurSigma)`;
  - `ui.ImageFilter liquidLensFilter(ui.FragmentShader, double)`;
  - `@visibleForTesting LiquidFilterFactory? debugLiquidFilterFactory`;
  - `class LiquidBackdrop extends StatefulWidget({required ui.FragmentProgram program, required BorderRadius borderRadius, required LiquidOpticsParams params})`;
  - `class RenderLiquidBackdrop extends RenderProxyBox`, with:
    - `passGeometry() → ({Rect rect, double scale, Size pass})`
    - `checkDrift()`
    - `@visibleForTesting debugPaintedRect`
    - `@visibleForTesting debugUniforms`
    - `backdropKey`
  - `class LiquidDriftGuard` with `instance`, `add`, `remove` and `@visibleForTesting debugCount`.

Why this design is the one in spec §5.3:
- The spike showed that the shader's coordinates are the render pass's physical pixels. `ImageFilterConfig` bounds are relative to the layer, so they cannot place the lens.
- Paint-time placement goes stale when only an ancestor *layer* moves.
- The route and scroll listeners fix that in the same frame, and the drift guard fixes every other case one frame later.

Each of the three tests below fails when its mechanism is removed. This was checked by deleting the listeners and the `add` call while the plan was written.

- [ ] **Step 1: Write the failing test**

`liquid_shell/test/widget/liquid_backdrop_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/drift_guard.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _params = LiquidOpticsParams(
  tint: Color(0x38FFFFFF),
  rim: Color(0x80FFFFFF),
  refraction: 1,
  dispersion: 0.3,
  blurSigma: 3,
);

late ui.FragmentProgram _program;
final _built = <double>[];

Future<void> _setUp(WidgetTester tester, {double ratio = 3}) async {
  _program = (await tester.runAsync(
    () => ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
  ))!;
  _built.clear();
  debugLiquidFilterFactory = (shader, sigma) {
    _built.add(sigma);
    return ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  };
  addTearDown(() => debugLiquidFilterFactory = null);
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = const Size(400, 800) * ratio;
  addTearDown(tester.view.reset);
}

Widget _glass({LiquidOpticsParams params = _params}) => SizedBox(
  width: 200,
  height: 60,
  child: LiquidBackdrop(
    program: _program,
    borderRadius: BorderRadius.circular(30),
    params: params,
  ),
);

RenderLiquidBackdrop _render(WidgetTester tester) =>
    tester.renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop));

void _expectInPlace(WidgetTester tester) {
  final render = _render(tester);
  expect(render.debugPaintedRect, render.passGeometry().rect);
}

void main() {
  testWidgets('paints the uniforms of its rect at the view pixel ratio', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(Center(child: _glass()));

    final render = _render(tester);
    // 200x60 centred in 400x800, times 3.
    const rect = Rect.fromLTWH(300, 1110, 600, 180);
    expect(render.debugPaintedRect, rect);
    expect(
      render.debugUniforms,
      liquidUniforms(
        rect: rect,
        radii: BorderRadius.circular(30),
        params: _params,
        scale: 3,
        pass: const Size(1200, 2400),
      ),
    );
    expect(render.layer, isA<BackdropFilterLayer>());
    expect(render.layer!.filter, ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3));
    expect(_built, [3]);
  });

  testWidgets('builds a new filter only when the uniforms change', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(Center(child: _glass()));
    _render(tester).markNeedsPaint();
    await tester.pump();
    expect(_built, hasLength(1));

    await tester.pumpWidget(
      Center(
        child: _glass(
          params: const LiquidOpticsParams(
            tint: Color(0x38FFFFFF),
            rim: Color(0x80FFFFFF),
            refraction: 1,
            dispersion: 0.3,
            blurSigma: 5,
          ),
        ),
      ),
    );
    expect(_built, [3, 5]);
  });

  testWidgets('shares the nearest BackdropGroup', (tester) async {
    await _setUp(tester);
    final group = BackdropGroup(child: Center(child: _glass()));
    await tester.pumpWidget(group);
    expect(_render(tester).layer!.backdropKey, group.backdropKey);
  });

  testWidgets('follows a route transition in the same frame', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(const CupertinoApp(home: SizedBox.expand()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator
        .push(CupertinoPageRoute<void>(builder: (_) => Center(child: _glass())))
        .ignore();
    await tester.pump(); // built offstage first
    await tester.pump(const Duration(milliseconds: 16)); // first painted
    final start = _render(tester).debugPaintedRect!;
    await tester.pump(const Duration(milliseconds: 16)); // moved
    _expectInPlace(tester);
    expect(_render(tester).debugPaintedRect!.left, lessThan(start.left));
  });

  testWidgets('follows scrolling in the same frame', (tester) async {
    await _setUp(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 300),
            Center(child: _glass()),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final before = _render(tester).debugPaintedRect!;
    controller.jumpTo(50);
    await tester.pump();
    _expectInPlace(tester);
    expect(_render(tester).debugPaintedRect!.top, before.top - 150);
  });

  testWidgets('the drift guard corrects a layer-only move one frame later', (
    tester,
  ) async {
    await _setUp(tester);
    final offset = ValueNotifier(Offset.zero);
    addTearDown(offset.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Offset>(
        valueListenable: offset,
        builder: (_, value, child) =>
            Transform.translate(offset: value, child: child),
        child: RepaintBoundary(child: Center(child: _glass())),
      ),
    );
    offset.value = const Offset(0, 40);
    await tester.pump();
    final render = _render(tester);
    // The RepaintBoundary layer moved; the lens did not repaint yet.
    expect(render.debugPaintedRect, isNot(render.passGeometry().rect));
    await tester.pump();
    _expectInPlace(tester);
  });

  testWidgets('registers with the drift guard while attached', (tester) async {
    await _setUp(tester);
    final before = LiquidDriftGuard.instance.debugCount;
    await tester.pumpWidget(Center(child: _glass()));
    expect(LiquidDriftGuard.instance.debugCount, before + 1);
    await tester.pumpWidget(const SizedBox());
    expect(LiquidDriftGuard.instance.debugCount, before);
  });

  testWidgets('scale 1 views keep logical pixels', (tester) async {
    await _setUp(tester, ratio: 1);
    await tester.pumpWidget(Center(child: _glass()));
    expect(
      _render(tester).debugPaintedRect,
      const Rect.fromLTWH(100, 370, 200, 60),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/widget/liquid_backdrop_test.dart`
Expected: FAIL. It does not compile, with "Target of URI doesn't exist: 'package:liquid_shell/src/glass/liquid_backdrop.dart'".

- [ ] **Step 3: Implement the render object and the drift guard**

`liquid_shell/lib/src/glass/liquid_backdrop.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/drift_guard.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

/// Builds the filter of one liquid surface from its [shader], whose
/// uniforms are already set, and the logical blur sigma.
typedef LiquidFilterFactory =
    ui.ImageFilter Function(ui.FragmentShader shader, double blurSigma);

/// The production filter: the engine blur, then the lens (spec §3.3).
ui.ImageFilter liquidLensFilter(ui.FragmentShader shader, double blurSigma) {
  final lens = ui.ImageFilter.shader(shader);
  if (blurSigma <= 0) return lens;
  return ui.ImageFilter.compose(
    outer: lens,
    inner: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
  );
}

/// Test hook replacing [liquidLensFilter]: `ImageFilter.shader` throws
/// without Impeller, so widget tests build a blur instead.
@visibleForTesting
LiquidFilterFactory? debugLiquidFilterFactory;

/// The liquid lens over the backdrop behind this box (spec §5.3).
///
/// Repaints in the same frame when an enclosing route animates or an
/// enclosing scrollable scrolls; any other move that skips its paint is
/// corrected one frame later by [LiquidDriftGuard].
class LiquidBackdrop extends StatefulWidget {
  /// Creates the lens for a box of shape [borderRadius].
  const LiquidBackdrop({
    required this.program,
    required this.borderRadius,
    required this.params,
    super.key,
  });

  /// The loaded lens program.
  final ui.FragmentProgram program;

  /// The drawn shape (clipped by the caller).
  final BorderRadius borderRadius;

  /// Tint, rim and strength, from the theme.
  final LiquidOpticsParams params;

  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop> {
  final List<Listenable> _movers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unlisten();
    final route = ModalRoute.of(context);
    _movers.addAll([
      ?route?.animation,
      ?route?.secondaryAnimation,
      ?Scrollable.maybeOf(context)?.position,
    ]);
    for (final mover in _movers) {
      mover.addListener(_moved);
    }
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  void _unlisten() {
    for (final mover in _movers) {
      mover.removeListener(_moved);
    }
    _movers.clear();
  }

  void _moved() {
    final render = context.findRenderObject();
    if (render is RenderLiquidBackdrop) render.markNeedsPaint();
  }

  @override
  Widget build(BuildContext context) => _LiquidBackdropBox(
    program: widget.program,
    borderRadius: widget.borderRadius,
    params: widget.params,
    backdropKey: BackdropGroup.of(context)?.backdropKey,
    child: const SizedBox.expand(),
  );
}

class _LiquidBackdropBox extends SingleChildRenderObjectWidget {
  const _LiquidBackdropBox({
    required this.program,
    required this.borderRadius,
    required this.params,
    required this.backdropKey,
    super.child,
  });

  final ui.FragmentProgram program;
  final BorderRadius borderRadius;
  final LiquidOpticsParams params;
  final BackdropKey? backdropKey;

  @override
  RenderLiquidBackdrop createRenderObject(BuildContext context) =>
      RenderLiquidBackdrop(
        program: program,
        borderRadius: borderRadius,
        params: params,
        backdropKey: backdropKey,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidBackdrop renderObject,
  ) {
    renderObject
      ..program = program
      ..borderRadius = borderRadius
      ..params = params
      ..backdropKey = backdropKey;
  }
}

/// Pushes a backdrop filter layer whose lens is placed from this box's
/// rect in pass pixels, computed at paint time (spec §5.3).
class RenderLiquidBackdrop extends RenderProxyBox {
  /// Creates the render object.
  RenderLiquidBackdrop({
    required this._program,
    required this._borderRadius,
    required this._params,
    this._backdropKey,
  });

  /// The lens program.
  ui.FragmentProgram get program => _program;
  ui.FragmentProgram _program;
  set program(ui.FragmentProgram value) {
    if (identical(value, _program)) return;
    _program = value;
    _invalidate();
  }

  /// The drawn shape.
  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    _invalidate();
  }

  /// Tint, rim and strength.
  LiquidOpticsParams get params => _params;
  LiquidOpticsParams _params;
  set params(LiquidOpticsParams value) {
    if (value == _params) return;
    _params = value;
    _invalidate();
  }

  /// The shared backdrop of the nearest `BackdropGroup`, if any.
  BackdropKey? get backdropKey => _backdropKey;
  BackdropKey? _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  Float32List? _uniforms;
  ui.ImageFilter? _filter;
  Rect? _paintedRect;

  /// The rect of the last paint in pass pixels; null before it.
  @visibleForTesting
  Rect? get debugPaintedRect => _paintedRect;

  /// The uniforms of the current filter; null before the first paint.
  @visibleForTesting
  Float32List? get debugUniforms => _uniforms;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    LiquidDriftGuard.instance.add(this);
  }

  @override
  void detach() {
    LiquidDriftGuard.instance.remove(this);
    super.detach();
  }

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  void _invalidate() {
    _filter = null;
    markNeedsPaint();
  }

  /// This box in pass pixels, pass pixels per logical pixel, and the pass
  /// size in pixels (spec §5.3, §5.4).
  ({Rect rect, double scale, Size pass}) passGeometry() {
    final box = Offset.zero & size;
    final root = owner?.rootNode;
    if (root is RenderView) {
      final config = root.configuration;
      final transform = config.toMatrix()..multiply(getTransformTo(null));
      return (
        rect: MatrixUtils.transformRect(transform, box),
        scale: config.devicePixelRatio,
        pass: root.size * config.devicePixelRatio,
      );
    }
    assert(false, 'RenderLiquidBackdrop is not under a RenderView');
    return (
      rect: MatrixUtils.transformRect(getTransformTo(null), box),
      scale: 1,
      pass: Size.infinite,
    );
  }

  /// Repaints when this box moved since its last paint (the drift guard).
  void checkDrift() {
    final painted = _paintedRect;
    if (!attached || painted == null) return;
    final now = passGeometry().rect;
    if ((now.left - painted.left).abs() > 0.5 ||
        (now.top - painted.top).abs() > 0.5 ||
        (now.right - painted.right).abs() > 0.5 ||
        (now.bottom - painted.bottom).abs() > 0.5) {
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final geometry = passGeometry();
    final uniforms = liquidUniforms(
      rect: geometry.rect,
      radii: _borderRadius,
      params: _params,
      scale: geometry.scale,
      pass: geometry.pass,
    );
    ui.FragmentShader? retired;
    if (_filter == null || !_sameFloats(uniforms, _uniforms)) {
      // A fresh shader per change: ImageFilter.shader equality compares
      // the shader object, so mutating the current one could leave the
      // layer's filter unchanged (spec §5.3).
      final shader = _program.fragmentShader();
      for (var i = 0; i < uniforms.length; i++) {
        shader.setFloat(LiquidOptics.firstIndex + i, uniforms[i]);
      }
      _filter = (debugLiquidFilterFactory ?? liquidLensFilter)(
        shader,
        _params.blurSigma,
      );
      retired = _shader;
      _shader = shader;
      _uniforms = uniforms;
    }
    _paintedRect = geometry.rect;
    layer ??= BackdropFilterLayer();
    layer!
      ..filter = _filter
      ..blendMode = BlendMode.srcOver
      ..backdropKey = _backdropKey;
    retired?.dispose();
    context.pushLayer(layer!, super.paint, offset);
  }

  static bool _sameFloats(Float32List a, Float32List? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
```

> `required this._program` is a private named initializing formal, which Dart 3.12 allows. `very_good_analysis`'s `prefer_initializing_formals` asks for it, and the public parameter name is still `program:`.

`liquid_shell/lib/src/glass/drift_guard.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';

/// After every frame, asks each attached [RenderLiquidBackdrop] whether it
/// moved without repainting, so a lens under an ancestor that moved only
/// its layer is corrected one frame later (spec §5.3).
///
/// Registers one post-frame callback at a time and only while a backdrop
/// is attached; an idle app runs no frames, so it does no work.
class LiquidDriftGuard {
  LiquidDriftGuard._();

  /// The single instance.
  static final instance = LiquidDriftGuard._();

  final Set<RenderLiquidBackdrop> _backdrops = {};
  bool _scheduled = false;

  /// Number of attached backdrops, for tests.
  @visibleForTesting
  int get debugCount => _backdrops.length;

  /// Starts checking [backdrop] after each frame.
  void add(RenderLiquidBackdrop backdrop) {
    _backdrops.add(backdrop);
    _schedule();
  }

  /// Stops checking [backdrop].
  void remove(RenderLiquidBackdrop backdrop) => _backdrops.remove(backdrop);

  void _schedule() {
    if (_scheduled || _backdrops.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      for (final backdrop in _backdrops.toList()) {
        backdrop.checkDrift();
      }
      _schedule();
    }, debugLabel: 'LiquidDriftGuard');
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/widget/liquid_backdrop_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Prove each mechanism is needed (red for the right reason)**

Temporarily delete the three `?route?.animation, ?route?.secondaryAnimation, ?Scrollable.maybeOf(context)?.position` entries and the `LiquidDriftGuard.instance.add(this);` line, then run the test again.

Expected: 4 failures:
- "follows a route transition in the same frame";
- "follows scrolling in the same frame";
- "the drift guard corrects a layer-only move one frame later";
- "registers with the drift guard while attached".

Restore the lines (`git checkout liquid_shell/lib/src/glass/liquid_backdrop.dart` if you staged nothing) and run the test again. Expected: PASS.

- [ ] **Step 6: Render the real lens through it under Impeller**

Append to `liquid_shell/test/impeller/liquid_shader_test.dart`, inside `main()`, with imports `package:liquid_shell/src/glass/liquid_backdrop.dart` and `package:flutter/widgets.dart` (already covered by `material.dart`):

```dart
  testWidgets('RenderLiquidBackdrop places the real lens while moving', (
    tester,
  ) async {
    final program = await _program(tester);
    final left = ValueNotifier<double>(100);
    addTearDown(left.dispose);
    tester.view
      ..devicePixelRatio = _scale
      ..physicalSize = _view * _scale;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _Stripes())),
            ValueListenableBuilder<double>(
              valueListenable: left,
              builder: (_, x, _) => Positioned(
                left: x,
                top: 100,
                width: 200,
                height: 100,
                child: ClipRect(
                  child: LiquidBackdrop(
                    program: program,
                    borderRadius: BorderRadius.zero,
                    params: const LiquidOpticsParams(
                      tint: Color(0x00000000),
                      rim: Color(0x00000000),
                      refraction: 1,
                      dispersion: 0.3,
                      blurSigma: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      left.value += 3;
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
```

Run: `cd liquid_shell && fvm flutter test --enable-impeller --tags impeller`
Expected: PASS (6 tests). This runs the real `liquidLensFilter` (compose + shader) through the render object with a fresh shader on every move.

- [ ] **Step 7: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/liquid_backdrop.dart liquid_shell/lib/src/glass/drift_guard.dart \
  liquid_shell/test/widget/liquid_backdrop_test.dart liquid_shell/test/impeller/liquid_shader_test.dart
git commit -m "feat(glass): liquid backdrop placed at paint time, follows moving ancestors (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The built-in liquid renderer and the tier policy

**Files:**
- Create: `liquid_shell/lib/src/glass/liquid_renderer.dart`
- Modify:
  - `liquid_shell/lib/src/glass/policy.dart`
  - `liquid_shell/lib/src/glass/signals_controller.dart`
  - `liquid_shell/lib/src/glass/liquid_glass.dart`
  - `liquid_shell/lib/src/glass/tier.dart`
  - `liquid_shell/lib/liquid_shell.dart`
  - `liquid_shell_platform_interface/lib/src/platform_signals.dart`
- Modify (tests):
  - `liquid_shell/test/flutter_test_config.dart`
  - `liquid_shell/example/test/flutter_test_config.dart`
  - `liquid_shell/test/unit/glass_policy_test.dart`
  - `liquid_shell/test/widget/liquid_glass_test.dart`
  - `liquid_shell/test/widget/shell_behaviour_test.dart`
  - `liquid_shell_platform_interface/test/platform_signals_test.dart`

**Interfaces:**
- Consumes: `LiquidBackdrop` and `debugLiquidFilterFactory` (Task 3); `LiquidShaderProgram` (Task 2); `LiquidOpticsParams.fromTheme` (Task 2).
- Produces:
  - `class LiquidShaderRenderer extends LiquidGlassRenderer` (internal, const).
  - `LiquidGlassSignals({reduceTransparency, highContrast, powerSave, blurDisabled, lowEnd, glesOnly, slowFrames})`, with `prefersSolid` and `prefersFrosted`. `canBlur` is removed.
  - `bool liquidGlassCanRefract()` and `@visibleForTesting bool? debugLiquidGlassCanRefractOverride` (exported). These replace `liquidGlassCanBlur` and `debugLiquidGlassCanBlurOverride`.
  - `LiquidPlatformSignals({…, bool lowEnd = false, bool glesOnly = false})`, decoded from the keys `lowEnd` and `glesOnly`.

Every diff below was applied and run, green, while the plan was written: 369 package tests, 33 interface tests, 52 example tests, and all 26 existing `golden` images byte-identical. Apply them with `git apply` from the repo root, or by hand. The context lines are exact.

- [ ] **Step 1: Write the failing tests**

Apply this patch (tests and test configs only):

```diff
diff --git a/liquid_shell/example/test/flutter_test_config.dart b/liquid_shell/example/test/flutter_test_config.dart
index be6443a..671b53a 100644
--- a/liquid_shell/example/test/flutter_test_config.dart
+++ b/liquid_shell/example/test/flutter_test_config.dart
@@ -8,15 +8,11 @@ import 'support/golden_harness.dart';
 
 /// Runs before every test file of the example.
 ///
-/// `flutter test` reports Android without shader filters, so without the
-/// override every golden would show the solid tier. `case_tier_solid` gets
-/// solid through `forcedTier`, not through this flag.
+/// Without `--enable-impeller` there are no shader filters, so the
+/// `golden` images show frosted glass; `liquid_golden` runs with
+/// `--enable-impeller` and shows the liquid tier.
 Future<void> testExecutable(FutureOr<void> Function() testMain) async {
-  setUp(() => debugLiquidGlassCanBlurOverride = true);
-  tearDown(() {
-    debugLiquidGlassCanBlurOverride = null;
-    debugResetLiquidGlassSignals();
-  });
+  tearDown(debugResetLiquidGlassSignals);
   await loadGoldenFonts();
   final local = goldenFileComparator;
   if (local is LocalFileComparator) {
diff --git a/liquid_shell/test/flutter_test_config.dart b/liquid_shell/test/flutter_test_config.dart
index 171ec42..1070e48 100644
--- a/liquid_shell/test/flutter_test_config.dart
+++ b/liquid_shell/test/flutter_test_config.dart
@@ -5,13 +5,12 @@ import 'package:liquid_shell/liquid_shell.dart';
 
 /// Runs before every test file in this package.
 ///
-/// `flutter test` reports Android with no shader filters, so the device
-/// probe would answer "cannot blur" and every glass would be solid. Tests
-/// that exercise the probe set the override back to null themselves.
+/// Without `--enable-impeller` there are no shader filters, so glass is
+/// frosted unless a test opts into the liquid tier with
+/// `debugLiquidGlassCanRefractOverride`; this resets it after each test.
 Future<void> testExecutable(FutureOr<void> Function() testMain) async {
-  setUp(() => debugLiquidGlassCanBlurOverride = true);
   tearDown(() {
-    debugLiquidGlassCanBlurOverride = null;
+    debugLiquidGlassCanRefractOverride = null;
     debugResetLiquidGlassSignals();
     debugResetLiquidNative();
   });
diff --git a/liquid_shell/test/unit/glass_policy_test.dart b/liquid_shell/test/unit/glass_policy_test.dart
index 101af99..fc5c449 100644
--- a/liquid_shell/test/unit/glass_policy_test.dart
+++ b/liquid_shell/test/unit/glass_policy_test.dart
@@ -1,7 +1,10 @@
+import 'dart:ui' show ImageFilter;
+
 import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:liquid_shell/liquid_shell.dart';
 import 'package:liquid_shell/src/glass/frosted_renderer.dart';
+import 'package:liquid_shell/src/glass/liquid_renderer.dart';
 import 'package:liquid_shell/src/glass/policy.dart';
 import 'package:liquid_shell/src/glass/solid_renderer.dart';
 
@@ -67,34 +70,58 @@ Future<List<String>> _captureLogs(Future<void> Function() body) async {
 }
 
 void main() {
-  group('LiquidGlassSignals.prefersSolid', () {
-    test('is false with every signal off', () {
+  group('LiquidGlassSignals (spec 2026-10-10 §6.1)', () {
+    test('every signal off prefers neither solid nor frosted', () {
       expect(const LiquidGlassSignals().prefersSolid, isFalse);
+      expect(const LiquidGlassSignals().prefersFrosted, isFalse);
     });
 
-    test('is true for each signal alone', () {
-      expect(
-        const LiquidGlassSignals(reduceTransparency: true).prefersSolid,
-        isTrue,
-      );
-      expect(const LiquidGlassSignals(highContrast: true).prefersSolid, isTrue);
-      expect(const LiquidGlassSignals(powerSave: true).prefersSolid, isTrue);
-      expect(const LiquidGlassSignals(blurDisabled: true).prefersSolid, isTrue);
-      expect(const LiquidGlassSignals(canBlur: false).prefersSolid, isTrue);
+    test('solid: reduce transparency, high contrast, blur disabled', () {
+      for (final signals in const [
+        LiquidGlassSignals(reduceTransparency: true),
+        LiquidGlassSignals(highContrast: true),
+        LiquidGlassSignals(blurDisabled: true),
+      ]) {
+        expect(signals.prefersSolid, isTrue);
+      }
+    });
+
+    test('frosted: power save, low end, GLES only, slow frames', () {
+      for (final signals in const [
+        LiquidGlassSignals(powerSave: true),
+        LiquidGlassSignals(lowEnd: true),
+        LiquidGlassSignals(glesOnly: true),
+        LiquidGlassSignals(slowFrames: true),
+      ]) {
+        expect(signals.prefersFrosted, isTrue);
+        expect(signals.prefersSolid, isFalse);
+      }
+    });
+
+    test('battery saver disables blur too: frosted, not solid (Q9)', () {
+      const signals = LiquidGlassSignals(powerSave: true, blurDisabled: true);
+      expect(signals.prefersSolid, isFalse);
+      expect(signals.prefersFrosted, isTrue);
     });
 
     test('== and hashCode compare every field', () {
+      const each = [
+        LiquidGlassSignals(reduceTransparency: true),
+        LiquidGlassSignals(highContrast: true),
+        LiquidGlassSignals(powerSave: true),
+        LiquidGlassSignals(blurDisabled: true),
+        LiquidGlassSignals(lowEnd: true),
+        LiquidGlassSignals(glesOnly: true),
+        LiquidGlassSignals(slowFrames: true),
+      ];
+      for (var a = 0; a < each.length; a++) {
+        for (var b = 0; b < each.length; b++) {
+          expect(each[a] == each[b], a == b, reason: '$a vs $b');
+        }
+      }
       expect(
-        const LiquidGlassSignals(powerSave: true),
-        const LiquidGlassSignals(powerSave: true),
-      );
-      expect(
-        const LiquidGlassSignals(powerSave: true).hashCode,
-        const LiquidGlassSignals(powerSave: true).hashCode,
-      );
-      expect(
-        const LiquidGlassSignals(powerSave: true),
-        isNot(const LiquidGlassSignals(canBlur: false)),
+        const LiquidGlassSignals(lowEnd: true).hashCode,
+        const LiquidGlassSignals(lowEnd: true).hashCode,
       );
     });
   });
@@ -108,22 +135,51 @@ void main() {
       );
     });
 
-    testWidgets('each signal alone → solid', (tester) async {
+    testWidgets('each signal → its tier (spec §6.3)', (tester) async {
       final context = await _context(tester);
       const policy = LiquidGlassPolicy(
         renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
       );
-      for (final signals in const [
-        LiquidGlassSignals(reduceTransparency: true),
-        LiquidGlassSignals(highContrast: true),
-        LiquidGlassSignals(powerSave: true),
-        LiquidGlassSignals(blurDisabled: true),
-        LiquidGlassSignals(canBlur: false),
+      for (final (signals, tier) in const [
+        (LiquidGlassSignals(), LiquidGlassTier.liquid),
+        (LiquidGlassSignals(reduceTransparency: true), LiquidGlassTier.solid),
+        (LiquidGlassSignals(highContrast: true), LiquidGlassTier.solid),
+        (LiquidGlassSignals(blurDisabled: true), LiquidGlassTier.solid),
+        (LiquidGlassSignals(powerSave: true), LiquidGlassTier.frosted),
+        (
+          LiquidGlassSignals(powerSave: true, blurDisabled: true),
+          LiquidGlassTier.frosted,
+        ),
+        (LiquidGlassSignals(lowEnd: true), LiquidGlassTier.frosted),
+        (LiquidGlassSignals(glesOnly: true), LiquidGlassTier.frosted),
+        (LiquidGlassSignals(slowFrames: true), LiquidGlassTier.frosted),
       ]) {
-        expect(policy.resolve(context, signals), LiquidGlassTier.solid);
+        expect(policy.resolve(context, signals), tier);
       }
     });
 
+    testWidgets('a forced liquid tier wins over the frosted signals', (
+      tester,
+    ) async {
+      final context = await _context(tester);
+      const policy = LiquidGlassPolicy(
+        forcedTier: LiquidGlassTier.liquid,
+        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
+      );
+      expect(
+        policy.resolve(
+          context,
+          const LiquidGlassSignals(
+            powerSave: true,
+            lowEnd: true,
+            glesOnly: true,
+            slowFrames: true,
+          ),
+        ),
+        LiquidGlassTier.liquid,
+      );
+    });
+
     testWidgets('a supported liquid renderer → liquid', (tester) async {
       final context = await _context(tester);
       const policy = LiquidGlassPolicy(
@@ -282,7 +338,7 @@ void main() {
         resolveGlassRenderer(
           const LiquidGlassPolicy(),
           context,
-          const LiquidGlassSignals(powerSave: true),
+          const LiquidGlassSignals(reduceTransparency: true),
         ),
         isA<SolidGlassRenderer>(),
       );
@@ -290,7 +346,7 @@ void main() {
         resolveGlassRenderer(
           const LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid),
           context,
-          const LiquidGlassSignals(powerSave: true),
+          const LiquidGlassSignals(reduceTransparency: true),
         ),
         isA<FrostedGlassRenderer>(),
       );
@@ -335,6 +391,90 @@ void main() {
     });
   });
 
+  group('the built-in liquid renderer (spec §5.2, §6.2)', () {
+    testWidgets('without shader filters liquid falls back to frosted', (
+      tester,
+    ) async {
+      debugLiquidGlassCanRefractOverride = false;
+      await tester.runAsync(LiquidGlass.precache);
+      final context = await _context(tester);
+      expect(
+        const LiquidGlassPolicy().rendererFor(context, LiquidGlassTier.liquid),
+        isA<FrostedGlassRenderer>(),
+      );
+    });
+
+    testWidgets('before the program loads liquid falls back to frosted', (
+      tester,
+    ) async {
+      debugLiquidGlassCanRefractOverride = true;
+      final context = await _context(tester);
+      expect(
+        const LiquidGlassPolicy().resolve(context, const LiquidGlassSignals()),
+        LiquidGlassTier.frosted,
+      );
+    });
+
+    testWidgets('with shader filters and the program it is the default', (
+      tester,
+    ) async {
+      debugLiquidGlassCanRefractOverride = true;
+      await tester.runAsync(LiquidGlass.precache);
+      final context = await _context(tester);
+      const policy = LiquidGlassPolicy();
+      expect(
+        policy.rendererFor(context, LiquidGlassTier.liquid),
+        isA<LiquidShaderRenderer>(),
+      );
+      expect(
+        policy.resolve(context, const LiquidGlassSignals()),
+        LiquidGlassTier.liquid,
+      );
+    });
+
+    testWidgets('a registered liquid renderer wins over the built-in one', (
+      tester,
+    ) async {
+      debugLiquidGlassCanRefractOverride = true;
+      await tester.runAsync(LiquidGlass.precache);
+      final context = await _context(tester);
+      const mine = _FakeRenderer(LiquidGlassTier.liquid);
+      expect(
+        identical(
+          const LiquidGlassPolicy(
+            renderers: [mine],
+          ).rendererFor(context, LiquidGlassTier.liquid),
+          mine,
+        ),
+        isTrue,
+      );
+    });
+
+    testWidgets('inside another BackdropFilter it is unsupported (Q10)', (
+      tester,
+    ) async {
+      debugLiquidGlassCanRefractOverride = true;
+      await tester.runAsync(LiquidGlass.precache);
+      late BuildContext inner;
+      await tester.pumpWidget(
+        BackdropFilter(
+          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
+          child: Builder(
+            builder: (context) {
+              inner = context;
+              return const SizedBox();
+            },
+          ),
+        ),
+      );
+      expect(const LiquidShaderRenderer().isSupported(inner), isFalse);
+      expect(
+        const LiquidGlassPolicy().rendererFor(inner, LiquidGlassTier.liquid),
+        isA<FrostedGlassRenderer>(),
+      );
+    });
+  });
+
   test('== compares the type, forcedTier and renderers', () {
     expect(
       const LiquidGlassPolicy(),
diff --git a/liquid_shell/test/widget/liquid_glass_test.dart b/liquid_shell/test/widget/liquid_glass_test.dart
index 15f1abf..055703a 100644
--- a/liquid_shell/test/widget/liquid_glass_test.dart
+++ b/liquid_shell/test/widget/liquid_glass_test.dart
@@ -1,7 +1,10 @@
+import 'dart:ui' show ImageFilter;
+
 import 'package:flutter/foundation.dart';
 import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:liquid_shell/liquid_shell.dart';
+import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
 
 import '../helpers/fake_signals_platform.dart';
 
@@ -90,6 +93,21 @@ class _AlwaysSolidPolicy extends LiquidGlassPolicy {
       LiquidGlassTier.solid;
 }
 
+/// Builds blurs instead of shader filters: `ImageFilter.shader` throws
+/// without Impeller.
+void _installBlurFactory() {
+  debugLiquidFilterFactory = (shader, sigma) =>
+      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
+  addTearDown(() => debugLiquidFilterFactory = null);
+}
+
+/// Shader filters on, the program loaded, blur in place of the shader.
+Future<void> _enableLiquid(WidgetTester tester) async {
+  debugLiquidGlassCanRefractOverride = true;
+  _installBlurFactory();
+  await tester.runAsync(LiquidGlass.precache);
+}
+
 void main() {
   final glassTheme = LiquidGlassTheme.fromColorScheme(_scheme);
 
@@ -100,7 +118,7 @@ void main() {
     expect(_fills(tester, glassTheme.tint), hasLength(1));
   });
 
-  testWidgets('each platform signal → solid; back to none → frosted', (
+  testWidgets('reduce transparency or blur disabled → solid; none → back', (
     tester,
   ) async {
     final platform = installFakeSignals();
@@ -109,7 +127,6 @@ void main() {
 
     for (final signals in const [
       LiquidPlatformSignals(reduceTransparency: true),
-      LiquidPlatformSignals(powerSave: true),
       LiquidPlatformSignals(blurDisabled: true),
     ]) {
       platform.emit(signals);
@@ -123,6 +140,32 @@ void main() {
     }
   });
 
+  testWidgets('battery saver, low end and GLES only → frosted, not liquid', (
+    tester,
+  ) async {
+    await _enableLiquid(tester);
+    final platform = installFakeSignals();
+    await tester.pumpWidget(_app());
+    await tester.pumpAndSettle();
+    expect(find.byType(LiquidBackdrop), findsOneWidget);
+
+    for (final signals in const [
+      LiquidPlatformSignals(powerSave: true),
+      LiquidPlatformSignals(powerSave: true, blurDisabled: true),
+      LiquidPlatformSignals(lowEnd: true),
+      LiquidPlatformSignals(glesOnly: true),
+    ]) {
+      platform.emit(signals);
+      await tester.pumpAndSettle();
+      expect(find.byType(LiquidBackdrop), findsNothing, reason: '$signals');
+      expect(_fills(tester, glassTheme.tint), hasLength(1));
+
+      platform.emit(LiquidPlatformSignals.none);
+      await tester.pumpAndSettle();
+      expect(find.byType(LiquidBackdrop), findsOneWidget);
+    }
+  });
+
   testWidgets('high contrast → solid', (tester) async {
     await tester.pumpWidget(
       _app(mediaQuery: const MediaQueryData(highContrast: true)),
@@ -131,26 +174,79 @@ void main() {
     expect(find.byType(BackdropFilter), findsNothing);
   });
 
-  testWidgets('cannot blur → solid', (tester) async {
-    debugLiquidGlassCanBlurOverride = false;
+  testWidgets('no shader filters → frosted, on every platform', (
+    tester,
+  ) async {
+    debugLiquidGlassCanRefractOverride = false;
+    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
+      debugDefaultTargetPlatformOverride = platform;
+      await tester.pumpWidget(_app(child: SizedBox(width: platform.index + 1)));
+      await tester.pumpAndSettle();
+      expect(find.byType(BackdropFilter), findsOneWidget);
+      expect(find.byType(LiquidBackdrop), findsNothing);
+    }
+    debugDefaultTargetPlatformOverride = null;
+  });
+
+  testWidgets('liquid by default with shader filters and the program', (
+    tester,
+  ) async {
+    await _enableLiquid(tester);
     await tester.pumpWidget(_app());
     await tester.pumpAndSettle();
-    expect(find.byType(BackdropFilter), findsNothing);
+    expect(find.byType(LiquidBackdrop), findsOneWidget);
+    expect(_fills(tester, glassTheme.tint), isEmpty);
   });
 
-  testWidgets('the blur probe only demotes Android (Q6)', (tester) async {
-    debugLiquidGlassCanBlurOverride = null;
-    // flutter test has no shader filters, like Android on Skia.
-    debugDefaultTargetPlatformOverride = TargetPlatform.android;
-    await tester.pumpWidget(_app());
+  testWidgets('frosted until the program loads, then liquid; child kept', (
+    tester,
+  ) async {
+    debugLiquidGlassCanRefractOverride = true;
+    _installBlurFactory();
+    _StatefulState.created = 0;
+    // The first frame is built before the load (started on mount) ends.
+    await tester.pumpWidget(_app(child: const _Stateful()));
+    expect(find.byType(LiquidBackdrop), findsNothing);
+
+    await tester.runAsync(LiquidGlass.precache);
     await tester.pumpAndSettle();
-    expect(find.byType(BackdropFilter), findsNothing);
+    expect(find.byType(LiquidBackdrop), findsOneWidget);
+    expect(_StatefulState.created, 1);
+  });
 
-    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
-    await tester.pumpWidget(_app(child: const SizedBox(width: 121)));
+  testWidgets('inside another BackdropFilter → frosted (Q10)', (tester) async {
+    await _enableLiquid(tester);
+    await tester.pumpWidget(
+      MaterialApp(
+        home: BackdropFilter(
+          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
+          child: const Center(
+            child: LiquidGlass(child: SizedBox(width: 120, height: 40)),
+          ),
+        ),
+      ),
+    );
     await tester.pumpAndSettle();
-    expect(find.byType(BackdropFilter), findsOneWidget);
-    debugDefaultTargetPlatformOverride = null;
+    expect(find.byType(LiquidBackdrop), findsNothing);
+  });
+
+  testWidgets('inside another LiquidGlass child it stays liquid', (
+    tester,
+  ) async {
+    await _enableLiquid(tester);
+    await tester.pumpWidget(
+      _app(
+        child: const SizedBox(
+          width: 200,
+          height: 100,
+          child: Center(
+            child: LiquidGlass(child: SizedBox(width: 80, height: 40)),
+          ),
+        ),
+      ),
+    );
+    await tester.pumpAndSettle();
+    expect(find.byType(LiquidBackdrop), findsNWidgets(2));
   });
 
   testWidgets('a forced tier from LiquidGlassScope wins', (tester) async {
@@ -235,7 +331,7 @@ void main() {
     try {
       await tester.pumpWidget(_app());
       await tester.pump();
-      platform.emit(const LiquidPlatformSignals(powerSave: true));
+      platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
       await tester.pumpAndSettle();
       expect(find.byType(BackdropFilter), findsNothing);
 
diff --git a/liquid_shell/test/widget/shell_behaviour_test.dart b/liquid_shell/test/widget/shell_behaviour_test.dart
index 1e1cf00..c704912 100644
--- a/liquid_shell/test/widget/shell_behaviour_test.dart
+++ b/liquid_shell/test/widget/shell_behaviour_test.dart
@@ -601,7 +601,7 @@ void main() {
       expect(find.byType(BackdropFilter), findsNWidgets(2));
       expect(find.byType(BackdropGroup), findsOneWidget);
 
-      platform.emit(const LiquidPlatformSignals(powerSave: true));
+      platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
       await tester.pumpAndSettle();
       expect(find.byType(BackdropFilter), findsNothing);
     });
diff --git a/liquid_shell_platform_interface/test/platform_signals_test.dart b/liquid_shell_platform_interface/test/platform_signals_test.dart
index 29c9222..d890d4b 100644
--- a/liquid_shell_platform_interface/test/platform_signals_test.dart
+++ b/liquid_shell_platform_interface/test/platform_signals_test.dart
@@ -46,6 +46,22 @@ void main() {
     });
   });
 
+  test('reads lowEnd and glesOnly (spec 2026-10-10 §7.3)', () {
+    expect(
+      LiquidPlatformSignals.fromMap(const {'lowEnd': true, 'glesOnly': true}),
+      const LiquidPlatformSignals(lowEnd: true, glesOnly: true),
+    );
+    expect(LiquidPlatformSignals.fromMap(const {'lowEnd': 1}).lowEnd, isFalse);
+    expect(
+      const LiquidPlatformSignals(glesOnly: true),
+      isNot(const LiquidPlatformSignals(lowEnd: true)),
+    );
+    expect(
+      const LiquidPlatformSignals(lowEnd: true).toString(),
+      contains('lowEnd: true'),
+    );
+  });
+
   test('none has every signal off', () {
     expect(LiquidPlatformSignals.none.reduceTransparency, isFalse);
     expect(LiquidPlatformSignals.none.powerSave, isFalse);
```

Save the block as `/tmp/vk348-task4-tests.patch` (or a file in your scratchpad), then run `git apply --check` on it and `git apply` it.

Why each change:
- **`flutter_test_config.dart` (both).** No canBlur override is needed any more. Without `--enable-impeller` there are no shader filters, so glass is frosted, which is exactly what P1's tests and goldens expect.
- **`glass_policy_test.dart`.** The new signal table (spec §6.3), battery saver + blur disabled → frosted, a forced liquid tier that wins over the frosted signals, and the built-in renderer's support rules (Q10).
- **`liquid_glass_test.dart`.**
  - Reduce transparency or blur disabled → solid.
  - Battery saver, low end and GLES-only → frosted.
  - No shader filters → frosted on every platform.
  - Liquid by default.
  - Frosted until the program loads, then liquid, with the child kept.
  - Nested inside a `BackdropFilter` → frosted, but liquid inside another glass's child.
- **`shell_behaviour_test.dart`.** A solid-tier check used battery saver; it now uses reduce transparency.
- **`platform_signals_test.dart`.** `lowEnd` and `glesOnly`.

- [ ] **Step 2: Run them to verify they fail**

Run: `cd liquid_shell && fvm flutter test test/unit/glass_policy_test.dart test/widget/liquid_glass_test.dart`
Expected: FAIL. It does not compile, with errors such as "No named parameter with the name 'lowEnd'", "Undefined name 'debugLiquidGlassCanRefractOverride'" and "Target of URI doesn't exist: 'package:liquid_shell/src/glass/liquid_renderer.dart'".

- [ ] **Step 3: Implement the renderer**

`liquid_shell/lib/src/glass/liquid_renderer.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Built-in liquid tier: the clean-room lens shader over a light blur,
/// then the outside shadow (spec 2026-10-10 §5.2).
class LiquidShaderRenderer extends LiquidGlassRenderer {
  /// Creates the liquid renderer.
  const LiquidShaderRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.liquid;

  /// Shader filters are supported, the program is loaded, and the glass is
  /// not inside another [BackdropFilter]: there the shader's coordinates
  /// start at that filter's region, not the screen (spec §3.2 case I).
  @override
  bool isSupported(BuildContext context) =>
      liquidGlassCanRefract() &&
      LiquidShaderProgram.instance.value != null &&
      context.findAncestorWidgetOfExactType<BackdropFilter>() == null;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) {
    final shadow = OutsideShadow(
      borderRadius: spec.borderRadius,
      shadow: spec.theme.shadow,
    );
    final program = LiquidShaderProgram.instance.value;
    // isSupported guarantees a program; this keeps a stray call harmless.
    if (program == null) return shadow;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: spec.borderRadius,
          child: LiquidBackdrop(
            program: program,
            borderRadius: spec.borderRadius,
            params: LiquidOpticsParams.fromTheme(spec.theme),
          ),
        ),
        // Above the lens, so the lens never samples the shadow.
        shadow,
      ],
    );
  }
}
```

- [ ] **Step 4: Implement the policy, signals and `LiquidGlass` changes**

Apply:

```diff
diff --git a/liquid_shell/lib/liquid_shell.dart b/liquid_shell/lib/liquid_shell.dart
index a510171..270a0d3 100644
--- a/liquid_shell/lib/liquid_shell.dart
+++ b/liquid_shell/lib/liquid_shell.dart
@@ -17,7 +17,7 @@ export 'src/glass/liquid_glass.dart';
 export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
 export 'src/glass/renderer.dart';
 export 'src/glass/signals_controller.dart'
-    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
+    show debugLiquidGlassCanRefractOverride, debugResetLiquidGlassSignals;
 export 'src/glass/tier.dart';
 export 'src/native/native_chrome.dart';
 export 'src/native/native_reset.dart';
diff --git a/liquid_shell/lib/src/glass/liquid_glass.dart b/liquid_shell/lib/src/glass/liquid_glass.dart
index a57147c..54744ac 100644
--- a/liquid_shell/lib/src/glass/liquid_glass.dart
+++ b/liquid_shell/lib/src/glass/liquid_glass.dart
@@ -1,3 +1,5 @@
+import 'dart:async';
+
 import 'package:flutter/widgets.dart';
 import 'package:liquid_shell/src/glass/glass_scope.dart';
 import 'package:liquid_shell/src/glass/glass_theme.dart';
@@ -5,7 +7,6 @@ import 'package:liquid_shell/src/glass/policy.dart';
 import 'package:liquid_shell/src/glass/renderer.dart';
 import 'package:liquid_shell/src/glass/shader_program.dart';
 import 'package:liquid_shell/src/glass/signals_controller.dart';
-import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';
 
 /// A glass surface.
 ///
@@ -43,11 +44,18 @@ class LiquidGlass extends StatefulWidget {
 class _LiquidGlassState extends State<LiquidGlass> {
   static const _fade = Duration(milliseconds: 200);
   final LiquidSignalsController _signals = LiquidSignalsController.instance;
+  late final Listenable _changes = Listenable.merge([
+    _signals,
+    LiquidShaderProgram.instance,
+  ]);
 
   @override
   void initState() {
     super.initState();
     _signals.acquire();
+    if (liquidGlassCanRefract()) {
+      unawaited(LiquidShaderProgram.instance.load());
+    }
   }
 
   @override
@@ -59,10 +67,11 @@ class _LiquidGlassState extends State<LiquidGlass> {
   @override
   Widget build(
     BuildContext context,
-  ) => ValueListenableBuilder<LiquidPlatformSignals>(
-    valueListenable: _signals,
+  ) => ListenableBuilder(
+    listenable: _changes,
     child: widget.child,
-    builder: (context, platform, child) {
+    builder: (context, child) {
+      final platform = _signals.value;
       final policy = LiquidGlassScope.policyOf(context);
       // policy.resolve, then rendererFor, probing each renderer once.
       final renderer = resolveGlassRenderer(
@@ -73,7 +82,8 @@ class _LiquidGlassState extends State<LiquidGlass> {
           highContrast: MediaQuery.highContrastOf(context),
           powerSave: platform.powerSave,
           blurDisabled: platform.blurDisabled,
-          canBlur: liquidGlassCanBlur(),
+          lowEnd: platform.lowEnd,
+          glesOnly: platform.glesOnly,
         ),
       );
       final theme = LiquidGlassTheme.of(context);
diff --git a/liquid_shell/lib/src/glass/policy.dart b/liquid_shell/lib/src/glass/policy.dart
index 408dd11..b154bb3 100644
--- a/liquid_shell/lib/src/glass/policy.dart
+++ b/liquid_shell/lib/src/glass/policy.dart
@@ -1,6 +1,7 @@
 import 'package:flutter/foundation.dart';
 import 'package:flutter/widgets.dart';
 import 'package:liquid_shell/src/glass/frosted_renderer.dart';
+import 'package:liquid_shell/src/glass/liquid_renderer.dart';
 import 'package:liquid_shell/src/glass/renderer.dart';
 import 'package:liquid_shell/src/glass/solid_renderer.dart';
 import 'package:liquid_shell/src/glass/tier.dart';
@@ -9,13 +10,15 @@ import 'package:liquid_shell/src/glass/tier.dart';
 @immutable
 class LiquidGlassSignals {
   /// Creates a set of signals. Defaults describe a device with no
-  /// accessibility or power restriction that can blur.
+  /// accessibility, power or performance restriction.
   const LiquidGlassSignals({
     this.reduceTransparency = false,
     this.highContrast = false,
     this.powerSave = false,
     this.blurDisabled = false,
-    this.canBlur = true,
+    this.lowEnd = false,
+    this.glesOnly = false,
+    this.slowFrames = false,
   });
 
   /// iOS Reduce Transparency; Android animations off or high contrast.
@@ -24,22 +27,29 @@ class LiquidGlassSignals {
   /// `MediaQuery.highContrastOf` (reported by iOS only).
   final bool highContrast;
 
-  /// Android battery saver.
+  /// Android battery saver; iOS Low Power Mode.
   final bool powerSave;
 
-  /// Android 12+: the system disabled window blurs.
+  /// Android 12+: the system disabled window blurs. Battery saver does
+  /// that too, so it counts only while [powerSave] is off.
   final bool blurDisabled;
 
-  /// False on Android without Impeller (no shader filters, API ≤ 28).
-  final bool canBlur;
+  /// Android: a low-RAM device or under 3 GiB of memory.
+  final bool lowEnd;
 
-  /// Whether any signal asks for the solid tier.
+  /// Android 10+ without Vulkan 1.1 (Flutter renders with OpenGL ES).
+  final bool glesOnly;
+
+  /// Frames were too slow while liquid glass was shown (the frame guard).
+  final bool slowFrames;
+
+  /// Whether a signal asks for the solid tier: reduce transparency, high
+  /// contrast, or blur disabled for a reason other than battery saver.
   bool get prefersSolid =>
-      reduceTransparency ||
-      highContrast ||
-      powerSave ||
-      blurDisabled ||
-      !canBlur;
+      reduceTransparency || highContrast || (blurDisabled && !powerSave);
+
+  /// Whether a signal asks for frosted instead of liquid.
+  bool get prefersFrosted => powerSave || lowEnd || glesOnly || slowFrames;
 
   @override
   bool operator ==(Object other) =>
@@ -48,7 +58,9 @@ class LiquidGlassSignals {
       other.highContrast == highContrast &&
       other.powerSave == powerSave &&
       other.blurDisabled == blurDisabled &&
-      other.canBlur == canBlur;
+      other.lowEnd == lowEnd &&
+      other.glesOnly == glesOnly &&
+      other.slowFrames == slowFrames;
 
   @override
   int get hashCode => Object.hash(
@@ -56,7 +68,9 @@ class LiquidGlassSignals {
     highContrast,
     powerSave,
     blurDisabled,
-    canBlur,
+    lowEnd,
+    glesOnly,
+    slowFrames,
   );
 }
 
@@ -107,17 +121,18 @@ void _logForcedFallback(LiquidGlassTier forced, LiquidGlassTier used) {
 @immutable
 class LiquidGlassPolicy {
   /// Creates a policy. With no arguments it picks automatically and uses
-  /// the built-in frosted and solid renderers.
+  /// the built-in liquid, frosted and solid renderers.
   const LiquidGlassPolicy({this.forcedTier, this.renderers = const []});
 
   /// App override. Wins over every signal. `null` picks automatically.
   final LiquidGlassTier? forcedTier;
 
-  /// Extra renderers, for example a liquid adapter. For each tier the first
-  /// supported registered renderer wins; the built-in frosted and solid
-  /// renderers fill the rest. Solid is always available.
+  /// Extra renderers. For each tier the first supported registered
+  /// renderer wins; the built-in liquid, frosted and solid renderers fill
+  /// the rest. Solid is always available.
   final List<LiquidGlassRenderer> renderers;
 
+  static const _liquid = LiquidShaderRenderer();
   static const _frosted = FrostedGlassRenderer();
   static const _solid = SolidGlassRenderer();
 
@@ -126,8 +141,9 @@ class LiquidGlassPolicy {
   /// 1. [forcedTier], stepping down liquid → frosted → solid when it has no
   ///    supported renderer (logged once in debug builds).
   /// 2. [LiquidGlassSignals.prefersSolid] → solid.
-  /// 3. Otherwise liquid when a supported liquid renderer is registered,
-  ///    else frosted.
+  /// 3. [LiquidGlassSignals.prefersFrosted] → frosted.
+  /// 4. Otherwise liquid when a liquid renderer is supported (a registered
+  ///    one, else the built-in lens), else frosted.
   ///
   /// Override it to change the rule, for example to force solid on some
   /// devices; every `LiquidGlass` under this policy then draws
@@ -140,6 +156,9 @@ class LiquidGlassPolicy {
       return used;
     }
     if (signals.prefersSolid) return LiquidGlassTier.solid;
+    if (signals.prefersFrosted) {
+      return rendererFor(context, LiquidGlassTier.frosted).tier;
+    }
     return rendererFor(context, LiquidGlassTier.liquid).tier;
   }
 
@@ -148,7 +167,10 @@ class LiquidGlassPolicy {
     final registered = _registered(context, tier);
     if (registered != null) return registered;
     return switch (tier) {
-      LiquidGlassTier.liquid => rendererFor(context, LiquidGlassTier.frosted),
+      LiquidGlassTier.liquid =>
+        _supported(_liquid, context)
+            ? _liquid
+            : rendererFor(context, LiquidGlassTier.frosted),
       LiquidGlassTier.frosted => _frosted,
       LiquidGlassTier.solid => _solid,
     };
diff --git a/liquid_shell/lib/src/glass/signals_controller.dart b/liquid_shell/lib/src/glass/signals_controller.dart
index a31ce57..63a780a 100644
--- a/liquid_shell/lib/src/glass/signals_controller.dart
+++ b/liquid_shell/lib/src/glass/signals_controller.dart
@@ -6,22 +6,21 @@ import 'package:liquid_shell/src/glass/policy.dart';
 import 'package:liquid_shell/src/glass/shader_program.dart';
 import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';
 
-/// Test hook replacing the device blur probe. `null` (the default) probes.
+/// Test hook replacing the shader-filter probe. `null` (the default)
+/// probes.
 ///
-/// `flutter test` reports Android without shader filters, so tests that
-/// want frosted glass set this to `true`.
+/// `flutter test` has no shader filters unless run with
+/// `--enable-impeller`, so glass there is frosted by default; tests of the
+/// liquid tier set this to `true` and inject a filter factory.
 @visibleForTesting
-bool? debugLiquidGlassCanBlurOverride;
+bool? debugLiquidGlassCanRefractOverride;
 
-/// Whether this device can blur behind glass.
-///
-/// False only on Android without Impeller (`isShaderFilterSupported` is
-/// false on Skia, API ≤ 28). Reads `defaultTargetPlatform`, not the theme:
-/// the capability belongs to the device.
-bool liquidGlassCanBlur() =>
-    debugLiquidGlassCanBlurOverride ??
-    !(defaultTargetPlatform == TargetPlatform.android &&
-        !ui.ImageFilter.isShaderFilterSupported);
+/// Whether this device can draw the liquid lens: `ImageFilter.shader` is
+/// supported (Impeller). False on Skia (Android 9 and lower) and the web,
+/// which then draw frosted (spec 2026-10-10 §6).
+bool liquidGlassCanRefract() =>
+    debugLiquidGlassCanRefractOverride ??
+    ui.ImageFilter.isShaderFilterSupported;
 
 /// Process-wide platform signals.
 ///
diff --git a/liquid_shell/lib/src/glass/tier.dart b/liquid_shell/lib/src/glass/tier.dart
index 04a830f..c605fe9 100644
--- a/liquid_shell/lib/src/glass/tier.dart
+++ b/liquid_shell/lib/src/glass/tier.dart
@@ -1,7 +1,7 @@
 /// How a glass surface is drawn, from richest to plainest.
 enum LiquidGlassTier {
-  /// Refracting glass. Needs a registered renderer (none ships in this
-  /// package yet).
+  /// Refracting glass: the built-in lens shader (Impeller), or a
+  /// registered renderer.
   liquid,
 
   /// Blurred backdrop with a tint, border, rim highlight and shadow.
diff --git a/liquid_shell_platform_interface/lib/src/platform_signals.dart b/liquid_shell_platform_interface/lib/src/platform_signals.dart
index 11c7fc0..66ab090 100644
--- a/liquid_shell_platform_interface/lib/src/platform_signals.dart
+++ b/liquid_shell_platform_interface/lib/src/platform_signals.dart
@@ -2,8 +2,8 @@ import 'package:flutter/foundation.dart';
 
 /// Accessibility and power signals read from the operating system.
 ///
-/// Any of them being `true` makes `liquid_shell` draw solid instead of
-/// glass. Every field defaults to `false`; a signal that cannot be read is
+/// `liquid_shell` maps them to a glass tier (its spec 2026-10-10 §6).
+/// Every field defaults to `false`; a signal that cannot be read is
 /// reported as `false`.
 @immutable
 class LiquidPlatformSignals {
@@ -12,6 +12,8 @@ class LiquidPlatformSignals {
     this.reduceTransparency = false,
     this.powerSave = false,
     this.blurDisabled = false,
+    this.lowEnd = false,
+    this.glesOnly = false,
   });
 
   /// Lenient decoding of a channel payload.
@@ -25,6 +27,8 @@ class LiquidPlatformSignals {
       reduceTransparency: read('reduceTransparency'),
       powerSave: read('powerSave'),
       blurDisabled: read('blurDisabled'),
+      lowEnd: read('lowEnd'),
+      glesOnly: read('glesOnly'),
     );
   }
 
@@ -34,24 +38,39 @@ class LiquidPlatformSignals {
   /// iOS Reduce Transparency; on Android, animations off or high contrast.
   final bool reduceTransparency;
 
-  /// Android battery saver.
+  /// Android battery saver; iOS Low Power Mode.
   final bool powerSave;
 
   /// Android 12+: the system disabled window blurs.
   final bool blurDisabled;
 
+  /// Android: a low-RAM device or under 3 GiB of memory.
+  final bool lowEnd;
+
+  /// Android 10+ without Vulkan 1.1: Flutter renders with OpenGL ES.
+  final bool glesOnly;
+
   @override
   bool operator ==(Object other) =>
       other is LiquidPlatformSignals &&
       other.reduceTransparency == reduceTransparency &&
       other.powerSave == powerSave &&
-      other.blurDisabled == blurDisabled;
+      other.blurDisabled == blurDisabled &&
+      other.lowEnd == lowEnd &&
+      other.glesOnly == glesOnly;
 
   @override
-  int get hashCode => Object.hash(reduceTransparency, powerSave, blurDisabled);
+  int get hashCode => Object.hash(
+    reduceTransparency,
+    powerSave,
+    blurDisabled,
+    lowEnd,
+    glesOnly,
+  );
 
   @override
   String toString() =>
       'LiquidPlatformSignals(reduceTransparency: $reduceTransparency, '
-      'powerSave: $powerSave, blurDisabled: $blurDisabled)';
+      'powerSave: $powerSave, blurDisabled: $blurDisabled, '
+      'lowEnd: $lowEnd, glesOnly: $glesOnly)';
 }
```

What it does:
- `policy.dart`:
  - adds `lowEnd`, `glesOnly`, `slowFrames` and `prefersFrosted`;
  - narrows `prefersSolid`;
  - removes `canBlur`;
  - makes `LiquidShaderRenderer` the built-in liquid renderer, after the registered ones;
  - adds step 3 of `resolve` (spec §6.2).
- `signals_controller.dart`: `liquidGlassCanRefract()` is `isShaderFilterSupported` on every platform. Skia and the web now draw frosted, not solid (Q9).
- `liquid_glass.dart`:
  - starts loading the program on mount when shader filters are supported;
  - rebuilds when the program arrives (`Listenable.merge`);
  - passes the new signals.
- `platform_signals.dart`: `lowEnd` and `glesOnly`, decoded leniently.

The patch keeps the `slowFrames` field at its default. Task 6 wires the frame guard into it.

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```bash
cd liquid_shell && fvm flutter test --exclude-tags golden,impeller,liquid_golden
cd example && fvm flutter test --exclude-tags golden,liquid_golden && fvm flutter test --tags golden
cd ../../liquid_shell_platform_interface && fvm flutter test
```

Expected: all pass, and the `golden` run passes **without** `--update-goldens`, so the frosted images are byte-identical.

- [ ] **Step 6: Check under Impeller that liquid is the default**

Run: `cd liquid_shell && fvm flutter test --enable-impeller --tags impeller`
Expected: PASS. Then run `fvm dart analyze --fatal-infos --fatal-warnings liquid_shell liquid_shell_platform_interface` from the repo root. Expected: "No issues found!"

- [ ] **Step 7: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/liquid_renderer.dart liquid_shell/lib/src/glass/policy.dart \
  liquid_shell/lib/src/glass/signals_controller.dart liquid_shell/lib/src/glass/liquid_glass.dart \
  liquid_shell/lib/src/glass/tier.dart liquid_shell/lib/liquid_shell.dart \
  liquid_shell_platform_interface/lib/src/platform_signals.dart \
  liquid_shell/test/flutter_test_config.dart liquid_shell/example/test/flutter_test_config.dart \
  liquid_shell/test/unit/glass_policy_test.dart liquid_shell/test/widget/liquid_glass_test.dart \
  liquid_shell/test/widget/shell_behaviour_test.dart \
  liquid_shell_platform_interface/test/platform_signals_test.dart
git commit -m "feat(glass): liquid is the default tier; frosted and solid rules per L2 (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 5: Native signals (Android RAM and Vulkan, iOS Low Power Mode)

**Files:**
- Modify: `liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt`
- Modify: `liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt`
- Modify (test): `liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift`
- Modify (test): `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`
- Modify: `liquid_shell/example/integration_test/signals_test.dart`, `tool/integration_android.sh`

**Interfaces:**
- Consumes: the payload keys `lowEnd` and `glesOnly` and `LiquidPlatformSignals.lowEnd/glesOnly` (Task 4).
- Produces:
  - Kotlin:
    - `RawSignals(…, isLowRamDevice: Boolean? = null, totalMemBytes: Long? = null, vulkan11: Boolean? = null)`;
    - `SignalReader.LOW_END_BYTES`;
    - `SignalReader.VULKAN_1_1`.
  - Swift: `LiquidShellPlugin.signalsPayload(reduceTransparency:lowPowerMode:) -> [String: Bool]`.

The Kotlin diff was applied and `make android-unit` ran green while the plan was written. `glesOnlyIsApi29PlusWithoutVulkan11` and `lowEndIsTheLowRamFlagOrUnderThreeGiB` both passed.

- [ ] **Step 1: Write the failing Kotlin tests**

From this patch, apply only the `SignalReaderTest.kt` hunks first (`git apply --include='*SignalReaderTest.kt'`):

```diff
diff --git a/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt b/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt
index 4c9bde3..4e09c3c 100644
--- a/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt
+++ b/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt
@@ -1,11 +1,13 @@
 package vn.lasoai.liquid_shell
 
 import android.app.Activity
+import android.app.ActivityManager
 import android.app.UiModeManager
 import android.content.BroadcastReceiver
 import android.content.Context
 import android.content.Intent
 import android.content.IntentFilter
+import android.content.pm.PackageManager
 import android.database.ContentObserver
 import android.os.Build
 import android.os.Handler
@@ -118,6 +120,20 @@ class LiquidShellPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandl
                 null
             },
             apiLevel = api,
+            isLowRamDevice = attempt {
+                ctx?.getSystemService(ActivityManager::class.java)?.isLowRamDevice
+            },
+            totalMemBytes = attempt {
+                ctx?.getSystemService(ActivityManager::class.java)?.let { manager ->
+                    ActivityManager.MemoryInfo().also(manager::getMemoryInfo).totalMem
+                }
+            },
+            vulkan11 = attempt {
+                ctx?.packageManager?.hasSystemFeature(
+                    PackageManager.FEATURE_VULKAN_HARDWARE_VERSION,
+                    SignalReader.VULKAN_1_1,
+                )
+            },
         )
     }
 
diff --git a/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt b/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt
index 516b8cb..584f9ae 100644
--- a/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt
+++ b/liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt
@@ -17,16 +17,37 @@ internal data class RawSignals(
     val crossWindowBlurEnabled: Boolean?,
     /** Build.VERSION.SDK_INT. */
     val apiLevel: Int,
+    /** ActivityManager.isLowRamDevice. */
+    val isLowRamDevice: Boolean? = null,
+    /** ActivityManager.MemoryInfo.totalMem, bytes. */
+    val totalMemBytes: Long? = null,
+    /** FEATURE_VULKAN_HARDWARE_VERSION >= 1.1 (Impeller's Vulkan floor). */
+    val vulkan11: Boolean? = null,
 )
 
-/** Pure mapping from raw system values to the channel payload (spec §6.1). */
+/**
+ * Pure mapping from raw system values to the channel payload (spec P1 §6.1;
+ * `lowEnd` and `glesOnly`: spec 2026-10-10 §7.1).
+ */
 internal object SignalReader {
+    /** Under 3 GiB of memory counts as low end (owner Q5). */
+    const val LOW_END_BYTES = 3L * 1024 * 1024 * 1024
+
+    /** Vulkan 1.1 as PackageManager encodes it: (1 shl 22) or (1 shl 12). */
+    const val VULKAN_1_1 = 0x00401000
+
     fun toPayload(raw: RawSignals): Map<String, Boolean> = mapOf(
         "reduceTransparency" to reduceTransparency(raw),
         "powerSave" to (raw.powerSaveMode == true),
         "blurDisabled" to (raw.apiLevel >= 31 && raw.crossWindowBlurEnabled == false),
+        "lowEnd" to lowEnd(raw),
+        "glesOnly" to (raw.apiLevel >= 29 && raw.vulkan11 == false),
     )
 
+    private fun lowEnd(raw: RawSignals): Boolean =
+        raw.isLowRamDevice == true ||
+            (raw.totalMemBytes != null && raw.totalMemBytes < LOW_END_BYTES)
+
     private fun reduceTransparency(raw: RawSignals): Boolean =
         raw.animatorDurationScale == 0f ||
             (raw.apiLevel >= 34 && (raw.contrast ?: 0f) > 0f) ||
diff --git a/liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt b/liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt
index f8fb7dc..e7530ac 100644
--- a/liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt
+++ b/liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt
@@ -11,6 +11,9 @@ class SignalReaderTest {
         highTextContrast: Int? = 0,
         powerSaveMode: Boolean? = false,
         crossWindowBlurEnabled: Boolean? = true,
+        isLowRamDevice: Boolean? = false,
+        totalMemBytes: Long? = 8L shl 30,
+        vulkan11: Boolean? = true,
     ) = RawSignals(
         animatorDurationScale = animatorDurationScale,
         contrast = contrast,
@@ -18,16 +21,23 @@ class SignalReaderTest {
         powerSaveMode = powerSaveMode,
         crossWindowBlurEnabled = crossWindowBlurEnabled,
         apiLevel = api,
+        isLowRamDevice = isLowRamDevice,
+        totalMemBytes = totalMemBytes,
+        vulkan11 = vulkan11,
     )
 
     private fun payload(
         reduceTransparency: Boolean = false,
         powerSave: Boolean = false,
         blurDisabled: Boolean = false,
+        lowEnd: Boolean = false,
+        glesOnly: Boolean = false,
     ) = mapOf(
         "reduceTransparency" to reduceTransparency,
         "powerSave" to powerSave,
         "blurDisabled" to blurDisabled,
+        "lowEnd" to lowEnd,
+        "glesOnly" to glesOnly,
     )
 
     @Test
@@ -112,4 +122,28 @@ class SignalReaderTest {
         )
         assertEquals(payload(), SignalReader.toPayload(failed))
     }
+
+    @Test
+    fun lowEndIsTheLowRamFlagOrUnderThreeGiB() {
+        assertEquals(payload(lowEnd = true), SignalReader.toPayload(raw(34, isLowRamDevice = true)))
+        assertEquals(
+            payload(lowEnd = true),
+            SignalReader.toPayload(raw(34, totalMemBytes = (29L shl 30) / 10)),
+        )
+        assertEquals(payload(), SignalReader.toPayload(raw(34, totalMemBytes = 3L shl 30)))
+        assertEquals(
+            payload(),
+            SignalReader.toPayload(raw(34, isLowRamDevice = null, totalMemBytes = null)),
+        )
+    }
+
+    @Test
+    fun glesOnlyIsApi29PlusWithoutVulkan11() {
+        assertEquals(payload(glesOnly = true), SignalReader.toPayload(raw(29, vulkan11 = false)))
+        assertEquals(payload(glesOnly = true), SignalReader.toPayload(raw(36, vulkan11 = false)))
+        // API 28 and lower runs Skia: no shader filters at all, not a GLES case.
+        assertEquals(payload(), SignalReader.toPayload(raw(28, vulkan11 = false)))
+        assertEquals(payload(), SignalReader.toPayload(raw(34, vulkan11 = true)))
+        assertEquals(payload(), SignalReader.toPayload(raw(34, vulkan11 = null)))
+    }
 }
```

- [ ] **Step 2: Run them to verify they fail**

Run: `make android-unit`
Expected: FAIL to compile, with "Cannot find a parameter with this name: isLowRamDevice" in `SignalReaderTest.kt`.

- [ ] **Step 3: Implement**

Apply the rest of the patch: `git apply --exclude='*SignalReaderTest.kt'`. `SignalReader` maps the raw facts, and `LiquidShellPlugin.read()` reads them through the existing `attempt { }`. These facts never change while the app runs, so no observer is added.

- [ ] **Step 4: Run them to verify they pass**

Run: `make android-unit`
Expected: `BUILD SUCCESSFUL`, with `SignalReaderTest > glesOnlyIsApi29PlusWithoutVulkan11() PASSED` and `SignalReaderTest > lowEndIsTheLowRamFlagOrUnderThreeGiB() PASSED` in the output.

- [ ] **Step 5: Write the failing XCTest for the iOS payload**

Append to the `RunnerTests` class in `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`:

```swift
  // MARK: Signals payload (spec 2026-10-10 §7.2)

  func testLowPowerModeIsPowerSave() {
    XCTAssertEqual(
      LiquidShellPlugin.signalsPayload(reduceTransparency: false, lowPowerMode: true),
      [
        "reduceTransparency": false, "powerSave": true, "blurDisabled": false,
        "lowEnd": false, "glesOnly": false,
      ])
  }

  func testReduceTransparencyAloneIsReported() {
    XCTAssertEqual(
      LiquidShellPlugin.signalsPayload(reduceTransparency: true, lowPowerMode: false),
      [
        "reduceTransparency": true, "powerSave": false, "blurDisabled": false,
        "lowEnd": false, "glesOnly": false,
      ])
  }
```

Run (create your own simulator first):

```bash
UDID=$(xcrun simctl create "vk348 iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5)
make ios-unit IOS_UNIT_DEVICE=$UDID
```

Expected: FAIL to build, with "type 'LiquidShellPlugin' has no member 'signalsPayload'".

- [ ] **Step 6: Implement Low Power Mode on iOS**

In `LiquidShellPlugin.swift`:

1. Replace the doc comment's first bullet with:

```swift
/// - Streams Reduce Transparency and Low Power Mode over the
///   `vn.lasoai.liquid_shell/signals` event channel (spec P1 §6; Low Power
///   Mode as `powerSave`: spec 2026-10-10 §7.2, owner Q8). Blur-disabled,
///   low-end and GLES-only are always false here (Metal is always present).
```

2. Add `private var powerObserver: NSObjectProtocol?` after `private var observer: NSObjectProtocol?`.
3. In `onListen`, after the reduce-transparency observer is added, add:

```swift
    powerObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name.NSProcessInfoPowerStateDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.send()
    }
```

4. Replace `removeObserver()` and `send()` with:

```swift
  private func removeObserver() {
    for token in [observer, powerObserver] {
      if let token = token {
        NotificationCenter.default.removeObserver(token)
      }
    }
    observer = nil
    powerObserver = nil
  }

  private func send() {
    sink?(
      LiquidShellPlugin.signalsPayload(
        reduceTransparency: UIAccessibility.isReduceTransparencyEnabled,
        lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled))
  }

  /// The signals event (spec P1 §6.2; `powerSave` is Low Power Mode,
  /// spec 2026-10-10 §7.2). Pure, for XCTest.
  static func signalsPayload(reduceTransparency: Bool, lowPowerMode: Bool) -> [String: Bool] {
    [
      "reduceTransparency": reduceTransparency,
      "powerSave": lowPowerMode,
      "blurDisabled": false,
      "lowEnd": false,
      "glesOnly": false,
    ]
  }
```

Run: `make ios-unit IOS_UNIT_DEVICE=$UDID`
Expected: `** TEST SUCCEEDED **`, including the two new tests.

- [ ] **Step 7: Update the signals integration test**

In `liquid_shell/example/integration_test/signals_test.dart`:

1. After `_expectBlurDisabled`, add:

```dart
const _expectLowEnd = String.fromEnvironment('EXPECT_LOW_END');
const _expectGlesOnly = String.fromEnvironment('EXPECT_GLES_ONLY');
```

2. Replace the `_expectSolid` declaration with:

```dart
/// The tier the run's signals ask for (spec 2026-10-10 §6.3), mirroring
/// what the script switched on. An empty expectation counts as off.
LiquidGlassTier _expectedTier() {
  bool on(String value) => value == 'true';
  final reduce = on(_expectReduceTransparency);
  final powerSave = on(_expectPowerSave);
  final blurDisabled = on(_expectBlurDisabled);
  if (reduce || (blurDisabled && !powerSave)) return LiquidGlassTier.solid;
  if (powerSave ||
      on(_expectLowEnd) ||
      on(_expectGlesOnly) ||
      !ui.ImageFilter.isShaderFilterSupported) {
    return LiquidGlassTier.frosted;
  }
  return LiquidGlassTier.liquid;
}

/// Whether the internal liquid backdrop is on screen. It is not exported,
/// so it is matched by type name.
bool _liquidShown() => find
    .byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidBackdrop')
    .evaluate()
    .isNotEmpty;
```

and add `import 'dart:ui' as ui;` at the top.

3. In "watchSignals emits a well-formed value", after the `blurDisabled` check, add:

```dart
    _check(_expectLowEnd, actual: signals.lowEnd, name: 'lowEnd');
    _check(_expectGlesOnly, actual: signals.glesOnly, name: 'glesOnly');
```

4. In "the shell draws the tier the signals ask for", add `await LiquidGlass.precache();` as the first line. Then replace

```dart
    expect(
      find.byType(BackdropFilter),
      _expectSolid ? findsNothing : findsWidgets,
    );
```

with

```dart
    switch (_expectedTier()) {
      case LiquidGlassTier.solid:
        expect(find.byType(BackdropFilter), findsNothing);
        expect(_liquidShown(), isFalse);
      case LiquidGlassTier.frosted:
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(_liquidShown(), isFalse);
      case LiquidGlassTier.liquid:
        expect(_liquidShown(), isTrue);
    }
```

- [ ] **Step 8: Pass the device facts from the Android script**

In `tool/integration_android.sh`, after the `blur_default` block, add:

```bash
# Device facts behind lowEnd and glesOnly (spec 2026-10-10 §7.1), read the
# way the plugin reads them: MemTotal is ActivityManager's totalMem.
mem_kb=$(adb shell cat /proc/meminfo | tr -d '\r' | awk '/^MemTotal:/ {print $2}')
low_ram=$(adb shell getprop ro.config.low_ram | tr -d '\r')
low_end=false
if [ "$low_ram" = true ] || [ "$mem_kb" -lt 3145728 ]; then low_end=true; fi
gles_only=false
if [ "$api" -ge 29 ] &&
  [ "$(adb shell pm has-feature android.hardware.vulkan.version 4198400 | tr -d '\r')" != true ]; then
  gles_only=true
fi
echo "▸ MemTotal ${mem_kb} kB (low end: $low_end), Vulkan 1.1 missing: $gles_only"
```

and change the `run()` body's last line from `--dart-define=RUN_NAME="android_$name" "$@"` to:

```bash
    --dart-define=RUN_NAME="android_$name" \
    --dart-define=EXPECT_LOW_END="$low_end" \
    --dart-define=EXPECT_GLES_ONLY="$gles_only" "$@"
```

The powerSave run's comment already explains why `EXPECT_BLUR_DISABLED` is not passed. `_expectedTier` treats battery saver as frosted whatever the blur flag says.

- [ ] **Step 9: Run the integration on your own emulator**

```bash
"$ANDROID_HOME"/cmdline-tools/latest/bin/avdmanager create avd -n vk348-api36 \
  -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_7 --force
"$ANDROID_HOME"/emulator/emulator -avd vk348-api36 -port 5594 -no-snapshot -no-audio &
adb -s emulator-5594 wait-for-device
until [ "$(adb -s emulator-5594 shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done
ANDROID_SERIAL=emulator-5594 FLUTTER="fvm flutter" tool/integration_android.sh
```

Expected: `✓ Android integration passed`. The default run on the API 36 image expects liquid (Impeller GLES, Vulkan advertised) unless the image reports less than 3 GiB of RAM, in which case it expects frosted. Read the `▸ MemTotal` line and check that the asserted tier matches.

Then run `FLUTTER="fvm flutter" IOS_DEVICES=$UDID tool/integration_ios.sh`. Expected: it passes. The simulator reports `powerSave: false` and draws liquid.

Leave the emulator running for Task 9, or kill it with `adb -s emulator-5594 emu kill`.

- [ ] **Step 10: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt \
  liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt \
  liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift \
  liquid_shell/example/ios/RunnerTests/RunnerTests.swift \
  liquid_shell/example/integration_test/signals_test.dart tool/integration_android.sh
git commit -m "feat(platform): lowEnd and glesOnly on Android, Low Power Mode on iOS (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The frame guard

**Files:**
- Create: `liquid_shell/lib/src/glass/frame_guard.dart`
- Modify: `liquid_shell/lib/src/glass/liquid_backdrop.dart`, `liquid_glass.dart`, `signals_controller.dart`
- Test: `liquid_shell/test/unit/frame_guard_test.dart`

**Interfaces:**
- Consumes: `RenderLiquidBackdrop.attach/detach` (Task 3) and `LiquidGlassSignals.slowFrames` (Task 4).
- Produces:
  - the consts `kLiquidSlowWindows = 3` and `kLiquidWindowFrames = 60`;
  - `Duration p90(List<Duration>)`;
  - `bool liquidFramesTooSlow(List<Duration>, Duration budget)`;
  - `@visibleForTesting bool debugLiquidFrameGuardEnabled`;
  - `class LiquidFrameGuard extends ValueNotifier<bool>`, with `instance`, `budget`, `acquire()`, `release()`, `@visibleForTesting addRasterTimes(Iterable<Duration>)`, `debugUsers`, `debugSubscribed` and `debugReset()`.

This code was applied and run green (9 tests, the full suite at 368) while the plan was written.

- [ ] **Step 1: Write the failing test**

`liquid_shell/test/unit/frame_guard_test.dart`:

```dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frame_guard.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';

const _ms = Duration(milliseconds: 1);
const _budget = Duration(microseconds: 16667);

List<Duration> _window(Duration each) => List.filled(kLiquidWindowFrames, each);

void main() {
  tearDown(() => debugLiquidFrameGuardEnabled = false);

  group('p90', () {
    test('nearest rank', () {
      expect(p90(const []), Duration.zero);
      expect(p90([for (var i = 1; i <= 10; i++) _ms * i]), _ms * 9);
      expect(p90([_ms * 5]), _ms * 5);
      expect(p90([for (var i = 100; i >= 1; i--) _ms * i]), _ms * 90);
    });
  });

  group('liquidFramesTooSlow', () {
    final slow = _budget * 1.3;
    final fast = _budget * 1.2;

    test('needs three slow windows in a row', () {
      expect(liquidFramesTooSlow([slow, slow], _budget), isFalse);
      expect(liquidFramesTooSlow([slow, slow, slow], _budget), isTrue);
      expect(liquidFramesTooSlow([slow, fast, slow], _budget), isFalse);
      expect(liquidFramesTooSlow([fast, slow, slow, slow], _budget), isTrue);
    });

    test('exactly 1.25 × budget is not slow', () {
      final edge = _budget * 1.25;
      expect(liquidFramesTooSlow([edge, edge, edge], _budget), isFalse);
    });

    test('a 120 Hz budget is half as long', () {
      const budget120 = Duration(microseconds: 8333);
      final p = _ms * 12;
      expect(liquidFramesTooSlow([p, p, p], budget120), isTrue);
      expect(liquidFramesTooSlow([p, p, p], _budget), isFalse);
    });
  });

  group('LiquidFrameGuard', () {
    final guard = LiquidFrameGuard.instance;
    tearDown(guard.debugReset);

    test('turns slowFrames on after three slow windows and stays on', () {
      final slow = guard.budget * 2;
      guard.addRasterTimes([..._window(slow), ..._window(slow)]);
      expect(guard.value, isFalse);
      guard.addRasterTimes(_window(slow));
      expect(guard.value, isTrue);
      guard.addRasterTimes(_window(Duration.zero));
      expect(guard.value, isTrue);
    });

    test('a fast window resets the run', () {
      final slow = guard.budget * 2;
      guard.addRasterTimes([
        ..._window(slow),
        ..._window(slow),
        ..._window(Duration.zero),
        ..._window(slow),
        ..._window(slow),
      ]);
      expect(guard.value, isFalse);
    });

    test('subscribes only while a surface is held and enabled', () {
      guard.acquire();
      expect(guard.debugSubscribed, isFalse, reason: 'off in debug');
      guard.release();

      debugLiquidFrameGuardEnabled = true;
      guard.acquire();
      expect(guard.debugSubscribed, isTrue);
      guard.release();
      expect(guard.debugSubscribed, isFalse);
    });

    testWidgets('a liquid backdrop holds the guard while attached', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = true;
      debugLiquidFilterFactory = (shader, sigma) =>
          ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      addTearDown(() => debugLiquidFilterFactory = null);
      await tester.runAsync(LiquidGlass.precache);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(guard.debugUsers, 1);
      await tester.pumpWidget(const SizedBox());
      expect(guard.debugUsers, 0);
    });

    testWidgets('slowFrames demotes LiquidGlass to frosted', (tester) async {
      debugLiquidGlassCanRefractOverride = true;
      debugLiquidFilterFactory = (shader, sigma) =>
          ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
      addTearDown(() => debugLiquidFilterFactory = null);
      await tester.runAsync(LiquidGlass.precache);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: LiquidGlass(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackdrop), findsOneWidget);

      final slow = guard.budget * 2;
      guard.addRasterTimes([
        ..._window(slow),
        ..._window(slow),
        ..._window(slow),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackdrop), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/frame_guard_test.dart`
Expected: FAIL. It does not compile, with "Target of URI doesn't exist: 'package:liquid_shell/src/glass/frame_guard.dart'".

- [ ] **Step 3: Implement the guard**

`liquid_shell/lib/src/glass/frame_guard.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Consecutive slow windows that demote liquid to frosted (spec §7.4).
const kLiquidSlowWindows = 3;

/// Frames per measuring window.
const kLiquidWindowFrames = 60;

/// The nearest-rank 90th percentile of [durations]; zero when empty.
Duration p90(List<Duration> durations) {
  if (durations.isEmpty) return Duration.zero;
  final sorted = [...durations]..sort();
  final rank = (0.9 * sorted.length).ceil() - 1;
  return sorted[rank.clamp(0, sorted.length - 1)];
}

/// Whether the last [kLiquidSlowWindows] window p90s are all above
/// 1.25 × [budget].
bool liquidFramesTooSlow(List<Duration> windowP90s, Duration budget) {
  if (windowP90s.length < kLiquidSlowWindows) return false;
  final limit = budget * 1.25;
  return windowP90s
      .sublist(windowP90s.length - kLiquidSlowWindows)
      .every((p) => p > limit);
}

/// Test hook: runs the guard in debug builds too.
@visibleForTesting
bool debugLiquidFrameGuardEnabled = false;

/// Watches raster times while liquid glass is on screen and turns
/// [value] (`slowFrames`) on for the rest of the process when they stay
/// over budget (spec §7.4). Sticky: frosted is cheaper, so switching
/// back would oscillate.
class LiquidFrameGuard extends ValueNotifier<bool> {
  LiquidFrameGuard._() : super(false);

  /// The single instance.
  static final instance = LiquidFrameGuard._();

  int _users = 0;
  bool _subscribed = false;
  bool _logged = false;
  final List<Duration> _window = [];
  final List<Duration> _p90s = [];

  bool get _enabled =>
      kProfileMode || kReleaseMode || debugLiquidFrameGuardEnabled;

  /// The frame budget of the first display (60 Hz when unknown).
  Duration get budget {
    final views = ui.PlatformDispatcher.instance.views;
    final hz = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    return Duration(microseconds: (1e6 / (hz > 0 ? hz : 60)).round());
  }

  /// One liquid surface is on screen.
  void acquire() {
    _users++;
    _update();
  }

  /// One liquid surface left the screen.
  void release() {
    if (_users > 0) _users--;
    _update();
  }

  void _update() {
    final wanted = _enabled && _users > 0 && !value;
    if (wanted && !_subscribed) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _subscribed = true;
    } else if (!wanted && _subscribed) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _subscribed = false;
      _window.clear();
    }
  }

  void _onTimings(List<ui.FrameTiming> timings) =>
      addRasterTimes([for (final t in timings) t.rasterDuration]);

  /// Feeds raster times; the timings callback calls it, and so may tests.
  @visibleForTesting
  void addRasterTimes(Iterable<Duration> rasters) {
    if (value) return;
    for (final raster in rasters) {
      _window.add(raster);
      if (_window.length < kLiquidWindowFrames) continue;
      _p90s.add(p90(_window));
      _window.clear();
      if (_p90s.length > kLiquidSlowWindows) _p90s.removeAt(0);
      if (liquidFramesTooSlow(_p90s, budget)) {
        if (kDebugMode && !_logged) {
          _logged = true;
          debugPrint(
            'liquid_shell: raster p90 ${_p90s.last.inMicroseconds}µs over '
            'a ${budget.inMicroseconds}µs budget; drawing frosted.',
          );
        }
        value = true;
        _update();
        return;
      }
    }
  }

  /// Number of liquid surfaces on screen, for tests.
  @visibleForTesting
  int get debugUsers => _users;

  /// Whether the timings callback is registered, for tests.
  @visibleForTesting
  bool get debugSubscribed => _subscribed;

  /// Test hook: forgets everything. Called by
  /// `debugResetLiquidGlassSignals` (not annotated `@visibleForTesting`,
  /// because that function lives in `lib/`).
  void debugReset() {
    if (_subscribed) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _subscribed = false;
    _users = 0;
    _logged = false;
    _window.clear();
    _p90s.clear();
    value = false;
  }
}
```

Wire it in (attach and detach hold it, `LiquidGlass` listens to it and passes `slowFrames`, and the test reset forgets it):

```diff
diff --git a/liquid_shell/lib/src/glass/liquid_backdrop.dart b/liquid_shell/lib/src/glass/liquid_backdrop.dart
index 0dd0c15..a1facb7 100644
--- a/liquid_shell/lib/src/glass/liquid_backdrop.dart
+++ b/liquid_shell/lib/src/glass/liquid_backdrop.dart
@@ -4,6 +4,7 @@ import 'package:flutter/foundation.dart';
 import 'package:flutter/rendering.dart';
 import 'package:flutter/widgets.dart';
 import 'package:liquid_shell/src/glass/drift_guard.dart';
+import 'package:liquid_shell/src/glass/frame_guard.dart';
 import 'package:liquid_shell/src/glass/liquid_optics.dart';
 
 /// Builds the filter of one liquid surface from its [shader], whose
@@ -205,11 +206,13 @@ class RenderLiquidBackdrop extends RenderProxyBox {
   void attach(PipelineOwner owner) {
     super.attach(owner);
     LiquidDriftGuard.instance.add(this);
+    LiquidFrameGuard.instance.acquire();
   }
 
   @override
   void detach() {
     LiquidDriftGuard.instance.remove(this);
+    LiquidFrameGuard.instance.release();
     super.detach();
   }
 
diff --git a/liquid_shell/lib/src/glass/liquid_glass.dart b/liquid_shell/lib/src/glass/liquid_glass.dart
index 54744ac..cca07d8 100644
--- a/liquid_shell/lib/src/glass/liquid_glass.dart
+++ b/liquid_shell/lib/src/glass/liquid_glass.dart
@@ -1,6 +1,7 @@
 import 'dart:async';
 
 import 'package:flutter/widgets.dart';
+import 'package:liquid_shell/src/glass/frame_guard.dart';
 import 'package:liquid_shell/src/glass/glass_scope.dart';
 import 'package:liquid_shell/src/glass/glass_theme.dart';
 import 'package:liquid_shell/src/glass/policy.dart';
@@ -47,6 +48,7 @@ class _LiquidGlassState extends State<LiquidGlass> {
   late final Listenable _changes = Listenable.merge([
     _signals,
     LiquidShaderProgram.instance,
+    LiquidFrameGuard.instance,
   ]);
 
   @override
@@ -84,6 +86,7 @@ class _LiquidGlassState extends State<LiquidGlass> {
           blurDisabled: platform.blurDisabled,
           lowEnd: platform.lowEnd,
           glesOnly: platform.glesOnly,
+          slowFrames: LiquidFrameGuard.instance.value,
         ),
       );
       final theme = LiquidGlassTheme.of(context);
diff --git a/liquid_shell/lib/src/glass/signals_controller.dart b/liquid_shell/lib/src/glass/signals_controller.dart
index 63a780a..2fa4894 100644
--- a/liquid_shell/lib/src/glass/signals_controller.dart
+++ b/liquid_shell/lib/src/glass/signals_controller.dart
@@ -2,6 +2,7 @@ import 'dart:async';
 import 'dart:ui' as ui;
 
 import 'package:flutter/foundation.dart';
+import 'package:liquid_shell/src/glass/frame_guard.dart';
 import 'package:liquid_shell/src/glass/policy.dart';
 import 'package:liquid_shell/src/glass/shader_program.dart';
 import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';
@@ -89,4 +90,5 @@ void debugResetLiquidGlassSignals() {
     .._set(LiquidPlatformSignals.none);
   debugResetPolicyLogging();
   LiquidShaderProgram.instance.debugReset();
+  LiquidFrameGuard.instance.debugReset();
 }
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd liquid_shell && fvm flutter test test/unit/frame_guard_test.dart && fvm flutter test --exclude-tags golden,impeller,liquid_golden`
Expected: PASS, all tests.

- [ ] **Step 5: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/glass/frame_guard.dart liquid_shell/lib/src/glass/liquid_backdrop.dart \
  liquid_shell/lib/src/glass/liquid_glass.dart liquid_shell/lib/src/glass/signals_controller.dart \
  liquid_shell/test/unit/frame_guard_test.dart
git commit -m "feat(glass): frame guard demotes liquid to frosted on slow devices (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Every surface through `LiquidGlass`; a forced tier turns native chrome off

**Files:**
- Create: `tool/check_glass_seam.sh`, `tool/test/check_glass_seam_test.dart`
- Modify: `Makefile` (the `provenance` target)
- Modify: `liquid_shell/lib/src/native/native_layout.dart`, `liquid_shell/lib/src/shell/liquid_shell.dart`
- Modify (tests): `liquid_shell/test/unit/native_layout_test.dart`, `liquid_shell/test/widget/native_chrome_test.dart`
- Modify: `liquid_shell/lib/src/glass/policy.dart` (the `forcedTier` dartdoc only)

**Interfaces:**
- Consumes: `LiquidGlassScope.policyOf` (P1).
- Produces:
  - `nativeChromePossible({required mode, required hasChromeBuilder, required describable, required bool glassTierForced})`;
  - `nativeChromeEngaged({…, required bool glassTierForced})`;
  - the gate `tool/check_glass_seam.sh`.

This code was applied and run green (gate test: 4 tests; package suite: 369) while the plan was written. When it was written, `git grep` found no `BackdropFilter` or `ImageFilter.*` outside `lib/src/glass/`. The five surfaces of spec §8 already go through `LiquidGlass`, so the gate starts green and guards P3 and P3a.

- [ ] **Step 1: Write the failing gate test**

`tool/test/check_glass_seam_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory repo;
  final script = File('tool/check_glass_seam.sh').absolute;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('glass_seam_');
    Directory('${repo.path}/tool').createSync();
    Directory(
      '${repo.path}/liquid_shell/lib/src/glass',
    ).createSync(recursive: true);
    Directory('${repo.path}/liquid_shell/lib/src/chrome').createSync();
    script.copySync('${repo.path}/tool/check_glass_seam.sh');
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  int run(String path, String content) {
    File('${repo.path}/$path').writeAsStringSync(content);
    return Process.runSync('bash', [
      'tool/check_glass_seam.sh',
    ], workingDirectory: repo.path).exitCode;
  }

  test('a backdrop filter inside lib/src/glass/ passes', () {
    expect(
      run('liquid_shell/lib/src/glass/x.dart', 'BackdropFilter(filter: f)'),
      0,
    );
  });

  test('a backdrop filter elsewhere in lib fails', () {
    expect(
      run('liquid_shell/lib/src/chrome/x.dart', 'BackdropFilter(filter: f)'),
      1,
    );
  });

  test('ImageFilter.blur, .shader and .compose elsewhere fail', () {
    for (final call in ['blur', 'shader', 'compose']) {
      expect(
        run('liquid_shell/lib/src/chrome/x.dart', 'ImageFilter.$call(a)'),
        1,
        reason: call,
      );
    }
  });

  test('BackdropGroup is allowed', () {
    expect(
      run('liquid_shell/lib/src/chrome/x.dart', 'BackdropGroup(child: c)'),
      0,
    );
  });
}
```

Run: `fvm dart test tool/test/check_glass_seam_test.dart`
Expected: FAIL, with "PathNotFoundException: Cannot copy file … tool/check_glass_seam.sh".

- [ ] **Step 2: Write the gate and wire it**

`tool/check_glass_seam.sh` (then `chmod +x tool/check_glass_seam.sh`):

```bash
#!/usr/bin/env bash
# Glass seam gate (spec 2026-10-10 §8, owner decision L3): every glass
# surface goes through LiquidGlass, so no backdrop filter or image filter
# may appear in liquid_shell/lib outside lib/src/glass/. BackdropGroup
# reads nothing and is allowed. `make provenance` runs this.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern='BackdropFilter|ImageFilter\.(blur|shader|compose)'
if git grep --untracked -n -I -E "$pattern" -- 'liquid_shell/lib' ':!liquid_shell/lib/src/glass/'; then
  echo "✗ glass seam: draw glass through LiquidGlass (spec 2026-10-10 §8)" >&2
  exit 1
fi
echo "✓ glass seam clean"
```

In `Makefile`, change the `provenance` recipe from `tool/check_provenance.sh` to:

```make
provenance: ## Fail on app names or banned dependencies outside docs/, or glass outside LiquidGlass
	tool/check_provenance.sh
	tool/check_glass_seam.sh
```

Run: `fvm dart test tool/test/check_glass_seam_test.dart && make provenance`
Expected: `All tests passed!`, then `✓ provenance clean` and `✓ glass seam clean`.

- [ ] **Step 3: Write the failing native-chrome tests**

Apply the test hunks of this patch (`git apply --include='*_test.dart'`):

```diff
diff --git a/liquid_shell/lib/src/native/native_layout.dart b/liquid_shell/lib/src/native/native_layout.dart
index f8a6b52..b21d5ef 100644
--- a/liquid_shell/lib/src/native/native_layout.dart
+++ b/liquid_shell/lib/src/native/native_layout.dart
@@ -20,19 +20,23 @@ bool nativeChromeEngaged({
   required LiquidNativeShellState? state,
   required bool hasChromeBuilder,
   required bool describable,
+  required bool glassTierForced,
 }) =>
     nativeChromePossible(
       mode: mode,
       hasChromeBuilder: hasChromeBuilder,
       describable: describable,
+      glassTierForced: glassTierForced,
     ) &&
     owner &&
     state != null &&
     state.installed;
 
 /// The conditions of [nativeChromeEngaged] that the shell knows without the
-/// platform: the app allows it, it has no custom Flutter chrome, and it
-/// can be drawn natively. Pure.
+/// platform: the app allows it, it has no custom Flutter chrome, no
+/// `LiquidGlassScope` above it forces a glass tier (an app that forces a
+/// tier asks for Flutter glass; spec 2026-10-10 §9.1), and it can be drawn
+/// natively. Pure.
 ///
 /// While the platform has not answered (pending), only a shell for which
 /// this holds waits with no chrome; every other one draws Flutter chrome
@@ -41,7 +45,12 @@ bool nativeChromePossible({
   required LiquidNativeChrome mode,
   required bool hasChromeBuilder,
   required bool describable,
-}) => mode == LiquidNativeChrome.auto && !hasChromeBuilder && describable;
+  required bool glassTierForced,
+}) =>
+    mode == LiquidNativeChrome.auto &&
+    !hasChromeBuilder &&
+    !glassTierForced &&
+    describable;
 
 /// Whether every destination and the trailing action have an SF Symbol.
 bool nativeDescribable(
diff --git a/liquid_shell/lib/src/shell/liquid_shell.dart b/liquid_shell/lib/src/shell/liquid_shell.dart
index 559f4bf..24eaefb 100644
--- a/liquid_shell/lib/src/shell/liquid_shell.dart
+++ b/liquid_shell/lib/src/shell/liquid_shell.dart
@@ -10,6 +10,7 @@ import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
 import 'package:liquid_shell/src/chrome/tab_bar.dart';
 import 'package:liquid_shell/src/destinations/destination.dart';
 import 'package:liquid_shell/src/destinations/tab_action.dart';
+import 'package:liquid_shell/src/glass/glass_scope.dart';
 import 'package:liquid_shell/src/native/native_chrome.dart';
 import 'package:liquid_shell/src/native/native_host.dart';
 import 'package:liquid_shell/src/native/native_layout.dart';
@@ -846,10 +847,12 @@ class _LiquidShellState extends State<LiquidShell>
       widget.destinations,
       widget.tabBarTrailing,
     );
+    final forced = LiquidGlassScope.policyOf(context).forcedTier != null;
     final possible = nativeChromePossible(
       mode: widget.nativeChrome,
       hasChromeBuilder: widget.chromeBuilder != null,
       describable: describable,
+      glassTierForced: forced,
     );
     final engaged = nativeChromeEngaged(
       mode: widget.nativeChrome,
@@ -857,6 +860,7 @@ class _LiquidShellState extends State<LiquidShell>
       state: state,
       hasChromeBuilder: widget.chromeBuilder != null,
       describable: describable,
+      glassTierForced: forced,
     );
     // Only for a shell that asked for native chrome and could use it.
     if (!describable &&
diff --git a/liquid_shell/test/unit/native_layout_test.dart b/liquid_shell/test/unit/native_layout_test.dart
index 9c99a17..1531b76 100644
--- a/liquid_shell/test/unit/native_layout_test.dart
+++ b/liquid_shell/test/unit/native_layout_test.dart
@@ -12,12 +12,14 @@ bool _engaged({
   LiquidNativeShellState? state = _installed,
   bool hasChromeBuilder = false,
   bool describable = true,
+  bool glassTierForced = false,
 }) => nativeChromeEngaged(
   mode: mode,
   owner: owner,
   state: state,
   hasChromeBuilder: hasChromeBuilder,
   describable: describable,
+  glassTierForced: glassTierForced,
 );
 
 void main() {
@@ -42,6 +44,7 @@ void main() {
       );
       expect(_engaged(hasChromeBuilder: true), isFalse);
       expect(_engaged(describable: false), isFalse);
+      expect(_engaged(glassTierForced: true), isFalse);
     });
   });
 
@@ -50,10 +53,12 @@ void main() {
       LiquidNativeChrome mode = LiquidNativeChrome.auto,
       bool hasChromeBuilder = false,
       bool describable = true,
+      bool glassTierForced = false,
     }) => nativeChromePossible(
       mode: mode,
       hasChromeBuilder: hasChromeBuilder,
       describable: describable,
+      glassTierForced: glassTierForced,
     );
 
     test('auto, no chromeBuilder, describable → possible', () {
@@ -64,6 +69,7 @@ void main() {
       expect(possible(mode: LiquidNativeChrome.off), isFalse);
       expect(possible(hasChromeBuilder: true), isFalse);
       expect(possible(describable: false), isFalse);
+      expect(possible(glassTierForced: true), isFalse);
     });
   });
 
diff --git a/liquid_shell/test/widget/native_chrome_test.dart b/liquid_shell/test/widget/native_chrome_test.dart
index 3c1a4f7..c57c34e 100644
--- a/liquid_shell/test/widget/native_chrome_test.dart
+++ b/liquid_shell/test/widget/native_chrome_test.dart
@@ -220,6 +220,21 @@ void main() {
       expect(_scope(tester).sizeClass, LiquidSizeClass.regular);
     });
 
+    testWidgets('a forced glass tier keeps Flutter chrome (spec §9.1)', (
+      tester,
+    ) async {
+      final native = installFakeNative();
+      await _pumpNative(
+        tester,
+        shell: const LiquidGlassScope(
+          policy: LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid),
+          child: TestShell(destinations: kNative),
+        ),
+      );
+      expect(_flutterChrome(), isTrue);
+      expect(native.last.engaged, isFalse);
+    });
+
     testWidgets('a destination without sfSymbol keeps Flutter chrome', (
       tester,
     ) async {
```

Run: `cd liquid_shell && fvm flutter test test/unit/native_layout_test.dart test/widget/native_chrome_test.dart`
Expected: FAIL to compile, with "No named parameter with the name 'glassTierForced'".

- [ ] **Step 4: Implement**

Apply the library hunks: `git apply --exclude='*_test.dart'`. `liquid_shell.dart` imports `glass_scope.dart` and passes `LiquidGlassScope.policyOf(context).forcedTier != null`. Then add one sentence to the `forcedTier` dartdoc in `liquid_shell/lib/src/glass/policy.dart`:

```dart
  /// App override. Wins over every signal. `null` picks automatically.
  ///
  /// A forced tier also keeps every `LiquidShell` under this policy on
  /// Flutter chrome, even where native chrome could engage: forcing a tier
  /// asks for Flutter glass (spec 2026-10-10 §9.1).
  final LiquidGlassTier? forcedTier;
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd liquid_shell && fvm flutter test --exclude-tags golden,impeller,liquid_golden`
Expected: PASS, all tests, including "a forced glass tier keeps Flutter chrome (spec §9.1)".

- [ ] **Step 6: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add tool/check_glass_seam.sh tool/test/check_glass_seam_test.dart Makefile \
  liquid_shell/lib/src/native/native_layout.dart liquid_shell/lib/src/shell/liquid_shell.dart \
  liquid_shell/lib/src/glass/policy.dart \
  liquid_shell/test/unit/native_layout_test.dart liquid_shell/test/widget/native_chrome_test.dart
git commit -m "feat(shell): glass seam gate; a forced glass tier keeps Flutter chrome (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 8: The example's "Native / Flutter liquid" switch

> **Rebase first (owner decision L6).** Before this task, P2 must be merged with VK-405 (E1: SF Symbols on the native cases, a "drawn by Flutter" note on the others) and E2. Rebase `VK-348-liquid-tier` onto `main` and run `make verify`. If a hunk below no longer applies because E1 changed `demo_page.dart` or a case, keep both changes: E1's note goes above the switch.

**Files:**
- Create: `liquid_shell/example/lib/support/chrome_mode.dart`
- Modify:
  - `liquid_shell/example/lib/main.dart`
  - `liquid_shell/example/lib/support/demo_page.dart`
  - `liquid_shell/example/lib/cases/form_factors.dart`
  - `liquid_shell/example/lib/cases/forced_tier.dart`
  - `liquid_shell/README.md` (only the forced-tier snippet, through `--fix`)
- Test: `liquid_shell/example/test/chrome_mode_test.dart`

**Interfaces:**
- Consumes: the rule "a forced tier turns native chrome off" (Task 7), and `LiquidGlass.precache()` (Task 2).
- Produces:
  - `enum ExampleChromeMode { native, flutterLiquid }`;
  - `ChromeModeScope.maybeOf(context) → ValueNotifier<ExampleChromeMode>?`;
  - `CaseFrame({required Widget child})`;
  - `ChromeModeSwitch({required ValueNotifier<ExampleChromeMode> mode})`, whose segmented button has key `ValueKey('chrome-mode')` and the labels `Native` (iOS) or `Auto`, and `Flutter liquid`.

This code was applied and run green while the plan was written:
- the example's 52 widget tests;
- the 26 frosted goldens, unchanged, because they pump cases without `CaseFrame`;
- `check_readme_snippets` after `--fix`.

A first version drew the switch in the top trailing corner over the case. It covered the regular-width top bar and broke the guard tests, so the switch lives in the scrolling body (spec §9.2).

- [ ] **Step 1: Write the failing test**

`liquid_shell/example/test/chrome_mode_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/main.dart';

Future<void> _open(WidgetTester tester, String id) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 852);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ExampleApp());
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

LiquidGlassTier? _forced(WidgetTester tester) => LiquidGlassScope.policyOf(
  tester.element(find.byType(LiquidShell)),
).forcedTier;

void main() {
  testWidgets('every case shows the switch, starting at native', (
    tester,
  ) async {
    await _open(tester, 'basic');
    expect(find.byKey(const ValueKey('chrome-mode')), findsOneWidget);

    expect(find.text('Auto'), findsOneWidget); // not iOS in flutter test
    expect(_forced(tester), isNull);
  });

  testWidgets('the form factors case shows it too', (tester) async {
    await _open(tester, 'form_factors');
    // Its own switch, then one per framed DemoPage.
    expect(find.byKey(const ValueKey('chrome-mode')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flutter liquid forces the liquid tier and keeps the case', (
    tester,
  ) async {
    await _open(tester, 'basic');
    final shell = tester.state(find.byType(LiquidShell));
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    expect(_forced(tester), LiquidGlassTier.liquid);
    expect(tester.state(find.byType(LiquidShell)), same(shell));
  });

  testWidgets('the mode is shared by every case', (tester) async {
    await _open(tester, 'basic');
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('case-badges')));
    await tester.pumpAndSettle();
    expect(_forced(tester), LiquidGlassTier.liquid);
  });

  testWidgets('the forced-tier case keeps its own tier (inner scope)', (
    tester,
  ) async {
    await _open(tester, 'forced_tier');
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    expect(_forced(tester), LiquidGlassTier.frosted);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd liquid_shell/example && fvm flutter test test/chrome_mode_test.dart`
Expected: FAIL. The finder for `ValueKey('chrome-mode')` finds nothing (the switch does not exist yet).

- [ ] **Step 3: Implement**

`liquid_shell/example/lib/support/chrome_mode.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// How the example draws its chrome (spec 2026-10-10 §9.2).
enum ExampleChromeMode {
  /// The library's default: native chrome where it engages (iOS 26),
  /// otherwise the automatic glass tier.
  native,

  /// The Flutter liquid tier, forced. A forced tier also turns native
  /// chrome off, so the two can be compared on the same device.
  flutterLiquid,
}

/// The app-wide chrome mode, shared by every case and every pushed page.
class ChromeModeScope
    extends InheritedNotifier<ValueNotifier<ExampleChromeMode>> {
  /// Provides [notifier] to [child].
  const ChromeModeScope({
    required ValueNotifier<ExampleChromeMode> super.notifier,
    required super.child,
    super.key,
  });

  /// The nearest notifier, or null outside a scope.
  static ValueNotifier<ExampleChromeMode>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChromeModeScope>()?.notifier;
}

/// Wraps one case page in the mode's [LiquidGlassScope].
///
/// The scope is always there (with no forced tier in
/// [ExampleChromeMode.native]), so switching never rebuilds the case. The
/// switch itself is drawn by `DemoPage` under its title (and by the form
/// factors case in its app bar), never over the chrome.
class CaseFrame extends StatelessWidget {
  /// Frames [child].
  const CaseFrame({required this.child, super.key});

  /// The case page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final liquid =
        ChromeModeScope.maybeOf(context)?.value ==
        ExampleChromeMode.flutterLiquid;
    return LiquidGlassScope(
      policy: LiquidGlassPolicy(
        forcedTier: liquid ? LiquidGlassTier.liquid : null,
      ),
      child: child,
    );
  }
}

/// "Native / Flutter liquid" (L4).
class ChromeModeSwitch extends StatelessWidget {
  /// Creates the switch for [mode].
  const ChromeModeSwitch({required this.mode, super.key});

  /// The app-wide mode.
  final ValueNotifier<ExampleChromeMode> mode;

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: 'Chrome: native or Flutter liquid',
        child: SegmentedButton<ExampleChromeMode>(
          key: const ValueKey('chrome-mode'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: ExampleChromeMode.native,
              label: Text(ios ? 'Native' : 'Auto'),
              tooltip:
                  'Native chrome on iOS 26; elsewhere the library '
                  'picks the tier',
            ),
            const ButtonSegment(
              value: ExampleChromeMode.flutterLiquid,
              label: Text('Flutter liquid'),
            ),
          ],
          selected: {mode.value},
          onSelectionChanged: (s) => mode.value = s.single,
        ),
      ),
    );
  }
}
```

Then apply:

```diff
diff --git a/liquid_shell/README.md b/liquid_shell/README.md
index 6fa0e93..69be6d0 100644
--- a/liquid_shell/README.md
+++ b/liquid_shell/README.md
@@ -658,7 +658,9 @@ Widget build(BuildContext context) {
             onSelectionChanged: (s) => setState(() => _tier = s.single),
           ),
           if (_tier == LiquidGlassTier.liquid)
-            const Text('No liquid renderer is registered: drawing frosted.'),
+            const Text(
+              'Liquid needs Impeller; without it this draws frosted.',
+            ),
         ],
       ),
     ),
diff --git a/liquid_shell/example/lib/cases/forced_tier.dart b/liquid_shell/example/lib/cases/forced_tier.dart
index f23798a..de41ca5 100644
--- a/liquid_shell/example/lib/cases/forced_tier.dart
+++ b/liquid_shell/example/lib/cases/forced_tier.dart
@@ -42,7 +42,9 @@ class _ForcedTierCaseState extends State<ForcedTierCase> {
               onSelectionChanged: (s) => setState(() => _tier = s.single),
             ),
             if (_tier == LiquidGlassTier.liquid)
-              const Text('No liquid renderer is registered: drawing frosted.'),
+              const Text(
+                'Liquid needs Impeller; without it this draws frosted.',
+              ),
           ],
         ),
       ),
diff --git a/liquid_shell/example/lib/cases/form_factors.dart b/liquid_shell/example/lib/cases/form_factors.dart
index 6c1d33f..e4d5cb7 100644
--- a/liquid_shell/example/lib/cases/form_factors.dart
+++ b/liquid_shell/example/lib/cases/form_factors.dart
@@ -1,5 +1,6 @@
 import 'package:flutter/material.dart';
 import 'package:liquid_shell_example/cases/basic_tabs.dart';
+import 'package:liquid_shell_example/support/chrome_mode.dart';
 
 /// A device frame: logical size and safe-area padding.
 typedef DeviceFrame = ({String name, Size size, EdgeInsets padding});
@@ -40,6 +41,13 @@ class FormFactorsCase extends StatelessWidget {
     body: ListView(
       padding: const EdgeInsets.all(16),
       children: [
+        if (ChromeModeScope.maybeOf(context) case final mode?) ...[
+          Align(
+            alignment: AlignmentDirectional.centerStart,
+            child: ChromeModeSwitch(mode: mode),
+          ),
+          const SizedBox(height: 16),
+        ],
         for (final frame in kDeviceFrames) ...[
           Text(frame.name, style: Theme.of(context).textTheme.titleMedium),
           const SizedBox(height: 8),
diff --git a/liquid_shell/example/lib/main.dart b/liquid_shell/example/lib/main.dart
index b118abe..5b9f46b 100644
--- a/liquid_shell/example/lib/main.dart
+++ b/liquid_shell/example/lib/main.dart
@@ -1,25 +1,51 @@
 import 'package:flutter/material.dart';
+import 'package:liquid_shell/liquid_shell.dart';
 import 'package:liquid_shell_example/cases/cases.dart';
+import 'package:liquid_shell_example/support/chrome_mode.dart';
 
-void main() => runApp(const ExampleApp());
+Future<void> main() async {
+  WidgetsFlutterBinding.ensureInitialized();
+  // The first frame is already liquid, so no screenshot catches the
+  // frosted → liquid cross-fade.
+  await LiquidGlass.precache();
+  runApp(const ExampleApp());
+}
 
 /// The seed colour of the example theme.
 const kExampleSeed = Color(0xFF3D5AFE);
 
 /// The example app: a list of cases, each opening one screen.
-class ExampleApp extends StatelessWidget {
+class ExampleApp extends StatefulWidget {
   /// Creates the app.
   const ExampleApp({super.key});
 
   @override
-  Widget build(BuildContext context) => MaterialApp(
-    title: 'liquid_shell',
-    theme: ThemeData(colorSchemeSeed: kExampleSeed),
-    darkTheme: ThemeData(
-      colorSchemeSeed: kExampleSeed,
-      brightness: Brightness.dark,
+  State<ExampleApp> createState() => _ExampleAppState();
+}
+
+class _ExampleAppState extends State<ExampleApp> {
+  final ValueNotifier<ExampleChromeMode> _mode = ValueNotifier(
+    ExampleChromeMode.native,
+  );
+
+  @override
+  void dispose() {
+    _mode.dispose();
+    super.dispose();
+  }
+
+  @override
+  Widget build(BuildContext context) => ChromeModeScope(
+    notifier: _mode,
+    child: MaterialApp(
+      title: 'liquid_shell',
+      theme: ThemeData(colorSchemeSeed: kExampleSeed),
+      darkTheme: ThemeData(
+        colorSchemeSeed: kExampleSeed,
+        brightness: Brightness.dark,
+      ),
+      home: const CaseList(),
     ),
-    home: const CaseList(),
   );
 }
 
@@ -40,7 +66,9 @@ class CaseList extends StatelessWidget {
             subtitle: Text(entry.subtitle),
             trailing: const Icon(Icons.chevron_right),
             onTap: () => Navigator.of(context).push(
-              MaterialPageRoute<void>(builder: (_) => entry.page),
+              MaterialPageRoute<void>(
+                builder: (_) => CaseFrame(child: entry.page),
+              ),
             ),
           ),
       ],
diff --git a/liquid_shell/example/lib/support/demo_page.dart b/liquid_shell/example/lib/support/demo_page.dart
index d422505..9f12137 100644
--- a/liquid_shell/example/lib/support/demo_page.dart
+++ b/liquid_shell/example/lib/support/demo_page.dart
@@ -1,5 +1,6 @@
 import 'package:flutter/material.dart';
 import 'package:liquid_shell/liquid_shell.dart';
+import 'package:liquid_shell_example/support/chrome_mode.dart';
 import 'package:liquid_shell_example/support/wallpaper.dart';
 
 /// A long page over the [Wallpaper]. Its list is padded with
@@ -18,6 +19,7 @@ class DemoPage extends StatelessWidget {
   @override
   Widget build(BuildContext context) {
     final theme = Theme.of(context);
+    final mode = ChromeModeScope.maybeOf(context);
     // The nearest navigator with a page to pop: a branch navigator while it
     // holds a pushed page, otherwise the app's (back to the case list).
     final local = Navigator.of(context);
@@ -53,6 +55,13 @@ class DemoPage extends StatelessWidget {
                 ),
               ),
               const SizedBox(height: 12),
+              if (mode != null) ...[
+                Align(
+                  alignment: AlignmentDirectional.centerStart,
+                  child: ChromeModeSwitch(mode: mode),
+                ),
+                const SizedBox(height: 12),
+              ],
               ...children,
               for (var i = 1; i <= 24; i++)
                 Card(
```

Do not hand-edit the README hunk. Edit `forced_tier.dart`, then run `fvm dart run tool/check_readme_snippets.dart --fix` from the repo root. It rewrites the snippet from the `#docregion`.

- [ ] **Step 4: Run it to verify it passes**

Run:

```bash
cd liquid_shell/example && fvm flutter test --exclude-tags golden,liquid_golden && fvm flutter test --tags golden
cd ../.. && fvm dart run tool/check_readme_snippets.dart
```

Expected:
- all widget tests pass;
- the goldens pass without `--update-goldens`;
- the snippet check prints `✓ 16 README and doc snippets match their #docregion` (or the count after E1).

- [ ] **Step 5: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/example/lib/support/chrome_mode.dart liquid_shell/example/lib/main.dart \
  liquid_shell/example/lib/support/demo_page.dart liquid_shell/example/lib/cases/form_factors.dart \
  liquid_shell/example/lib/cases/forced_tier.dart liquid_shell/README.md \
  liquid_shell/example/test/chrome_mode_test.dart
git commit -m "feat(example): Native / Flutter liquid switch in every case (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Impeller goldens, side-by-side screenshots and docs

**Files:**
- Create:
  - `liquid_shell/example/test/goldens/liquid_test.dart`
  - `liquid_shell/example/integration_test/liquid_compare_test.dart`
  - `tool/side_by_side.dart`, `tool/test/side_by_side_test.dart`
  - `tool/compare_ios.sh`, `tool/compare_android.sh`
  - `liquid_shell/doc/liquid.md`
- Modify:
  - `liquid_shell/example/dart_test.yaml`
  - `tool/update_goldens.sh`
  - `Makefile` (`goldens`, new `compare-images`)
  - `liquid_shell/doc/tiers.md`, `liquid_shell/doc/native_chrome.md`, `liquid_shell/doc/theming.md`
  - `liquid_shell/README.md`
- Generated (never hand-edited): `liquid_shell/doc/images/liquid_*.png` and `liquid_shell/doc/images/compare_*.png`.

**Interfaces:**
- Consumes: everything above. The `ExampleApp` switch has the key `ValueKey('chrome-mode')` and the labels `Native`, `Auto` and `Flutter liquid`.
- Produces:
  - the tag `liquid_golden`;
  - the tool functions `Rgba scaleToHeight(Rgba, int)`, `Rgba sideBySide(Rgba, Rgba)` and `Uint8List encodeRgbaPng(Rgba)`, plus `const sideBySideGap = 24`;
  - the make targets `compare-images` and (extended) `goldens`.

The Impeller golden route and `tool/side_by_side.dart` were run while the plan was written. A liquid golden of `BasicTabsCase` (iPhone) and of `SidebarSlotsCase` (iPad landscape, dark) rendered through the existing `pumpGolden` and `expectDocImage`. It was then composed next to `doc/images/native_iphone.png`, and that comparison set the tint and blur defaults (spec §3.6).

- [ ] **Step 1: Write the failing tool test**

`tool/test/side_by_side_test.dart`:

```dart
import 'dart:typed_data';

import 'package:test/test.dart';

import '../compress_pngs.dart';
import '../side_by_side.dart';

Rgba _solid(int width, int height, List<int> rgba) => (
  width: width,
  height: height,
  pixels: Uint8List.fromList([
    for (var i = 0; i < width * height; i++) ...rgba,
  ]),
);

List<int> _at(Rgba image, int x, int y) {
  final i = (y * image.width + x) * 4;
  return image.pixels.sublist(i, i + 4);
}

void main() {
  test('scaleToHeight keeps the aspect ratio and the colour', () {
    final scaled = scaleToHeight(_solid(4, 8, [10, 20, 30, 255]), 4);
    expect(scaled.width, 2);
    expect(scaled.height, 4);
    expect(_at(scaled, 1, 3), [10, 20, 30, 255]);
  });

  test('sideBySide: left, a white gap, then right at the left height', () {
    final out = sideBySide(
      _solid(10, 20, [255, 0, 0, 255]),
      _solid(5, 10, [0, 0, 255, 255]),
    );
    expect(out.height, 20);
    expect(out.width, 10 + sideBySideGap + 10);
    expect(_at(out, 0, 0), [255, 0, 0, 255]);
    expect(_at(out, 10 + sideBySideGap ~/ 2, 5), [255, 255, 255, 255]);
    expect(_at(out, 10 + sideBySideGap + 9, 19), [0, 0, 255, 255]);
  });

  test('encodeRgbaPng round-trips through decodePng', () {
    final image = (
      width: 3,
      height: 2,
      pixels: Uint8List.fromList(List.generate(24, (i) => i * 10)),
    );
    final png = decodePng(encodeRgbaPng(image));
    expect(png.width, 3);
    expect(png.height, 2);
    expect(png.rgba, image.pixels);
  });
}
```

Run: `fvm dart test tool/test/side_by_side_test.dart`
Expected: FAIL to compile, with "Error when reading 'tool/side_by_side.dart'".

- [ ] **Step 2: Write the tool**

`tool/side_by_side.dart`:

```dart
// Places two screenshots side by side for the liquid tier acceptance
// (spec 2026-10-10 §10.4, §11): iOS 26 native on the left, Flutter liquid
// on the right. The right image is scaled (bilinear) to the left one's
// height; the gap and the margins are white. Pure Dart: reuses the PNG
// decoder of tool/compress_pngs.dart and writes an RGBA PNG.
//
// Usage: dart run tool/side_by_side.dart <left.png> <right.png> <out.png>
import 'dart:io';
import 'dart:typed_data';

import 'compress_pngs.dart';

/// Gap between the two images, in pixels.
const sideBySideGap = 24;

/// An RGBA image.
typedef Rgba = ({int width, int height, Uint8List pixels});

/// [image] scaled to [height] with bilinear sampling, keeping its aspect.
Rgba scaleToHeight(Rgba image, int height) {
  if (image.height == height) return image;
  final width = (image.width * height / image.height).round();
  final out = Uint8List(width * height * 4);
  final sx = image.width / width;
  final sy = image.height / height;
  for (var y = 0; y < height; y++) {
    final fy = ((y + 0.5) * sy - 0.5).clamp(0, image.height - 1).toDouble();
    final y0 = fy.floor();
    final y1 = (y0 + 1).clamp(0, image.height - 1);
    final wy = fy - y0;
    for (var x = 0; x < width; x++) {
      final fx = ((x + 0.5) * sx - 0.5).clamp(0, image.width - 1).toDouble();
      final x0 = fx.floor();
      final x1 = (x0 + 1).clamp(0, image.width - 1);
      final wx = fx - x0;
      for (var c = 0; c < 4; c++) {
        int at(int px, int py) => image.pixels[(py * image.width + px) * 4 + c];
        final top = at(x0, y0) * (1 - wx) + at(x1, y0) * wx;
        final bottom = at(x0, y1) * (1 - wx) + at(x1, y1) * wx;
        out[(y * width + x) * 4 + c] = (top * (1 - wy) + bottom * wy).round();
      }
    }
  }
  return (width: width, height: height, pixels: out);
}

/// [left] and [right] (scaled to [left]'s height) with a white gap.
Rgba sideBySide(Rgba left, Rgba right) {
  final r = scaleToHeight(right, left.height);
  final width = left.width + sideBySideGap + r.width;
  final out = Uint8List(width * left.height * 4)..fillRange(0, 0);
  for (var i = 0; i < out.length; i++) {
    out[i] = 255; // opaque white
  }
  for (var y = 0; y < left.height; y++) {
    out.setRange(
      y * width * 4,
      y * width * 4 + left.width * 4,
      left.pixels,
      y * left.width * 4,
    );
    final start = (y * width + left.width + sideBySideGap) * 4;
    out.setRange(start, start + r.width * 4, r.pixels, y * r.width * 4);
  }
  return (width: width, height: left.height, pixels: out);
}

/// [image] as a PNG: 8-bit RGBA, filter 0, zlib.
Uint8List encodeRgbaPng(Rgba image) {
  final stride = image.width * 4;
  final raw = Uint8List((stride + 1) * image.height);
  for (var y = 0; y < image.height; y++) {
    raw.setRange(
      y * (stride + 1) + 1,
      (y + 1) * (stride + 1),
      image.pixels,
      y * stride,
    );
  }
  final ihdr = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // RGBA
  return Uint8List.fromList([
    ...pngSignature,
    ...pngChunk('IHDR', ihdr.buffer.asUint8List()),
    ...pngChunk('IDAT', zlib.encode(raw)),
    ...pngChunk('IEND', const []),
  ]);
}

Rgba _read(String path) {
  final png = decodePng(File(path).readAsBytesSync());
  return (width: png.width, height: png.height, pixels: png.rgba);
}

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'usage: dart run tool/side_by_side.dart <left.png> <right.png> <out>',
    );
    exit(2);
  }
  final out = File(args[2])..createSync(recursive: true);
  final bytes = encodeRgbaPng(sideBySide(_read(args[0]), _read(args[1])));
  out.writeAsBytesSync(compressPng(bytes) ?? bytes);
  stdout.writeln('✓ ${args[2]}');
}
```

Run: `fvm dart test tool/test/side_by_side_test.dart`
Expected: PASS (3 tests).

Then run `fvm dart run tool/side_by_side.dart liquid_shell/doc/images/native_iphone.png liquid_shell/doc/images/hero_iphone_light.png /tmp/vk348_pair.png`. Expected: `✓ /tmp/vk348_pair.png`, an image 24 px wider than the two halves.

- [ ] **Step 3: Write the liquid goldens (they fail: no images yet)**

In `liquid_shell/example/dart_test.yaml`, add the tag:

```yaml
tags:
  golden:
  # Needs `flutter test --enable-impeller`: the liquid tier's shader.
  liquid_golden:
```

`liquid_shell/example/test/goldens/liquid_test.dart`:

```dart
@Tags(['liquid_golden'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';

import '../support/golden_harness.dart';

/// Changes one field of the default glass theme.
typedef _Adjust = LiquidGlassTheme Function(LiquidGlassTheme theme);

/// [child] under a theme whose glass is [adjust]ed.
Widget _themed(_Adjust adjust, Widget child) => Builder(
  builder: (context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: [
          adjust(LiquidGlassTheme.fromColorScheme(theme.colorScheme)),
        ],
      ),
      child: child,
    );
  },
);

void main() {
  setUp(() {
    // These goldens are the liquid tier; a run without Impeller is a
    // misconfiguration, not a frosted image to record.
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
  });

  Future<void> liquid(
    WidgetTester tester,
    String name,
    Widget child, {
    GoldenDevice device = iphone,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.runAsync(LiquidGlass.precache);
    await pumpGolden(tester, child, device: device, brightness: brightness);
    await expectDocImage(tester, name);
  }

  for (final device in [iphone, ipadLandscape, android]) {
    for (final brightness in Brightness.values) {
      final name = 'liquid_hero_${device.name}_${brightness.name}';
      testWidgets(name, (tester) async {
        await liquid(
          tester,
          name,
          const SidebarSlotsCase(),
          device: device,
          brightness: brightness,
        );
      });
    }
  }

  testWidgets('case_tier_liquid', (tester) async {
    await liquid(
      tester,
      'case_tier_liquid',
      const ForcedTierCase(initialTier: LiquidGlassTier.liquid),
    );
  });

  for (final (name, adjust) in <(String, _Adjust)>[
    ('liquid_refraction_0', (t) => t.copyWith(refraction: 0)),
    ('liquid_refraction_2', (t) => t.copyWith(refraction: 2)),
    ('liquid_dispersion_0', (t) => t.copyWith(dispersion: 0)),
  ]) {
    testWidgets(name, (tester) async {
      await liquid(tester, name, _themed(adjust, const BasicTabsCase()));
    });
  }
}
```

Run: `cd liquid_shell/example && fvm flutter test --enable-impeller --tags liquid_golden`
Expected: FAIL. Every test reports a missing golden file (`liquid_hero_iphone_light.png` … could not be found).

- [ ] **Step 4: Generate the liquid goldens with the one command**

In `tool/update_goldens.sh`, after `$FLUTTER test --tags golden --update-goldens`, add:

```bash
# The liquid tier needs Impeller's shader filters (spec 2026-10-10 §10.3).
$FLUTTER test --enable-impeller --tags liquid_golden --update-goldens
```

In `Makefile`, change the `goldens` recipe to:

```make
goldens: ## Golden tests (reference toolchain: macOS + Flutter 3.44.x); liquid ones under Impeller
	@if [ -d $(EXAMPLE)/test/goldens ]; then \
	  cd $(EXAMPLE) && $(FLUTTER) test --tags golden && \
	  $(FLUTTER) test --enable-impeller --tags liquid_golden; \
	else echo "▸ no goldens yet"; fi
```

and add `liquid_golden` to the `test` and `coverage` exclusions if Task 1 did not already (`--exclude-tags golden,impeller,liquid_golden`).

Run: `make goldens-update && make goldens`
Expected:
- `goldens-update` writes 9 `liquid_*.png` files and `case_tier_liquid.png` into `liquid_shell/doc/images/`;
- `goldens` passes;
- `git status` shows **no** change to any pre-existing image.

Open `liquid_hero_ipad_landscape_light.png`: the sidebar bends the backdrop only at its inner edge (the screen-edge rule).

- [ ] **Step 5: Write the screenshot integration test**

`liquid_shell/example/integration_test/liquid_compare_test.dart`:

```dart
// Native vs Flutter liquid screenshots for the owner's acceptance (spec
// 2026-10-10 §10.4, §11). tool/compare_ios.sh and tool/compare_android.sh
// run it; tool/side_by_side.dart places the pairs next to each other.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/main.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// `ios` or `android`: the first part of every screenshot name.
const _platform = String.fromEnvironment('COMPARE_PLATFORM');

/// The device part of the name, for example `iphone` or `ipad`.
const _device = String.fromEnvironment('COMPARE_DEVICE');

/// The modes to capture, comma-separated (`native,flutterLiquid`).
const _modes = String.fromEnvironment(
  'COMPARE_MODES',
  defaultValue: 'native,flutterLiquid',
);

/// Whether native chrome must engage in `native` mode (iOS 26).
const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');

/// The cases with native chrome (owner decision E1), in README order.
const kCompareCases = [
  'basic',
  'badges',
  'sidebar_only',
  'sidebar_slots',
  'trailing',
  'guard',
  'hide_chrome',
  'native_chrome',
];

Future<void> _open(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String mode) async {
  final label = mode == 'flutterLiquid'
      ? 'Flutter liquid'
      : (defaultTargetPlatform == TargetPlatform.iOS ? 'Native' : 'Auto');
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('chrome-mode')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
  // Native chrome attaches over the channel: give it a moment.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

bool _liquidShown() => find
    .byWidgetPredicate((w) => w.runtimeType.toString() == 'LiquidBackdrop')
    .evaluate()
    .isNotEmpty;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native and Flutter liquid, case by case', (tester) async {
    expect(_platform, isNotEmpty, reason: 'pass COMPARE_PLATFORM');
    await LiquidGlass.precache();
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    for (final mode in _modes.split(',')) {
      for (final id in kCompareCases) {
        await _open(tester, id);
        await _select(tester, mode);

        final scope = LiquidShellScope.of(
          tester.element(find.byType(DemoPage).first),
        );
        if (mode == 'flutterLiquid') {
          expect(scope.nativeChrome, isFalse, reason: '$id: forced liquid');
          expect(_liquidShown(), isTrue, reason: '$id: liquid drawn');
        } else if (_expectNative) {
          expect(scope.nativeChrome, isTrue, reason: '$id: native chrome');
        }

        // Scroll so cards and wallpaper sit under the chrome.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('${_platform}_${_device}_${id}_$mode');

        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }
  });
}
```

> If `LiquidShellScope.of` is named differently after P2 merges (check `lib/src/shell/shell_scope.dart`), use the accessor that returns `LiquidShellScopeData`. Its `nativeChrome` field is P2 API.

- [ ] **Step 6: Write the compare scripts and the make target**

`tool/compare_ios.sh` (then `chmod +x`):

```bash
#!/usr/bin/env bash
# Native vs Flutter liquid screenshots on iOS 26 simulators, then side by
# side (spec 2026-10-10 §11). Creates its own simulators and deletes them.
#
# IOS_RUNTIME  simctl runtime id (default com.apple.CoreSimulator.SimRuntime.iOS-26-5)
# FLUTTER      flutter command (default: flutter)
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
IOS_RUNTIME=${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}
created=()
cleanup() { for u in "${created[@]}"; do xcrun simctl delete "$u" || true; done; }
trap cleanup EXIT

shots=build/integration_screenshots
mkdir -p build/compare
for pair in "iphone=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro" \
            "ipad=com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4"; do
  device=${pair%%=*}
  udid=$(xcrun simctl create "vk348-compare-$device" "${pair#*=}" "$IOS_RUNTIME")
  created+=("$udid")
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
  "$tool_dir/with_timeout.sh" 1800 $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/liquid_compare_test.dart -d "$udid" \
    --dart-define=COMPARE_PLATFORM=ios --dart-define=COMPARE_DEVICE="$device" \
    --dart-define=EXPECT_NATIVE=true
  for native in "$shots"/ios_"$device"_*_native.png; do
    liquid=${native%_native.png}_flutterLiquid.png
    name=$(basename "${native%_native.png}")
    # shellcheck disable=SC2086 # DART may be "fvm dart"
    $DART run "$tool_dir/side_by_side.dart" "$native" "$liquid" "build/compare/$name.png"
  done
done
echo "✓ iOS comparisons in liquid_shell/example/build/compare/"
```

`tool/compare_android.sh` (then `chmod +x`):

```bash
#!/usr/bin/env bash
# Flutter liquid on an Android emulator, placed next to the iPhone native
# shots of tool/compare_ios.sh (spec 2026-10-10 §11).
#
# ANDROID_SERIAL  an emulator-* serial you started (never a physical device)
# FLUTTER, DART   commands (default: flutter, dart)
set -euo pipefail
tool_dir=$(cd "$(dirname "$0")" && pwd)
cd "$tool_dir/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
DART=${DART:-dart}
: "${ANDROID_SERIAL:?start an emulator and set ANDROID_SERIAL=emulator-NNNN}"
if [[ "$ANDROID_SERIAL" != emulator-* ]]; then
  echo "✗ $ANDROID_SERIAL is not an emulator" >&2
  exit 1
fi
shots=build/integration_screenshots
mkdir -p build/compare
# shellcheck disable=SC2086
$FLUTTER drive --driver=test_driver/integration_test.dart \
  --target=integration_test/liquid_compare_test.dart -d "$ANDROID_SERIAL" \
  --dart-define=COMPARE_PLATFORM=android --dart-define=COMPARE_DEVICE=phone \
  --dart-define=COMPARE_MODES=flutterLiquid
for liquid in "$shots"/android_phone_*_flutterLiquid.png; do
  id=${liquid#"$shots"/android_phone_}
  id=${id%_flutterLiquid.png}
  native="$shots/ios_iphone_${id}_native.png"
  if [ -f "$native" ]; then
    # shellcheck disable=SC2086
    $DART run "$tool_dir/side_by_side.dart" "$native" "$liquid" "build/compare/android_$id.png"
  else
    echo "▸ no $native yet (run tool/compare_ios.sh first); kept $liquid alone"
  fi
done
echo "✓ Android comparisons in liquid_shell/example/build/compare/"
```

In `Makefile`, add `compare-images` to `.PHONY` and:

```make
compare-images: ## Native vs Flutter liquid side by side (iOS sims you create, emulator in ANDROID_SERIAL); README subset to doc/images
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/compare_ios.sh
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/compare_android.sh
	cp $(EXAMPLE)/build/compare/ios_iphone_basic.png liquid_shell/doc/images/compare_iphone_basic.png
	cp $(EXAMPLE)/build/compare/ios_ipad_sidebar_slots.png liquid_shell/doc/images/compare_ipad_sidebar_slots.png
	cp $(EXAMPLE)/build/compare/android_basic.png liquid_shell/doc/images/compare_android_basic.png
	$(DART) run tool/compress_pngs.dart liquid_shell/doc/images
```

> Make recipes run under `sh`, where the environment's interactive `cp` alias does not apply. If you run these lines by hand, use `command cp`.

- [ ] **Step 7: Run the comparison and look at every pair**

Run (with the Task 5 emulator still up): `ANDROID_SERIAL=emulator-5594 make compare-images FLUTTER="fvm flutter" DART="fvm dart"`

Expected:
- 16 iOS pairs (8 cases × iPhone and iPad) and 8 Android pairs in `liquid_shell/example/build/compare/`;
- the 3 README images in `doc/images/`;
- the script deletes its simulators.

Open every pair. On the left, the iOS 26 native bar or sidebar; on the right, the Flutter liquid one with lens edge, rim and legible labels. Note each visible difference (for example the selection lens, a non-goal) in the VK-348 comment of Task 10.

- [ ] **Step 8: Write the docs**

1. `liquid_shell/doc/liquid.md` (new):

```markdown
# The liquid tier

`LiquidGlass` draws liquid glass by default wherever Flutter runs on
Impeller (iOS, Android 10+, macOS). The lens is this package's own
fragment shader; no other package is involved.

![Native iOS 26 (left) and Flutter liquid (right), iPhone](images/compare_iphone_basic.png)

## What it draws

- **Lens.** Across a 12pt band inside the edge the glass curves down like
  a thick lens. Content under that band is pulled in and magnified, up to
  about 9pt at the very edge; the middle is flat.
- **Specular rim.** A thin highlight, strongest on the top-left edge and
  fainter on the opposite one, plus a soft glow across the band.
- **Dispersion.** Red and blue bend slightly differently in the band, a
  faint colour fringe. `dispersion: 0` turns it off.
- **Blur and tint.** A light blur (σ 6) and the `liquidTint` colour.

A side that touches the screen edge (the sidebar's outer edges) has no
lens and no rim.

## Theme

| Field | Default | Effect |
|---|---|---|
| `liquidTint` | surface @ 50 % (light), 55 % (dark) | Colour over the glass; raise its alpha for more legibility |
| `refraction` | 1 | Lens strength; 0 is flat glass, 2 doubles it |
| `dispersion` | 0.3 | Colour fringe, 0–1 |
| `liquidBlurSigma` | 6 | Blur under the lens; 0 for none |

| `refraction: 0` | default | `refraction: 2` |
|---|---|---|
| ![](images/liquid_refraction_0.png) | ![](images/liquid_hero_iphone_light.png) | ![](images/liquid_refraction_2.png) |

## When it is not drawn

The tier drops to **frosted** without Impeller (Android 9 and lower, the
web), on Android devices without Vulkan 1.1 or with less than 3 GiB of
memory, in battery saver or iOS Low Power Mode, after sustained slow
frames, inside another `BackdropFilter`, and until the shader has loaded.
It drops to **solid** with Reduce Transparency, Increase Contrast, or
window blurs disabled outside battery saver. See [tiers.md](tiers.md).

## First frame

The shader loads when the first `LiquidGlass` mounts; until then glass is
frosted and then cross-fades. To start liquid:

    Future<void> main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await LiquidGlass.precache();
      runApp(const MyApp());
    }

## Cost

All chrome shares one backdrop copy (`BackdropGroup`). Each surface adds a
small blur and one pass of the lens over its own area. Never put glass on
list cells.

## Provenance

The shader is written from first principles (a rounded-rect distance
field, Snell's law, a Fresnel-like rim). No other glass package's code
was read or copied.
```

2. `liquid_shell/doc/tiers.md`:
   - Replace the tiers table's first row with `| `liquid` | the built-in lens shader (Impeller); see [liquid.md](liquid.md) | built in |`.
   - Replace "How the tier is chosen" steps 2–3 with the four steps of spec §6.2.
   - Replace the signals table with spec §6.1's table: drop `canBlur`, and add `lowEnd`, `glesOnly` and `slowFrames`. Battery saver and Low Power Mode → frosted; blur disabled → solid only without battery saver.
   - Change `TintOnlyRenderer`'s example so that it registers ahead of the built-in renderer (a registered renderer wins).
3. `liquid_shell/doc/native_chrome.md`, "When the native chrome is used": add the bullet `- no LiquidGlassScope above the shell forces a glass tier (a forced tier asks for Flutter glass)`.
4. `liquid_shell/doc/theming.md`: add the four fields to its table, with the defaults above.
5. `liquid_shell/README.md`:
   - In Features, replace the glass-tiers bullet with: `**Liquid glass by default**: the package's own lens shader on Impeller (iOS, Android 10+), with automatic **frosted** fallback (no Impeller, low-end or GLES-only Android, battery saver, Low Power Mode, slow frames) and **solid** for Reduce Transparency, Increase Contrast and disabled window blurs.`
   - In the platform table's Android row, change "no Impeller" to "low memory, no Vulkan 1.1".
   - Add a section "### Liquid glass" before "### Forced tier", with the three `compare_*.png` images captioned "iOS 26 native (left) and Flutter liquid (right)", and a link to `doc/liquid.md`.
   - Replace the "Accessibility and fallbacks" table with spec §6.1's mapping.
   - In Limitations, delete "No liquid tier yet", and add `- **Liquid glass inside another BackdropFilter draws frosted.** Flutter 3.44 gives a nested filter coordinates relative to its parent's region, so the lens cannot be placed there.`
   - In Roadmap, change P4 to `- **P4 (this release):** the liquid tier in the core package.`

Run: `fvm dart run tool/check_readme_snippets.dart && make provenance`
Expected: `✓ … match their #docregion`, `✓ provenance clean`, `✓ glass seam clean`.

- [ ] **Step 9: Run the gate and commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/example/dart_test.yaml liquid_shell/example/test/goldens/liquid_test.dart \
  liquid_shell/example/integration_test/liquid_compare_test.dart \
  tool/side_by_side.dart tool/test/side_by_side_test.dart tool/compare_ios.sh tool/compare_android.sh \
  tool/update_goldens.sh Makefile liquid_shell/doc/liquid.md liquid_shell/doc/tiers.md \
  liquid_shell/doc/native_chrome.md liquid_shell/doc/theming.md liquid_shell/README.md \
  liquid_shell/doc/images/liquid_*.png liquid_shell/doc/images/case_tier_liquid.png \
  liquid_shell/doc/images/compare_*.png
git commit -m "docs(glass): liquid goldens, native vs liquid comparisons, liquid docs (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: CI, versions, verification, owner review and one tuning round

**Files:**
- Modify: `.github/workflows/ci.yaml`
- Modify: `CLAUDE.md`, `CONTRIBUTING.md`
- Modify: the four `pubspec.yaml` files, `liquid_shell/example/pubspec.yaml`, `liquid_shell_ios/ios/liquid_shell_ios.podspec`, and the four `CHANGELOG.md` files

**Interfaces:**
- Consumes: every make target above.
- Produces: green CI on the 3.44.x leg. The owner's verdict is recorded on VK-348.

- [ ] **Step 1: Measure golden determinism on the CI runner (Q12)**

Before changing CI, run this once on a branch build, or have the controller trigger it:

```yaml
      - run: make goldens
      - run: make goldens   # twice: same runner, same images?
```

The job is the `goldens` job on `macos-latest`. If `liquid_golden` passes against the images generated locally (Task 9) on both runs, keep it blocking. If it differs by more than 0.5 %, add `continue-on-error: true` to a separate `liquid goldens` step (Step 2), and record the measured difference in the VK-348 comment.

- [ ] **Step 2: CI changes**

In `.github/workflows/ci.yaml`:

1. In the `goldens` job, after `- run: make goldens`, add `- run: make test-impeller`. (`make goldens` now includes `liquid_golden`.)
2. In `integration-android`, after `script: tool/integration_android.sh`, the same emulator also runs the liquid screenshots. Change the step's `script` to:

```yaml
          script: |
            tool/integration_android.sh
            cd liquid_shell/example && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/liquid_compare_test.dart --dart-define=COMPARE_PLATFORM=android --dart-define=COMPARE_DEVICE=phone --dart-define=COMPARE_MODES=flutterLiquid
```

   and add:

```yaml
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: liquid-android-screenshots
          path: liquid_shell/example/build/integration_screenshots/
```

3. In `integration-ios-native`, after "Native shell on the newest … simulator", add:

```yaml
      - name: Native vs Flutter liquid on the newest ${{ matrix.device }} simulator
        run: |
          udid=$(xcrun simctl list devices available | grep -F "    ${{ matrix.device }}" | tail -n1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
          cd liquid_shell/example
          flutter drive --driver=test_driver/integration_test.dart \
            --target=integration_test/liquid_compare_test.dart -d "$udid" \
            --dart-define=COMPARE_PLATFORM=ios \
            --dart-define=COMPARE_DEVICE=$(echo "${{ matrix.device }}" | tr '[:upper:]' '[:lower:]') \
            --dart-define=EXPECT_NATIVE=true
          mkdir -p build/compare
          for n in build/integration_screenshots/ios_*_native.png; do
            dart run ../../tool/side_by_side.dart "$n" "${n%_native.png}_flutterLiquid.png" "build/compare/$(basename "${n%_native.png}").png"
          done
```

   and extend that job's existing `upload-artifact` `path` with a second line: `liquid_shell/example/build/compare/`.

Run: `fvm dart run tool/check_readme_snippets.dart` (unchanged) and, if `actionlint` is installed, `actionlint .github/workflows/ci.yaml`. Expected: no findings.

- [ ] **Step 3: Versions and CHANGELOGs**

Replace `0.1.0-dev.2` with `0.1.0-dev.3` in:
- `liquid_shell/pubspec.yaml`, `liquid_shell_android/pubspec.yaml`, `liquid_shell_ios/pubspec.yaml` and `liquid_shell_platform_interface/pubspec.yaml` (the version and every `^0.1.0-dev.2` dependency);
- `liquid_shell/example/pubspec.yaml`;
- `liquid_shell_ios/ios/liquid_shell_ios.podspec`.

Check with: `git grep -n "0\.1\.0-dev\.2" -- '*pubspec.yaml' '*.podspec'`. Expected: no output.

Prepend to `liquid_shell/CHANGELOG.md`:

```markdown
## 0.1.0-dev.3

- **Liquid glass by default.** A built-in, clean-room lens shader draws the
  `liquid` tier on Impeller: edge refraction, a specular rim, light
  dispersion, blur and tint. `LiquidGlass.precache()` loads it before the
  first frame. New `LiquidGlassTheme` fields: `liquidTint`, `refraction`,
  `dispersion`, `liquidBlurSigma`.
- Frosted instead of liquid without Impeller, on Android without Vulkan 1.1
  or under 3 GiB of memory, in battery saver and iOS Low Power Mode, after
  sustained slow frames, and inside another `BackdropFilter`.
- A `forcedTier` keeps shells under it on Flutter chrome.
- **Breaking:** `LiquidGlassSignals.canBlur` is removed (Skia now draws
  frosted, not solid); `debugLiquidGlassCanBlurOverride` is now
  `debugLiquidGlassCanRefractOverride`; battery saver gives frosted, not
  solid. `LiquidGlassSignals` gains `lowEnd`, `glesOnly`, `slowFrames` and
  `prefersFrosted`.
```

Prepend these to the other three:
- `liquid_shell_platform_interface`: `## 0.1.0-dev.3` followed by `- `LiquidPlatformSignals.lowEnd` and `glesOnly`.`
- `liquid_shell_android`: `## 0.1.0-dev.3` followed by `- Reports `lowEnd` (low-RAM flag or under 3 GiB) and `glesOnly` (Android 10+ without Vulkan 1.1).`
- `liquid_shell_ios`: `## 0.1.0-dev.3` followed by `- Reports Low Power Mode as `powerSave`.`

Run: `make get && make publish-check`
Expected: every package's dry run has the same warnings as before, and none new.

- [ ] **Step 4: Contributor docs**

In `CLAUDE.md`:
- Under "Commands", add `make test-impeller   # shader tests under Impeller (macOS)` and `make compare-images   # native vs Flutter liquid screenshots`.
- Under "Hard rules", add: `- **Clean-room shader.** Never open or copy another glass package's shader or glass code (liquid_glass_renderer, liquid_glass_widgets, liquid_glass_easy, …). Derive from spec 2026-10-10 §4.`

In `CONTRIBUTING.md`, add the same two commands to its commands list.

- [ ] **Step 5: Full verification**

Run on macOS:

```bash
make verify 2>&1 | tail -20
make android-unit && make integration-android      # with your emulator in ANDROID_SERIAL
make ios-unit IOS_UNIT_DEVICE=$UDID
make integration-ios-native
```

Expected:
- `✓ verify passed`. That run includes `test-impeller`, the liquid goldens and the glass seam gate.
- Each integration target passes.

Paste the tails into the PR body later. Then delete your simulators (`xcrun simctl delete <udid>`) and your AVD (`avdmanager delete avd -n vk348-api36`), and run `command rm -rf liquid_shell/example/build`.

- [ ] **Step 6: Commit**

```bash
bash .githooks/pre-commit
git add .github/workflows/ci.yaml CLAUDE.md CONTRIBUTING.md \
  liquid_shell/pubspec.yaml liquid_shell_android/pubspec.yaml liquid_shell_ios/pubspec.yaml \
  liquid_shell_platform_interface/pubspec.yaml liquid_shell/example/pubspec.yaml \
  liquid_shell_ios/ios/liquid_shell_ios.podspec \
  liquid_shell/CHANGELOG.md liquid_shell_android/CHANGELOG.md liquid_shell_ios/CHANGELOG.md \
  liquid_shell_platform_interface/CHANGELOG.md
git commit -m "ci(glass): Impeller goldens and liquid screenshots; 0.1.0-dev.3 (VK-348)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Owner review (L5) and one tuning round**

1. Publish `liquid_shell/example/build/compare/*.png` to the owner, either as a private artifact page or as the CI artifacts. Comment on VK-348 with the list and the differences noted in Task 9 Step 7.
2. Build the example for the owner's devices with the OTA script (`~/ota/vankhan/build.sh <worktree>`, see the vankhan memory note). The owner selects "Flutter liquid" on a real iPad and iPhone. Nobody else touches the devices.
3. Apply the owner's verdict in **one** tuning commit.
   - It changes only `LiquidOptics` constants or the four theme defaults.
   - The tests for those values (`liquid_optics_test.dart` numbers, the `glass_theme_test.dart` defaults) change in the same commit.
   - After it, regenerate with `make goldens-update` and `make compare-images`.
   - Commit message: `fix(glass): tune liquid look after owner review (VK-348)`.

Anything beyond tuning (the selection lens, motion) is a new Plane item, not this task.

---

## Dry-run notes (2026-10-10, while writing this plan)

A throwaway copy of the branch (`git archive` of `5e0a1e9`) was set up in the session scratchpad. Tasks 1–8 and the tool part of Task 9 were applied there in order, from the exact code in this plan. Nothing from that copy was committed. Measured on macOS with Flutter 3.44.6:

| Check | Result |
|---|---|
| Task 1 unit tests (`liquid_optics_test.dart`) | 13 pass |
| Task 1 Impeller pixel tests (`flutter test --enable-impeller --tags impeller`) | 5 pass. Without Impeller, 4 fail, which is why they are tagged |
| Task 2 theme and loader tests | pass. `FragmentProgram.fromAsset('shaders/liquid_glass.frag')` loads in plain `flutter test` |
| Task 3 widget tests | 8 pass. With the listeners and the drift-guard `add` removed, exactly the 4 tests named in Step 5 fail |
| Task 3 real lens through the render object under Impeller (moving) | passes; a rendered frame showed the lens on a moving pill |
| Task 4: package / interface / example widget / example `golden` | 369 / 33 / 47 / 26 pass; every frosted golden byte-identical |
| Task 5 Kotlin `make android-unit` | `BUILD SUCCESSFUL`; both new tests pass |
| Task 6 frame guard | 9 pass; package suite 368 |
| Task 7 gate test, native tests | 4 pass; package suite 369 |
| Task 8 example widget tests, goldens, snippets | 52 pass, 26 goldens unchanged, snippets match after `--fix` |
| Task 9 liquid goldens | 10 images rendered through `pumpGolden`/`expectDocImage`; the iPad sidebar bends only at its inner edge |
| Task 9 `tool/side_by_side.dart` | 3 tests pass; it composed `native_iphone.png` with a liquid golden, which set the tint and blur defaults (spec §3.6) |
| `dart analyze --fatal-infos --fatal-warnings` on everything touched | no issues |

**Not run in the dry run** (they need devices or CI, so the tasks run them):
- the Swift change and its XCTests (Task 5 Steps 5–6);
- both integration tests on a simulator or emulator (Task 5 Step 9, Task 9 Step 7);
- `tool/compare_*.sh`;
- the CI YAML.

The spike behind spec §3.2 did run on an iOS 26.5 simulator and an Android 36 emulator (GLES and Vulkan), with a probe shader declared in a package.

## Self-review

**Spec coverage:**

| Spec item | Where |
|---|---|
| S1 shader, its declaration, compile check (§4) | Task 1 |
| S2 renderer, paint-time placement, moving ancestors, nesting (§5.2–5.4) | Task 3, Task 4 |
| S3 theme fields (§5.6, Q3, Q4) | Task 2 |
| S4 tier policy, matrix (§6) | Task 4 |
| S5 Android `lowEnd`/`glesOnly`, iOS Low Power Mode (§7.1–7.3, Q5, Q6, Q8) | Task 4 (interface), Task 5 |
| S5 frame guard (§7.4, Q7) | Task 6 |
| S6 every surface through `LiquidGlass`, gate, screen-edge rule (§8, Q14) | Task 1 (rule), Task 7 (gate) |
| S7 forced tier → Flutter chrome (§9.1, Q11) | Task 7 |
| S8 switch, `precache` in `main` (§9.2) | Task 8 |
| S9 unit, widget, Impeller tests (§10.1–10.3) | Tasks 1–8, Task 9 |
| S10 side-by-side screenshots (§10.4, §11) | Task 9, Task 10 Step 7 |
| S11 CI, Q12 measurement (§12.2) | Task 10 |
| S12 docs, CHANGELOGs, version (§12.3, Q13, Q16) | Task 9, Task 10 |
| Q1, Q2 (optics constants) | Task 1 (`LiquidOptics`), Task 10 Step 7 tuning |
| Q9 (battery saver, Skia, blur disabled) | Task 4 |
| Q10 (inside another `BackdropFilter`) | Task 4 |
| Q15 (non-goals) | not implemented, by design; Task 10 Step 7 routes them to new Plane items |

**Placeholder scan:** no "TBD" or "TODO". Every code step carries its code or an exact patch.

**Type consistency:** these names are used identically in every task and were compiled together in the dry run:
- `liquidUniforms({rect, radii, params, scale, pass})`
- `LiquidOptics.firstIndex`
- `LiquidOpticsParams.fromTheme`
- `LiquidShaderProgram.instance.load()` and `.debugReset()`
- `LiquidGlass.precache()`
- `LiquidBackdrop({program, borderRadius, params})`
- `RenderLiquidBackdrop.passGeometry()`, `checkDrift()`, `debugPaintedRect` and `debugUniforms`
- `debugLiquidFilterFactory`
- `LiquidDriftGuard.instance.add`, `remove` and `debugCount`
- `LiquidShaderRenderer`
- `liquidGlassCanRefract()` and `debugLiquidGlassCanRefractOverride`
- `LiquidGlassSignals(lowEnd, glesOnly, slowFrames)` and `prefersFrosted`
- `LiquidPlatformSignals(lowEnd, glesOnly)`
- `LiquidFrameGuard.instance` with `acquire`, `release`, `addRasterTimes`, `debugUsers`, `debugSubscribed` and `debugReset`
- `nativeChromePossible(…, glassTierForced:)`
- `ExampleChromeMode`, `ChromeModeScope.maybeOf`, `CaseFrame` and `ChromeModeSwitch(mode:)`
- `Rgba`, `scaleToHeight`, `sideBySide`, `encodeRgbaPng` and `sideBySideGap`
