# liquid_shell VK-701: release docs and metadata (the first pub.dev release, part A)

- **Plane:** VK-701, part A of VK-681 (the pre-release review of 2026-10-19). Part B (VK-702) changes public code; part C (VK-703) publishes. This spec touches no `lib/` code except dartdoc comments.
- **Date:** 2026-10-21
- **Status:** approved in the brainstorm of 2026-10-21 (owner: "ok", "tiếp tục" to each section). Plan: `docs/plans/2026-10-21-release-docs.md`. Choices the owner did not state are in "Quyết định phát sinh", at the end.
- **Branch:** `VK-701-release-docs`, from `origin/main` at `cd6504c`.
- **Sources:**
  - VK-681's description (the review at `cd6504c`) and its comment of 2026-10-21 (seven tests that read `../docs/qa/vk550/*.json`).
  - pub.dev's README renderer, `dart-lang/pub-dev` `app/lib/shared/markdown.dart`, `_RelativeUrlRewriter`: every relative `<a href>` and `<img src>`, HTML tags included, is resolved against the package's `repository` URL (raw for images). dart-lang/pub-dev#5068 (default branch `main`) is closed.
  - CI run 39095489319 (main, `cd6504c`), job integration-ios-native (iPhone, iOS 26): "Adding Swift Package Manager integration…", "All plugins found for ios are Swift Packages".
  - `go_router` 18.1.1 on pub.dev (2026-10-21).

> **Tóm tắt (cho chủ sản phẩm).**
> - **Đóng gói:** gói pub không mang `test/`, `example/test/`, `example/integration_test/`. Thêm `screenshots:` (một ảnh hero). Kiểm bằng `dart pub publish --dry-run` trước/sau.
> - **Ảnh README:** giữ đường dẫn tương đối. pub.dev tự phân giải chúng qua `repository` (đọc mã pub-dev), nên mục "ảnh vỡ" của rà soát VK-681 không đúng. Ảnh luôn lấy từ `main`.
> - **Metadata:** podspec `author` thành `https://lasoai.vn` (không bịa email); xoá `DEVELOPMENT_TEAM` khỏi example; example nâng ràng buộc lên `^0.1.0-dev.8`.
> - **I5:** CI đã build iOS bằng SwiftPM; sửa câu "unverified", đóng gate §12.1, thêm dòng CHANGELOG.
> - **README:** Install nêu iOS 15.0, Android minSdk 24, khoá Info.plist. Chỉ iOS và Android là hỗ trợ chính thức; macOS/web/desktop ghi "chưa test". Roadmap và Known issues viết lại, không mã nội bộ.
> - **M6:** dọn dấu nội bộ (`§`, `VK-`, `P3b`, `(Q9)`) khỏi dartdoc `///` và markdown công khai; cổng `make public-docs` chặn tái phát.
> - **example/README.md:** mô tả các case, cách chạy.
> - **go_router:** app riêng `liquid_shell/example_go_router/` (không publish) + widget test; `doc/router_integration.md` lấy code từ đó qua `make snippets`. Cổng provenance chỉ nới đúng thư mục đó.

---

## 1. Goal

Everything a pub.dev reader sees of the four packages, except the code itself, is ready for the first release: the archive holds no file that breaks outside the repo, the README states what is supported and how to install, no public text carries this project's internal references, and the go_router recipe is code that CI runs.

Success: `make verify` green with the two new gates; `dart pub publish --dry-run` with 0 warnings for the four packages, listings recorded before and after; pana for `liquid_shell_platform_interface` not lower than 150/160.

## 2. Scope

### 2.1 In

1. Packaging (§3.1).
2. Metadata: podspec author, example `DEVELOPMENT_TEAM`, example constraints (§3.2).
3. I5, the SwiftPM sentence (§3.3).
4. The `liquid_shell` README: Install, supported platforms (M13), Roadmap, Known issues (§3.4).
5. M6 and its gate (§3.5).
6. `liquid_shell/example/README.md` (§3.6).
7. `liquid_shell/example_go_router/` and `doc/router_integration.md` (§3.7).

### 2.2 Non-goals

- Any `lib/` change other than dartdoc text (VK-702).
- Version bump, publishing, tags, publisher transfer, pana blocking in CI (VK-703).
- The `dart format` drift in `liquid_shell_platform_interface/lib/src/native_chrome.dart` that costs 10 pana points: it is code formatting, VK-702.
- Absolute or tag-pinned image URLs (Quyết định phát sinh 1).
- `//` comments and Swift/Kotlin comments keep their internal references (owner, Q5).
- CHANGELOG entries of released versions are not rewritten.
- A fix for VK-680 or VK-593: the router app documents today's behaviour.
- Opening GitHub issues for the Known issues.

