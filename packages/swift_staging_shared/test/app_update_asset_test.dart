import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

void main() {
  group('classifyReleaseAsset', () {
    test('maps SwiftStagingLog-Android.apk to android only', () {
      expect(
        classifyReleaseAsset('SwiftStagingLog-Android.apk'),
        ReleaseAssetKind.androidApk,
      );
    });

    test('maps legacy SLST-Android.apk to android only', () {
      expect(
        classifyReleaseAsset('SLST-Android.apk'),
        ReleaseAssetKind.androidApk,
      );
    });

    test('maps SwiftStagingLog-Wear.apk to wear only', () {
      expect(
        classifyReleaseAsset('SwiftStagingLog-Wear.apk'),
        ReleaseAssetKind.wearApk,
      );
    });

    test('wear wins when both tokens appear', () {
      expect(
        classifyReleaseAsset('SST-Android-Wear.apk'),
        ReleaseAssetKind.wearApk,
      );
    });

    test('generic apk is ignored (no cross-platform fallback)', () {
      expect(classifyReleaseAsset('app.apk'), ReleaseAssetKind.unknown);
      expect(classifyReleaseAsset('slst.apk'), ReleaseAssetKind.unknown);
    });

    test('windows assets', () {
      expect(
        classifyReleaseAsset('SwiftStagingLog-Setup-User.exe'),
        ReleaseAssetKind.windowsSetup,
      );
      expect(
        classifyReleaseAsset('SwiftStagingLog-Windows-Portable.zip'),
        ReleaseAssetKind.windowsPortable,
      );
      expect(
        classifyReleaseAsset('SLST-Setup-User.exe'),
        ReleaseAssetKind.windowsSetup,
      );
    });
  });

  group('AppReleaseInfo.hasAssetFor', () {
    const release = AppReleaseInfo(
      tagName: 'sst-1.2.0',
      name: 'SST 1.2.0',
      htmlUrl: 'https://example.com',
      androidApkUrl: 'https://example.com/SwiftStagingLog-Android.apk',
      wearApkUrl: 'https://example.com/SwiftStagingLog-Wear.apk',
    );

    test('android platform never reads wear url', () {
      expect(release.hasAssetFor(AppUpdatePlatform.android), isTrue);
      expect(
        release.assetUrlFor(AppUpdatePlatform.android),
        endsWith('SwiftStagingLog-Android.apk'),
      );
      expect(
        release.assetLabelFor(AppUpdatePlatform.android),
        'SwiftStagingLog-Android.apk',
      );
    });

    test('wear platform never reads android url', () {
      expect(release.hasAssetFor(AppUpdatePlatform.wear), isTrue);
      expect(
        release.assetUrlFor(AppUpdatePlatform.wear),
        endsWith('SwiftStagingLog-Wear.apk'),
      );
      expect(release.assetLabelFor(AppUpdatePlatform.wear), 'SwiftStagingLog-Wear.apk');
    });

    test('wear-only release is not an android update', () {
      const wearOnly = AppReleaseInfo(
        tagName: 'sst-9.9.9',
        name: 'Wear only',
        htmlUrl: 'https://example.com',
        wearApkUrl: 'https://example.com/SwiftStagingLog-Wear.apk',
      );
      expect(wearOnly.hasAssetFor(AppUpdatePlatform.wear), isTrue);
      expect(wearOnly.hasAssetFor(AppUpdatePlatform.android), isFalse);
      expect(wearOnly.isNewerThanInstalled('1.0.0', '1'), isTrue);
    });

    test('windows in-app update requires Setup.exe, not portable zip', () {
      const portableOnly = AppReleaseInfo(
        tagName: 'sst-9.9.9',
        name: 'Portable only',
        htmlUrl: 'https://example.com',
        windowsPortableUrl: 'https://example.com/SwiftStagingLog-Windows-Portable.zip',
      );
      expect(portableOnly.hasAssetFor(AppUpdatePlatform.windows), isFalse);

      const withSetup = AppReleaseInfo(
        tagName: 'sst-9.9.9',
        name: 'With setup',
        htmlUrl: 'https://example.com',
        windowsInstallerUrl: 'https://example.com/SwiftStagingLog-Setup-User.exe',
        windowsPortableUrl: 'https://example.com/SwiftStagingLog-Windows-Portable.zip',
      );
      expect(withSetup.hasAssetFor(AppUpdatePlatform.windows), isTrue);
      expect(
        withSetup.assetUrlFor(AppUpdatePlatform.windows),
        endsWith('SwiftStagingLog-Setup-User.exe'),
      );
      expect(
        withSetup.assetLabelFor(AppUpdatePlatform.windows),
        'SwiftStagingLog-Setup-User.exe',
      );
    });
  });
}
