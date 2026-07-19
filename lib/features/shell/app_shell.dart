import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';

class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _allDestinations = [
  _Destination('/', 'Dashboard', Icons.space_dashboard_outlined,
      Icons.space_dashboard),
  _Destination(
      '/staging', 'Staging', Icons.inventory_2_outlined, Icons.inventory_2),
  _Destination('/shipped', 'Shipped', Icons.local_shipping_outlined,
      Icons.local_shipping),
  _Destination(
      '/reports', 'Reports', Icons.insert_chart_outlined, Icons.insert_chart),
  _Destination('/notifications', 'Notify', Icons.notifications_outlined,
      Icons.notifications),
  _Destination(
      '/contacts', 'Contacts', Icons.contacts_outlined, Icons.contacts),
];

/// Phone bottom bar shows 4 primary destinations + a More sheet.
const _phonePrimaryCount = 4;

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
            for (final d in _allDestinations.skip(_phonePrimaryCount))
              ListTile(
                leading: Icon(
                  location == d.path ? d.selectedIcon : d.icon,
                  color: location == d.path ? SlstColors.brand : null,
                ),
                title: Text(
                  d.label == 'Notify' ? 'PM Notifications' : d.label,
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
                    fontFamily: 'SLSTBrand',
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
                    fontFamily: 'Oswald',
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
    final useRail = width >= 840;

    final appBar = _buildAppBar(context, ref, location);

    if (useRail) {
      final selected = _allDestinations.indexWhere((d) => d.path == location);
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) =>
                  context.go(_allDestinations[i].path),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _allDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      tooltip: 'Request access',
                      onPressed: _requestAccess,
                      icon: const Icon(Icons.mail_outline),
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    final primary = _allDestinations.take(_phonePrimaryCount).toList();
    var selected = primary.indexWhere((d) => d.path == location);
    final onMorePage =
        _allDestinations.skip(_phonePrimaryCount).any((d) => d.path == location);
    if (onMorePage) selected = _phonePrimaryCount;

    return Scaffold(
      appBar: appBar,
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
              label: d.label,
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
