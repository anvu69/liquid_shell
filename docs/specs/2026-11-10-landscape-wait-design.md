# The native scope bar rotation test waits for the state it checks (VK-815)

Status: approved by the owner on 2026-11-10 ("duyệt spec và plan").

## 1. Problem

The integration test "VK-550: the native scope bar, over the results, follows the
app" (`liquid_shell/example/integration_test/native_search_test.dart:235-357`)
fails about once in nine runs on the CI leg `integration-ios-native (iPhone, iOS 26)`.
In the last 38 runs that leg failed four times, every time in this test.

After `SystemChrome.setPreferredOrientations([landscapeLeft])` (:303-306), the test
waits a fixed time (`_settle`: ten 100 ms pumps plus `pumpAndSettle`, :21-26). Then
it checks two values once:

- **A** (3 of 4 reds): the orientation is still portrait (:308-311). Before it,
  the simulator logs `Failed to change device orientation: Error
  Domain=BSActionErrorDomain Code=2 … timeout`. The Flutter engine logs that
  rejection and does not retry.
- **B** (main run 42747360006): `viewInsets.bottom` is 0 (:327-331). The rotation
  worked and the scope-bar checks passed, but the keyboard had not come back yet.
  The native field was at its resting frame (393,338, 363 wide). In green runs it
  sits above the keyboard (80,142, 662 wide, keyboard 208).

The logs cannot rule out that the field lost focus during the rotation, which
would be a real bug. The snapshot's `firstResponderIsSearch` would answer that,
but the test does not read it.

Evidence: `.superpowers/sdd/vk815-investigation.md`.

## 2. Decision

All changes are in the test file. No package code changes.

1. **A condition wait with a deadline.** A helper `_pumpUntil(tester, condition,
   {timeout = 10 s, describe})` pumps 100 ms at a time until `condition()` is true.
   At the deadline it fails with `describe()`, which reports the last values.
2. **The rotation, retried.** After the landscape request, the test waits up to
   3 s for `orientation == landscape`. If the orientation is still portrait, it
   asks again, at most twice. Each retry first changes the mask, to
   `[landscapeLeft, landscapeRight]`, and then sets `[landscapeLeft]` again,
   because the engine ignores a request that repeats the current mask. The
   implementer checks this in the Flutter 3.44.9 engine source
   (`FlutterViewController.mm`, `onPreferredOrientationsNotification` /
   `performOrientationUpdate`) and says what it found. If the engine does not
   skip repeats, a plain re-send is used instead. The final deadline is 10 s.
3. **The keyboard.** Once the orientation is landscape, the test waits up to
   10 s until `viewInsets.bottom > 0` **and** the snapshot's `fieldFrame` differs
   from its resting frame. The field is never refocused, because that would hide
   a real loss of focus.
4. **Failure messages.** Every deadline message includes the orientation,
   `viewInsets.bottom`, the field frame and `firstResponderIsSearch`. The
   `liquid_shell VK-594 landscape:` debug line also logs the number of retries
   and the time waited.
5. **The return to portrait** at the end of the test (if any is checked) uses the
   same wait.

Rejected:

- A longer fixed wait. It only makes the race rarer, and every run gets slower.
- Retrying the whole test in `tool/integration_ios_native.sh`. That would hide real
  bugs in all four targets, and the script deliberately does not do it.

## 3. Verification

1. `.githooks/pre-commit` exits 0, covering analyze and format of the test file.
2. Locally, on a freshly created iPhone 17 Pro (iOS 26.5) simulator, which is
   deleted afterwards: run `native_search_test.dart` through
   `tool/integration_ios_native.sh` with `NATIVE_TARGETS`, three times. Each run
   passes, and the log line shows the waits.
3. CI on the PR: the leg is green, then re-run twice. Each log contains the
   `VK-594 landscape:` line with its wait and retry counts.
