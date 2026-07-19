import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../domain/status.dart';
import '../shared/widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final changelog = ref.watch(_changelogProvider);

    final overdue = data.staging.where((e) => StatusRules.isOverdue(e.status)).toList();
    final shipToday = data.staging
        .where((e) => StatusRules.formatUi(e.status) == 'Ship Today')
        .toList();
    final shipTomorrow = data.staging
        .where((e) => StatusRules.formatUi(e.status) == 'Ship Tomorrow')
        .toList();
    final awaiting = data.staging
        .where((e) => e.status.toLowerCase() == 'awaiting instructions')
        .toList();
    final corpPick = data.staging
        .where((e) => e.status.toLowerCase().contains('corp pick'))
        .toList();
    final returned = data.shipped
        .where((e) => e.carrier.toUpperCase() == 'RETURNED TO STOCK')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 150,
              child: StatTile(label: 'Overdue', value: overdue.length),
            ),
            SizedBox(
              width: 150,
              child: StatTile(label: 'Ship Today', value: shipToday.length),
            ),
            SizedBox(
              width: 150,
              child: StatTile(label: 'Tomorrow', value: shipTomorrow.length),
            ),
            SizedBox(
              width: 150,
              child: StatTile(label: 'Corp Pick', value: corpPick.length),
            ),
            SizedBox(
              width: 150,
              child: StatTile(label: 'Awaiting', value: awaiting.length),
            ),
            SizedBox(
              width: 150,
              child: StatTile(label: 'Returned', value: returned.length),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All staging')),
            ButtonSegment(value: 'overdue', label: Text('Overdue')),
            ButtonSegment(value: 'today', label: Text('Today')),
            ButtonSegment(value: 'awaiting', label: Text('Awaiting')),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
        const SizedBox(height: 12),
        ...() {
          final list = switch (_filter) {
            'overdue' => overdue,
            'today' => shipToday,
            'awaiting' => awaiting,
            _ => data.staging,
          };
          return list.map(
            (e) => EntryCard(
              title: 'SO ${e.so}',
              subtitle: e.customer,
              details: [
                '${StatusRules.formatUi(e.status)} · ${e.location}',
                e.type,
              ],
              color: statusColor(e.status),
            ),
          );
        }(),
        const SizedBox(height: 24),
        Text('Changelog', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        changelog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load changelog: $e'),
          data: (rows) => Column(
            children: [
              for (final r in rows.take(50))
                ListTile(
                  dense: true,
                  title: Text(r.action),
                  subtitle: Text(
                    '${r.tableName} · ${r.userEmail}${r.createdAt == null ? '' : ' · ${r.createdAt!.toLocal()}'}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

final _changelogProvider = FutureProvider((ref) async {
  return ref.watch(changelogRepoProvider).recent();
});
