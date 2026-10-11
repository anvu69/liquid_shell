# P3b-1: the owner's checklist on device

The ten checks of spec P3b §12.8. Run 1–9 on an iPhone and an iPad Air on
iOS 27; run 10 on the Android emulator and on iOS 18. Open the example's
"Search tab" case.

Telex (3) and VoiceOver (9) can only be checked by hand.

- [ ] **1. iPhone, iOS 27:** ⌕ separate; tap → pill becomes one circle with the
  previous tab's icon, ⌕ becomes the field at the bottom, keyboard down.
- [ ] **2. iPhone, iOS 27:** tap the field → field above the keyboard with ×;
  × → back to step 1's selected state; the circle → back to the previous tab.
- [ ] **3. iPhone and iPad Air, iOS 27:** Telex: type "ho hoan kiem" with the
  Vietnamese keyboard → "hồ hoàn kiếm", no repeated letters; results show
  "Hồ Hoàn Kiếm".
- [ ] **4. iPhone and iPad Air, iOS 27:** switch tabs and back → the query is
  still there.
- [ ] **5. iPhone and iPad Air, iOS 27:** tap a result → detail with the glass
  back circle; back → results. Long-press the back circle → the back menu;
  pick "Search" → the results, with no detail left behind.
- [ ] **6. iPad Air, iOS 27, narrow window:** Search inside the bottom bar; field
  under •••, rises level with ••• when active.
- [ ] **7. iPad Air, iOS 27, full screen:** Search in the top bar / sidebar; field
  under the bar, rises when active.
- [ ] **8. iPhone and iPad Air, iOS 27:** a dirty form + Search →
  "Discard changes?".
- [ ] **9. iPhone and iPad Air, iOS 27:** VoiceOver: the field, ×, the collapsed
  circle and the back circle are announced; the results are reachable. On a
  detail, the two-finger Z (escape) goes back to the results, with no
  "bonk" and nothing else closing. On iPad, in a narrow window, the small
  "Search" title is announced as a heading after the window controls.
- [ ] **10. Android emulator and iOS 18 (if available):** the same states drawn
  in glass.

## Automated coverage

- `make ios-ui` (`SearchUITests`, XCUITest) taps the real native search tab,
  field, back circle, × and (iPhone) the collapsed circle on iPhone and iPad,
  iOS 26.5 and 27.0. Flutter's result rows are read through Flutter's
  semantics: a row's title and subtitle merge into one label, so the test
  matches the label's start ("Hồ Hoàn Kiếm…").
- `SearchUITests` also picks entries from the back circle's long-press menu
  (the menu pops Flutter too) and, in the `search-guarded` demo where every
  detail refuses to close (`PopScope`), checks that a refused pick two pages
  up leaves the detail, its bar and its back circle in place (Task 13).
- `make integration-ios-native` (`native_search_test.dart`, Task 11) checks
  every phase's frames and insets.
