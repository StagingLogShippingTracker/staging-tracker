import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/popup_gate.dart';
import '../../core/theme.dart';

/// In-app "What's new" prompt for the first [maxShows] launches of each
/// installed version on this device.
class AppChangelog {
  AppChangelog._();

  /// Per-version campaign: each app version shows What's New up to [maxShows] times.
  static const maxShows = 3;

  static String campaignIdFor(String version) => 'whats_new_$version';

  static String titleFor(String version) => "What's new (v$version)";

  /// Ordered newest-first, same campaign-wave pattern as Document Generator.
  static const sections = <ChangelogSection>[
    ChangelogSection(
      version: 'v1.1.49',
      bullets: [
        'Staging and Shipped logs now fit the window — Timestamp, Shipped By and Actions are no longer cut off at the right edge',
        'Rows stay the same height whether or not they carry the Prepared marker, so the list scans evenly',
        'SO numbers, links and contact initials use a brand red that meets accessibility contrast on both themes',
        'Dashboard KPIs are one strip instead of eight boxes, and categories sitting at zero step back so live counts stand out',
        'Warehouse floor map: bigger aisle letters and zone names, and "RECEIVING" no longer splits across lines mid-word',
        'The neighbouring-tenant block on the floor map fades into the background instead of dominating the map',
        'Quick Ship keeps its button on screen instead of hiding it below the fold',
        'Field hints sit a step below their labels so the two no longer blur together',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.48',
      bullets: [
        'Fixed: Pair Watch failed with a "Missing or invalid apikey" error — the app now sends the project\'s current key',
        'Android and Wear now get their own branded load screen (Swift mark, real progress) instead of holding a plain native launch screen',
        'Cleaned up raw error text (e.g. "Exception: ...") shown after a failed save or notification — messages now read as plain English',
        'The list/card view switch now shows list and grid icons instead of an unlabeled toggle',
        'Location picker highlights selectable bays in a distinct color, no longer the same red used for Rush/Hotshot elsewhere on the map',
        'What\'s New and How to Use no longer both pop up back-to-back on every update; How to Use now only appears a few times ever, not once per version',
        'Fixed the floor summary text (Skids/Boxes/Crates/Pipe) getting cut off at the bottom of the window',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.47',
      bullets: [
        'Windows splash matches Document Generator — Swift mark, real progress, briysce-apps lockup; holds until staging data is ready',
        'Android and Wear keep their existing launch screens, held open until the same Supabase-ready signal (9s cap)',
        'Carrier Forget removes the name everywhere (shared directory + tombstones), same as Staged By / Shipped By',
        'Prepared for Shipping carries through split, consolidate, and undo; Wear shows the marker on list and ship confirm',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.46',
      bullets: [
        'New "Prepared for Shipping" marker for staged entries — informational only; Ship and Quick Ship are unaffected',
        'Scanner: a page that failed processing or OCR is no longer stuck — Retry and every tool work on it again',
        'Scanner: better edge detection for smaller or off-center documents, sharper perspective correction, faster processing',
        'Carrier now uses the same shared directory as Staged By/Shipped By, Wear, and Swift Document Generator',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.45',
      bullets: [
        'Prompt windows no longer stack from rapid clicks or F-keys (intentional multi-step dialogs still work)',
        'Wear Pair Watch works with no sign-in; Unpair replaces Sign out on the watch',
        'Android launch screen is solid dark — no light tile / white padding behind the splash logo',
        'CI and packaging use SwiftStagingLog-* names; installer version tracks pubspec',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.44',
      bullets: [
        'Settings → Pair Watch creates a Wear pairing code with no sign-in (anon floor)',
        'Windows installer version tracks pubspec (no more stale 1.1.40 label)',
        'Staging log action column no longer overflows on Ship + menu',
        "What's New and How to use can be reopened anytime from Settings",
        'PM emails with photos no longer send twice (Make router routes are mutually exclusive)',
        'How to Use matches Notifications compose tabs and Settings Pair Watch / What’s New',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.43',
      bullets: [
        'Bulk PO, PO, and other PM notifications work again without sign-in (floor app uses secure server proxy only)',
        'Staging, ship, and return operations no longer block on missing session',
        'Notifications screen copy reflects no sign-in required',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.40',
      bullets: [
        'Sidebar shows only the Swift logo, centered (product name no longer squeezed next to it)',
        'Settings feedback emails now reach warehouse2@swiftsupply.ca through the same Make path as PM notifications',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.39',
      bullets: [
        'Launcher keeps Staging Log STAGE & SHIP artwork in a rounded-square tile (not Document Generator art)',
        'Send notification uses the same brand-red accent as Send feedback',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.38',
      bullets: [
        'Staging Log launcher art uses a rounded-square tile (same shape as Document Generator, our own graphic)',
        'Windows installer and shortcuts show Swift Staging & Shipping Log (not &&)',
        'Larger Swift logo above the expanded sidebar',
        'Wear no longer shows a signed-in email or mock credential on the icon',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.37',
      bullets: [
        'Product files and packages use Swift Staging & Shipping Log names (SwiftStagingLog-*), not SLST',
        'Expanded sidebar More Apps tile opens or installs Swift Document Generator',
      ],
    ),
    ChangelogSection(
      version: 'v1.1.36',
      bullets: [
        'Expanded sidebar includes a More Apps tile for Swift Document Generator',
        'If Document Generator is installed, the tile opens it; otherwise it downloads Setup/APK and starts install',
      ],
    ),
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

/// Shows the What's New dialog on demand (e.g. from Settings), regardless of
/// the auto-prompt's per-device show count.
Future<void> showWhatsNewDialog(BuildContext context) async {
  if (!context.mounted) return;
  String version = 'unknown';
  String versionLabel = '';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version.trim();
    versionLabel = '${info.version}+${info.buildNumber}';
  } catch (_) {}
  if (!context.mounted) return;
  await _showChangelogDialog(
    context,
    version: version,
    versionLabel: versionLabel,
    footer: 'You can reopen this anytime from Settings.',
    sections: AppChangelog.sections,
  );
}

/// Shows the What's New dialog when this device still has shows remaining.
Future<void> maybeShowChangelogPrompt(BuildContext context) async {
  if (!context.mounted) return;

  var state = await loadChangelogPromptState();
  String version = 'unknown';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version.trim();
  } catch (_) {}
  final campaignId = AppChangelog.campaignIdFor(version);
  if (state.campaignId != campaignId) {
    state = ChangelogPromptState(
      campaignId: campaignId,
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

  final remainingBefore = AppChangelog.maxShows - state.timesShown;
  final remainingAfter = remainingBefore - 1;
  final footer = remainingAfter <= 0
      ? 'This is the last time this summary will appear on this device. '
          'See Settings for the full history.'
      : remainingAfter == 1
          ? 'This summary will appear 1 more time on this device.'
          : 'This summary will appear $remainingAfter more times on this device.';

  // Just the current version here — this pops up unprompted, often on a
  // phone screen, so it should be a quick read. The full back-catalog stays
  // one tap away in Settings via showWhatsNewDialog.
  await _showChangelogDialog(
    context,
    version: version,
    versionLabel: versionLabel,
    footer: footer,
    sections: AppChangelog.sections.isNotEmpty
        ? [AppChangelog.sections.first]
        : const [],
  );

  await saveChangelogPromptState(
    ChangelogPromptState(
      campaignId: campaignId,
      timesShown: state.timesShown + 1,
    ),
  );
}

Future<void> _showChangelogDialog(
  BuildContext context, {
  required String version,
  required String versionLabel,
  required String footer,
  required List<ChangelogSection> sections,
}) async {
  await PopupGate.exclusive<void>(PopupKeys.whatsNew, () {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (ctx) {
      final chrome = IndustrialTheme.chromeOf(ctx);
      return AlertDialog(
        title: Text(AppChangelog.titleFor(version)),
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
                for (final section in sections) ...[
                  Text(
                    section.version,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: chrome.accentText,
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
  });
}
