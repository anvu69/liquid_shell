import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell/src/dialogs/dialog_layout.dart';
import 'package:liquid_shell/src/dialogs/dialog_metrics.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Shows [request] as a Flutter glass dialog on the root navigator (spec
/// P3a §7). Completes with the chosen action's index, or null when it is
/// dismissed without a choice.
Future<int?> showGlassDialog(
  BuildContext context,
  LiquidNativeDialogRequest request, {
  LiquidShellStrings strings = const LiquidShellStrings(),
}) {
  final alert = request.kind == LiquidNativeDialogKind.alert;
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: !alert,
    barrierLabel: alert ? null : strings.dismiss,
    barrierColor: kDialogBarrier,
    transitionDuration: alert ? kAlertDuration : kSheetDuration,
    pageBuilder: (context, animation, secondaryAnimation) => alert
        ? GlassAlert(request: request)
        : GlassActionSheet(request: request),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        _transition(context, animation, child, request.kind),
  );
}

/// Whether the screen is wide enough for the anchored action-sheet card.
bool isRegularDialogWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= const LiquidShellBreakpoints().regular;

Widget _transition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
  LiquidNativeDialogKind kind,
) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return FadeTransition(opacity: animation, child: child);
  }
  final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
  if (kind == LiquidNativeDialogKind.actionSheet &&
      !isRegularDialogWidth(context)) {
    return SlideTransition(
      position: eased.drive(
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
      ),
      child: child,
    );
  }
  final from = kind == LiquidNativeDialogKind.alert
      ? kAlertScaleFrom
      : kCardScaleFrom;
  return FadeTransition(
    opacity: eased,
    child: ScaleTransition(
      scale: eased.drive(Tween<double>(begin: from, end: 1)),
      child: child,
    ),
  );
}

Widget _routeSemantics(String? label, Widget child) => Semantics(
  scopesRoute: true,
  namesRoute: true,
  explicitChildNodes: true,
  label: label,
  child: child,
);

Widget _glassGroup(Widget child) => LiquidGlass(
  borderRadius: const BorderRadius.all(Radius.circular(kSheetRadius)),
  child: Material(
    type: MaterialType.transparency,
    child: Padding(
      padding: const EdgeInsets.all(kSheetGroupPadding),
      child: child,
    ),
  ),
);

Widget _stack(List<Widget> buttons) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (n, button) in buttons.indexed) ...[
      if (n > 0) const SizedBox(height: kActionGap),
      button,
    ],
  ],
);

/// The label style of a dialog action.
TextStyle dialogActionTextStyle(
  BuildContext context, {
  required bool emphasised,
}) => (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
  fontSize: kActionFontSize,
  fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
);

/// The Flutter glass alert (spec P3a §7.1). Pops the chosen index.
class GlassAlert extends StatelessWidget {
  /// Creates the alert.
  const GlassAlert({required this.request, super.key});

  /// What to show.
  final LiquidNativeDialogRequest request;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final actions = request.actions;
    final preferred = request.preferredIndex;
    final cancel = actions.indexWhere(
      (action) => action.style == LiquidNativeDialogActionStyle.cancel,
    );
    final width = math.min(kAlertWidth, media.size.width - 2 * kDialogMargin);
    final sideBySide = alertActionsSideBySide(
      labels: [for (final action in actions) action.label],
      style: dialogActionTextStyle(context, emphasised: true),
      textScaler: media.textScaler,
      textDirection: Directionality.of(context),
      rowWidth: width - kAlertPadding.horizontal,
    );
    final order = alertDisplayOrder(actions, sideBySide: sideBySide);
    final focused = firstEnabled(actions, [preferred, ...order]);
    // Return picks the default only when there is an enabled one (spec
    // §7.1). Otherwise Enter must reach the focused button's ActivateIntent:
    // CallbackShortcuts swallows every key it binds, even a no-op.
    final enterPicksPreferred = preferred != null && actions[preferred].enabled;
    void choose(int? index) {
      if (index == null || index < 0 || !actions[index].enabled) return;
      Navigator.of(context).pop(index);
    }

