import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';

/// One-time How To Use prompt for **v1.1.37 only**.
///
/// Same show-count logic as Document Generator / What's New: [maxShows]
/// launches per device, then silence. Later app versions never show this.
class HowToUsePrompt {
  HowToUsePrompt._();

  static const campaignId = 'how_to_use_1_1_37';
  static const targetVersion = '1.1.37';
  static const maxShows = 3;
  static const title = 'How to use';

  static const intro =
      'Swift Staging & Shipping Log is the warehouse floor book for Swift '
      'operations. It tracks what is sitting in staging, when it should ship, '
      'and what already left — then emails project managers from the same record.';

  static const sections = <HowToUseSection>[
    HowToUseSection(
      title: 'Dashboard',
      body:
          'Start here. KPI cards and the staging board show rush, today, tomorrow, '
          'partial, future, pickups, and awaiting. The warehouse floor map shows '
          'where pallets sit. Search and tap an order to inspect it.',
    ),
    HowToUseSection(
      title: 'Active Staging Entries Log',
      body:
          'Everything still in the warehouse. Add a new entry (F1 on Windows), '
          'edit location or status, scan documents onto the order, consolidate '
          'or split lines, then ship when freight leaves. Staged By / Picked By '
          'remember names across this app and Document Generator.',
    ),
    HowToUseSection(
      title: 'Shipped Staging Entries Log',
      body:
          'Completed shipments. Use Quick Ship for a fast outbound, or open a '
          'row to confirm carrier details, photos, and PM notification. Returns '
          'and return-to-stock also live on this path.',
    ),
    HowToUseSection(
      title: 'Reports & Analytics',
      body:
          'Verification and audit of what is on the floor versus the log. Work '
          'exceptions (wrong location, missing pieces) until the warehouse and '
          'the book match.',
    ),
    HowToUseSection(
      title: 'Notifications',
      body:
          'History of PM emails this app sent (ship confirm, PO, bulk, returns). '
          'Use it to see whether a message went out and to retry if it failed.',
    ),
    HowToUseSection(
      title: 'Contacts',
      body:
          'People and companies used on entries. Remembered names stay in sync '
          'with Document Generator. Delete a remembered name with the X if it '
          'should not suggest again.',
    ),
    HowToUseSection(
      title: 'Settings',
      body:
          'Theme, Pair Watch (Wear OS), in-app Update from GitHub, and warehouse '
          'feedback. Update downloads the Windows Setup or Android APK for this '
          'app only.',
    ),
    HowToUseSection(
      title: 'More Apps',
      body:
          'With the sidebar expanded, More Apps can open Swift Document Generator '
          'if it is installed, or download Setup/APK and start install if it is not.',
    ),
  ];
}

class HowToUseSection {
  const HowToUseSection({required this.title, required this.body});

  final String title;
  final String body;
}

class HowToUsePromptState {
  const HowToUsePromptState({
    required this.campaignId,
    required this.timesShown,
  });

  final String campaignId;
  final int timesShown;
}

abstract final class HowToUsePromptPrefs {
  static const campaignId = 'app_how_to_use_campaign_id';
  static const timesShown = 'app_how_to_use_times_shown';
}

Future<HowToUsePromptState> loadHowToUsePromptState() async {
  final prefs = await SharedPreferences.getInstance();
  return HowToUsePromptState(
    campaignId: (prefs.getString(HowToUsePromptPrefs.campaignId) ?? '').trim(),
    timesShown: prefs.getInt(HowToUsePromptPrefs.timesShown) ?? 0,
  );
}

Future<void> saveHowToUsePromptState(HowToUsePromptState state) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(HowToUsePromptPrefs.campaignId, state.campaignId);
  await prefs.setInt(HowToUsePromptPrefs.timesShown, state.timesShown);
}

/// Shows How To Use on v1.1.37 only, for the first [HowToUsePrompt.maxShows]
/// launches on this device.
Future<void> maybeShowHowToUsePrompt(BuildContext context) async {
  if (!context.mounted) return;

  String version = '';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version.trim();
  } catch (_) {
    return;
  }
  if (version != HowToUsePrompt.targetVersion) return;

  var state = await loadHowToUsePromptState();
  if (state.campaignId != HowToUsePrompt.campaignId) {
    state = const HowToUsePromptState(
      campaignId: HowToUsePrompt.campaignId,
      timesShown: 0,
    );
  }
  if (state.timesShown >= HowToUsePrompt.maxShows) return;
  if (!context.mounted) return;

  final next = HowToUsePromptState(
    campaignId: HowToUsePrompt.campaignId,
    timesShown: state.timesShown + 1,
  );
  await saveHowToUsePromptState(next);

  final remaining = HowToUsePrompt.maxShows - next.timesShown;
  final footer = remaining <= 0
      ? 'This is the last time this guide will appear on this device.'
      : remaining == 1
          ? 'This guide will appear 1 more time on this device.'
          : 'This guide will appear $remaining more times on this device.';

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final chrome = IndustrialTheme.chromeOf(ctx);
      return AlertDialog(
        title: const Text(HowToUsePrompt.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  HowToUsePrompt.intro,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: chrome.ink,
                  ),
                ),
                const SizedBox(height: 14),
                for (final section in HowToUsePrompt.sections) ...[
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: IndustrialTheme.chromeAccent,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    section.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: chrome.ink,
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
