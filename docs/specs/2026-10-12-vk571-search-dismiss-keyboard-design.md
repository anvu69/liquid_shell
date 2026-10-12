# VK-571: the search keyboard goes on a drag or a scope tap

Owner, testing main 60f98df on an iPhone 16 Plus in native mode: the
keyboard must also go when the user scrolls the results or taps the scope
tabs under the search field. Apple Music and Settings do this: the
keyboard goes, the query stays in the field, the search stays active
(results shown, Cancel available).

## Design

- **One command, both modes.** `LiquidSearchController.dismissKeyboard()`
  goes through the `SearchDriver` to `ShellSearch.dismissKeyboard()`, a
  no-op unless the search tab is selected and the search active.
  - Native: `NativeChromeClaim.dismissSearchKeyboard()` →
    `LiquidShellPlatform.dismissNativeSearchKeyboard()` (interface default:
    nothing; Android keeps it) → Pigeon `dismissSearchKeyboard()` →
    `NativeTabsController.dismissSearchKeyboard()` (search tab selected) →
    `SearchBridge.dismissKeyboard()`: the field resigns first responder;
    `isActive` and the text are untouched; then the field is read once
    more, so marked text the resignation commits reaches Dart once. No
    text is written: the native → Dart query bridge stays one-way.
  - Flutter: the field unfocuses with `_keyboardDown` set, so the focus
    loss keeps `active`; the phase stays `active`, the field drops to the
    bottom row with its × (`compactSearchRects` with no keyboard). The
    field takes the focus back on a tap; ×, `deactivate()` (system back
    included) and `releaseField()` (another tab, hidden chrome, the other
    size class, native chrome) end it. Unfocusing ends an IME composition
    with its text as composed; nothing is written into the field.
  - `LiquidSearchValue.active` / `LiquidSearchPhase.active` now mean "the
    search is active", with or without the keyboard, as natively.
- **Drag.** The shell's body listener (the same `NotificationListener`
  chain in both modes, now on `ScrollNotification`) hands every
  notification to `ShellSearch.onBodyScroll`: a `ScrollStartNotification`
  with drag details arms it, the first `ScrollUpdateNotification` or
  `OverscrollNotification` with drag details dismisses, once per drag.
  This is the rule of Flutter's `ScrollViewKeyboardDismissBehavior.onDrag`.
  Dismissing on the start alone was tried and rejected: a sideways swipe
  over a vertical list (the iOS edge swipe of VK-551, with the shell's back
  gesture blocked by the active search) wins that list's gesture arena
  alone and starts a drag that scrolls nothing. Programmatic scrolls have
  no drag details. `LiquidSearch.dismissKeyboardOnDrag` (default true)
  opts out.
- **Scope tap.** `LiquidSearchScopeBar` sets `scopeIndex`, then calls
  `dismissKeyboard()`. VK-550's native scope bar and
  `LiquidSegmentedControl` can call the same command.

## Tests

Dart widget tests in both modes (fake platform): `dismissKeyboard`, a
user drag, a programmatic scroll, a sideways edge swipe, a scope tap, the
opt-out, mid-composition, and what ends the kept search. XCTest of
`dismissSearchKeyboard` (keeps the search and its text, reports a
committed composition once, does nothing without an active search).
XCUITest on an iPhone: native search, type, drag the results / tap a
scope; the keyboard is gone, the field text and × stay.
