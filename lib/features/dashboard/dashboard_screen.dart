import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/industrial_widgets.dart';
import '../shared/widgets.dart';
import 'order_inspector.dart';
import 'stat_detail_dialog.dart';
import 'warehouse_floor_map.dart';

enum _StagingBoardColumn {
  shipToday,
  shipTomorrow,
  partial,
  awaiting,
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StagingEntry? _inspect;

  /// Preferred compact KPI card width at the content-column ceiling.
  static const double _kpiPreferredCardWidth = 112;
  static const double _kpiGap = 8;
  static const int _kpiCount = 8;

  /// Single source of truth: KPIs + map + staging share this max width.
  /// `8 × 112 + 7 × 8 = 952`.
  static const double _dashboardContentMaxWidth =
      _kpiCount * _kpiPreferredCardWidth + (_kpiCount - 1) * _kpiGap;

  /// Vertical rhythm between dashboard sections.
  static const double _sectionGap = 18;

  /// Below this content width, staging columns stack instead of 4-across.
  static const double _boardStackBreakpoint = 720;

  _StagingBoardColumn _columnFor(StagingEntry e) {
    final ui = StatusRules.formatUi(e.status);
    if (ui == 'Ship Today' || StatusRules.isOverdue(e.status)) {
      return _StagingBoardColumn.shipToday;
    }
    if (ui == 'Ship Tomorrow') return _StagingBoardColumn.shipTomorrow;
    if (ui == 'Partial') return _StagingBoardColumn.partial;
    return _StagingBoardColumn.awaiting;
  }

  List<StagingEntry> _bucket(
    List<StagingEntry> staging,
    _StagingBoardColumn column,
  ) {
    final list = staging.where((e) => _columnFor(e) == column).toList();
    list.sort(
      (a, b) =>
          StatusRules.urgencyWeight(b.status) -
          StatusRules.urgencyWeight(a.status),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final totals = data.containerTotals;

    final kpis = [
      (
        key: 'orders',
        label: 'Orders',
        subtext: 'Unique SO',
        detail: StatDetailMode.orders,
      ),
      (
        key: 'containers',
        label: 'Containers',
        subtext: 'On floor',
        detail: StatDetailMode.containers,
      ),
      (
        key: 'skids',
        label: 'Skids',
        subtext: 'Active',
        detail: StatDetailMode.skid,
      ),
      (
        key: 'boxes',
        label: 'Boxes',
        subtext: 'Active',
        detail: StatDetailMode.box,
      ),
      (
        key: 'crates',
        label: 'Crates',
        subtext: 'Active',
        detail: StatDetailMode.crate,
      ),
      (
        key: 'pipe',
        label: 'Pipe/Rod',
        subtext: 'Active',
        detail: StatDetailMode.pipe,
      ),
      (
        key: 'other',
        label: 'Other',
        subtext: 'Active',
        detail: StatDetailMode.other,
      ),
      (
        key: 'shipped',
        label: 'Shipped',
        subtext: 'Done',
        detail: null,
      ),
    ];

    final shipToday = _bucket(data.staging, _StagingBoardColumn.shipToday);
    final shipTomorrow =
        _bucket(data.staging, _StagingBoardColumn.shipTomorrow);
    final partial = _bucket(data.staging, _StagingBoardColumn.partial);
    final awaiting = _bucket(data.staging, _StagingBoardColumn.awaiting);

    final scrollBody = RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: ListView(
        padding: slstPagePadding(context),
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
                  onPressed: () =>
                      ref.read(appDataProvider.notifier).refresh(),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Unified content column: KPIs + map + staging share one width.
          LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  constraints.maxWidth < _dashboardContentMaxWidth
                      ? constraints.maxWidth
                      : _dashboardContentMaxWidth;
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section A — KPI strip (evenly fills content width)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < kpis.length; i++) ...[
                              if (i > 0) const SizedBox(width: _kpiGap),
                              Expanded(
                                child: IndustrialKpiCard.compact(
                                  label: kpis[i].label,
                                  value: '${totals[kpis[i].key] ?? 0}',
                                  subtext: kpis[i].subtext,
                                  onTap: kpis[i].detail == null
                                      ? () => context.go('/shipped')
                                      : () => showStatDetailDialog(
                                            context,
                                            kpis[i].detail!,
                                          ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: _sectionGap),
                      // Section B — Floor map (same width; scales with container)
                      WarehouseFloorMap(staging: data.staging),
                      const SizedBox(height: _sectionGap),
                      // Section C — Active Staging (same content bounds)
                      _ActiveStagingBoard(
                        shipToday: shipToday,
                        shipTomorrow: shipTomorrow,
                        partial: partial,
                        awaiting: awaiting,
                        selectedId: _inspect?.id,
                        onSelect: (e) => setState(() => _inspect = e),
                        loading: data.loading && data.staging.isEmpty,
                        stackBreakpoint: _boardStackBreakpoint,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const BrandFooter(),
        ],
      ),
    );

    if (_inspect == null) {
      return ColoredBox(
        color: IndustrialTheme.darkBase,
        child: scrollBody,
      );
    }

    return ColoredBox(
      color: IndustrialTheme.darkBase,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: scrollBody),
          OrderInspector(
            entry: _inspect!,
            onClose: () => setState(() => _inspect = null),
          ),
        ],
      ),
    );
  }
}

