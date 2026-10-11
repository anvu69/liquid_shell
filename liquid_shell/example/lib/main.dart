import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';
import 'package:liquid_shell_example/support/launch_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ExampleApp(demo: await launchDemo()));
}

/// Kept for the app's life: XCUITest reads Flutter's rows through it.
SemanticsHandle? _demoSemantics;

/// Releases the demo's semantics handle; widget tests must end without one.
@visibleForTesting
void debugReleaseDemoSemantics() {
  _demoSemantics?.dispose();
  _demoSemantics = null;
}

/// The seed colour of the example theme.
const kExampleSeed = Color(0xFF3D5AFE);

/// The example app: a list of cases, each opening one screen.
class ExampleApp extends StatelessWidget {
  /// Creates the app. [demo] opens one case directly (UI tests): `search`,
  /// `search-guarded`.
  const ExampleApp({this.demo, super.key});

  /// The case to open at launch, or null for the case list.
  final String? demo;

  @override
  Widget build(BuildContext context) {
    final home = switch (demo) {
      'search' => const SearchCase(),
      'search-guarded' => const SearchCase(guardDetails: true),
      _ => const CaseList(),
    };
    // XCUITest reads Flutter's rows through the accessibility tree.
    if (demo != null) {
      _demoSemantics ??= SemanticsBinding.instance.ensureSemantics();
    }
    return MaterialApp(
      title: 'liquid_shell',
      theme: ThemeData(colorSchemeSeed: kExampleSeed),
      darkTheme: ThemeData(
        colorSchemeSeed: kExampleSeed,
        brightness: Brightness.dark,
      ),
      home: home,
    );
  }
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
