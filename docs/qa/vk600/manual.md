# VK-600: the owner's checklist on device

The checks of spec `docs/specs/2026-10-14-native-tab-minimize-design.md` §12.6 (plan Task 10 Step 3), with the expected results of spec §4 and §10. The automated evidence is in `acceptance.md`.

**Devices.** An iPhone on iOS 26 and an iPhone on iOS 27; an iPad that can run a narrow window (Windowed Apps or Stage Manager). Build the example (`liquid_shell/example`) in Debug from Xcode.

**Where to check.**

- **"Basic 3 tabs"** (case list): three tabs, 24 rows each.
- **"Search tab"** (case list): Home · Library · ⌕, with scopes.
- **The `minimize` demo:** the three tabs under a `Scaffold`, which handles the status-bar tap, and a "Next tab" button that changes the tab from the app. Open it with the scheme's environment variable `LIQUID_SHELL_EXAMPLE_DEMO=minimize` (Xcode › Product › Scheme › Edit Scheme › Run › Arguments). The cases opened from the list have no `Scaffold` of their own, so a status-bar tap there does not scroll the case.
- **Rows 11–13** need a page the example does not have: a web view or a native map in the body, a `TabBarView` of several lists, a feed longer than 100 000 pt. Check them in an app that has such a page, or mark them "not checked".

**Open question first: Q14 (R3, the bottom scroll-edge effect).** Since VK-600, UIKit draws its bottom scroll-edge effect under the native bar: the content near the bottom edge is softly blurred, as under a native `UITabBarController` with a scroll view. Before VK-600 it was not drawn. It shows with `minimizeOnScroll: false` too. See `acceptance.md` §7 and `r3_bands.png`, `r3_zoom.png`. Spec Q12 accepts the change only if before and after look the same, and they do not, so the owner decides (see `acceptance.md` §7):

- **A:** keep it, as native apps look;
- **B:** hide it with the public `bottomEdgeEffect.isHidden = true` on the proxy. Outside the bar this matches the look before VK-600. It needs a small TDD task and a rerun of the iOS suites.

## The checks

Mark each one ✅ as expected, ❌ with what happened, or "not checked".

- [ ] **1. iPhone, iOS 26 and iOS 27, against Apple Music** ("Basic 3 tabs", Home):
  - [ ] scroll the list down about 20–40 pt → the bar shrinks to the 48 pt circle of the selected tab, with UIKit's animation (about 0.8 s), as Apple Music's does;
  - [ ] drag slowly back up in mid-content → the bar stays minimized;
  - [ ] fling down so the list reaches its top → the bar expands as the list arrives;
  - [ ] drag (no fling) the list down into its top edge → the bar stays minimized, as UIKit's own bar does;
  - [ ] tap the circle → the bar expands;
  - [ ] the `minimize` demo: minimize, then "Next tab" → the bar expands and shows the next tab selected (Q4).
- [ ] **2. The search tab does not minimize** ("Search tab", iPhone): select ⌕, drag the search page up and down → the search bar and field keep their form (Q5).
- [ ] **3. Minimized → ⌕ with scopes** ("Search tab", iPhone, iOS 26 and 27):
  - [ ] on Library, scroll down → minimized: Library's circle and the ⌕;
  - [ ] tap ⌕ → search's own collapsed form (the previous tab's circle and the field), and no keyboard;
  - [ ] tap the field → the keyboard; type "pho" → the scope bar at the top, and "Songs" filters;
  - [ ] × → the keyboard goes down; tap Library's circle → Library, with the whole bar.
- [ ] **4. Status-bar tap** (`minimize` demo, iPhone, VoiceOver off): scroll down → minimized; tap the status bar → the list scrolls to the top and the bar expands (Q3). Note how many taps it took (expected: one).
- [ ] **5. Status-bar tap under VoiceOver and Speak Screen** (`minimize` demo, iPhone). This is Flutter's engine, not VK-600, so only record what happens:
  - VoiceOver on: scroll down, then tap the status bar (with VoiceOver, select the status bar and double-tap) → record whether the list scrolls to the top on the first tap or only on the second, and whether the bar expands once the list is at the top;
  - Speak Screen on (Settings › Accessibility › Spoken Content), VoiceOver off: the same, a plain tap.

  On a simulator the first tap after a scroll can move only Flutter's accessibility mirror of the list and leave the list where it was; the second tap scrolls it (`acceptance.md` §3). On a device the engine creates the mirror only under VoiceOver, Switch Control or Speak Screen.
- [ ] **6. VoiceOver** (iPhone, "Basic 3 tabs"):
  - [ ] minimized, the circle is announced (UIKit's label for the tab, and its collapsed state), and a double-tap expands the bar;
  - [ ] a three-finger swipe down repeated up to the top → the list reaches the top and the bar expands (Q3);
  - [ ] a three-finger swipe up does not minimize the bar (VoiceOver scrolling is not a trigger, Q8).
- [ ] **7. Reduce Motion** on (Settings › Accessibility › Motion): minimize and expand still happen, with UIKit's own reduced animation.
- [ ] **8. iPhone landscape:** scroll down → the bar minimizes as in portrait; the circle expands it. On a Plus or Pro Max, whose landscape width is regular, record what UIKit does.
- [ ] **9. iPad:**
  - [ ] a narrow window (compact, the bottom bar) → it minimizes, the circle and a fling to the top expand it, as on an iPhone (Q6);
  - [ ] full screen (the top bar and the sidebar) → a scroll never minimizes the bar.
- [ ] **10. Stage Manager resize while minimized** (iPad): minimize in a narrow window, widen the window to regular → the top bar, whole; narrow it again → the bottom bar, expanded, and it minimizes again on the next scroll down. Nothing stays half-drawn.
- [ ] **11. A web view or a native map in the body:** a drag that starts on it scrolls it as before, and the native bar does not minimize (Q7).
- [ ] **12. Several lists in one tab** (a `TabBarView`): scroll list A deep, switch to list B, flick B up in mid-content. After it stops, the bar does not minimize on its own (spec §9.1 rule 3).
- [ ] **13. A long feed** scrolled past 100 000 pt: tap the circle to expand, then scroll down → the bar still minimizes (`MinimizeProxy` grows its content, spec §8.1).
- [ ] **14. Q14 by eye** (iPhone, "Basic 3 tabs", at rest and scrolled): the soft blur of the content near the bottom edge, under and beside the bar. Answer A or B above.

## Automated coverage

- `make ios-ui` (`MinimizeUITests`, XCUITest, real swipes) covers rows 1 (minimize, slow reverse, fling to the top, circle, the app's tab change), 2, 3 (minimized → ⌕ → scopes → ×) and 4 (on a simulator) on iPhones, and row 9 (narrow window, full screen) on iPads, iOS 26.5 and 27.0.
- `make ios-unit` (`NativeTabsTests`, `MinimizeProxyTests`) covers the pan's attachment, the size-class change (row 10's mechanism), the content that grows (row 13's mechanism) and the gate over platform views (row 11's mechanism).
- `liquid_shell/test` (`native_minimize_test.dart`, unit and widget) covers the offset rules behind row 12: one offset per tab across several lists, and at rest it only drops.
