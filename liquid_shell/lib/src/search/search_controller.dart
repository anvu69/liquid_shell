import 'package:flutter/foundation.dart';

/// Where the search is (spec P3b §3.1).
enum LiquidSearchPhase {
  /// Another tab is selected.
  idle,

  /// The search tab is selected; the field has no focus.
  selected,

  /// The field has focus.
  active,
}

/// The search field's state.
@immutable
class LiquidSearchValue {
  /// Creates a value.
  const LiquidSearchValue({
    this.text = '',
    this.composing = false,
    this.active = false,
    this.scopeIndex = 0,
  });

  /// No text, not active, the first scope.
  static const empty = LiquidSearchValue();

  /// The field's text, IME composition included.
  final String text;

  /// An IME composition is in progress (Japanese kana natively; also
  /// Vietnamese Telex in the Flutter field on Android): [text] may still
  /// change. Filter on it if you like. Writing the same text back through
  /// the controller is a no-op.
  final bool composing;

  /// The field has focus.
  final bool active;

  /// Index into the app's scope titles (`LiquidSearchScopeBar`).
  final int scopeIndex;

  /// A copy with the given fields replaced.
  LiquidSearchValue copyWith({
    String? text,
    bool? composing,
    bool? active,
    int? scopeIndex,
  }) => LiquidSearchValue(
    text: text ?? this.text,
    composing: composing ?? this.composing,
    active: active ?? this.active,
    scopeIndex: scopeIndex ?? this.scopeIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidSearchValue &&
      other.text == text &&
      other.composing == composing &&
      other.active == active &&
      other.scopeIndex == scopeIndex;

  @override
  int get hashCode => Object.hash(text, composing, active, scopeIndex);

  @override
  String toString() =>
      'LiquidSearchValue(text: $text, composing: $composing, active: $active, '
      'scopeIndex: $scopeIndex)';
}

/// What a shell does for the controller's commands. Internal: the barrel
/// does not export it.
abstract interface class SearchDriver {
  /// Focus the field.
  void activate();

  /// Unfocus the field, keep the text.
  void deactivate();

  /// The app replaced the text.
  void textSetByApp(String text);
}

/// The search query as a [ValueListenable] (Flutter's stream of values),
/// plus commands for the shell's field (spec P3b §4.3). Owned by the app,
/// so the query outlives tab switches.
///
/// The app creates it, keeps it alive at least as long as the shell that
/// shows it, and disposes it; the shell never does. Giving the shell a
/// different controller between builds is fine: the shell re-attaches.
///
/// From the app's side, [LiquidSearchValue.text] and
/// [LiquidSearchValue.scopeIndex] are writable (through [text],
/// [scopeIndex] or [value]); [LiquidSearchValue.active] and
/// [LiquidSearchValue.composing] belong to the field and are read-only:
/// use [activate] and [deactivate] for the focus.
class LiquidSearchController extends ValueNotifier<LiquidSearchValue> {
  /// Creates a controller.
  LiquidSearchController({String text = '', int scopeIndex = 0})
    : assert(scopeIndex >= 0, 'scopeIndex must not be negative.'),
      super(LiquidSearchValue(text: text, scopeIndex: scopeIndex));

  SearchDriver? _driver;

  /// The field's text.
  String get text => value.text;

  /// Replaces the text. The field shows it (natively once no IME
  /// composition is in progress). Does not call `LiquidSearch.onChanged`.
  /// The same text is a no-op, also during a composition.
  set text(String text) => value = value.copyWith(text: text);

  /// The app's write. A new [LiquidSearchValue.text] goes to the field and
  /// ends the composition; the same text changes nothing. `active` and
  /// `composing` stay the field's: the ones in [next] are ignored.
  @override
  set value(LiquidSearchValue next) {
    final current = value;
    final textChanged = next.text != current.text;
    super.value = LiquidSearchValue(
      text: next.text,
      composing: !textChanged && current.composing,
      active: current.active,
      scopeIndex: next.scopeIndex,
    );
    if (textChanged) _driver?.textSetByApp(next.text);
  }

  /// The field's own edit: never goes back to the field.
  void _applyEdit(LiquidSearchValue next) {
    assert(next.scopeIndex >= 0, 'scopeIndex must not be negative.');
    super.value = next;
  }

  /// Whether the field has focus.
  bool get isActive => value.active;

  /// The selected scope.
  int get scopeIndex => value.scopeIndex;

  set scopeIndex(int index) {
    assert(index >= 0, 'scopeIndex must not be negative.');
    value = value.copyWith(scopeIndex: index);
  }

  /// Focuses the field. Only while the search tab is selected; otherwise
  /// the shell ignores it (one debug line).
  void activate() => _driver?.activate();

  /// Unfocuses the field and keeps the text (unlike ×).
  void deactivate() => _driver?.deactivate();

  /// Empties the text; keeps the focus.
  void clear() => text = '';
}

/// Attaches the shell that shows [controller]. One at a time.
void attachSearchDriver(
  LiquidSearchController controller,
  SearchDriver driver,
) {
  assert(
    controller._driver == null || identical(controller._driver, driver),
    'A LiquidSearchController is attached to one LiquidShell at a time.',
  );
  controller._driver = driver;
}

/// Detaches [driver] if it is the attached one.
void detachSearchDriver(
  LiquidSearchController controller,
  SearchDriver driver,
) {
  if (identical(controller._driver, driver)) controller._driver = null;
}

/// The field's own edit (native or Flutter): updates the value and never
/// goes back to the field.
void applySearchEdit(
  LiquidSearchController controller,
  LiquidSearchValue next,
) {
  controller._applyEdit(next);
}
