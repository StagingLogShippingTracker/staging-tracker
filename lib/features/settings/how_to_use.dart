import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/popup_gate.dart';
import '../../core/theme.dart';

/// How To Use prompt: first [maxShows] launches ever on this device.
///
/// Deliberately NOT keyed per app version — this app ships small updates
/// often, and re-explaining the whole app on every update (stacked right
/// after What's New) trained users to reflexively dismiss both. Basic
/// navigation doesn't change release to release, so this is onboarding for
/// a new device/install, not a per-release notice.
class HowToUsePrompt {
  HowToUsePrompt._();

  static const maxShows = 3;
  static const title = 'How to use';

  static const campaignId = 'how_to_use_v1';

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
          'edit location or status, mark Prepared for Shipping when a line is '
          'physically ready to load (informational only — Ship and Quick Ship '
          'still work the same), scan documents onto the order, consolidate or '
          'split lines, then ship when freight leaves. Staged By / Picked By / '
          'Carrier remember values across this app, Wear, and Document Generator.',
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
          'Compose PO, Bulk PO, and Return emails to project managers, or open '
          'Notification log to see delivery history and whether a message went out. '
          'Ship confirm and return-to-stock emails also record here after you send them.',
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
          'Theme, in-app Update from GitHub, warehouse feedback, and Pair Watch '
          '(Wear OS — generate a 6-digit code; no sign-in). Reopen What’s New '
          'or How to use anytime. Update downloads the Windows Setup or Android APK '
          'for this app only.',
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

/// Shows How To Use on demand (e.g. from Settings), regardless of the
/// auto-prompt's per-device show count.
Future<void> showHowToUseDialog(BuildContext context) async {
  if (!context.mounted) return;
  await _showHowToUseDialog(
    context,
    footer: 'You can reopen this anytime from Settings.',
  );
}

/// Shows How To Use for the first [HowToUsePrompt.maxShows] launches of
/// each installed version on this device.
Future<void> maybeShowHowToUsePrompt(BuildContext context) async {
  if (!context.mounted) return;

  const campaignId = HowToUsePrompt.campaignId;
  var state = await loadHowToUsePromptState();
  if (state.campaignId != campaignId) {
    state = const HowToUsePromptState(
      campaignId: campaignId,
      timesShown: 0,
    );
  }
  if (state.timesShown >= HowToUsePrompt.maxShows) return;
  if (!context.mounted) return;

  final remainingAfter = HowToUsePrompt.maxShows - state.timesShown - 1;
  final footer = remainingAfter <= 0
      ? 'This is the last time this guide will appear on this device.'
      : remainingAfter == 1
          ? 'This guide will appear 1 more time on this device.'
          : 'This guide will appear $remainingAfter more times on this device.';

  await _showHowToUseDialog(context, footer: footer);

  await saveHowToUsePromptState(
    HowToUsePromptState(
      campaignId: campaignId,
      timesShown: state.timesShown + 1,
    ),
  );
}

Future<void> _showHowToUseDialog(
  BuildContext context, {
  required String footer,
}) async {
  await PopupGate.exclusive<void>(PopupKeys.howToUse, () {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: chrome.accentText,
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
  });
}
