import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/search/search_layout.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// The fallback field (or the idle ⌕ circle).
const kSearchFieldKey = ValueKey<String>('liquid-search-field');

/// The fallback collapsed circle (previous tab): the tab bar's own
/// minimized circle while the search tab is selected.
const kSearchCollapsedKey = ValueKey<String>('liquid-search-collapsed');

/// The fallback × circle.
const kSearchCancelKey = ValueKey<String>('liquid-search-cancel');

const _capsule = BorderRadius.all(Radius.circular(999));

/// The field morphs on the bar's clock: it shrinks into
/// the ⌕ as the bar expands, and grows out of it as the bar collapses into
/// the previous tab's circle, as native does in step.
final SpringCurve _toIdle = SpringCurve(
  TabSprings.expand,
  delay: TabSprings.tapDelay,
);
final SpringCurve _toSelected = SpringCurve(TabSprings.collapse);

/// The fallback search field on glass. The `TextField` is
/// the first child of the same chain in every phase, so a phase change
/// never rebuilds it; in idle it is invisible and a ⌕ glyph takes taps.
class SearchFieldGlass extends StatelessWidget {
  /// Creates the field.
  const SearchFieldGlass({
    required this.phase,
    required this.editing,
    required this.focus,
    required this.placeholder,
    required this.searchLabel,
    required this.searchIcon,
    required this.onOpen,
    required this.onSubmitted,
    required this.onDeactivate,
    required this.cancelLabel,
    this.inlineCancel,
    this.highlight = const _Off(),
    super.key,
  });

  /// The search phase: idle shows the ⌕ circle, the others the field.
  final LiquidSearchPhase phase;

  /// The field's text, owned by the shell for its lifetime.
  final TextEditingController editing;

  /// The field's focus, owned by the shell for its lifetime.
  final FocusNode focus;

  /// The empty field's text.
  final String placeholder;

  /// The search destination's label: the idle circle's semantics.
  final String searchLabel;

  /// The search destination's icon: the idle circle's glyph.
  final Widget searchIcon;

  /// Idle tap: select the search tab.
  final VoidCallback onOpen;

  /// The keyboard's Search key.
  final ValueChanged<String> onSubmitted;

  /// Esc.
  final VoidCallback onDeactivate;

  /// Regular layout: an × inside the field while active.
  final VoidCallback? inlineCancel;

  /// The inline ×'s tooltip and semantics (`LiquidShellStrings.cancelSearch`).
  final String cancelLabel;

