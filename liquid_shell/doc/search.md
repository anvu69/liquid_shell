# The search tab

Search in `liquid_shell` is a tab, as in Apple Music: one destination with
the search role, a field that the shell draws, and a page of your own for
the categories, the live results and the recent searches. On iOS 26 with
[native chrome](native_chrome.md) the field is UIKit's own `UISearchTab`;
everywhere else the shell draws the same states in glass.

## API

**The destination.** Give the last destination
`role: LiquidDestinationRole.search`, and the shell a `LiquidSearch`:

```dart
LiquidShell(
  destinations: const [
    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    ),
    LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
    ),
  ],
  selectedIndex: index,
  onDestinationSelected: (i) => setState(() => index = i),
  search: LiquidSearch(controller: search, placeholder: 'Songs, places'),
  body: IndexedStack(index: index, children: [home, searchPage]),
)
```

The shell checks in debug that there is at most one search destination,
that it is the last one and placed everywhere, that `search` is set exactly
when it exists, and that there is no `tabBarTrailing` with it (both would
be the trailing ⌕). In release the first search destination wins and a
missing `search` gets an internal controller. Selecting the search tab goes
through `beforeDestinationChange` and `onDestinationSelected` like any
other tab; `selectedIndex` equal to its index means it is selected. A
search destination needs no `sfSymbol`: UIKit draws its own magnifying
glass, and your symbol replaces it when you give one.

**`LiquidSearch`** is the field's configuration:
- `controller`: the query, the active state and the scope (below).
- `placeholder`: the empty field's text. Null: the platform's own,
  "Search" in the device language natively, and
  `LiquidShellStrings.searchPlaceholder` in the Flutter field.
- `onChanged`: every text change the user makes, IME composition included.
  It is not called for text the app sets through the controller.
- `onSubmitted`: the user pressed the keyboard's Search key.
- `dismissKeyboardOnDrag` (default true): a user drag on the shell's body
  puts the keyboard away while the search is active (below).

**`LiquidSearchController`** is a `ValueNotifier<LiquidSearchValue>`. The
app creates it, keeps it alive at least as long as the shell, and disposes
it; the shell never does. Giving the shell another controller between
builds is fine: the shell re-attaches.

| Member | What it does |
|---|---|
| `text` (get, set) | The field's text. Setting it shows it in the field (natively once no IME composition is in progress) and does not call `onChanged`. The same text is a no-op |
| `scopeIndex` (get, set) | The selected scope, for `LiquidSearchScopeBar` |
| `isActive` | Whether the search is active: the field has focus, or its keyboard was put away and the search stays up with its × |
| `activate()` | Focuses the field, only while the search tab is selected (otherwise ignored, with one debug line). Unfocuses any Flutter text field first |
| `deactivate()` | Ends the search: unfocuses the field and keeps the text |
| `dismissKeyboard()` | Puts the keyboard away and keeps the search active, its text and its ×. Only while active |
| `clear()` | Empties the text and keeps the focus |

`LiquidSearchValue` carries `text`, `composing` (an IME composition is
open), `active` (the search is active) and `scopeIndex`. `active` and `composing` belong to the
field: the app reads them and changes the focus with `activate` and
`deactivate`.

**`LiquidSearchPhase`** is where the search is: `idle` (another tab),
`selected` (the search tab, not searching) and `active` (searching: the
field has focus, or the keyboard was put away and the × still shows).
Read it from `LiquidShellScope.of(context).searchPhase`; it is null for a
shell without a search tab.

**`LiquidSearchScopeBar(controller:, scopes:)`** is a glass segmented
control for search scopes ("All | Songs | Places"), bound to the
controller's `scopeIndex`. Flutter draws it on every platform. Put it at
the top of the search page's content while the phase is `active`, as Apple
Music does. A tap on a scope selects it and puts the keyboard away
(`dismissKeyboard()`); the search stays active.

## Phases per platform

Selecting the search tab never focuses the field (the keyboard stays down,
as in Apple Music and as the HIG asks on iPad); a tap on the field, or
`controller.activate()`, does.

**iPhone.**

| Phase | iOS 26, native | Glass (iOS before 26, Android, no native chrome) |
|---|---|---|
| `idle` | The glass tab pill, and a separate ⌕ circle beside it | The pill, and a 62pt ⌕ circle 8pt after it |
| `selected` | UIKit's morph: the pill collapses to one circle with the previous tab's icon, the ⌕ becomes a 48pt field; the large title "Search" | The same morph in Flutter (350 ms, none under reduce motion): a 48pt circle and the field in the bottom row |
| `active` | The field rides 8pt above the keyboard with a × circle; the circle and the title hide | The field above the keyboard with a × circle |
| × | Clears the text and goes back to `selected` | Clears the text and unfocuses |
| The circle | Back to the previous tab, through your guard | The same |

