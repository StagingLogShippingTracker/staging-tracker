import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/log_tables.dart';
import '../shared/widgets.dart';
import '../shipping/quick_ship_sheet.dart';
import 'stat_detail_dialog.dart';

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
          '${e.so} ${e.customer} ${e.location} ${e.status} ${e.comments ?? ''}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();

    final shipped = data.shipped.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.carrier} ${e.location} ${e.comments ?? ''}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();

    // detail: which stat-detail window the card opens (legacy web parity);
    // the Shipped card jumps to the Shipped Log instead.
    final kpis = [
      (key: 'orders', label: 'Orders', icon: Icons.description_outlined, detail: StatDetailMode.orders),
      (key: 'containers', label: 'Containers', icon: Icons.widgets_outlined, detail: StatDetailMode.containers),
      (key: 'skids', label: 'Skids', icon: Icons.pallet, detail: StatDetailMode.skid),
      (key: 'boxes', label: 'Boxes', icon: Icons.inventory_2_outlined, detail: StatDetailMode.box),
      (key: 'crates', label: 'Crates', icon: Icons.dataset_outlined, detail: StatDetailMode.crate),
      (key: 'pipe', label: 'Pipe/Rod', icon: Icons.horizontal_rule, detail: StatDetailMode.pipe),
      (key: 'other', label: 'Other', icon: Icons.category_outlined, detail: StatDetailMode.other),
      (key: 'shipped', label: 'Shipped', icon: Icons.local_shipping_outlined, detail: null),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        children: [
          if (data.error != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Data load error'),
                subtitle: Text(data.error!),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(appDataProvider.notifier).refresh(),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // KPI grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1100
                  ? 8
                  : constraints.maxWidth >= 720
                      ? 4
                      : 2;
              const gap = 10.0;
              final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final k in kpis)
                    SizedBox(
                      width: w,
                      child: KpiCard(
                        label: k.label,
                        value: totals[k.key] ?? 0,
                        icon: k.icon,
                        onTap: k.detail == null
                            ? () => context.go('/shipped')
                            : () => showStatDetailDialog(context, k.detail!),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Quick search + quick actions row
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final search = SearchField(
                controller: _search,
                hint: 'Quick search — SO, customer, carrier, location…',
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillButton(
                    label: 'Quick Consolidate',
                    icon: Icons.merge_type,
                    color: SlstColors.purple,
                    onPressed: user == null
                        ? null
                        : () => showQuickConsolidateDialog(context, ref),
                  ),
                  PillButton(
                    label: 'Quick Ship',
                    icon: Icons.flash_on,
                    color: SlstColors.success,
                    onPressed: user == null
                        ? null
                        : () => showQuickShipSheet(context, ref),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 10), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (data.loading && data.staging.isEmpty && data.shipped.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            StagingLogCard(
              entries: staging,
              onExpand: () => context.go('/staging'),
            ),
            const SizedBox(height: 16),
            ShippedLogCard(
              entries: shipped,
              onExpand: () => context.go('/shipped'),
              onQuickShip: () => showQuickShipSheet(context, ref),
            ),
          ],
          const SizedBox(height: 16),
          const ComingSoonCard(
            title: 'Shipment Tracker — Coming Soon',
            text:
                'Live carrier tracking for outbound freight is on the roadmap. '
                'Shipped entries will link directly to carrier tracking status.',
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}