    Widget button(int index) => GlassDialogButton(
      action: actions[index],
      prominent: index == preferred,
      autofocus: index == focused,
      onPressed: () => choose(index),
    );
    final buttons = sideBySide
        ? Row(
            children: [
              Expanded(child: button(order[0])),
              const SizedBox(width: kActionGap),
              Expanded(child: button(order[1])),
            ],
          )
        : _stack([for (final index in order) button(index)]);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => choose(cancel),
        if (enterPicksPreferred) ...{
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              choose(preferred),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
              choose(preferred),
        },
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kDialogMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: media.size.height * kDialogMaxHeightFraction,
            ),
            child: _routeSemantics(
              request.title ?? request.message,
              LiquidGlass(
                borderRadius: BorderRadius.circular(kAlertRadius),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: kAlertPadding,
                    // The header scrolls first; the actions stay visible
                    // and scroll themselves only past what is left after
                    // one action's height of header (large text).
                    child: LayoutBuilder(
                      builder: (context, constraints) => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kAlertHeaderInset,
                                ),
                                child: DialogHeader(
                                  title: request.title,
                                  message: request.message,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: kHeaderGap),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.max(
                                kActionHeight,
                                constraints.maxHeight -
                                    kHeaderGap -
                                    kActionHeight,
                              ),
                            ),
                            child: SingleChildScrollView(child: buttons),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Flutter glass action sheet (spec P3a §7.2): at the bottom with a
/// separate cancel action when compact, an anchored card without one when
/// regular. Pops the chosen index; a tap outside pops null.
class GlassActionSheet extends StatelessWidget {
  /// Creates the sheet.
  const GlassActionSheet({required this.request, super.key});

  /// What to show.
  final LiquidNativeDialogRequest request;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final groups = sheetGroups(request.actions);
    final regular = isRegularDialogWidth(context);
    // A popover has no cancel row (UIKit): a tap outside cancels. A sheet
    // whose only action is cancel still shows it.
    final cancel = groups.cancel;
    final stacked = regular && groups.main.isEmpty && cancel != null
        ? [cancel]
        : groups.main;
    final apart = regular ? null : cancel;
    final first = firstEnabled(request.actions, [...stacked, apart]);
    Widget button(int index) => GlassDialogButton(
      action: request.actions[index],
      autofocus: index == first,
      onPressed: () => Navigator.of(context).pop(index),
    );
    final hasHeader = request.title != null || request.message != null;
    final group = _glassGroup(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header and actions scroll together when they do not fit.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasHeader)
                    Padding(
                      padding: kSheetHeaderPadding,
                      child: DialogHeader(
                        title: request.title,
                        message: request.message,
                      ),
                    ),
                  _stack([for (final index in stacked) button(index)]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final label = request.title ?? request.message;
    final Widget sheet;
    if (regular) {
      sheet = CustomSingleChildLayout(
        delegate: AnchoredCardLayout(
          anchor: request.anchor,
          padding: media.padding,
        ),
        child: SizedBox(
          width: kSheetPopoverWidth,
          child: _routeSemantics(label, group),
        ),
      );
    } else {
      sheet = Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            kSheetSideMargin,
            media.padding.top + kSheetSideMargin,
            kSheetSideMargin,
            media.viewPadding.bottom + kSheetSideMargin,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
            child: _routeSemantics(
              label,
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(child: group),
                  if (apart != null) ...[
                    const SizedBox(height: kActionGap),
                    _glassGroup(button(apart)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: sheet,
    );
  }
}

/// Places the regular-width action-sheet card at its anchor.
class AnchoredCardLayout extends SingleChildLayoutDelegate {
  /// Creates the layout.
  AnchoredCardLayout({required this.anchor, required this.padding});

  /// Where the card points, in global logical coordinates.
  final Rect? anchor;

  /// The screen's safe area.
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth,
          math.max(
            0,
            constraints.maxHeight - padding.vertical - 2 * kAnchorGap,
          ),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => anchoredCardOffset(
    screen: size,
    padding: padding,
    card: childSize,
    anchor: anchor,
  );

  @override
  bool shouldRelayout(AnchoredCardLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.padding != padding;
}

/// One action capsule of a glass dialog.
class GlassDialogButton extends StatelessWidget {
  /// Creates the button.
  const GlassDialogButton({
    required this.action,
    required this.onPressed,
    this.prominent = false,
    this.autofocus = false,
    super.key,
  });

  /// What it shows and whether it is enabled.
  final LiquidNativeDialogAction action;

  /// Called on a tap when enabled.
  final VoidCallback onPressed;

  /// The alert's preferred action: a bold label, on a filled capsule
  /// unless it is destructive (as UIKit on iOS 26).
  final bool prominent;

  /// Whether it takes focus first.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destructive =
        action.style == LiquidNativeDialogActionStyle.destructive;
    final accent = destructive ? scheme.error : scheme.primary;
    final filled = prominent && action.enabled && !destructive;
    final fill = filled
        ? accent
        : scheme.onSurface.withValues(alpha: kActionFillAlpha);
    final Color label;
    if (!action.enabled) {
      label = scheme.onSurface.withValues(alpha: 0.38);
    } else if (filled) {
      label = scheme.onPrimary;
    } else {
      label = accent;
    }
    return Semantics(
      button: true,
      enabled: action.enabled,
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: autofocus,
          onTap: action.enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kActionHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kActionLabelPadding,
                  vertical: 8,
                ),
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: dialogActionTextStyle(
                    context,
                    emphasised: prominent,
                  ).copyWith(color: label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog's title and message, aligned to the leading edge (as UIKit on
/// iOS 26).
class DialogHeader extends StatelessWidget {
  /// Creates the header.
  const DialogHeader({this.title, this.message, super.key});

  /// The title, or null.
  final String? title;

  /// The message, or null.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = this.title;
    final message = this.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: kTitleFontSize,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        if (title != null && message != null)
          const SizedBox(height: kTitleMessageGap),
        if (message != null)
          Text(
            message,
            textAlign: TextAlign.start,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: kMessageFontSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
