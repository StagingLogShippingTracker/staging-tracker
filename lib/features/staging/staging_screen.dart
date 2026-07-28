import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/status.dart';
import '../shared/industrial_widgets.dart';
import '../shared/log_tables.dart';
import '../shared/widgets.dart';

class StagingScreen extends ConsumerStatefulWidget {
  const StagingScreen({super.key});

  @override
  ConsumerState<StagingScreen> createState() => _StagingScreenState();
}

class _StagingScreenState extends ConsumerState<StagingScreen> {
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
    final entries = data.staging.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.location} ${e.status} ${e.comments ?? ''} ${e.stagedBy ?? ''} ${e.id}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();

    final totals = data.containerTotals;
    var shipToday = 0;
    var partial = 0;
    var awaiting = 0;
    for (final e in data.staging) {
      final ui = StatusRules.formatUi(e.status);
      if (ui == 'Ship Today' || StatusRules.isOverdue(e.status)) {
        shipToday++;
      } else if (ui == 'Partial') {
        partial++;
      } else if (StatusRules.isAwaitingInstructions(e.status)) {
        awaiting++;
      }
    }

    return ColoredBox(
      color: IndustrialTheme.darkBase,
      child: RefreshIndicator(
        onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: slstPagePadding(context),
          children: [
            Text(
              'Active Staging Entries Log',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: IndustrialTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 720;
                final statusCard = LogSummaryCard(
                  eyebrow: 'Live Staging Status',
                  value: '${data.staging.length}',
                  unit: 'Active Jobs',
                  stats: [
                    (
                      label: 'Ship Today',
                      value: '$shipToday',
                      accent: IndustrialTheme.mintGreen,
                    ),
                    (
                      label: 'Partial',
                      value: '$partial',
                      accent: IndustrialTheme.amber,
                    ),
                    (
                      label: 'Awaiting',
                      value: '$awaiting',
                      accent: IndustrialTheme.purple,
                    ),
                  ],
                );
                final floorCard = LogSummaryCard(
                  eyebrow: 'Current Floor Units',
                  value: '${totals['containers'] ?? 0}',
                  unit: 'Total Units',
                  stats: [
                    (
                      label: 'Skids',
                      value: '${totals['skids'] ?? 0}',
                      accent: null,
                    ),
                    (
                      label: 'Boxes',
                      value: '${totals['boxes'] ?? 0}',
                      accent: null,
                    ),
                    (
                      label: 'Crates',
                      value: '${totals['crates'] ?? 0}',
                      accent: null,
                    ),
                    (
                      label: 'Pipe/Rod',
                      value: '${totals['pipe'] ?? 0}',
                      accent: null,
                    ),
                  ],
                );
                if (stacked) {
                  return Column(
                    children: [
                      statusCard,
                      const SizedBox(height: 10),
                      floorCard,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: statusCard),
                    const SizedBox(width: 12),
                    Expanded(child: floorCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SearchField(
              controller: _search,
              hint: 'Global search — SO, customer, zone, status, UUID…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 14),
            if (data.loading && data.staging.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              StagingLogCard(entries: entries, expanded: true),
            const BrandFooter(),
          ],
        ),
      ),
    );
  }
}
