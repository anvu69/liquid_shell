import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A brand glass theme with a light/dark switch.
class CustomThemeCase extends StatefulWidget {
  /// Creates the case.
  const CustomThemeCase({super.key});

  @override
  State<CustomThemeCase> createState() => _CustomThemeCaseState();
}

class _CustomThemeCaseState extends State<CustomThemeCase> {
  // #docregion readme
  int _index = 0;
  Brightness _brightness = Brightness.light;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: _brightness,
    );
    final glass = LiquidGlassTheme.fromColorScheme(scheme).copyWith(
      tint: scheme.primaryContainer.withValues(alpha: 0.6),
      blurSigma: 18,
      labelStyle: const TextStyle(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
    );
    final theme = ThemeData(colorScheme: scheme, extensions: [glass]);
    return Theme(
      data: theme,
      child: LiquidShell(
        destinations: kDemoDestinations,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        // The glass below is Flutter's: keep it on iOS 26 too.
        nativeChrome: LiquidNativeChrome.off,
        body: DemoPage(
          title: 'Brand glass',
          children: [
            SwitchListTile(
              title: const Text('Dark'),
              value: _brightness == Brightness.dark,
              onChanged: (dark) => setState(
                () => _brightness = dark ? Brightness.dark : Brightness.light,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // #enddocregion readme
}
