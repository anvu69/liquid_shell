import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/cases/native_alerts.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/cases/segments.dart';
import 'package:liquid_shell_example/support/chrome_mode.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';
import 'package:liquid_shell_example/support/launch_demo.dart';
import 'package:liquid_shell_example/support/minimize_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The first frame is already liquid, so no screenshot catches the
  // frosted → liquid cross-fade.
  await LiquidGlass.precache();
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
class ExampleApp extends StatefulWidget {
  /// Creates the app. [demo] opens one case directly (UI tests): `search`
  /// and `search-guarded` open the search case; `search-above` and
  /// `search-above-liquid` push it above the case list, as a person opens
  /// it, natively and in the Flutter liquid tier (VK-551); `alert` and
  /// `sheet` open the alerts case and run that demo (spec P3a §9.4);
  /// `tabs` and `tabs-liquid` open the basic case, `segments` and
  /// `segments-liquid` the segments case (the frame strips; the Runner
  /// answers `segments-native` with its own UIKit screen, over the case
  /// list); `minimize` opens the basic tabs with a status-bar scroll to the
  /// top and an app-driven tab change (VK-600). Every `-liquid` demo starts
  /// in the Flutter liquid tier.
  const ExampleApp({this.demo, super.key});

  /// The demo to open at launch, or null for the case list. Any other
  /// value shows the case list too.
  final String? demo;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final ValueNotifier<ExampleChromeMode> _mode = ValueNotifier(
    ExampleChromeMode.native,
  );

  @override
  void initState() {
    super.initState();
    if (widget.demo?.endsWith('-liquid') ?? false) {
      _mode.value = ExampleChromeMode.flutterLiquid;
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.demo;
    final above = demo == 'search-above' || demo == 'search-above-liquid';
    final search = demo == 'search' || demo == 'search-guarded';
    // Framed as a case opened from the list, so its switch works (L4).
    final home = switch (demo) {
      'search' => const CaseFrame(child: SearchCase()),
      'search-guarded' => const CaseFrame(
        child: SearchCase(guardDetails: true),
      ),
      'alert' || 'sheet' => NativeAlertsCase(autorun: demo),
      'tabs' || 'tabs-liquid' => const CaseFrame(child: BasicTabsCase()),
      'segments' || 'segments-liquid' => const CaseFrame(child: SegmentsCase()),
      'minimize' => const CaseFrame(child: MinimizeDemo()),
      _ => const CaseList(),
    };
    // XCUITest reads the search case's and the minimize demo's Flutter
    // rows through the accessibility tree (the alerts are native).
    if (search || above || demo == 'minimize') {
      _demoSemantics ??= SemanticsBinding.instance.ensureSemantics();
    }
    return ChromeModeScope(
      notifier: _mode,
      child: MaterialApp(
        title: 'liquid_shell',
        theme: ThemeData(colorSchemeSeed: kExampleSeed),
        darkTheme: ThemeData(
          colorSchemeSeed: kExampleSeed,
          brightness: Brightness.dark,
        ),
        home: above ? null : home,
        // The case list, and the search case pushed above it.
        onGenerateInitialRoutes: above
            ? (_) => [
                MaterialPageRoute<void>(builder: (_) => home),
                MaterialPageRoute<void>(
                  builder: (_) => const CaseFrame(child: SearchCase()),
                ),
              ]
            : null,
        onGenerateRoute: above
            ? (_) => MaterialPageRoute<void>(builder: (_) => home)
            : null,
      ),
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
