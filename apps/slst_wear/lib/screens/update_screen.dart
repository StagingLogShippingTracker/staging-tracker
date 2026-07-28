import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slst_shared/slst_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Compact Wear Settings → Update: download SST-Wear.apk from GitHub Releases.
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
  bool _opening = false;
  String? _error;

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
    });
    try {
      final latest = await _svc.fetchLatestRelease();
      if (!mounted) return;
      setState(() => _latest = latest);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download() async {
    if (_latest == null) await _check();
    final release = _latest;
    if (release == null) return;
    final url = release.assetUrlFor(AppUpdatePlatform.wear);
    if (url == null || url.isEmpty) {
      setState(() {
        _error =
            'No Wear APK on release ${release.tagName}. Publish SST-Wear.apk.';
      });
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        setState(() => _error = 'Could not open download link.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = _info == null
        ? '…'
        : '${_info!.version} (${_info!.buildNumber})';
    final published = _latest?.publishedAt == null
        ? null
        : DateFormat.MMMd().add_jm().format(_latest!.publishedAt!);
    final asset = _latest?.assetLabelFor(AppUpdatePlatform.wear);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  color: WearTheme.muted,
                ),
                Expanded(
                  child: Text(
                    'UPDATE',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            Text(
              'Installed $installed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Wear builds update less often. Download SST-Wear.apk from GitHub Releases when available.',
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
              child: OutlinedButton(
                onPressed: _checking ? null : _check,
                child: Text(_checking ? 'Checking…' : 'Check for updates'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: (_checking || _opening) ? null : _download,
                child: Text(
                  _opening ? 'Opening…' : 'Download Wear APK',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
