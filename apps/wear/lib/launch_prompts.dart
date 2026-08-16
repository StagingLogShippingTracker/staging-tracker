import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Wear: What's New + How To Use, first 3 launches of each installed version.
Future<void> maybeShowWearLaunchPrompts(BuildContext context) async {
  if (!context.mounted) return;
  await maybeShowWearChangelog(context);
  if (!context.mounted) return;
  await maybeShowWearHowToUse(context);
}

Future<void> maybeShowWearChangelog(BuildContext context) async {
  await _maybeShowCampaign(
    context,
    prefsPrefix: 'wear_whats_new',
    title: "What's new",
    body:
        'Rounded launcher icon. Pairing never shows an email. Staging list, '
        'ship confirm, verify, and in-app Update are the watch tools.',
  );
}

Future<void> maybeShowWearHowToUse(BuildContext context) async {
  await _maybeShowCampaign(
    context,
    prefsPrefix: 'wear_how_to_use',
    title: 'How to use',
    body:
        'Pair once with the 6-digit code from phone or PC Settings. Tap an '
        'order to confirm ship. Verify checks the floor. Update installs the '
        'Wear APK from GitHub. No sign-in email is shown on this watch.',
  );
}

Future<void> _maybeShowCampaign(
  BuildContext context, {
  required String prefsPrefix,
  required String title,
  required String body,
}) async {
  if (!context.mounted) return;
  String version = 'unknown';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version.trim();
  } catch (_) {}
  if (version.isEmpty) return;

  final campaignId = '${prefsPrefix}_$version';
  final prefs = await SharedPreferences.getInstance();
  final storedId = (prefs.getString('${prefsPrefix}_campaign') ?? '').trim();
  var shown = prefs.getInt('${prefsPrefix}_shown') ?? 0;
  if (storedId != campaignId) {
    shown = 0;
  }
  if (shown >= 3) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: WearTheme.surface,
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Text(
          body,
          style: const TextStyle(fontSize: 12, height: 1.35),
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

  await prefs.setString('${prefsPrefix}_campaign', campaignId);
  await prefs.setInt('${prefsPrefix}_shown', shown + 1);
}

String wearSafeError(Object error) {
  final text = error.toString();
  if (text.contains('@') ||
      text.toLowerCase().contains('email') ||
      text.toLowerCase().contains('jwt')) {
    return 'Could not complete that step. Try again.';
  }
  if (text.length > 120) {
    return 'Could not complete that step. Try again.';
  }
  return text;
}
