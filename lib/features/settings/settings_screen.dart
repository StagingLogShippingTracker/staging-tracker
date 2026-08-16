import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/theme_preference.dart';
import '../shared/industrial_widgets.dart';
import '../shared/widgets.dart';
import 'pair_watch_card.dart';
import 'app_update_card.dart';
import 'feedback_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: IndustrialTheme.chromeOf(context).base,
      child: ListView(
      padding: slstPagePadding(context),
      children: [
        const IndustrialPageTitle('Settings'),
        Card(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Dark mode'),
            subtitle: Text(
              'Matches Swift Document Generator light and dark chrome.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: ref.watch(darkModeProvider),
            onChanged: (v) => ref.read(darkModeProvider.notifier).setDark(v),
          ),
        ),
        const SizedBox(height: 16),
        const PairWatchCard(),
        const SizedBox(height: 16),
        const AppUpdateCard(),
        const SizedBox(height: 16),
        const FeedbackCard(),
      ],
    ),
    );
  }
}
