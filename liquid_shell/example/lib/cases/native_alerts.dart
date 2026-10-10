import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// What the demo dialogs answer.
enum DemoChoice {
  /// Keep editing.
  keep,

  /// Discard the edits.
  discard,

  /// Save the edits.
  save,

  /// Delete the photo.
  delete,

  /// Share the photo.
  share,

  /// Duplicate the photo.
  duplicate,

  /// Close without a choice.
  cancel,
}

/// Native alerts and action sheets: the system's `UIAlertController` on
/// iOS 26 (above the native tab bar), the Flutter glass dialog elsewhere.
/// "Draw with Flutter liquid" draws the Flutter dialog everywhere, to
/// compare the two on one device.
class NativeAlertsCase extends StatefulWidget {
  /// Creates the case.
  const NativeAlertsCase({this.autorun, super.key});

  /// A demo to run once after the first frame (`alert` or `sheet`), whose
  /// answer is shown in a second alert, "Result: …". UI tests use it: they
  /// can read native alerts without Flutter's semantics.
  final String? autorun;

  @override
  State<NativeAlertsCase> createState() => _NativeAlertsCaseState();
}

class _NativeAlertsCaseState extends State<NativeAlertsCase> {
  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.chat_bubble_outline),
      label: 'Alerts',
      sfSymbol: 'exclamationmark.bubble',
    ),
    LiquidDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
      sfSymbol: 'gear',
    ),
  ];

  final GlobalKey _sheetButton = GlobalKey();
  int _index = 0;
  bool _flutter = false;
  String _result = 'Result: none';

  LiquidDialogPresentation get _presentation => _flutter
      ? LiquidDialogPresentation.flutter
      : LiquidDialogPresentation.auto;

  @override
  void initState() {
    super.initState();
    final demo = widget.autorun;
    if (demo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autorun(demo));
    }
  }

  Future<void> _autorun(String demo) async {
    final choice = demo == 'sheet'
        ? await _actionSheet(_sheetButton.currentContext!)
        : await _alert();
    if (!mounted) return;
    await showLiquidAlert<bool>(
      context,
      title: _label(choice),
      actions: const [LiquidAlertAction(label: 'OK', value: true)],
    );
  }

  String _label(DemoChoice? choice) => 'Result: ${choice?.name ?? 'none'}';

  Future<void> _show(Future<DemoChoice?> Function() dialog) async {
    final choice = await dialog();
    if (mounted) setState(() => _result = _label(choice));
  }

  // #docregion readme
  Future<DemoChoice?> _alert() => showLiquidAlert<DemoChoice>(
    context,
    title: 'Discard changes?',
    message: 'Your edits will be lost.',
    actions: const [
      LiquidAlertAction(
        label: 'Keep editing',
        value: DemoChoice.keep,
        style: LiquidAlertActionStyle.cancel,
      ),
      LiquidAlertAction(
        label: 'Discard',
        value: DemoChoice.discard,
        style: LiquidAlertActionStyle.destructive,
      ),
    ],
    presentation: _presentation,
  );

  // Pass the tapped button's context: on iPad the sheet points at it.
  Future<DemoChoice?> _actionSheet(BuildContext button) =>
      showLiquidActionSheet<DemoChoice>(
        button,
        title: 'Photo',
        actions: const [
          LiquidAlertAction(
            label: 'Delete photo',
            value: DemoChoice.delete,
            style: LiquidAlertActionStyle.destructive,
          ),
          LiquidAlertAction(label: 'Share', value: DemoChoice.share),
          LiquidAlertAction(
            label: 'Cancel',
            value: DemoChoice.cancel,
            style: LiquidAlertActionStyle.cancel,
          ),
        ],
        presentation: _presentation,
      );
  // #enddocregion readme

  Future<DemoChoice?> _threeActions() => showLiquidAlert<DemoChoice>(
    context,
    title: 'Save changes?',
    message: 'You can keep them for later.',
    actions: const [
      LiquidAlertAction(
        label: 'Save',
        value: DemoChoice.save,
        preferred: true,
      ),
      LiquidAlertAction(
        label: "Don't save",
        value: DemoChoice.discard,
        style: LiquidAlertActionStyle.destructive,
      ),
      LiquidAlertAction(
        label: 'Cancel',
        value: DemoChoice.cancel,
        style: LiquidAlertActionStyle.cancel,
      ),
    ],
    presentation: _presentation,
  );

  Future<DemoChoice?> _noCancelSheet(BuildContext button) =>
      showLiquidActionSheet<DemoChoice>(
        button,
        actions: const [
          LiquidAlertAction(label: 'Share', value: DemoChoice.share),
          LiquidAlertAction(label: 'Duplicate', value: DemoChoice.duplicate),
        ],
        presentation: _presentation,
      );

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: _destinations,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    body: DemoPage(
      title: _destinations[_index].label,
      children: [
        SwitchListTile(
          title: const Text('Draw with Flutter liquid'),
          subtitle: const Text('Off: the system draws it on iOS 26'),
          value: _flutter,
          onChanged: (value) => setState(() => _flutter = value),
        ),
        ListTile(title: const Text('Alert'), onTap: () => _show(_alert)),
        ListTile(
          title: const Text('Three actions'),
          onTap: () => _show(_threeActions),
        ),
        Builder(
          key: _sheetButton,
          builder: (button) => ListTile(
            title: const Text('Action sheet'),
            onTap: () => _show(() => _actionSheet(button)),
          ),
        ),
        Builder(
          builder: (button) => ListTile(
            title: const Text('Action sheet without cancel'),
            onTap: () => _show(() => _noCancelSheet(button)),
          ),
        ),
        ListTile(title: Text(_result)),
      ],
    ),
  );
}
