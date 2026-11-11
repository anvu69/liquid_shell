# Move the reference toolchain to Flutter 3.47.9 and regenerate the dark liquid goldens (VK-1032)

Status: approved by the owner on 2026-11-11 ("duyệt").

## 1. Problem

The golden reference is Flutter 3.44.x (`.fvmrc` 3.44.9, `tool/update_goldens.sh`
gate `3.44.*`, CI `goldens (3.44.x)`). Latest stable is 3.47.9. On it the CI leg
`goldens (stable)` (macos-26-arm64) reports eight liquid goldens above the 0.5 %
tolerance of `TolerantGoldenComparator`, all of them dark and all under
`--enable-impeller` (liquid tier):

| Image | Pixels differing on 3.47.9 |
|---|---|
| `doc/images/liquid_default_dark.png` | 3.37 % locally (CI's failure files are overwritten by the band's, same name) |
| `bands/liquid_default_dark.png` | 16.09 % |
| `doc/images/liquid_hero_iphone_dark.png` | 3.37 % |
| `doc/images/liquid_hero_android_dark.png` | 3.18 % |
| `doc/images/liquid_hero_ipad_landscape_dark.png` | 0.86 % |
| `bands/tab_glow_release_dark.png` | 19.94 % |
| `bands/tab_lens_pressed_dark.png` | 19.20 % |
| `bands/segment_lens_pressed_dark.png` | 1.17 % |

(Percentages: differing pixels between the artifact's `*_masterImage.png` and
`*_testImage.png`.)

The leg stays green only because its liquid step is `continue-on-error`. The
3.47 engine draws the dark glass shader differently (VK-700). Plain goldens,
light images and the shader probes pass on 3.47.9.

Evidence: `.superpowers/sdd/vk1032-investigation.md` (main run 42978546819,
artifact `golden-failures-stable` 13836637295).

## 2. Decision

1. **Reference version 3.47.9, pinned exactly.** `.fvmrc` moves to 3.47.9. Every
   CI job hard-pinned to `3.44.x` moves to `3.47.9`: `android-unit`,
   `integration-android`, `integration-ios`, `ios-unit`, `ios-ui`,
   `ios-minimize`, `integration-ios-native`. 3.47.9 contains the Xcode 27 lipo fix
   that VK-931 needed (fixed in 3.44.8).
2. **The floor stays 3.44.0.** Every pubspec keeps `flutter: ">=3.44.0"`; the
   consumer app is on the 3.44 line. `checks (3.44.x)` stays the required floor
   leg (format, analyze, unit tests, coverage, snippets; no goldens), and
   `sdk_floor_test.dart` keeps compiling there.
3. **Goldens matrix.** `goldens (3.44.x)` is removed: the 3.44 engine cannot match
   the new dark images. The new required leg is `goldens (3.47.9)`. `goldens
   (stable)` and `checks (stable)` stay experimental (continue-on-error) as the
   early warning for the next release.
4. **Images.** Regenerate with `make goldens-update` on macOS + 3.47.9 (the script's
   gate becomes `3.47.*`) and keep only the eight images above; every other PNG is
   restored. If the local render does not pass the 3.47.9 golden tests, the
   fallback is CI's `*_testImage.png` from the artifact.
5. **Docs** that name the dev pin move to 3.47.9: `CLAUDE.md`, `CONTRIBUTING.md`,
   `Makefile` comments, `tool/update_goldens.sh`, the `ci.yaml` comments.
   `liquid_shell/README.md:76` ("Flutter 3.44 or later") states the minimum and
   stays.

Rejected: keep `stable` as the reference (it drifts at the next release), and
keep a `goldens (3.44.x)` leg (it would fail on the eight images by design).

No branch protection or ruleset exists on `main`, so renaming the goldens leg
breaks no required status check.

## 3. What does not change

- Package code, pubspecs, lockfiles, CHANGELOGs (the packages are unchanged for
  users; VK-931's pin bump had no CHANGELOG line either).
- Historic specs and plans.
- `pana` (plain stable, as before).

## 4. Verification

1. On 3.47.9: `make format-check analyze test` exit 0 (the hook's targets).
2. After regeneration: `git status` shows exactly the eight PNGs changed.
3. On 3.47.9: `make goldens-plain`, `make goldens-liquid`, `make test-impeller`
   exit 0.
4. Each new image is compared with CI's 3.47.9 render (`*_testImage.png` of the
   artifact) at the same 0.5 % tolerance; all within it.
5. On 3.44.9 (record only, `FLUTTER=` override): `make goldens-liquid` fails on
   exactly the eight images.
6. `.githooks/pre-commit` exit 0 before each commit.
7. Acceptance: the PR's CI `goldens (3.47.9)` and the jobs now on 3.47.9 pass.
