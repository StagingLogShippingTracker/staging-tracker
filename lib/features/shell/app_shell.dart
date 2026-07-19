import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _destinations = [
    (path: '/', label: 'Dashboard', icon: Icons.dashboard_outlined),
    (path: '/staging', label: 'Staging', icon: Icons.inventory_2_outlined),
    (path: '/shipped', label: 'Shipped', icon: Icons.local_shipping_outlined),
    (path: '/reports', label: 'Reports', icon: Icons.fact_check_outlined),
    (path: '/notifications', label: 'Notify', icon: Icons.notifications_outlined),
    (path: '/contacts', label: 'Contacts', icon: Icons.contacts_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final user = ref.watch(currentUserProvider);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 900;

    final body = Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: ListTile(
              leading: Image.asset(
                'assets/staging-shipping-logo.png',
                width: 40,
                height: 40,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.local_shipping, color: SlstColors.brand),
              ),
              title: const Text(
                'SLST',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                user?.email ?? 'Signed out (read-only)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Toggle theme',
                    onPressed: () async {
                      final next = !ref.read(darkModeProvider);
                      ref.read(darkModeProvider.notifier).state = next;
                      final prefs = await ref.read(prefsProvider.future);
                      await prefs.setDarkMode(next);
                    },
                    icon: Icon(
                      ref.watch(darkModeProvider)
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () =>
                        ref.read(appDataProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                  ),
                  if (user == null)
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Sign In'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(supabaseClientProvider)
                            .auth
                            .signOut();
                      },
                      child: const Text('Sign Out'),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );

    if (useRail) {
      final selected = _destinations.indexWhere((d) => d.path == location);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
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
                      icon: const Icon(Icons.mail_outline),
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    final selected = _destinations.indexWhere((d) => d.path == location);
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
