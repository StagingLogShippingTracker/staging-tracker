import 'package:flutter_test/flutter_test.dart';
import 'package:slst_shared/slst_shared.dart';

void main() {
  group('classifyReleaseAsset', () {
    test('maps SST-Android.apk to android only', () {
      expect(
        classifyReleaseAsset('SST-Android.apk'),
        ReleaseAssetKind.androidApk,
      );
    });

    test('maps SST-Wear.apk to wear only', () {
      expect(classifyReleaseAsset('SST-Wear.apk'), ReleaseAssetKind.wearApk);
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
        classifyReleaseAsset('SST-Setup-User.exe'),
        ReleaseAssetKind.windowsSetup,
      );
      expect(
        classifyReleaseAsset('SST-Windows-Portable.zip'),
        ReleaseAssetKind.windowsPortable,
      );
    });
  });

  group('AppReleaseInfo.hasAssetFor', () {
    const release = AppReleaseInfo(
      tagName: 'sst-1.2.0',
      name: 'SST 1.2.0',
      htmlUrl: 'https://example.com',
      androidApkUrl: 'https://example.com/SST-Android.apk',
      wearApkUrl: 'https://example.com/SST-Wear.apk',
    );

    test('android platform never reads wear url', () {
      expect(release.hasAssetFor(AppUpdatePlatform.android), isTrue);
      expect(
        release.assetUrlFor(AppUpdatePlatform.android),
        endsWith('SST-Android.apk'),
      );
      expect(
        release.assetLabelFor(AppUpdatePlatform.android),
        'SST-Android.apk',
      );
    });

    test('wear platform never reads android url', () {
      expect(release.hasAssetFor(AppUpdatePlatform.wear), isTrue);
      expect(
        release.assetUrlFor(AppUpdatePlatform.wear),
        endsWith('SST-Wear.apk'),
      );
      expect(release.assetLabelFor(AppUpdatePlatform.wear), 'SST-Wear.apk');
    });

    test('wear-only release is not an android update', () {
      const wearOnly = AppReleaseInfo(
        tagName: 'sst-9.9.9',
        name: 'Wear only',
        htmlUrl: 'https://example.com',
        wearApkUrl: 'https://example.com/SST-Wear.apk',
      );
      expect(wearOnly.hasAssetFor(AppUpdatePlatform.wear), isTrue);
      expect(wearOnly.hasAssetFor(AppUpdatePlatform.android), isFalse);
      expect(wearOnly.isNewerThanInstalled('1.0.0', '1'), isTrue);
    });
  });
}
