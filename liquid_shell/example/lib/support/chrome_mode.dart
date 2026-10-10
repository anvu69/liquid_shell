import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// How the example draws its chrome (spec 2026-10-10 §9.2).
enum ExampleChromeMode {
  /// The library's default: native chrome where it engages (iOS 26),
  /// otherwise the automatic glass tier.
  native,

  /// The Flutter liquid tier, forced. A forced tier also turns native
  /// chrome off, so the two can be compared on the same device.
  flutterLiquid,
}

/// The app-wide chrome mode, shared by every case and every pushed page.
class ChromeModeScope
    extends InheritedNotifier<ValueNotifier<ExampleChromeMode>> {
  /// Provides [notifier] to [child].
  const ChromeModeScope({
    required ValueNotifier<ExampleChromeMode> super.notifier,
    required super.child,
    super.key,
  });

  /// The nearest notifier, or null outside a scope.
  static ValueNotifier<ExampleChromeMode>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChromeModeScope>()?.notifier;
}

/// Wraps one case page in the mode's [LiquidGlassScope].
///
/// The scope is always there (with no forced tier in
/// [ExampleChromeMode.native]), so switching never rebuilds the case. The
/// switch itself is drawn by `DemoPage` under its title (and by the form
/// factors case in its app bar), never over the chrome.
class CaseFrame extends StatelessWidget {
  /// Frames [child].
  const CaseFrame({required this.child, super.key});

  /// The case page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final liquid =
        ChromeModeScope.maybeOf(context)?.value ==
        ExampleChromeMode.flutterLiquid;
    return LiquidGlassScope(
      policy: LiquidGlassPolicy(
        forcedTier: liquid ? LiquidGlassTier.liquid : null,
      ),
      child: child,
    );
  }
}

/// "Native / Flutter liquid" (L4).
class ChromeModeSwitch extends StatelessWidget {
  /// Creates the switch for [mode].
  const ChromeModeSwitch({required this.mode, super.key});

  /// The app-wide mode.
  final ValueNotifier<ExampleChromeMode> mode;

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: 'Chrome: native or Flutter liquid',
        child: SegmentedButton<ExampleChromeMode>(
          key: const ValueKey('chrome-mode'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: ExampleChromeMode.native,
              label: Text(ios ? 'Native' : 'Auto'),
              tooltip:
                  'Native chrome on iOS 26; elsewhere the library '
                  'picks the tier',
            ),
            const ButtonSegment(
              value: ExampleChromeMode.flutterLiquid,
              label: Text('Flutter liquid'),
            ),
          ],
          selected: {mode.value},
          onSelectionChanged: (s) => mode.value = s.single,
        ),
      ),
    );
  }
}
