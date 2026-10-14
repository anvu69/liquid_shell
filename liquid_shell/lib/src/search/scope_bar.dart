import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/segmented/segmented_control.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

/// The search scopes ("All | Songs | Places") as a [LiquidSegmentedControl],
/// bound to [controller]'s `scopeIndex` (spec VK-550 §11). Place it at the
/// top of the search page's content.
///
/// When native chrome draws the scopes (iOS 26+, `LiquidSearch.scopes`
/// given) it builds nothing, so the page needs no branching.
class LiquidSearchScopeBar extends StatelessWidget {
  /// Creates the bar.
  const LiquidSearchScopeBar({
    required this.controller,
    this.scopes,
    super.key,
  });

  /// The search controller.
  final LiquidSearchController controller;

  /// Scope titles, at least two. Null: the enclosing shell's
  /// `LiquidSearch.scopes`. When both are given they must be equal.
  final List<String>? scopes;

  /// Selects scope [i] and puts the keyboard away, keeping the search
  /// active, as a tap on UIKit's scope bar does (VK-571).
  void _select(int i) => controller
    ..scopeIndex = i
    ..dismissKeyboard();

  @override
  Widget build(BuildContext context) {
    final shell = LiquidShellScope.maybeOf(context);
    final shellScopes = shell?.searchScopes;
    assert(
      scopes == null || shellScopes == null || listEquals(scopes, shellScopes),
      "LiquidSearchScopeBar.scopes $scopes differ from the shell's "
      'LiquidSearch.scopes $shellScopes. Give them in one place.',
    );
    if (shell?.nativeSearchScopes ?? false) return const SizedBox.shrink();
    final titles = scopes ?? shellScopes;
    assert(
      titles != null && titles.length >= 2,
      'LiquidSearchScopeBar needs two scopes or more: give it scopes, or '
      'give LiquidSearch.scopes to the shell.',
    );
    if (titles == null || titles.length < 2) return const SizedBox.shrink();
    final segments = [for (final t in titles) LiquidSegment(label: t)];
    return ValueListenableBuilder<LiquidSearchValue>(
      valueListenable: controller,
      builder: (context, value, _) => LiquidSegmentedControl(
        segments: segments,
        selectedIndex: value.scopeIndex.clamp(0, titles.length - 1),
        onChanged: _select,
      ),
    );
  }
}
