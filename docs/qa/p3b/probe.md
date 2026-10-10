# P3b-1 probe: the search tab over the Flutter view (VK-407 Task 1)

Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5 and 27.0
(own `vk407 …` devices). Throwaway patch of `NativeTabsController` and
`PassThroughView`, plus `lib/probe_search.dart`; reverted after the run.

Measured 2026-10-10 on Xcode 27.0 (27A266a), Flutter 3.44.6, debug build,
rebased on `main` a38e2b0 (P2 + VK-426). Taps and on-screen keys were sent
with `idb ui tap` at the keys' accessibility frames; the logs are the
patch's `[probe]` `NSLog` lines plus Dart `debugPrint` lines, streamed with
`log stream`. Besides the plan's patch, the probe added:

- a `probe/search` method channel: every `updateSearchResults` sent the text
  and `composing` to Dart, Dart showed it and sent it back (`setText`). Native
  applied it only when `markedTextRange == nil` and the text differed (the
  spec §7.4 rule);
- first-responder logs (`searchBarTextDidBegin/EndEditing`,
  `keyboardWillShow/Hide` with `nativeFirst`);
- switches: `PROBE_MARKED` (programmatic `setMarkedText`),
  `PROBE_ECHO_DELAY_MS` / `PROBE_NO_ECHO`, `PROBE_ROUNDTRIP` (select in the
  completion of a real Pigeon call), `PROBE_COMPACT` (a compact
  `horizontalSizeClass` trait override on the tab bar controller, standing in
  for a narrow iPad window; there is no Simulator.app in this Xcode, so no
  Stage Manager), `PROBE_IPAD_PROMINENT`;
- the push in `PROBE_PUSH` fired 3 s after the search root first appeared,
  not 5 s after the provider ran (the provider runs at `setTabs`, at launch).

The Telex keyboard was installed with
`defaults write .GlobalPreferences AppleKeyboards`
(`vi_VN-Telex@sw=QWERTY;hw=Automatic`).

## Results

