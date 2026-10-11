# Native alerts and action sheets

`showLiquidAlert` and `showLiquidActionSheet` ask the user a question and
complete with the value of the action they picked. On iOS 26 and later the
system draws the dialog: a `UIAlertController`, with Liquid Glass, above
the native tab bar and sidebar. Everywhere else Flutter draws a glass
dialog with `LiquidGlass`, the same glass as the shell: liquid where the
shell is liquid, frosted or solid where it falls back. The call and the
answer are the same on every path.

## When the system draws the dialog

Who draws it depends on `presentation`:

| | iOS 26+ | iOS 15–25 | Android, web, desktop |
|---|---|---|---|
| `auto` (default) | `UIAlertController` (glass) | Flutter glass | Flutter glass |
| `system` | `UIAlertController` (glass) | `UIAlertController` | Flutter glass |
| `flutter` | Flutter glass | Flutter glass | Flutter glass |

On iOS, the plugin then checks these facts in order. The first one that
fails names the reason, and Flutter draws the glass dialog instead:

| # | Fact | Reason when it fails |
|---|---|---|
| 1 | The environment variable `LIQUID_SHELL_NATIVE_OFF` is not `1` | `disabledByEnvironment` |
| 2 | The request does not need glass (`system`), or iOS is 26 or later | `osTooOld` |
| 3 | The engine's view controller is in a window | `noWindow` |

No Info.plist key is needed. The `LiquidShellNativeChrome` key turns on
the native tab bar and sidebar only: a dialog changes nothing in the
window's root, so calling the function is the opt-in. An app with Flutter
chrome on iOS 26 still gets the system alert, as a Swift app would.

`osTooOld` and `disabledByEnvironment` cannot change while the app runs,
so after the first one, later calls go straight to Flutter with no
platform round trip.

## How the answer is decided

Every dialog completes exactly once, whatever closes it:

