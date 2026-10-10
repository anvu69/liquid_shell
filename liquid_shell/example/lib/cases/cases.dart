import 'package:flutter/widgets.dart';
import 'package:liquid_shell_example/cases/badges.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_chrome.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/discard_guard.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/form_factors.dart';
import 'package:liquid_shell_example/cases/hide_chrome.dart';
import 'package:liquid_shell_example/cases/narrow_width.dart';
import 'package:liquid_shell_example/cases/native_chrome.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/cases/sidebar_only.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';
import 'package:liquid_shell_example/cases/standalone_widgets.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';

/// One entry of the case list. `drawnByFlutter` says in one line why the
/// case keeps the Flutter chrome where native chrome is available (iOS 26);
/// null for a case that runs native there (owner E1).
typedef ExampleCase = ({
  String id,
  String title,
  String subtitle,
  String? drawnByFlutter,
  Widget page,
});

/// Every documented case, in README order.
const kCases = <ExampleCase>[
  (
    id: 'basic',
    title: 'Basic 3 tabs',
    subtitle: 'The smallest LiquidShell',
    drawnByFlutter: null,
    page: BasicTabsCase(),
  ),
  (
    id: 'badges',
    title: 'Badges',
    subtitle: 'count(3), count(120) → 99+, dot()',
    drawnByFlutter: null,
    page: BadgesCase(),
  ),
  (
    id: 'sidebar_only',
    title: 'Sidebar-only destinations',
    subtitle: 'Hidden on phones, with a fallback',
    drawnByFlutter: null,
    page: SidebarOnlyCase(),
  ),
  (
    id: 'sidebar_slots',
    title: 'Sidebar header and footer',
    subtitle: 'App title and profile; natively, the profile only',
    drawnByFlutter: null,
    page: SidebarSlotsCase(),
  ),
  (
    id: 'trailing',
    title: 'Trailing action',
    subtitle: 'Compose: opens a page above the shell',
    drawnByFlutter: null,
    page: TrailingActionCase(),
  ),
  (
    id: 'search',
    title: 'Search tab',
    subtitle: 'A real search tab: field, scopes, recents, live results',
    drawnByFlutter: null,
    page: SearchCase(),
  ),
  (
    id: 'guard',
    title: '"Discard changes?" guard',
    subtitle: 'beforeDestinationChange',
    drawnByFlutter: null,
    page: DiscardGuardCase(),
  ),
  (
    id: 'hide_chrome',
    title: 'Hide the chrome',
    subtitle: 'LiquidHideChrome on a page inside the branch',
    drawnByFlutter: null,
    page: HideChromeCase(),
  ),
  (
    id: 'custom_chrome',
    title: 'Custom chrome',
    subtitle: 'Wrap the bar, replace the sidebar',
    drawnByFlutter:
        'A chromeBuilder draws it; native chrome cannot host widgets.',
    page: CustomChromeCase(),
  ),
  (
    id: 'custom_theme',
    title: 'Custom theme',
    subtitle: 'LiquidGlassTheme extension, light and dark',
    drawnByFlutter:
        'LiquidGlassTheme styles the Flutter glass; native follows iOS.',
    page: CustomThemeCase(),
  ),
  (
    id: 'forced_tier',
    title: 'Forced tier',
    subtitle: 'liquid / frosted / solid',
    drawnByFlutter:
        'Glass tiers are how Flutter draws glass; native chrome has none.',
    page: ForcedTierCase(),
  ),
  (
    id: 'form_factors',
    title: 'Form factors',
    subtitle: 'iPhone, iPad portrait and landscape, Android',
    drawnByFlutter:
        'Four shells in scaled frames; a window has one native chrome.',
    page: FormFactorsCase(),
  ),
  (
    id: 'narrow',
    title: 'Narrow width',
    subtitle: '5 tabs + trailing in a 320pt shell: 44pt cells at text scale 1',
    drawnByFlutter:
        'A 320pt shell in a wider window; native chrome spans the window.',
    page: NarrowWidthCase(),
  ),
  (
    id: 'standalone',
    title: 'Standalone widgets',
    subtitle: 'LiquidTabBar and LiquidSidebar in your own Scaffold',
    drawnByFlutter: 'LiquidTabBar and LiquidSidebar are Flutter widgets.',
    page: StandaloneWidgetsCase(),
  ),
  (
    id: 'native_chrome',
    title: 'Native chrome',
    subtitle: 'Native footer, sidebar-only tab and guard on iOS 26',
    drawnByFlutter: null,
    page: NativeChromeCase(),
  ),
];
