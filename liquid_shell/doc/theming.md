# Theming

All glass reads one `ThemeExtension`, `LiquidGlassTheme`. Without one,
`LiquidGlassTheme.of(context)` derives it from the **displayed**
`Theme.of(context).colorScheme` (never from the platform brightness), so
`themeMode` and nested `Theme` widgets just work.

## Fields and defaults

| Field | Light | Dark | Used for |
|---|---|---|---|
| `tint` | `surface` @ 0.72 | `surface` @ 0.90 | fill, frosted tier only |
| `solid` | `surface` | `surface` | fill, solid tier only |
| `border` | `outline` @ 0.28 | `onSurface` @ 0.18 | 1px outline, frosted and solid tiers |
| `borderWidth` | 1 | 1 | outline width, frosted and solid tiers |
| `rimHighlight` | white @ 0.12 | white @ 0.12 | frosted top-edge highlight; liquid specular rim |
| `shadow` | `#12000000` (7 %), offset (0, 3), blur 20 | same | drawn outside the shape only |
| `blurSigma` | 10 | 10 | blur, frosted tier only |
| `borderRadius` | pill (999) | pill | bars, circles |
| `labelStyle` | 10/12, w500, no letter spacing, theme font | same | tab labels: the bottom bar as is, the landscape bar at 12pt w400, the top bar at 17pt; w600 on the selected tab |
| `liquidTint` | white @ 0.55 | #1C1C1C @ 0.90 | colour over liquid glass, inside the lens shader, liquid tier only |
| `refraction` | 1 | 1 | liquid lens strength: 0 is flat glass, 2 doubles it |
| `dispersion` | 0 | 0 | liquid colour fringe in the lens band, 0–1; 0 turns it off (the touched tab lens draws its own) |
| `liquidBlurSigma` | 2 | 2 | liquid blur under the lens; 0 for none (and no scroll-edge pocket) |
| `selectionFill` | black @ 0.08 (`#14000000`) | white @ 0.13 (`#21FFFFFF`) | the selected tab's capsule at rest, over the pill |
| `tabForeground` | `#191919` | `#F4F4F4` | unselected tab icons and labels, the trailing circle's icon, unselected sidebar rows |
| `badgeColor` | `#FF383C` | `#FF4245` | badge capsules in the tab bar and the sidebar |
| `tabIconSize` | 26 | 26 | tab and trailing-circle icons at text scale 1 (the landscape bar uses 22) |
| `segmentTrack` | `#767680` @ 0.12 (`#1F767680`) | `#767680` @ 0.24 (`#3D767680`) | the segmented control's track and the search scope bar's |
| `segmentThumb` | `#FFFFFF` | `#EBEBF5` @ 0.30 (`#4DEBEBF5`) | the segmented control's thumb at rest |
| `segmentLabelStyle` | 13, w400, −0.08 tracking, black | 13, w400, −0.08 tracking, white | segment labels; the selected one is w500. The app's font family is kept; set `fontFamily` here to change it. The tracking is SF Pro's at 13 pt, which UIKit applies and Flutter does not |

Tab colours: the selected tab is `ColorScheme.primary` (the tint the
native chrome uses too) over a `selectionFill` capsule, and the others are
`tabForeground`. Every tab draws `selectedIcon ?? icon` (see
[tab_bar.md](tab_bar.md#icons)). Sidebar rows use `textTheme.bodyLarge`:
`onPrimaryContainer` on `primaryContainer` when selected, `tabForeground`
otherwise.

`tabIconSize` is 26 because Material icons draw their ink at about 20/24
of their box, which gives the 21–22pt glyphs of iOS's tab bar. Tune it for
another icon font. From text scale 1.6 the icons grow with the text and
the tabs become icon-only.

`labelStyle` is the base of every tab label. In a narrow bottom bar
(the shell narrower than `kLiquidNarrowWidth`, 340) a label that does not
fit its cell first takes the cell's side padding, then shrinks, never below
10pt (or its own size when that is smaller), and only then ends in an
ellipsis. A `labelStyle` above 10pt can therefore draw smaller there.
Between text scale 1 and 1.6 this also shrinks labels below the size the
user chose; from 1.6 the cells are icon-only with a large content viewer.
The pill height never changes, because a shrunk label keeps its line
height.

The segmented control and its fields are in
[segmented_control.md](segmented_control.md).

## A brand theme

Liquid is the default tier wherever Flutter runs on Impeller (iOS,
Android 10+, macOS), and it reads `liquidTint`, `liquidBlurSigma`,
`refraction` and `dispersion`, not `tint` and `blurSigma`. Set both pairs,
or a brand theme shows only where glass falls back to frosted:

```dart
final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));
final glass = LiquidGlassTheme.fromColorScheme(scheme).copyWith(
  // Liquid: the default tier on Impeller.
  liquidTint: scheme.primaryContainer.withValues(alpha: 0.5),
  liquidBlurSigma: 3,
  // Frosted: no Impeller, battery saver, Low Power Mode, slow frames.
  tint: scheme.primaryContainer.withValues(alpha: 0.6),
  blurSigma: 18,
);
MaterialApp(
  theme: ThemeData(colorScheme: scheme, extensions: [glass]),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: Brightness.dark,
    ),
  ), // no extension: dark defaults are derived
  home: const MyShell(),
);
```

Built directly with `LiquidGlassTheme(...)`, a theme without `liquidTint`
gets the same neutral tint: white @ 0.55, or #1C1C1C @ 0.90 when `solid`
is dark. For a stronger or flatter brand lens, set `refraction` (0 flat, 2
double).

`LiquidGlassTheme` implements `lerp`, so theme animations interpolate the
glass too.

## Your own glass surfaces

`LiquidGlass` is public. Wrap any widget to get the same tiers, signals and
theme as the chrome:

```dart
LiquidGlass(
  borderRadius: BorderRadius.circular(20),
  child: const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Now playing'),
  ),
)
```

Keep glass to a few surfaces: every frosted surface reads the backdrop. The
shell groups its own chrome into one `BackdropGroup`; never put glass on list
cells.
