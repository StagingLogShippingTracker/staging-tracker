import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';

/// In-app "What's new" prompt for the first [maxShows] launches of a campaign.
///
/// Matches Swift Document Generator: a campaign id, three shows, then silence
/// until [campaignId] is bumped for the next wave.
class AppChangelog {
  AppChangelog._();

  /// Bump this when starting a new What's New wave.
  static const campaignId = 'whats_new_1_1_35';
  static const maxShows = 3;
  static const title = "What's new (v1.1.35)";

  static const sections = <ChangelogSection>[
    ChangelogSection(
      version: 'v1.1.35',
      bullets: [
        'Staged By, Shipped By, Picked By, and Returned By use shared name memory (same as Document Generator), including delete',
        'Success chime after ship confirm, quick ship, and PM notifications',
        'Light/dark chrome matches Document Generator; Wear uses the same charcoal palette',
        'PM emails use warehouse chrome without the app name; disclaimer starts with This service',
        'Warehouse floor map, logs, and notifications no longer require sign-in',
      ],
    ),
  ];
}

class ChangelogSection {
  const ChangelogSection({required this.version, required this.bullets});

  final String version;
  final List<String> bullets;
}

class ChangelogPromptState {
  const ChangelogPromptState({
    required this.campaignId,
    required this.timesShown,
  });

  final String campaignId;
  final int timesShown;
}

abstract final class ChangelogPromptPrefs {
  static const campaignId = 'app_changelog_campaign_id';
  static const timesShown = 'app_changelog_times_shown';
}

Future<ChangelogPromptState> loadChangelogPromptState() async {
  final prefs = await SharedPreferences.getInstance();
  return ChangelogPromptState(
    campaignId: (prefs.getString(ChangelogPromptPrefs.campaignId) ?? '').trim(),
    timesShown: prefs.getInt(ChangelogPromptPrefs.timesShown) ?? 0,
  );
}

Future<void> saveChangelogPromptState(ChangelogPromptState state) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(ChangelogPromptPrefs.campaignId, state.campaignId);
  await prefs.setInt(ChangelogPromptPrefs.timesShown, state.timesShown);
}

/// Shows the What's New dialog when this device still has shows remaining.
Future<void> maybeShowChangelogPrompt(BuildContext context) async {
  if (!context.mounted) return;

  var state = await loadChangelogPromptState();
  if (state.campaignId != AppChangelog.campaignId) {
    state = const ChangelogPromptState(
      campaignId: AppChangelog.campaignId,
      timesShown: 0,
    );
  }
  if (state.timesShown >= AppChangelog.maxShows) return;

  String versionLabel = '';
  try {
    final info = await PackageInfo.fromPlatform();
    versionLabel = '${info.version}+${info.buildNumber}';
  } catch (_) {}

  if (!context.mounted) return;

  final next = ChangelogPromptState(
    campaignId: AppChangelog.campaignId,
    timesShown: state.timesShown + 1,
  );
  await saveChangelogPromptState(next);

  final remaining = AppChangelog.maxShows - next.timesShown;
  final footer = remaining <= 0
      ? 'This is the last time this summary will appear on this device.'
      : remaining == 1
          ? 'This summary will appear 1 more time on this device.'
          : 'This summary will appear $remaining more times on this device.';

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final chrome = IndustrialTheme.chromeOf(ctx);
      return AlertDialog(
        title: const Text(AppChangelog.title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (versionLabel.isNotEmpty) ...[
                  Text(
                    'Installed: $versionLabel',
                    style: TextStyle(
                      fontSize: 12,
                      color: chrome.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final section in AppChangelog.sections) ...[
                  Text(
                    section.version,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: IndustrialTheme.chromeAccent,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final bullet in section.bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•  ',
                            style: TextStyle(color: chrome.ink, height: 1.35),
                          ),
                          Expanded(
                            child: Text(
                              bullet,
                              style: TextStyle(
                                color: chrome.ink,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                Text(
                  footer,
                  style: TextStyle(
                    fontSize: 12,
                    color: chrome.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}
