import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/status.dart';
import '../shared/widgets.dart';
import '../shipping/quick_ship_sheet.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final kpiColumns = width >= 840 ? 4 : 2;

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
    }).take(10).toList();

    final kpis = <(String, int, IconData, Color)>[
      ('Orders', totals['orders']!, Icons.receipt_long, SlstColors.brand),
      ('Staging', totals['staging']!, Icons.inventory_2, SlstColors.blue),
      ('Skids', totals['skids']!, Icons.pallet, SlstColors.purple),
      ('Boxes', totals['boxes']!, Icons.archive, const Color(0xFFC2410C)),
      ('Crates', totals['crates']!, Icons.all_inbox, const Color(0xFFA16207)),
      ('Pipe/Rod', totals['pipe']!, Icons.horizontal_rule, SlstColors.muted),
      ('Other', totals['other']!, Icons.category, const Color(0xFF475569)),
      ('Shipped', totals['shipped']!, Icons.local_shipping, SlstColors.green),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (data.error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.cloud_off,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: const Text('Data load error'),
                subtitle: Text(data.error!),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(appDataProvider.notifier).refresh(),
                ),
              ),
            ),
          SearchField(
            controller: _search,
            hint: 'Search SO, customer, location…',
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
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
          // Quick actions carried over from the legacy web toolbar.
          Row(
            children: [
              if (user != null) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showStagingFormSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('New Entry'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SlstColors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => showQuickShipSheet(context, ref),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Quick Ship'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SlstColors.purple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.go('/staging'),
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Batch'),
                  ),
                ),
              ] else
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Read-only mode'),
                      subtitle:
                          const Text('Sign in to stage, ship, and notify'),
                      trailing: FilledButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('Sign In'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const StatusLegend(),
          const SizedBox(height: 8),
          SectionHeader(
            title: 'Staging Entries',
            icon: Icons.inventory_2,
            actions: [
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
          else if (staging.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline,
                    color: SlstColors.green),
                title: Text('Nothing in staging'),
                subtitle: Text('New entries will appear here.'),
              ),
            )
          else
            ...staging.take(15).map(
                  (e) => EntryCard(
                    title: 'SO ${e.so}',
                    subtitle: e.customer,
                    details: [
                      '${e.location} · ${e.type} · qty ${e.qty}',
                    ],
                    dbStatus: e.status,
                    onTap: () => context.go('/staging'),
                  ),
                ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Recent Shipped',
            icon: Icons.local_shipping,
            actions: [
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
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.travel_explore,
                color: SlstColors.blueBright,
              ),
              title: const Text('Shipment tracker'),
              subtitle: const Text(
                'Live carrier tracking is coming soon.',
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SlstColors.blueBright.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'SOON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SlstColors.blue,
                  ),
                ),
              ),
            ),
          ),
          const BrandFooter(),
        ],
      ),
    );
  }
}
