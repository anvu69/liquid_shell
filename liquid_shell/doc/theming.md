# Theming

All glass reads one `ThemeExtension`, `LiquidGlassTheme`. Without one,
`LiquidGlassTheme.of(context)` derives it from the **displayed**
`Theme.of(context).colorScheme` (never from the platform brightness), so
`themeMode` and nested `Theme` widgets just work.

## Fields and defaults

| Field | Light | Dark | Used for |
|---|---|---|---|
| `tint` | `surface` @ 0.72 | `surface` @ 0.90 | frosted fill |
| `solid` | `surface` | `surface` | solid fill |
| `border` | `outline` @ 0.28 | `onSurface` @ 0.18 | 1px outline |
| `borderWidth` | 1 | 1 | outline width |
| `rimHighlight` | white @ 0.50 | white @ 0.18 | frosted top-edge highlight |
| `shadow` | `#24000000`, offset (0, 6), blur 20, spread −2 | same | drawn outside the shape only |
| `blurSigma` | 10 | 10 | frosted blur |
| `borderRadius` | pill (999) | pill | bars, circles |
| `labelStyle` | 10/14, w600, letter spacing 0.4, theme font | same | compact tab labels |

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

```dart
final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));
final glass = LiquidGlassTheme.fromColorScheme(scheme).copyWith(
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