On iOS 27 the ⌕ is the prominent tab; on iOS 26 it is UIKit's search tab.

**iPad.**

| Phase | iPadOS 26, native | Glass (regular width) |
|---|---|---|
| `idle` | Search is a tab: in the top tab bar, the first sidebar row, or (narrow window) the bottom bar | A cell of the top bar, the last sidebar row |
| `selected` | A small title "Search" and a full-width field on the row below it | A 44pt field one row below the top bar |
| `active` | The field rises into the title row, with ⓧ; the keyboard covers the bottom | The top bar fades out and the field moves into its row |

A narrow iPad window keeps the stacked top field natively. The glass
fallback decides by width only, so there a narrow window gets the iPhone
layout. iPadOS 26 always shows the ⌕ apart from the bar in a narrow
window; iPadOS 27 puts it inside the bar.

## The keyboard goes, the search stays

As in Apple Music and Settings, the keyboard is put away and the search
stays active (the query, the results, the × and Cancel) when:

- **The user drags the results.** The shell watches its body's scroll
  notifications: the first scroll of a user drag (a `ScrollUpdate` or
  `Overscroll` notification with drag details, the rule of Flutter's
  `ScrollViewKeyboardDismissBehavior.onDrag`) calls `dismissKeyboard()`,
  once per drag, while the search is active, as soon as the finger has
  moved at least as far along the list's axis as across it. Every
  scrollable in the search page does it, nested ones and pages pushed in
  the tab included; you add nothing. A programmatic scroll (`jumpTo`,
  `animateTo`) has no drag details and keeps the keyboard. So does a
  near-horizontal swipe over a vertical list, such as the iOS edge swipe:
  it may scroll the list by the thumb's drift, but it moves mostly across
  it. Opt out with `LiquidSearch(dismissKeyboardOnDrag: false)`.
- **The user taps a scope** of `LiquidSearchScopeBar`.
- **The app calls `controller.dismissKeyboard()`**, for a control of its
  own (a filter chip, a custom scope bar).

Natively the field resigns first responder: UIKit's search stays
presented, nothing is written into the field, and marked text the
resignation commits reaches `onChanged` once. In the Flutter field the
field unfocuses, which ends an IME composition with its text as composed
(Vietnamese diacritics included) and writes nothing; the phase stays
`active`, the field moves down to the bottom row with its × (on a
regular width it keeps the bar row and its inline ×). A tap on the
field brings the keyboard back; × clears and ends the search;
`deactivate()`, system back, another tab or hidden chrome end it and keep
the text.

Natively, an iPhone shows the active search with the keyboard down as
UIKit's × beside the field; an iPad has no ×: its stacked field stays
risen into the title row, with its ⓧ for the kept text.

## The controller is the truth

The app owns the controller, so the query lives as long as you keep it,
whatever the tabs do.

- **No echo.** The user's edits reach the controller and `onChanged`; they
  never go back to the field. Only text the app sets (`controller.text =`,
  `clear()`) is sent to the field.
- **× clears.** The user's × clears the text for good, as UIKit's does,
  and ends the search.
- **The query is kept across tab switches.** Leaving the search tab (or a
  dialog over it) unfocuses the field and keeps the text; coming back shows
  it again. UIKit empties its field when the tab is left: the shell does
  not pass that on, and restores the text when the tab is selected again.
- **Back while the search is active.** System back deactivates the
  search instead of popping, natively and in the Flutter field, and the
  iOS edge swipe pops nothing of the shell's own route meanwhile. While
  the search is active, the swipe on a page pushed in the search tab pops
  that page, and the search stays active. With the search inactive, a
  shell that is itself a pushed page still loses the swipe to its own
  route: the swipe pops the whole shell (VK-567).
- **Dialogs and pages above the shell.** While a Flutter dialog, sheet or
  page covers the shell, an active search is deactivated first (the
  keyboard would sit above the barrier). The text is kept. One difference
  in the Flutter field: a search whose keyboard was already put away
  (`dismissKeyboard()`) has no focus to lose, so it stays active under the
  dialog, keyboard down, and is there as it was when the dialog closes.
