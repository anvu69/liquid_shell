// The SDK's Cupertino files the tests use, for the reason the lib barrel
// (lib/src/material_sdk.dart) gives: Flutter 3.50 deprecates the library
// package:flutter/cupertino.dart, not its src files. Test-only, so the lib
// barrel stays Material-only. tool/check_material_seam.sh keeps the
// deprecated library out of test/.
export 'package:flutter/src/cupertino/app.dart';
export 'package:flutter/src/cupertino/route.dart';
export 'package:flutter/widgets.dart';
