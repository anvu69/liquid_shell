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
import 'package:liquid_shell_example/cases/sidebar_only.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';
import 'package:liquid_shell_example/cases/standalone_widgets.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';

/// One entry of the case list.
typedef ExampleCase = ({String id, String title, String subtitle, Widget page});

/// Every documented case, in README order.
const kCases = <ExampleCase>[
  (
    id: 'basic',
    title: 'Basic 3 tabs',
    subtitle: 'The smallest LiquidShell',
    page: BasicTabsCase(),
  ),
  (
    id: 'badges',
    title: 'Badges',
    subtitle: 'count(3), count(120) → 99+, dot()',
    page: BadgesCase(),
  ),
  (
    id: 'sidebar_only',
    title: 'Sidebar-only destinations',
    subtitle: 'Hidden on phones, with a fallback',
    page: SidebarOnlyCase(),
  ),
  (
    id: 'sidebar_slots',
    title: 'Sidebar header and footer',
    subtitle: 'App title and profile',
    page: SidebarSlotsCase(),
  ),
  (
    id: 'trailing',
    title: 'Trailing search action',
    subtitle: 'Opens a page above the shell',
    page: TrailingActionCase(),
  ),
  (
    id: 'guard',
    title: '"Discard changes?" guard',
    subtitle: 'beforeDestinationChange',
    page: DiscardGuardCase(),
  ),
  (
    id: 'hide_chrome',
    title: 'Hide the chrome',
    subtitle: 'LiquidHideChrome on a page inside the branch',
    page: HideChromeCase(),
  ),
  (
    id: 'custom_chrome',
    title: 'Custom chrome',
    subtitle: 'Wrap the bar, replace the sidebar',
    page: CustomChromeCase(),
  ),
  (
    id: 'custom_theme',
    title: 'Custom theme',
    subtitle: 'LiquidGlassTheme extension, light and dark',
    page: CustomThemeCase(),
  ),
  (
    id: 'forced_tier',
    title: 'Forced tier',
    subtitle: 'liquid / frosted / solid',
    page: ForcedTierCase(),
  ),
  (
    id: 'form_factors',
    title: 'Form factors',
    subtitle: 'iPhone, iPad portrait and landscape, Android',
    page: FormFactorsCase(),
  ),
  (
    id: 'narrow',
    title: 'Narrow width',
    subtitle: '5 tabs + trailing in a 320pt shell: 44pt cells at text scale 1',
    page: NarrowWidthCase(),
  ),
  (
    id: 'standalone',
    title: 'Standalone widgets',
    subtitle: 'LiquidTabBar and LiquidSidebar in your own Scaffold',
    page: StandaloneWidgetsCase(),
  ),
  (
    id: 'native_chrome',
    title: 'Native iPadOS chrome',
    subtitle: 'UITabBarController sidebar on iPad 26, Flutter elsewhere',
    page: NativeChromeCase(),
  ),
];
