import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/search/search_controller.dart';

/// A glass segmented control for search scopes ("All | Songs | Places"),
/// bound to [controller]'s `scopeIndex` (spec P3b §4.4, Q5). Place it at
/// the top of the search page's content while the search is active.
class LiquidSearchScopeBar extends StatelessWidget {
  /// Creates the bar.
  const LiquidSearchScopeBar({
    required this.controller,
    required this.scopes,
    super.key,
  });

  /// The search controller.
  final LiquidSearchController controller;

  /// Scope titles, at least two.
  final List<String> scopes;

  @override
  Widget build(BuildContext context) {
    assert(
      scopes.length >= 2,
      'LiquidSearchScopeBar needs two scopes or more.',
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<LiquidSearchValue>(
      valueListenable: controller,
      builder: (context, value, _) => LiquidGlass(
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final (i, title) in scopes.indexed)
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: value.scopeIndex == i,
                    inMutuallyExclusiveGroup: true,
                    label: title,
                    onTap: () => controller.scopeIndex = i,
                    excludeSemantics: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                        onTap: () => controller.scopeIndex = i,
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          constraints: const BoxConstraints(minHeight: 36),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: value.scopeIndex == i
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: value.scopeIndex == i
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
