import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/industrial_widgets.dart';
import '../shared/order_history_dialog.dart';
import '../shared/widgets.dart';

/// Right-side Order Inspector for the dashboard card board.
class OrderInspector extends ConsumerWidget {
  const OrderInspector({
    super.key,
    required this.entry,
    required this.onClose,
  });

  final StagingEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiStatus = StatusRules.formatUi(entry.status);
    final urgent =
        uiStatus == 'Ship Today' || StatusRules.isOverdue(entry.status);

    return SlideOverInspector(
      title: 'ORDER INSPECTOR: ${entry.so}',
      onClose: onClose,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IndustrialStatusBadge(status: uiStatus),
              if (urgent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Customer'),
          Text(entry.customer, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Zone'),
          Text(
            entry.location.isEmpty ? '—' : entry.location,
            style: IndustrialTheme.mono(
              fontSize: 13,
              color: IndustrialTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel(context, 'Proof of Staging'),
          const SizedBox(height: 8),
          _ProofOfStagingGrid(paths: entry.photoUrls, so: entry.so),
          const SizedBox(height: 18),
          _sectionLabel(context, 'Container Checklist'),
          const SizedBox(height: 8),
          _ContainerChecklist(entry: entry),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _sectionLabel(context, 'Live Audit Trail')),
              TextButton(
                onPressed: () =>
                    showOrderHistoryDialog(context, ref, so: entry.so),
                style: TextButton.styleFrom(
                  foregroundColor: IndustrialTheme.skyBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View all',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LiveAuditTrail(so: entry.so),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class _ProofOfStagingGrid extends StatelessWidget {
  const _ProofOfStagingGrid({required this.paths, required this.so});

  final List<String> paths;
  final String so;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        decoration: BoxDecoration(
          color: IndustrialTheme.darkHeader,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: IndustrialTheme.borderStroke),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 28,
              color: IndustrialTheme.textMuted,
            ),
            SizedBox(height: 8),
            Text(
              'No proof-of-staging photos',
              style: TextStyle(
                fontSize: 12,
                color: IndustrialTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, i) {
        final url = AppConfig.publicPhotoUrl(paths[i]);
        return Material(
          color: IndustrialTheme.darkHeader,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showPhotosDialog(
              context,
              title: 'Proof of Staging — SO $so',
              paths: paths,
            ),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: IndustrialTheme.textMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContainerChecklist extends StatelessWidget {
  const _ContainerChecklist({required this.entry});

  final StagingEntry entry;

  @override
  Widget build(BuildContext context) {
    final weight = (entry.weight ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialTheme.darkHeader,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialTheme.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_box_outlined,
                size: 16,
                color: IndustrialTheme.mintGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.qty} × ${entry.type}',
                  style: IndustrialTheme.mono(
                    fontSize: 13,
                    color: IndustrialTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (weight.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Weight: $weight',
              style: IndustrialTheme.mono(
                fontSize: 12,
                color: IndustrialTheme.textMuted,
              ),
            ),
          ],
          if ((entry.stagedBy ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Staged by: ${entry.stagedBy}',
              style: const TextStyle(
                fontSize: 12,
                color: IndustrialTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveAuditTrail extends ConsumerWidget {
  const _LiveAuditTrail({required this.so});

  final String so;

  static final _ts = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ChangelogEntry>>(
      future: ref.read(changelogRepoProvider).forOrder(so),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Text(
            'Could not load audit trail',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final rows = snap.data ?? const <ChangelogEntry>[];
        if (rows.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: IndustrialTheme.darkHeader,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: IndustrialTheme.borderStroke),
            ),
            child: const Text(
              'No changelog entries for this SO yet.',
              style: TextStyle(
                fontSize: 12,
                color: IndustrialTheme.textMuted,
              ),
            ),
          );
        }

        final preview = rows.take(12).toList();
        return Column(
          children: [
            for (final row in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118,
                      child: Text(
                        row.createdAt == null
                            ? '—'
                            : _ts.format(row.createdAt!.toLocal()),
                        style: IndustrialTheme.mono(
                          fontSize: 10,
                          color: IndustrialTheme.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.action,
                        style: IndustrialTheme.mono(
                          fontSize: 11,
                          color: IndustrialTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
