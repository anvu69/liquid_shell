import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell/src/search/search.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Keeps a [LiquidSearchController] and the field that shows it in step
/// (spec P3b §8.2): the native field over the claim, or the shell's
/// Flutter field ([editing], [focus]). The controller is the truth; a
/// field's own edits never go back to that field.
final class ShellSearch implements SearchDriver {
  /// Creates the bridge. [claim] is the shell's native claim (null when it
  /// has none); [onChange] rebuilds the shell.
  ShellSearch({required this.claim, required this.onChange}) {
    editing.addListener(_onEditing);
    focus.addListener(_onFocus);
  }

  /// The shell's native claim, read when a command goes out.
  final NativeChromeClaim? Function() claim;

  /// Rebuilds the shell.
  final VoidCallback onChange;

  /// The Flutter field's text (fallback, spec §9.4). Lives as long as the
  /// shell, so the field is never rebuilt with a new controller.
  final TextEditingController editing = TextEditingController();

  /// The Flutter field's focus.
  final FocusNode focus = FocusNode(debugLabel: 'LiquidShell search');

  LiquidSearch? _config;
  LiquidSearchController? _controller;
  LiquidSearchController? _internal;
  bool _lastActive = false;
  bool _sentSelected = false;
  // Whether the last config showed the search tab natively.
  bool _sentShown = false;
  // The next native entry sends the text even when empty: native may
  // still show another one (a hot restart, a reconnected scene).
  bool _replay = true;
  // The controller's text came from the user's typing in the field (not
  // from the app): native has it, unless its scene was rebuilt.
  bool _userText = false;
  bool _native = false;
  bool _writing = false;
  bool _disposed = false;
  String? _pendingFieldText;

  /// Whether the native field shows the search (native chrome engaged).
  /// A build without it (pending, standby, Flutter chrome) makes the next
  /// native entry send the text again, empty included: native never got
  /// what the app set meanwhile, a cleared query too.
  bool get native => _native;
  set native(bool value) {
    if (!value) {
      _sentShown = false;
      _replay = true;
    }
    _native = value;
  }

  /// Whether the search tab is selected (set by the shell's build).
  bool selected = false;

  /// The native field's frame in the Flutter view; zero when not shown.
  Rect field = Rect.zero;

  /// The controller in use; null without a search destination.
  LiquidSearchController? get controller => _controller;

  /// The app's config.
  LiquidSearch? get config => _config;

  /// Follows the shell's `search` parameter. Without one but with a search
  /// destination (a release build that ignored the assert), an internal
  /// controller keeps the field working (spec §14).
  ///
  /// A new controller takes over the field: it gets the field's focus,
  /// and the field shows its text.
  void configure(LiquidSearch? config, {required bool hasSearchDestination}) {
    _config = config;
    final next =
        config?.controller ??
        (hasSearchDestination
            ? (_internal ??= LiquidSearchController())
            : null);
    if (identical(next, _controller)) return;
    final previous = _controller;
    if (previous != null) _release(previous);
    _controller = next;
    if (next == null) return;
    attachSearchDriver(next, this);
    if (previous != null) {
      // The field keeps its focus: the new controller hears it.
      if (next.isActive != previous.isActive) {
        applySearchEdit(next, next.value.copyWith(active: previous.isActive));
      }
      if (native && selected && next.text != previous.text) {
        claim()?.setSearchText(next.text);
      }
    }
    // A new controller's text is the app's.
    _userText = false;
    next.addListener(_onValue);
    _lastActive = next.isActive;
    _writeField(next.text);
  }

  /// A native state report. [reconnect]: the same state again, which only
  /// a rebuilt native controller sends (a live one reports changes only):
  /// its field lost the text, so the next config that shows the search tab
  /// sends it, empty or not. A changed state (an iPad crossing the size
  /// class) comes from a live field the user may be typing in: the user's
  /// own text is never sent back to it (the one-way rule, spec §7.4); only
  /// a text the app set is replayed.
  void replay({required bool reconnect}) {
    if (!reconnect && _userText) return;
    _sentShown = false;
    _replay = true;
  }

  /// Lets go of the controller while the shell is out of the tree (a new
  /// key, a GlobalKey move): another shell may take it meanwhile. The
  /// next [configure] takes it again.
  void detach() {
    final controller = _controller;
    if (controller == null) return;
    _release(controller);
    _controller = null;
  }

  void _release(LiquidSearchController controller) {
    controller.removeListener(_onValue);
    detachSearchDriver(controller, this);
  }

  void _onValue() {
    final active = _controller?.isActive ?? false;
    if (active == _lastActive) return;
    _lastActive = active;
    onChange();
  }

  // --- native → controller --------------------------------------------

  /// A native search event (routed by the shell).
  void onNativeEvent(LiquidNativeEvent event) {
    final controller = _controller;
    if (controller == null) return;
    switch (event) {
      case LiquidNativeSearchTextChanged(:final text, :final composing):
        if (!selected) return;
        final value = controller.value;
        if (value.text == text && value.composing == composing) return;
        applySearchEdit(
          controller,
          value.copyWith(text: text, composing: composing),
        );
        _userText = true;
        _config?.onChanged?.call(text);
      case LiquidNativeSearchActiveChanged(:final active):
        final next = active && selected;
        if (controller.isActive != next) {
          applySearchEdit(controller, controller.value.copyWith(active: next));
        }
      case LiquidNativeSearchSubmitted(:final text):
        if (selected) _config?.onSubmitted?.call(text);
      case LiquidNativeSearchFieldChanged(:final frame):
        if (frame != field) {
          field = frame;
          onChange();
        }
      default:
        break;
    }
  }

