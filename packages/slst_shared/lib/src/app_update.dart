import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

/// Host platform for resolving which GitHub Release asset to download.
enum AppUpdatePlatform { windows, android, wear }

/// Latest GitHub Release metadata used by Settings → Update (all clients).
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    this.publishedAt,
    this.windowsInstallerUrl,
    this.windowsPortableUrl,
    this.androidApkUrl,
    this.wearApkUrl,
  });

  final String tagName;
  final String name;
  final String htmlUrl;
  final DateTime? publishedAt;
  final String? windowsInstallerUrl;
  final String? windowsPortableUrl;
  final String? androidApkUrl;
  final String? wearApkUrl;

  String? assetUrlFor(AppUpdatePlatform platform) {
    switch (platform) {
      case AppUpdatePlatform.windows:
        return windowsInstallerUrl ?? windowsPortableUrl;
      case AppUpdatePlatform.android:
        return androidApkUrl;
      case AppUpdatePlatform.wear:
        return wearApkUrl;
    }
  }

  String? assetLabelFor(AppUpdatePlatform platform) {
    switch (platform) {
      case AppUpdatePlatform.windows:
        if (windowsInstallerUrl != null) return 'SST-Setup-User.exe';
        if (windowsPortableUrl != null) return 'SST-Windows-Portable.zip';
        return null;
      case AppUpdatePlatform.android:
        return androidApkUrl == null ? null : 'SST-Android.apk';
      case AppUpdatePlatform.wear:
        return wearApkUrl == null ? null : 'SST-Wear.apk';
    }
  }
}

class AppUpdateService {
  const AppUpdateService();

  Future<AppReleaseInfo> fetchLatestRelease() async {
    final res = await http.get(
      Uri.parse(AppConfig.githubLatestReleaseApi),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'SST-Swift-Staging-Tracker',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (res.statusCode == 404) {
      throw Exception('No GitHub releases published yet.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Could not check for updates (HTTP ${res.statusCode}).');
    }

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Unexpected release payload.');
    }

    final assets = body['assets'];
    String? installer;
    String? portable;
    String? androidApk;
    String? wearApk;
    if (assets is List) {
      for (final raw in assets) {
        if (raw is! Map) continue;
        final name = '${raw['name'] ?? ''}'.trim();
        final url = '${raw['browser_download_url'] ?? ''}'.trim();
        if (name.isEmpty || url.isEmpty) continue;
        final lower = name.toLowerCase();
        if (lower.contains('setup') && lower.endsWith('.exe')) {
          installer = url;
        } else if (lower.contains('portable') && lower.endsWith('.zip')) {
          portable = url;
        } else if (lower.endsWith('.apk') && lower.contains('wear')) {
          wearApk = url;
        } else if (lower.endsWith('.apk') &&
            (lower.contains('android') || lower == 'sst-android.apk')) {
          androidApk = url;
        } else if (lower.endsWith('.apk') &&
            !lower.contains('wear') &&
            androidApk == null) {
          androidApk = url;
        }
      }
    }

    DateTime? published;
    final publishedRaw = body['published_at'] ?? body['created_at'];
    if (publishedRaw is String && publishedRaw.isNotEmpty) {
      published = DateTime.tryParse(publishedRaw)?.toLocal();
    }

    return AppReleaseInfo(
      tagName: '${body['tag_name'] ?? ''}'.trim(),
      name: '${body['name'] ?? body['tag_name'] ?? 'Latest'}'.trim(),
      htmlUrl: '${body['html_url'] ?? AppConfig.githubReleasesPage}'.trim(),
      publishedAt: published,
      windowsInstallerUrl: installer,
      windowsPortableUrl: portable,
      androidApkUrl: androidApk,
      wearApkUrl: wearApk,
    );
  }
}
