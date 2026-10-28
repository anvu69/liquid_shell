# liquid_shell VK-703: release 0.1.0-dev.9, Implementation Plan

> **Approval:** the owner approved the release decisions Q2-Q6 ("Ok hết", 2026-10-28); the spec `docs/specs/2026-10-28-release-dev9-design.md` records them. This plan implements it.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare `0.1.0-dev.9` for the first pub.dev upload: every version string moves from `0.1.0-dev.8` to `0.1.0-dev.9`, four CHANGELOGs get a `## 0.1.0-dev.9` heading, a small Dart test keeps the versions from drifting, and the last task hands the owner the publish commands. Nothing is published, tagged or pushed.

**Architecture:**

1. **Task 1.** `tool/test/release_version_test.dart`: reads the four pubspecs, the podspec, the nine sibling constraints and the four CHANGELOGs. Green at dev.8; red under `RELEASE_VERSION=0.1.0-dev.9`.
2. **Task 2.** The bump (7 files with versions, 4 CHANGELOGs), in one commit. Red to green with the Task 1 test.
3. **Task 3.** Dry runs in the four packages, the Dart part of `make verify`, and the owner hand-off.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12 through fvm (`.fvmrc`), `package:test` for `tool/test`, `flutter pub publish --dry-run`.

## Global Constraints

- Prefix every shell command with `rtk` (unknown commands pass through). Use `command rm` / `command cp` for rm/cp.
- Run `bash .githooks/pre-commit` by hand before every commit. Never `--no-verify`. Never change git config or global flutter config; never set `core.hooksPath`.
- Commit message format `<type>(<scope>): <summary> (VK-NNN)`, scopes `shell glass platform ios android example docs ci`. Every commit ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, whatever attribution hint the agent's own environment gives.
- No pushes, no remotes, no publishing. (`dart pub publish --dry-run` is allowed only where a task says so.)
- Never commit `.env` or `.superpowers/`.
- Simulators: each agent creates its own with `xcrun simctl create` and deletes it at the end. Never run `xcrun simctl shutdown all`. Never touch physical devices (no devicectl, no idb on devices). Other agents use other simulators at the same time.
- Keep disk free ≥10 GB (`df -h /`). Delete your build output at the end.
- Vietnamese IME safety: never rebuild a focused field; never write into a field while it is composing (marked text); keep the native→Dart query bridge one-way.
- CHANGELOG: follow wave2-decisions.md (R adds `## 0.1.0-dev.9`; S, F and P3b-2 put entries under a new `## 0.1.0-dev.10` heading at the top of the CHANGELOG of each package they change). Only branch R changes pubspec versions.
- Dependencies, provenance, generated-channel and goldens rules from the repo `CLAUDE.md` apply. Never loosen `analysis_options.yaml`.
- Python, if needed, with `python3 -I`. Never enter credentials.

This plan's own values:

- Version: `0.1.0-dev.9` (from `0.1.0-dev.8`). Sibling constraints: `^0.1.0-dev.9`.
- Packages, in publish order: `liquid_shell_platform_interface`, then `liquid_shell_ios` and `liquid_shell_android`, then `liquid_shell`.
- CHANGELOG text, above `## 0.1.0-dev.8` in each package: `## 0.1.0-dev.9`, a blank line, `First release on pub.dev.`, a blank line. The dev.8 text is not edited.
- Files that carry the version: the four package pubspecs (line 3 each); constraints in `liquid_shell/pubspec.yaml` (3), `liquid_shell_ios/pubspec.yaml` (1), `liquid_shell_android/pubspec.yaml` (1), `liquid_shell/example/pubspec.yaml` (3), `liquid_shell/example_go_router/pubspec.yaml` (1); `liquid_shell_ios/ios/liquid_shell_ios.podspec:3`.
- Not changed: `liquid_shell_android/android/build.gradle:2` (`1.0-SNAPSHOT`), `liquid_shell/doc/liquid.md:70` (history).
- `flutter pub publish --dry-run` runs only after the bump is committed (a dirty tree gives `liquid_shell` a warning).
- Shell note: this repo's shell is zsh with `mv`/`cp` aliased to ask before overwriting; use `command mv`, or the Python snippets below.
- The first `rtk make get` is needed once in a fresh worktree (`.dart_tool` is absent) and again after the bump, so the workspace resolves the new constraints from the local siblings.