  /// After the shell's config went out: the search tab newly shown
  /// natively gets the kept query (Q2; spec §7.10: a cold start, a hot
  /// restart, a reconnected scene); leaving it ends the active state.
  void afterConfigSent() {
    final controller = _controller;
    final shown = selected && native;
    final entered = shown && !_sentShown;
    _sentShown = shown;
    final left = !selected && _sentSelected;
    _sentSelected = selected;
    if (controller == null) return;
    if (entered && (_replay || controller.text.isNotEmpty)) {
      _replay = false;
      claim()?.setSearchText(controller.text);
    }
    if (left && controller.isActive) {
      applySearchEdit(controller, controller.value.copyWith(active: false));
    }
  }

  // --- the controller's commands (SearchDriver) ------------------------

  @override
  void activate() {
    if (!selected) {
      if (kDebugMode) {
        debugPrint(
          'liquid_shell: LiquidSearchController.activate() ignored: the '
          'search tab is not selected.',
        );
      }
      return;
    }
    if (native) {
      FocusManager.instance.primaryFocus?.unfocus();
      claim()?.setSearchActive(active: true);
    } else {
      focus.requestFocus();
    }
  }

  @override
  void deactivate() {
    if (native) {
      claim()?.setSearchActive(active: false);
    } else {
      focus.unfocus();
    }
  }

  @override
  void textSetByApp(String text) {
    _userText = false;
    if (native) {
      claim()?.setSearchText(text);
    } else {
      _writeField(text);
    }
  }

  // --- the Flutter field (fallback) --------------------------------------

  /// The ×: clears (a user edit, so onChanged hears it) and unfocuses.
  void cancel() {
    final controller = _controller;
    if (controller != null && controller.text.isNotEmpty) {
      applySearchEdit(
        controller,
        controller.value.copyWith(text: '', composing: false),
      );
      _userText = true;
      _config?.onChanged?.call('');
    }
    _writeField('');
    focus.unfocus();
  }

  /// The shell will not show the Flutter field in this frame (hidden
  /// chrome, another tab, the other size class): let go of its focus, then
  /// end its composition and active state (spec P3b §8.2, §9.4). A focused
  /// field taken out of the tree never hears its focus loss (the focus
  /// manager drops a detached node silently), so this does not wait for
  /// the listener. The microtask runs after the focus manager's.
  void releaseField() {
    focus.unfocus();
    scheduleMicrotask(() {
      if (!_disposed) _onFocus();
    });
  }

  /// The keyboard's Search key in the Flutter field.
  void submit(String text) => _config?.onSubmitted?.call(text);

  /// Writes [text] into the Flutter field, never into a composition.
  void _writeField(String text) {
    if (!editing.value.composing.isCollapsed) {
      _pendingFieldText = text;
      return;
    }
    _pendingFieldText = null;
    if (editing.text == text) return;
    _writing = true;
    editing.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _writing = false;
  }

  void _onEditing() {
    if (_writing || native) return;
    final value = editing.value;
    final composing = !value.composing.isCollapsed;
    final pending = _pendingFieldText;
    final controller = _controller;
    if (!composing && pending != null) {
      _writeField(pending);
      // The app's write lands once the composition ends: the controller
      // holds it again and the composition is over (spec P3b §9.4).
      if (controller != null &&
          (controller.text != pending || controller.value.composing)) {
        applySearchEdit(
          controller,
          controller.value.copyWith(text: pending, composing: false),
        );
        _userText = false;
      }
      return;
    }
    if (controller == null) return;
    if (value.text == controller.text &&
        composing == controller.value.composing) {
      return;
    }
    applySearchEdit(
      controller,
      controller.value.copyWith(text: value.text, composing: composing),
    );
    _userText = true;
    _config?.onChanged?.call(value.text);
  }

  void _onFocus() {
    // A field that loses focus mid-composition (hidden, taken out of the
    // tree, another tab) ends the composition: EditableText only does
    // while it is mounted. Otherwise the stale range would reach the IME on
    // the next focus and a held app write would land on the user's next
    // edit (spec P3b §9.4). Deferred: this listener runs before
    // EditableText's, so a collapse now would flush the held write into
    // the still-open IME connection. A mounted field closes the connection
    // and collapses first, leaving the microtask nothing to do.
    if (!focus.hasFocus && !editing.value.composing.isCollapsed) {
      scheduleMicrotask(() {
        if (_disposed ||
            focus.hasFocus ||
            editing.value.composing.isCollapsed) {
          return;
        }
        editing.value = editing.value.copyWith(composing: TextRange.empty);
      });
    }
    if (native) return;
    final controller = _controller;
    if (controller == null) return;
    final active = focus.hasFocus && selected;
    if (controller.isActive != active) {
      applySearchEdit(controller, controller.value.copyWith(active: active));
    }
  }

  /// Releases the controller and the field's resources.
  void dispose() {
    _disposed = true;
    detach();
    _internal?.dispose();
    editing.dispose();
    focus.dispose();
  }
}
