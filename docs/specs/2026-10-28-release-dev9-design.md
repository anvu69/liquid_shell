# liquid_shell VK-703: release 0.1.0-dev.9, the first upload to pub.dev

- **Plane:** VK-703 (the main item), under VK-681.
- **Date:** 2026-10-28
- **Status:** approved. The owner answered "Ok hết" to Q1-Q18 on 2026-10-28; this spec records Q2-Q6 (`.superpowers/sdd/wave2-decisions.md`). Plan: `docs/plans/2026-10-28-release-dev9.md`.
- **Branch:** `VK-703-release-dev9`, from `origin/main` at `e0bbf62`.
- **Kind of change:** metadata only: pubspec versions and constraints, the iOS podspec, four CHANGELOG headings, and one Dart tool test. No `lib/`, no native code, no public API.

> **Tóm tắt (cho chủ sản phẩm).**
> - Nâng cả bốn gói lên `0.1.0-dev.9`, thêm mục `## 0.1.0-dev.9` ("First release on pub.dev.") trên mục dev.8 trong bốn CHANGELOG. dev.8 giữ nguyên.
> - Thêm một test Dart nhỏ để các số phiên bản không lệch nhau về sau.
> - Claude **không** publish, không tag, không push. Chủ sản phẩm chạy 4 lệnh publish theo thứ tự, rồi chuyển 4 gói sang publisher `lasoai.vn`. Sau khi chủ sản phẩm báo xong, Claude tạo tag `v0.1.0-dev.9` và GitHub pre-release.

## 1. Goal and non-goals

**Goal.** At the merge of this branch, `main` carries `0.1.0-dev.9` everywhere, `flutter pub publish --dry-run` says "Package has 0 warnings." in all four packages, and the plan ends with the exact commands the owner runs.

**Non-goals.**
- Publishing, tagging, pushing, or creating a GitHub release (Q4, Q5). The plan's last task hands over; it runs nothing that uploads.
- Making the three informational pana CI steps blocking (Q6). That is a follow-up PR after the packages are on pub.dev (`.github/workflows/ci.yaml:88-96`).
- Any S, F or P3b-2 change. Those branches put CHANGELOG entries under `## 0.1.0-dev.10` and do not bump pubspecs (Q2).
- A publish workflow or automated publishing from GitHub Actions. Manual publishing works.

## 2. Evidence (at e0bbf62)

From `.superpowers/sdd/wave2-release-evidence.md`, re-counted on the tree:

| Where | What |
|---|---|
| `liquid_shell/pubspec.yaml:3`, `liquid_shell_platform_interface/pubspec.yaml:3`, `liquid_shell_ios/pubspec.yaml:3`, `liquid_shell_android/pubspec.yaml:3` | `version: 0.1.0-dev.8` |
| `liquid_shell/pubspec.yaml:20-22` | `liquid_shell_android`, `liquid_shell_ios`, `liquid_shell_platform_interface` at `^0.1.0-dev.8` |
| `liquid_shell_ios/pubspec.yaml:17`, `liquid_shell_android/pubspec.yaml:17` | `liquid_shell_platform_interface: ^0.1.0-dev.8` |
| `liquid_shell/example/pubspec.yaml:14,24,25` | `liquid_shell`, `liquid_shell_ios`, `liquid_shell_platform_interface` at `^0.1.0-dev.8` |
| `liquid_shell/example_go_router/pubspec.yaml:15` | `liquid_shell: ^0.1.0-dev.8` |
| `liquid_shell_ios/ios/liquid_shell_ios.podspec:3` | `s.version = '0.1.0-dev.8'` |
| `<package>/CHANGELOG.md:1` (four) | first heading `## 0.1.0-dev.8` |

That is 4 versions, 5 constraints in the packages plus 4 in the examples (9 in all; the evidence report says 6 and 3, a miscount of the packages: `liquid_shell` 3, `liquid_shell_ios` 1, `liquid_shell_android` 1), 1 podspec line, 4 headings. A search for `dev.8` outside `docs/` and the CHANGELOGs finds nothing else. Not changed: `liquid_shell_android/android/build.gradle:2` (`1.0-SNAPSHOT`, a template value), `liquid_shell/doc/liquid.md:70` (history).

Dry run at `e0bbf62`: "Package has 0 warnings." in all four. Prototype for this spec (2026-10-28): the same holds after the bump **once the bump is committed**. With the bump uncommitted `liquid_shell` reports "3 checked-in files are modified in git" and "Package has 1 warning", so the plan runs the dry runs after the commit.

