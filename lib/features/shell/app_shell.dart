import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/widgets.dart';
import 'command_dock.dart';

/// Width below which phone layout uses NavigationBar + Drawer instead of rail.
const double kCompactShellBreakpoint = 700;

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

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

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

  Future<void> _requestAccess() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.accessRequestEmail,
      queryParameters: {
        'subject': 'Access Request: SLST',
      },
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onRequestAccess: _requestAccess,
                child: child,
              )
            : Scaffold(
                backgroundColor: IndustrialTheme.darkBase,
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
                              onRequestAccess: _requestAccess,
                            ),
                            Expanded(child: child),
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
    required this.onRequestAccess,
    required this.child,
  });

  final String selectedPath;
  final String location;
  final String title;
  final Future<void> Function() onRequestAccess;
  final Widget child;

  int _barIndexFor(String path) {
    final i = _compactBarPaths.indexOf(path);
    if (i >= 0) return i;
    // Secondary routes (notifications / contacts) highlight Settings.
    return _compactBarPaths.indexOf('/settings');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barIndex = _barIndexFor(selectedPath);
    final barDestinations = [
      for (final p in _compactBarPaths)
        _destinations.firstWhere((d) => d.path == p),
    ];
    final loading = ref.watch(appDataProvider).loading;
    final syncing = ref.watch(appDataProvider).syncing;
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
      backgroundColor: IndustrialTheme.darkBase,
      appBar: AppBar(
        backgroundColor: IndustrialTheme.darkHeader,
        foregroundColor: IndustrialTheme.textPrimary,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: IndustrialTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IndustrialTheme.mintGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: IndustrialTheme.mintGreen.withValues(alpha: 0.45),
                  ),
                ),
                child: SizedBox(
                  width: 56,
                  child: Text(
                    (loading || syncing) ? 'Syncing…' : 'Live',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: IndustrialTheme.mintGreen,
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
          _AccountMenu(onRequestAccess: onRequestAccess),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: IndustrialTheme.darkHeader,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  // Prior ~76px effective drawer mark / 1.5 → ~51px.
                  child: _RailBrandWordmark(targetHeight: 51),
                ),
              ),
              const Divider(height: 1, color: IndustrialTheme.borderStroke),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final d in _destinations)
                      ListTile(
                        selected: d.path == selectedPath,
                        selectedTileColor: IndustrialTheme.skyBlue.withValues(
                          alpha: 0.14,
                        ),
                        leading: Icon(
                          d.path == selectedPath ? d.selectedIcon : d.icon,
                          color: d.path == selectedPath
                              ? IndustrialTheme.skyBlue
                              : IndustrialTheme.textMuted,
                        ),
                        title: Text(
                          d.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: d.path == selectedPath
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: d.path == selectedPath
                                ? IndustrialTheme.textPrimary
                                : IndustrialTheme.textMuted,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(d.path);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        // Keep bottom free for NavigationBar's own SafeArea; pad sides/top so
        // landscape content does not bleed under system gesture/nav bars.
        bottom: false,
        child: Column(
          children: [
            if (compactActions.isNotEmpty)
              _CompactActionStrip(actions: compactActions),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          backgroundColor: IndustrialTheme.darkHeader,
          indicatorColor: IndustrialTheme.skyBlue.withValues(alpha: 0.22),
          selectedIndex: barIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => context.go(barDestinations[i].path),
          destinations: [
            for (final d in barDestinations)
              NavigationDestination(
                icon: Icon(d.icon, color: IndustrialTheme.textMuted),
                selectedIcon: Icon(
                  d.selectedIcon,
                  color: IndustrialTheme.skyBlue,
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
        return 'Settings';
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
    return Material(
      color: IndustrialTheme.darkHeader,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: IndustrialTheme.borderStroke),
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
                    backgroundColor: IndustrialTheme.darkSurface,
                    foregroundColor: actions[i].onPressed == null
                        ? IndustrialTheme.textMuted
                        : IndustrialTheme.textPrimary,
                    disabledForegroundColor: IndustrialTheme.textMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(
                        color: IndustrialTheme.borderStroke,
                      ),
                    ),
                  ),
                  child: Text(
                    actions[i].label,
                    style: const TextStyle(
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
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.onRequestAccess});

  final Future<void> Function() onRequestAccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return PopupMenuButton<String>(
      tooltip: user?.email ?? 'Account',
      onSelected: (v) async {
        switch (v) {
          case 'signin':
            context.push('/login');
          case 'signout':
            await ref.read(supabaseClientProvider).auth.signOut();
          case 'settings':
            context.go('/settings');
          case 'access':
            await onRequestAccess();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            user?.email ?? 'Signed out — read-only',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const PopupMenuDivider(),
        if (user == null)
          const PopupMenuItem(
            value: 'signin',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.login),
              title: Text('Sign in'),
            ),
          )
        else
          const PopupMenuItem(
            value: 'signout',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout),
              title: Text('Sign out'),
            ),
          ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        const PopupMenuItem(
          value: 'access',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.mail_outline),
            title: Text('Request access'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: user == null
              ? IndustrialTheme.darkSurface
              : IndustrialTheme.skyBlue.withValues(alpha: 0.22),
          child: user == null
              ? const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: IndustrialTheme.textMuted,
                )
              : Text(
                  user.email!.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: IndustrialTheme.skyBlue,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RailBrandWordmark extends StatelessWidget {
  const _RailBrandWordmark({required this.targetHeight});

  final double targetHeight;

  /// Approximate aspect of assets/slst-wordmark-white.png.
  static const double _aspect = 3108 / 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxWidth / _aspect;
        final h = targetHeight < maxH ? targetHeight : maxH;
        return Align(
          alignment: Alignment.centerLeft,
          child: BrandWordmark(height: h),
        );
      },
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
      decoration: const BoxDecoration(
        color: IndustrialTheme.darkBase,
        border: Border(
          right: BorderSide(color: IndustrialTheme.borderStroke, width: 1),
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
            child: collapsed
                ? const Center(
                    child: Tooltip(
                      message: 'SLST',
                      child: BrandMark(size: 24),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.only(left: 2),
                    // ~54px effective / 1.5 → ~36px (was 3× prior 34px target).
                    child: _RailBrandWordmark(targetHeight: 36),
                  ),
          ),
          const Divider(height: 1, color: IndustrialTheme.borderStroke),
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
          const Divider(height: 1, color: IndustrialTheme.borderStroke),
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
                  color: IndustrialTheme.textMuted,
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
        ? IndustrialTheme.textPrimary
        : IndustrialTheme.textMuted;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? IndustrialTheme.skyBlue.withValues(alpha: 0.14)
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
                      color: selected ? IndustrialTheme.skyBlue : fg,
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
                          color: IndustrialTheme.skyBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 18,
                        color: selected ? IndustrialTheme.skyBlue : fg,
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
  const _TopHeader({required this.title, required this.onRequestAccess});

  final String title;
  final Future<void> Function() onRequestAccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final syncing = data.syncing || data.loading;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: IndustrialTheme.darkHeader,
        border: Border(
          bottom: BorderSide(color: IndustrialTheme.borderStroke, width: 1),
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
                color: IndustrialTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: IndustrialTheme.mintGreen.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: IndustrialTheme.mintGreen.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: IndustrialTheme.mintGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 72,
                  child: Text(
                    syncing ? 'Syncing…' : 'Live sync',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IndustrialTheme.mintGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: const Icon(
              Icons.notifications_outlined,
              size: 20,
              color: IndustrialTheme.textMuted,
            ),
          ),
          _AccountMenu(onRequestAccess: onRequestAccess),
        ],
      ),
    );
  }
}