| Path | Answer |
|---|---|
| A tap on an action | That action's value |
| iPhone action sheet: a tap on the dimmed area, with a cancel action | The cancel action's value (UIKit calls its handler) |
| iPad popover: a tap outside (UIKit shows no cancel row in a popover) | Dismissed |
| The dialog dismissed by someone else (another plugin dismissing the root, a scene closing) | Dismissed |
| Another presentation is mid-transition (a second alert opened from the first one's answer) | The dialog waits for the transition to end, up to three times, and is then shown |
| UIKit refuses the presentation (another one is stuck mid-transition) | The Flutter glass dialog is shown instead, and its answer counts |
| The engine detaches | Dismissed (nobody is listening) |
| Escape, Android back, a tap on a Flutter sheet's barrier | Dismissed |

The value the future completes with:

- **A chosen action:** its `value`. Values never cross the platform
  channel (Dart sends labels and styles, the platform answers with an
  index), so `T` can be anything: an enum, a record, a closure.
- **Dismissed:** the cancel action's `value`, or null when there is no
  cancel action.
- **Never shown:** null. That happens when the context is unmounted while
  the platform answered "unavailable", before the Flutter fallback could
  be pushed.

Validation runs first and throws `ArgumentError` synchronously, before
anything is shown, for:

- no actions;
- more than one `cancel` action (UIKit would crash);
- more than one `preferred` action, or a disabled preferred action;
- a blank label;
- no enabled action (an alert has no tap-outside, so it could never close);
- a blank `title` on an alert.

## With native chrome

| Situation | Native dialog (iOS 26) | Flutter glass dialog |
|---|---|---|
| Z-order | Presented above the window's root: above the tab bar, sidebar and footer. UIKit dims and blocks the whole window | Drawn in the Flutter view, under the native chrome. The shell keeps the chrome inert, or hidden when compact |
| Shell route | Stays current. Nothing changes in the shell's chrome config (`interactive: true`, `hidden: false`); UIKit's dimming view takes every touch | Not current, so the chrome is `interactive: false` (regular) or `hidden: true` (compact) |
| Compact bar and its bottom inset | Not touched. The bar stays drawn under UIKit's dimming, and nothing jumps | The bar hides, the body behind keeps the bar's inset, and the dialog lays out against the home indicator |
| Guard (`beforeDestinationChange`) from a native tab tap | While the guard runs the chrome ignores touches, which still closes an overlay sidebar first. Then the native alert shows over the window | Unchanged |
| VoiceOver | The alert is modal for VoiceOver. After it closes, focus goes back to the Flutter view; Flutter does not restore it to the exact node | Flutter semantics, scoped to the dialog's route |
| Keyboard up for a Flutter `TextField` | UIKit keeps or hides it by its own rules for a presented alert; the field keeps focus afterwards | Unchanged |
| App lifecycle | An in-app `UIAlertController` sends no `inactive` (only system alerts do): the app stays `resumed` | — |

## Accessibility and languages

- The Flutter dialog's route is a named, scoped route whose label is the
  title (or the message), so screen readers announce it when it opens.
  Its buttons are semantic buttons with their enabled state. Focus starts
  on the preferred action of an alert, else on the first action.
- The Flutter dialog follows the ambient `TextScaler`, unclamped, as iOS
  does not clamp Dynamic Type in alerts. Large text stacks the two
  side-by-side buttons.
- The system alert follows the **device's** Dynamic Type setting, not
  Flutter's `TextScaler`. An app that scales its text in Flutter does not
  scale UIKit's alert.
- Every visible string comes from you: title, message and labels. The only
  string the library owns is the Flutter sheet's barrier label for screen
  readers, `LiquidShellStrings.dismiss` (default `'Dismiss'`). UIKit's
  alert draws no strings of its own; what it adds for VoiceOver (hints)
  follows the device language.
- Right-to-left follows `Directionality` in both dialogs. The system alert
  gets the app's direction and light or dark style, not the device's.

## Troubleshooting

When the system dialog does not appear, the plugin answered with a
`LiquidNativeDialogUnavailableReason` and Flutter drew the glass dialog
instead. The user is still asked.

| Reason | Cause | Fix |
|---|---|---|
| `unsupportedPlatform` | Android, web, desktop, or a test without the iOS plugin | Nothing: the Flutter glass dialog is the design there |
| `osTooOld` | iOS before 26 with `presentation: auto` | Expected. Pass `presentation: LiquidDialogPresentation.system` for UIKit's non-glass alert on old iOS |
| `noWindow` | The engine's view is not in a window: a headless engine, or an add-to-app engine whose Flutter view is not shown yet | Show the dialog once the Flutter view is on screen |
| `refused` | UIKit refused to present, because another presentation was stuck (presented and never finished its transition) | Find the view controller that stays mid-presentation (often another plugin). The Flutter dialog covers this case meanwhile |
| `disabledByEnvironment` | The app runs with `LIQUID_SHELL_NATIVE_OFF=1` (the diagnostic switch for every native UI of this package) | Remove the variable from the scheme or launch environment |
| `channelError` | The platform channel call failed: the iOS plugin is not registered, or registered twice. Logged once in debug | Rebuild the iOS app (`flutter clean`, `pod install`), and check that `GeneratedPluginRegistrant` registers `LiquidShellPlugin` |

## Known limits

- **Hot restart with an alert up** leaves an orphan alert in debug builds:
  the old Dart isolate is gone, so its answer is dropped. A tap only
  closes it. Release builds have no hot restart.
- **The root `Navigator` disposed with the Flutter glass dialog up**
  (for example the whole app widget replaced): the future never
  completes, as with Flutter's `showDialog`. Popping or removing the
  route is fine: that completes it with the cancel value.
- **VoiceOver focus** goes back to the Flutter view after a system alert,
  not to the node that was tapped.
- **No text fields in alerts.** `addTextField` (secure entry, keyboard
  type) is planned for P3a-2, with share, haptics and a date picker.
- **iOS before 26** is verified by XCTest with the OS version injected, not
  on a real iOS 15–25 runtime: the installed Xcode offers no older
  simulator runtime to download.
