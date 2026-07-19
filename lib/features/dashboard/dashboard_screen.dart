import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../domain/status.dart';
import '../shared/widgets.dart';
import '../staging/staging_form_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final user = ref.watch(currentUserProvider);
    final totals = data.containerTotals;
    final staging = data.staging.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.location} ${e.status}'.toLowerCase();
      return hay.contains(_q);
    }).toList()
      ..sort((a, b) {
        final u = StatusRules.urgencyWeight(b.status) -
            StatusRules.urgencyWeight(a.status);
        if (u != 0) return u;
        return (b.entryDate ?? DateTime(1970))
            .compareTo(a.entryDate ?? DateTime(1970));
      });

    final shipped = data.shipped.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.carrier} ${e.location}'.toLowerCase();
      return hay.contains(_q);
    }).take(20).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (data.error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                title: const Text('Data load error'),
                subtitle: Text(data.error!),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(appDataProvider.notifier).refresh(),
                ),
              ),
            ),
          SearchField(
            controller: _search,
            hint: 'Search SO, customer, location…',
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in [
                ('Orders', totals['orders']!),
                ('Staging', totals['staging']!),
                ('Skids', totals['skids']!),
                ('Boxes', totals['boxes']!),
                ('Crates', totals['crates']!),
                ('Pipe', totals['pipe']!),
                ('Other', totals['other']!),
                ('Shipped', totals['shipped']!),
              ])
                SizedBox(
                  width: 140,
                  child: StatTile(label: e.$1, value: e.$2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Staging Entries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (user != null)
                FilledButton.icon(
                  onPressed: () => showStagingFormSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New Entry'),
                ),
              TextButton(
                onPressed: () => context.go('/staging'),
                child: const Text('View all'),
              ),
            ],
          ),
          if (data.loading && staging.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ...staging.take(25).map(
              (e) => EntryCard(
                title: 'SO ${e.so}',
                subtitle: e.customer,
                details: [
                  '${StatusRules.formatUi(e.status)} · ${e.location}',
                  '${e.type} · qty ${e.qty}',
                ],
                color: statusColor(e.status),
                onTap: () => context.go('/staging'),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Shipped',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/shipped'),
                child: const Text('View all'),
              ),
            ],
          ),
          ...shipped.map(
            (e) => EntryCard(
              title: 'SO ${e.so}',
              subtitle: e.customer,
              details: [
                '${e.carrier} · ${e.location}',
                '${e.type} · qty ${e.qty}',
              ],
              onTap: () => context.go('/shipped'),
            ),
          ),
        ],
      ),
    );
  }
}
