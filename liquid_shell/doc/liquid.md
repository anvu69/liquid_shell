# The liquid tier

`LiquidGlass` draws liquid glass by default wherever Flutter runs on
Impeller: iOS, Android 10+ and macOS. The web, Windows and Linux have no
Impeller shader filters by default, so glass there is frosted. The lens
is this package's own fragment shader; no other package is involved.

<img src="images/compare_iphone_basic.png" width="410" alt="Native iOS 26 (left) and Flutter liquid (right), iPhone">

## What it draws

- **Lens.** Across a 20pt band inside the edge the glass curves down like
  a thick lens. Content under that band is pulled in by up to about 27pt,
  so the band shows a mirrored strip of what lies further inside, as
  iOS 26 glass does; the middle is flat.
- **Specular rim.** A thin highlight, strongest on the top-left edge and
  fainter on the opposite one, plus a soft glow across the band.
- **Dispersion.** Red and blue bend slightly differently in the band, a
  faint colour fringe. `dispersion: 0` turns it off.
- **Blur and tint.** A light blur (σ 2) and the `liquidTint` colour,
  so what lies behind the glass stays recognisable.

A side that touches the screen edge (the sidebar's outer edges) has no
lens and no rim.

## Theme

| Field | Default | Effect |
|---|---|---|
| `liquidTint` | surface @ 40 % (light), 45 % (dark) | Colour over the glass; raise its alpha for more legibility |
| `refraction` | 1 | Lens strength; 0 is flat glass, 2 doubles it |
| `dispersion` | 0.3 | Colour fringe, 0–1 |
| `liquidBlurSigma` | 2 | Blur under the lens; 0 for none |

The same screen with one field changed at a time:

| `refraction: 0` | default (`refraction: 1`) | `refraction: 2` |
|---|---|---|
| <img src="images/liquid_refraction_0.png" width="240" alt="refraction 0: flat glass"> | <img src="images/liquid_default.png" width="240" alt="default liquid glass"> | <img src="images/liquid_refraction_2.png" width="240" alt="refraction 2: twice the lens"> |

| `dispersion: 0` | default (`dispersion: 0.3`) | default, dark |
|---|---|---|
| <img src="images/liquid_dispersion_0.png" width="240" alt="dispersion 0: no colour fringe"> | <img src="images/liquid_default.png" width="240" alt="default liquid glass"> | <img src="images/liquid_default_dark.png" width="240" alt="default liquid glass, dark"> |

## When it is not drawn

The tier drops to **frosted** without Impeller (Android 9 and lower, the
web), on Android 10+ devices without Vulkan 1.1 or with less than 3 GiB of
memory, in battery saver or iOS Low Power Mode, after sustained slow
frames, inside another `BackdropFilter`, and until the shader has loaded.
It drops to **solid** with Reduce Transparency, Increase Contrast, or
window blurs disabled outside battery saver. See [tiers.md](tiers.md).

## Limitations

- **Opaque output.** The lens writes opaque pixels. That is invisible in
  an opaque app, and an `Opacity`, `FadeTransition` or fading page
  transition above the glass fades it like frosted. But over a
  transparent backdrop it is a solid slab of the tint over black, not
  see-through glass:
  - add-to-app with a transparent `FlutterView`, or Android
    `TransparencyMode.transparent`;
  - an overlay window;
  - an image capture of a subtree (`RepaintBoundary.toImage`,
    share-as-image features).

  Force frosted for those surfaces:

  ```dart
  LiquidGlassScope(
    policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.frosted),
    child: shareableCard,
  )
  ```

- **Scaled or rotated ancestors.** The lens is placed on the glass's
  axis-aligned bounding box in screen pixels, and its corner radii, bezel,
  thickness and rim keep their unscaled size. Under a `Transform.scale`
  or a rotation (zoom page transitions, scale-in dialogs,
  `CupertinoContextMenu`) the lens corners therefore do not match the
  clip, and a rotated glass gets a misplaced lens. A transition is over in
  a few frames; for glass that stays transformed, force frosted.
- **One frame of lag.** The nearest route's transition and the nearest
  `Scrollable` repaint the lens in the same frame. Any other move is
  caught by a check after each frame and corrected one frame late: glass
  under a `CompositedTransformFollower`, or moved by an outer
  `Navigator`'s route or an outer `Scrollable`.
- **Inside another `BackdropFilter`** glass draws frosted: the lens cannot
  be placed in a nested filter's coordinates.

## First frame

The shader loads when the first `LiquidGlass` mounts; until then glass is
frosted and then cross-fades. To start liquid:

    Future<void> main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await LiquidGlass.precache();
      runApp(const MyApp());
    }

## Cost

All chrome shares one backdrop copy (`BackdropGroup`). Each surface adds a
small blur and one pass of the lens over its own area. Never put glass on
list cells.

In profile and release builds a frame guard watches raster times while
liquid glass is on screen. After three windows of 60 frames in a row whose
90th percentile is above 1.25 × the frame budget (1 s / refresh rate, never
less than 16.7 ms), the glass turns frosted for the rest of the session.

## Provenance

The shader is written from first principles (a rounded-rect distance
field, Snell's law, a Fresnel-like rim). No other glass package's code
was read or copied.