class _ActiveStagingBoard extends StatelessWidget {
  const _ActiveStagingBoard({
    required this.shipToday,
    required this.shipTomorrow,
    required this.partial,
    required this.awaiting,
    required this.selectedId,
    required this.onSelect,
    required this.loading,
    this.stackBreakpoint = 720,
  });

  final List<StagingEntry> shipToday;
  final List<StagingEntry> shipTomorrow;
  final List<StagingEntry> partial;
  final List<StagingEntry> awaiting;
  final String? selectedId;
  final ValueChanged<StagingEntry> onSelect;
  final bool loading;
  final double stackBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ACTIVE STAGING',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < stackBreakpoint;
              final columns = [
                _BoardColumn(
                  title: 'SHIP TODAY',
                  accent: IndustrialTheme.mintGreen,
                  entries: shipToday,
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _BoardColumn(
                  title: 'SHIP TOMORROW',
                  accent: IndustrialTheme.skyBlue,
                  entries: shipTomorrow,
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _BoardColumn(
                  title: 'PARTIAL STAGED',
                  accent: IndustrialTheme.amber,
                  entries: partial,
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
                _BoardColumn(
                  title: 'AWAITING SHIPPING INSTRUCTIONS',
                  accent: IndustrialTheme.purple,
                  entries: awaiting,
                  selectedId: selectedId,
                  onSelect: onSelect,
                ),
              ];

              if (narrow) {
                return Column(
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      columns[i],
                    ],
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: columns[i]),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.title,
    required this.accent,
    required this.entries,
    required this.selectedId,
    required this.onSelect,
  });

  final String title;
  final Color accent;
  final List<StagingEntry> entries;
  final String? selectedId;
  final ValueChanged<StagingEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IndustrialTheme.darkHeader,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialTheme.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: accent,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entries.length}',
                  style: IndustrialTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No orders',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.textMuted,
                ),
              ),
            )
          else
            for (final e in entries) ...[
              _StagingSoCard(
                entry: e,
                selected: e.id == selectedId,
                onTap: () => onSelect(e),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StagingSoCard extends StatelessWidget {
  const _StagingSoCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final StagingEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = StatusRules.formatUi(entry.status) == 'Ship Today' ||
        StatusRules.isOverdue(entry.status);
    final weight = (entry.weight ?? '').trim();
    final stager = (entry.stagedBy ?? '').trim();

    return Material(
      color: selected
          ? IndustrialTheme.skyBlue.withValues(alpha: 0.12)
          : IndustrialTheme.darkSurface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? IndustrialTheme.skyBlue.withValues(alpha: 0.55)
                  : IndustrialTheme.borderStroke,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.so,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IndustrialTheme.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: IndustrialTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (urgent)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.customer.isEmpty ? '—' : entry.customer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (entry.location.trim().isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: IndustrialTheme.darkHeader,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: IndustrialTheme.borderStroke),
                  ),
                  child: Text(
                    entry.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IndustrialTheme.mono(
                      fontSize: 10,
                      color: IndustrialTheme.skyBlue,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                [
                  if (weight.isNotEmpty) weight,
                  '${entry.qty} ${entry.type}',
                  if (stager.isNotEmpty) stager,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: IndustrialTheme.mono(
                  fontSize: 10,
                  color: IndustrialTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
