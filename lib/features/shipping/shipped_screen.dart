import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../shared/industrial_widgets.dart';
import '../shared/log_tables.dart';
import '../shared/widgets.dart';
import 'quick_ship_sheet.dart';

class ShippedScreen extends ConsumerStatefulWidget {
  const ShippedScreen({super.key});

  @override
  ConsumerState<ShippedScreen> createState() => _ShippedScreenState();
}

class _ShippedScreenState extends ConsumerState<ShippedScreen> {
  final _search = TextEditingController();
  String _q = '';
  ShippedEntry? _inspect;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final entries = data.shipped.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.carrier} ${e.location} ${e.comments ?? ''} ${e.shippedBy ?? ''} ${e.id}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();

    if (_inspect != null && !data.shipped.any((e) => e.id == _inspect!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _inspect = null);
      });
    }

    final trueShips = data.shipped.where(AppData.isTrueShip).toList();
    final returned = data.shipped
        .where((e) => e.carrier.trim().toUpperCase() == 'RETURNED TO STOCK')
        .length;
    final today = DateTime.now();
    final shippedToday = trueShips.where((e) {
      final at = e.shippedAt;
      if (at == null) return false;
      final local = at.toLocal();
      return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day;
    }).length;
    final units = trueShips.fold<int>(0, (sum, e) => sum + e.qty);

    final scrollBody = RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: slstPagePadding(context),
        children: [
          Text(
            'Shipped Staging Entries Log',
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
                eyebrow: 'Shipment Activity',
                value: '${trueShips.length}',
                unit: 'True Ships',
                stats: [
                  (
                    label: 'Shipped Today',
                    value: '$shippedToday',
                    accent: IndustrialTheme.mintGreen,
                  ),
                  (
                    label: 'Returned',
                    value: '$returned',
                    accent: IndustrialTheme.amber,
                  ),
                  (
                    label: 'All Records',
                    value: '${data.shipped.length}',
                    accent: IndustrialTheme.skyBlue,
                  ),
                ],
              );
              final unitsCard = LogSummaryCard(
                eyebrow: 'Shipped Units',
                value: '$units',
                unit: 'Total Units',
                stats: [
                  (
                    label: 'Matching Search',
                    value: '${entries.length}',
                    accent: null,
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  children: [statusCard, const SizedBox(height: 10), unitsCard],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: statusCard),
                  const SizedBox(width: 12),
                  Expanded(child: unitsCard),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SearchField(
            controller: _search,
            hint: 'Global search — SO, customer, carrier, zone, UUID…',
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 14),
          ShippedLogCard(
            entries: entries,
            expanded: true,
            selectedId: _inspect?.id,
            onInspect: (e) => setState(() => _inspect = e),
            onQuickShip: () => showQuickShipSheet(context, ref),
          ),
          const BrandFooter(),
        ],
      ),
    );

    final content = AsyncPanel(
      loading: data.loading,
      syncing: data.syncing,
      isEmpty: data.shipped.isEmpty,
      error: data.error,
      onRetry: () => ref.read(appDataProvider.notifier).refresh(),
      emptyTitle: 'No shipped entries',
      emptyMessage: 'Completed shipments will appear here.',
      child: scrollBody,
    );

    final compact =
        MediaQuery.sizeOf(context).width <
        IndustrialTheme.tokens.inspectorBreakpoint;

    if (_inspect == null) {
      return ColoredBox(color: IndustrialTheme.darkBase, child: content);
    }

    final inspector = SlideOverInspector(
      title: 'SO ${_inspect!.so}',
      onClose: () => setState(() => _inspect = null),
      body: ShippedInspectorBody(entry: _inspect!),
    );

    if (compact) {
      return ColoredBox(
        color: IndustrialTheme.darkBase,
        child: Stack(
          children: [
            content,
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: inspector,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: IndustrialTheme.darkBase,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: content),
          inspector,
        ],
      ),
    );
  }
}
