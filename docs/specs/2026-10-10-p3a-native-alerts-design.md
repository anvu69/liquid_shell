# liquid_shell P3a: native iOS alerts and action sheets design

- **Plane:** VK-406 (parent VK-404)
- **Date:** 2026-10-10
- **Status:** draft for the owner. The owner approves this spec and the plan `docs/plans/2026-10-10-p3a-native-alerts.md` together. Open choices are in the last section, the table "Quyết định cần chủ sản phẩm xác nhận". Each row has a recommended default, and if the owner says nothing the default applies.
- **Branch:** `VK-406-native-alerts`, from the P2 branch `VK-346-p2-native-ios` at `5e0a1e9`. P2 is not merged yet, so this branch is rebased onto `main` once P2 lands (D4).
- **Floor:** Flutter 3.44.6 / Dart 3.12 (`>=3.44.0`, `^3.12.0`), iOS deployment target 15.0, Pigeon 27.3.0 (dev, exact), `very_good_analysis` 10.3.0.
- **Sources:**
  - Owner words: "Chúng ta phải làm đủ tất cả mọi thứ thuộc về native của iOS, kể cả đến alert dialog, mọi nút bấm, item, khung search đều phải làm được như một app chạy thật", and after the P2 device test: "Dialog khi chọn unsaved changes cũng chưa phải là dialog của iOS".
  - Approved order D2 (P2 spec §14.1): ② native alerts and action sheets (P3a). D3: list rows, text fields and Flutter-content sheets stay Flutter.
  - vankhan `.superpowers/sdd/ls-liquid-decisions.md`: L3 (every glass surface goes through `LiquidGlass`, including dialogs and action sheets on Android and iOS < 26) and L6 (P3a runs in parallel with the core liquid tier; the discard-guard example uses it).
  - vankhan `.superpowers/sdd/vk404-native-ios-research.md` §1 rows 5, 9, 12, 13 and §4 phase P3a.
  - P1 spec `docs/specs/2026-10-08-p1-foundation-design.md` (§4.6 strings, §4.7 glass, §5.10 accessibility).
  - P2 spec `docs/specs/2026-10-09-p2-native-ios-design.md` (§5 the container, §6 Pigeon, §7.4 routes above the shell / Q8, §14.3 the compact hide and the bottom-inset hold).

> **Tóm tắt (cho chủ sản phẩm).** P3a làm cho hộp thoại "Discard changes?" và mọi alert, action sheet của app trở thành hộp thoại thật của iOS. App gọi một hàm duy nhất, `showLiquidAlert(context, title:, message:, actions: [...])` hoặc `showLiquidActionSheet(...)`, rồi nhận về giá trị của nút người dùng bấm qua một `Future`. Trên iOS 26 trở lên, thư viện gọi thẳng `UIAlertController` của UIKit, nên hộp thoại có Liquid Glass của hệ thống, nằm TRÊN thanh tab và sidebar native, đúng như app viết bằng Swift. Không cần platform view, và cũng không cần khoá Info.plist. Trên iPad, action sheet bật ra từ đúng nút đã bấm (popover). Trên Android và iOS < 26, thư viện tự vẽ hộp thoại bằng Flutter qua `LiquidGlass` (quyết định L3), nên tự có tầng liquid khi nhánh liquid song song merge. Chữ trên hộp thoại đều do app truyền vào. Share, haptic, chọn ngày và ô nhập chữ trong alert được đề xuất tách sang P3a-2, vì cả ba đều cần mã native cho Android còn P3a thì không. Ví dụ "Discard changes?" của example chuyển sang alert native. Kiểm thử gồm test Dart với nền tảng giả, XCTest cho phần trình bày, integration trên simulator, và XCUITest chạm thật vào nút alert. Mọi kiểm thử chỉ chạy trên simulator, không đụng máy thật.

---

## 1. Goal

1. **Real system dialogs on iOS.** On iOS 26 and later, `showLiquidAlert` and `showLiquidActionSheet` present a `UIAlertController`. It gets the system's Liquid Glass, the system's motion, haptics, VoiceOver and keyboard behaviour, and it draws above the native chrome of P2. That fixes the z-order defect P2 §7.4 could only make inert: a Flutter dialog is drawn in the Flutter view, *under* the native tab bar and sidebar.
2. **One API everywhere.** The same call draws a Flutter glass dialog through `LiquidGlass` on Android and on iOS before 26 (L3), and wherever the app asks for Flutter (`presentation: flutter`, the L4 comparison switch). The answer is the value of the chosen action, the same on every path.
3. **The example's guard uses it** (L6): "Discard changes?" in `DiscardGuardCase` and `NativeChromeCase` becomes a native alert on iOS 26.

## 2. Scope

### 2.1 In P3a (this spec and plan)

