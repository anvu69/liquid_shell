# Router integration

`LiquidShell` owns no navigation. You give it the selected index, a callback
and a `body`; it gives you chrome, insets and the sidebar.

## Keep branch state alive

The shell never rebuilds `body` under a new parent, so state survives every
layout change. Keeping **inactive** branches alive is your job: use an
`IndexedStack` (or your router's equivalent).

```dart
LiquidShell(
  destinations: destinations,
  selectedIndex: index,
  onDestinationSelected: (i) => setState(() => index = i),
  body: IndexedStack(
    index: index,
    children: [for (final tab in tabs) tab.page],
  ),
)
```

## One Navigator per tab

Create the navigator keys once, as fields of your `State`. A `GlobalKey`
made in `build` is a new key on every build, so every tab would lose its
stack.

```dart
// Fields of your State class: created once, never in build.
late final List<GlobalKey<NavigatorState>> _keys = [
  for (final _ in tabs) GlobalKey<NavigatorState>(),
];

// In build:
LiquidShell(
  destinations: destinations,
  selectedIndex: index,
  onDestinationSelected: (i) {
    if (i == index) {
      _keys[i].currentState!.popUntil((route) => route.isFirst); // reselect
    }
    setState(() => index = i);
  },
  body: IndexedStack(
    index: index,
    children: [
      for (final (i, tab) in tabs.indexed)
        Navigator(
          key: _keys[i],
          onGenerateRoute: (_) => MaterialPageRoute(builder: tab.builder),
        ),
    ],
  ),
)
```

## A search branch

A search destination (`role: LiquidDestinationRole.search`, see
[search.md](search.md)) is just an index: the shell draws the field, and
the branch at that index is your search page. Give it its own `Navigator`,
as every other tab, so a result's detail pushes inside the tab, under the
glass back button, and the field and the query stay where they were when
the user comes back.

```dart
// Fields of your State class.
final _search = LiquidSearchController(); // dispose it in dispose()
late final List<GlobalKey<NavigatorState>> _keys = [
  for (final _ in destinations) GlobalKey<NavigatorState>(),
];

// In build: the search destination is the last one.
LiquidShell(
  destinations: destinations,
  selectedIndex: index,
  onDestinationSelected: (i) {
    if (i == index) {
      _keys[i].currentState!.popUntil((route) => route.isFirst); // reselect
    }
    setState(() => index = i);
  },
  search: LiquidSearch(controller: _search),
  body: IndexedStack(
    index: index,
    children: [
      for (final (i, root) in [home, library, searchPage].indexed)
        Navigator(
          key: _keys[i],
          onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
        ),
    ],
  ),
)
```

- **Reselect pops to the root**, in the search tab too: tapping Search
  while a detail is open goes back to the results. The query is kept.
- **Wrap each page in `LiquidPage`** (title, back button). In the native
  search tab UIKit draws them; the page's `PopScope` runs for the native
  back circle and its long-press menu, which go through `maybePop`.
- **Never push the search page above the shell** (on the root navigator).
  It would cover the tab bar and lose the native field. A trailing action
  (`tabBarTrailing`) is for something else, such as compose; a shell with
  a search destination has none.
- With go_router, the search destination is one more
  `StatefulShellBranch`; `goBranch(i, initialLocation: i == currentIndex)`
  gives the same reselect.

## go_router (until the adapter ships)

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => LiquidShell(
    destinations: destinations,
    selectedIndex: shell.currentIndex,
    onDestinationSelected: (i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex),
    body: shell,
  ),
  branches: [/* one StatefulShellBranch per destination */],
)
```

`StatefulShellRoute.indexedStack` already keeps each branch alive.

## Pages and the chrome

| Page | Wrap it in | Effect |
|---|---|---|
| Inside a branch, normal | nothing; pad with `LiquidShellScope.contentPaddingOf(context)` | content scrolls under the glass |
| Inside a branch, full frame (reader, detail) | `LiquidHideChrome` | every piece of chrome hides while it is mounted and on screen |
| Above the shell (root navigator: compose, sheets) | `LiquidNoChrome` | its insets ignore the chrome underneath |
| Static content | `LiquidContentInset` | `Padding(contentPaddingOf(context))` |

"Inside a branch" means on a `Navigator` that sits **under** the shell, in
its `body`: a router's shell branch, or your own per-tab `Navigator` as
above. `LiquidHideChrome` finds the shell above it, so a page on the app's
root navigator cannot hide the chrome; it is above the shell and needs
`LiquidNoChrome` instead. Wrap your own branch navigator in a
`NavigatorPopHandler` so system back pops the branch first. The README's
"Hide the chrome" case is a complete example.

"On screen" means no ancestor `Visibility` is hidden and tickers are on. An
`IndexedStack` hides inactive branches with `Visibility`;
`StatefulShellRoute.indexedStack` wraps them in `Offstage` and
`TickerMode(enabled: false)`; a `Navigator` turns tickers off for a route
covered by an opaque one. So a detail page left open in one branch stops
hiding the chrome when you switch branches in code (a deep link, a
notification tap, `context.go`), and hides it again when you switch back.
If you keep branches alive some other way, wrap the inactive ones in
`Visibility(visible: false, maintainState: true, ...)` or
`TickerMode(enabled: false)`.

### With native iOS chrome

Native chrome (iOS 26 on iPhone and iPad, see
[native_chrome.md](native_chrome.md)) follows the same table. It also
watches the shell's own route: a page pushed above the shell hides the
native chrome while it covers the shell. A dialog or sheet above the shell
makes the native top bar and sidebar ignore touches at regular width, and
hides the native compact bar at compact width (every iPhone, and a narrow
iPad window), so the bar never covers the bottom of the sheet.

Both work only for routes on a navigator **above** the shell. A modal shown
on a branch's own navigator is drawn **under** the native chrome, which
stays visible and takes touches. At compact width that is the floating bar
over the bottom of the sheet, and it is the default for
`showModalBottomSheet` (`useRootNavigator: false`) from a page inside a
branch. Show modals on the root navigator (`showDialog` does by default;
pass `useRootNavigator: true` to `showModalBottomSheet`), or wrap the page
in `LiquidHideChrome`. Overlays that are not routes (a `SnackBar`, an
`OverlayPortal` or `Autocomplete` menu) also stay under the native chrome,
as they do under the Flutter chrome.

## Leaving a page with unsaved work

`beforeDestinationChange` runs before every user selection (not before
programmatic `selectedIndex` changes). Show a dialog and return its answer:

```dart
beforeDestinationChange: (index) async {
  if (!form.isDirty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (_) => const DiscardDialog(),
      ) ??
      false;
},
```

While it is pending, further taps are ignored. A throw counts as `false`
and is reported through `FlutterError.reportError`. If `destinations`
changes while the guard is pending, an accepted selection goes to the
destination with the same label, or is dropped when that label is gone.
That is why labels must be unique; a debug assert names any repeats.

## The sidebar from your pages

```dart
// In the State of a wide editor page.
bool _askedForRoom = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final scope = LiquidShellScope.of(context);
  if (!_askedForRoom && scope.sizeClass == LiquidSizeClass.regular) {
    _askedForRoom = true;
    scope.setSidebarVisible(false); // once, when the page opens
  }
}
```

A call made while the page builds (from `initState`,
`didChangeDependencies` or `build`) applies right after that frame. Ask
once, as above: a page that reads the scope rebuilds when the sidebar
changes, so a call in `build` would hide the sidebar again as soon as the
user shows it.

There is one shell-wide sidebar state. It resets to the default (shown when
tiled, hidden when overlay) whenever the presentation changes.

## System back and the overlay sidebar

While the overlay sidebar is open, system back closes it before it pops
anything. The shell does this with a `PopScope` that blocks the pop only
while the overlay is shown; otherwise it does not take part, and your own
`PopScope`s (an exit confirmation, an unsaved form) decide as usual.

Known limitation: a route calls **every** `PopScope` on it. So while the
overlay is open, a back gesture that closes the sidebar also calls your own
`PopScope.onPopInvokedWithResult` on the same route, with `didPop: false`.
If that handler shows a dialog, ignore the call while the overlay is open:

```dart
PopScope(
  canPop: !form.isDirty,
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return;
    final shell = LiquidShellScope.maybeOf(context);
    if (shell?.chromeKind == LiquidChromeKind.sidebarOverlay) return;
    showDiscardDialog(context);
  },
  child: page,
)
```

`LiquidShellScope.maybeOf` only sees the shell from below it, so put such a
`PopScope` inside the shell's `body`, or track the sidebar yourself. The
same goes for a `NavigatorPopHandler` around a branch navigator: it is a
`PopScope` on the shell's route, so while the overlay is open a back
gesture would also pop a page the branch has pushed. Return early from its
`onPopWithResult` the same way. (A `PopScope` on a page of the branch's own
navigator belongs to that navigator's route and is not called.)

A router that sends system back to the deepest navigator itself, as
go_router does, has its own order; this guide does not cover how it treats
an open overlay sidebar. The planned go_router adapter will.