## 3. Design

### 3.1 Packaging

`liquid_shell/.pubignore` gains:

```
test/
example/test/
example/integration_test/
```

`test/` replaces the three C8 lines of PR #19 (VK-651) if that PR is merged first; the rebase keeps one rule. Reason: seven tests read `../docs/qa/vk550/*.json` (`test/helpers/native_rows.dart:8`, `test/unit/glass_theme_test.dart:334`) and three import `../../../tool/`, so the archive's tests cannot run outside the repo; pub.dev and pana do not ask for tests.

`screenshots:` in `liquid_shell/pubspec.yaml`, one entry: `doc/images/hero_iphone_light.png` (210 KB), description "Glass tab bar on an iPhone". `.pubignore` keeps `doc/images/` and re-includes that file (`!doc/images/hero_iphone_light.png`). If the dry run does not show the file, the fallback is a copy at `screenshots/hero_iphone_light.png` outside `doc/images/` (recorded in the task report).

Check: `make publish-check` before (listing saved) and after, for the four packages: the removed files are gone, the screenshot is in, 0 warnings, sizes noted.

### 3.2 Metadata

- `liquid_shell_ios/ios/liquid_shell_ios.podspec:11`: `s.author = { 'lasoai.vn' => 'https://lasoai.vn' }`.
- `liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj`: the three `DEVELOPMENT_TEAM` lines removed. CI runs simulators, which need no team; a device run picks a team in Xcode.
- `liquid_shell/example/pubspec.yaml`: `liquid_shell`, `liquid_shell_ios`, `liquid_shell_platform_interface` constraints `^0.1.0-dev.8`.

### 3.3 I5: SwiftPM is verified

- `liquid_shell_ios/README.md:13`: the sentence becomes "Both CocoaPods and Swift Package Manager builds are tested on CI.", dropping "unverified until …".
- `docs/specs/2026-10-08-p1-foundation-design.md` §12.1: the SwiftPM gate is marked closed, with run 39095489319 and the two log lines in Sources.
- `liquid_shell_ios/CHANGELOG.md`, under the unreleased section: "Swift Package Manager builds are now tested on CI."

### 3.4 The `liquid_shell` README

- **Install:** after `flutter pub add liquid_shell`: Flutter 3.44+; iOS 15.0 (Podfile `platform :ios, '15.0'` and `IPHONEOS_DEPLOYMENT_TARGET`); Android minSdk 24; native iOS 26 chrome needs `LiquidShellNativeChrome` in `Info.plist` (link to "Native iOS chrome").
- **Platforms (M13):** a short "Platforms" paragraph above the tier table: iOS and Android are supported and tested; macOS, web, Windows and Linux are not tested (the shell has no native code there and draws the frosted or liquid tier). The tier table keeps its rows, with "(not tested)" on macOS and on Web/Windows/Linux. `flutter.plugin.platforms` already lists only `ios` and `android` (`pubspec.yaml:26-32`): no change.
- **Roadmap:** rewritten without phase codes: what 0.1.0 holds, then "Planned": native navigation bars on every tab (today the search tab only), a go_router adapter. No version numbers for planned work.
- **Known issues** (new, after Limitations): plain sentences, links upstream where one exists, no internal ids:
  - the first status-bar tap may not scroll a Flutter list to the top while the iOS accessibility bridge is on (VoiceOver, Speak Screen; always in the simulator): flutter/flutter#191565;
  - a tab that is revealed a few frames after it is selected (a custom `navigatorContainerBuilder` with an animation): system back does not find its navigator;
  - native navigation bars only on the search tab.
  The landscape keyboard inset (VK-594) is fixed by PR #20 and is not listed; if PR #20 is not merged when this branch lands, the plan adds it.

### 3.5 M6: internal references out of public docs, and the gate

**Gate.** `tool/check_public_docs.sh`, in the style of `tool/check_provenance.sh` (`git grep`, tracked plus untracked-not-ignored files). It fails, printing `file:line`, on these patterns (case-sensitive):

