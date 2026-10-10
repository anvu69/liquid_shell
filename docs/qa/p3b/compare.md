# P3b-1: our search tab against the owner's Apple Music videos

The owner's frames stay outside the repository (session scratchpad
`vk407/frames/`); this file lists which frame each comparison used. Frames
are at 5 fps: frame n is at t = (n − 1) / 5 s.

Our screenshots are XCUITest captures taken on 2026-10-11 at this branch's
Task 12 commit (iPhone 17 Pro and iPad Air 11-inch (M4), iOS 27.0, debug
build, light mode). Task 11's `flutter drive` set has no shot of the
collapsed-circle return or of a narrow iPad window, so all pairs use the
same capture run. The narrow window is iPadOS 27 "Windowed Apps", resized
to its 375 pt minimum; the owner's Music window is about as narrow.

| State | Our screenshot | Owner frame | Difference noted |
|---|---|---|---|
| iPhone idle (Home) | iPhone 27.0 `idle` | iphone/f_0001.jpg | Same layout: tab pill at the left, a separate ⌕ circle at the right, large title at the top left. Our large title sits about 60 pt lower than Music's, which shares its row with the avatar. No mini player (not in scope). |
| iPhone selected | iPhone 27.0 `selected` | iphone/f_0041.jpg | Matches: the pill collapses to one circle with the Home icon, ⌕ widens into the bottom field, no keyboard, large title "Search". The title is about 60 pt lower, as on Home. No microphone (Q11). |
| iPhone active | iPhone 27.0 `active` | iphone/f_0081.jpg | Matches: the field sits above the keyboard with a separate × circle, the collapsed circle is hidden, the title is gone, the scope bar is at the top, then "Recently searched" with "Clear". Our recents list is empty. |
| iPhone after × | iPhone 27.0 `cancelled` | iphone/f_0091.jpg | Matches the selected state: unfocused field at the bottom and the collapsed circle back at the left. |
| iPhone back via the collapsed circle | iPhone 27.0 `circle_back` | iphone/f_0106.jpg | Matches: Home is selected, and the full pill and the separate ⌕ circle are back. |
| iPad narrow, another tab | iPad 27.0 narrow `idle` | ipad/f_0066.jpg | Search is inside the single bottom bar, as in the video. Music puts the large title "Home" on the ••• row; ours (a root page with the Flutter bar, Q17) sits on the row below. |
| iPad selected (narrow window) | iPad 27.0 narrow `selected` | ipad/f_0071.jpg | Matches: the full-width field sits under the ••• row and Search is highlighted in the bottom bar. Difference: Music shows a small inline title "Search" (and the avatar) on the ••• row; our ••• row is empty. |
| iPad active (narrow window) | iPad 27.0 narrow `active` | ipad/f_0086.jpg | Matches: the field rises onto the ••• row with ⓧ, the title goes away, then the scope bar and "Recently searched" / "Clear"; the keyboard covers the bottom bar. |
| iPad full screen (regular), selected and active | iPad 27.0 `selected`, `active` | none (the video has no regular-width window) | Search is in the top bar. The field sits under the bar and, when active, rises to the top and replaces the bar. This is spec §12.8 check 7; there is no owner reference to compare with. |
