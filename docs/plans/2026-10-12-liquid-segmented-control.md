# liquid_shell VK-550: `LiquidSegmentedControl` and the liquid scope bar Implementation Plan

> **Approval:** the owner approves this plan together with the spec `docs/specs/2026-10-12-liquid-segmented-control-design.md`. Q1–Q5 are decided. Until the owner answers the spec's new rows (Q-A … Q-F), this plan implements their recommended defaults; a different answer changes only the tasks named in "Owner defaults applied".
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the search scope bar ("All | Songs | Places") Liquid Glass (VK-550):

- on iOS 26+ with native chrome, UIKit's own scope bar on the native search tab, through a one-way bridge;
- everywhere else, a new public `LiquidSegmentedControl` that matches iOS 26.5's `UISegmentedControl` at rest and in motion (tap spring, pressed lens with refraction and the rainbow rim, drag and flick across segments with selection clicks), built on the VK-503 lens engine, generalised rather than copied;
- `LiquidSearchScopeBar` as a thin wrapper of it; docs, example, `0.1.0-dev.7`.

**Architecture:** The VK-503 engine is generalised first, as a pure refactor guarded by every VK-503 test: `LensMotion` takes a `LensTrack` (the slots a lens moves over) and a `LensProfile` (springs plus a `TabEnvelope` or `SegmentEnvelope`); the ticker loop and the lens clip leave `GlassTabBar` as `LensTicker` and `LensClip`. Then the segment geometry and the segment envelope are pure Dart, fitted to the native rows of the spike. `LiquidSegmentedControl` paints a track fill, the rest thumb or a `LiquidLens`, and two label rows split by `LensClip`. The native scope bar is a Pigeon addition (config `scopes`, `setSearchScope`, `onSearchScopeChanged`), `SearchBridge` drives `UISearchBar`'s scope bar with `.manual` activation toggled by the search controller's delegate, and `ShellSearch` dedupes.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12 (fvm), `flutter_test`, `integration_test`, Impeller tests, Pigeon 27.3.0, Swift (XCTest, XCUITest), Xcode 27 with iOS 26.5 and 27.0 simulators, `ffmpeg` (developer tool, strips only).

## Global Constraints

- **Floor:** Flutter `>=3.44.0`, Dart `^3.12.0`, iOS deployment target `15.0`. fvm pins `3.44.6` (`.fvmrc`).
- **Analysis:** `very_good_analysis` pinned to `10.3.0`; `dart analyze --fatal-infos --fatal-warnings` clean. Never loosen `analysis_options.yaml`.
- **Runtime dependencies:** Flutter, our packages, `plugin_platform_interface`, plus `meta` in `liquid_shell_ios`. Nothing new anywhere, the example included. `ffmpeg` and `idb` are developer tools only.
- **Clean room:** never open or copy another glass package's shader or glass code (`liquid_glass_renderer`, `liquid_glass_widgets`, `liquid_glass_easy`, …). `liquid_glass.frag` is not edited.
- **Reuse, don't copy (owner Q3):** no second copy of springs, the ticker loop, the lens clip, the gesture recognizer or the lens pass. Shared code moves to one place; both widgets import it.
- **Glass seam:** `BackdropFilter` and `ImageFilter.(blur|shader|compose)` only under `liquid_shell/lib/src/glass/` (`make provenance`).
- **Public API:** the barrel exports only `LiquidSegmentedControl`, `LiquidSegment` (new), the new fields of `LiquidSearch`, `LiquidShellScopeData` and `LiquidGlassTheme`. `LensTrack`, `LensProfile`, `LensTicker`, `LensClip`, `SegmentGeometry`, `debugSegmentTrace`, `debugSegmentLensPress` stay in `src/` (`test/unit/public_api_test.dart`).
- **Numbers:** every metric and spring comes from the spec (§5, §6, §8) and `docs/qa/vk550/native_reference.json`. Values marked "(assumption)" in the spec keep their stated value until Task 1 measures them. Acceptance rows compare with native data, never with our own constants (owner Q3).
- **Generated channel:** edit `liquid_shell_ios/pigeons/native_shell.dart`, run `make pigeon`, commit the source and both generated files (`make pigeon-check`).
- **TDD:** no production code without a test that failed first for the right reason. Run the single test, see it red, implement, see it green. Refactor tasks (2, 6) are guarded by the existing tests staying green before and after; each adds a test that pins the new seam.
- **Commits:** `<type>(<scope>): <summary> (VK-550)`, scopes `shell glass platform ios android example docs ci`, ending with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run `bash .githooks/pre-commit` by hand before every commit; stage by explicit path; never `--no-verify`, never set `core.hooksPath`, never change git or flutter config. No pushes, no remotes, no publishing.
- **Goldens:** only through `make goldens-update` on macOS + Flutter 3.44.6; never edit images by hand; review every regenerated image's diff.
- **Simulators:** create your own (`xcrun simctl create "vk550 …"`), delete them at the end, never `simctl shutdown all`, never touch a physical device. Keep ≥ 10 GB free (`df -h /`). The host is shared and often loaded: time-box every simulator step (`tool/with_timeout.sh`).
- **Environment:** `rm` is aliased here: use `command rm`.
- **Worktree:** only `/Users/invoker/Projects/tuvi/liquid_shell-vk550`, branch `VK-550-liquid-segmented-control` (on VK-503 `1c1eeb9`). After PR #9 merges, rebase on `main` before the PR (Q4).
- **Version:** all four packages `0.1.0-dev.6` → `0.1.0-dev.7` (Task 14).

## Owner defaults applied

| Q | Default | Tasks |
|---|---|---|
| Q1 (decided) | Native scope bar on iOS 26+ native chrome: `.manual` + `setShowsScope` toggled in `willPresent` / `willDismiss` (spike §1) | 10, 11 |
| Q2 (decided) | Public `LiquidSegmentedControl`; `LiquidSearchScopeBar` wraps it | 7, 9 |
| Q3 (decided) | Engine reuse; tab-level fidelity; selection click per crossing while dragging | 2–8, 13, 15 |
| Q4 (decided) | Stacked on VK-503; PR after #9 | all |
| Q5 (decided) | Flutter control on Android and iOS < 26, tier demotion | 7, 8 |
| Q-A | Accept UIKit's scope bar look and placement; shown only while the search is active | 10, 11 |
| Q-B | Flat track fill (as `UISegmentedControl`), glass only in the lens | 5, 7 |
| Q-C | 44 pt box, 32 pt track centred; intrinsic segments ≥ 44 | 3, 7 |
| Q-D | Labels scale up to ×2; track grows; ellipsis; large content viewer at AX | 3, 7 |
| Q-E | Two-spring flight + wobble + speed squash, gated on peaks and settle | 4, 15 |
| Q-F | Text segments (+ per-segment enabled) only | 7 |

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `docs/qa/vk550/native_reference.json` (new), `docs/qa/vk550/spike.md` | 1 | The native fixture; the spike notes completed |
| `tool/test/segment_reference_test.dart` (new) | 1 | The fixture's schema |
| `liquid_shell/lib/src/chrome/lens_track.dart` (new) | 2 | `LensTrack` |
| `liquid_shell/lib/src/chrome/lens_profile.dart` (new) | 2, 4 | `LensProfile`, `LensEnvelope`, `TabEnvelope`, `SegmentEnvelope`, `LensProfile.tab`, `LensProfile.segment` |
| `liquid_shell/lib/src/chrome/lens_motion.dart` | 2, 4 | `LensMotion(geometry: LensTrack, profile:)`; segment envelope targets |
| `liquid_shell/lib/src/chrome/tab_geometry.dart` | 2 | `TabBarGeometry implements LensTrack` |
| `liquid_shell/test/unit/lens_profile_test.dart` (new) | 2, 4 | Profile pins |
| `liquid_shell/lib/src/segmented/segment_geometry.dart` (new) | 3 | `SegmentMetrics`, `SegmentGeometry`, `segmentGeometry()` |
| `liquid_shell/test/unit/segment_geometry_test.dart` (new) | 3 | Spec §5 checks |
| `liquid_shell/test/unit/segment_motion_test.dart` (new), `liquid_shell/test/helpers/native_rows.dart` (new) | 4 | The segment profile against the fixture |
| `liquid_shell/lib/src/glass/glass_theme.dart`, `test/unit/glass_theme_test.dart` | 5 | `segmentTrack`, `segmentThumb`, `segmentLabelStyle` |
| `liquid_shell/lib/src/chrome/lens_ticker.dart` (new), `lens_clip.dart` (new), `glass_tab_bar.dart` | 6 | Shared ticker loop and clip |
| `liquid_shell/test/widget/lens_ticker_test.dart` (new) | 6 | The ticker seam |
| `liquid_shell/lib/src/glass/liquid_lens.dart` | 7 | Optional `bezel` |
| `liquid_shell/lib/src/segmented/segmented_control.dart` (new), `lib/liquid_shell.dart`, `test/unit/public_api_test.dart` | 7, 8 | `LiquidSegment`, `LiquidSegmentedControl`, hooks |
| `liquid_shell/test/widget/{segmented_control,segment_gesture,segment_lens}_test.dart` (new) | 7, 8 | Widget tests |
| `liquid_shell/lib/src/search/{search,search_controller,scope_bar,shell_search}.dart`, `lib/src/shell/shell_scope.dart`, `lib/src/shell/liquid_shell.dart` | 9, 10 | `LiquidSearch.scopes`, `scopeSetByApp`, wrapper, `nativeSearchScopes`, sync |
| `liquid_shell/test/widget/scope_bar_test.dart` (new), `test/unit/{search,shell_search}_test.dart` | 9, 10 | Wrapper and sync tests |
| `liquid_shell_platform_interface/lib/src/{native_chrome,liquid_shell_platform}.dart` + tests | 10 | `scopes`, `setNativeSearchScope`, `LiquidNativeSearchScopeChanged` |
| `liquid_shell_ios/pigeons/native_shell.dart`, both generated files, `lib/src/{mapping,platform}.dart` + tests | 10 | Channel |
| `liquid_shell_ios/ios/.../SearchBridge.swift`, `NativeTabsController.swift`, `NativeShellInstaller.swift` | 10 | UIKit scope bar |
| `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` | 10 | XCTest of the bridge |
| `liquid_shell/example/integration_test/native_search_test.dart`, `example/ios/RunnerUITests/SearchUITests.swift` | 11 | Native integration |
| `liquid_shell/example/lib/cases/{search,segments,cases}.dart`, `example/lib/main.dart`, `example/ios/Runner/SegmentReferenceViewController.swift` (new), `example/ios/Runner/AppDelegate.swift`, example tests and goldens | 12 | Example |
| `tool/trace_math.dart` (new, from `tab_trace_compare.dart`), `tool/segment_trace_compare.dart` (new), `tool/frames_lib.sh` (new, from `tab_frames.sh`), `tool/segment_frames.sh` (new), `tool/test/segment_trace_compare_test.dart` (new), `liquid_shell/example/integration_test/segment_fidelity_test.dart` (new), `example/ios/RunnerUITests/SegmentFidelityUITests.swift` (new), `Makefile` | 13 | Acceptance tooling |
| `liquid_shell/doc/segmented_control.md` (new), `doc/search.md`, `README.md`, CHANGELOG ×4, pubspecs, podspec | 14 | Docs and version |
| `docs/qa/vk550/acceptance.md` (new) | 15 | Trace table, strip index, owner checklist |

