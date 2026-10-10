import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/support/chrome_mode.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The first frame is already liquid, so no screenshot catches the
  // frosted → liquid cross-fade.
  await LiquidGlass.precache();
  runApp(const ExampleApp());
}

/// The seed colour of the example theme.
const kExampleSeed = Color(0xFF3D5AFE);

/// The example app: a list of cases, each opening one screen.
class ExampleApp extends StatefulWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final ValueNotifier<ExampleChromeMode> _mode = ValueNotifier(
    ExampleChromeMode.native,
  );

  @override
  void dispose() {
    _mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChromeModeScope(
    notifier: _mode,
    child: MaterialApp(
      title: 'liquid_shell',
      theme: ThemeData(colorSchemeSeed: kExampleSeed),
      darkTheme: ThemeData(
        colorSchemeSeed: kExampleSeed,
        brightness: Brightness.dark,
      ),
      home: const CaseList(),
    ),
  );
}

/// The home screen: one row per case.
class CaseList extends StatelessWidget {
  /// Creates the list.
  const CaseList({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('liquid_shell')),
    body: ListView(
      children: [
        for (final entry in kCases)
          ListTile(
            key: ValueKey('case-${entry.id}'),
            title: Text(entry.title),
            subtitle: Text(entry.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CaseFrame(
                  child: DrawnByFlutter(
                    reason: entry.drawnByFlutter,
                    child: entry.page,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