| Pattern | Catches |
|---|---|
| `§` | spec sections |
| `\bVK-[0-9]+` | Plane ids |
| `\bP[0-9]+[a-z]?(-[0-9]+)?\b` | phases: P2, P3b, P3b-2 |
| `\(Q[0-9]+\)` | brainstorm questions |

in:
- lines starting with `///` (after spaces) in `*/lib/**/*.dart` of the four packages, generated `*.g.dart` excluded;
- `README.md` of the four packages and `liquid_shell/doc/*.md`.

CHANGELOGs are exempt. `make public-docs` runs it; `verify` and CI's `checks` job add it next to `provenance`. Test: `tool/test/check_public_docs_test.dart`, as `check_provenance_test.dart` does: a temporary file with each pattern fails, a clean file passes, `p90` and a `CHANGELOG.md` pass.

**Counts at `cd6504c`.** `///` lines: `liquid_shell` 254, `liquid_shell_ios` 6, `liquid_shell_platform_interface` 3, `liquid_shell_android` 0. Markdown: 22 lines in `liquid_shell` README and `doc/`. The plan records the script's own count on main as the red.

**Cleaning rule.** Remove the reference or replace it with what it stands for, never with another code: "(spec §7.4)" is dropped; "the one-way rule (spec §7.4)" keeps "the one-way rule"; "P3b-2 brings them" becomes "a later release brings them". A sentence that only makes sense with the reference is rewritten. Comment text only: the task's diff touches no code line (checked by `git diff -U0 | grep '^[+-]' | grep -v '^\(+++\|---\)' | grep -vE '^[+-]\s*///'` being empty for the Dart files).

### 3.6 `liquid_shell/example/README.md`

What the app is (one screen per README case), the case list with one line each (from `example/lib/cases/cases.dart`), how to run it (`flutter run` in `example/`, Impeller note for the liquid tier, native iOS 26 chrome needs an iOS 26 simulator), and a pointer to `example_go_router/`. pub.dev's Example tab shows this file instead of `main.dart`. No code snippets, so `make snippets` is not involved.

### 3.7 `liquid_shell/example_go_router/`

**Package.** `publish_to: none`, workspace member (root `pubspec.yaml` `workspace:` list), `resolution: workspace`. Dependencies: `flutter`, `liquid_shell` (workspace), `go_router: ^18.1.1`. Dev: `flutter_test`, `very_good_analysis` (same pin as `example`). Platform folders: none generated beyond what `flutter test` needs (widget tests only; no iOS/Android project), unless `flutter create` is required by the workspace analyzer, in which case `--platforms ios,android` and nothing else.

**App** (`lib/go_router_app.dart`, with a two-line `lib/main.dart` that runs it; `#docregion` blocks named `shell`, `branches`, `detail`). The file name is unique across both example apps, because a marker names a file without its directory:
- `GoRouter` with a root navigator key and `StatefulShellRoute.indexedStack`: three branches, Home, Explore, Search (the search branch uses `LiquidSearch`).
- `builder`: `LiquidShell(selectedIndex: shell.currentIndex, onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex), body: shell)`.
- A detail route under Home with `parentNavigatorKey: rootKey`, wrapped in `LiquidHideChrome` (the chrome hides above a root page).
- Back and the edge swipe: what the shell does under go_router today, no extra code.

**Tests** (`test/router_test.dart`, red first: written against a stub `go_router_app.dart`):
1. Selecting Explore shows Explore; a counter incremented on Home survives Home → Explore → Home.
2. Pushing the detail page hides the chrome (`find.byType(LiquidTabBar)` gone or the hide wrapper active, whichever the shell exposes; the plan picks after reading `hide_chrome.dart`'s test).
3. System back (`tester.binding.handlePopRoute()`) on the detail page returns to Home with the chrome shown.
4. On Explore's root, system back goes to Home (the shell's default).
If a case does not hold under go_router, the test records the actual behaviour, the case goes to Known issues (§3.4), and `lib/` is not changed.

