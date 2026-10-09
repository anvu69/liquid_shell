// The README quickstart: a whole app. Run it with
// `flutter run -t lib/quickstart.dart`.
// #docregion quickstart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';

void main() => runApp(const MaterialApp(home: _Tabs()));

class _Tabs extends StatefulWidget {
  const _Tabs();
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: const [
      LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
      LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
    ],
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    body: Center(child: Text('Tab ${_index + 1}')),
  );
}

// #enddocregion quickstart
