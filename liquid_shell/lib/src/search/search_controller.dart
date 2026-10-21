import 'package:flutter/foundation.dart';

/// Where the search is.
enum LiquidSearchPhase {
  /// Another tab is selected.
  idle,

  /// The search tab is selected; the field has no focus.
  selected,

  /// The search is active: the field has focus, or its keyboard was put
  /// away (`LiquidSearchController.dismissKeyboard`) and the search stays
  /// up with its ×.
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

  /// The search is active: the field has focus, or its keyboard was put
  /// away (`LiquidSearchController.dismissKeyboard`, a drag on the
  /// results, a scope tap) and the search stays up with its ×.
  final bool active;

  /// Index into the scope titles (`LiquidSearch.scopes`).
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

  /// The app changed the scope.
  void scopeSetByApp(int index);

  /// Put the keyboard away; the search stays active.
  void dismissKeyboard();
}

/// The search query as a [ValueListenable] (Flutter's stream of values),
/// plus commands for the shell's field. Owned by the app,
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

  /// Replaces the text. The field shows it. Does not call
  /// `LiquidSearch.onChanged`. The same text is a no-op, also during a
  /// composition.
  ///
  /// Write only for an app action (a recent search tapped, a reset), never
  /// in reply to `LiquidSearch.onChanged`: a write computed from the user's
  /// text may be stale when it lands, and erases keystrokes in flight.
  /// Apple's Vietnamese Telex never marks its text, so
  /// [LiquidSearchValue.composing] does not warn you.
  ///
  /// A write during an IME composition (marked text) is held by both
  /// fields, then resolved differently: natively the user's next change,
  /// the commit included, drops it (the user wins); in the Flutter field it
  /// replaces the committed text once the composition ends (the app wins).
  set text(String text) => value = value.copyWith(text: text);

  /// The app's write. A new [LiquidSearchValue.text] goes to the field and
  /// ends the composition; the same text changes nothing. A new
  /// [LiquidSearchValue.scopeIndex] goes to the native scope bar. `active`
  /// and `composing` stay the field's: the ones in [next] are ignored.
  @override
  set value(LiquidSearchValue next) {
    final current = value;
    final textChanged = next.text != current.text;
    final scopeChanged = next.scopeIndex != current.scopeIndex;
    super.value = LiquidSearchValue(
      text: next.text,
      composing: !textChanged && current.composing,
      active: current.active,
      scopeIndex: next.scopeIndex,
    );
    if (textChanged) _driver?.textSetByApp(next.text);
    if (scopeChanged) _driver?.scopeSetByApp(next.scopeIndex);
  }

  /// The field's own edit: never goes back to the field.
  void _applyEdit(LiquidSearchValue next) {
    assert(next.scopeIndex >= 0, 'scopeIndex must not be negative.');
    super.value = next;
  }

  /// Whether the search is active, with or without the keyboard.
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

  /// Ends the search: unfocuses the field and keeps the text (unlike ×).
  void deactivate() => _driver?.deactivate();

  /// Puts the keyboard away and keeps the search active, with its text and
  /// its ×, as a drag on Apple Music's results does. Only while
  /// [isActive]; otherwise nothing happens. Natively the field resigns
  /// first responder; the Flutter field unfocuses. Neither writes text, so
  /// an IME composition ends with its text as composed. A tap on the field
  /// brings the keyboard back.
  ///
  /// The shell already calls it on a user drag of its body
  /// (`LiquidSearch.dismissKeyboardOnDrag`) and `LiquidSearchScopeBar` on
  /// a scope tap; call it for a control of your own.
  void dismissKeyboard() => _driver?.dismissKeyboard();

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
