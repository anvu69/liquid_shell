// The SDK's Material library, for liquid_shell's own code and tests (VK-1077).
//
// Flutter 3.50 deprecates the library `package:flutter/material.dart` (users
// are pointed at package:material_ui), while every member and every
// `src/material` file stays undeprecated. material_ui is not an option yet:
// its types are distinct from the SDK's, so an app's SDK `ThemeData` would
// be invisible to us and `LiquidGlassTheme` would stop fitting into it
// (spec docs/specs/2026-11-18-material-seam-design.md).
//
// So this file re-exports exactly the `src/material` files liquid_shell uses,
// which is what `material.dart` itself does. The types are the SDK's own;
// users see no change. `implementation_imports` checks import directives
// only, so these exports need no ignore, and every importer of this file
// imports its own package. Add a file here when a new symbol is needed.
//
// Exit: the move to material_ui, or the SDK deprecating anything below
// (the stable CI leg reports it on this file). tool/check_material_seam.sh
// keeps the deprecated library out of lib/ and test/.
export 'package:flutter/src/material/app.dart';
export 'package:flutter/src/material/badge.dart';
export 'package:flutter/src/material/color_scheme.dart';
export 'package:flutter/src/material/colors.dart';
export 'package:flutter/src/material/dialog.dart';
export 'package:flutter/src/material/icon_button.dart';
export 'package:flutter/src/material/icons.dart';
export 'package:flutter/src/material/ink_well.dart';
export 'package:flutter/src/material/input_decorator.dart';
export 'package:flutter/src/material/material.dart';
export 'package:flutter/src/material/scaffold.dart';
export 'package:flutter/src/material/text_field.dart';
export 'package:flutter/src/material/text_theme.dart';
export 'package:flutter/src/material/theme.dart';
export 'package:flutter/src/material/theme_data.dart';
export 'package:flutter/src/material/tooltip.dart';
export 'package:flutter/src/material/typography.dart';
export 'package:flutter/widgets.dart';