| # | Item | Notes |
|---|---|---|
| A1 | Public API: `showLiquidAlert`, `showLiquidActionSheet`, `LiquidAlertAction<T>`, `LiquidAlertActionStyle`, `LiquidDialogPresentation` | §4 |
| A2 | Platform interface: `supportsNativeDialogs`, `presentNativeDialog`, request and result types | §4.4, every member has a default |
| A3 | Pigeon `NativeDialogHostApi` (async `present`, debug hooks) in the existing Pigeon source | §6 |
| A4 | Swift `NativeDialogPresenter` + pure `DialogMath`: window choice, top-most presenter, transition wait, popover anchor, exactly-once completion | §5 |
| A5 | Flutter glass fallback: alert and action sheet (bottom sheet when compact, anchored card when regular) drawn with `LiquidGlass` | §7 |
| A6 | Interaction with native chrome: no shell change needed; documented and pinned by tests | §8 |
| A7 | Example: a new "Alerts and action sheets" case with the native/Flutter switch, and the two guard cases moved to `showLiquidAlert` | §10 |
| A8 | Tests: Dart unit/widget with a fake platform, XCTest, `flutter drive` integration, XCUITest real taps, goldens of the fallback, side-by-side screenshots | §9 |
| A9 | Docs: README section, `doc/native_dialogs.md`, CHANGELOGs, `0.1.0-dev.3` | §11 |

### 2.2 Split out: P3a-2 (recommended, Q1)

The approved order D2 puts share, haptics and the date picker in P3a. This spec recommends a second plan, **P3a-2**, for them and for text fields in alerts:

| Item | Why it is a separate plan |
|---|---|
| Share sheet (`UIActivityViewController`, iPad `sourceRect`) | Android needs its own native share intent. That means the first Kotlin method channel beyond P1's signals, and a Pigeon Kotlin output with its own drift gate and JVM tests. P3a needs no Android code at all |
| Haptics (`UINotificationFeedbackGenerator` success / warning / error, impact, selection) | Small, but Android maps them to `HapticFeedbackConstants` (CONFIRM/REJECT on API 30+) through the same new Android channel. It has nothing to show on screen, so a haptic is verified on a device. That is a different test plan from P3a's simulator-only one |
| Date / time picker (`UIDatePicker` in a popover or sheet anchored to the Flutter field) | Value round trip, locale and calendar (Gregorian only; the vnlunar picker stays Flutter, research §1 row 9), and a Flutter glass picker fallback. It is about as large as P3a itself |
| Text fields in alerts (`addTextField`, secure entry, keyboard type, "enable OK when not empty") | A native field next to Flutter's hidden text input view raises the first-responder hand-off risks of research §3 (flutter#189263, #183507). It needs a different result type (value + texts) and a Flutter `TextField` fallback. D3 keeps form text fields Flutter, and P3a-2 would reopen that question with the owner |

P3a's types leave room for all four. Text fields would be a separate function (`showLiquidTextAlert`) with its own result record, and the request type gains optional fields. Nothing here would change.

### 2.3 Non-goals

- Native sheets or popovers with **Flutter content** (D3; research §1 row 11).
- Menus (`UIMenu`, context menus). They need a native touch, so they come with the P3b/P3c controls.
- `UIAlertController` on Android or the web. Android draws the Flutter glass dialog (L3).
- Changing `LiquidShell`'s route handling (P2 §7.4). The native path does not need it (§8), and the Flutter path keeps it.
- Programmatic dismissal (`LiquidDialogController.close()`). Flutter's `showDialog` has none either, so it is left out until an app needs it (YAGNI). External dismissal is still handled (§5.4).

## 3. Approach

| Option | Verdict |
|---|---|
| **(a) Native presentation from the plugin, over Pigeon (chosen)** | `UIAlertController` presented from the top-most view controller of the engine's window. There is no platform view, so none of the platform-view costs of research §3. It works on every iOS ≥ 15, and the glass comes for free on 26. native_liquid_glass ships the same pattern, and its presenter is about 100 lines for alerts. P2's Pigeon channel and plugin already exist |
| (b) Flutter-drawn only (Cupertino/glass) | Not "the iOS dialog" the owner asked for. Under native chrome it is drawn below the tab bar and sidebar (P2 §7.4) |
| (c) Depend on native_liquid_glass's presenter | Rejected in research §2: platform-view architecture, one maintainer, a transitive SVGKit dependency, and our dependency rule (Flutter + our packages + `plugin_platform_interface` + `meta`) |

## 4. Public API (`liquid_shell`)

Every name is exported from `package:liquid_shell/liquid_shell.dart`. Every change is additive.

### 4.1 Actions and presentation

```dart
/// How an action looks. The platform decides where a cancel action sits.
enum LiquidAlertActionStyle {
  /// A plain action.
  standard,
  /// The cancel action: at most one per dialog.
  cancel,
  /// A destructive action, drawn in the error colour.
  destructive,
}

/// One button of an alert or an action sheet. [value] is what the dialog's
/// future completes with when the user picks it.
@immutable
class LiquidAlertAction<T> {
  const LiquidAlertAction({
    required this.label,
    required this.value,
    this.style = LiquidAlertActionStyle.standard,
    this.preferred = false,   // alerts only: bold on iOS, Return key; ignored by action sheets
    this.enabled = true,
  });
  // == over label, value, style, preferred, enabled.
}

/// Who draws the dialog.
enum LiquidDialogPresentation {
  /// The platform's own dialog where it has Liquid Glass (iOS 26+);
  /// the Flutter glass dialog everywhere else (Android, iOS < 26). Default (L3).
  auto,
  /// The platform's own dialog wherever it has one: also UIKit's
  /// non-glass alert on iOS 15–25 (Q2). Flutter glass elsewhere.
  system,
  /// Always the Flutter glass dialog (the L4 comparison switch).
  flutter,
}
```

