# Glass tiers

| Tier | Drawn as | Ships in |
|---|---|---|
| `liquid` | the built-in lens shader (Impeller); see [liquid.md](liquid.md) | built in |
| `frosted` | backdrop blur, tint, 1px border, rim highlight, outside shadow | built in |
| `solid` | opaque fill, border, outside shadow; no blur | built in |

A tier change cross-fades over 200ms (instantly with reduce motion). The
child of a `LiquidGlass` is never rebuilt by a tier change, so focus and
scroll position survive.

## How the tier is chosen

`LiquidGlassPolicy.resolve(context, signals)`:

1. `forcedTier` set → that tier, stepping down liquid → frosted → solid
   when it has no supported renderer (logged once in debug builds). A
   forced tier wins over every signal.
2. `signals.prefersSolid` → solid.
3. `signals.prefersFrosted` → frosted.
4. Otherwise liquid.

Liquid is drawn by the first registered liquid renderer whose
`isSupported` is true, else by the built-in lens shader when it is
supported (Impeller's shader filters, the shader loaded, and no
`BackdropFilter` above the glass), else frosted.

Signals:

| Field | Source | Effect |
|---|---|---|
| `reduceTransparency` | iOS Reduce Transparency. Android: animator duration scale 0, contrast > 0 (API 34+), or the high-text-contrast setting | solid |
| `highContrast` | `MediaQuery.highContrastOf` (reported by iOS) | solid |
| `blurDisabled` | Android 12+ `WindowManager.isCrossWindowBlurEnabled` false: battery saver, GPU without blur, or the developer "disable window blurs" switch | solid, only when `powerSave` is off (battery saver turns window blurs off too) |
| `powerSave` | Android battery saver; iOS Low Power Mode | frosted |
| `lowEnd` | Android `isLowRamDevice`, or less than 3 GiB of memory | frosted |
| `glesOnly` | Android 10+ without Vulkan 1.1 | frosted |
| `slowFrames` | the frame guard: three 60-frame windows in a row with a raster p90 above 1.25 × the frame budget (1 s / refresh rate, never below 16.7 ms); profile and release only, for the rest of the session | frosted |

- `prefersSolid` = `reduceTransparency || highContrast || (blurDisabled && !powerSave)`.
- `prefersFrosted` = `powerSave || lowEnd || glesOnly || slowFrames`.

Without Impeller (Android 9 and lower, the web) there are no shader
filters, so the built-in liquid renderer is unsupported and glass is
frosted.

Android signals are best effort: OEM builds vary, and Android 16's "Reduce
blur effects" has no public API (on the API 36 emulator it is not exposed as
a setting). Every read that fails counts as off.

## Forcing a tier

```dart
LiquidGlassScope(
  policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid),
  child: MyShell(),
)
```

Put the scope in `MaterialApp.builder` to cover pages pushed above the
shell too.

## Your own rule

Every `LiquidGlass` draws `policy.rendererFor(context, policy.resolve(context,
signals))`, so overriding `resolve` changes the tier everywhere under the
scope:

```dart
/// Never refracts, even with a liquid renderer registered.
class FrostedAtMost extends LiquidGlassPolicy {
  const FrostedAtMost({super.renderers});

  @override
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals) {
    final tier = super.resolve(context, signals);
    return tier == LiquidGlassTier.liquid ? LiquidGlassTier.frosted : tier;
  }
}
```

A tier without a supported renderer steps down (liquid → frosted). Each
renderer's `isSupported` runs once per build, however often `resolve` and
`rendererFor` ask. Policies of different classes are never equal, so
swapping one in rebuilds the glass.

## Writing a renderer

A registered renderer wins over the built-in one of its tier, so this one
replaces the lens shader wherever it is supported:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';

class TintOnlyRenderer extends LiquidGlassRenderer {
  const TintOnlyRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.liquid;

  @override
  bool isSupported(BuildContext context) =>
      ui.ImageFilter.isShaderFilterSupported;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: spec.theme.tint,
          borderRadius: spec.borderRadius,
        ),
      );
}

LiquidGlassScope(
  policy: const LiquidGlassPolicy(renderers: [TintOnlyRenderer()]),
  child: MyShell(),
)
```

Rules: fill the parent, paint nothing outside the shape except a shadow, and
keep `isSupported` cheap. If `isSupported` throws, the error is reported and
the renderer counts as unsupported.

## Testing

`flutter test` has no shader filters unless it runs with
`--enable-impeller`, so glass is frosted and app tests need no setup. Reset
the signals between tests in `test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDown(debugResetLiquidGlassSignals);
  await testMain();
}
```

Leave `debugLiquidGlassCanRefractOverride` null there: `false` would pin
frosted in `flutter test --enable-impeller` runs too, where liquid glass
can be drawn (await `LiquidGlass.precache()` inside `tester.runAsync`
first).