There is no existing version-consistency check: `tool/test/` holds tests of the tool scripts only, and `make test` ends with `dart test tool/test`. CI and `.githooks/pre-commit` both reach it through `make test`.

## 3. Design

1. **Guard test** `tool/test/release_version_test.dart` (Dart `test`, run from the repo root like its neighbours). It reads the four pubspecs, the podspec, the sibling constraints of the four packages and both examples, and the four CHANGELOGs, and asserts:
   - the four packages share one version (`liquid_shell` is the reference);
   - the podspec `s.version` equals it;
   - every sibling dependency constraint is `^<version>` (and there are nine of them, so a new or deleted one is noticed);
   - each CHANGELOG has a `## <version>` heading, and only newer dev headings (`0.1.0-dev.N`, N greater) may sit above it;
   - when the environment variable `RELEASE_VERSION` is set, the shared version equals it.
2. **Bump** in one commit: the 4 versions, 9 constraints, the podspec, and a heading `## 0.1.0-dev.9` followed by `First release on pub.dev.` above `## 0.1.0-dev.8` in each CHANGELOG (Q3). Dev.8 text is untouched.
3. **Hand-off** (last plan task, text only): publish commands in order, the transfer step, the post-publish step. See plan Task 3.

Why constraints stay `^0.1.0-dev.9` and not `^0.1.0`: a prerelease caret accepts later 0.1.x, so the final 0.1.0 needs only the version bump.

## 4. Test strategy

| Check | Red first because | Targets |
|---|---|---|
| `RELEASE_VERSION=0.1.0-dev.9 dart test tool/test/release_version_test.dart` | the tree is at dev.8: `Expected: '0.1.0-dev.9' Actual: '0.1.0-dev.8'` | host Dart |
| Same command with only the pubspec versions bumped | the CHANGELOG test fails: `liquid_shell_platform_interface/CHANGELOG.md lacks "## 0.1.0-dev.9"` (shown during the prototype) | host Dart |
| Mutation after the bump: one constraint back to `^0.1.0-dev.8` | the constraint test goes red; revert | host Dart |
| `flutter pub publish --dry-run` x4 | not red-first: it is the acceptance check, run after the commit | host Flutter |

The guard is green at `e0bbf62` without the variable (all dev.8), so it is committed first as a locker; the red is the `RELEASE_VERSION` run and the mutation. Native and simulator tests are not run: no native code changes.

## 5. CHANGELOG wording

Each of the four packages, above `## 0.1.0-dev.8`:

```markdown
## 0.1.0-dev.9

First release on pub.dev.
```

## 6. Risks

- **A pub.dev version is permanent.** It can be retracted, never reused. The number must be final before the owner's first upload; this spec fixes it at dev.9.
- **The bump must be on `main` before publishing**, because pub.dev verifies `repository` against GitHub `main` and pana resolves siblings from pub.dev only. Hence: merge, then publish.
- **Order.** `^0.1.0-dev.9` siblings are resolved from the workspace, so the dry run cannot prove the order. Interface first, then ios and android, then `liquid_shell`, waiting for each version page to appear.
- **Upload goes under the personal account, then transfer.** Whether the account behind `~/Library/Application Support/dart/pub-credentials.json` is an admin of `lasoai.vn` is unknown (Claude did not read the file). The owner checks at `https://pub.dev/publishers/lasoai.vn/admin` before the first upload.
- **S and F merge later** and add `## 0.1.0-dev.10` above dev.9; the guard allows that (§3.1).
- **The 21 "newer versions incompatible" notes** of `pub get` are dev or transitive dependencies; direct runtime dependencies are loose, so no pub points are expected to be lost.

## 7. Quyết định phát sinh

1. **The CHANGELOG assertion allows newer dev headings above the pubspec version.** Q2 has S, F and P3b-2 put `## 0.1.0-dev.10` at the top without a bump; "top heading equals the version" would turn their branches red. Rule: the version's heading exists, and anything above it is a larger dev number of the same prefix.
2. **The guard lives in `tool/test/` and the red-first form is an opt-in `RELEASE_VERSION` variable.** It is the one place `make test`, the pre-commit hook and CI already run, and a hard-coded expected version would need editing at every release.
3. **The dry runs run after the bump commit, not before it.** A dirty git state makes `liquid_shell` report a warning (§2).
4. **The hand-off is text in the plan and the PR body, not a new file.** The repo has no release document, and the commands are used once. A `docs/RELEASING.md` is left to the owner's call.
5. **The guard commit uses scope `ci` and the bump commit scope `docs`.** The allowed scopes have no `release`.
