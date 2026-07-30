import 'package:flutter_test/flutter_test.dart';
import 'package:slst_shared/slst_shared.dart';

void main() {
  group('classifyReleaseAsset', () {
    test('maps SLST-Android.apk to android only', () {
      expect(
        classifyReleaseAsset('SLST-Android.apk'),
        ReleaseAssetKind.androidApk,
      );
    });

    test('maps SLST-Wear.apk to wear only', () {
      expect(classifyReleaseAsset('SLST-Wear.apk'), ReleaseAssetKind.wearApk);
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
        classifyReleaseAsset('SLST-Setup-User.exe'),
        ReleaseAssetKind.windowsSetup,
      );
      expect(
        classifyReleaseAsset('SLST-Windows-Portable.zip'),
        ReleaseAssetKind.windowsPortable,
      );
    });
  });

  group('AppReleaseInfo.hasAssetFor', () {
    const release = AppReleaseInfo(
      tagName: 'sst-1.2.0',
      name: 'SST 1.2.0',
      htmlUrl: 'https://example.com',
      androidApkUrl: 'https://example.com/SLST-Android.apk',
      wearApkUrl: 'https://example.com/SLST-Wear.apk',
    );

    test('android platform never reads wear url', () {
      expect(release.hasAssetFor(AppUpdatePlatform.android), isTrue);
      expect(
        release.assetUrlFor(AppUpdatePlatform.android),
        endsWith('SLST-Android.apk'),
      );
      expect(
        release.assetLabelFor(AppUpdatePlatform.android),
        'SLST-Android.apk',
      );
    });

    test('wear platform never reads android url', () {
      expect(release.hasAssetFor(AppUpdatePlatform.wear), isTrue);
      expect(
        release.assetUrlFor(AppUpdatePlatform.wear),
        endsWith('SLST-Wear.apk'),
      );
      expect(release.assetLabelFor(AppUpdatePlatform.wear), 'SLST-Wear.apk');
    });

    test('wear-only release is not an android update', () {
      const wearOnly = AppReleaseInfo(
        tagName: 'sst-9.9.9',
        name: 'Wear only',
        htmlUrl: 'https://example.com',
        wearApkUrl: 'https://example.com/SLST-Wear.apk',
      );
      expect(wearOnly.hasAssetFor(AppUpdatePlatform.wear), isTrue);
      expect(wearOnly.hasAssetFor(AppUpdatePlatform.android), isFalse);
      expect(wearOnly.isNewerThanInstalled('1.0.0', '1'), isTrue);
    });
  });
}
