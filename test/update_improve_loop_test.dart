import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// In-app Update improve-loop harness → qa_update/synthetic/harness_results.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('update improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_update', 'synthetic'));
    await synDir.create(recursive: true);
    final cases = <Map<String, dynamic>>[];

    Map<String, dynamic> timed(
      String caseId,
      bool Function() run, {
      Map<String, dynamic>? metricsRaw,
      Map<String, bool>? gatesRaw,
    }) {
      final t0 = DateTime.now();
      var ok = false;
      String? err;
      try {
        ok = run();
      } catch (e) {
        err = '$e';
        ok = false;
      }
      return {
        'case_id': caseId,
        'ok': ok,
        'duration_ms': DateTime.now().difference(t0).inMilliseconds,
        if (metricsRaw != null) 'metrics_raw': metricsRaw,
        if (gatesRaw != null) 'gates_raw': gatesRaw,
        if (err != null) 'error': err,
      };
    }

    cases.add(
      timed(
        'classify_windows_setup_exe',
        () =>
            classifyReleaseAsset('SwiftStagingLog-Setup-User.exe') ==
                ReleaseAssetKind.windowsSetup &&
            classifyReleaseAsset('SLST-Setup-User.exe') ==
                ReleaseAssetKind.windowsSetup,
        metricsRaw: {'integrity': true},
      ),
    );

    cases.add(
      timed(
        'classify_windows_portable_zip',
        () =>
            classifyReleaseAsset('SwiftStagingLog-Windows-Portable.zip') ==
            ReleaseAssetKind.windowsPortable,
      ),
    );

    cases.add(
      timed(
        'classify_android_apk',
        () =>
            classifyReleaseAsset('SwiftStagingLog-Android.apk') ==
                ReleaseAssetKind.androidApk &&
            classifyReleaseAsset('SLST-Android.apk') ==
                ReleaseAssetKind.androidApk,
      ),
    );

    cases.add(
      timed(
        'classify_wear_apk',
        () =>
            classifyReleaseAsset('SwiftStagingLog-Wear.apk') ==
            ReleaseAssetKind.wearApk,
      ),
    );

    cases.add(
      timed(
        'wear_wins_over_android_token',
        () =>
            classifyReleaseAsset('SST-Android-Wear.apk') ==
            ReleaseAssetKind.wearApk,
        gatesRaw: {'wear_precedence': true},
      ),
    );

    cases.add(
      timed(
        'generic_apk_unknown',
        () =>
            classifyReleaseAsset('app.apk') == ReleaseAssetKind.unknown &&
            classifyReleaseAsset('slst.apk') == ReleaseAssetKind.unknown,
        gatesRaw: {'no_cross_install': true},
      ),
    );

    cases.add(
      timed('windows_update_requires_setup_not_portable', () {
        const portableOnly = AppReleaseInfo(
          tagName: 't',
          name: 'n',
          htmlUrl: 'https://example.com',
          windowsPortableUrl:
              'https://example.com/SwiftStagingLog-Windows-Portable.zip',
        );
        const withSetup = AppReleaseInfo(
          tagName: 't',
          name: 'n',
          htmlUrl: 'https://example.com',
          windowsInstallerUrl:
              'https://example.com/SwiftStagingLog-Setup-User.exe',
          windowsPortableUrl:
              'https://example.com/SwiftStagingLog-Windows-Portable.zip',
        );
        return !portableOnly.hasAssetFor(AppUpdatePlatform.windows) &&
            withSetup.hasAssetFor(AppUpdatePlatform.windows) &&
            withSetup
                .assetUrlFor(AppUpdatePlatform.windows)!
                .endsWith('Setup-User.exe');
      }, gatesRaw: {'setup_required': true}),
    );

    cases.add(
      timed('android_never_reads_wear_url', () {
        const release = AppReleaseInfo(
          tagName: 't',
          name: 'n',
          htmlUrl: 'https://example.com',
          androidApkUrl: 'https://example.com/SwiftStagingLog-Android.apk',
          wearApkUrl: 'https://example.com/SwiftStagingLog-Wear.apk',
        );
        return release
            .assetUrlFor(AppUpdatePlatform.android)!
            .endsWith('Android.apk');
      }),
    );

    cases.add(
      timed('wear_never_reads_android_url', () {
        const release = AppReleaseInfo(
          tagName: 't',
          name: 'n',
          htmlUrl: 'https://example.com',
          androidApkUrl: 'https://example.com/SwiftStagingLog-Android.apk',
          wearApkUrl: 'https://example.com/SwiftStagingLog-Wear.apk',
        );
        return release.assetUrlFor(AppUpdatePlatform.wear)!.endsWith('Wear.apk');
      }),
    );

    cases.add(
      timed(
        'github_latest_api_configured',
        () =>
            AppConfig.githubLatestReleaseApi.contains('releases/latest') &&
            AppConfig.githubLatestReleaseApi.contains(
              'StagingLogShippingTracker',
            ),
      ),
    );

    cases.add(
      timed(
        'denver_prompt_1500',
        () => DenverTime.checkHour == 15,
      ),
    );

    cases.add(
      timed(
        'snooze_three_days',
        () =>
            const UpdatePromptSchedule().snoozeDuration ==
            const Duration(days: 3),
      ),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'update',
      'cases': cases,
      'notes': [
        'Windows Update requires Setup.exe; portable zip is not enough.',
        'Wear APK must never install on phone and vice versa.',
      ],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
