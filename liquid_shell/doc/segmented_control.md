# The segmented control

`LiquidSegmentedControl` is iOS 26's `UISegmentedControl` for Flutter: a
flat track with a white thumb, and a liquid lens that lifts under the
finger, follows a drag across the segments and lands with a wobble. The
search scopes use it ([search.md](search.md)); it is public so the rest of
your app can too. It is text-only: icons and momentary segments are not
part of it.

![Segmented controls of two, three and five segments](images/case_segments_light.png)

## API

```dart
LiquidSegmentedControl(
  segments: const [
    LiquidSegment(label: 'All'),
    LiquidSegment(label: 'Songs'),
    LiquidSegment(label: 'Places', enabled: false),
  ],
  selectedIndex: _scope,
  onChanged: (i) => setState(() => _scope = i),
)
```

| Member | What it does |
|---|---|
| `segments` | Two or more `LiquidSegment`s, in index order (right to left in RTL) |
| `selectedIndex` | The selected segment, or null for none. The control is controlled: rebuild it with the index `onChanged` gives. If you do not, the lens returns to the segment you still select |
| `onChanged` | Called with the segment the user chose, on release. Not called for the selected segment, a disabled one or an app-made change. Null disables the whole control (drawn at half opacity) |
| `expand` | True (default): fill the width given. False: size to the labels, each segment as wide as the widest label plus 18, and at least 44 |
| `semanticLabel` | What a screen reader says for the control as a whole |
| `LiquidSegment.label` | The title |
| `LiquidSegment.enabled` | False: not tappable, never the target of a drag, label at half opacity |
| `LiquidSegment.semanticLabel` | The segment's spoken label, when it differs from `label` |

Under an unbounded width (a `Row` without `Expanded`) the control sizes to
its labels either way. It never overflows: in a narrow width every
segment shrinks equally and labels that do not fit end in an ellipsis.
Asserts: two or more segments, and `selectedIndex` inside them.

## Geometry

| Part | Size |
|---|---|
| Track | 32 pt tall at text scale 1, a capsule |
| Box | 44 pt tall; the track is centred in it, 6 pt above and below |
| Thumb at rest | the segment minus an inset of 2 pt, so `(segment - 4) x 28` |
| Pressed lens | the thumb plus 24 x 16, so 44 pt tall |
| Lens bezel | 9 pt |
| Label | 13 pt, w400, tracking −0.08 pt; w500 on the selected one |

Every segment's tap target is the full 44 pt box height by its width, with
no gaps. Native's control is 32 pt tall; yours takes 12 pt more layout,
and looks the same.

## Theming

Three fields of [`LiquidGlassTheme`](theming.md):

| Field | Light | Dark |
|---|---|---|
| `segmentTrack` | `#767680` @ 0.12 | `#767680` @ 0.24 |
| `segmentThumb` | `#FFFFFF` | `#EBEBF5` @ 0.30 |
| `segmentLabelStyle` | 13 pt, w400, −0.08 pt tracking, black | 13 pt, w400, −0.08 pt tracking, white |

The label keeps the app's font (`ThemeData.fontFamily`); set
`segmentLabelStyle.fontFamily` to choose another. The −0.08 pt tracking is
SF Pro's at 13 pt: UIKit applies it to the system font and Flutter's text
engine does not, so without it the labels, and an intrinsic control, come
out wider than native's. With a font of your own, set the `letterSpacing`
it needs. The selected label and
the one under the lens are w500. A disabled control is drawn at half
opacity.

## Motion

- **A tap commits on release**, as native does. The lens lifts when the
  finger lands on the selected segment; on another segment the label fades
  while it is held, and the lens flies there on release. On the way it
  lifts, wide over a short hop and tall over a long one, then lands with
  a wobble that keeps its area: as it narrows it grows taller, as it
  flattens it grows wider.
- **A drag** moves the lens with the finger, clamped to the first and last
  segment, and squashes a little at speed. On release it commits the
  segment nearest the lens; after a flick, the segment under the finger.
- **Selection clicks.** `HapticFeedback.selectionClick()` plays once per
  segment the lens crosses while dragging. A tap, a release and an app
  change play none.
- **An app change** (`selectedIndex` changed by your code) slides the thumb
  without the lens and does not call `onChanged`.
- The lens is the same engine as the [tab bar](tab_bar.md)'s, with the
  segment springs.

## Accessibility

- Each segment is a button in a mutually exclusive group, with selected and
  enabled states; the order follows the screen, in LTR and RTL. A semantics
  tap commits at once. Keyboard focus moves between enabled segments with
  Tab or the arrow keys, shows a ring, and Enter or Space commits.
- **Reduce motion:** a tap dissolves the thumb from one segment to the
  other in 150 ms, no slide, lift or wobble.
- **RTL** mirrors the segments, the drag and the crossings.
- **Text scale** follows the system up to x2: the track grows with the
  line, labels that do not fit end in an ellipsis. At accessibility sizes a
  long press shows the label in the large content viewer.
- Every segment is at least 44 pt tall; see below for width.

## Tiers

On the liquid tier the lens is a second glass pass over the control,
drawn only while a finger touches it, so a control at rest costs two fills
and text. The frosted and solid tiers draw the lens as their own fills; the
track and the rest thumb are fills on every tier. With reduce transparency
or increased contrast there is no lens pass, only the thumb.

## What is not identical to iOS

Measured against a `UISegmentedControl` on iOS 26.5; the numbers are in
the acceptance notes of VK-550.

- **Track (Q-B).** Flat, like native's. Only the lens is glass. iOS 27's
  glass track is not drawn.
- **Size (Q-C).** The box is 44 pt, not 32. Intrinsic segments are at least
  44 pt wide: "A | B | C" is 132 pt where native's is 96. Longer labels
  match native to within a point ("All | Songs | Places" is 177 pt).
- **Width below 44 pt per segment.** The segments shrink equally to fit,
  so hit targets follow the segment width and are narrower than 44 pt
  there. They stay 44 pt tall.
- **Text scale (Q-D).** Native's labels stay at 13 pt; these follow the
  system text size up to x2, which is the Flutter convention.
- **Wobble (Q-E).** The lens lifts and lands with springs matched to
  native's peaks, overshoot and settle time within 10 % on every native
  tap capture, and on fresh repeats it was not fitted to; not frame by
  frame. Two differences remain. A short tap toward the left (one segment
  of three, two of five) lifts tall in native, about 49 pt, and 38 pt
  here; taps to the right and long taps match. And the overshoot after a
  fast release changes with its speed here, where native's barely does:
  4.4 pt against 4.04 at about 630 pt/s, 3.3 against 3.86 at about 450.
- **Lens look.** Clear glass with a thin rim and a refracting ring, as
  native's. Native's lens also shrinks the page behind it about 0.8 times
  vertically; this one passes it as it is inside the ring.
- **Segments (Q-F).** Text only, with a per-segment `enabled`. No icons, no
  momentary mode.
- **Haptics.** One selection click per segment crossed while dragging; the
  device's own pattern for native's control could not be observed on the
  simulator.
