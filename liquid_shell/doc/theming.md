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
| `rimHighlight` | white @ 0.50 | white @ 0.18 | frosted top-edge highlight; liquid specular rim |
| `shadow` | `#24000000`, offset (0, 6), blur 20, spread −2 | same | drawn outside the shape only |
| `blurSigma` | 10 | 10 | blur, frosted tier only |
| `borderRadius` | pill (999) | pill | bars, circles |
| `labelStyle` | 10/14, w600, letter spacing 0.4, theme font | same | compact tab labels |
| `liquidTint` | `surface` @ 0.40 | `surface` @ 0.45 | colour over liquid glass, inside the lens shader, liquid tier only |
| `refraction` | 1 | 1 | liquid lens strength: 0 is flat glass, 2 doubles it |
| `dispersion` | 0.3 | 0.3 | liquid colour fringe in the lens band, 0–1; 0 turns it off |
| `liquidBlurSigma` | 2 | 2 | liquid blur under the lens; 0 for none |

Tab colours come from the `ColorScheme`: the selected cell is `primary` on
a `primaryContainer` chip, others `onSurfaceVariant`. The selected label
keeps the same style; only its colour changes. Top-bar labels use
`textTheme.labelMedium`; sidebar rows use `textTheme.bodyLarge`
(`onPrimaryContainer` on `primaryContainer` when selected).

`labelStyle` sets the compact (bottom) tab labels. In a narrow bottom bar
(the shell narrower than `kLiquidNarrowWidth`, 340) a label that does not
fit its cell first takes the cell's side padding, then shrinks, never below
10pt (or its own size when that is smaller), and only then ends in an
ellipsis. A `labelStyle` above 10pt can therefore draw smaller there.
Between text scale 1 and 1.6 this also shrinks labels below the size the
user chose; from 1.6 the cells are icon-only with a large content viewer.
The pill height never changes, because a shrunk label keeps its line
height.

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
gets `solid` @ 0.40 (0.45 when `solid` is dark). For a stronger or flatter
brand lens, set `refraction` (0 flat, 2 double).

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
