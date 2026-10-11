import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Forces the glass tier for a subtree.
class ForcedTierCase extends StatefulWidget {
  /// Creates the case, optionally starting at [initialTier].
  const ForcedTierCase({this.initialTier = LiquidGlassTier.frosted, super.key});

  /// The tier selected first.
  final LiquidGlassTier initialTier;

  @override
  State<ForcedTierCase> createState() => _ForcedTierCaseState();
}

class _ForcedTierCaseState extends State<ForcedTierCase> {
  // The README shows the region below as a pasteable snippet, so `_tier`
  // starts at `frosted` there; `initState` (outside the region) then applies
  // `widget.initialTier`, which the goldens use to start at another tier.
  // #docregion readme
  int _index = 0;
  LiquidGlassTier _tier = LiquidGlassTier.frosted;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScope(
      policy: LiquidGlassPolicy(forcedTier: _tier),
      child: LiquidShell(
        destinations: kDemoDestinations,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        // The glass below is Flutter's: keep it on iOS 26 too.
        nativeChrome: LiquidNativeChrome.off,
        body: DemoPage(
          title: 'Forced tier',
          children: [
            SegmentedButton<LiquidGlassTier>(
              segments: [
                for (final tier in LiquidGlassTier.values)
                  ButtonSegment(value: tier, label: Text(tier.name)),
              ],
              selected: {_tier},
              onSelectionChanged: (s) => setState(() => _tier = s.single),
            ),
            if (_tier == LiquidGlassTier.liquid)
              const Text(
                'Liquid needs Impeller; without it this draws frosted.',
              ),
          ],
        ),
      ),
    );
  }
  // #enddocregion readme

  @override
  void initState() {
    super.initState();
    _tier = widget.initialTier;
  }
}