---

### Task 1: the version guard test (VK-703)

**Files:**
- Create: `tool/test/release_version_test.dart`

**Interfaces:** none (a test). It reads files relative to the repo root, like the other `tool/test` files; `make test` runs it through `dart test tool/test`.

- [ ] **Step 1: resolve the workspace**

```bash
rtk make get
```

Expected: ends without error (`Got dependencies!` or `Resolving dependencies...` then no failure).

- [ ] **Step 2: write the test**

Create `tool/test/release_version_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

/// The four published packages, in publish order.
const packages = [
  'liquid_shell_platform_interface',
  'liquid_shell_ios',
  'liquid_shell_android',
  'liquid_shell',
];

/// Every pubspec that may depend on a sibling: the packages and both examples.
final List<String> pubspecs = [
  for (final p in packages) '$p/pubspec.yaml',
  'liquid_shell/example/pubspec.yaml',
  'liquid_shell/example_go_router/pubspec.yaml',
];

const podspec = 'liquid_shell_ios/ios/liquid_shell_ios.podspec';

/// `RELEASE_VERSION=0.1.0-dev.9 dart test tool/test/release_version_test.dart`
/// also pins the shared version, so a release bump can be run red first.
final String? expected = Platform.environment['RELEASE_VERSION'];

String read(String path) => File(path).readAsStringSync();

String pubspecVersion(String path) {
  final m = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(read(path));
  if (m == null) throw StateError('$path has no version: line');
  return m.group(1)!;
}

/// `0.1.0-dev.9` -> (`0.1.0-dev`, 9); null when it is not a dev version.
(String, int)? devParts(String v) {
  final m = RegExp(r'^(.+-dev)\.(\d+)$').firstMatch(v);
  return m == null ? null : (m.group(1)!, int.parse(m.group(2)!));
}

void main() {
  final version = pubspecVersion('liquid_shell/pubspec.yaml');

  test('the four packages share one version', () {
    for (final p in packages) {
      expect(pubspecVersion('$p/pubspec.yaml'), version, reason: p);
    }
  });

  test('the iOS podspec carries the same version', () {
    final m = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(read(podspec));
    expect(m, isNotNull, reason: '$podspec has no s.version');
    expect(m!.group(1), version);
  });

  test('every sibling constraint is ^<version>, in packages and examples', () {
    var seen = 0;
    for (final path in pubspecs) {
      for (final p in packages) {
        final m = RegExp(
          '^\\s+${RegExp.escape(p)}:\\s*(\\S+)\\s*\$',
          multiLine: true,
        ).firstMatch(read(path));
        if (m == null) continue;
        seen++;
        expect(m.group(1), '^$version', reason: '$path -> $p');
      }
    }
    // 5 in the packages (3 + 1 + 1), 3 in example, 1 in example_go_router.
    expect(seen, 9);
  });

  test('each CHANGELOG has a heading for the version, nothing older above', () {
    for (final p in packages) {
      final headings = RegExp(
        r'^## (\S+)\s*$',
        multiLine: true,
      ).allMatches(read('$p/CHANGELOG.md')).map((m) => m.group(1)!).toList();
      final at = headings.indexOf(version);
      expect(at, isNonNegative, reason: '$p/CHANGELOG.md lacks "## $version"');
      // Unreleased work may sit above it, under a newer dev heading.
      final mine = devParts(version);
      for (final above in headings.take(at)) {
        final theirs = devParts(above);
        expect(
          mine != null &&
              theirs != null &&
              theirs.$1 == mine.$1 &&
              theirs.$2 > mine.$2,
          isTrue,
          reason: '$p/CHANGELOG.md: "## $above" above "## $version"',
        );
      }
    }
  });

  test(
    'RELEASE_VERSION, when set, is the shared version',
    () {
      if (expected == null) return;
      expect(version, expected);
    },
    skip: expected == null ? 'RELEASE_VERSION not set' : false,
  );
}
```

- [ ] **Step 3: the test is green without the variable (a locker), then format and analyze**

```bash
rtk dart format tool/test/release_version_test.dart
rtk dart analyze --fatal-infos --fatal-warnings tool
rtk dart test tool/test/release_version_test.dart
```