### 4.2 The two functions

```dart
/// Shows an alert and completes with the chosen action's value.
///
/// Completes with the cancel action's value (or null without one) when
/// the alert is dismissed without a choice: Escape, Android back, or a
/// dismissal by the system. Completes with null if it could never be shown.
Future<T?> showLiquidAlert<T>(
  BuildContext context, {
  required String title,
  required List<LiquidAlertAction<T>> actions,
  String? message,
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
});

/// Shows an action sheet. On iPad (and on any regular-width Flutter
/// fallback) it points at [anchor]; when [anchor] is null it points at
/// [context]'s render box, so pass the tapped widget's context (a Builder
/// around the button). A tap outside completes with the cancel action's
/// value, or null without one.
Future<T?> showLiquidActionSheet<T>(
  BuildContext context, {
  required List<LiquidAlertAction<T>> actions,
  String? title,
  String? message,
  Rect? anchor,                                  // global logical coordinates
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
  LiquidShellStrings strings = const LiquidShellStrings(),
});
```

- **Values never cross the channel.** Dart sends labels and styles, and native answers with an index. Dart maps the index to `actions[index].value`, so `T` can be anything (an enum, a record, a closure).
- **Validation at the boundary** (CLAUDE.md, P1 §7). Each of these throws an `ArgumentError` synchronously, before anything is shown: no actions, more than one `cancel` (UIKit raises `NSInternalInconsistencyException` and the app crashes), more than one `preferred`, an empty or blank label. On an alert, `title` must not be blank.
- **Context use.** Theme, direction and anchor are read before the first `await`. The Flutter fallback after a native "unavailable" answer checks `context.mounted`. If the context is gone, the future completes with null and nothing is shown.

### 4.3 Strings

Every visible string is a parameter: title, message and labels. The only string the library owns is the fallback action sheet's barrier label (VoiceOver/TalkBack "dismiss"), a new field `LiquidShellStrings.dismiss` (default `'Dismiss'`). It joins `==`/`hashCode` and is additive. UIKit's alert draws no strings of its own.

### 4.4 Platform interface (`liquid_shell_platform_interface`)

```dart
abstract class LiquidShellPlatform extends PlatformInterface {
  // … P1 + P2 members …
  /// Whether this platform may present native dialogs (sync). Default: false.
  bool get supportsNativeDialogs => false;

  /// Presents a native dialog; completes when it closes, or at once with
  /// LiquidNativeDialogUnavailable. Default: unavailable(unsupportedPlatform).
  Future<LiquidNativeDialogResult> presentNativeDialog(LiquidNativeDialogRequest request) async =>
      const LiquidNativeDialogUnavailable(LiquidNativeDialogUnavailableReason.unsupportedPlatform);
}
```

New value types in `src/native_dialog.dart`, exported:

- `LiquidNativeDialogKind { alert, actionSheet }`
- `LiquidNativeDialogActionStyle { standard, cancel, destructive }`
- `LiquidNativeDialogAction { label, style, enabled }`
- `LiquidNativeDialogRequest { kind, title?, message?, actions, preferredIndex?, anchor (Rect?), tintArgb, dark, rtl, requireGlass }`. The Flutter fallback consumes the same request, so the dialog is described once (DRY).
- `LiquidNativeDialogUnavailableReason { unsupportedPlatform, osTooOld, noWindow, refused, disabledByEnvironment, channelError }`
- sealed `LiquidNativeDialogResult`: `LiquidNativeDialogChose(index)`, `LiquidNativeDialogDismissed()`, `LiquidNativeDialogUnavailable(reason)`.

The new members have defaults, so Android, web, tests and any implementation that `extends` keep compiling.

## 5. Native architecture (`liquid_shell_ios`)

### 5.1 Who presents, and from which window

```
UIWindow  (the window of THIS engine's FlutterViewController)
└─ rootViewController: ShellContainerController (P2, opted in, iOS 26)  — or the FlutterViewController itself
   └─ presentedViewController … (walk to the top, skipping one being dismissed)
        └─ presents: UIAlertController (.alert | .actionSheet)
```

- **One presenter per engine.** `LiquidShellPlugin.register` creates a `NativeDialogPresenter` beside the installer and registers it for `NativeDialogHostApi` on that engine's messenger. Each engine answers its own Dart isolate.
- **The window is the engine's own.** The presenter takes `registrar.viewController` (non-nil once the scene has connected) and its `view.window`. It never searches `connectedScenes`, so with several scenes or engines each alert lands in the window whose Dart code asked. An engine with no view controller in a window (headless, add-to-app before showing) answers `unavailable(noWindow)`, and Dart falls back (§7). P2 handles multiple scenes the same way (the first scene installs, the others keep Flutter chrome), and dialogs need no such rule.
- **Top-most presenter.** Start at `window.rootViewController` and follow `presentedViewController` while it is not `isBeingDismissed`. If the top one is in a transition (its `transitionCoordinator` is non-nil), wait for it to finish, up to 3 times, and then present. This matters for **chained alerts**: when an app shows a second alert from the first one's answer, UIKit is still dismissing the first. A plain `present` there is refused with "Attempt to present … while a presentation is in progress", and the future would hang.
- **Refusal check.** Right after `present(_:animated:)`, an accepted presentation has a non-nil `alert.presentingViewController`. If it is nil, UIKit refused, and the presenter answers `unavailable(refused)`. Dart then shows the Flutter glass dialog, so the user still gets asked.

