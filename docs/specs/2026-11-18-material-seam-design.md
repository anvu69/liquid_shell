# One Material seam and the 3.50 lint infos (VK-1077, VK-1078)

Status: approved by the owner on 2026-11-18 (every default of the decision
table in §7). Evidence: `.superpowers/sdd/vk1077-1078-design.md` in the
vankhan ledger dir (not in this worktree).

## 1. Problem

VK-1076 made CI green on Flutter stable 3.50.0 (Dart 3.14.0) by tolerating
two info classes in `make analyze-stable` (`tool/check_analyze.dart`):

- **R1** `deprecated_member_use` ×112: Flutter 3.50 puts a library-level
  `@Deprecated` on `package:flutter/material.dart` and
  `package:flutter/cupertino.dart` (→ `material_ui` / `cupertino_ui`).
  `liquid_shell/lib` 16, `liquid_shell/test` 48 (one of them cupertino),
  `example` 45, `example_go_router` 3; the other packages 0. No member and
  no `src/material/*.dart` file is deprecated.
- **R2** `unnecessary_ignore` ×4 of `avoid_positional_boolean_parameters`:
  Dart 3.14 narrowed the rule to two or more positional bools
  (dart-lang/sdk#64913); 3.44 and 3.47 still flag a single one, so the
  ignore is needed on the floor and unnecessary on stable.

  | # | Site | Surface |
  |---|---|---|
  | 1 | `liquid_shell_platform_interface/lib/src/native_chrome.dart`, `LiquidNativeSearchActiveChanged(this.active)` | public |
  | 2 | `liquid_shell/lib/src/chrome/lens_motion.dart`, `MinimizeMotion.set(bool minimized, …)` | internal |
  | 3 | `liquid_shell/test/widget/shell_chrome_test.dart`, `void setVisible(bool _)` | test |
  | 4 | `tool/pigeon/pigeons/native_shell.dart`, `ignore_for_file` | Pigeon DSL |

Both cost pana points on stable. pana ≥ 0.23.17 honours the package's
`include:` again, so very_good_analysis (with `unnecessary_ignore`) applies:
on 3.50 with pana 0.23.19, `liquid_shell` scores 40/50 for static analysis
(R1 in `lib`, R2 site 2) and `liquid_shell_platform_interface` 40/50 (R2
site 1). pub.dev will score the published packages the same once its SDK
moves to 3.50.

## 2. Goals

- `liquid_shell/lib` and `liquid_shell/test` report no R1 on 3.44.9, 3.47.9
  and 3.50.0, and use exactly the SDK's Material types (no user-visible
  change).
- R2 sites 2 and 3 are fixed in code.
- `tool/check_analyze.dart` tolerates R1 only under the two example apps and
  R2 only in the two files that cannot change (sites 1 and 4).
- A blocking gate keeps the deprecated imports out of `liquid_shell/lib` and
  `liquid_shell/test` on the floor.
- `liquid_shell` scores 50/50 for static analysis on 3.50.

## 3. Non-goals

- The migration to `material_ui` / `cupertino_ui` (F2): it splits the
  Material types (an SDK `MaterialApp` theme is not seen by `material_ui`'s
  `Theme.of`; `LiquidGlassTheme` stops fitting an SDK `ThemeData`) and adds
  six runtime dependencies against the dependency rule.
- R1 in the examples: the README snippets come from `example/lib`, and a
  reader on the floor must see the real import.
- R2 site 1 (a breaking constructor in the platform interface, B6) and site
  4 (Pigeon rejects named FlutterApi parameters).
- A release (`0.1.0-dev.14`).

## 4. Design

### 4.1 The barrel `liquid_shell/lib/src/material_sdk.dart`

- `export`s `package:flutter/widgets.dart` and only the
  `package:flutter/src/material/*.dart` files liquid_shell uses: 17 for
  `lib` (`app badge color_scheme colors dialog icon_button icons ink_well
  input_decorator material scaffold text_field text_theme theme theme_data
  tooltip typography`), plus 5 for `test` (`bottom_sheet page tab_controller
  tabs text_button`). It grows when a new symbol is needed.
- `implementation_imports` checks `import` directives, not `export`, so the
  barrel needs no ignore; every file that imports the barrel imports its own
  package.
- Plain `//` comments only (no `library;`, no dartdoc, so `make
  public-docs` and `dangling_library_doc_comments` stay quiet). They say
  why it exists, why it is not a loophole, and its exit (F2, or anything the
  stable leg reports on it).
- It is not exported from `liquid_shell.dart`.
- The 16 `lib` files and the 47 material test files import it instead of
  `package:flutter/material.dart`; `dart fix --code=directives_ordering`
  reorders.

### 4.2 The one cupertino test

`liquid_shell/test/widget/liquid_backdrop_test.dart` uses `CupertinoApp` and
`CupertinoPageRoute` only. A test-side barrel,
`liquid_shell/test/helpers/cupertino_sdk.dart`, exports
`package:flutter/widgets.dart` and `package:flutter/src/cupertino/{app,
route}.dart`. The lib barrel stays Material-only (D2).