Expected: `Formatted 1 file (0 changed)`, `No issues found!`, and `00:00 +4 ~1: All tests passed!` (four tests pass, the `RELEASE_VERSION` one is skipped with `Skip: RELEASE_VERSION not set`).

- [ ] **Step 4: red against the dev.9 expectation**

```bash
RELEASE_VERSION=0.1.0-dev.9 rtk dart test tool/test/release_version_test.dart
```

Expected: one failure, for the right reason:

```text
  RELEASE_VERSION, when set, is the shared version
  Expected: '0.1.0-dev.9'
    Actual: '0.1.0-dev.8'
00:00 +4 -1: Some tests failed.
```

Paste this run into the task's report.

- [ ] **Step 5: mutation check for the other four tests**

Each mutation is a temporary edit of a tracked file, reverted at once with `git checkout -- <file>`:

```bash
sed -i '' "s/s.version          = '0.1.0-dev.8'/s.version          = '0.1.0-dev.7'/" liquid_shell_ios/ios/liquid_shell_ios.podspec
rtk dart test tool/test/release_version_test.dart   # podspec test red: Expected: '0.1.0-dev.8' Actual: '0.1.0-dev.7'
git checkout -- liquid_shell_ios/ios/liquid_shell_ios.podspec

sed -i '' 's/liquid_shell_platform_interface: ^0.1.0-dev.8/liquid_shell_platform_interface: ^0.1.0-dev.7/' liquid_shell_ios/pubspec.yaml
rtk dart test tool/test/release_version_test.dart   # constraints test red: reason "liquid_shell_ios/pubspec.yaml -> liquid_shell_platform_interface"
git checkout -- liquid_shell_ios/pubspec.yaml

sed -i '' 's/^version: 0.1.0-dev.8/version: 0.1.0-dev.9/' liquid_shell_android/pubspec.yaml
rtk dart test tool/test/release_version_test.dart   # shared-version test red, reason: liquid_shell_android, Expected: '0.1.0-dev.8' Actual: '0.1.0-dev.9' (dev.9, not dev.7: a lower version would stop the workspace from resolving)
git checkout -- liquid_shell_android/pubspec.yaml

sed -i '' '1s/dev.8/dev.7/' liquid_shell_platform_interface/CHANGELOG.md
rtk dart test tool/test/release_version_test.dart   # CHANGELOG test red: lacks "## 0.1.0-dev.8"
git checkout -- liquid_shell_platform_interface/CHANGELOG.md
rtk git status --short
```

Expected: each of the four runs shows exactly one red test, named in its comment; `git status --short` then lists only `?? tool/test/release_version_test.dart`. Paste the four failure lines into the task's report.

- [ ] **Step 6: commit**

```bash
bash .githooks/pre-commit && git add tool/test/release_version_test.dart && git commit -m "test(ci): guard version consistency across the four packages (VK-703)

One shared version in the pubspecs and the podspec, matching sibling
constraints in packages and examples, a CHANGELOG heading for the version.
RELEASE_VERSION=<v> also pins the expected version, to run a bump red first.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Expected: `✓ pre-commit passed`, then one commit.

---

### Task 2: bump to 0.1.0-dev.9 (VK-703)

**Files:**
- Modify: `liquid_shell/pubspec.yaml`, `liquid_shell_platform_interface/pubspec.yaml`, `liquid_shell_ios/pubspec.yaml`, `liquid_shell_android/pubspec.yaml`, `liquid_shell/example/pubspec.yaml`, `liquid_shell/example_go_router/pubspec.yaml`, `liquid_shell_ios/ios/liquid_shell_ios.podspec`
- Modify: `liquid_shell/CHANGELOG.md`, `liquid_shell_platform_interface/CHANGELOG.md`, `liquid_shell_ios/CHANGELOG.md`, `liquid_shell_android/CHANGELOG.md`

**Interfaces:** none. Every `0.1.0-dev.8` in the seven version files becomes `0.1.0-dev.9` (4 versions, 9 constraints, 1 podspec line: 14 occurrences); each CHANGELOG gains the heading.

- [ ] **Step 1: red (the test of Task 1 under the dev.9 expectation)**

```bash
RELEASE_VERSION=0.1.0-dev.9 rtk dart test tool/test/release_version_test.dart
```

Expected: the red of Task 1 Step 4 (`Expected: '0.1.0-dev.9'`, `Actual: '0.1.0-dev.8'`, `+4 -1`).

- [ ] **Step 2: bump the versions, constraints and podspec**

```bash
python3 -I - <<'PY'
files = [
    'liquid_shell/pubspec.yaml',
    'liquid_shell_platform_interface/pubspec.yaml',
    'liquid_shell_ios/pubspec.yaml',
    'liquid_shell_android/pubspec.yaml',
    'liquid_shell/example/pubspec.yaml',
    'liquid_shell/example_go_router/pubspec.yaml',
    'liquid_shell_ios/ios/liquid_shell_ios.podspec',
]
total = 0
for f in files:
    s = open(f).read()
    n = s.count('0.1.0-dev.8')
    assert n > 0, f
    total += n
    open(f, 'w').write(s.replace('0.1.0-dev.8', '0.1.0-dev.9'))
