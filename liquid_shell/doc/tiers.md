# Glass tiers

| Tier | Drawn as | Ships in |
|---|---|---|
| `liquid` | refracting glass | a separate adapter package (planned); none in this package |
| `frosted` | backdrop blur, tint, 1px border, rim highlight, outside shadow | built in |
| `solid` | opaque fill, border, outside shadow; no blur | built in |

A tier change cross-fades over 200ms (instantly with reduce motion). The
child of a `LiquidGlass` is never rebuilt by a tier change, so focus and
scroll position survive.

## How the tier is chosen

`LiquidGlassPolicy.resolve(context, signals)`:

1. `forcedTier` set → that tier. If it has no supported renderer, step down
   liquid → frosted → solid (logged once in debug builds).
2. Any signal asks for solid (`LiquidGlassSignals.prefersSolid`) → solid.
3. Otherwise the richest tier with a supported renderer: liquid if a
   registered liquid renderer's `isSupported` is true, else frosted.

Signals:

| Field | Source |
|---|---|
| `reduceTransparency` | iOS Reduce Transparency. Android: animator duration scale 0, contrast > 0 (API 34+), or the high-text-contrast setting |
| `highContrast` | `MediaQuery.highContrastOf` (reported by iOS) |
| `powerSave` | Android battery saver (iOS Low Power Mode is ignored, like the system glass) |
| `blurDisabled` | Android 12+ `WindowManager.isCrossWindowBlurEnabled` false: battery saver, GPU without blur, or the developer "disable window blurs" switch |
| `canBlur` | false only on Android without Impeller (`ImageFilter.isShaderFilterSupported`, Skia on API 28 and lower) |

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

## Writing a renderer

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

`flutter test` reports Android without shader filters, so the probe answers
"cannot blur" and glass is solid. Set the override in
`test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => debugLiquidGlassCanBlurOverride = true);
  tearDown(() {
    debugLiquidGlassCanBlurOverride = null;
    debugResetLiquidGlassSignals();
  });
  await testMain();
}
```
