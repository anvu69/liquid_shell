import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/search_data.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

/// Search is a tab (VK-407). On iOS 26 with native chrome the field is
/// UIKit's: on iPhone the ⌕ beside the tab pill becomes the field and the
/// pill collapses to the previous tab; on iPad the field sits under the
/// title row and rises into it when active. Everywhere else the shell draws
/// the same states in glass. Results, recents and the scope bar are this
/// page's Flutter content; a result pushes a detail inside the tab, with
/// the glass back button. The query survives tab switches: the controller
/// lives here.
class SearchCase extends StatefulWidget {
  /// Creates the case.
  const SearchCase({super.key});

  @override
  State<SearchCase> createState() => _SearchCaseState();
}

class _SearchCaseState extends State<SearchCase> {
  // #docregion search
  int _index = 0;
  final _search = LiquidSearchController();
  final _recents = ValueNotifier<List<String>>(const []);
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
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music),
      label: 'Library',
      sfSymbol: 'books.vertical',
    ),
    LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
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
    search: LiquidSearch(
      controller: _search,
      placeholder: 'Songs, places',
      onSubmitted: _remember,
    ),
    body: IndexedStack(
      index: _index,
      children: [
        _branch(0, _ListPage(title: 'Home', items: _home)),
        _branch(1, _ListPage(title: 'Library', items: _library)),
        _branch(
          2,
          _SearchPage(
            controller: _search,
            recents: _recents,
            onRemember: _remember,
          ),
        ),
      ],
    ),
  );

  /// Each tab has its own navigator: a detail pushes inside the tab.
  Widget _branch(int index, Widget root) => Navigator(
    key: _navigators[index],
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
  );
  // #enddocregion search

  void _remember(String query) =>
      _recents.value = rememberQuery(_recents.value, query);

  @override
  void dispose() {
    _search.dispose();
    _recents.dispose();
    super.dispose();
  }
}

final List<SearchItem> _home = [for (final i in kSearchItems.take(6)) i];
final List<SearchItem> _library = [
  for (final i in kSearchItems)
    if (i.kind == SearchKind.song) i,
];

/// Pads a list clear of every chrome, the search field included.
EdgeInsets _padding(BuildContext context) =>
    LiquidShellScope.contentPaddingOf(context) +
    const EdgeInsets.symmetric(horizontal: 16);

/// A wallpaper page: the glass has something to show. The wallpaper sits
/// behind the page bar; the content gets its own [Material].
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: Wallpaper()),
      LiquidPage(
        title: title,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ],
  );
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.items});

  final String title;
  final List<SearchItem> items;

  @override
  Widget build(BuildContext context) => _Page(
    title: title,
    child: Builder(
      builder: (context) => ListView(
        padding: _padding(context),
        children: [for (final item in items) _ResultTile(item: item)],
      ),
    ),
  );
}

class _SearchPage extends StatelessWidget {
  const _SearchPage({
    required this.controller,
    required this.recents,
    required this.onRemember,
  });

  final LiquidSearchController controller;
  final ValueNotifier<List<String>> recents;
  final ValueChanged<String> onRemember;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Search',
    child: ListenableBuilder(
      listenable: Listenable.merge([controller, recents]),
      builder: (context, _) {
        final value = controller.value;
        final phase = LiquidShellScope.of(context).searchPhase;
        final padding = _padding(context);
        if (value.text.isEmpty && phase != LiquidSearchPhase.active) {
          return _CategoryGrid(padding: padding);
        }
        final results = value.text.trim().isEmpty
            ? null
            : searchResults(value.text, scope: value.scopeIndex);
        return ListView(
          padding: padding,
          children: [
            LiquidSearchScopeBar(
              controller: controller,
              scopes: kSearchScopes,
            ),
            const SizedBox(height: 16),
            if (results == null)
              ..._recents(context)
            else if (results.isEmpty)
              _Empty(query: value.text)
            else
              for (final item in results)
                _ResultTile(item: item, onOpen: () => onRemember(value.text)),
          ],
        );
      },
    ),
  );

  List<Widget> _recents(BuildContext context) => [
    Row(
      children: [
        Expanded(
          child: Text(
            'Recently searched',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(
          onPressed: recents.value.isEmpty
              ? null
              : () => recents.value = const [],
          child: const Text('Clear'),
        ),
      ],
    ),
    if (recents.value.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Your searches show here.'),
      )
    else
      for (final query in recents.value)
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(query),
          // Never write the field's text under an IME composition.
          onTap: () {
            if (!controller.value.composing) controller.text = query;
          },
        ),
  ];
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.padding});

  final EdgeInsets padding;

  static const _colors = [
    Color(0xFF7E57C2),
    Color(0xFFEF6C00),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF3949AB),
    Color(0xFF558B2F),
    Color(0xFF6D4C41),
    Color(0xFF0277BD),
  ];

  @override
  Widget build(BuildContext context) => GridView.extent(
    padding: padding,
    // Two columns on a phone, four on a tablet.
    maxCrossAxisExtent: 240,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.6,
    children: [
      for (final (i, category) in kSearchCategories.indexed)
        Material(
          color: _colors[i % _colors.length],
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _ListPage(
                  title: category,
                  items: [
                    for (final item in kSearchItems)
                      if (item.category == category) item,
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, this.onOpen});

  final SearchItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
    child: ListTile(
      leading: Icon(
        item.kind == SearchKind.song ? Icons.music_note : Icons.place_outlined,
      ),
      title: Text(item.title),
      subtitle: Text(
        '${item.kind == SearchKind.song ? 'Song' : 'Place'} · ${item.subtitle}',
      ),
      onTap: () {
        onOpen?.call();
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => _DetailPage(item: item)),
          ),
        );
      },
    ),
  );
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.item});

  final SearchItem item;

  @override
  Widget build(BuildContext context) => _Page(
    title: item.title,
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return ListView(
          padding: _padding(context),
          children: [
            const SizedBox(height: 24),
            Icon(
              item.kind == SearchKind.song ? Icons.album : Icons.landscape,
              size: 96,
            ),
            const SizedBox(height: 16),
            Text(item.title, style: theme.textTheme.headlineSmall),
            Text(item.subtitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(label: Text(item.category)),
            ),
          ],
        );
      },
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(
      children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 12),
        Text(
          'No results for "$query"',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('Check the spelling, or try another scope.'),
      ],
    ),
  );
}