assert total == 14, total
print('replaced', total)
PY
```

Expected: `replaced 14`. Then:

```bash
RELEASE_VERSION=0.1.0-dev.9 rtk dart test tool/test/release_version_test.dart
```

Expected: still red, now for the CHANGELOGs (the prototype printed `liquid_shell_platform_interface/CHANGELOG.md lacks "## 0.1.0-dev.9"` and `Expected: a non-negative value  Actual: <-1>`), with the version, podspec and constraint tests green. This is the proof that the guard sees a half-done bump.

- [ ] **Step 3: add the CHANGELOG headings**

```bash
python3 -I - <<'PY'
for p in ['liquid_shell_platform_interface', 'liquid_shell_ios',
          'liquid_shell_android', 'liquid_shell']:
    f = p + '/CHANGELOG.md'
    s = open(f).read()
    assert s.startswith('## 0.1.0-dev.8\n'), f
    open(f, 'w').write('## 0.1.0-dev.9\n\nFirst release on pub.dev.\n\n' + s)
PY
head -6 liquid_shell_ios/CHANGELOG.md
```

Expected first lines: `## 0.1.0-dev.9`, empty, `First release on pub.dev.`, empty, `## 0.1.0-dev.8`, empty.

- [ ] **Step 4: green**

```bash
RELEASE_VERSION=0.1.0-dev.9 rtk dart test tool/test/release_version_test.dart
rtk dart test tool/test/release_version_test.dart
rtk make get
rtk grep -rIn "dev\.8" . --exclude-dir=.git --exclude-dir=docs --exclude=CHANGELOG.md --exclude-dir=.dart_tool --exclude-dir=build
```

Expected: `00:00 +5: All tests passed!` with the variable; `+4 ~1: All tests passed!` without; `make get` resolves with no error; the last search prints nothing (every remaining `dev.8` is in a CHANGELOG or under `docs/`).

- [ ] **Step 5: the constraint mutation (locker check)**

```bash
sed -i '' 's/liquid_shell_ios: ^0.1.0-dev.9/liquid_shell_ios: ^0.1.0-dev.8/' liquid_shell/example/pubspec.yaml
rtk dart test tool/test/release_version_test.dart
sed -i '' 's/liquid_shell_ios: ^0.1.0-dev.8/liquid_shell_ios: ^0.1.0-dev.9/' liquid_shell/example/pubspec.yaml
rtk dart test tool/test/release_version_test.dart
```

Expected: the first run is red (`liquid_shell/example/pubspec.yaml -> liquid_shell_ios`), the second green. Paste both into the report. `rtk git diff --stat` then shows 11 files changed.

- [ ] **Step 6: commit**

```bash
bash .githooks/pre-commit && git add liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android && git commit -m "chore(docs): bump the four packages to 0.1.0-dev.9 (VK-703)

Versions, sibling constraints (packages and both examples), the iOS podspec,
and a '## 0.1.0-dev.9: First release on pub.dev.' heading above dev.8 in each
CHANGELOG. Nothing is published or tagged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Expected: `✓ pre-commit passed`, then one commit. Check `rtk git status --short` is empty before Task 3.

---

### Task 3: dry runs, verify, and the owner hand-off (VK-703)

**Files:** none changed. This task only runs checks and writes the hand-off into the PR body and the final report.

**Interfaces:** none.

- [ ] **Step 1: dry run in each package, with a clean tree**

```bash
rtk git status --short   # must print nothing
for p in liquid_shell_platform_interface liquid_shell_ios liquid_shell_android liquid_shell; do
  echo "-- $p"; (cd $p && flutter pub publish --dry-run 2>&1 | grep -E "warning|Failed|rror"); done
