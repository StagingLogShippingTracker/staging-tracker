import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slst_shared/slst_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../wear_layout.dart';

/// Compact Wear Settings → Update: check, confirm, download+install SLST-Wear.apk.
class WearUpdateScreen extends StatefulWidget {
  const WearUpdateScreen({super.key});

  @override
  State<WearUpdateScreen> createState() => _WearUpdateScreenState();
}

class _WearUpdateScreenState extends State<WearUpdateScreen> {
  static const _svc = AppUpdateService();

  PackageInfo? _info;
  AppReleaseInfo? _latest;
  bool _checking = false;
  bool _installing = false;
  double? _progress;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _info = info);
    } catch (_) {}
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
        platform: AppUpdatePlatform.wear,
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _latest = result.latest;
      });

      if (result.missingPlatformAsset) {
        setState(() {
          _status =
              'Latest ${result.latest.tagName} has no Wear APK. Phone builds are ignored.';
        });
        return;
      }

      if (!result.updateAvailable) {
        setState(() {
          _status = 'Up to date (${info.version}).';
        });
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update?', style: TextStyle(fontSize: 16)),
          content: Text(
            '${result.latest.tagName}\nInstall SLST-Wear.apk?',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _downloadAndInstall(result.latest);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall(AppReleaseInfo release) async {
    final url = release.assetUrlFor(AppUpdatePlatform.wear);
    if (url == null || url.isEmpty) {
      setState(() {
        _error =
            'No Wear APK on release ${release.tagName}. Publish SLST-Wear.apk.';
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
        platform: AppUpdatePlatform.wear,
        release: release,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _status = p >= 1.0
                ? 'Opening installer…'
                : 'Downloading… ${(p * 100).round()}%';
          });
        },
      );
      if (!mounted) return;
      setState(() => _status = 'Installer opened.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
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
    final insets = WearLayout.contentInsets(context);
    final installed = _info == null
        ? '…'
        : '${_info!.version} (${_info!.buildNumber})';
    final published = _latest?.publishedAt == null
        ? null
        : DateFormat.MMMd().add_jm().format(_latest!.publishedAt!);
    final asset = _latest?.assetLabelFor(AppUpdatePlatform.wear);
    final busy = _checking || _installing;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          insets.left,
          insets.top,
          insets.right,
          insets.bottom + 12,
        ),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          WearPageHeader(
            title: 'UPDATE',
            onBack: () => Navigator.of(context).pop(),
          ),
          Text(
            'Installed $installed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Checks GitHub for a newer Wear build, then downloads and installs.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (_latest != null) ...[
            const SizedBox(height: 10),
            Text(
              _latest!.name.isEmpty ? _latest!.tagName : _latest!.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (published != null)
              Text(
                published,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            Text(
              asset ?? 'No Wear APK on this release',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: asset == null ? WearTheme.warn : WearTheme.ok,
              ),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(
              _status!,
              style: const TextStyle(
                color: WearTheme.ok,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_progress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: WearTheme.danger, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : _check,
              child: Text(
                _installing
                    ? 'Installing…'
                    : _checking
                        ? 'Checking…'
                        : 'Check for updates',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: TextButton(
              onPressed: _openReleases,
              child: const Text('View releases'),
            ),
          ),
        ],
      ),
    );
  }
}
