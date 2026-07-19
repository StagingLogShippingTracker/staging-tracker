import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final kpiColumns = width >= 840 ? 3 : 2;
    final dateFmt = DateFormat('MMM d · h:mm a');

    final overdue =
        data.staging.where((e) => StatusRules.isOverdue(e.status)).toList();
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

    final kpis = <(String, int, IconData, Color)>[
      ('Overdue', overdue.length, Icons.warning_amber_rounded,
          const Color(0xFF991B1B)),
      ('Ship Today', shipToday.length, Icons.local_shipping, SlstColors.brand),
      ('Tomorrow', shipTomorrow.length, Icons.wb_twilight,
          const Color(0xFFA16207)),
      ('Corp Pick', corpPick.length, Icons.store_mall_directory,
          const Color(0xFF047857)),
      ('Awaiting', awaiting.length, Icons.hourglass_empty,
          const Color(0xFF475569)),
      ('Returned', returned.length, Icons.keyboard_return, SlstColors.purple),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(appDataProvider.notifier).refresh();
        ref.invalidate(_changelogProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: kpiColumns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: kpiColumns == 2 ? 2.6 : 3.0,
            children: [
              for (final k in kpis)
                KpiTile(label: k.$1, value: k.$2, icon: k.$3, accent: k.$4),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'overdue', label: Text('Overdue')),
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(value: 'awaiting', label: Text('Awaiting')),
            ],
            selected: {_filter},
            showSelectedIcon: false,
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
            if (list.isEmpty) {
              return [
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline,
                        color: SlstColors.green),
                    title: Text('Nothing to report here.'),
                  ),
                ),
              ];
            }
            return list
                .map(
                  (e) => EntryCard(
                    title: 'SO ${e.so}',
                    subtitle: e.customer,
                    details: ['${e.location} · ${e.type} · qty ${e.qty}'],
                    dbStatus: e.status,
                  ),
                )
                .toList();
          }(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Changelog', icon: Icons.history),
          const SizedBox(height: 4),
          changelog.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              color: scheme.errorContainer,
              child: ListTile(title: Text('Failed to load changelog: $e')),
            ),
            data: (rows) => Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, r) in rows.take(50).indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 52),
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: SlstColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          r.tableName == 'shipped'
                              ? Icons.local_shipping
                              : Icons.inventory_2,
                          size: 16,
                          color: SlstColors.blue,
                        ),
                      ),
                      title: Text(r.action),
                      subtitle: Text(
                        '${r.userEmail}${r.createdAt == null ? '' : ' · ${dateFmt.format(r.createdAt!.toLocal())}'}',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const BrandFooter(),
        ],
      ),
    );
  }
}

final _changelogProvider = FutureProvider((ref) async {
  return ref.watch(changelogRepoProvider).recent();
});
