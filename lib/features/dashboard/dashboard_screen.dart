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
  future,
  corpPick,
  customerPick,
  awaiting,
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StagingEntry? _inspect;
  final _search = TextEditingController();
  String _q = '';
  bool _overduePromptRunning = false;
  final _overduePromptedIds = <String>{};
  bool _showAllCompactKpis = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowOverduePrompts();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesQuickSearch(StagingEntry e) {
    if (_q.isEmpty) return true;
    final ui = StatusRules.formatUi(e.status);
    final hay = '${e.so} ${e.customer} ${e.location} ${e.status} $ui'
        .toLowerCase();
    return hay.contains(_q);
  }

  Future<void> _maybeShowOverduePrompts() async {
    if (!mounted || _overduePromptRunning) return;
    final data = ref.read(appDataProvider);
    if (data.loading) return;

    final prefs = await ref.read(prefsProvider.future);
    if (!mounted) return;
    final handled = prefs.overdueHandled;
    final overdue =
        data.staging
            .where(
              (e) =>
                  StatusRules.isOverdue(e.status) &&
                  !handled.contains(e.id) &&
                  !_overduePromptedIds.contains(e.id),
            )
            .toList()
          ..sort((a, b) => a.status.compareTo(b.status));
    if (overdue.isEmpty) return;

    _overduePromptRunning = true;
    try {
      for (final entry in overdue) {
        if (!mounted) break;
        _overduePromptedIds.add(entry.id);
        final open = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: IndustrialTheme.darkSurface,
            title: Text(
              'Overdue staging entry',
              style: IndustrialTheme.mono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: IndustrialTheme.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SO ${entry.so}',
                  style: IndustrialTheme.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: IndustrialTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.customer,
                  style: const TextStyle(color: IndustrialTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Location: ${entry.location.isEmpty ? '—' : entry.location}',
                  style: const TextStyle(color: IndustrialTheme.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ship date: ${entry.status}',
                  style: IndustrialTheme.mono(
                    fontSize: 12,
                    color: IndustrialTheme.amber,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This entry is past its ship window.',
                  style: TextStyle(
                    fontSize: 12,
                    color: IndustrialTheme.textMuted,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: TextButton.styleFrom(
                  foregroundColor: IndustrialTheme.textMuted,
                ),
                child: const Text('Dismiss'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: IndustrialTheme.skyBlue,
                  foregroundColor: IndustrialTheme.textPrimary,
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        );
        await prefs.markOverdueHandled(entry.id);
        if (!mounted) break;
        if (open == true) {
          _openInspector(entry);
          break;
        }
      }
    } finally {
      _overduePromptRunning = false;
    }
  }

  _StagingBoardColumn _columnFor(StagingEntry e) {
    final ui = StatusRules.formatUi(e.status);
    if (ui == 'Ship Today' || StatusRules.isOverdue(e.status)) {
      return _StagingBoardColumn.shipToday;
    }
    if (ui == 'Ship Tomorrow') return _StagingBoardColumn.shipTomorrow;
    if (ui == 'Partial') return _StagingBoardColumn.partial;
    if (ui == 'Corp Pick' || ui.toLowerCase().contains('corp pick')) {
      return _StagingBoardColumn.corpPick;
    }
    if (ui == 'Customer Pick-Up' ||
        ui.toLowerCase().contains('customer pick')) {
      return _StagingBoardColumn.customerPick;
    }
    if (ui == 'Awaiting Instructions' ||
        StatusRules.isAwaitingInstructions(e.status)) {
      return _StagingBoardColumn.awaiting;
    }
    // Future YMD dates, TBD, Ship On Future Date → Future column.
    if (ui == 'Ship On Future Date' ||
        ui == 'TBD' ||
        StatusRules.isYmd(e.status)) {
      return _StagingBoardColumn.future;
    }
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

  void _openInspector(StagingEntry entry) {
    final compact =
        MediaQuery.sizeOf(context).width <
        IndustrialTheme.tokens.inspectorBreakpoint;
    setState(() => _inspect = entry);
    if (!compact) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: OrderInspector(
            entry: entry,
            width: double.infinity,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted && _inspect?.id == entry.id) {
        setState(() => _inspect = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    ref.listen<AppData>(appDataProvider, (prev, next) {
      if (prev?.loading == true && !next.loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowOverduePrompts();
        });
      }
    });
    final totals = data.containerTotals;
    final filteredStaging = data.staging.where(_matchesQuickSearch).toList();

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
      (key: 'shipped', label: 'Shipped', subtext: 'Done', detail: null),
    ];

    final shipToday = _bucket(filteredStaging, _StagingBoardColumn.shipToday);
    final shipTomorrow = _bucket(
      filteredStaging,
      _StagingBoardColumn.shipTomorrow,
    );
    final partial = _bucket(filteredStaging, _StagingBoardColumn.partial);
    final future = _bucket(filteredStaging, _StagingBoardColumn.future);
    final corpPick = _bucket(filteredStaging, _StagingBoardColumn.corpPick);
    final customerPick = _bucket(
      filteredStaging,
      _StagingBoardColumn.customerPick,
    );
    final awaiting = _bucket(filteredStaging, _StagingBoardColumn.awaiting);

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
                  onPressed: () => ref.read(appDataProvider.notifier).refresh(),
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
                      // Section A — KPI strip. On narrow widths, scroll
                      // horizontally with a minimum card width so labels
                      // (Orders, Skids, …) stay readable instead of "O…".
                      Builder(
                        builder: (context) {
                          final minCell = _kpiPreferredCardWidth;
                          final needed =
                              kpis.length * minCell +
                              (kpis.length - 1) * _kpiGap;
                          final scroll = contentWidth < needed;
                          final phone = contentWidth < _boardStackBreakpoint;

                          Widget cardAt(int i) => IndustrialKpiCard.compact(
                            label: kpis[i].label,
                            value: '${totals[kpis[i].key] ?? 0}',
                            subtext: kpis[i].subtext,
                            onTap: kpis[i].detail == null
                                ? () => context.go('/shipped')
                                : () => showStatDetailDialog(
                                    context,
                                    kpis[i].detail!,
                                  ),
                          );

                          if (phone) {
                            final visible = _showAllCompactKpis
                                ? kpis
                                : kpis.take(4).toList();
                            return Column(
                              children: [
                                GridView.count(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.55,
                                  mainAxisSpacing: _kpiGap,
                                  crossAxisSpacing: _kpiGap,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    for (var i = 0; i < visible.length; i++)
                                      cardAt(kpis.indexOf(visible[i])),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showAllCompactKpis =
                                        !_showAllCompactKpis,
                                  ),
                                  icon: Icon(
                                    _showAllCompactKpis
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _showAllCompactKpis
                                        ? 'Show priority KPIs'
                                        : 'Show all KPIs',
                                  ),
                                ),
                              ],
                            );
                          }

                          if (!scroll) {
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < kpis.length; i++) ...[
                                    if (i > 0) const SizedBox(width: _kpiGap),
                                    Expanded(child: cardAt(i)),
                                  ],
                                ],
                              ),
                            );
                          }

                          // Tall enough for 2-line labels + value + subtext.
                          return SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: kpis.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: _kpiGap),
                              itemBuilder: (context, i) =>
                                  SizedBox(width: minCell, child: cardAt(i)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: _sectionGap),
                      // Section B — Floor map (same width; scales with container)
                      RepaintBoundary(
                        child: NotificationListener<ScrollNotification>(
                          // Keep horizontal map pans from fighting the page
                          // ListView / RefreshIndicator after occupancy paints.
                          onNotification: (n) =>
                              n.metrics.axis == Axis.horizontal,
                          child: WarehouseFloorMap(staging: data.staging),
                        ),
                      ),
                      const SizedBox(height: _sectionGap),
                      SearchField(
                        controller: _search,
                        hint: 'Quick Search — SO, customer, location, status…',
                        onChanged: (v) =>
                            setState(() => _q = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      // Section C — Active Staging (same content bounds)
                      _ActiveStagingBoard(
                        shipToday: shipToday,
                        shipTomorrow: shipTomorrow,
                        partial: partial,
                        future: future,
                        corpPick: corpPick,
                        customerPick: customerPick,
                        awaiting: awaiting,
                        selectedId: _inspect?.id,
                        onSelect: _openInspector,
                        loading: data.loading && data.staging.isEmpty,
                        stackBreakpoint: _boardStackBreakpoint,
                        filterActive: _q.isNotEmpty,
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

    final compact =
        MediaQuery.sizeOf(context).width <
        IndustrialTheme.tokens.inspectorBreakpoint;

    if (_inspect == null) {
      return ColoredBox(color: IndustrialTheme.darkBase, child: scrollBody);
    }

    // Compact layouts present the inspector as a modal sheet from [_openInspector].
    // Desktop keeps a persistent 400px side panel beside the board.
    if (compact) {
      return ColoredBox(color: IndustrialTheme.darkBase, child: scrollBody);
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
    required this.future,
    required this.corpPick,
    required this.customerPick,
    required this.awaiting,
    required this.selectedId,
    required this.onSelect,
    required this.loading,
    this.stackBreakpoint = 720,
    this.filterActive = false,
  });

  final List<StagingEntry> shipToday;
  final List<StagingEntry> shipTomorrow;
  final List<StagingEntry> partial;
  final List<StagingEntry> future;
  final List<StagingEntry> corpPick;
  final List<StagingEntry> customerPick;
  final List<StagingEntry> awaiting;
  final String? selectedId;
  final ValueChanged<StagingEntry> onSelect;
  final bool loading;
  final double stackBreakpoint;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final totalVisible =
        shipToday.length +
        shipTomorrow.length +
        partial.length +
        future.length +
        corpPick.length +
        customerPick.length +
        awaiting.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ACTIVE STAGING',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (filterActive)
              Text(
                '$totalVisible match${totalVisible == 1 ? '' : 'es'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: IndustrialTheme.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Builder(
            builder: (context) {
              // Always a fixed-height horizontal kanban (matches Windows).
              // Stacking inside the page ListView previously used Expanded
              // with unbounded height → blank Active Staging on Android and
              // layout thrash that broke floor-map pan/tap after data load.
              final phone = MediaQuery.sizeOf(context).width < stackBreakpoint;
              final columns =
                  <({String title, Color accent, List<StagingEntry> entries})>[
                    (
                      title: 'SHIP TODAY',
                      accent: IndustrialTheme.mintGreen,
                      entries: shipToday,
                    ),
                    (
                      title: 'SHIP TOMORROW',
                      accent: IndustrialTheme.skyBlue,
                      entries: shipTomorrow,
                    ),
                    (
                      title: 'PARTIAL STAGED',
                      accent: IndustrialTheme.amber,
                      entries: partial,
                    ),
                    (
                      title: 'FUTURE',
                      accent: const Color(0xFF8B5CF6),
                      entries: future,
                    ),
                    (
                      title: 'CORP PICK',
                      accent: IndustrialTheme.purple,
                      entries: corpPick,
                    ),
                    (
                      title: 'CUSTOMER PICK-UP',
                      accent: IndustrialTheme.purple,
                      entries: customerPick,
                    ),
                    (
                      title: 'AWAITING INSTRUCTIONS',
                      accent: IndustrialTheme.slateMuted,
                      entries: awaiting,
                    ),
                  ];

              return SizedBox(
                height: phone ? 360 : 420,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  itemCount: columns.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => SizedBox(
                    width: phone ? 188 : 210,
                    child: _BoardColumn(
                      title: columns[i].title,
                      accent: columns[i].accent,
                      entries: columns[i].entries,
                      selectedId: selectedId,
                      onSelect: onSelect,
                    ),
                  ),
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                primary: false,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _StagingSoCard(
                      entry: entries[i],
                      selected: entries[i].id == selectedId,
                      onTap: () => onSelect(entries[i]),
                    ),
                  ],
                ],
              ),
            ),
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
    final ui = StatusRules.formatUi(entry.status);
    final overdue = StatusRules.isOverdue(entry.status);
    final statusLabel = overdue
        ? 'Overdue'
        : (StatusRules.isYmd(entry.status) && ui == entry.status
              ? 'Future: ${entry.status}'
              : ui);
    final accent = industrialStatusAccent(statusLabel);
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(6),
                    ),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: IndustrialTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IndustrialStatusBadge(status: statusLabel),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.customer.isEmpty ? '—' : entry.customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: IndustrialTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IndustrialZonePill(entry.location),
                          if (weight.isNotEmpty) IndustrialWeightPill(weight),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
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
            ],
          ),
        ),
      ),
    );
  }
}
