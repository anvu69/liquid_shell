import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';

/// Size of the show-sidebar toggle.
const double kSidebarToggleSize = 48;

/// Distance of the toggle from the start edge and the top bar row.
const double kSidebarToggleInset = 20;

/// The 48pt glass circle that shows the sidebar.
class SidebarToggle extends StatelessWidget {
  /// Creates the toggle.
  const SidebarToggle({
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  /// Shows the sidebar.
  final VoidCallback onPressed;

  /// Tooltip and semantics label.
  final String tooltip;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: kSidebarToggleSize,
    child: LiquidGlass(
      child: Material(
        type: MaterialType.transparency,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: const Icon(Icons.view_sidebar_outlined),
        ),
      ),
    ),
  );
}