| # | Check | iPhone 26.5 | iPhone 27.0 | iPad 26.5 | iPad 27.0 | Decision |
|---|---|---|---|---|---|---|
| P1 | Programmatic select vs direct (frames at 60 fps) | first change → pill starts collapsing: direct 23–45 ms (median 43), proposed 50–65 ms (median 55): **+0.7 frame** (worst +1.3) | the morph starts in the first changed frame in both modes; to the pill mostly collapsed (diff > 20): direct 0–30 ms (median 8), proposed 18–48 ms (median 20): **+0.7 frame** (worst +1.1) | press → field: direct 60–85 ms (median 65), proposed 51–112 ms (median 89): **+1.4 frames** | no separate press frame: the selection is the first visible change in both modes; programmatic select 17–52 ms after `shouldSelect` (log) | guarded flag: **no**, see note 1 |
| P2 | Push inside the search tab: bottom field over the detail? | **No.** `hidesBottomBarWhenPushed = false`: UIKit removes the bottom field and the collapsed circle and shows the full compact bar again (pill + ⌕ circle, selected) under the detail; glass back circle 44×44 at (16, 62), large title "Detail". `= true`: the whole bar hides. Pop: the bottom field comes back | same as 26.5 | n/a | n/a | hidesBottomBarWhenPushed: **no** (UIKit's default already takes the field off the detail); owner compares with Music (Q19) |
| P3 | Telex `hoof hoafn kieems` → `hồ hoàn kiếm` | on-screen keys: log ends `text=Hồ hoàn kiếm` (auto-capital H), one step per key, no doubled letter, Dart got every step | same | same (regular and compact) | same (regular and compact); hardware key events: `text=hồ hoàn kiếm` | **pass** |
| P4 | `viewInsets.bottom` with the native field focused | 335 | 328 (326 before the suggestion bar) | 337 | 337 | pass; `padding.bottom` drops to 0 meanwhile |
| P5 | First responder native ↔ Flutter | native → Flutter: `native didEndEditing first=0`, `keyboardWillShow nativeFirst=0`, keys reach the Flutter field only; Flutter → native: `didBeginEditing first=1`, Flutter field drawn unfocused, keys reach the native field only. One keyboard throughout | same | same | same | **pass** |
| P6 | Host safe area (t/l/b/r) idle · selected · active · after × | 62/0/83/0 · 168.7/0/83/0 · 62/0/83/0 · 168.7/0/83/0 | 62/0/83/0 · 168.7/0/83/0 · 62/0/83/0 · 168.7/0/83/0 | regular: 96/0/20/0 · 146/0/20/0 · 90/0/20/0 · 146/0/20/0; compact: 32/0/77/0 · 146/0/77/0 · 90/0/77/0 | regular: 96/0/20/0 · 140/0/20/0 · 86/0/20/0 · 140/0/20/0; compact: 32/0/77/0 · 140/0/77/0 · 86/0/77/0 | Task 5 XCTest values (idle = the Flutter padding from the destination host) |
| P6 | Field frame in Flutter coordinates, selected · active | {88, 798, 286, 48} · {8, 483, 330, 48}, × {346, 483, 48, 48} | {88, 798, 286, 48} · {8, 490, 330, 48}, × {346, 490, 48, 48} | {20, 87, 780, 44} · {20, 38, 780, 44} (regular and compact) | {20, 86, 780, 44} · {20, 32, 780, 44} (regular and compact) | active iPhone frame only from the AX tree: no host layout pass runs when the field rises (note 6) |
| P7 | Text after a programmatic deactivate | `text before=Ho`, `text after=` (empty) | same | same | same | restore in setSearchActive(false): **yes** |
| P8 | `updateSearchResults` after programmatic `text =` | yes: `text=ho` follows at once (selected `active=0`, and active `active=1`) | same | same | same | suppress: yes (always) |
| Hit | field / × / circle → UIKit, rows → Flutter, every phase | rows print `flutter row N` in idle, selected, active, after × and under a pushed detail; field, ×, circle, ⌕ and back circle never do (they run their UIKit action) | same | same (regular and compact; ⓧ instead of ×) | same (regular and compact; ⓧ instead of ×) | pass with the nav-controller rule (spec §7.8) |

Stop rule: P3 and P5 pass on all four simulators. Task 2 may start.

## Notes

1. **P1 and the real round trip.** The probe's proposed path waits about one
   frame (17 ms) before it selects; it lands +0.7 to +1.4 frames behind UIKit's
   own selection at the median, inside the 2-frame bar, and runs the same morph
   to the same end frame. The real path waits for Dart: P2's destination
   proposal (`onDestinationTapped` → `setState` → `update` → `selectedTab =`)
   took **18–58 ms** (1–3.5 frames) on the iPhone 27 simulator in a debug build;
   a bare Pigeon reply took 5–6 ms. Release builds are faster, but the update
   waits for a Flutter frame, so expect 1–2 frames on device. Decision: no
   `guarded` flag in Task 4. The owner's side-by-side on a device (spec §12.7)
   rechecks, and Q6's fallback stays specified. The simulator recorder drops
   frames without Simulator.app, so only recordings with ≥ 45 frames were
   counted (11 on iPhone 27.0, 8 on iPhone 26.5, 6 per iPad). The diff is the
   mean absolute luma change of the pill, ⌕ or field region against the first
   frame, read with AVFoundation (no ffmpeg here).
2. **Never echo the user's own text (Task 4).** With Dart echoing each text
   back, `setText` was always `skipped: same` at on-screen key speed. With
   hardware keys (about 25 ms apart) or a 1.2 s echo delay, a stale echo landed
   after a newer keystroke and was applied (`dart setText=h APPLIED over ho`).
   Because programmatic text triggers `updateSearchResults` (P8), the two sides
   then ping-ponged until the app was killed (5849 `APPLIED` lines in 2 min 19 s
   with hardware keys; with the delayed echo, `Hồ hoàn` turned into an
   oscillating `H`/`Hồa`/`Hồ f`). The bridge must be one-way per origin:
   native → Dart for user edits, Dart → native only for Dart's own commands,
   which never answer a native report. Native suppresses its callbacks while it
   applies Dart text (`applyingFromDart`). Without the echo, hardware-key Telex
   reached Dart exactly (`hồ hoàn kiếm`).
3. **The iOS Vietnamese keyboard never sets marked text.** Every line had
   `marked=0`: Telex replaces the preceding characters in place. The
   `markedTextRange` rule still matters for other IMEs: a programmatic
   `setMarkedText("hô")` reached Dart as `composing=true`, and the echo was
   `skipped: marked`.
4. **iOS 26.5 bilingual keyboard.** With both `vi_VN-Telex` and `en_US`
   enabled, iOS 26.5 merges them into one "EN VI" keyboard that does no Telex
   (`Hoof hoafn kieems`, the same in a Flutter `TextField`). The first
   activation also shows a one-time "Type English and Vietnamese" sheet over
   the keys. iOS 27.0 kept two keyboards. The 26.5 runs used Telex only. This
   is keyboard configuration, not the shell; the manual check (spec §12.8) must
   say which keyboard is active.
5. **Flutter's own field during Telex** logs transient values (`đươn`, `đư`,
   `đươ`, `đ`, `đư`, `đường` within 1 ms) as iOS replaces characters. The final
   value is right. The Flutter fallback field (spec §9.4) must not act on each
   transient value (for example, flash empty results on `""`).
6. **Field frame needs the keyboard notifications.** When the iPhone field rises
   above the keyboard, no host layout pass fires, so the probe's `field=` log
   showed only the selected frame. Spec §7.5's `keyboardWillChangeFrame` re-read
   is required. On iOS 26.5, while a Flutter field held the keyboard on the
   selected search tab, the unfocused native field also floated above that
   keyboard ({8, 483, 386, 48}).
