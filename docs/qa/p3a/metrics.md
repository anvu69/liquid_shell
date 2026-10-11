# P3a: native iOS 26.5 dialog metrics (VK-406 Task 4)

Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5. Probe: the
geometry of `UIAlertController.view` and every subview, logged after presentation.
The alert was rechecked on an iPhone 17 Pro with iOS 27.0, and every number
matched.

The probe dialog is the brief's: title "Discard changes?", message "Your edits
will be lost.", then "Keep editing" (`.cancel`) and "Discard" (`.destructive`).
The variants add "Share" (`.default`, 3 actions) and a preferred action. The
action sheet sets `sourceView`/`sourceRect` on every idiom, as
`NativeDialogPresenter` does (spec §5.3).

| Metric | iPhone alert | iPad alert | iPhone sheet | iPad popover | constant |
|---|---|---|---|---|---|
| card width (pt) | 320 | 320 | 240 (a popover, see below) | 288 | kAlertWidth / kSheetMaxWidth / kSheetPopoverWidth |
| corner radius (pt) | 34 | 34 | ≈ 32 (popover) | ≈ 32 | kAlertRadius / kSheetRadius |
| title size / weight | 17 / Semibold | 17 / Semibold | 17 / Semibold | 17 / Semibold | kTitleFontSize |
| message size | 15 Regular | 15 Regular | 15 Regular | 15 Regular | kMessageFontSize |
| action height (pt) | 48 | 48 | 48 | 48 | kActionHeight |
| gap between actions (pt) | 8 | 8 | 8 | 8 | kActionGap |
| two actions: cancel leading? | yes | yes | n/a | n/a | alertDisplayOrder |
| preferred action filled? | standard: yes (tint); destructive: no, bold only | same | n/a | n/a | GlassDialogButton.prominent |

Screenshots: native-iphone-alert.png, native-ipad-alert.png,
native-iphone-sheet.png, native-ipad-sheet.png, and
native-iphone-alert-preferred.png (a preferred standard "OK", filled).

## Details behind the table

**Alert card** (iPhone and iPad are identical):

- Card 320 × 159.3, `cornerRadius` 34. Fill: UIKit's glass `_UIAlertBackground`.
- Title label: x + 30 from the card edge, width 260, top 24 below the card
  top. Text is **leading-aligned**, not centred. Title is `labelColor`, the
  message is `secondaryLabelColor`.
- From the title's line box to the message's line box: 7.3. From the message's
  line box to the actions: 18.7.
- Actions: a stack inset 16 from the left, right and bottom edges, 288 wide.
  Each capsule is 48 high with radius 24, filled with `tertiarySystemFillColor`.
  Labels are 17pt **Medium**. The cancel label is also Medium; it is not bold.
- Two actions that fit sit side by side at 140 each with an 8 gap. The cancel
  action ("Keep editing") is on the leading side, whatever its list position.
- Three actions are stacked in list order, with the cancel action moved last:
  Discard, Share, Keep editing.
- Preferred action: the label becomes **Semibold**. For a `.default` action,
  the capsule is filled with the tint colour (`systemBlue`, or the
  `view.tintColor` when it is set: `systemGreen` in the tint variant). A
  preferred `.destructive` action is **not** filled; it keeps the plain
  capsule and the red label.
- Label colours: standard and cancel labels are `labelColor`, and destructive
  is red. Even with `view.tintColor` set, a non-preferred standard label stays
  `labelColor`. See "Divergences" below.

**Action sheet with a source, as the presenter shows it:** it is a **popover**
on every idiom on iOS 26 (WWDC25-284).

- iPhone: 240 wide. iPad: 288 wide, with a 13pt arrow (`_UIPopoverView` is
  301 wide).
- No cancel row on either. The cancel action is not drawn, and a tap outside
  dismisses.
- Inside, the layout matches the alert: labels 30 from the edge and 24 from the
  top, actions inset 16, height 48, radius 24.
- `_UIPopoverDimmingView` is clear: a popover does not dim the screen.
- The popover's corner comes from a shape layer, and its `cornerRadius` reads
  0. From the 2× screenshot, the corner arc spans about 65 px, so ≈ 32pt.

**Action sheet without a source on iPhone** (probed for the compact metrics;
`PROBE_NOANCHOR`): iOS 26.5 and 27.0 draw a **centred 320pt card** with the
alert's metrics, and both actions sit side by side, cancel leading. No
bottom-attached sheet exists any more. That means the compact sheet's side
margin, the bottom group radius and the cancel group's gap **cannot be
measured** on iOS 26. `kSheetMaxWidth` (420) and `kSheetSideMargin` (8) keep
the brief's starting values.

## Constants (liquid_shell/lib/src/dialogs/dialog_metrics.dart)

| Constant | Value | Source |
|---|---|---|
| kAlertWidth | 320 | measured (was 300) |
| kAlertRadius | 34 | measured |
| kAlertPadding | LTRB(16, 24, 16, 16) | measured: actions inset 16, header top 24 |
| kAlertHeaderInset (new) | 14 | measured: labels at 30 = 16 + 14 |
| kTitleFontSize / kMessageFontSize | 17 / 15 | measured |
| kTitleMessageGap | 7 | measured 7.3 between UIKit line boxes |
| kHeaderGap | 19 | measured 18.7 |
| kActionFontSize | 17 (Medium; Semibold when preferred) | measured |
| kActionHeight / kActionGap | 48 / 8 | measured |
| kActionFillAlpha | 0.12 | `tertiarySystemFill` light is (118, 118, 128) at 12 % |
| kSheetPopoverWidth | 288 | measured iPad popover (was 320) |
| kSheetRadius | 32 | estimated from the screenshot (was 28) |
| kSheetGroupPadding | 16 | measured: popover actions inset 16 |
| kSheetHeaderPadding | LTRB(14, 8, 14, 19) | gives the measured 30 / 24 / 18.7 inside the group padding |
| kActionLabelPadding, kDialogMargin, kSheetMaxWidth, kSheetSideMargin, kAnchorGap, durations, scales, kDialogBarrier | brief | not measurable from the view tree |

## Divergences kept on purpose (owner's call)

1. **Standard label colour.** Natively it is `labelColor`, but spec §7.1 says
   `colorScheme.primary`. The fallback follows the spec.
2. **Compact sheet.** iOS 26 has no bottom sheet: with a source it draws a
   popover, without one a centred card. The fallback keeps spec §7.2 and
   owner decision A5: a bottom sheet with the cancel action apart when compact,
   and an anchored card when regular.
3. **Popover dimming.** The native popover does not dim. The fallback's
   barrier uses `kDialogBarrier` for every kind (brief).
4. **Anchor gap.** Native has a 13pt arrow. The fallback has no arrow and
   keeps an 8pt gap (`kAnchorGap`).

## Changes to the brief's code that follow from the measurements

- `GlassDialogButton`: a preferred **destructive** action is not filled. The
  label is bold only, as on iOS 26. The cancel action is not emphasised
  (UIKit draws it Medium, like the others). Pinned by the widget tests
  "the preferred action is filled with the primary colour" and "the
  preferred action is not filled when destructive".
- `DialogHeader`: title and message are leading-aligned
  (`TextAlign.start`), not centred.
- `GlassAlert`: the header has an extra `kAlertHeaderInset` of horizontal
  padding.
- `alertDisplayOrder` is unchanged: the native alert puts cancel leading when
  side by side, and last when stacked.