### 4.3 The seam gate `tool/check_material_seam.sh`

Mirrors `tool/check_glass_seam.sh`: `git grep --untracked` over
`liquid_shell/lib` and `liquid_shell/test` for an `import` or `export`
directive of `package:flutter/(material|cupertino).dart`, anchored to the
start of the line so comments and dartdoc snippets pass. Exit 1 with a hint
to import `package:liquid_shell/src/material_sdk.dart`. The barrels export
`src/…` files, so they need no exemption. `make provenance` runs it, so it
blocks on the floor (pre-commit, `make verify`, CI 3.44.x).

### 4.4 R2 sites 2 and 3

- `MinimizeMotion.set({required bool minimized, bool delayed = true})`
  (internal), callers `glass_tab_bar.dart` and `lens_motion_test.dart`; the
  ignore goes.
- The test double becomes a tear-off, `final setVisible = <bool>[].add;`
  (one shared instance, so `LiquidChromeDetails ==` still compares equal);
  tear-offs are not flagged on any SDK.

### 4.5 `tool/check_analyze.dart`

`toleratedBecause` also takes the path:

- R1 only when the path contains `/liquid_shell/example/` or
  `/liquid_shell/example_go_router/` (a segment, not a prefix: machine
  output is absolute and the checkout directory varies). Reason
  `R1, VK-1077 (examples: README)`.
- R2 only when the path ends with
  `/liquid_shell_platform_interface/lib/src/native_chrome.dart` or
  `/tool/pigeon/pigeons/native_shell.dart`. Reason
  `R2, VK-1078 (floor < Dart 3.14)`.

On 3.50 `make analyze-stable` then tolerates 48 + 2 = 50 issues (was 116).
If a list ever empties the tool and its tests stay (D8). R2 is deleted with
the floor raise to Dart 3.14 (F3).

### 4.6 Docs

`liquid_shell/CHANGELOG.md` gets one line under a new `## 0.1.0-dev.14`
(the repo's unreleased convention). Comments that name R1/R2: `ci.yaml`,
the Makefile's `analyze-stable` and `provenance`, `CONTRIBUTING.md`. The
VK-1076 spec gets a one-line pointer here. Historic plans are not edited.

## 5. Verification

| | 3.44.9 | 3.47.9 | 3.50.0 |
|---|---|---|---|
| `make get`, `make format-check` | ✓ | ✓ | ✓ |
| `make analyze` | ✓ 0 issues | ✓ (in `make verify`) | |
| `make analyze-stable` | ✓ 0 tolerated | ✓ 0 tolerated | ✓ 0 blocking, 50 tolerated |
| `make provenance` (seam gate) | ✓ | ✓ | ✓ |
| `make test`, `make coverage` | ✓ | ✓ | ✓ |
| `make goldens-plain` | | ✓ (`make verify`) | ✓ |
| `make verify` | | ✓ | |
| pana 0.23.19 static analysis | | | `liquid_shell` 50/50 (was 40), platform_interface 40/50 (R2 site 1, unchanged) |

Tool tests red first (`check_analyze_test`, `check_material_seam_test`).

## 6. Risks and follow-ups

- The barrel depends on the SDK's `src/material` paths. `material.dart` is
  itself only a re-export of them, so the coupling is not new; if a later
  SDK annotates or moves them, the stable leg reports it on the barrel
  (R1 no longer covers `lib`).
- **platform_interface stays 150/160 on stable pana** until R2 site 1 goes:
  B6 (a breaking named `active:`), an owner waiver, or the floor raise (F3).
  The approved design assumed R2 cost no pana points (measured with pana
  0.23.12, which dropped `include:`); pana 0.23.19 contradicts that.
- F1: `LiquidGlassTheme` reachable without `ThemeData.extensions`, for apps
  migrated to `material_ui`. F2: the real migration. F3: floor 3.50.

## 7. Decisions (owner, 2026-11-18)

| # | Decision |
|---|---|
| D1 | A4: internal barrel `liquid_shell/lib/src/material_sdk.dart` |
| D2 | only the `src/material` files used (17 for `lib`, 22 with tests) + `widgets.dart` |
| D3 | tests import the barrel too; the cupertino test via a test-side barrel |
| D4 | examples keep `package:flutter/material.dart`; R1 narrowed to the two example apps |
| D5 | R2 sites 2 and 3 fixed now (named `minimized:`, tear-off) |
| D6 | site 1 keeps its positional bool; R2 narrowed to that file |
| D7 | site 4 (Pigeon) kept; R2 narrowed to that file |
| D8 | `tool/check_analyze.dart` and its tests stay even if a list empties |
| D9 | `tool/check_material_seam.sh` in `make provenance`, blocking on 3.44 |
| D10 | no release; CHANGELOG line under the next dev heading only |