7. **UIKit callbacks on dismissal.** × (iPhone), ⓧ (iPad) and a programmatic
   `isActive = false` each produce two or three `updateSearchResults("")`
   (`active=0`), then `didDismiss`. × and ⓧ clear the text and dismiss; ⓧ is the
   iPad's only way out besides the keyboard.
8. **Reselecting the search tab while a page is pushed** goes through the
   proposal path, so UIKit's pop-to-root does not happen. Dart decides what a
   tap on the selected search tab does.
9. **Pushed hosts must sync the Flutter frame** (spec §7.9). The probe's plain
   detail controller left Dart's padding stale (168.7 top while pushed; 62 top
   with the bar hidden, under a 116 pt title).
10. **Probe artifact.** The search tab was not a Dart destination, so leaving it
    by a destination that Dart already had selected sent no `update`. On iPad
    the tab stayed on Search; on iPhone the collapsed circle worked. Task 4's
    search destination removes this.

## `prominentTabIdentifier`: trailing action (VK-426) and search tab

- `main` (VK-426) marks the P2 trailing action prominent in `showTrailingApart()`,
  on iOS 27 with the iOS 27 SDK (`#if compiler(>=6.4)`), on **every idiom**:
  the trailing ⌕ is the separate circle on the iPhone and on a compact iPad.
- The search destination is prominent on the **iPhone only** (Q10). On the iPad it
  is nil (Q1). Measured with the compact override on iPad 27.0: without
  prominent, Search is the third item inside the pill, as in the video; with
  prominent, it is a separate circle. On iPad 26.5 it is always a separate
  circle.
- Both are `UISearchTab`s, and both report the fixed identifier
  `com.apple.UIKit.Search` (logged on 26.5 and 27.0). A tab set cannot hold
  both, so Q9 ("never together") is also a UIKit constraint.
- So `NativeTabsController` keeps one rule, applied after `setTabs` where
  `showTrailingApart()` runs today, with the same compiler and availability
  guards:
  - **trailing action present:** its identifier, on any idiom (VK-426,
    unchanged);
  - **search destination present:** its identifier when
    `userInterfaceIdiom == .phone`, else nil;
  - **neither:** nil.

  If both ever arrive, Dart's Q9 assert has already failed. Native then
  builds the search destination and drops the trailing action.

## Integration

`native_search_test.dart` (Task 11, `make integration-ios-native`) on fresh
iPhone 17 Pro and iPad Air 11-inch (M4) simulators. Frames are in Flutter
logical points; `insets` is the shell's `chromeInsets`, `padding` the search
page's `MediaQuery` padding.

```
iPhone 26.5  liquid_shell search selected: placement inline field 88.0,798.0 286.0x48.0 insets EdgeInsets(0.0, 0.0, 0.0, 83.0) padding EdgeInsets(0.0, 168.7, 0.0, 83.0)
iPhone 27.0  liquid_shell search selected: placement inline field 88.0,798.0 286.0x48.0 insets EdgeInsets(0.0, 0.0, 0.0, 83.0) padding EdgeInsets(0.0, 168.7, 0.0, 83.0)
iPad 26.5    liquid_shell search selected: placement stacked field 20.0,87.0 780.0x44.0 insets EdgeInsets(0.0, 146.0, 0.0, 0.0) padding EdgeInsets(0.0, 146.0, 0.0, 20.0)
iPad 27.0    liquid_shell search selected: placement stacked field 20.0,86.0 780.0x44.0 insets EdgeInsets(0.0, 140.0, 0.0, 0.0) padding EdgeInsets(0.0, 140.0, 0.0, 20.0)
```

Active, with the software keyboard up (the keyboard observers publish the
field's end position):

```
iPhone 26.5  liquid_shell search active: keyboard 335.0 field 8.0,483.0 330.0x48.0 insets EdgeInsets(0.0, 0.0, 0.0, 399.0)
iPhone 27.0  liquid_shell search active: keyboard 328.0 field 8.0,490.0 330.0x48.0 insets EdgeInsets(0.0, 0.0, 0.0, 392.0)
iPad 26.5    liquid_shell search active: keyboard 337.0 field 20.0,38.0 780.0x44.0 insets EdgeInsets(0.0, 90.0, 0.0, 0.0)
iPad 27.0    liquid_shell search active: keyboard 337.0 field 20.0,32.0 780.0x44.0 insets EdgeInsets(0.0, 86.0, 0.0, 0.0)
```

The placement and every frame match the P6 rows above: `.stacked` is
realised on iPadOS 26.5 as on 27.0. The iPhone's active field frame, which
P6 could read only from the accessibility tree, now reaches Flutter.
