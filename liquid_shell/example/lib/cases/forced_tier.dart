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
              const Text('No liquid renderer is registered: drawing frosted.'),
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
