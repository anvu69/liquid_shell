# A dropped native page-action tap says why, in debug builds (VK-1046)

Status: approved by the owner on 2026-11-11 ("duyệt").

## 1. Problem

`PagesUITests` taps the native Favourite button of the `pages` demo and waits
10 s for `heart.fill`. On CI it sometimes never comes. The tap goes native
`tapAction(at:)` → Pigeon `onPageActionTapped` → Dart
`_LiquidShellState._onNativePageAction`
(`liquid_shell/lib/src/shell/liquid_shell.dart`), and every guard on that path
returns without a word: two on the native side, nine in Dart, plus an action
with no `onPressed`. A failed run cannot tell which guard dropped the tap, or
whether the tap reached Dart at all.

Even a Dart log would not reach the job log: `tool/ios_xctest.sh` runs
`xcodebuild test-without-building`, whose output is the XCUITest runner's.
The app under test logs to the simulator's unified log, which a red XCTest run
does not save (only a stall is diagnosed, `tool/ios_sim.sh diagnose`, and that
dump keeps only the VM service line).

Evidence: `.superpowers/sdd/vk1046-investigation.md` (in the vankhan ledger
dir, not in this worktree).

## 2. Decision

### 2.1 Dart: one line per dropped tap

In debug builds only (`kDebugMode` + `debugPrint`, the package's style),
every dropped tap prints one line, every time (not once: a flake is one tap,
and a once-only key would hide the second):

```
liquid_shell: native page action tap dropped (<guard>): tab=<t> page=<p> index=<i> sfSymbol=<s>[ <state>]
```

| Guard | When | State |
|---|---|---|
| `bad index` | `page < 0`, `index < 0` or `index >= LiquidPage.maxActions` | none |
| `tab not selected` | `tab` is not the selected tab | `selected=<n>` |
| `shell route not current` | the shell's route is not current (a route above the shell) | `coveredByPush=<b> tickersOff=<b>` |
| `shell covered` | a page covers the shell (`_coveredByPush` or tickers off) | `coveredByPush=<b> tickersOff=<b>` |
| `not the top page` | the native page is not the tab's last stack record | `stack=<n or null> target=<n> standIn=<b>` |
| `page detached` | the top record has unregistered (before the post-frame refresh) | none |
| `page route not current` | the top page's route is not current, or null | `route=null` or `route=not current` |
| `no action at index` | `index >= actions.length` | `actions=<n>` |
| `symbol differs` | the action at `index` shows another symbol | `have=<symbol>` |
| `no onPressed` | the action is disabled (`onPressed == null`) | none |

The combined `tab != selected || !_routeCurrent || _covered` check splits into
three checks in the same order, so each has its own name. A tap that runs its
action logs nothing. Control flow and outcomes are unchanged: every drop still
drops, and nothing new runs. Release builds print nothing.

Test reach (`liquid_shell/test/widget/native_pages_test.dart`):

- Reachable, each with its own test: `bad index`, `tab not selected`,
  `shell route not current` (a page pushed on the root navigator above the
  shell), `shell covered` (the shell under `TickerMode(enabled: false)`, its
  route still current), `not the top page` (also under a stand-in root),
  `page route not current` (a modal sheet in the tab's navigator),
  `no action at index`, `symbol differs`, `no onPressed`. One more test:
  a tap that runs its action logs nothing.
- Not reachable from a widget test: `page detached`. A record unregisters
  when its element unmounts and the stack refresh runs after that same frame,
  and the fake delivers native events between frames, never inside one. It is
  covered by review only.

### 2.2 Swift: the two silent native guards

Under `#if DEBUG`, `NSLog` with the native prefix `[liquid_shell]` (as every
native log of the plugin; the Dart prefix is `liquid_shell:`) and the same
wording:

- `PageHostController.tapAction(at:)`: the guard splits into
  `[liquid_shell] native page action tap dropped (bad index): index=<i> actions=<n>`
  and `... (disabled): index=<i> sfSymbol=<s>`.
- The `setActions` closure in `ShellNavController` (`guard let host,
  host.actions.indices.contains(action)`):
  `[liquid_shell] native page action tap dropped (no host or bad index): tab=<t> page=<p> index=<i>`.

No new XCTest: `NSLog` output cannot be asserted from XCTest without a seam
that would exist only for the test. The existing
`NativeTabsTests.testAPageActionTapSendsAnEventAndDoesNotPop` already taps a
disabled action and an index past the last through `debugTap(.pageAction)`,
which calls `tapAction(at:)`, and asserts that nothing is sent; it stays green.
The closure guard needs a deallocated host and is not reachable from a test.

### 2.3 CI: a red XCTest run saves the app's log

`tool/ios_sim.sh` gets a subcommand:

```
tool/ios_sim.sh applog UDID LABEL SECONDS
```

It writes `IOS_DIAG_DIR/<UTC time>-<LABEL>-app.log`: `xcrun simctl spawn UDID
log show --last <SECONDS>s --style compact --predicate 'process == "Runner"
AND eventMessage CONTAINS "liquid_shell"'`, the last 2 MB of it
(`tail -c`; `IOS_APPLOG_BYTES` overrides), capped at 120 s by
`tool/with_timeout.sh`. A window that is not a number falls back to 3600 s.
Default-level lines suffice: on an iPhone 17 Pro simulator (iOS 26.5) the read
without `--info --debug` showed the example's `debugPrint` line
(`Runner[…] (Flutter) flutter: liquid_shell: …`) and both new `NSLog` lines
(`Runner[…] (Foundation) [liquid_shell] native page action tap dropped …`). The predicate keeps
the app's own process (not `RunnerUITests-Runner`) and both prefixes
(`liquid_shell:` from Dart's `debugPrint`, `[liquid_shell]` from `NSLog`). It
always exits 0; a failed read leaves a note in the file.

`tool/ios_xctest.sh` notes the time before `xcodebuild test-without-building`;
when the suite fails for any reason, a stall included, it runs `applog` with
the suite's elapsed seconds plus 60, before printing the result summary, and
keeps the suite's status. The file is a file, not a dump directory, so the
stall test's single diagnose dump stays single.

`IOS_DIAG_DIR` defaults to `liquid_shell/example/build/ios-diagnostics/`, which
the `ios-unit`, `ios-ui` and `ios-minimize` jobs already upload with
`if: always()` (`.github/workflows/ci.yaml`) as `cold-launch-<job>-a<attempt>`.
VK-1067: a red run also uploads the app log in `<job>-diagnostics`, next to
the result bundle and the crash reports
(`liquid_shell/example/build/ios-diagnostics/*-app.log`), so it is found where
the failure's screenshot is.

### 2.4 CHANGELOG

No line. The head `## 0.1.0-dev.12` is released; the repo has no Unreleased
heading, and a new version heading is written only in release prep. A
debug-only diagnostic changes no API and no behaviour.
`tool/test/release_version_test.dart` checks only that each CHANGELOG has the
pubspec version's heading, which stays true.

## 3. Verification

- `fvm flutter test test/widget/native_pages_test.dart` red first (the new
  log tests), then green; the package's whole suite green; `fvm flutter
  analyze` clean.
- `dart test tool/test/ios_xctest_test.dart tool/test/ios_sim_test.dart`
  red first, then green.
- On an own iPhone 17 Pro simulator (iOS 26.5): `tool/ios_xctest.sh` with
  `-only-testing:RunnerTests/NativeTabsTests/testAPageActionTapSendsAnEventAndDoesNotPop`
  exits 0; `tool/ios_sim.sh applog` on that simulator shows a `liquid_shell`
  `debugPrint` line of the example app.
