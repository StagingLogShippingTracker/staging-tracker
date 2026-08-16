import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:slst_shared/slst_shared.dart';

/// Sibling Swift Operations apps advertised from the expanded sidebar.
class SiblingApp {
  const SiblingApp({
    required this.id,
    required this.name,
    required this.blurb,
    required this.iconAsset,
    required this.githubLatestApi,
    required this.windowsSetupAsset,
    required this.androidApkAsset,
    required this.androidPackageName,
    required this.windowsExeName,
    required this.windowsInstallFolderName,
  });

  final String id;
  final String name;
  final String blurb;
  final String iconAsset;
  final String githubLatestApi;
  final String windowsSetupAsset;
  final String androidApkAsset;
  final String androidPackageName;
  final String windowsExeName;
  final String windowsInstallFolderName;
}

const siblingDocumentGenerator = SiblingApp(
  id: 'document-generator',
  name: 'Document Generator',
  blurb: 'Labels, packing slips, and shipping documents.',
  iconAsset: 'assets/swift-document-generator-icon.png',
  githubLatestApi:
      'https://api.github.com/repos/StagingLogShippingTracker/swift-shipping-label/releases/latest',
  windowsSetupAsset: 'SwiftDocumentGenerator-Setup.exe',
  androidApkAsset: 'SwiftDocumentGenerator-android.apk',
  androidPackageName: 'com.swiftoilfield.swift_shipping_label',
  windowsExeName: 'swift_shipping_label.exe',
  windowsInstallFolderName: 'Swift Document Generator',
);

class SiblingAppLaunch {
  const SiblingAppLaunch._({
    required this.launched,
    required this.installed,
    this.status,
  });

  final bool launched;
  final bool installed;
  final String? status;

  factory SiblingAppLaunch.opened() =>
      const SiblingAppLaunch._(launched: true, installed: true);

  factory SiblingAppLaunch.installing(String status) => SiblingAppLaunch._(
        launched: false,
        installed: false,
        status: status,
      );
}

/// Detect, launch, or download/install a sibling operations app.
class SiblingAppsService {
  SiblingAppsService({AppUpdateService? updates})
      : _updates = updates ?? const AppUpdateService();

  static const _androidChannel = MethodChannel('slst/sibling_apps');
  final AppUpdateService _updates;

  Future<bool> isInstalled(SiblingApp app) async {
    if (kIsWeb) return false;
    if (Platform.isWindows) return _windowsExePath(app) != null;
    if (Platform.isAndroid) {
      try {
        final result = await _androidChannel.invokeMethod<bool>(
          'isInstalled',
          {'packageName': app.androidPackageName},
        );
        return result == true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<SiblingAppLaunch> openOrInstall(
    SiblingApp app, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    if (await isInstalled(app)) {
      final ok = await _launch(app);
      if (ok) return SiblingAppLaunch.opened();
      throw Exception('Could not open ${app.name}.');
    }

    onStatus?.call('Downloading ${app.name}…');
    final asset = await _latestInstallAsset(app);
    if (asset == null) {
      throw Exception(
        'No ${Platform.isWindows ? 'Windows' : 'Android'} installer is attached '
        'to the latest ${app.name} release.',
      );
    }

    final file = Platform.isWindows
        ? await _updates.downloadToAppStorage(
            url: asset.url,
            fileName: asset.fileName,
            onProgress: onProgress,
          )
        : await _updates.downloadToTemp(
            url: asset.url,
            fileName: asset.fileName,
            onProgress: onProgress,
          );

    onStatus?.call('Starting installer…');
    await _updates.installDownloadedFile(
      platform: Platform.isWindows
          ? AppUpdatePlatform.windows
          : AppUpdatePlatform.android,
      file: file,
    );
    return SiblingAppLaunch.installing(
      Platform.isWindows
          ? 'Installer launched — finish Setup, then tap again to open.'
          : 'Install prompt opened — after install, tap again to open.',
    );
  }

  Future<bool> _launch(SiblingApp app) async {
    if (Platform.isWindows) {
      final path = _windowsExePath(app);
      if (path == null) return false;
      await Process.start(
        path,
        const <String>[],
        workingDirectory: File(path).parent.path,
        mode: ProcessStartMode.detached,
      );
      return true;
    }
    if (Platform.isAndroid) {
      try {
        final result = await _androidChannel.invokeMethod<bool>(
          'launch',
          {'packageName': app.androidPackageName},
        );
        return result == true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  String? _windowsExePath(SiblingApp app) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      final installed = File(
        '$localAppData${Platform.pathSeparator}Programs'
        '${Platform.pathSeparator}${app.windowsInstallFolderName}'
        '${Platform.pathSeparator}${app.windowsExeName}',
      );
      if (installed.existsSync()) return installed.path;
    }
    return null;
  }

  Future<({String url, String fileName})?> _latestInstallAsset(
    SiblingApp app,
  ) async {
    final client = http.Client();
    try {
      final res = await client.get(
        Uri.parse(app.githubLatestApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'SwiftStagingLog',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Could not reach ${app.name} releases (${res.statusCode}).');
      }
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      final assets = body['assets'];
      if (assets is! List) return null;

      final want = Platform.isWindows
          ? app.windowsSetupAsset.toLowerCase()
          : app.androidApkAsset.toLowerCase();

      for (final raw in assets) {
        if (raw is! Map) continue;
        final name = '${raw['name'] ?? ''}'.trim();
        final url = '${raw['browser_download_url'] ?? ''}'.trim();
        if (name.toLowerCase() == want && url.isNotEmpty) {
          return (url: url, fileName: name);
        }
      }
      return null;
    } finally {
      client.close();
    }
  }
}
