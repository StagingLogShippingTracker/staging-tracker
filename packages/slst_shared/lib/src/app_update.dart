import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'app_config.dart';

/// Host platform for resolving which GitHub Release asset to download.
enum AppUpdatePlatform { windows, android, wear }

/// Parsed semver (major.minor.patch) plus optional build number.
class AppVersion {
  const AppVersion(this.major, this.minor, this.patch, [this.build = 0]);

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// Parses `1.1.0`, `1.1.0+2`, `sst-1.1.0`, `v1.1.0`, etc.
  static AppVersion? tryParse(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    final match = RegExp(
      r'(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?',
    ).firstMatch(cleaned);
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.tryParse(match.group(4) ?? '') ?? 0,
    );
  }

  /// Compare name/version, then build. Returns negative / 0 / positive.
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => build > 0 ? '$major.$minor.$patch+$build' : '$major.$minor.$patch';
}

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

  AppVersion? get version => AppVersion.tryParse(tagName) ?? AppVersion.tryParse(name);

  /// True when this release is newer than the installed package version/build.
  bool isNewerThanInstalled(String version, [String? buildNumber]) {
    final remote = this.version;
    if (remote == null) return false;
    final build = int.tryParse((buildNumber ?? '').trim()) ?? 0;
    final local = AppVersion.tryParse(
          build > 0 ? '$version+$build' : version,
        ) ??
        AppVersion.tryParse(version);
    if (local == null) return false;
    // Prefer name/version; if equal, treat a higher remote build (from tag+N) as newer.
    return remote.isNewerThan(local);
  }

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

  String? assetFileNameFor(AppUpdatePlatform platform) {
    return assetLabelFor(platform);
  }
}

/// Result of [AppUpdateService.checkForUpdate].
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.latest,
    required this.updateAvailable,
  });

  final AppReleaseInfo latest;
  final bool updateAvailable;
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

  /// Fetches latest release and compares against [installedVersion] / [installedBuild].
  Future<AppUpdateCheckResult> checkForUpdate({
    required String installedVersion,
    String? installedBuild,
  }) async {
    final latest = await fetchLatestRelease();
    return AppUpdateCheckResult(
      latest: latest,
      updateAvailable: latest.isNewerThanInstalled(
        installedVersion,
        installedBuild,
      ),
    );
  }

  /// Downloads the platform asset to a temp file, then launches the installer
  /// (Windows exe) or package installer (Android/Wear APK).
  Future<File> downloadAndInstall({
    required AppUpdatePlatform platform,
    required AppReleaseInfo release,
    void Function(double progress)? onProgress,
  }) async {
    final url = release.assetUrlFor(platform);
    final fileName = release.assetFileNameFor(platform);
    if (url == null || url.isEmpty || fileName == null) {
      throw Exception('No package asset available for this platform.');
    }

    final file = await downloadToTemp(
      url: url,
      fileName: fileName,
      onProgress: onProgress,
    );
    await installDownloadedFile(platform: platform, file: file);
    return file;
  }

  Future<File> downloadToTemp({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (await target.exists()) {
      await target.delete();
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'SST-Swift-Staging-Tracker';
      final res = await client.send(req);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Download failed (HTTP ${res.statusCode}).');
      }
      final total = res.contentLength ?? 0;
      final sink = target.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0 && onProgress != null) {
            onProgress((received / total).clamp(0.0, 1.0));
          }
        }
        if (onProgress != null) onProgress(1.0);
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    if (!await target.exists() || await target.length() == 0) {
      throw Exception('Download produced an empty file.');
    }
    return target;
  }

  Future<void> installDownloadedFile({
    required AppUpdatePlatform platform,
    required File file,
  }) async {
    switch (platform) {
      case AppUpdatePlatform.windows:
        await Process.start(
          file.path,
          const <String>[],
          mode: ProcessStartMode.detached,
          runInShell: true,
        );
      case AppUpdatePlatform.android:
      case AppUpdatePlatform.wear:
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          throw Exception(
            result.message.isEmpty
                ? 'Could not open the downloaded package for install.'
                : result.message,
          );
        }
    }
  }
}