- **Hidden chrome.** While the chrome is hidden (`LiquidHideChrome`, a
  covering page), the search is not active: hiding it ends an active
  search and keeps its text, and `activate()` is ignored natively until
  the chrome shows again. Coming back shows the search selected, not
  active, as the Flutter field does.

## Vietnamese and other IMEs

An IME composition (Vietnamese Telex, Japanese kana) changes the text under
the user's fingers until it is committed. Writing text into the field in
the middle of it breaks the composition.

- **Natively** the field is a real `UISearchTextField`: iOS runs the IME,
  not Flutter's text input. Text the app sets is written only when no
  composition (marked text) is open.
- **In the Flutter field** the shell writes the controller's text into the
  field only when the field has no composition and the text differs. The
  field is one persistent `TextField`: phase changes move and resize it,
  and never rebuild it under a new parent while it has focus.
- **Your side: write only for app actions.** Read `value.text` as it
  changes (filter, fetch results), but set `controller.text` only for an
  app action: a recent search tapped, a reset, `clear()`. Never write in
  reply to `onChanged`, not even a trimmed or lowercased copy of the
  user's text. Such a write is computed from a text that may already be
  stale; the field applies it because it differs, and the keystrokes
  typed meanwhile are lost. `LiquidSearchValue.composing` does not guard
  this: Apple's Vietnamese Telex keyboard never marks its text, so
  `composing` stays false natively while the user types Telex.

### An app write during a composition

Where an IME does mark its text (Japanese kana natively; Telex in the
Flutter field on Android), the two fields resolve an app write that lands
mid-composition differently. Both keep the composition intact; they
differ in who wins:

| | The write is | Then |
|---|---|---|
| Native field | held | The user wins: their next change, the commit included, drops the held write. It is applied only if the composition is cancelled back to the last reported text. |
| Flutter field | held | The app wins: when the composition ends, the held write replaces the committed text. |

So a recent search tapped mid-composition shows the tapped query in the
Flutter field, but natively the user's committed text stays and the tap
is lost. Make such writes from taps that end the composition first (a tap
outside the field does), or check `composing` before writing.

## Insets

The shell's `chromeInsets` cover the search field in every phase:

| Where the field is | Inset |
|---|---|
| iPhone, native, `selected` (the field in the tab bar area) | `bottom`: the bottom safe area, as for the tab bar |
| iPhone, native, `active` (above the keyboard) | `bottom`: down from the field's top, from the native field's real frame |
| iPad, native (stacked at the top) | `top`: the top safe area, which holds the bar and the field |
| Glass, compact | `bottom`: the bottom row; above the keyboard while `active` |
| Glass, regular | `top`: below the field |

Pad the search page with `LiquidShellScope.contentPaddingOf(context)` and
nothing else. Never also add `MediaQuery.viewInsets`: the active inset
already includes the keyboard, and a `Scaffold` with
`resizeToAvoidBottomInset: true` would count it twice.

## Pages in the search tab

A result usually pushes a detail. Give the search branch its own
`Navigator` (see [router_integration.md](router_integration.md#a-search-branch))
and wrap each page in `LiquidPage`. In the native search tab UIKit then
draws the page's title and its glass back circle; elsewhere `LiquidPage`
draws the Flutter glass bar. Every back, the native long-press history menu
included, goes through `Navigator.maybePop`, so `PopScope` runs.

## Troubleshooting

- **No native field: the glass one shows on iOS 26.** The native chrome is
  not in use. Check the opt-in (`LiquidShellNativeChrome` in Info.plist),
  that every other destination and the trailing action have an `sfSymbol`
  (in debug the shell logs one line naming them), that the shell has no
  `chromeBuilder`, and that `nativeChrome` is not `LiquidNativeChrome.off`.
  See [native_chrome.md](native_chrome.md#troubleshooting).
- **The field sits over a dialog.** It does not: the shell deactivates an
  active search when a dialog, sheet or page covers the shell. A custom
  overlay that is not a route (an `OverlayEntry`) is not seen; call
  `controller.deactivate()` before you show it.
- **The text is gone after ×.** By design: × clears the query, as UIKit's
  does. Leaving the tab, a dialog and `deactivate()` keep it.
- **The keyboard goes when the results scroll.** By design, as in Apple
  Music: the search stays active. Keep the keyboard with
  `LiquidSearch(dismissKeyboardOnDrag: false)`.
- **`activate()` does nothing.** It works only while the search tab is
  selected: select the tab first, and activate once the shell has built
  with it (for example in a post-frame callback).
- **The list sits under the field or the keyboard.** Pad it with
  `contentPaddingOf`, and remove any `viewInsets` padding of your own.
