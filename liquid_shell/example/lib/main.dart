import 'package:flutter/material.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/cases/native_alerts.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';
import 'package:liquid_shell_example/support/launch_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ExampleApp(demo: await launchDemo()));
}

/// The seed colour of the example theme.
const kExampleSeed = Color(0xFF3D5AFE);

/// The example app: a list of cases, each opening one screen.
class ExampleApp extends StatelessWidget {
  /// Creates the app. With [demo], it opens straight on the alerts case and
  /// runs that demo (UI tests, spec P3a §9.4).
  const ExampleApp({this.demo, super.key});

  /// `alert` or `sheet`; null shows the case list.
  final String? demo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'liquid_shell',
    theme: ThemeData(colorSchemeSeed: kExampleSeed),
    darkTheme: ThemeData(
      colorSchemeSeed: kExampleSeed,
      brightness: Brightness.dark,
    ),
    home: demo == null ? const CaseList() : NativeAlertsCase(autorun: demo),
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
                builder: (_) => DrawnByFlutter(
                  reason: entry.drawnByFlutter,
                  child: entry.page,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
