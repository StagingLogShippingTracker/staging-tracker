import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

import 'app_changelog.dart';
import 'how_to_use.dart';

/// Runs the daily 15:00 America/Denver update check while the app is open,
/// matching Swift Document Generator (live GitHub latest, Later = 3 days).
///
/// Quiet when already up to date (no dialog). Only shows Update/Later when
/// GitHub `releases/latest` has a newer package for this platform. Each prompt
/// (including after a 3-day Later snooze) re-fetches latest — never installs a
/// version cached from an earlier prompt.
class ScheduledUpdateHost extends StatefulWidget {
  const ScheduledUpdateHost({super.key, required this.child});

  final Widget child;

  @override
  State<ScheduledUpdateHost> createState() => _ScheduledUpdateHostState();
}

class _ScheduledUpdateHostState extends State<ScheduledUpdateHost>
    with WidgetsBindingObserver {
  static const _svc = AppUpdateService();
  static const _schedule = UpdatePromptSchedule();

  Timer? _wakeTimer;
  Timer? _pollTimer;
  bool _busy = false;
  bool _dialogOpen = false;

  bool get _supported {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isAndroid;
  }

  AppUpdatePlatform get _hostPlatform => Platform.isWindows
      ? AppUpdatePlatform.windows
      : AppUpdatePlatform.android;

  String get _platformLabel {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    return 'This platform';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstFrame());
    _pollTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _evaluate(),
    );
  }

  Future<void> _onFirstFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    try {
      await maybeShowHowToUsePrompt(context);
      if (!mounted) return;
      await maybeShowChangelogPrompt(context);
    } catch (_) {}
    if (mounted) await _evaluate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluate();
    }
  }

  Future<void> _evaluate() async {
    if (!_supported || _busy || _dialogOpen || !mounted) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final snoozeUntil = _readSnoozeUntil(prefs);
      final lastDate = prefs.getString(UpdatePromptPrefs.lastPromptDenverDate);

      _armWakeTimer(
        _schedule.nextWakeUtc(now: now, snoozeUntil: snoozeUntil),
      );

      if (!_schedule.shouldRunCheck(
        now: now,
        snoozeUntil: snoozeUntil,
        lastPromptDenverDate: lastDate,
      )) {
        return;
      }

      // Always live-check releases/latest — never reuse a prior "available" version.
      final info = await PackageInfo.fromPlatform();
      final result = await _svc.checkForUpdate(
        installedVersion: info.version,
        installedBuild: info.buildNumber,
        platform: _hostPlatform,
      );
      if (!mounted) return;

      // Up to date (or no platform asset): stay silent — no Update/Later dialog.
      if (!result.updateAvailable) {
        await prefs.setString(
          UpdatePromptPrefs.lastPromptDenverDate,
          DenverTime.dateKey(now),
        );
        return;
      }

      await prefs.setString(
        UpdatePromptPrefs.lastPromptDenverDate,
        DenverTime.dateKey(now),
      );

      _dialogOpen = true;
      final choice = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'A newer $_platformLabel build is available:\n'
            '${result.latest.name.isEmpty ? result.latest.tagName : result.latest.name}\n\n'
            'Package: ${result.latest.assetLabelFor(_hostPlatform) ?? '$_platformLabel package'}\n'
            'Installed: ${info.version} (${info.buildNumber})\n\n'
            'Update now, or choose Later to snooze this prompt for 3 days?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      _dialogOpen = false;
      if (!mounted) return;

      if (choice == true) {
        // Re-fetch immediately before install so a release published between
        // the prompt check and the tap still wins.
        final fresh = await _svc.checkForUpdate(
          installedVersion: info.version,
          installedBuild: info.buildNumber,
          platform: _hostPlatform,
        );
        if (!mounted) return;
        if (!fresh.updateAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already up to date.')),
          );
          return;
        }
        await _downloadAndInstall(fresh.latest);
        return;
      }

      // Later (or unexpected null) → 3-day snooze.
      final until = _schedule.snoozeUntilFrom(DateTime.now());
      await prefs.setInt(
        UpdatePromptPrefs.snoozeUntilMs,
        until.millisecondsSinceEpoch,
      );
      _armWakeTimer(
        _schedule.nextWakeUtc(now: DateTime.now(), snoozeUntil: until),
      );
    } catch (_) {
      // Network / parse errors: leave the day unmarked so a later resume can retry.
    } finally {
      _busy = false;
    }
  }

  DateTime? _readSnoozeUntil(SharedPreferences prefs) {
    final ms = prefs.getInt(UpdatePromptPrefs.snoozeUntilMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void _armWakeTimer(DateTime wakeUtc) {
    _wakeTimer?.cancel();
    final delay = wakeUtc.difference(DateTime.now().toUtc());
    if (delay <= Duration.zero) {
      _wakeTimer = Timer(const Duration(seconds: 2), _evaluate);
      return;
    }
    // Cap very long sleeps so DST / clock changes get re-evaluated daily.
    final capped =
        delay > const Duration(hours: 24) ? const Duration(hours: 24) : delay;
    _wakeTimer = Timer(capped, _evaluate);
  }

  Future<void> _downloadAndInstall(AppReleaseInfo release) async {
    var progress = 0.0;
    StateSetter? setProgress;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            setProgress = setState;
            return AlertDialog(
              title: const Text('Updating'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress <= 0 ? null : progress,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progress >= 1.0
                        ? 'Starting installer…'
                        : 'Downloading… ${(progress * 100).round()}%',
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      await _svc.downloadAndInstall(
        platform: _hostPlatform,
        release: release,
        onProgress: (p) {
          progress = p;
          setProgress?.call(() {});
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
