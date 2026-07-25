import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shipping/shipped_screen.dart';
import '../features/staging/staging_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/staging',
            name: 'staging',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StagingScreen()),
          ),
          GoRoute(
            path: '/shipped',
            name: 'shipped',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ShippedScreen()),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationsScreen()),
          ),
          GoRoute(
            path: '/contacts',
            name: 'contacts',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ContactsScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});
