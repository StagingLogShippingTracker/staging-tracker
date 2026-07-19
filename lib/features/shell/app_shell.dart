import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';

/// One shell destination, shared by the desktop sidebar and the phone bottom
/// bar. Carries both a full [label] (sidebar / header bar) and a compact
/// [shortLabel] (bottom bar) plus a [subtitle] used by the desktop header.
class NavDestinationInfo {
  const NavDestinationInfo({
    required this.path,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final String shortLabel;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}

const List<NavDestinationInfo> _destinations = [
  NavDestinationInfo(
    path: '/',
    label: 'Dashboard',
    shortLabel: 'Dashboard',
    subtitle: 'Staging Log & Shipping Tracker overview',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
  ),
  NavDestinationInfo(
    path: '/staging',
    label: 'Staging Log',
    shortLabel: 'Staging',
    subtitle: 'All staged freight awaiting shipment',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  NavDestinationInfo(
    path: '/shipped',
    label: 'Shipped Log',
    shortLabel: 'Shipped',
    subtitle: 'Completed shipments and returns',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
  NavDestinationInfo(
    path: '/reports',
    label: 'Reports',
    shortLabel: 'Reports',
    subtitle: 'Operational summaries and changelog',
    icon: Icons.insert_chart_outlined_rounded,
    selectedIcon: Icons.insert_chart,
  ),
  NavDestinationInfo(
    path: '/notifications',
    label: 'Notifications',
    shortLabel: 'Notify',
    subtitle: 'PM email notifications via Make',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
  ),
  NavDestinationInfo(
    path: '/contacts',
    label: 'Contacts',
    shortLabel: 'Contacts',
    subtitle: 'Swift Supply directory',
    icon: Icons.contacts_outlined,
    selectedIcon: Icons.contacts,
  ),
];

/// Phone bottom bar shows this many primary destinations + a More sheet.
const _phonePrimaryCount = 4;

/// At/above this width the desktop sidebar shell is used; below it the
/// touch-first phone shell (app bar + bottom navigation) is used.
const _sidebarBreakpoint = 900.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  String _titleFor(String location) {
    switch (location) {
      case '/staging':
        return 'Staging Log';
      case '/shipped':
        return 'Shipped Log';
      case '/reports':
        return 'Reports';
      case '/notifications':
        return 'PM Notifications';
      case '/contacts':
        return 'Contacts';
      default:
        return 'Dashboard';
    }
  }

  Future<void> _requestAccess() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.accessRequestEmail,
      queryParameters: {
        'subject': 'Access Request: Staging Log & Shipping Tracker',
      },
    );
    await launchUrl(uri);
  }

  void _showMoreSheet(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in _destinations.skip(_phonePrimaryCount))
              ListTile(
                leading: Icon(
                  location == d.path ? d.selectedIcon : d.icon,
                  color: location == d.path ? SlstColors.brand : null,
                ),
                title: Text(
                  _titleFor(d.path),
                  style: TextStyle(
                    fontWeight:
                        location == d.path ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(d.path);
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Request access'),
              subtitle: const Text('Email the admin for edit permissions'),
              onTap: () {
                Navigator.pop(sheetContext);
                _requestAccess();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    String location,
  ) {
    final user = ref.watch(currentUserProvider);
    final dark = ref.watch(darkModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Image.asset(
              'assets/staging-shipping-logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.local_shipping,
                color: SlstColors.brand,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SLST',
                  style: TextStyle(
                    fontFamily: kBrandFontFamily,
                    fontSize: 17,
                    height: 1.1,
                    letterSpacing: 1.5,
                    color: SlstColors.brand,
                  ),
                ),
                Text(
                  _titleFor(location),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.1,
                    fontFamily: kBodyFontFamily,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: dark ? 'Light mode' : 'Dark mode',
          onPressed: () async {
            final next = !ref.read(darkModeProvider);
            ref.read(darkModeProvider.notifier).state = next;
            final prefs = await ref.read(prefsProvider.future);
            await prefs.setDarkMode(next);
          },
          icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PopupMenuButton<String>(
            tooltip: user == null ? 'Signed out (read-only)' : user.email,
            onSelected: (v) async {
              switch (v) {
                case 'signin':
                  context.push('/login');
                case 'signout':
                  await ref.read(supabaseClientProvider).auth.signOut();
                case 'access':
                  await _requestAccess();
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
                value: 'access',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.mail_outline),
                  title: Text('Request access'),
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 17,
              backgroundColor: user == null
                  ? scheme.surfaceContainerHighest
                  : SlstColors.brandSoft,
              child: user == null
                  ? Icon(Icons.person_outline,
                      size: 20, color: scheme.onSurfaceVariant)
                  : Text(
                      user.email!.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SlstColors.brand,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final width = MediaQuery.sizeOf(context).width;
    final useSidebar = width >= _sidebarBreakpoint;

    final index = _destinations.indexWhere((d) => d.path == location);
    final current = _destinations[index < 0 ? 0 : index];

    // Desktop / Windows: rich sidebar + header bar (brand header, nav accent
    // bars, account footer).
    if (useSidebar) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(selectedPath: current.path),
            Expanded(
              child: Column(
                children: [
                  _HeaderBar(title: current.label, subtitle: current.subtitle),
                  const Divider(height: 1),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Phone / tablet: touch-first app bar + bottom navigation with a More
    // sheet for the overflow destinations.
    final primary = _destinations.take(_phonePrimaryCount).toList();
    var selected = primary.indexWhere((d) => d.path == location);
    final onMorePage =
        _destinations.skip(_phonePrimaryCount).any((d) => d.path == location);
    if (onMorePage) selected = _phonePrimaryCount;

    return Scaffold(
      appBar: _buildAppBar(context, ref, location),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (i) {
          if (i == _phonePrimaryCount) {
            _showMoreSheet(context, ref);
          } else {
            context.go(primary[i].path);
          }
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.shortLabel,
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selectedPath});
  final String selectedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: dark ? SlstColors.darkSurface : SlstColors.surface,
        border: Border(
          right: BorderSide(
            color: dark ? SlstColors.darkBorder : SlstColors.border,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : SlstColors.surfaceMuted,
                    border: Border.all(
                      color: dark ? SlstColors.darkBorder : SlstColors.border,
                    ),
                  ),
                  child: Image.asset(
                    'assets/staging-shipping-logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.local_shipping,
                      color: SlstColors.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SLST',
                        style: TextStyle(
                          fontFamily: kBrandFontFamily,
                          fontSize: 22,
                          height: 1.0,
                          color: dark ? SlstColors.darkInk : SlstColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'STAGING & SHIPPING',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          color: dark ? SlstColors.darkMuted : SlstColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: [
                for (final d in _destinations)
                  _NavTile(item: d, selected: d.path == selectedPath),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user == null
                            ? (dark
                                ? SlstColors.darkSurfaceMuted
                                : SlstColors.surfaceSubtle)
                            : SlstColors.brandSoft,
                      ),
                      child: Icon(
                        user == null
                            ? Icons.person_off_outlined
                            : Icons.person_outline,
                        size: 18,
                        color: user == null
                            ? (dark ? SlstColors.darkMuted : SlstColors.muted)
                            : SlstColors.brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'Signed out',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            user == null ? 'Read-only mode' : 'Full access',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: dark
                                  ? SlstColors.darkMuted
                                  : SlstColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        dark ? SlstColors.darkMuted : SlstColors.muted,
                    alignment: Alignment.centerLeft,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: AppConfig.accessRequestEmail,
                      queryParameters: {
                        'subject':
                            'Access Request: Staging Log & Shipping Tracker',
                      },
                    );
                    await launchUrl(uri);
                  },
                  icon: const Icon(Icons.mail_outline, size: 16),
                  label: const Text('Request access'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected});

  final NavDestinationInfo item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? SlstColors.brand
        : (dark ? SlstColors.darkInk : SlstColors.ink);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? (dark
                ? SlstColors.brand.withValues(alpha: 0.16)
                : SlstColors.brandSoft)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(item.path),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: selected ? 18 : 0,
                  margin: const EdgeInsets.only(left: 4, right: 9),
                  decoration: BoxDecoration(
                    color: SlstColors.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(selected ? item.selectedIcon : item.icon, size: 19, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? SlstColors.darkSurface : SlstColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: dark ? SlstColors.darkInk : SlstColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? SlstColors.darkMuted : SlstColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const _HeaderActions(),
        ],
      ),
    );
  }
}

class _HeaderActions extends ConsumerWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final darkMode = ref.watch(darkModeProvider);
    final loading = ref.watch(appDataProvider).loading;

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: darkMode ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () async {
            final next = !ref.read(darkModeProvider);
            ref.read(darkModeProvider.notifier).state = next;
            final prefs = await ref.read(prefsProvider.future);
            await prefs.setDarkMode(next);
          },
          icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'Refresh data',
          onPressed: loading
              ? null
              : () => ref.read(appDataProvider.notifier).refresh(),
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 20),
        ),
        if (user == null)
          FilledButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Sign In'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
      ],
    );
  }
}