### 5.2 Availability, in order

`DialogMath.unavailableReason` is pure and XCTest-pinned. The first fact that fails names the reason:

| # | Fact | Reason |
|---|---|---|
| 1 | env `LIQUID_SHELL_NATIVE_OFF != "1"` (P2's diagnostic switch now covers all native UI, Q3) | `disabledByEnvironment` |
| 2 | `requireGlass == false` or `#available(iOS 26.0, *)` | `osTooOld` |
| 3 | the engine's view controller is in a window | `noWindow` |

The `LiquidShellNativeChrome` Info.plist key is **not** a fact (Q3). A presentation changes nothing in the window's root, so P2 Q2's reason for an opt-in (plugins that cast the root) does not apply. Calling the function is the opt-in. An app with Flutter chrome on iOS 26 still gets the system alert, as a Swift app would.

### 5.3 Building the controller

| Request field | UIKit |
|---|---|
| `kind` | `.alert` or `.actionSheet` |
| `title`, `message` | as given (nil stays nil) |
| `actions[i]` | `UIAlertAction(title:style:)` with `.default` / `.cancel` / `.destructive`, `isEnabled`. The handler answers `chose(i)` |
| `preferredIndex` (alert only) | `preferredAction` |
| `anchor` (action sheet) | `popoverPresentationController.sourceView = flutter.view`, `sourceRect = DialogMath.sourceRect(anchor, in: flutter.view.bounds)`. With no usable anchor: the view's centre, `permittedArrowDirections = []`. Set on every idiom: iPad requires it, and iOS 26 originates sheets from their source on iPhone too (WWDC25-284) |
| `tintArgb` | `alert.view.tintColor` (Q4: the app's `colorScheme.primary`, as P2's tab bar) |
| `dark` | `overrideUserInterfaceStyle` (`.dark` / `.light`). It follows the app's theme, not the device (the VK-250 lesson in P2 §5.5) |
| `rtl` | iOS 17+: `traitOverrides.layoutDirection = .rightToLeft`. iOS 15–16 (only with `system`): `view.semanticContentAttribute = .forceRightToLeft` |

Flutter's logical coordinates are the Flutter view's points. The anchor is the tapped widget's `RenderBox` corners through `localToGlobal`, so `sourceView = flutter.view` needs no conversion. That also holds inside P2's container, where the Flutter view keeps its own frame and only gets extra safe-area insets.

### 5.4 Completing exactly once

Every path ends the Dart future exactly once. `DialogCompletion` (pure) drops every answer after the first.

| Path | Answer |
|---|---|
| A tap on action *i* (UIKit calls its handler) | `chose(i)` |
| iPhone action sheet, a tap on the dimmed area when it has a cancel action | UIKit calls the cancel handler → `chose(cancelIndex)` |
| iPad popover, a tap outside (no handler is called; the cancel action is not shown in a popover) | `UIPopoverPresentationControllerDelegate.presentationControllerDidDismiss` → `dismissed` |
| The alert dismissed by anyone else (another plugin calling `dismiss` on the root, a scene teardown) | A **lifetime sentinel**, an object attached to the alert with `objc_setAssociatedObject`. When the alert is released, its `deinit` answers `dismissed`. That is public runtime API, and it avoids subclassing `UIAlertController`, which Apple does not support |
| `present` refused | `unavailable(refused)` (§5.1) |
| Engine detach (`detachFromEngine`) | The presenter dismisses its alert without animation and answers `dismissed`. Nobody receives it, which is harmless |
| Dart hot restart while an alert is up | The old isolate's reply is dropped by the engine. The alert stays until it is tapped, and a tap only dismisses it. Debug only; documented |

Dart maps `dismissed` to the cancel action's value, or null without one. That is the same answer as Escape or Android back on the Flutter path (Q11).

### 5.5 Debug hooks (integration tests only)

`debugCurrent() → NativeDialogSnapshot?` (kind, title, message, labels, preferred index, popover source rect in Flutter view points) and `debugRespond(actionIndex)`. Index ≥ 0 runs that action's answer path, and −1 runs the outside-tap/dismiss path. Both act only on the alert this presenter showed, and they dismiss it before answering, so chained alerts work as with a real tap. Release builds return nil and ignore `debugRespond`, as with P2's `debugTap`. Real taps are covered by XCUITest (§9.4).

### 5.6 Files

| File | Responsibility |
|---|---|
| `DialogMath.swift` | Pure: availability reason, source rect, preferred index check, `DialogCompletion` |
| `NativeDialogPresenter.swift` | UIKit: window, top-most, transition wait, building, lifetime sentinel, popover delegate, debug hooks, dismiss-on-detach |
| `LiquidShellPlugin.swift` | Creates the presenter, sets up `NativeDialogHostApi`, tears it down on detach |

`UIColor(argb:)` from `NativeTabsController.swift` is reused. It is not availability-gated.

## 6. The channel

The new API goes in the **existing** Pigeon source `liquid_shell_ios/pigeons/native_shell.dart`. A second Pigeon file would generate a second `PigeonError` class in the same Swift module, which does not compile. One file keeps one generated pair and one `make pigeon-check` drift gate, and the Makefile does not change.

| Direction | Message | Payload / result |
|---|---|---|
| Dart → native (`@async`) | `present(NativeDialogRequest)` | `NativeDialogResult { outcome: chose \| dismissed \| unavailable, actionIndex?, reason? }` |
| Dart → native | `debugCurrent()` | `NativeDialogSnapshot?` |
| Dart → native | `debugRespond(int actionIndex)` | — |

`NativeDialogRequest { kind, title?, message?, actions: [NativeDialogAction{label, style, enabled}], preferredIndex?, anchor?: NativeRect{x, y, width, height}, tintArgb, dark, rtl, requireGlass }`.

Boundary checks: Dart drops an `actionIndex` outside `0..actions.length-1` (it becomes `dismissed`). Dart sends an anchor only if it is finite, and Swift checks again (`DialogMath.sourceRect`). A `PlatformException` becomes `unavailable(channelError)`, logged once in debug, and Dart falls back.

**Remembered refusals.** `osTooOld` (for `requireGlass`) and `disabledByEnvironment` cannot change while the process runs. Dart remembers them, so on iOS < 26 later calls go straight to Flutter with no channel round trip. `noWindow`, `refused` and `channelError` are not remembered. `debugResetLiquidNative()` forgets them.

## 7. The Flutter glass fallback (`liquid_shell`, Android / iOS < 26 / `flutter`)

Drawn with `LiquidGlass`, so it gets frosted today and the liquid tier from the parallel branch (L1–L3) with no change here. Reduce Transparency gives solid, and high contrast is handled by the policy. Shown with `showGeneralDialog` on the **root** navigator, so the shell's route becomes non-current and P2 §7.4 applies unchanged (§8).

### 7.1 Alert

- Centred card, `LiquidGlass(borderRadius: kAlertRadius)`. Width `min(kAlertWidth, screen − 2 × kDialogMargin)`. Title, then message, then actions. The barrier is `kDialogBarrier` and is **not** dismissible by a tap (iOS).
- **Button layout, as UIKit:** exactly two actions whose labels both fit in half the row go side by side, with the cancel action on the leading side. Otherwise every action is stacked in list order, with the cancel action last. The fit check measures with the ambient `TextScaler`, so large text stacks (`alertActionsSideBySide`, pure, unit-tested).
- **Styles:** standard is `colorScheme.primary`; destructive is `colorScheme.error`; preferred is a filled prominent capsule (`primary` / `onPrimary`); disabled is `onSurface` at 38 % and does not respond. Exact metrics come from the native alert measured in Task 4 (`docs/qa/p3a/metrics.md`) and live in `dialog_metrics.dart`.
- **Keys:** Escape picks the cancel action, if there is one. Enter / numpad Enter picks the preferred action, if it is enabled. Android back pops the route, and the result is the cancel value or null (Q6).
- **Motion:** fade + scale 1.08 → 1.0 over 250 ms (`Curves.easeOutCubic`). Under reduce motion it only fades.
- **Long content:** title and message scroll when the card would pass 80 % of the screen height. Actions stay visible below the scroll.

### 7.2 Action sheet

- **Compact width** (the screen is narrower than `LiquidShellBreakpoints().regular`, 700): at the bottom, max width `kSheetMaxWidth`, centred. One glass group holds the optional header (title, message) and the non-cancel actions stacked. A separate glass capsule below it holds the cancel action. Bottom margin = view padding bottom + 8. It slides up over 300 ms, or fades under reduce motion.
- **Regular width** (Q5): an anchored card, `kSheetPopoverWidth` wide. It sits below the anchor if it fits, else above, and is centred on the anchor horizontally and clamped to the screen with an 8pt margin. It has no cancel row, as a UIKit popover. With no anchor it sits at the screen centre.
- **Dismissal:** a barrier tap, Escape or Android back completes with the cancel value or null. The barrier has `LiquidShellStrings.dismiss` as its semantics label.

### 7.3 Accessibility and localisation

- The route is `scopesRoute` + `namesRoute` with the title (or the message) as its label, so screen readers announce it on open. Buttons are `Semantics(button: true, enabled: …)`. Focus starts on the preferred action (alert), else the first.
- Text uses the ambient `TextScaler`. It is not clamped (iOS Dynamic Type is not clamped in alerts either).
- Every string comes from the caller, plus `LiquidShellStrings.dismiss`. RTL follows `Directionality`, which also mirrors the side-by-side order.

## 8. Interaction with the native chrome (P2)

| Situation | Native dialog (iOS 26) | Flutter fallback |
|---|---|---|
| Z-order | Presented above the window's root: above the tab bar, sidebar and footer. UIKit dims and blocks the whole window | Drawn in the Flutter view, under the native chrome (P2 §7.4). P2 keeps the chrome inert, or hidden when compact |
| Shell route | Stays current: **nothing changes** in the shell's config (`interactive: true`, `hidden: false`). UIKit's dimming view takes every touch | Not current, so `interactive: false` (regular) or `hidden: true` (compact) |
| Compact bar and the bottom-inset hold (P2 §14.3) | Not triggered. The bar stays drawn under UIKit's dimming and nothing jumps. This is an improvement over P2, where the bar hid and the body held 83pt | Unchanged: the bar hides, the body behind keeps the bar's inset, and the dialog lays out against the home indicator |
| Guard (`beforeDestinationChange`) from a native tab tap | `_guardPending` makes the config `interactive: false` while the guard runs (P2 §7.3), which still closes an overlay sidebar first (Q7, keep P2). Then the native alert shows over the window | Unchanged P2 path |
| VoiceOver | The alert is modal for VoiceOver (UIKit). After it closes, focus goes back to the Flutter view; Flutter does not restore focus to the exact node (manual QA) | Flutter semantics, scoped to the route |
| Keyboard showing for a Flutter `TextField` | UIKit keeps or hides it per its own rules for a presented alert; the Flutter field keeps focus after. Manual check on the simulator (§9.5) | Unchanged |
| App lifecycle | An in-app `UIAlertController` sends no `inactive` (only system alerts do). The integration test asserts `resumed` throughout | — |

So P3a needs **no change** to `liquid_shell.dart`'s shell code. The plan pins this with a widget test: a pending native alert leaves the last config `interactive: true, hidden: false` on a compact native shell. The integration test asserts the same on the iPhone simulator.

## 9. Testing

TDD per task (red → green → commit), a review per task, and a whole-branch review at the end, as in P1/P2. Simulators only, never a physical device.

### 9.1 Dart unit

- Interface: every value type's `==` field by field; the sealed result; the default platform's `supportsNativeDialogs == false` and `presentNativeDialog → unavailable(unsupportedPlatform)` touching no channel.
- `liquid_shell_ios`: request → Pigeon mapping for every field; result mapping, including an out-of-range index → dismissed; `PlatformException` → `unavailable(channelError)`, logged once; the real channel name `dev.flutter.pigeon.liquid_shell_ios.NativeDialogHostApi.present` with `pigeonChannelCodec`; debug hooks.
- `liquid_shell` pure: `checkAlertActions` (each error), `dialogValue` (index, dismissed with or without cancel), `alertActionsSideBySide`, `alertDisplayOrder`, `sheetGroups`, `anchorOf`, `NativeDialogMemory`.

### 9.2 Widget (`liquid_shell/test/widget/`, `FakeNativePlatform` extended)

- `glass_dialogs_test.dart` (fallback): alert content; side-by-side vs stacked and the cancel position; the barrier does not dismiss an alert; Escape / Enter; disabled; reduce motion; semantics label; compact sheet with its cancel group; the barrier tap → null; regular anchored card below or above the anchor and without a cancel row.
- `liquid_dialogs_test.dart` (API): native `chose` → value and no Flutter dialog; `dismissed` → cancel value or null; `unavailable` → fallback; `osTooOld` remembered; `noWindow` not remembered; `flutter` never asks the platform; `system` sends `requireGlass: false`; every request field (tint, dark, rtl, labels, styles, preferred, enabled); anchor from the context and an explicit anchor; validation errors before any platform call; a context unmounted during the round trip → null; native alert over a compact native shell → config unchanged; the guard with a native alert.

### 9.3 Swift (XCTest, `make ios-unit`)

- `DialogMathTests`: reasons in order; `sourceRect` (inside, clipped, outside → nil, NaN/∞/negative → nil, a point → 1×1); the preferred index range; `DialogCompletion` answers once.
- `NativeDialogPresenterTests` (a window of the test host, a plain view controller standing in for Flutter): presents a `UIAlertController` with the right style, titles, action styles, enabled flags, preferred action, tint and interface style; the popover source view and rect; centre with no arrow without an anchor; `osTooOld` / `noWindow` / `disabledByEnvironment` (injected facts); `requireGlass: false` presents on an "old" OS; a second request while the first is dismissing waits and appears; an external `dismiss` answers `dismissed` once; `debugRespond` answers and dismisses; detach dismisses and answers.

### 9.4 Simulator integration

- **`flutter drive`, `integration_test/native_dialogs_test.dart`** (iPad Air 11-inch (M4) and iPhone 17 Pro, iOS 26.5, `EXPECT_NATIVE=true`):
  - a native alert round trip through `debugNativeDialog` / `debugRespondToNativeDialog` returns the value;
  - an action sheet's popover source rect equals the button's rect (±0.5pt) on iPad;
  - −1 → the cancel value;
  - a chained second alert appears;
  - the lifecycle stays `resumed`;
  - the native chrome config is unchanged while the alert is up;
  - `presentation: flutter` draws the Flutter glass alert with the chrome inert, or hidden when compact.
- **`native_shell_test.dart`'s guard test** switches to the native alert. The P2 assertion "the compact bar hides under the guard dialog" becomes "it stays" (§8).
- **XCUITest, real taps** (`example/ios/RunnerUITests`, `make ios-ui`, Q8). The app is launched with `LIQUID_SHELL_EXAMPLE_DEMO=alert|sheet|sheet-outside`, and the example shows the dialog on its own. The UI test taps the real UIKit button (`app.alerts["Discard changes?"].buttons["Discard"]`) or taps outside the popover. Dart answers by presenting a second native alert, "Result: discard", which XCUITest can see. That proves tap → UIKit handler → Pigeon reply → Dart value → a new native presentation (the chained case of §5.1) without reading Flutter semantics. It runs on the iPad and the iPhone simulator.

### 9.5 Manual (owner + Task 8 QA, simulators; the owner then checks on device)

VoiceOver on the alert and the sheet; Dynamic Type at AX5; dark mode; RTL (Arabic locale on the simulator); hardware keyboard Esc/Return; an alert while a Flutter `TextField` has the keyboard; a guard alert from the iPad overlay sidebar and from the compact bar; side-by-side screenshots of native and Flutter-liquid alerts on iPhone and iPad simulators and on the Android emulator (L5) in `docs/qa/p3a/`.

### 9.6 Goldens and CI

- `case_guard.png` is regenerated: the fallback glass alert replaces the Material `AlertDialog`. `case_alert.png` (iPhone) and `case_action_sheet.png` (iPad portrait, anchored card) are new. Only through `make goldens-update`.
- CI: `ios-unit` runs the new XCTests unchanged. `integration-ios-native` drives both targets. A new non-blocking `ios-ui` job runs XCUITest on the newest iPad and iPhone simulator.

## 10. Example

- **`lib/cases/native_alerts.dart` (`NativeAlertsCase`, id `alerts`):** a `LiquidShell` whose destinations have SF Symbols, so native chrome engages, with these controls in the body:
  - a "Draw with Flutter liquid" switch (L4) that sets `presentation: flutter`;
  - "Alert": Discard changes?, with Keep editing (cancel) and Discard (destructive);
  - "Three actions" (stacked);
  - "Action sheet", anchored to its own button through a `Builder`;
  - "Action sheet without cancel";
  - a "Result: …" line;
  - `// #docregion readme`.
  - `autorun` (from `LIQUID_SHELL_EXAMPLE_DEMO`: Dart's `Platform.environment` is empty on iOS, so `main.dart` asks the Runner over the `liquid_shell_example/launch` channel) runs one demo after the first frame and answers with a "Result: <value>" native alert, for XCUITest.
- **`discard_guard.dart` and `native_chrome.dart`:** `_confirmLeave` uses `showLiquidAlert<bool>` with "Keep editing" (cancel, `false`) and "Discard" (destructive, `true`) (L6). The README snippet follows the `docregion`.
- `kCases` gains `alerts`. `cases_smoke_test` opens it on phone and tablet, and the existing guard smoke tests keep passing through the fallback (the same texts).

## 11. Documentation and versions

- README: a feature line; a new section "Alerts and action sheets" (snippet, platform table, the native/fallback rule, the anchor tip, the result semantics); the updated guard snippet; Limitations (hot restart leaves an orphan alert in debug; system alert text follows the device's Dynamic Type, not Flutter's `TextScaler`; VoiceOver focus after the alert).
- `doc/native_dialogs.md`: §5.2 availability table, §5.4 completion table, §8 chrome table, troubleshooting by reason.
- CHANGELOGs: `0.1.0-dev.3` in all four packages (Q10). `CLAUDE.md` / `CONTRIBUTING.md`: `make ios-ui`.

## 12. Error handling

| Case | Debug | Release |
|---|---|---|
| Invalid actions or a blank alert title | `ArgumentError` at the call | same |
| `osTooOld` / `disabledByEnvironment` | remembered; Flutter fallback | same |
| `noWindow` / `refused` | Flutter fallback | same |
| `PlatformException` | `debugPrint` once per method; fallback | fallback |
| Native index out of range | — | treated as `dismissed` |
| Context unmounted before a fallback | — | null, nothing shown |
| External dismissal, detach | — | `dismissed` → cancel value or null |
| Hot restart with an alert up | orphan alert until tapped | n/a |

## 13. Risks

| Risk | Mitigation |
|---|---|
| **A future that never completes** (a refused presentation, an external dismissal, a popover dismissed outside, a chained alert presented mid-transition) | §5.4: the transition wait, the refusal check → fallback, the lifetime sentinel, and the popover delegate, all XCTest-pinned; XCUITest proves the chained case with real taps |
| **The XCUITest target in a Flutter + CocoaPods project** (the `pbxproj` edit; Flutter's build script in a UI-test build) | Created once with the `xcodeproj` gem that CocoaPods ships; `pod install` leaves it alone (not in the Podfile); the debug simulator build runs without the flutter tool. Fallback if it fails in Task 7: an idb script (local only) and the `flutter drive` debug hooks |
| **No iOS < 26 simulator runtime installed** (only 26.5 and 27.0): the `osTooOld` fallback and `system` on iOS 15–25 are only XCTest-injected | Q9: download an iOS 18.x runtime if ≥ 10 GB of disk stays free; otherwise documented as unverified on a real old OS |
| **UIKit changes action-sheet placement on iPhone (iOS 26 sources sheets from their item)** | Always set the source; the XCUITest runs on the iPhone; the screenshots go to the owner |
| **Fallback metrics drift from iOS 26** | Measured from the native alert in Task 4 and recorded; side-by-side screenshots (L5) |
| **Parallel branches**: the liquid tier (L1) changes `LiquidGlass` and goldens, and VK-405 (E1) adds SF Symbols to `discard_guard.dart` | Only `LiquidGlass(borderRadius:, child:)` is used; goldens are regenerated after each rebase; the guard edit is a small conflict, resolved at rebase |
| **Text in the system alert ignores the app's `TextScaler`** | Documented (system behaviour) |

## Quyết định cần chủ sản phẩm xác nhận

> **Chủ sản phẩm chấp nhận toàn bộ đề xuất (10/10/2026: "chốt làm cả 3 việc đi").** Riêng Q10 → 0.1.0-dev.3 hoặc dev.4 tuỳ phần nào merge trước (B16).

Mỗi dòng có đề xuất mặc định. Nếu chủ sản phẩm im lặng, đề xuất được áp dụng.

| Q# | câu hỏi | đề xuất |
|---|---|---|
| Q1 | D2 ghi P3a gồm alert, action sheet, share, haptic, chọn ngày. Có tách share, haptic, chọn ngày và ô nhập chữ trong alert sang **P3a-2** (work item Plane mới, con của VK-404) không? | **Tách.** Ba mục này cần mã native Android (kênh Kotlin đầu tiên ngoài signals của P1), còn haptic chỉ kiểm được trên máy thật. P3a giữ chỉ alert và action sheet, kiểm 100 % trên simulator. API của P3a đã chừa chỗ để thêm chúng mà không đổi gì (§2.2) |
| Q2 | iOS 15–25: mặc định vẽ hộp thoại Flutter liquid glass (L3). Có thêm tuỳ chọn `LiquidDialogPresentation.system` để app nào muốn thì dùng `UIAlertController` thật (không có glass) trên iOS cũ không? | **Có, nhưng mặc định vẫn là `auto` theo L3.** Chỉ tốn một cờ `requireGlass` trên kênh. App muốn "giống app iOS 18 thật" thì bật `system` |
| Q3 | Alert native có cần khoá Info.plist `LiquidShellNativeChrome` như khung native của P2 không? | **Không.** Hiện alert không đổi root của window, nên rủi ro plugin ép kiểu root (lý do của P2 Q2) không có. App gọi hàm là đã opt-in. Biến `LIQUID_SHELL_NATIVE_OFF=1` vẫn tắt cả alert native để chẩn đoán |
| Q4 | Màu chữ nút của alert native: theo `colorScheme.primary` của app (giống thanh tab P2) hay để màu hệ thống? | **Theo `colorScheme.primary`**, đồng bộ với thanh tab native. Nút destructive vẫn đỏ theo hệ thống |
| Q5 | Action sheet vẽ bằng Flutter ở khổ rộng (iPad < 26, tablet Android): thẻ neo cạnh nút đã bấm (như popover, không có hàng Cancel) hay sheet trượt từ đáy? | **Thẻ neo cạnh nút**, giống popover của iPad. Bấm ra ngoài thì trả giá trị Cancel |
| Q6 | Nút Back của Android khi đang mở alert Flutter: đóng alert (trả giá trị Cancel, hoặc null nếu không có Cancel) hay chặn lại như iOS? | **Đóng alert**, theo thói quen của người dùng Android. Kết quả giống bấm Cancel |
| Q7 | Bấm tab ở sidebar dạng overlay khi trang đang có thay đổi chưa lưu: giữ hành vi P2 (đóng sidebar rồi mới hỏi) hay để sidebar mở phía sau alert native? | **Giữ P2** (đóng sidebar trước). Không phải sửa code shell, và integration test của P2 vẫn đúng |
| Q8 | Test chạm thật vào nút alert: thêm target XCUITest `RunnerUITests` vào example (CI chạy được) hay dùng script idb (chỉ chạy ở máy local)? | **XCUITest.** Công cụ chuẩn của Apple, chạy được trên CI, không phải cài thêm. Nếu Task 7 không dựng được target thì mới chuyển sang idb |
| Q9 | Có tải runtime simulator iOS 18.x (khoảng 8 GB) để kiểm thật đường fallback và `system` trên iOS < 26 không? Hiện máy chỉ có 26.5 và 27.0 | **Có, nếu sau khi tải vẫn còn ≥ 10 GB trống.** Nếu không đủ chỗ, chỉ kiểm bằng XCTest giả lập và ghi rõ là chưa kiểm trên iOS cũ thật |
| Q10 | Phiên bản sau P3a? | **`0.1.0-dev.3`** cho cả bốn package, có ghi CHANGELOG; chưa publish |
| Q11 | Alert native bị đóng từ bên ngoài (plugin khác gọi dismiss, scene bị huỷ): trả về gì? | **Giá trị của nút Cancel, hoặc null nếu không có Cancel**, giống bấm Esc hay Back. Riêng trường hợp alert không hiện được thì trả null |
