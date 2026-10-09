# P2 manual QA: native iPadOS chrome (Task 5)

Simulator: iPad Air 11-inch (M4), iOS 26.5, Xcode 27.0, Flutter 3.44.6;
iPhone 17 Pro, iOS 26.5. Both created for the run and deleted after it.

The agent session that ran Task 5 had no GUI access: `simctl` has no
rotation, iPadOS 26 refuses `requestGeometryUpdate` from the app ("the
current windowing mode does not allow programmatic changes to interface
orientation"), `XCUIDevice` is for UI test bundles only, and AppleScript had
no assistive access to Simulator.app. Every check below that needs a
rotation, a gesture, VoiceOver or a window resize is left for the owner's
Task 6 pass.

| Check | Result | Evidence |
|---|---|---|
| Native pill `[sidebar \| Home \| Inbox ③ \| Settings \| ⌕]` | pass | `liquid_shell/doc/images/native_ipad_portrait.png` |
| Portrait overlay sidebar with Search, the four rows and the "Ann Lee" footer | pass | `liquid_shell/doc/images/native_ipad_sidebar.png` |
| Trailing ⌕ and footer act (native tap path, `debugTap`) | pass | `native_shell_test.dart`, iPad run `+6` |
| Push a page above the shell → native chrome hides, back after the pop | pass | `native_shell_test.dart` |
| iPhone: Flutter chrome, `notIPad` | pass | iPhone run `+6` |
| Scene destroyed and reconnected → native chrome back | pass | Task 5 report (probe with multiple scenes enabled for the probe only) |
| Portrait overlay open → content under the dimming view does not jump | not run | needs a tap on the sidebar toggle |
| Landscape → sidebar tiled, content narrows | not run | no rotation (see above); no landscape doc image yet |
| Refused guard → tapped sidebar row does not stay highlighted (Q4) | not run | needs a row tap |
| Split View ⅓ → Flutter bottom bar only | not run | needs window resizing |
| Floating window → page title clears the `•••` | not run | needs windowing; Task 1 values in `spike.md` |
| VoiceOver reads tab names, the toggle, ⌕ and the footer | not run | needs VoiceOver |
| Hot restart keeps the native chrome right | not run | needs an interactive `flutter run` |
| Same smoke on an iOS 27.0 iPad simulator | not run | Task 6 |
