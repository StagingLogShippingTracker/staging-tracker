import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_update.dart';

/// Settings card: check GitHub Releases and download+install the host build.
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
  bool _installing = false;
  double? _progress;
  String? _error;
  String? _status;

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
      _status = null;
    });
    try {
      final info = _info ?? await PackageInfo.fromPlatform();
      final result = await _svc.checkForUpdate(
        installedVersion: info.version,
        installedBuild: info.buildNumber,
        platform: _hostPlatform,
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _latest = result.latest;
      });

      if (result.missingPlatformAsset) {
        setState(() {
          _status =
              'Latest ${result.latest.tagName} has no $_platformLabel package '
              'yet. Other platform builds are ignored on this device.';
        });
        return;
      }

      if (!result.updateAvailable) {
        setState(() {
          _status =
              'You are up to date (${info.version}). Latest is ${result.latest.tagName}.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Up to date — installed ${info.version}, latest ${result.latest.tagName}.',
              ),
            ),
          );
        }
        return;
      }

      final packageLabel =
          result.latest.assetLabelFor(_hostPlatform) ?? '$_platformLabel package';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'A newer $_platformLabel build is available:\n'
            '${result.latest.name.isEmpty ? result.latest.tagName : result.latest.name}\n\n'
            'Package: $packageLabel\n'
            'Installed: ${info.version} (${info.buildNumber})\n\n'
            'Download and install this $_platformLabel package only?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes, update'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _downloadAndInstall(result.latest);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall(AppReleaseInfo release) async {
    final url = release.assetUrlFor(_hostPlatform);
    if (url == null || url.isEmpty) {
      setState(() {
        _error =
            'No $_platformLabel package is attached to release ${release.tagName}.';
      });
      return;
    }

    setState(() {
      _installing = true;
      _progress = 0;
      _error = null;
      _status = 'Downloading…';
    });
    try {
      await _svc.downloadAndInstall(
        platform: _hostPlatform,
        release: release,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _status = p >= 1.0
                ? 'Starting installer…'
                : 'Downloading… ${(p * 100).round()}%';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _status = Platform.isWindows
            ? 'Installer launched. Follow the setup prompts.'
            : 'Opening package installer…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
          _progress = null;
        });
      }
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

    final installed = _info == null
        ? '…'
        : '${_info!.version} (${_info!.buildNumber})';
    final assetLabel = _latest?.assetLabelFor(_hostPlatform);
    final publishedAt = _latest?.publishedAt;
    final published = publishedAt == null
        ? null
        : DateFormat('MMM d, y · h:mm a').format(publishedAt);
    final busy = _checking || _installing;

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
              'Check GitHub Releases for a newer $_platformLabel build. '
              'If an update is available you can download and install it here.',
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
            if (_status != null) ...[
              const SizedBox(height: 10),
              Text(
                _status!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IndustrialTheme.mintGreen,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress),
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
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: busy ? null : _check,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt, size: 18),
                  label: Text(
                    _installing
                        ? 'Installing…'
                        : _checking
                            ? 'Checking…'
                            : 'Check for updates',
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
