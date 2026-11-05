# P3b-2: the owner's checklist on device

Spec P3b-2 §8.5. Open the example's "Pages on every tab" case. Devices: an
iPhone and an iPad on iOS 26 (26.5 where possible), and an Android phone.
Real taps and swipes only; agents never run this.

Release gate: `0.1.0-dev.11` is published only after every box is ticked or
the owner accepts a failure in writing in the PR (plan
`docs/plans/2026-11-05-p3b2-release.md`, Task 10).

## iPhone and iPad, iOS 26, native chrome

- [ ] **1. Back circle on every tab.** Home › Detail 1, Settings › About and
  Settings › Profile each show UIKit's glass back circle.
- [ ] **2. Back.** On each pushed page: tap the circle → one page back.
  Long-press it → the history menu; pick the root → the root, nothing left
  between. Edge swipe from the left → the page follows the finger, and the
  bar switches when you let go.
- [ ] **3. Large title.** Library: the large title collapses into the bar
  as the list scrolls and comes back at the top.
- [ ] **4. iPhone 26.5, Library scroll, push and back.** Scroll Library
  half-way, switch to Home, push Detail 1, back, return to Library: the
  title is still collapsed and the list where you left it; scroll to the
  top: the large title opens again.
- [ ] **5. Actions.** Home's `+` opens Detail 1. On a detail: Share
  increments "Shared n times"; Favourite swaps the heart outline and the
  filled heart (the symbol changes in the bar); Delete is greyed and a tap
  does nothing (no pop, no counter change).
- [ ] **5b. Action capsule.** On a detail the page actions (Share,
  Favourite, Delete) sit in one glass capsule at the trailing end of the
  bar, not three separate circles.
- [ ] **6. Disabled icon contrast.** On Detail 1 scrolled so a dark
  wallpaper circle sits under the bar, and again over a light area: the
  greyed Delete is still visible as a bin and reads as disabled, in light
  and dark mode. Repeat in the Flutter chrome (switch on Home or Library to
  "Flutter liquid").
- [ ] **7. Hide chrome.** Home › Photo: the tab bar (and on iPad the
  sidebar) hides, the page's navigation bar stays with its title and back
  circle; back → the tab bar returns. iPad landscape with the sidebar
  tiled: the sidebar comes back after Photo closes.
- [ ] **8. iPad, sidebar while the tab bar is hidden.** Portrait and
  landscape. On Photo, try to bring the sidebar in (an edge swipe from the
  left, a keyboard shortcut if one is attached): write down what appears.
  Pass: nothing is left half-drawn over Photo, the page's bar and back
  circle keep working, and after back the sidebar and tab bar behave as
  before (a tiled sidebar is back in landscape).
- [ ] **9. iPad, hardware keyboard Escape.** With a keyboard attached, on
  Detail 2 press Escape: exactly one page back (Detail 1), as the back
  circle does; nothing else closes. Again on Detail 1: back to Home.
- [ ] **10. Minimize.** Scroll Home down: the tab bar minimizes; push
  Detail 1: the bar keeps its form; scroll the detail: it follows; back:
  the form is kept.
- [ ] **11. Telex.** Settings › Profile: with the Vietnamese Telex
  keyboard type "ho hoan kiem" → "hồ hoàn kiếm", no repeated letters. Go
  back (a pop) and open Profile again (a push), type it again. Switch to
  Home, open Photo (hide chrome) and back, return to Settings › Profile and
  type it once more. Every time: "hồ hoàn kiếm", no repeated letters.

## Android phone (Flutter chrome)

- [ ] **12. Same states in the Flutter bar.** Steps 1, 3, 5, 6 and 7 with the
  Flutter bar: the 44pt back button, Library's collapsing row, the three
  action circles with a greyed bin, Photo keeping its bar.
- [ ] **13. System back.** On Home › Detail 1 › Detail 2, system back pops
  Detail 2, then Detail 1, then leaves the case only at Home's root.

## Notes

Write any failure under its number with the device, iOS version and what
you saw. Accepted differences (not failures): UIKit groups the actions in
one glass capsule while the Flutter bar draws one circle each; the native
bar does not follow the finger during the swipe.