```

Expected, four times: `Package has 0 warnings.` (the prototype printed it for all four at this commit). `dart pub publish --dry-run` uploads nothing. If `liquid_shell` shows "checked-in files are modified in git", the tree is dirty: commit or revert, then rerun. `rtk make publish-check` does the same loop (it can take a few minutes).

- [ ] **Step 2: the Dart part of `make verify`**

```bash
rtk make format-check analyze provenance public-docs
rtk dart test tool/test
rtk make pigeon-check
```

Expected: `Analyzing ... No issues found!`, `✓ provenance clean`, `✓ glass seam clean`, `✓ public docs clean`, `All tests passed!` (the prototype: `+185 ~1`), `✓ pigeon output matches its source`. Then, where the machine allows, run `rtk make verify` from the repo root and paste its output in the PR; a red only at the eight `liquid_golden` band images is the machine's known state and is reported, not fixed. The Flutter test, coverage, golden and Impeller targets were not run for this plan's prototype: no `lib/` or native file changes, so CI's run is the evidence there.

- [ ] **Step 3: the hand-off (text for the PR body and the final report; run nothing of it)**

> **Owner hand-off: publishing 0.1.0-dev.9.** Claude does not run any of this.
>
> **Before the first upload.**
> 1. Merge the PR into `main` first. pub.dev checks `repository` against GitHub `main`, and the bump must be there.
> 2. `git switch main && git pull` in a clean checkout of the merge commit. `git status --short` must be empty.
> 3. Open `https://pub.dev/publishers/lasoai.vn/admin` and confirm the Google account you will upload with is an admin. If the saved login is not that account: `dart pub logout` then `dart pub login`.
> 4. A published version cannot be deleted or reused, only retracted. The number is final.
>
> **Publish, in this order** (each command asks `Do you want to publish ... (y/n)?`: answer `y`; do not pass `--force`). After each one, wait until `https://pub.dev/packages/<name>/versions` lists `0.1.0-dev.9` (a minute or two) before the next.
>
> ```bash
> cd liquid_shell_platform_interface && flutter pub publish
> cd ../liquid_shell_ios && flutter pub publish
> cd ../liquid_shell_android && flutter pub publish
> cd ../liquid_shell && flutter pub publish
> ```
>
> `liquid_shell_ios` and `liquid_shell_android` both depend only on the interface, so their order is free, but both come before `liquid_shell`. Do not publish from `liquid_shell/example` or `example_go_router` (`publish_to: none`).
>
> **Transfer to the publisher.** For each of the four packages, open `https://pub.dev/packages/<name>/admin`, find "Publisher", choose `lasoai.vn`, and confirm. The order of the four does not matter. Check that each package page then shows the verified-publisher badge.
>
> **Then tell Claude "published".** On that word, Claude creates one tag `v0.1.0-dev.9` on the merge commit and a GitHub pre-release for it (`gh release create v0.1.0-dev.9 --prerelease --title "0.1.0-dev.9" --notes "First release on pub.dev."`), and opens the small follow-up PR that makes the three informational pana steps in `.github/workflows/ci.yaml` blocking. Claude pushes the tag only on your word.

- [ ] **Step 4: leave the tree clean**

```bash
rtk git status --short
rtk git log --oneline -3
```

Expected: empty status; the log shows the Task 2 and Task 1 commits on top of the spec and plan commits. Nothing was pushed, tagged or published.

---

## After the tasks

- PR to `main` linking Plane VK-703 and VK-681, with the Task 3 dry-run lines, the `make verify` output, and the hand-off text of Task 3 Step 3.
- The PR must merge before the owner publishes. S, F and P3b-2 branches merge `main` into themselves afterwards and keep their entries under `## 0.1.0-dev.10`.
