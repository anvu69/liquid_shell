import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import '../helpers/shell_harness.dart';

const _home = LiquidDestination(icon: Icon(Icons.home), label: 'Home');
const _search = LiquidDestination(
  icon: Icon(Icons.search),
  label: 'Search',
  role: LiquidDestinationRole.search,
);

Future<Object?> _errorOf(
  WidgetTester tester,
  List<LiquidDestination> destinations, {
  bool withSearch = true,
  LiquidTabAction? trailing,
}) async {
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  await pumpShell(
    tester,
    LiquidShell(
      destinations: destinations,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      tabBarTrailing: trailing,
      search: withSearch ? LiquidSearch(controller: controller) : null,
      body: const SizedBox(),
    ),
    settle: false,
  );
  return tester.takeException();
}

void main() {
  testWidgets('one search destination, last, with LiquidShell.search: fine', (
    tester,
  ) async {
    expect(await _errorOf(tester, const [_home, _search]), isNull);
  });

  testWidgets('two search destinations assert', (tester) async {
    final error = await _errorOf(tester, const [
      _home,
      LiquidDestination(
        icon: Icon(Icons.search),
        label: 'Find',
        role: LiquidDestinationRole.search,
      ),
      _search,
    ]);
    expect('$error', contains('one search destination'));
  });

  testWidgets('a search destination that is not last asserts', (tester) async {
    final error = await _errorOf(tester, const [_search, _home]);
    expect('$error', contains('must be the last'));
  });

  testWidgets('a sidebar-only search destination asserts', (tester) async {
    final error = await _errorOf(tester, const [
      _home,
      LiquidDestination(
        icon: Icon(Icons.search),
        label: 'Search',
        role: LiquidDestinationRole.search,
        placement: LiquidPlacement.sidebarOnly,
      ),
    ]);
    expect('$error', contains('placed everywhere'));
  });

  testWidgets('a search destination without LiquidShell.search asserts', (
    tester,
  ) async {
    final error = await _errorOf(
      tester,
      const [_home, _search],
      withSearch: false,
    );
    expect('$error', contains('needs LiquidShell.search'));
  });

  testWidgets('LiquidShell.search without a search destination asserts', (
    tester,
  ) async {
    final error = await _errorOf(tester, const [_home]);
    expect('$error', contains('LiquidDestinationRole.search'));
  });

  testWidgets('a search destination with tabBarTrailing asserts', (
    tester,
  ) async {
    final error = await _errorOf(
      tester,
      const [_home, _search],
      trailing: LiquidTabAction(
        icon: const Icon(Icons.edit),
        semanticLabel: 'Compose',
        onPressed: () {},
      ),
    );
    expect('$error', contains('no tabBarTrailing'));
  });
}
