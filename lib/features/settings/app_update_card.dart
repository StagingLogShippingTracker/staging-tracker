import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_update.dart';

/// Settings card: check GitHub Releases and download the host-platform build.
class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({super.key});

  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  static const _svc = AppUpdateService();

  PackageInfo? _info;
  AppReleaseInfo? _latest;
  bool _checking = false;
  bool _opening = false;
  String? _error;

  bool get _supported {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isAndroid;
  }

  String get _platformLabel {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    return 'This platform';
  }

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _loadInstalled();
    }
  }

  Future<void> _loadInstalled() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _info = info);
    } catch (_) {
      // Leave version unknown; update check still works.
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final latest = await _svc.fetchLatestRelease();
      if (!mounted) return;
      setState(() => _latest = latest);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    final latest = _latest;
    if (latest == null) {
      await _check();
    }
    final release = _latest;
    if (release == null) return;

    final platform = Platform.isWindows
        ? AppUpdatePlatform.windows
        : AppUpdatePlatform.android;
    final url = release.assetUrlFor(platform);
    if (url == null || url.isEmpty) {
      setState(() {
        _error =
            'No $_platformLabel package is attached to release ${release.tagName}.';
      });
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(() => _error = 'Could not open the download link.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openReleases() async {
    final uri = Uri.parse(
      (_latest?.htmlUrl.isNotEmpty ?? false)
          ? _latest!.htmlUrl
          : AppConfig.githubReleasesPage,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();

    final hostPlatform = Platform.isWindows
        ? AppUpdatePlatform.windows
        : AppUpdatePlatform.android;
    final installed = _info == null
        ? '…'
        : '${_info!.version} (${_info!.buildNumber})';
    final assetLabel = _latest?.assetLabelFor(hostPlatform);
    final publishedAt = _latest?.publishedAt;
    final published = publishedAt == null
        ? null
        : DateFormat('MMM d, y · h:mm a').format(publishedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.system_update_alt,
                  size: 20,
                  color: IndustrialTheme.skyBlue,
                ),
                const SizedBox(width: 10),
                Text(
                  'UPDATE',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Installed: $installed · $_platformLabel',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Download the latest $_platformLabel build from GitHub Releases '
              '(installer on Windows, APK on Android).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_latest != null) ...[
              const SizedBox(height: 12),
              Text(
                'Latest: ${_latest!.name.isEmpty ? _latest!.tagName : _latest!.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_latest!.tagName.isNotEmpty)
                Text(
                  'Tag ${_latest!.tagName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (published != null)
                Text(
                  'Published $published',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (assetLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Package: $assetLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IndustrialTheme.mintGreen,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'No $_platformLabel asset on this release yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IndustrialTheme.amber,
                        ),
                  ),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_checking ? 'Checking…' : 'Check for updates'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: (_checking || _opening) ? null : _download,
                  icon: _opening
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    _opening ? 'Opening…' : 'Download latest $_platformLabel',
                  ),
                ),
                TextButton.icon(
                  onPressed: _openReleases,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View releases'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
