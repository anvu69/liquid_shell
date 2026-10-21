# liquid_shell example

One screen per case of the
[liquid_shell README](https://github.com/anvu69/liquid_shell/blob/main/liquid_shell/README.md#cases).
Each case is a small file under `lib/cases/`; the README's code is copied
from those files and checked against them on CI.

## Run

```sh
cd liquid_shell/example
flutter run
```

- The liquid tier needs Impeller: the default on iOS and Android 10+.
- Native iOS 26 chrome needs an iOS 26 device or simulator; elsewhere the
  same cases draw the Flutter chrome.

## Cases

| Case | Shows |
|---|---|
| Basic 3 tabs | The smallest `LiquidShell` |
| Badges | `count(3)`, `count(120)` → 99+, `dot()` |
| Sidebar-only destinations | Hidden on phones, with a fallback |
| Sidebar header and footer | App title and profile; natively, the profile only |
| Trailing action | Compose: opens a page above the shell |
| Search tab | Field, scopes, recents, live results |
| Segmented control | `LiquidSegmentedControl` at the native frames |
| "Discard changes?" guard | `beforeDestinationChange` |
| Alerts and action sheets | Native on iOS 26, Flutter glass elsewhere |
| Hide the chrome | `LiquidHideChrome` on a page inside the branch |
| Custom chrome | Wrap the bar, replace the sidebar |
| Custom theme | `LiquidGlassTheme` extension, light and dark |
| Forced tier | liquid / frosted / solid |
| Form factors | iPhone, iPad portrait and landscape, Android |
| Narrow width | 5 tabs + trailing in a 320pt shell |
| Standalone widgets | `LiquidTabBar` and `LiquidSidebar` in your own `Scaffold` |
| Native chrome | Native footer, sidebar-only tab and guard on iOS 26 |

## go_router

[`../example_go_router`](https://github.com/anvu69/liquid_shell/tree/main/liquid_shell/example_go_router)
wires the shell to go_router's `StatefulShellRoute`; it is the code of
[doc/router_integration.md](https://github.com/anvu69/liquid_shell/blob/main/liquid_shell/doc/router_integration.md#go_router).