## Set up once (the controller, before Task 1)

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk550
git status            # clean, on VK-550-liquid-segmented-control
git log --oneline -2  # the docs commit of this plan, on top of 1c1eeb9
make get
make test             # green baseline
make tab-traces       # the VK-503 table: record it; Task 2 must reproduce it exactly
```

Keep the `make tab-traces` output in the scratchpad (`baseline-tab-traces.txt`): Task 2 diffs against it.

---

### Task 1: Native reference: finish the capture, write the fixture

The spike (`docs/qa/vk550/spike.md`) settled Q1 and measured the light rest look and the motion on three segments. This task adds what the spike did not measure and writes the fixture every later test reads.

**Files:**
- Create: `docs/qa/vk550/native_reference.json`
- Modify: `docs/qa/vk550/spike.md` (§4 becomes "Measured in Task 1")
- Test: `tool/test/segment_reference_test.dart`

**Interfaces:**
- Consumes: the spike's seed rows, vankhan `.superpowers/sdd/vk550-spike/native_rows.json` (control-local x, columns `t, x, w, h, engage`), and its probe source `segfid_probe_main.swift`.
- Produces: `native_reference.json` with the keys below. Every later task reads it; nothing in it is ever computed from our own code.

```jsonc
{
  "source": "...",
  "columns": ["t", "x", "w", "h", "engage"],
  "geometry": { "width": 370, "height": 32, "thumbInset": 2, "thumbs3": [[2,2,119,28],[125,2,119,28],[248,2,120,28]],
                "thumb2": [181,28], "thumb5": [70,28], "intrinsic3": 177, "intrinsicLong": 234, "intrinsicABC": 96,
                "pressedGrow": [24,16], "tolerance": 1 },
  "colors": { "lightTrackOverWhite": [238,238,239], "lightThumb": [255,255,255], "darkTrackOverBlack": [28,28,31],
              "darkThumbOverTrack": [90,90,95], "lightLabel": [0,0,0], "darkLabel": [255,255,255], "tolerance": 4 },
  "fits": { "tap": {"zeta":0.87,"response":0.41,"delay":0.008}, "pressSize": {...}, "releaseSize": {...},
            "programmatic": {"zeta":0.82,"response":0.41}, "dragLag": {"speed":82.2,"lag":6.77} },
  "tap_1_2": {"from":0,"to":1,"rows":[[t,x,w,h,engage], ...]},   // t from valueChanged, 0.05 s steps to 0.9 s
  "tap_2_3": {...}, "tap_3_1": {...},
  "press": {"rows": [...]},                                      // t from the down, 1/30 s steps to 0.3 s
  "release": {"rows": [...]},                                    // t from the up
  "slow_drag": {"release_rows": [...], "commit": 2},
  "flick": {"rows": [...], "release_at": 0.465, "commit": 0},
  "programmatic_2seg": {"from":0,"to":1,"rows":[...]},
  // added by this task:
  "dark": {"tap_1_2": {...}, "press": {...}},
  "tap_1_3_5seg": {...},
  "lens": {"labelMagnify": <measured>, "bezel": <measured ring width, pt>},
  "rtl": {"segment0Right": true},
  "tapOnSelected": {"valueChanged": <bool>},
  "flickLanding": {"overshoot": <pt>}
}
```

- [ ] **Step 1: Write the failing test**

`tool/test/segment_reference_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final file = File('docs/qa/vk550/native_reference.json');

  test('the segment fixture exists and has every key the gate reads', () {
    expect(file.existsSync(), isTrue);
    final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final key in [
      'geometry', 'colors', 'fits', 'tap_1_2', 'tap_2_3', 'tap_3_1', 'press',
      'release', 'slow_drag', 'flick', 'programmatic_2seg', 'dark',
      'tap_1_3_5seg', 'lens', 'rtl', 'tapOnSelected', 'flickLanding',
    ]) {
      expect(j, contains(key), reason: key);
    }
    expect(j['columns'], ['t', 'x', 'w', 'h', 'engage']);
  });

  test('every row has five numbers and rising time', () {
    final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final key in ['tap_1_2', 'tap_2_3', 'tap_3_1', 'press', 'release']) {
      final rows = (j[key] as Map)['rows'] as List;
      expect(rows, isNotEmpty, reason: key);
      var last = -1.0;
      for (final r in rows.cast<List<dynamic>>()) {
        expect(r, hasLength(5), reason: key);
        final t = (r[0] as num).toDouble();
        expect(t, greaterThan(last), reason: key);
        last = t;
      }
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fvm dart test tool/test/segment_reference_test.dart`
Expected: FAIL, `Expected: true Actual: <false>` (no fixture).

- [ ] **Step 3: Capture**

1. Rebuild the probe from `segfid_probe_main.swift` in your scratchpad (`xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios26.0-simulator -swift-version 5 -Onone main.swift -o SegFid.app/SegFid`, the Info.plist of the spike: scene delegate `SceneDelegate`, bundle id `dev.segfid.sample`; `codesign -s - --force SegFid.app`).
2. Create `vk550-t1-iphone265` (iPhone 17 Pro, iOS 26.5). Install, `idb connect`.
3. Drive with `idb ui tap --duration 0.07` (taps), `idb ui tap --duration 2` (hold), `idb ui swipe --duration 2.5 --delta 3` (slow drag), `idb ui swipe --duration 0.25` (flick), as the spike's `idbrun.sh`. Discard any run where a touch's `now − timestamp` exceeds 30 ms (host load).
4. Capture, each as per-frame rows with the spike's `rows.py` method (lens centre control-local, `opacityPair` as engage):
   - **dark** `-mode seg -bg plain` with `simctl ui appearance dark`: tap 1→2 and press;
   - **five segments**: tap 1→3 on `full5` (`-trace 3`, y = 416);
   - **flick landing**: overshoot past the landing segment (pt);
   - **RTL**: add `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` to the launch; record whether segment 0 is at the right;
   - **tap on the selected segment**: whether `valueChanged` fires (the `SEL` line);
   - **held press on an unselected segment**: whether the lens moves to the finger before the release (key `pressOther`, rows from the down);
   - **label magnification**: the `UISegmentLabel` presentation scale under the held lens (the trace's `s=` of the label layers inside `ContentLensingView`), and the lens's refracting ring width: from a held-lens screenshot over the `-bg grid` page, the band at the lens edge where the grid lines bend (pt).
5. Merge the seed (`native_rows.json`) and these into `docs/qa/vk550/native_reference.json`, with `"source"` naming the date, simulator, runtime and method. Add §4 "Measured in Task 1" to `spike.md` with the new numbers.
6. Delete the simulator (`xcrun simctl delete <udid>`).

- [ ] **Step 4: Run the test to verify it passes**

Run: `fvm dart test tool/test/segment_reference_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
fvm dart format tool/test/segment_reference_test.dart
bash .githooks/pre-commit
git add docs/qa/vk550/native_reference.json docs/qa/vk550/spike.md tool/test/segment_reference_test.dart
git commit -m "docs(docs): native segmented control reference fixture (VK-550)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

If a Task 1 measurement contradicts a spec "(assumption)" (bezel, magnification, RTL, tap on the selected segment), update the spec row in the same commit and say so in the task report.

---

### Task 2: Generalise the lens engine: `LensTrack` and `LensProfile` (pure refactor)

**Files:**
- Create: `liquid_shell/lib/src/chrome/lens_track.dart`, `liquid_shell/lib/src/chrome/lens_profile.dart`
- Modify: `liquid_shell/lib/src/chrome/lens_motion.dart`, `liquid_shell/lib/src/chrome/tab_geometry.dart`
- Test: `liquid_shell/test/unit/lens_profile_test.dart` (new); `test/unit/lens_motion_test.dart` and every tab widget test unchanged

**Interfaces:**
- Consumes: `TabSprings`, `TabBarGeometry`, `LensMotion` as they are at `1c1eeb9`.
- Produces:

```dart
// lens_track.dart
/// The slots a lens moves over (spec VK-550 §8.1): a tab bar's slots or a
/// segmented control's thumbs. Track-local coordinates.
abstract interface class LensTrack {
  /// Rest lens rects, in index order (mirrored in RTL).
  List<Rect> get slots;
  double centreOf(int slot);
  int slotNearest(double x);
  /// [x] clamped to [first slot centre, last slot centre].
  double clampCentre(double x);
  /// The rest lens size at lens centre [x].
  Size restLensAt(double x);
  /// A tap flight's size factor (VK-503's iPad top bar), null elsewhere.
  Size? get tapInflation;
}

// lens_profile.dart
sealed class LensEnvelope { const LensEnvelope(); }
/// VK-503's tab envelope: LensMotion's existing targets, reading TabSprings.
final class TabEnvelope extends LensEnvelope { const TabEnvelope(); }
/// VK-550's segment envelope (Task 4 fills it).
final class SegmentEnvelope extends LensEnvelope { ... }

final class LensProfile {
  const LensProfile({
    required this.tap, required this.dragFollow, required this.snap,
    required this.flickLand, required this.reduced, required this.engageIn,
    required this.engageOut, required this.effectIn, required this.effectOut,
    required this.tapDelay, required this.flickVelocity, required this.flickHold,
    required this.releaseHold, required this.ghostFade, required this.envelope,
    this.programmatic,
  });
  final SpringDescription tap, dragFollow, snap, flickLand, reduced,
      engageIn, engageOut, effectIn, effectOut;
  final double tapDelay, flickVelocity, flickHold, releaseHold, ghostFade;
  /// A programmatic change slides on it; null jumps (VK-503 Q12).
  final SpringDescription? programmatic;
  final LensEnvelope envelope;

  /// Exactly TabSprings (spec VK-503 §8.1).
  static final LensProfile tab = LensProfile(
    tap: TabSprings.tap, dragFollow: TabSprings.dragFollow, snap: TabSprings.snap,
    flickLand: TabSprings.flickLand, reduced: TabSprings.reduced,
    engageIn: TabSprings.engageIn, engageOut: TabSprings.engageOut,
    effectIn: TabSprings.effectIn, effectOut: TabSprings.effectOut,
    tapDelay: TabSprings.tapDelay, flickVelocity: TabSprings.flickVelocity,
    flickHold: TabSprings.flickHold, releaseHold: TabSprings.releaseHold,
    ghostFade: TabSprings.ghostFade, envelope: const TabEnvelope(),
  );
}

// lens_motion.dart
LensMotion({required LensTrack geometry, required int? selected,
            LensProfile? profile, bool reduceMotion = false}); // profile ?? LensProfile.tab
LensTrack get geometry; set geometry(LensTrack value);
LensProfile get profile;

// tab_geometry.dart
class TabBarGeometry implements LensTrack {
  @override
  Size? get tapInflation => form == TabBarForm.top
      ? const Size(TabSprings.topTapWidth, TabSprings.topTapHeight)
      : null;
  // centreOf, slotNearest, clampCentre, restLensAt, slots: unchanged (+ @override)
}
```

`LensMotion` replaces every `TabSprings.<spring or common constant>` with `profile.<same name>`, keeps the tab-only constants (`pressWidthFactor`, `liftUntil`, `stretchFor`, the glow, pop and bulge values) behind `profile.envelope is TabEnvelope` in the existing `_setTargets` (renamed `_tabTargets`), and reads `geometry.tapInflation` where it tested `_geometry.form == TabBarForm.top`. `show()` uses `profile.programmatic` when non-null (retarget x on it, `phase = settling`), else jumps as today.

- [ ] **Step 1: Record the baseline**

Run: `cd liquid_shell && fvm flutter test test/unit/lens_motion_test.dart test/widget/tab_gesture_test.dart test/widget/glass_tab_bar_test.dart test/widget/tab_effects_test.dart test/widget/tab_trace_test.dart test/widget/lens_layer_test.dart test/widget/minimize_test.dart test/widget/search_morph_test.dart`
Expected: PASS. Note the test count.

- [ ] **Step 2: Write the failing test**

`liquid_shell/test/unit/lens_profile_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/chrome/lens_track.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

void main() {
  test('LensProfile.tab is exactly TabSprings (spec VK-550 §4, R1)', () {
    final p = LensProfile.tab;
    expect(p.tap, same(TabSprings.tap));
    expect(p.dragFollow, same(TabSprings.dragFollow));
    expect(p.snap, same(TabSprings.snap));
    expect(p.flickLand, same(TabSprings.flickLand));
    expect(p.reduced, same(TabSprings.reduced));
    expect(p.engageIn, same(TabSprings.engageIn));
    expect(p.engageOut, same(TabSprings.engageOut));
    expect(p.effectIn, same(TabSprings.effectIn));
    expect(p.effectOut, same(TabSprings.effectOut));
    expect(p.tapDelay, TabSprings.tapDelay);
    expect(p.flickVelocity, TabSprings.flickVelocity);
    expect(p.flickHold, TabSprings.flickHold);
    expect(p.releaseHold, TabSprings.releaseHold);
    expect(p.ghostFade, TabSprings.ghostFade);
    expect(p.programmatic, isNull, reason: 'tabs jump (VK-503 Q12)');
    expect(p.envelope, isA<TabEnvelope>());
  });

  test('TabBarGeometry is a LensTrack; only the top form inflates taps', () {
    LensTrack compact = compactTabGeometry(
      count: 3, maxWidth: 360, trailing: false, direction: TextDirection.ltr,
    );
    expect(compact.tapInflation, isNull);
    final top = topTabGeometry(
      labelWidths: const [40, 60, 50], iconOnly: const [false, false, false],
      maxWidth: 800, trailing: false, direction: TextDirection.ltr,
    );
    expect(top.tapInflation, const Size(1.34, 1.375));
  });

  test('LensMotion defaults to the tab profile', () {
    final m = LensMotion(
      geometry: compactTabGeometry(
        count: 3, maxWidth: 360, trailing: false,
        direction: TextDirection.ltr,
      ),
      selected: 0,
    );
    expect(m.profile, same(LensProfile.tab));
  });
}
```


- [ ] **Step 3: Run the test to verify it fails**

Run: `cd liquid_shell && fvm flutter test test/unit/lens_profile_test.dart`
Expected: FAIL to compile: `lens_profile.dart` / `lens_track.dart` not found.

- [ ] **Step 4: Implement** the two files and the `LensMotion` / `TabBarGeometry` changes above. Do not change one number.

- [ ] **Step 5: Run the new test and the whole baseline**

Run: `cd liquid_shell && fvm flutter test test/unit/lens_profile_test.dart` → PASS (3).
Run: the Step 1 command → PASS, the same count.
Run: `make tab-traces > /tmp/claude-…/vk550-t2-tab-traces.txt; diff <(grep -v '^▸' baseline-tab-traces.txt) <(grep -v '^▸' vk550-t2-tab-traces.txt)` → no row's value changes by more than the trace's own run-to-run noise (± 1 frame on timings); every row that passed still passes.

- [ ] **Step 6: Commit**

```bash
fvm dart format liquid_shell/lib/src/chrome liquid_shell/test/unit/lens_profile_test.dart
bash .githooks/pre-commit
git add liquid_shell/lib/src/chrome/lens_track.dart liquid_shell/lib/src/chrome/lens_profile.dart liquid_shell/lib/src/chrome/lens_motion.dart liquid_shell/lib/src/chrome/tab_geometry.dart liquid_shell/test/unit/lens_profile_test.dart
git commit -m "refactor(shell): the lens engine takes a track and a profile (VK-550)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Segment geometry (pure)

**Files:**
- Create: `liquid_shell/lib/src/segmented/segment_geometry.dart`
- Test: `liquid_shell/test/unit/segment_geometry_test.dart`

**Interfaces:**
- Consumes: `LensTrack` (Task 2).
- Produces:

```dart
abstract final class SegmentMetrics {
  static const double trackHeight = 32;   // spike §2
  static const double box = 44;           // owner rule, Q-C
  static const double thumbInset = 2;     // spike §2
  static const double labelPadding = 9;   // intrinsic: label + 18 (spike §2)
  static const double minSegment = 44;    // Q-C (native 32)
  static const double labelBoxOffset = 16.33; // 32 − 15.67
  static const Size pressedGrow = Size(24, 16); // spike §3
  static const double maxTextScale = 2;   // Q-D
}

@immutable
class SegmentGeometry implements LensTrack {
  const SegmentGeometry({required this.size, required this.track,
      required this.segments, required this.slots, required this.labels});
  final Size size;            // the box: (W, max(44, H))
  final Rect track;           // W × H, vertically centred
  final List<Rect> segments;  // index order, mirrored in RTL
  @override final List<Rect> slots; // rest thumbs = segments deflated by 2
  final List<Rect> labels;    // label boxes
  /// The segment whose hit area holds [p] (full box height), or null.
  int? segmentAt(Offset p);
  // LensTrack: centreOf, slotNearest, clampCentre, restLensAt (thumb size), tapInflation => null
}

SegmentGeometry segmentGeometry({
  required int count,
  required double maxWidth,
  required double lineHeight,          // the scaled label line height (15.67 at 1×)
  required TextDirection direction,
  List<double>? mediumLabelWidths,     // non-null: intrinsic width (expand: false)
});
```

Rules (spec §5): `H = max(32, lineHeight + 16.33)`; box height `max(44, H)`; `W = maxWidth` (expand) or `n · max(44, ceil(maxMedium) + 18)`; segment `i` at `x = i·W/n` (LTR) or `W − (i+1)·W/n` (RTL); thumb = segment deflated by 2; label box centred, `lineHeight` tall, width `W/n − 18`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

const double line = 15.67;

void main() {
  SegmentGeometry full(int n, {TextDirection d = TextDirection.ltr}) =>
      segmentGeometry(count: n, maxWidth: 370, lineHeight: line, direction: d);

  test('3 segments at 370: native thumbs within ±1 (spike §2)', () {
    final g = full(3);
    expect(g.size, const Size(370, 44));
    expect(g.track, const Rect.fromLTWH(0, 6, 370, 32));
    const native = [
      Rect.fromLTWH(2, 8, 119, 28),
      Rect.fromLTWH(125, 8, 119, 28),
      Rect.fromLTWH(248, 8, 120, 28),
    ];
    for (var i = 0; i < 3; i++) {
      expect(g.slots[i].left, closeTo(native[i].left, 1));
      expect(g.slots[i].width, closeTo(native[i].width, 1));
      expect(g.slots[i].top, 8);
      expect(g.slots[i].height, 28);
    }
  });

  test('2 and 5 segments: thumbs 181 and 70 wide', () {
    expect(full(2).slots.first.width, closeTo(181, 1));
    expect(full(5).slots.first.width, closeTo(70, 1));
  });

  test('intrinsic: widest Medium label + 18, segments ≥ 44 (Q-C)', () {
    SegmentGeometry intrinsic(List<double> w) => segmentGeometry(
      count: w.length, maxWidth: double.infinity, lineHeight: line,
      direction: TextDirection.ltr, mediumLabelWidths: w,
    );
    expect(intrinsic(const [16, 39, 40.67]).size.width, 177);
    expect(intrinsic(const [16, 97.7]).size.width, closeTo(234, 2));
    expect(intrinsic(const [9.3, 8.7, 9]).size.width, 132);
  });

  test('RTL mirrors: segment 0 is at the right', () {
    final g = full(3, d: TextDirection.rtl);
    expect(g.segments[0].right, 370);
    expect(g.segments[2].left, 0);
  });

  test('text scale 2: the track grows, the box follows', () {
    final g = segmentGeometry(
      count: 3, maxWidth: 370, lineHeight: line * 2,
      direction: TextDirection.ltr,
    );
    expect(g.track.height, closeTo(line * 2 + 16.33, 0.01));
    expect(g.size.height, g.track.height);
    expect(g.slots.first.height, g.track.height - 4);
  });

  test('LensTrack: nearest, clamp, hit area over the whole box', () {
    final g = full(3);
    expect(g.slotNearest(10), 0);
    expect(g.slotNearest(200), 1);
    expect(g.clampCentre(0), g.slots.first.center.dx);
    expect(g.clampCentre(999), g.slots.last.center.dx);
    expect(g.segmentAt(const Offset(200, 1)), 1);
    expect(g.segmentAt(const Offset(200, 43)), 1);
    expect(g.segmentAt(const Offset(200, 45)), isNull);
    expect(g.restLensAt(200), const Size(119.33333333333334, 28));
    expect(g.tapInflation, isNull);
  });
}
```

- [ ] **Step 2: Run** `cd liquid_shell && fvm flutter test test/unit/segment_geometry_test.dart` → FAIL to compile (no file).
- [ ] **Step 3: Implement** `segment_geometry.dart` to the rules above (pure Dart: `dart:ui` and `package:flutter/foundation.dart` only).
- [ ] **Step 4: Run** the test → PASS (6).
- [ ] **Step 5: Commit** `feat(shell): segmented control geometry measured from native (VK-550)` (format, pre-commit, add both files).

---

### Task 4: The segment envelope, fitted to the native rows

**Files:**
- Modify: `liquid_shell/lib/src/chrome/lens_profile.dart` (`SegmentEnvelope`, `LensProfile.segment`), `liquid_shell/lib/src/chrome/lens_motion.dart` (`_segmentTargets`, effects off)
- Create: `liquid_shell/test/helpers/native_rows.dart`, `liquid_shell/test/unit/segment_motion_test.dart`
- Modify: `liquid_shell/test/unit/lens_profile_test.dart`

**Interfaces:**
- Consumes: Task 1's fixture, Tasks 2–3.
- Produces:

```dart
final class SegmentEnvelope extends LensEnvelope {
  const SegmentEnvelope({
    required this.pressGrow,       // Size(24, 16)
    required this.pressSize,       // fittedSpring(1.0, 0.25)
    required this.pressDelay,      // 0.024
    required this.releaseSize,     // fittedSpring(1.0, 0.24)
    required this.releaseDelay,    // 0.016
    required this.commitDelay,     // 0.008 (tap x after the commit)
    required this.engageHold,      // engage held after a tap's commit (≈ 0.30)
    required this.liftNear,        // Size(b1, a1): one segment, w and h gains
    required this.liftFar,         // Size(b2, a2): two segments or more
    required this.liftUntil,       // t1 / t2 as a pair: (near, far)
    required this.wobble,          // size spring after the landing
    required this.squashKnee,      // v0, pt/s
    required this.squashGain,      // Size(k', k) per pt/s
    required this.squashMax,       // Size(0.88, 1.13)
    required this.magnify,         // w500 copy scale at full engage (Task 1)
  });
}

static final LensProfile segment = LensProfile(
  tap: fittedSpring(0.87, 0.41),           // spike §3
  dragFollow: TabSprings.dragFollow,       // spike: lag within −5 %
  snap: fittedSpring(0.87, 0.41),          // (assumption) until Task 1 fits the release
  flickLand: TabSprings.flickLand,         // until Task 1's flickLanding says otherwise
  reduced: TabSprings.reduced,
  engageIn: TabSprings.engageIn, engageOut: TabSprings.engageOut,
  effectIn: TabSprings.effectIn, effectOut: TabSprings.effectOut,
  tapDelay: 0, flickVelocity: TabSprings.flickVelocity,
  flickHold: TabSprings.flickHold, releaseHold: TabSprings.releaseHold,
  ghostFade: TabSprings.ghostFade,
  programmatic: fittedSpring(0.82, 0.41),  // spike §3
  envelope: SegmentEnvelope(...),          // fitted in this task
);
```

In `LensMotion`, `profile.envelope is SegmentEnvelope` selects `_segmentTargets(since)` (spec §8.3–§8.4): a press does not move x; size and engage answer after `pressDelay`; a tap's x retargets `commitDelay` after the up on `profile.tap`; the flight size targets use `liftNear` / `liftFar` until `liftUntil`, then hand over to `wobble`; while dragging the size targets add the speed squash; glow, pill scale, highlight and pop stay at 0 / 1 (`LensFrame` defaults). The tab path (`_tabTargets`) is untouched.

Starting values for the fit (from the spike rows, not final): `liftNear = Size(0.14, 0.35)`, `liftFar = Size(0.0, 0.79)`, `liftUntil = (0.30, 0.32)`, `wobble = fittedSpring(0.45, 0.40)`, `squashKnee = 300`, `squashGain = Size(0.00024, 0.00026)`, `engageHold = 0.30`, `magnify = 1.0` (Task 1 may change it).

- [ ] **Step 1: Write the fixture reader**

`liquid_shell/test/helpers/native_rows.dart`:

```dart
import 'dart:convert';
import 'dart:io';

/// docs/qa/vk550/native_reference.json (spec VK-550 §14.5), read from the
/// package directory.
Map<String, dynamic> segmentReference() => jsonDecode(
  File('../docs/qa/vk550/native_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// One native row: t, lens centre x, w, h, engage.
typedef NativeRow = ({double t, double x, double w, double h, double engage});

List<NativeRow> rowsOf(Map<String, dynamic> ref, String key,
    {String field = 'rows'}) => [
  for (final r in ((ref[key] as Map)[field] as List).cast<List<dynamic>>())
    (
      t: (r[0] as num).toDouble(),
      x: (r[1] as num).toDouble(),
      w: (r[2] as num).toDouble(),
      h: (r[3] as num).toDouble(),
      engage: (r[4] as num).toDouble(),
    ),
];
```

- [ ] **Step 2: Write the failing tests**

`liquid_shell/test/unit/segment_motion_test.dart` (each case drives a `LensMotion(geometry: segmentGeometry(count: 3, maxWidth: 370, lineHeight: 15.67, direction: ltr) shifted to track-local, profile: LensProfile.segment)` at `advance(1/60)`; x in the fixture is control-local and the thumbs' `top` is 8 in the 44 box, so compare x, w, h only):

```dart
// Pseudocode-free outline; write each as a `test(...)`:
//
// tap_1_2, tap_2_3, tap_3_1:
//   selected = from; m.down(centre of `to`); advance one frame; m.up(...);
//   sample at each fixture row's t (t from the up = the commit);
//   x within ±2 pt of the row for t ≤ 0.6; settle time (0.5 pt) within
//   ±10 % of the fixture's last-in-band time;
//   one segment: max h within ±10 % of the fixture's max h; min w after the
//   landing within ±10 %; overshoot within ±1 pt;
//   two segments (tap_3_1): max h within ±10 %, overshoot within ±1 pt.
// press: down and hold 0.3 s; w and h within ±2 pt of each row; engage 1 by
//   0.067 s; frame.glowOpacity == 0, frame.pillScale == 1, popScale == 1.
// release: after 1 s held, up in place; w, h within ±2 pt, engage within
//   ±0.12 of each release row.
// drag lag: down at 61.5 (segment 0), move at 82.2 pt/s to 308; mean
//   (finger − lens x) over the steady part within ±10 % of 6.77;
//   takeCrossings() totals 2.
// slow_drag release: the release rows (x ±2, w/h ±2) after a drag that
//   ends at 308.
// flick: the fixture's flick (release_at 0.465, finger 308 → 61.5): commits
//   segment 0; overshoot within ±1 pt of flickLanding.overshoot.
// programmatic_2seg: two segments; m.show(1) while at rest on 0: x within
//   ±2 pt of each row; engage stays 0; w, h stay rest.
// reduce motion: tap 0 → 2: no h above rest, ghost fades over 0.15 s.
// disabled: (Task 8 passes the disabled set) not tested here.
```

Write the real assertions with `rowsOf(segmentReference(), 'tap_1_2')` etc. Pin the profile in `lens_profile_test.dart`: `LensProfile.segment.tap` stiffness `(2π/0.41)²` ±1e-9, ratio 0.87; `programmatic` (0.82, 0.41); `dragFollow` same as `TabSprings.dragFollow`; envelope `pressGrow == Size(24, 16)`.

- [ ] **Step 3: Run** `cd liquid_shell && fvm flutter test test/unit/segment_motion_test.dart test/unit/lens_profile_test.dart` → FAIL (`LensProfile.segment` undefined).

- [ ] **Step 4: Implement, then fit.** Add `SegmentEnvelope`, `LensProfile.segment` and `_segmentTargets`. Fit `liftNear`, `liftFar`, `liftUntil`, `wobble`, `engageHold` and the squash constants against the fixture with a throwaway grid-search script in the scratchpad (not committed) that runs `LensMotion` and scores the rows of `tap_1_2`, `tap_2_3`, `tap_3_1` and `flick` (sum of squared w and h errors). Keep the springs measured by the spike as they are; only the envelope knobs are free (spec §8.4). Document each fitted constant with its source row in a doc comment, as `TabSprings` does.

- [ ] **Step 5: Run** the two files → PASS. Run `fvm flutter test test/unit/lens_motion_test.dart` → PASS (tab path unchanged).

- [ ] **Step 6: Commit** `feat(shell): the segment lens profile, fitted to native traces (VK-550)`.

---

### Task 5: Theme tokens

**Files:**
- Modify: `liquid_shell/lib/src/glass/glass_theme.dart`
- Test: `liquid_shell/test/unit/glass_theme_test.dart`

**Interfaces:**
- Produces: `LiquidGlassTheme.segmentTrack` (`Color`), `segmentThumb` (`Color`), `segmentLabelStyle` (`TextStyle`), in the constructor, `fromColorScheme`, `copyWith`, `lerp`, `==`, `hashCode`, `debugFillProperties` (as `selectionFill`).
  - Light: `Color(0x1F767680)`, `Color(0xFFFFFFFF)`, `TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF000000), height: 15.67 / 13)`.
  - Dark: `Color(0x3D767680)`, `Color(0x4DEBEBF5)`, the same style with `Color(0xFFFFFFFF)`.

- [ ] **Step 1: Write the failing test** (append):

```dart
  group('segment tokens (spec VK-550 §6)', () {
    test('light defaults', () {
      final t = LiquidGlassTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
      );
      expect(t.segmentTrack, const Color(0x1F767680));
      expect(t.segmentThumb, const Color(0xFFFFFFFF));
      expect(t.segmentLabelStyle.fontSize, 13);
      expect(t.segmentLabelStyle.fontWeight, FontWeight.w400);
      expect(t.segmentLabelStyle.color, const Color(0xFF000000));
    });
    test('dark defaults', () {
      final t = LiquidGlassTheme.fromColorScheme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D5AFE), brightness: Brightness.dark,
        ),
      );
      expect(t.segmentTrack, const Color(0x3D767680));
      expect(t.segmentThumb, const Color(0x4DEBEBF5));
      expect(t.segmentLabelStyle.color, const Color(0xFFFFFFFF));
    });
    test('copyWith, lerp and == carry them', () {
      final a = LiquidGlassTheme.fromColorScheme(const ColorScheme.light());
      final b = a.copyWith(segmentTrack: const Color(0xFF00FF00));
      expect(b.segmentTrack, const Color(0xFF00FF00));
      expect(b == a, isFalse);
      expect(a.lerp(b, 1).segmentTrack, b.segmentTrack);
    });
  });
```


- [ ] **Step 2: Run** `fvm flutter test test/unit/glass_theme_test.dart` → FAIL (no getter).
- [ ] **Step 3: Implement.** Check the composite against the spike: `0x1F` (0.12) of #767680 over white gives 238/238/239; `0x3D` (0.24) over black gives 28/28/31; `0x4D` (0.30) of #EBEBF5 over that gives 90/90/95.
- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(glass): segmented control theme tokens (VK-550)`.

---

### Task 6: Shared lens ticker and clip (pure refactor of `GlassTabBar`)

**Files:**
- Create: `liquid_shell/lib/src/chrome/lens_ticker.dart`, `liquid_shell/lib/src/chrome/lens_clip.dart`
- Modify: `liquid_shell/lib/src/chrome/glass_tab_bar.dart`
- Test: `liquid_shell/test/widget/lens_ticker_test.dart` (new); every tab widget test unchanged

**Interfaces:**

```dart
// lens_clip.dart — moved from glass_tab_bar.dart's _LensClip, unchanged.
class LensClip extends CustomClipper<Path> {
  const LensClip(this.lens, {required this.inside});
  final Rect lens; final bool inside;
}

// lens_ticker.dart — GlassTabBar._onTick's motion part.
class LensTicker {
  LensTicker({
    required TickerProvider vsync,
    required LensMotion Function() motion,
    required int? Function() selected,      // the app's current selection, as a slot
    required VoidCallback onFrame,          // setState
    bool Function(double dt)? extra,        // the tab bar's minimize motion; true while it moves
    void Function(Duration elapsed, LensFrame frame)? trace,
  });
  /// Starts the ticker if it is not running (the old _kick).
  void kick();
  void dispose();
}
```

Each tick: `dt` from wall time capped at `SpringValue.maxAdvance`; `extra?.call(dt)`; `motion.advance(dt)`; one `HapticFeedback.selectionClick()` per `takeCrossings()` entry; when the motion stops: `returnTo(selected())` if the pending commit was not adopted, else `accept()`; stop when nothing moves; `trace`; `onFrame()`. `GlassTabBar` builds one with `extra: _minimize.advance` and its `debugTabTrace` sample in `trace`.

- [ ] **Step 1: Baseline.** Run the Task 2 Step 1 command → PASS (record the count).
- [ ] **Step 2: Write the failing test** `lens_ticker_test.dart`: a tiny `StatefulWidget` with `SingleTickerProviderStateMixin` owning a `LensTicker` over a 3-slot `compactTabGeometry`; (1) after `down` at slot 0, `move` across two slots with `pump(16ms)` steps and `up`, `SystemChannels.platform` records exactly two `HapticFeedback.vibrate` calls of type `HapticFeedbackType.selectionClick`; (2) after settling, `tester.binding.hasScheduledFrame` is false; (3) with `selected` returning the old slot, the lens returns (its `committed` equals the old slot after settle).
- [ ] **Step 3: Run** → FAIL to compile.
- [ ] **Step 4: Implement** both files; replace `_onTick`, `_kick` and `_LensClip` in `glass_tab_bar.dart` with them (keep `kTabNormalKey` / `kTabTintedKey` on the `ClipPath`s).
- [ ] **Step 5: Run** the new test and the baseline → PASS, same count; `make tab-traces` unchanged against the Task 2 file.
- [ ] **Step 6: Commit** `refactor(shell): one lens ticker and clip for every lens widget (VK-550)`.

---

### Task 7: `LiquidSegmentedControl` at rest

**Files:**
- Create: `liquid_shell/lib/src/segmented/segmented_control.dart`
- Modify: `liquid_shell/lib/src/glass/liquid_lens.dart` (optional `bezel`), `liquid_shell/lib/liquid_shell.dart`, `liquid_shell/test/unit/public_api_test.dart`
- Test: `liquid_shell/test/widget/segmented_control_test.dart`

**Interfaces:**

```dart
/// One segment of a [LiquidSegmentedControl].
@immutable
class LiquidSegment {
  const LiquidSegment({required this.label, this.enabled = true, this.semanticLabel});
  final String label;
  final bool enabled;
  final String? semanticLabel;
}

/// A segmented control drawn after iOS 26's UISegmentedControl, with a
/// liquid lens for its selection (spec VK-550). Controlled: rebuild it with
/// the index [onChanged] reports.
class LiquidSegmentedControl extends StatefulWidget {
  const LiquidSegmentedControl({
    required this.segments,       // ≥ 2 (assert)
    required this.selectedIndex,  // null: none; else 0 ≤ i < segments.length (assert)
    required this.onChanged,      // null: the whole control is disabled (opacity 0.5)
    this.expand = true,           // false: intrinsic width (spec §5)
    this.semanticLabel,
    super.key,
  });
}

// liquid_lens.dart
const LiquidLens({required this.refraction, this.engage = 1, this.restFill,
                  this.bezel = kLensBezel, super.key}); // bezel feeds LiquidOpticsParams.bezel
```

Layout (spec §5): `LayoutBuilder` → `segmentGeometry(count, maxWidth: expand ? constraints.maxWidth : ∞, lineHeight: the scaled 13 pt line (text scale capped at 2), direction, mediumLabelWidths: expand ? null : the w500 `TextPainter` widths)`; the box is `g.size`.

> **Amended in Task 7 review (coordinator):** not a bare `LayoutBuilder`, which throws under `IntrinsicWidth` / `IntrinsicHeight` (an `AlertDialog`'s content, a `Row` with intrinsic children) — and `expand: false` means "intrinsic width". The control uses `SizedLayoutBuilder` (`lib/src/chrome/sized_layout_builder.dart`): a `LayoutBuilder` under a proxy render object that answers intrinsic sizes and dry layout from the same pure `segmentGeometry` size, the approach `fit_label.dart` takes for the tab label. `expand: false` in a parent narrower than the labels falls back to the fill geometry (segments shrink to fit), so no segment is ever cut off.

Paint stack, in the box (rest only in this task; the lens comes in Task 8):

1. the track: `DecoratedBox(color: theme.segmentTrack, borderRadius: capsule)` at `g.track`;
2. the rest thumb: a capsule `theme.segmentThumb` at `g.slots[selectedIndex]` (nothing when `selectedIndex` is null);
3. the normal row: every label at `g.labels[i]` in `segmentLabelStyle` (w400), clipped by `LensClip(thumb, inside: false)`;
4. the selected row: every label in w500, clipped by `LensClip(thumb, inside: true)`;
5. one `Semantics` node per segment (spec §8.5) and a `GestureDetector`-free hit area (Task 8 adds `LensGestureRecognizer`); for now a semantics `onTap` calls `onChanged`.
6. disabled: `Opacity(0.5)` over the whole control when `onChanged == null`; a disabled segment's labels at 0.5.

Keys for tests: `kSegmentTrackKey`, `kSegmentThumbKey`, `kSegmentNormalKey`, `kSegmentSelectedKey` (`@visibleForTesting` in `src/`).

- [ ] **Step 1: Write the failing test** `segmented_control_test.dart`:

```dart
// Each a testWidgets inside MaterialApp(home: Center(child: SizedBox(width: 370, child: ...)))
// with the tier forced to solid as test/widget/glass_tab_bar_test.dart does (no shader in widget tests):
// 1. 'geometry: box 370 × 44, track and thumb rects equal segmentGeometry (±0.01)'
// 2. 'labels: unselected w400, selected copy w500 clipped to the thumb'
//    (find the two ClipPaths by key; their clippers' lens == thumb rect)
// 3. 'colours: track and thumb from LiquidGlassTheme, light and dark'
// 4. 'semantics: inMutuallyExclusiveGroup, selected on the selected segment,
//     button, enabled flags, labels' (tester.getSemantics + matchesSemantics)
// 5. 'tap targets: meetsGuideline(iOSTapTargetGuideline)'
// 6. 'disabled: onChanged null → Opacity 0.5 and a semantics tap calls nothing'
// 7. 'RTL: segment 0 at the right; semantics order visual'
// 8. 'text scale 2: track 2 × 15.67 + 16.33 tall; labels ellipsize'
// 9. 'expand: false sizes to the labels: All | Songs | Places = 177 ± 2'
// 10. 'no InkWell, no Material ink anywhere'
// 11. 'asserts: fewer than 2 segments; selectedIndex out of range'
```

Write each with real finders and expectations; take expected rects from `segmentGeometry` itself (the geometry is pinned to native in Task 3).

Add to `public_api_test.dart`:

```dart
  test('segmented_control.dart exports only the control and its segment', () {
    expect(
      _exports().where((e) => e.contains('segmented_control.dart')),
      ["export 'src/segmented/segmented_control.dart' show LiquidSegment, LiquidSegmentedControl"],
    );
  });
  test('the lens engine stays internal', () {
    for (final f in ['lens_track.dart', 'lens_profile.dart', 'lens_ticker.dart',
        'lens_clip.dart', 'segment_geometry.dart']) {
      expect(_exports().where((e) => e.contains(f)), isEmpty, reason: f);
    }
  });
```

- [ ] **Step 2: Run** `fvm flutter test test/widget/segmented_control_test.dart test/unit/public_api_test.dart` → FAIL.
- [ ] **Step 3: Implement**; export it from the barrel with `show LiquidSegment, LiquidSegmentedControl`.
- [ ] **Step 4: Run** → PASS. Also `make provenance` → green (no filter outside `src/glass/`).
- [ ] **Step 5: Commit** `feat(shell): LiquidSegmentedControl at rest (VK-550)`.

---

### Task 8: Gestures, motion and the lens on screen

**Files:**
- Modify: `liquid_shell/lib/src/segmented/segmented_control.dart`
- Test: `liquid_shell/test/widget/segment_gesture_test.dart`, `liquid_shell/test/widget/segment_lens_test.dart`

**Interfaces:**
- Consumes: `LensMotion` (profile `segment`), `LensTicker`, `LensGestureRecognizer`, `LiquidLens(bezel: 9)`, `LargeContentViewer`.
- Produces, in `src/` (not exported):

```dart
@visibleForTesting
void Function(Map<String, double> sample)? debugSegmentTrace; // t, x (global lens centre), y, w, h, engage
@visibleForTesting
double? debugSegmentLensPress; // goldens: the lens pressed and shifted by this many pt
```

Behaviour (spec §8): `RawGestureDetector` with `LensGestureRecognizer(eager: !ax && no vertical Scrollable)` over the box; `down` → `motion.down`; `move` → `motion.move`; `up` → if the segment under the finger is disabled and it was a tap, `motion.cancel()`; else `motion.up(...)` and `onChanged(slot)` when the committed slot differs from `selectedIndex` (a tap on the selected segment calls nothing, unless Task 1 found native sends `valueChanged`); drags never commit a disabled segment (pick the nearest enabled). `didUpdateWidget`: a new `selectedIndex` with no pending commit → `motion.show(i)` (slides on `programmatic`, jumps under reduce motion). The paint stack of Task 7 gains, between the thumb and the selected row, `LiquidLens(refraction: f.refraction, engage: f.engage, restFill: theme.segmentThumb, bezel: 9)` at `f.lens` while `f.engage > 0.001`; the selected row's clip and its `magnify` follow `f.lens` (as the tab bar's tinted copy). The control opens its own `BackdropGroup` with a `BackdropKey` kept for its life (as `GlassTabBar`'s `_backdropKey`). At AX sizes a long press shows `LargeContentViewer` with the label.

- [ ] **Step 1: Write the failing tests.**
  - `segment_gesture_test.dart`:
    - 'a tap commits on up, not on down' (`onChanged` count 0 after `startGesture`, 1 after `up`);
    - 'a drag across two segments commits the segment nearest the lens on release, with one selectionClick per crossing and none on a tap' (record `SystemChannels.platform` `HapticFeedback.vibrate` calls);
    - 'a cancel commits nothing';
    - 'a refused change returns to the app's index' (the parent ignores `onChanged`; after `pumpAndSettle` the thumb is back);
    - 'a programmatic change slides: the thumb is between the segments 100 ms later, and onChanged is not called';
    - 'reduce motion: a tap dissolves (ghost), no lift';
    - 'a semantics tap commits';
    - 'a disabled segment is never committed by a tap or a drag';
    - 'the ticker stops at rest'.
  - `segment_lens_test.dart` (liquid override on, as `lens_layer_test.dart`):
    - '`LiquidLens` exists only while engaged, with bezel 9';
    - 'it shares the control's own BackdropGroup key';
    - 'frosted and solid tiers draw their lens variants';
    - 'debugSegmentTrace reports one sample per tick with the lens size'.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both → PASS; rerun `segmented_control_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(shell): the segmented control's liquid lens, drag and haptics (VK-550)`.

---

### Task 9: `LiquidSearch.scopes` and `LiquidSearchScopeBar` as a wrapper

**Files:**
- Modify: `liquid_shell/lib/src/search/search.dart`, `search_controller.dart`, `scope_bar.dart`, `liquid_shell/lib/src/shell/shell_scope.dart`, `liquid_shell/lib/src/shell/liquid_shell.dart`
- Test: `liquid_shell/test/widget/scope_bar_test.dart` (new), `liquid_shell/test/unit/search_test.dart`

**Interfaces:**

```dart
// search.dart
const LiquidSearch({required this.controller, this.placeholder, this.scopes,
                    this.onChanged, this.onSubmitted});
final List<String>? scopes; // null or ≥ 2 (assert)

// search_controller.dart
abstract interface class SearchDriver {
  void activate(); void deactivate(); void textSetByApp(String text);
  /// The app changed the scope (spec VK-550 §10.2).
  void scopeSetByApp(int index);
}
// LiquidSearchController.value setter: also calls _driver?.scopeSetByApp(next.scopeIndex)
// when the scope changed. applySearchEdit never calls it.

// shell_scope.dart
const LiquidShellScopeData({..., this.nativeSearchScopes = false, this.searchScopes});
/// Native chrome draws the search scopes (iOS 26+); LiquidSearchScopeBar builds nothing.
final bool nativeSearchScopes;
/// The shell's LiquidSearch.scopes.
final List<String>? searchScopes;

// scope_bar.dart
class LiquidSearchScopeBar extends StatelessWidget {
  const LiquidSearchScopeBar({required this.controller, this.scopes, super.key});
  final LiquidSearchController controller;
  final List<String>? scopes; // null: LiquidShellScope.maybeOf(context)?.searchScopes
}
```

`LiquidShell` fills `searchScopes` from `search?.scopes` and `nativeSearchScopes` with `false` in this task (Task 10 sets it). `ShellSearch.scopeSetByApp` is a no-op here (Task 10 sends it).

- [ ] **Step 1: Write the failing tests.**
  - `scope_bar_test.dart`: (1) Flutter mode builds a `LiquidSegmentedControl` with the titles and `selectedIndex == controller.scopeIndex`; a tap on "Songs" sets `controller.scopeIndex` to 1; (2) with `LiquidShellScope` data `nativeSearchScopes: true` it builds `SizedBox.shrink` (no `LiquidSegmentedControl`); (3) `scopes: null` inside a `LiquidShell(search: LiquidSearch(scopes: [...]))` reads the shell's; (4) explicit and shell scopes differing assert in debug.
  - `search_test.dart`: setting `scopeIndex` calls the attached driver's `scopeSetByApp` once with the index; the same index again calls nothing; `applySearchEdit` with a new scope calls nothing; `LiquidSearch(scopes: ['All'])` asserts.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; update `ShellSearch` (it implements `SearchDriver`) with an empty `scopeSetByApp`, and the test fakes that implement `SearchDriver`.
- [ ] **Step 4: Run** the two files, plus `test/widget/search_fallback_test.dart` and `test/unit/shell_search_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(shell): LiquidSearch.scopes; the scope bar wraps LiquidSegmentedControl (VK-550)`.

---

### Task 10: The native scope bar (platform interface, Pigeon, iOS, Swift, sync)

**Files:**
- Modify: `liquid_shell_platform_interface/lib/src/native_chrome.dart`, `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart` (+ their tests)
- Modify: `liquid_shell_ios/pigeons/native_shell.dart`; run `make pigeon` (both generated files); `liquid_shell_ios/lib/src/mapping.dart`, `liquid_shell_ios/lib/src/platform.dart` (+ tests)
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchBridge.swift`, `NativeTabsController.swift`, `NativeShellInstaller.swift`
- Modify: `liquid_shell/lib/src/native/native_host.dart` (`NativeChromeClaim.setSearchScope`), `liquid_shell/lib/src/native/native_layout.dart` (config `scopes`), `liquid_shell/lib/src/search/shell_search.dart`, `liquid_shell/lib/src/shell/liquid_shell.dart` (`nativeSearchScopes`)
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`, `liquid_shell/test/unit/shell_search_test.dart`, `liquid_shell/test/unit/native_layout_test.dart`, platform-interface and iOS Dart tests

**Interfaces:**

```dart
// platform interface
const LiquidNativeSearchConfig({this.placeholder, this.scopes}); // ==, hashCode, toString include scopes
final List<String>? scopes;
Future<void> setNativeSearchScope(int index) async {} // LiquidShellPlatform default: nothing
final class LiquidNativeSearchScopeChanged extends LiquidNativeEvent { const LiquidNativeSearchScopeChanged(this.index); final int index; }

// pigeon
class NativeSearchConfig { NativeSearchConfig({this.placeholder, this.scopes}); String? placeholder; List<String>? scopes; }
// @HostApi NativeShellHostApi:  void setSearchScope(int index);
// @FlutterApi NativeShellFlutterApi: void onSearchScopeChanged(int index);
// NativeDebugSnapshot gains: List<String> scopeTitles; bool scopeShown; int selectedScope;

// NativeChromeClaim
void setSearchScope(int index) { if (!isOwner) return; unawaited(LiquidShellPlatform.instance.setNativeSearchScope(index)); }
```

```swift
// SearchBridge
var onScope: (Int) -> Void = { _ in }
/// Dart's titles; nil or fewer than two hide the scope bar (spec VK-550 §10.1).
func setScopes(_ titles: [String]?)
/// Dart's index, clamped. Never reported back.
func setScope(_ index: Int)
// willPresentSearchController: if hasScopes { controller.searchBar.setShowsScope(true, animated: true) }
// willDismissSearchController (new): controller.searchBar.setShowsScope(false, animated: true)
// searchBar(_:selectedScopeButtonIndexDidChange:): guard canReport(), index != knownScope else return; knownScope = index; onScope(index)
// init: controller.scopeBarActivation = .manual
```

`NativeTabsController`: `applySearch` passes `new.search?.scopes` to `searchBridge.setScopes`; `setSearchScope(_:)` holds the index while another tab is selected (as `heldSearchText`); `searchBridge.onScope` → `events.onSearchScopeChanged`. `NativeShellInstaller`: the host method. `ShellSearch`: `onNativeEvent(LiquidNativeSearchScopeChanged(:index))` → if `selected` and `index != controller.scopeIndex`, `applySearchEdit(controller, value.copyWith(scopeIndex: index))`; `scopeSetByApp(i)` → `if (native && selected) claim()?.setSearchScope(i)`; `afterConfigSent` on entering natively also sends the scope. `LiquidShell`: `nativeSearchScopes = native chrome engaged && search?.scopes != null` (native chrome only engages on iOS 26+, so nothing else gates it).

- [ ] **Step 1: Write the failing tests.**
  - Platform interface: `LiquidNativeSearchConfig(scopes:)` equality and `toString`; the default `setNativeSearchScope` completes.
  - iOS Dart (`liquid_shell_ios/test`): `mapping` puts `scopes` into `NativeSearchConfig`; `setNativeSearchScope(2)` calls the host `setSearchScope(2)`; `onSearchScopeChanged(1)` emits `LiquidNativeSearchScopeChanged(1)`.
  - `shell_search_test.dart`: (a) native event 1 → controller 1 and the app's listener hears it once; (b) the same event again → nothing; (c) an event while the search tab is not selected → ignored; (d) `controller.scopeIndex = 2` while native and selected → one `setNativeSearchScope(2)` on the fake platform, and no event goes back; (e) entering the search tab natively sends the scope with the text; (f) a native event never causes a `setNativeSearchScope`.
  - `native_layout_test.dart`: the chrome config carries `scopes`.
  - XCTest in `RunnerTests.swift` (`SearchBridge` without a window, as the existing search tests): `setScopes(["All","Songs","Places"])` sets `scopeButtonTitles` and `.manual`; `willPresentSearchController` sets `showsScopeBar = true`, `willDismissSearchController` false; `setScopes(nil)` clears; `setScope(5)` clamps to 2; a delegate call with index 1 while `canReport` reports 1 once and a repeat reports nothing; `setScope(2)` then a delegate call with 2 reports nothing.
- [ ] **Step 2: Run** each → FAIL (`make ios-unit IOS_UNIT_DEVICE=<your vk550 iPad or iPhone 26.5 udid>` for XCTest).
- [ ] **Step 3: Implement**, `make pigeon`.
- [ ] **Step 4: Run** all of Step 1 → PASS; `make pigeon-check` → "✓ pigeon output matches its source".
- [ ] **Step 5: Commit** `feat(ios): the native search scope bar and its one-way bridge (VK-550)` (all the files above, the generated two included).

---

### Task 11: Native integration on iPhone and iPad

**Files:**
- Modify: `liquid_shell/example/integration_test/native_search_test.dart`, `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`
- Modify (only if Step 4 shows a lagging inset): `liquid_shell_ios/ios/.../NativeTabsController.swift` (re-read the resting top after `setShowsScope`)

**Interfaces:** the example's search case passes `scopes: kSearchScopes` to `LiquidSearch` (Task 12 does the example; do that one-line change here first if Task 12 has not run).

- [ ] **Step 1: Write the failing tests.**
  - `native_search_test.dart` (runs per device under `make integration-ios-native`): activate the search; the debug snapshot reports `scopeShown == true`, `scopeTitles == ['All','Songs','Places']`; `find.byType(LiquidSegmentedControl)` finds nothing; the page's first result row's top is below the scope bar (`snapshot` gains the scope bar's frame in Flutter coordinates, `NativeRect scopeFrame`); `controller.scopeIndex = 2` → after a frame `selectedScope == 2`; deactivate → `scopeShown == false`.
  - `SearchUITests.swift`: `testTheNativeScopeBar`: tap the field; `app.segmentedControls.firstMatch` exists (iPhone: its frame's minY < 120; iPad: below the field); tap "Songs" → the Flutter list shows only songs (`flutterRow(app, "<a song title from kSearchItems>")` exists, a place row does not); press "Songs" and drag to "Places" (`press(forDuration:thenDragTo:)`) → only places.
- [ ] **Step 2: Run** on your own simulators (`vk550 iPhone 17 Pro 26.5`, `vk550 iPad Air 11 26.5`, plus the iOS 27.0 pair for the UI test): `NATIVE_DEVICES="<udid iPad>=true;<udid iPhone>=true" make integration-ios-native` and `make ios-ui IOS_UNIT_DEVICE=<udid>` → FAIL before the example passes scopes / before Task 10 is wired.
- [ ] **Step 3: Implement** what fails (the example's `scopes`, the inset re-read if the content top is above the scope bar's bottom).
- [ ] **Step 4: Run** → PASS on iPhone and iPad, 26.5 and 27.0 (UI test). Keep the screenshots `search_<run>_scopes.png`.
- [ ] **Step 5: Delete** your simulators. **Commit** `test(example): native scope bar on iPhone and iPad (VK-550)`.

---

### Task 12: Example updates

**Files:**
- Modify: `liquid_shell/example/lib/cases/search.dart` (`LiquidSearch(scopes: kSearchScopes)`; `LiquidSearchScopeBar(controller: controller)` without `scopes`), `liquid_shell/example/lib/cases/cases.dart`, `liquid_shell/example/lib/main.dart` (demos `segments`, `segments-liquid`)
- Create: `liquid_shell/example/lib/cases/segments.dart` (`#docregion segments`), `liquid_shell/example/ios/Runner/SegmentReferenceViewController.swift`
- Modify: `liquid_shell/example/ios/Runner/AppDelegate.swift` (DEBUG: `LIQUID_SHELL_EXAMPLE_DEMO=segments-native` shows the reference view controller instead of Flutter)
- Test: `liquid_shell/example/test/cases_smoke_test.dart`, `liquid_shell/example/test/search_case_test.dart`, `liquid_shell/example/test/goldens/cases_test.dart` (+ `segments` goldens), `liquid_shell/example/test/goldens/liquid_test.dart` (engaged lens bands)

**Interfaces:**
- `SegmentsCase`: a page with three controls on the same stripes the reference screen draws (diagonal 40 pt bands, the eight system colours of the spike's `PatternView`, drawn by a `CustomPainter`), at fixed frames: full width 3 segments at y 240 (margins 16), 2 segments at y 320, 5 at y 400, intrinsic "All | Songs | Places" centred at y 160, a disabled one at y 480; a switch row for RTL and text scale ×2.
- `SegmentReferenceViewController` (Swift, DEBUG only, public UIKit API only): the same controls at the same frames (`UISegmentedControl(items:)`, `selectedSegmentIndex = 0`, layout margins 16) over the same stripes drawn with `UIBezierPath`.

- [ ] **Step 1: Write the failing tests.**
  - `cases_smoke_test.dart`: the `segments` case opens and shows four `LiquidSegmentedControl`s; a tap on "Songs" selects it.
  - `search_case_test.dart`: the search case passes `scopes` to `LiquidSearch`; its scope bar is a `LiquidSegmentedControl` in Flutter mode.
  - Goldens: `case_segments_{light,dark,rtl,ax2}.png`; `liquid_golden` bands `segment_lens_pressed.png`, `segment_lens_straddle.png` through `debugSegmentLensPress` (import from `src/`, as the VK-503 bands do).
- [ ] **Step 2: Run** `cd liquid_shell/example && fvm flutter test test/cases_smoke_test.dart test/search_case_test.dart` → FAIL.
- [ ] **Step 3: Implement**; `make goldens-update`; review every changed image (the search case's active images change: the liquid control replaces the pill).
- [ ] **Step 4: Run** `make test` and `make goldens` → PASS.
- [ ] **Step 5: Commit** `feat(example): segments case, native reference screen, search scopes (VK-550)` (images included).

---

### Task 13: Acceptance tooling: traces and strips

**Files:**
- Create: `tool/trace_math.dart` (move `springAt`, `settle`, `steadyLag`, `overshoot`, `rampLag`, `within`, `fitDelay`, `colourCheck`, `valueAt` and the `Check` typedef out of `tool/tab_trace_compare.dart`; that file imports it)
- Create: `tool/segment_trace_compare.dart`, `tool/test/segment_trace_compare_test.dart`
- Create: `tool/frames_lib.sh` (move `stamp`, `tick`, `stop_recorder`, `record` out of `tool/tab_frames.sh`; it sources the lib), `tool/segment_frames.sh`
- Create: `liquid_shell/example/integration_test/segment_fidelity_test.dart`, `liquid_shell/example/ios/RunnerUITests/SegmentFidelityUITests.swift`
- Modify: `Makefile` (`segment-traces`, `segment-frames`; `.PHONY`), `tool/test/tab_trace_compare_test.dart` (imports move)

**Interfaces:**

```make
segment-traces: ## Flutter segmented control traces on an iOS 26.5 iPhone 17 Pro simulator vs the native reference (spec VK-550 §14.5)
	FLUTTER="$(FLUTTER)" DART="$(DART)" TRACES_ONLY=1 tool/segment_frames.sh
	$(DART) run tool/segment_trace_compare.dart $(EXAMPLE)/build/integration_response_data.json docs/qa/vk550/native_reference.json

segment-frames: ## Native vs Flutter liquid segmented control strips at 60 fps on an iOS 26.5 simulator (needs ffmpeg)
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/segment_frames.sh
```

- `segment_trace_compare.dart`: `main(args)` loads the Flutter `reportData` (`{'sequences': {name: [{t, x, w, h, engage}, ...]}, 'geometry': {...}, 'colours': {...}}`) and the fixture; prints one row per spec §14.5 check with its kind (`native`, `native, constant`), `pass`/`FAIL`, and a summary; exits 1 on any failure. Every reference value is read from the fixture; none is a Flutter constant.
- `segment_fidelity_test.dart`: opens demo `segments-liquid`, prints `SEGFID start`, records `debugSegmentTrace` while driving, through `tester` gestures with the same timings as the spike (`tap` held 0.07 s; hold 2 s; slow drag at 82 pt/s; flick 324 → 77 over 0.25 s; then `programmatic`: the case's "next" button), samples the rest colours over white and black pages, and calls `binding.reportData`. Coordinates are the case's full-width 3-segment control.
- `SegmentFidelityUITests.swift`: launches `segments-native`, prints `SEGFID start`, drives the same sequence on the reference screen with `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`.
- `segment_frames.sh`: as `tab_frames.sh` (sourcing `frames_lib.sh`), its own `vk550-segfid` simulator, the band `crop=iw:150:0:<(232 pt) × 3>`, `tool/tab_strips.dart` with `--band 0:150 --every 3 --rows 18`, light then dark (`simctl ui appearance`), output `liquid_shell/example/build/segfid/strips/{light,dark}/frames_<k>.png`.

- [ ] **Step 1: Write the failing test** `tool/test/segment_trace_compare_test.dart`: (a) a synthetic Flutter trace equal to the fixture rows passes every row; (b) one tap trace shifted by 3 pt fails exactly its x rows; (c) the tool exits 1 with a missing sequence; (d) no check reads a value from the Flutter side as its reference (the reference column of every printed row equals a fixture number: assert by building the table from a fixture with every number +1000 and checking the reference column changes). Also move the imports in `tab_trace_compare_test.dart` and keep it green.
- [ ] **Step 2: Run** `fvm dart test tool/test/segment_trace_compare_test.dart tool/test/tab_trace_compare_test.dart` → FAIL (no tool).
- [ ] **Step 3: Implement** the tools, scripts, tests and Makefile targets. `shellcheck tool/*.sh` clean.
- [ ] **Step 4: Run** the two tool tests → PASS; `make tab-traces` → the same table as Task 6's file (the refactor of `tab_frames.sh` changes nothing); `make segment-traces` → it runs end to end (rows may fail before Task 15's tuning; the tool must not crash).
- [ ] **Step 5: Commit** `test(ci): segmented control traces and strips against native (VK-550)`.

---

### Task 14: Docs, CHANGELOG, version 0.1.0-dev.7

**Files:**
- Create: `liquid_shell/doc/segmented_control.md`
- Modify: `liquid_shell/doc/search.md`, `liquid_shell/README.md`, `liquid_shell/doc/theming.md`, `CHANGELOG.md` in all four packages, every `pubspec.yaml` version and inter-package constraint, `liquid_shell_ios/ios/liquid_shell_ios.podspec`
- Test: `make snippets`, `make publish-check` (dry run only), a grep that no `0.1.0-dev.6` remains outside CHANGELOG history

- [ ] **Step 1: Write the failing check.** Add `#docregion segments` in `segments.dart` (Task 12) to README's new "Segmented control" section reference without copying the code yet → `make snippets` FAILS ("README snippet differs").
- [ ] **Step 2: Write the docs.**
  - `doc/segmented_control.md`: what it is; the API (`segments`, `selectedIndex`, `onChanged`, `expand`, `LiquidSegment.enabled`, `semanticLabel`); geometry (32 track, 44 box, inset 2, 13 pt); theming (`segmentTrack`, `segmentThumb`, `segmentLabelStyle`); motion (commit on release, the lens, drag and flick, selection clicks, programmatic slide); accessibility (semantics, reduce motion, RTL, text scale ×2, AX large content viewer, 44 pt); tiers; "What is not identical to iOS" (Q-B, Q-C, Q-D, Q-E, Q-F rows in plain words).
  - `doc/search.md`: `LiquidSearch.scopes`; native mode on iOS 26+ (UIKit's scope bar, shown while active, top on iPhone, under the field on iPad; `LiquidSearchScopeBar` builds nothing there); Flutter mode; the one-way rule (write `scopeIndex` for app actions only).
  - README: the section, the snippet, the search paragraph; CHANGELOG ×4 `## 0.1.0-dev.7` with spec §13's behaviour changes; versions `0.1.0-dev.7` everywhere.
- [ ] **Step 3: Run** `make snippets` → PASS; `make test` → PASS; `make publish-check` → only the known pre-publish warnings.
- [ ] **Step 4: Commit** `docs(docs): segmented control docs, CHANGELOG and version 0.1.0-dev.7 (VK-550)`.

---

### Task 15: Acceptance run, one tuning round, final verification

**Files:**
- Create: `docs/qa/vk550/acceptance.md`
- Modify (tuning only, if a row fails): `liquid_shell/lib/src/chrome/lens_profile.dart` (envelope knobs), `liquid_shell/lib/src/segmented/segmented_control.dart` (bezel), with their tests updated to the new pins

- [ ] **Step 1: Run the gate.** `make segment-traces` and `make segment-frames` on your own simulators (light and dark). Save the table and the strips (copy the strips to vankhan `.superpowers/sdd/vk550-strips/`).
- [ ] **Step 2: Tune once.** For each failing **native** row, change only the envelope knob or the bezel that row depends on, re-pin its unit test, rerun Step 1. Never change a measured spring or a fixture number. Any row still failing after one round is reported, not hidden.
- [ ] **Step 3: Verify everything.**

```bash
make verify
make test-impeller
make goldens
make tab-traces                 # the VK-503 table, unchanged
make segment-traces
make ios-unit IOS_UNIT_DEVICE=<udid>
make ios-ui IOS_UNIT_DEVICE=<udid>
NATIVE_DEVICES="<iPad udid>=true;<iPhone udid>=true" make integration-ios-native
```

Paste every output into `acceptance.md`: the run (date, simulators, commits), the trace table with kinds, the strip index (what matches, what differs), the native scope bar screenshots on the four devices, the accepted limits (Q-A … Q-F), and the owner's on-device checklist (haptics on drag, the native scope bar on iPhone and iPad, the Flutter control with "Flutter liquid" forced, light and dark).

- [ ] **Step 4: Delete** your simulators.
- [ ] **Step 5: Commit** `docs(docs): VK-550 acceptance traces and strips (VK-550)`. Then `superpowers:requesting-code-review`, `superpowers:verification-before-completion`, and, after PR #9 merges, rebase on `main` and `superpowers:finishing-a-development-branch` (PR body: the Plane link, `make verify` output). No push without the owner's go-ahead.

---

## Self-review notes (plan author)

- **Spec coverage.** §3 → Task 1; §4 → Tasks 2, 6; §5 → Task 3; §6 → Tasks 5, 7; §7 → Tasks 7, 8; §8 → Tasks 4, 8; §9 → Tasks 6, 8; §10 → Tasks 10, 11; §11 → Task 9; §12 → Tasks 3, 7, 8; §13 → Tasks 7, 9, 10, 14; §14 → Tasks 1, 4, 7–13, 15; §15 → Task 14.
- **Refactor safety (R1).** Tasks 2 and 6 change no behaviour: the VK-503 widget tests and `make tab-traces` are run before and after, and `lens_profile_test.dart` pins the tab profile to `TabSprings` by identity.
- **No read-back acceptance.** Every gate number lives in `docs/qa/vk550/native_reference.json`, written from native captures (spike + Task 1) before any Flutter segment code exists; `segment_trace_compare_test.dart` (d) proves the tool reads references only from it.
- **Ordering.** The native bridge (Task 10) does not depend on the Flutter control; Tasks 10–11 can run in parallel with Tasks 7–8 in separate subagents, merging at Task 12.
