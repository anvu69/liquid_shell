import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/chrome_mode.dart';
import 'package:liquid_shell_example/support/demo_page.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

/// Pages on every tab. Each tab has its own navigator and its pages are
/// `LiquidPage`s: with native chrome on iOS 26 each gets UIKit's
/// navigation bar (the title, the glass back circle, the large title);
/// elsewhere the same pages draw the Flutter glass bar.
///
/// Home has the default title and pushes details; one of them is full
/// frame under `LiquidHideChrome`, which hides the tab bar and keeps the
/// page's own bar. Library has a large title that collapses as the page
/// scrolls. Settings has a root without `LiquidPage`: the pages it pushes
/// get a back circle to it all the same, and Profile has a text field.
///
/// Page actions: Home's root has Add, which opens a detail; each detail
/// has Share (counts), Favourite (its symbol toggles) and Delete
/// (disabled). Natively they are UIKit bar buttons; elsewhere glass
/// circles in the Flutter bar.
class PagesCase extends StatefulWidget {
  /// Creates the case.
  const PagesCase({super.key});

  @override
  State<PagesCase> createState() => _PagesCaseState();
}

class _PagesCaseState extends State<PagesCase> {
  int _index = 0;
  final List<GlobalKey<NavigatorState>> _navigators = [
    for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
  ];

  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    ),
    LiquidDestination(
      icon: Icon(Icons.library_books_outlined),
      selectedIcon: Icon(Icons.library_books),
      label: 'Library',
      sfSymbol: 'books.vertical',
    ),
    LiquidDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
      sfSymbol: 'gear',
    ),
  ];

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: _destinations,
    selectedIndex: _index,
    onDestinationSelected: (i) {
      // Reselecting a tab pops it to its root.
      if (i == _index) _navigators[i].currentState?.popUntil((r) => r.isFirst);
      setState(() => _index = i);
    },
    body: IndexedStack(
      index: _index,
      children: [
        _branch(0, const _HomePage()),
        _branch(1, const _LibraryPage()),
        _branch(2, const _SettingsPage()),
      ],
    ),
  );

  /// Each tab has its own navigator: a page pushes inside the tab.
  Widget _branch(int index, Widget root) => Navigator(
    key: _navigators[index],
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
  );
}

/// Pushes [page] in the navigator of [context]'s tab.
Future<void> _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// A `LiquidPage` over the wallpaper, so the bar's glass has something to
/// show; its list is padded clear of every chrome.
class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.children,
    this.largeTitle,
    this.actions = const [],
  });

  final String title;
  final bool? largeTitle;
  final List<LiquidPageAction> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: Wallpaper()),
      LiquidPage(
        title: title,
        largeTitle: largeTitle,
        actions: actions,
        child: Material(
          type: MaterialType.transparency,
          child: Builder(
            builder: (context) => ListView(
              padding:
                  LiquidShellScope.contentPaddingOf(context) +
                  const EdgeInsets.symmetric(horizontal: 16),
              children: children,
            ),
          ),
        ),
      ),
    ],
  );
}

/// One row of a page; [onTap] opens something.
class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
    child: ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

/// The chrome mode switch, as every case shows it (L4).
List<Widget> _modeSwitch(BuildContext context) {
  final mode = ChromeModeScope.maybeOf(context);
  if (mode == null) return const [];
  return [
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: ChromeModeSwitch(mode: mode),
    ),
    const SizedBox(height: 12),
  ];
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Home',
    actions: [
      LiquidPageAction(
        sfSymbol: 'plus',
        icon: const Icon(Icons.add),
        label: 'Add',
        onPressed: () => _push(context, const _DetailPage(number: 1)),
      ),
    ],
    children: [
      ..._modeSwitch(context),
      for (var i = 1; i <= 3; i++)
        _Row(
          title: 'Detail $i',
          onTap: () => _push(context, _DetailPage(number: i)),
        ),
      _Row(
        title: 'Photo',
        subtitle: 'Full frame: the tab bar hides, the page keeps its bar',
        onTap: () =>
            _push(context, const LiquidHideChrome(child: _PhotoPage())),
      ),
      for (var i = 1; i <= 24; i++) _Row(title: 'Home item $i'),
    ],
  );
}

/// A detail with three actions: Share counts its taps, Favourite toggles
/// its symbol, and Delete is disabled (`onPressed: null`).
class _DetailPage extends StatefulWidget {
  const _DetailPage({required this.number});

  final int number;

  @override
  State<_DetailPage> createState() => _DetailPageState();
}

// #docregion pages
class _DetailPageState extends State<_DetailPage> {
  bool _favourite = false;
  int _shares = 0;

  @override
  Widget build(BuildContext context) {
    final number = widget.number;
    return _Page(
      title: 'Detail $number',
      actions: [
        LiquidPageAction(
          sfSymbol: 'square.and.arrow.up',
          icon: const Icon(Icons.ios_share),
          label: 'Share',
          onPressed: () => setState(() => _shares++),
        ),
        LiquidPageAction(
          sfSymbol: _favourite ? 'heart.fill' : 'heart',
          icon: Icon(_favourite ? Icons.favorite : Icons.favorite_border),
          label: 'Favourite',
          onPressed: () => setState(() => _favourite = !_favourite),
        ),
        const LiquidPageAction(
          sfSymbol: 'trash',
          icon: Icon(Icons.delete_outline),
          label: 'Delete',
          onPressed: null,
        ),
      ],
      children: [
        _Row(
          title: 'Detail ${number + 1}',
          subtitle: 'One page deeper',
          onTap: () => _push(context, _DetailPage(number: number + 1)),
        ),
        _Row(
          title: 'Shared $_shares ${_shares == 1 ? 'time' : 'times'}',
          subtitle: _favourite ? 'A favourite' : 'Not a favourite',
        ),
        for (var i = 1; i <= 30; i++) _Row(title: 'Detail $number item $i'),
      ],
    );
  }
}
// #enddocregion pages

class _PhotoPage extends StatelessWidget {
  const _PhotoPage();

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Photo',
    children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.tertiary,
              ],
            ),
          ),
        ),
      ),
      for (var i = 1; i <= 12; i++) _Row(title: 'Photo item $i'),
    ],
  );
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage();

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Library',
    largeTitle: true,
    children: [
      ..._modeSwitch(context),
      for (var i = 1; i <= 30; i++) _Row(title: 'Library item $i'),
    ],
  );
}

/// The root without `LiquidPage`: its own title row, as before.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) => DemoPage(
    title: 'Settings',
    children: [
      _Row(title: 'About', onTap: () => _push(context, const _AboutPage())),
      _Row(
        title: 'Profile',
        subtitle: 'A text field: type with any keyboard',
        onTap: () => _push(context, const _ProfilePage()),
      ),
    ],
  );
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => _Page(
    title: 'About',
    children: [
      for (var i = 1; i <= 20; i++) _Row(title: 'About item $i'),
    ],
  );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) => const _Page(
    title: 'Profile',
    children: [
      TextField(
        decoration: InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
}