**Doc.** `doc/router_integration.md` "go_router (until the adapter ships)" becomes "go_router", built from the three regions with the markers `make snippets` already reads (`<?code-excerpt "go_router_app.dart (shell)"?>` before a ```` ```dart ```` block; every region must be used), plus prose on the root page and back.

**Machinery.**
- `tool/check_readme_snippets.dart` (`regionsUnder(Directory('$package/example/lib'))`, `:226`) also reads `$package/example_go_router/lib`; a file name found in both is an error.
- `make analyze`, `make test`: the new package is included (the workspace already drives them; the plan checks the Makefile's package list).
- `tool/check_provenance.sh`: the `go_router` rule excludes `':!liquid_shell/example_go_router/'` (and the root `pubspec.lock`/`pubspec.yaml` lines the workspace adds, if any). Spec P1 §9 and §12.2 get one line: go_router may appear in that app only.
- `make coverage`: the app has no `lib` coverage requirement; `tool/check_covered.dart` is checked so it does not demand one.

## 4. Risks

| Risk | Handling |
|---|---|
| The `!doc/images/hero_iphone_light.png` re-include is not honoured by `.pubignore` | The dry run shows it; fallback a `screenshots/` copy (§3.1) |
| Cleaning 260+ dartdoc lines changes code | The diff check of §3.5; the M6 task is reviewed alone |
| A cleaned sentence loses its meaning | Rule of §3.5: rewrite, do not truncate; reviewer reads every hunk |
| The shell's back under go_router differs from the doc (VK-680, VK-593 open) | Tests record actual behaviour; Known issues lists the gap |
| go_router leaks into `example` or the package | Provenance excludes one directory only |
| The workspace pulls go_router into every member's resolution | It is a dependency of one member; the root lock gains it. Published archives are unaffected (pub resolves per package) |
| PR #19 / #20 land meanwhile | Fetch main before each task; `.pubignore` and Known issues adapt as §3.1/§3.4 say |

## 5. Test strategy

| Item | Red first? | How |
|---|---|---|
| Packaging | No test; the dry-run listing before/after is the check | `make publish-check` |
| Metadata, I5, README, example README | Docs | `make snippets`, `make verify` |
| M6 gate | Yes: the script test fails (no script), then the script fails on main with its count, then green after cleaning | `flutter test tool/test/…`, `make public-docs` |
| go_router app | Yes: the widget tests fail against a stub | `flutter test` in `example_go_router` |
| Snippet lock | A temporary mutation of a doc snippet turns `make snippets` red | reverted |
| Branch | `make verify`, `make pana` (platform_interface ≥ 150) | |

## 6. CHANGELOG

- `liquid_shell_ios`: "Swift Package Manager builds are now tested on CI." (§3.3)
- `liquid_shell`: "The package archive no longer includes tests; the README states supported platforms." Docs-only otherwise; no API line.

## 7. Process

- Commits `<type>(<scope>): <summary> (VK-701)`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `bash .githooks/pre-commit` before every commit; never `--no-verify`.
- No publish command other than `dart pub publish --dry-run`.
- The controller pushes and opens the PR; the owner merges. Merge just before VK-703's publish is not required (images are relative).

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã trả lời từng câu trong buổi brainstorm 2026-10-21:

| Câu | Đã chốt |
|---|---|
| Chia VK-681 | 3 issue con: A (VK-701), B (VK-702), C (VK-703) |
| Q2 7 test | Loại cả `test/` khỏi gói |
| Q3 ảnh | Ban đầu "tag mỗi lần phát hành"; đổi sau khi kiểm mã pub-dev (Quyết định phát sinh 1) |
| Q4 nền tảng | Chỉ iOS và Android chính thức; các nền tảng khác "chưa test" |
| Q5 M6 | Dọn `///` và markdown công khai; cổng quét đúng hai chỗ đó |
| Q6/Q8 go_router | App riêng `example_go_router/` + widget test; provenance nới đúng thư mục đó |
| Q7 podspec | URL `https://lasoai.vn` (chưa có email `@lasoai.vn`) |

### Quyết định phát sinh

1. **Ảnh README giữ đường dẫn tương đối, không tag.** Mã pub-dev (`_RelativeUrlRewriter`) phân giải `<img src>` tương đối qua `repository`; rà soát VK-681 sai ở mục này. Hệ quả: ảnh của mọi phiên bản trên pub.dev lấy từ `main`. Muốn ghim theo phiên bản thì làm ở VK-703.
2. **`screenshots:` một ảnh** (`hero_iphone_light.png`, 210 KB), không ba: đủ cho thẻ pub.dev, gói nhẹ.
3. **Known issues không gồm VK-594** vì PR #20 sửa nó; thêm lại nếu PR #20 chưa merge.
4. **`DEVELOPMENT_TEAM` xoá** khỏi example (chủ sản phẩm không phản đối).
5. **CHANGELOG `liquid_shell` một dòng** về gói không mang test và README nêu nền tảng.
