import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
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
  StagingEntry? _inspect;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openInspector(StagingEntry entry) {
    setState(() => _inspect = entry);
    if (!useInspectorPopup(context)) return;

    final size = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 20,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            width: double.infinity,
            height: size.height * 0.88,
            child: SlideOverInspector(
              title: 'SO ${entry.so}',
              asPopup: true,
              width: size.width,
              onClose: () => Navigator.of(dialogContext).pop(),
              body: StagingInspectorBody(
                entry: entry,
                onClose: () {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted && _inspect?.id == entry.id) {
        setState(() => _inspect = null);
      }
    });
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

    // Drop selection if the entry left staging.
    if (_inspect != null && !data.staging.any((e) => e.id == _inspect!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _inspect = null);
      });
    }

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

    final scrollBody = RefreshIndicator(
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
                  children: [statusCard, const SizedBox(height: 10), floorCard],
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
          StagingLogCard(
            entries: entries,
            expanded: true,
            selectedId: _inspect?.id,
            onInspect: _openInspector,
          ),
          const BrandFooter(),
        ],
      ),
    );

    final content = AsyncPanel(
      loading: data.loading,
      syncing: data.syncing,
      isEmpty: data.staging.isEmpty,
      error: data.error,
      onRetry: () => ref.read(appDataProvider.notifier).refresh(),
      emptyTitle: 'No active staging entries',
      emptyMessage: ref.watch(currentUserProvider) == null
          ? 'Sign in to view live staging inventory.'
          : 'New staging work will appear here when it is created.',
      child: scrollBody,
    );

    final popup = useInspectorPopup(context);
    final compact =
        MediaQuery.sizeOf(context).width <
        IndustrialTheme.tokens.inspectorBreakpoint;

    // Portrait mobile uses a dialog popup; keep side panel / overlay otherwise.
    if (_inspect == null || popup) {
      return ColoredBox(color: IndustrialTheme.darkBase, child: content);
    }

    final inspector = SlideOverInspector(
      title: 'SO ${_inspect!.so}',
      onClose: () => setState(() => _inspect = null),
      body: StagingInspectorBody(
        entry: _inspect!,
        onClose: () => setState(() => _inspect = null),
      ),
    );

    // Host at screen level (bounded height) — never inside the ListView card.
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
