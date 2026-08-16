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

  /// Preferred Windows asset for in-app Update — Setup.exe only (not portable zip).
  String? get windowsInstallUrl => windowsInstallerUrl;

  String? assetUrlFor(AppUpdatePlatform platform) {
    switch (platform) {
      case AppUpdatePlatform.windows:
        // Match swift_document_generator: in-app Update launches Setup.exe only.
        return windowsInstallUrl;
      case AppUpdatePlatform.android:
        return androidApkUrl;
      case AppUpdatePlatform.wear:
        return wearApkUrl;
    }
  }

  String? assetLabelFor(AppUpdatePlatform platform) {
    final url = assetUrlFor(platform);
    if (url == null || url.isEmpty) return null;
    final name = Uri.tryParse(url)?.pathSegments.last;
    if (name != null && name.isNotEmpty) return name;
    return switch (platform) {
      AppUpdatePlatform.windows => 'SwiftStagingLog-Setup-User.exe',
      AppUpdatePlatform.android => 'SwiftStagingLog-Android.apk',
      AppUpdatePlatform.wear => 'SwiftStagingLog-Wear.apk',
    };
  }

  String? assetFileNameFor(AppUpdatePlatform platform) {
    return assetLabelFor(platform);
  }

  /// Whether this release includes an installable package for [platform].
  /// Phone/tablet never treat Wear APKs as available (and vice versa).
  bool hasAssetFor(AppUpdatePlatform platform) {
    final url = assetUrlFor(platform);
    return url != null && url.isNotEmpty;
  }
}

/// Result of [AppUpdateService.checkForUpdate].
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.latest,
    required this.updateAvailable,
    required this.platform,
    this.missingPlatformAsset = false,
  });

  final AppReleaseInfo latest;
  final AppUpdatePlatform platform;

  /// True only when the release is newer **and** has this platform's package.
  final bool updateAvailable;

  /// Newer release exists, but it has no package for [platform]
  /// (e.g. Wear-only asset on a phone check).
  final bool missingPlatformAsset;
}

class AppUpdateService {
  const AppUpdateService();

  /// Prefer SwiftStagingLog-* over leftover SLST-* names on the same release.
  static bool _preferReleaseAsset(String? currentUrl, String newName) {
    if (currentUrl == null || currentUrl.isEmpty) return true;
    final current =
        Uri.tryParse(currentUrl)?.pathSegments.last.toLowerCase() ?? '';
    final incoming = newName.toLowerCase();
    final currentLegacy = current.startsWith('slst-');
    final incomingProduct = incoming.contains('swiftstaginglog');
    final incomingLegacy = incoming.startsWith('slst-');
    final currentProduct = current.contains('swiftstaginglog');
    if (incomingProduct && currentLegacy) return true;
    if (incomingLegacy && currentProduct) return false;
    return true;
  }

  Future<AppReleaseInfo> fetchLatestRelease() async {
    final res = await http.get(
      Uri.parse(AppConfig.githubLatestReleaseApi),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'SwiftStagingLog',
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
        final kind = classifyReleaseAsset(name);
        switch (kind) {
          case ReleaseAssetKind.windowsSetup:
            if (_preferReleaseAsset(installer, name)) installer = url;
          case ReleaseAssetKind.windowsPortable:
            if (_preferReleaseAsset(portable, name)) portable = url;
          case ReleaseAssetKind.androidApk:
            if (_preferReleaseAsset(androidApk, name)) androidApk = url;
          case ReleaseAssetKind.wearApk:
            if (_preferReleaseAsset(wearApk, name)) wearApk = url;
          case ReleaseAssetKind.unknown:
            break;
        }
      }
    }

