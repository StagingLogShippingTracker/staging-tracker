import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/industrial_widgets.dart';
import '../shared/widgets.dart';
import 'pair_watch_card.dart';
import 'app_update_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
    final user = ref.watch(currentUserProvider);

    // Pair Watch first so it is above the fold on phone/emulator and OCR
    // automation can find "Pair Watch" without scrolling past Account.
    return ColoredBox(
      color: IndustrialTheme.darkBase,
      child: ListView(
      padding: slstPagePadding(context),
      children: [
        const IndustrialPageTitle('Settings'),
        const PairWatchCard(),
        const SizedBox(height: 16),
        const AppUpdateCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: user == null
                          ? IndustrialTheme.darkHeader
                          : IndustrialTheme.skyBlue.withValues(alpha: 0.22),
                      child: user == null
                          ? const Icon(
                              Icons.person_off_outlined,
                              color: IndustrialTheme.textMuted,
                            )
                          : Text(
                              user.email!.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: IndustrialTheme.skyBlue,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'Signed out',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user == null
                                ? 'Read-only mode — sign in to create, edit, ship, or notify.'
                                : 'Authenticated — write actions enabled.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (user == null)
                      FilledButton.icon(
                        onPressed: () => context.push('/login'),
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Sign in'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(supabaseClientProvider)
                              .auth
                              .signOut();
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign out'),
                      ),
                    TextButton.icon(
                      onPressed: _requestAccess,
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: const Text('Request access'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const BrandFooter(),
      ],
    ),
    );
  }
}