  /// Lens drag over the idle ⌕.
  final ValueListenable<bool> highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idle = phase == LiquidSearchPhase.idle;
    final cancel = inlineCancel;
    return LiquidGlass(
      borderRadius: _capsule,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: idle,
                child: ExcludeSemantics(
                  excluding: idle,
                  child: Opacity(
                    opacity: idle ? 0 : 1,
                    // VK-779: never narrower than its fixed parts. The
                    // compact landscape ⌕ is 44 wide, and the first frame
                    // out of idle paints the Row there; clipped, it shows
                    // its leading edge. Layout only, in every phase: the
                    // field is never rebuilt.
                    child: ConstraintsTransformBox(
                      constraintsTransform: _atLeastFixedParts,
                      alignment: AlignmentDirectional.centerStart,
                      clipBehavior: Clip.hardEdge,
                      child: Row(
                        children: [
                          const SizedBox(width: _fieldInset),
                          Icon(
                            Icons.search,
                            size: _fieldIcon,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: _fieldIconGap),
                          Expanded(
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): onDeactivate,
                              },
                              child: TextField(
                                controller: editing,
                                focusNode: focus,
                                textInputAction: TextInputAction.search,
                                onSubmitted: onSubmitted,
                                decoration: InputDecoration.collapsed(
                                  hintText: placeholder,
                                ),
                              ),
                            ),
                          ),
                          if (cancel != null &&
                              phase == LiquidSearchPhase.active)
                            Semantics(
                              container: true,
                              button: true,
                              label: cancelLabel,
                              onTap: cancel,
                              excludeSemantics: true,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: cancelLabel,
                                onPressed: cancel,
                              ),
                            )
                          else
                            const SizedBox(width: _fieldInset),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (idle)
              Positioned.fill(
                child: TabHoverHighlight(
                  hovered: highlight,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: searchLabel,
                    onTap: onOpen,
                    excludeSemantics: true,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onOpen,
                      child: Center(
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: 26,
                            color: scheme.onSurfaceVariant,
                          ),
                          child: searchIcon,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The compact search row: the pill (built by the shell,
/// which also collapses into the previous tab's circle),
/// the field and ×, each animating between the phase's rects. Empty areas
/// pass touches to the body.
class CompactSearchChrome extends StatelessWidget {
  /// Creates the row.
  const CompactSearchChrome({
    required this.phase,
    required this.rects,
    required this.pill,
    required this.field,
    required this.onCancel,
    required this.strings,
    super.key,
  });

  /// The search phase.
  final LiquidSearchPhase phase;

  /// Where each part is in [phase].
  final CompactSearchRects rects;

  /// The pill of the other destinations: a `Positioned`, faded by the shell.
  final Widget pill;

  /// The field (a `SearchFieldGlass`, possibly wrapped by a chrome builder).
  final Widget field;

  /// The ×: clears and unfocuses.
  final VoidCallback onCancel;

  /// The shell's strings (the ×'s label).
  final LiquidShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : kSearchMorphDuration;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget part(
      Key key,
      Rect rect, {
      required bool shown,
      required Widget child,
    }) => AnimatedPositioned.fromRect(
      key: key,
      rect: rect,
      duration: duration,
      curve: kSearchMorphCurve,
      child: IgnorePointer(
        ignoring: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: duration,
            curve: kSearchMorphCurve,
            child: child,
          ),
        ),
      ),
    );
    Widget circle({
      required String label,
      required VoidCallback onTap,
      required Widget icon,
    }) => Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: LiquidGlass(
          borderRadius: _capsule,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(size: 24, color: color),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Positioned.fill(
      child: Stack(
        children: [
          pill,
          AnimatedPositioned.fromRect(
            key: kSearchFieldKey,
            rect: rects.field,
            // To and from idle the bar morphs too: the field takes its
            // spring (the curve follows the phase it goes to, so active →
            // selected, the keyboard closing, runs on collapse too). To
            // active, the keyboard opening, keeps the P3b ease.
            duration: duration == Duration.zero
                ? duration
                : switch (phase) {
                    LiquidSearchPhase.idle => _toIdle.duration,
                    LiquidSearchPhase.selected => _toSelected.duration,
                    LiquidSearchPhase.active => duration,
                  },
            curve: switch (phase) {
              LiquidSearchPhase.idle => _toIdle,
              LiquidSearchPhase.selected => _toSelected,
              LiquidSearchPhase.active => kSearchMorphCurve,
            },
            child: field,
          ),
          part(
            kSearchCancelKey,
            rects.cancel,
            shown: phase == LiquidSearchPhase.active,
            child: circle(
              label: strings.cancelSearch,
              onTap: onCancel,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

// The field Row's fixed parts: the leading inset, the search icon, its gap
// and the trailing inset, 56 in all. With the regular field's inline ×
// (an IconButton, at least 48) it needs 90; that field spans the body, so
// it is never that narrow.
const double _fieldInset = 14;
const double _fieldIcon = 20;
const double _fieldIconGap = 8;
const double _fieldFixedWidth =
    _fieldInset + _fieldIcon + _fieldIconGap + _fieldInset;

/// The field Row's constraints: at least its fixed parts wide.
BoxConstraints _atLeastFixedParts(BoxConstraints constraints) =>
    constraints.maxWidth < _fieldFixedWidth
    ? constraints.copyWith(maxWidth: _fieldFixedWidth)
    : constraints;

/// The default [SearchFieldGlass.highlight]: never on.
class _Off implements ValueListenable<bool> {
  const _Off();

  @override
  bool get value => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
