import 'package:flutter/widgets.dart';

/// Keeps a scroll child (a `PageView` page) alive once built: off screen
/// it stays in the tree, not laid out.
class KeptAlive extends StatefulWidget {
  /// Keeps [child] alive.
  const KeptAlive({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  State<KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