    DateTime? published;
    final publishedRaw = body['published_at'] ?? body['created_at'];
    if (publishedRaw is String && publishedRaw.isNotEmpty) {
      // Prefer UTC→local so release cards show the calendar year from GitHub.
      final parsed = DateTime.tryParse(publishedRaw);
      if (parsed != null) {
        published = parsed.isUtc ? parsed.toLocal() : parsed.toLocal();
      }
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
  ///
  /// [platform] gates the installable package: Android phone/tablet only sees
  /// the Android APK; Wear only sees the Wear APK; Windows only sees
  /// Setup.exe (portable zip is not used for in-app Update).
  /// A newer tag with only another platform's package does **not** count as
  /// an update for this device.
  Future<AppUpdateCheckResult> checkForUpdate({
    required String installedVersion,
    String? installedBuild,
    required AppUpdatePlatform platform,
  }) async {
    final latest = await fetchLatestRelease();
    final newer = latest.isNewerThanInstalled(
      installedVersion,
      installedBuild,
    );
    final hasAsset = latest.hasAssetFor(platform);
    return AppUpdateCheckResult(
      latest: latest,
      platform: platform,
      updateAvailable: newer && hasAsset,
      missingPlatformAsset: newer && !hasAsset,
    );
  }

  /// Downloads the platform asset, then launches the installer
  /// (Windows Setup.exe in-process) or package installer (Android/Wear APK).
  Future<File> downloadAndInstall({
    required AppUpdatePlatform platform,
    required AppReleaseInfo release,
    void Function(double progress)? onProgress,
  }) async {
    final url = release.assetUrlFor(platform);
    final fileName = release.assetFileNameFor(platform);
    if (url == null || url.isEmpty || fileName == null) {
      if (platform == AppUpdatePlatform.windows) {
        throw Exception(
          'No Windows Setup.exe asset on this release. '
          'In-app Update requires the Windows Setup installer.',
        );
      }
      throw Exception('No package asset available for this platform.');
    }
    _assertAssetMatchesPlatform(platform: platform, url: url, fileName: fileName);

    // Windows: durable app-support path (same as swift_document_generator).
    // Android/Wear: temp is fine for OpenFilex handoff.
    final file = platform == AppUpdatePlatform.windows
        ? await downloadToAppStorage(
            url: url,
            fileName: fileName,
            onProgress: onProgress,
          )
        : await downloadToTemp(
            url: url,
            fileName: fileName,
            onProgress: onProgress,
          );
    await installDownloadedFile(platform: platform, file: file);
    return file;
  }

  void _assertAssetMatchesPlatform({
    required AppUpdatePlatform platform,
    required String url,
    required String fileName,
  }) {
    final kind = classifyReleaseAsset(fileName);
    final urlLower = url.toLowerCase();
    switch (platform) {
      case AppUpdatePlatform.windows:
        if (kind != ReleaseAssetKind.windowsSetup) {
          throw Exception(
            'Refusing Windows in-app install of non-Setup asset ($fileName).',
          );
        }
      case AppUpdatePlatform.android:
        if (kind != ReleaseAssetKind.androidApk ||
            urlLower.contains('wear')) {
          throw Exception(
            'Refusing Android phone/tablet install of Wear or unknown APK ($fileName).',
          );
        }
      case AppUpdatePlatform.wear:
        if (kind != ReleaseAssetKind.wearApk) {
          throw Exception(
            'Refusing Wear install of non-Wear APK ($fileName).',
          );
        }
    }
  }

  Future<File> downloadToAppStorage({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}updates',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _downloadToFile(
      url: url,
      target: File('${dir.path}${Platform.pathSeparator}$fileName'),
      onProgress: onProgress,
    );
  }

  Future<File> downloadToTemp({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    return _downloadToFile(
      url: url,
      target: File('${dir.path}${Platform.pathSeparator}$fileName'),
      onProgress: onProgress,
    );
  }

  Future<File> _downloadToFile({
    required String url,
    required File target,
    void Function(double progress)? onProgress,
  }) async {
    if (await target.exists()) {
      await target.delete();
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'SwiftStagingLog';
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
        // Direct detached spawn (no runInShell) — same as swift_document_generator.
        // Avoids cmd.exe / shell association opening a separate install window.
        await Process.start(
          file.path,
          const <String>[],
          mode: ProcessStartMode.detached,
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

/// Maps a GitHub asset filename to a platform package kind.
enum ReleaseAssetKind {
  windowsSetup,
  windowsPortable,
  androidApk,
  wearApk,
  unknown,
}

/// Classifies GitHub Release asset filenames into platform packages.
///
/// Wear APKs are identified first (name contains `wear`) so they are never
/// treated as phone/tablet Android packages. Phone/tablet APKs must include
/// `android` in the filename (e.g. `SwiftStagingLog-Android.apk`). Generic `.apk` names
/// are ignored to avoid cross-installing the wrong client.
ReleaseAssetKind classifyReleaseAsset(String fileName) {
  final lower = fileName.trim().toLowerCase();
  if (lower.isEmpty) return ReleaseAssetKind.unknown;

  if (lower.endsWith('.exe') && lower.contains('setup')) {
    return ReleaseAssetKind.windowsSetup;
  }
  if (lower.endsWith('.zip') && lower.contains('portable')) {
    return ReleaseAssetKind.windowsPortable;
  }
  if (lower.endsWith('.apk')) {
    // Wear wins over "android" if both appear in the name.
    if (lower.contains('wear')) return ReleaseAssetKind.wearApk;
    if (lower.contains('android') ||
        lower == 'swiftstaginglog-android.apk' ||
        lower == 'sst-android.apk' ||
        lower == 'slst-android.apk') {
      return ReleaseAssetKind.androidApk;
    }
    return ReleaseAssetKind.unknown;
  }
  return ReleaseAssetKind.unknown;
}

