import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/branding.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/theme_preference.dart';
import '../settings/app_changelog.dart';
import '../settings/how_to_use.dart';
import '../shared/widgets.dart';
import 'command_dock.dart';
import 'operations_apps_rail.dart';

/// Width below which phone layout uses NavigationBar (no drawer) instead of rail.
const double kCompactShellBreakpoint = 700;

/// Phone action strip height (padding 6×2 + 48px buttons) — kept in AppBar.bottom
/// so list content cannot paint underneath.
const double kCompactActionStripHeight = 60;

/// When true, the left nav rail shrinks to icons-only (~64px).
final railCollapsedProvider = StateProvider<bool>((ref) => false);

class NavDestinationInfo {
  const NavDestinationInfo({
    required this.path,
    required this.label,
    required this.sectionTitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final String sectionTitle;
  final IconData icon;
  final IconData selectedIcon;
}

const List<NavDestinationInfo> _destinations = [
  NavDestinationInfo(
    path: '/',
    label: 'Dashboard',
    sectionTitle: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
  ),
  NavDestinationInfo(
    path: '/staging',
    label: 'Active Staging Entries Log',
    sectionTitle: 'Active Staging Entries Log',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  NavDestinationInfo(
    path: '/shipped',
    label: 'Shipped Staging Entries Log',
    sectionTitle: 'Shipped Staging Entries Log',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
  NavDestinationInfo(
    path: '/reports',
    label: 'Reports & Analytics',
    sectionTitle: 'Reports & Analytics',
    icon: Icons.insert_chart_outlined_rounded,
    selectedIcon: Icons.insert_chart,
  ),
  NavDestinationInfo(
    path: '/notifications',
    label: 'Notifications',
    sectionTitle: 'Notifications',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
  ),
  NavDestinationInfo(
    path: '/contacts',
    label: 'Contacts',
    sectionTitle: 'Contacts',
    icon: Icons.contacts_outlined,
    selectedIcon: Icons.contacts,
  ),
  NavDestinationInfo(
    path: '/settings',
    label: 'Settings',
    sectionTitle: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

/// Primary destinations shown on the compact bottom NavigationBar.
const List<String> _compactBarPaths = [
  '/',
  '/staging',
  '/shipped',
  '/reports',
  '/settings',
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String _normalizePath(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;
    if (path.isEmpty) return '/';
    return path;
  }

  NavDestinationInfo _destinationFor(String path) {
    final match = _destinations.where((d) => d.path == path);
    if (match.isNotEmpty) return match.first;
    return _destinations.first;
  }

  @override
  void initState() {
    super.initState();
    // CallbackShortcuts only fire when the shell Focus has primary focus.
    // Text fields / dialogs steal focus on Windows and let OS Help take F1.
    // A global handler keeps F1–F5 mapped to the dock while the app is focused.
    HardwareKeyboard.instance.addHandler(_handleDockHotkey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showLaunchPrompts());
    });
  }

  Future<void> _showLaunchPrompts() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    try {
      await maybeShowHowToUsePrompt(context);
      if (!mounted) return;
      await maybeShowChangelogPrompt(context);
    } catch (_) {
      // Prompts are optional — never block the shell.
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleDockHotkey);
    super.dispose();
  }

  bool _handleDockHotkey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    final location = GoRouterState.of(context).uri.toString();
    final actions = ShellCommandDock.actionsFor(context, ref, location);
    for (final action in actions) {
      final key = ShellCommandDock.logicalKeyFor(action.key);
      final onPressed = action.onPressed;
      if (key == null || onPressed == null) continue;
      if (event.logicalKey == key) {
        onPressed();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final path = _normalizePath(location);
    final current = _destinationFor(path);
    final dockActions = ShellCommandDock.actionsFor(context, ref, location);
    final compact = MediaQuery.sizeOf(context).width < kCompactShellBreakpoint;

    return CallbackShortcuts(
      bindings: ShellCommandDock.shortcutBindings(dockActions),
      child: Focus(
        autofocus: true,
        child: compact
            ? _CompactShell(
                selectedPath: current.path,
                location: location,
                title: current.sectionTitle,
                child: widget.child,
              )
            : Scaffold(
                backgroundColor: IndustrialTheme.chromeOf(context).base,
                // Tablet/desktop shell draws under Android edge-to-edge
                // system bars unless inset — otherwise status + nav overlap
                // the header and command dock (seen on Galaxy Tab).
                // Pin the command dock via bottomNavigationBar so Scaffold
                // always reserves its height — short Windows work areas (~852px)
                // must never let page content push the dock off-screen.
                body: SafeArea(
                  bottom: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IndustrialRail(selectedPath: current.path),
                      Expanded(
                        child: Column(
                          children: [
                            _TopHeader(
                              title: current.sectionTitle,
                            ),
                            Expanded(child: widget.child),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: ShellCommandDock(location: location),
                ),
              ),
      ),
    );
  }
}

class _CompactShell extends ConsumerWidget {
  const _CompactShell({
    required this.selectedPath,
    required this.location,
    required this.title,
    required this.child,
  });

  final String selectedPath;
  final String location;
  final String title;
  final Widget child;

  int _barIndexFor(String path) {
    final i = _compactBarPaths.indexOf(path);
    if (i >= 0) return i;
    // Secondary routes (notifications / contacts) highlight More.
    return _compactBarPaths.indexOf('/settings');
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: IndustrialTheme.chromeOf(context).header,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'More',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.notifications_outlined,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
                title: Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go('/notifications');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.contacts_outlined,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
                title: Text(
                  'Contacts',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go('/contacts');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
                title: Text(
                  'Settings',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go('/settings');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barIndex = _barIndexFor(selectedPath);
    final barDestinations = [
      for (final p in _compactBarPaths)
        _destinations.firstWhere((d) => d.path == p),
    ];
    final data = ref.watch(appDataProvider);
    final loading = data.loading;
    final syncing = data.syncing;
    final hasError = data.error != null && !(loading || syncing);
    final liveAccent =
        hasError ? IndustrialTheme.amber : IndustrialTheme.mintGreen;
    final liveLabel = (loading || syncing)
        ? 'Syncing…'
        : hasError
            ? 'Error'
            : 'Live';
    final dockActions = ShellCommandDock.actionsFor(context, ref, location);
    // Primary floor actions only — skip pure navigation chips already in the bar.
    final compactActions = dockActions
        .where(
          (a) =>
              a.label != 'Settings' &&
              a.label != 'Staging Log' &&
              a.label != 'Shipped Log' &&
              a.label != 'Reports' &&
              a.label != 'Notifications' &&
              a.label != 'Contacts',
        )
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: IndustrialTheme.chromeOf(context).base,
      // Bottom nav covers primary destinations; More sheet covers the rest —
      // no redundant hamburger/drawer on compact Android phones.
      appBar: AppBar(
        backgroundColor: IndustrialTheme.chromeOf(context).header,
        foregroundColor: IndustrialTheme.chromeOf(context).ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: IndustrialTheme.chromeOf(context).ink,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Tooltip(
                message: hasError ? data.error! : 'Realtime inventory sync',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: liveAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: liveAccent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: SizedBox(
                    width: 56,
                    child: Text(
                      liveLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: liveAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.notifications_outlined, size: 20),
          ),
          const _ThemeToggleButton(),
          const SizedBox(width: 4),
        ],
        // Pin floor actions in the app bar so Scaffold reserves height and the
        // opaque header background covers gaps — body list cannot paint under.
        bottom: compactActions.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(kCompactActionStripHeight),
                child: _CompactActionStrip(actions: compactActions),
              ),
      ),
      body: SafeArea(
        // AppBar already owns the top inset + action strip; keep bottom free
        // for NavigationBar's own SafeArea. Side insets cover landscape bars.
        top: false,
        bottom: false,
        child: ClipRect(child: child),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          backgroundColor: IndustrialTheme.chromeOf(context).header,
          indicatorColor: IndustrialTheme.chromeAccent.withValues(alpha: 0.22),
          selectedIndex: barIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            final dest = barDestinations[i];
            if (dest.path == '/settings') {
              _openMoreSheet(context);
              return;
            }
            context.go(dest.path);
          },
          destinations: [
            for (final d in barDestinations)
              NavigationDestination(
                icon: Icon(
                  d.path == '/settings' ? Icons.more_horiz : d.icon,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
                selectedIcon: Icon(
                  d.path == '/settings' ? Icons.more_horiz : d.selectedIcon,
                  color: IndustrialTheme.chromeAccent,
                ),
                label: _compactNavLabel(d.path),
              ),
          ],
        ),
      ),
    );
  }

  static String _compactNavLabel(String path) {
    switch (path) {
      case '/':
        return 'Home';
      case '/staging':
        return 'Staging';
      case '/shipped':
        return 'Shipped';
      case '/reports':
        return 'Reports';
      case '/settings':
        return 'More';
      default:
        return 'App';
    }
  }
}

/// Phone/tablet parity with the Windows command dock — primary actions only.
class _CompactActionStrip extends StatelessWidget {
  const _CompactActionStrip({required this.actions});

  final List<DockAction> actions;

  @override
  Widget build(BuildContext context) {
    // Explicit opaque fill: gaps between tonal buttons must never show list
    // content scrolling underneath (seen on Android portrait when the strip
    // lived in the body Column without a clipped viewport).
    return ColoredBox(
      color: IndustrialTheme.chromeOf(context).header,
      child: SizedBox(
        height: kCompactActionStripHeight,
        width: double.infinity,
        child: Material(
          color: IndustrialTheme.chromeOf(context).header,
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: IndustrialTheme.chromeOf(context).border),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: actions[i].onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: IndustrialTheme.chromeOf(context).surface,
                        foregroundColor: actions[i].onPressed == null
                            ? IndustrialTheme.chromeOf(context).muted
                            : IndustrialTheme.chromeOf(context).ink,
                        disabledForegroundColor: IndustrialTheme.chromeOf(context).muted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: IndustrialTheme.chromeOf(context).border,
                          ),
                        ),
                      ),
                      child: Text(
                        actions[i].label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      onPressed: () => ref.read(darkModeProvider.notifier).toggle(),
      icon: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 20,
        color: IndustrialTheme.chromeOf(context).muted,
      ),
    );
  }
}

class _IndustrialRail extends ConsumerWidget {
  const _IndustrialRail({required this.selectedPath});
  final String selectedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(railCollapsedProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: collapsed ? 64 : 220,
      decoration: BoxDecoration(
        color: IndustrialTheme.chromeOf(context).base,
        border: Border(
          right: BorderSide(color: IndustrialTheme.chromeOf(context).border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 8 : 16,
              16,
              collapsed ? 8 : 16,
              14,
            ),
            child: Center(
              child: Tooltip(
                message: kProductName,
                child: collapsed
                    ? const BrandMark(size: 32)
                    : const SwiftChromeLogo(height: 56),
              ),
            ),
          ),
          Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 6 : 8,
                vertical: 12,
              ),
              children: [
                for (final d in _destinations)
                  _RailNavTile(
                    item: d,
                    selected: d.path == selectedPath,
                    collapsed: collapsed,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
          if (!collapsed) const OperationsAppsRail(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Tooltip(
              message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              child: IconButton(
                onPressed: () {
                  ref.read(railCollapsedProvider.notifier).state = !collapsed;
                },
                icon: Icon(
                  collapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailNavTile extends StatelessWidget {
  const _RailNavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
  });

  final NavDestinationInfo item;
  final bool selected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? IndustrialTheme.chromeOf(context).ink
        : IndustrialTheme.chromeOf(context).muted;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? IndustrialTheme.chromeAccent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(item.path),
          child: SizedBox(
            height: 42,
            child: collapsed
                ? Center(
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 20,
                      color: selected ? IndustrialTheme.chromeAccent : fg,
                    ),
                  )
                : Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 3,
                        height: selected ? 18 : 0,
                        margin: const EdgeInsets.only(left: 4, right: 8),
                        decoration: BoxDecoration(
                          color: IndustrialTheme.chromeAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 18,
                        color: selected ? IndustrialTheme.chromeAccent : fg,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: fg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!collapsed) return tile;
    return Tooltip(message: item.label, child: tile);
  }
}

class _TopHeader extends ConsumerWidget {
  const _TopHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final syncing = data.syncing || data.loading;
    final hasError = data.error != null && !syncing;
    final accent = hasError
        ? IndustrialTheme.amber
        : IndustrialTheme.mintGreen;
    final label = syncing
        ? 'Syncing…'
        : hasError
            ? 'Sync error'
            : 'Live sync';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: IndustrialTheme.chromeOf(context).header,
        border: Border(
          bottom: BorderSide(color: IndustrialTheme.chromeOf(context).border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: IndustrialTheme.chromeOf(context).ink,
              ),
            ),
          ),
          Tooltip(
            message: hasError ? data.error! : 'Realtime inventory sync',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 72,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: IndustrialTheme.chromeOf(context).muted,
            ),
          ),
          const _ThemeToggleButton(),
        ],
      ),
    );
  }
}
