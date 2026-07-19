import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/widgets.dart';
import 'ship_dialog.dart';
import 'split_dialog.dart';
import 'staging_form_sheet.dart';

class StagingScreen extends ConsumerStatefulWidget {
  const StagingScreen({super.key});

  @override
  ConsumerState<StagingScreen> createState() => _StagingScreenState();
}

class _StagingScreenState extends ConsumerState<StagingScreen> {
  final _search = TextEditingController();
  String _q = '';
  String _statusFilter = 'all';
  final _selected = <String>{};

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('today', 'Ship Today'),
    ('tomorrow', 'Tomorrow'),
    ('partial', 'Partial'),
    ('future', 'Future'),
    ('pick', 'Pick-Up'),
    ('awaiting', 'Awaiting'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesFilter(StagingEntry e) {
    if (_statusFilter == 'all') return true;
    final ui = StatusRules.formatUi(e.status).toLowerCase();
    return switch (_statusFilter) {
      'today' => ui == 'ship today' || StatusRules.isOverdue(e.status),
      'tomorrow' => ui == 'ship tomorrow',
      'partial' => ui == 'partial',
      'future' => StatusRules.isYmd(e.status) &&
          ui != 'ship today' &&
          ui != 'ship tomorrow',
      'pick' => ui.contains('pick'),
      'awaiting' => ui.contains('awaiting'),
      _ => true,
    };
  }

  List<StagingEntry> _filtered(List<StagingEntry> all) {
    final list = all.where((e) {
      if (!_matchesFilter(e)) return false;
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.location} ${e.status} ${e.comments ?? ''}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList()
      ..sort((a, b) {
        final u = StatusRules.urgencyWeight(b.status) -
            StatusRules.urgencyWeight(a.status);
        if (u != 0) return u;
        return (b.entryDate ?? DateTime(1970))
            .compareTo(a.entryDate ?? DateTime(1970));
      });
    return list;
  }

  Future<void> _consolidateSelected(List<StagingEntry> entries) async {
    final picked = entries.where((e) => _selected.contains(e.id)).toList();
    try {
      await ref.read(operationsProvider).consolidateStaging(picked);
      setState(() => _selected.clear());
      if (mounted) showOk(context, 'Consolidated');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _batchDelete(List<StagingEntry> entries) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text('Delete ${_selected.length} staging entries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ops = ref.read(operationsProvider);
    try {
      for (final e in entries.where((e) => _selected.contains(e.id))) {
        await ops.deleteRecord(table: 'staging', id: e.id, so: e.so);
      }
      setState(() => _selected.clear());
      if (mounted) showOk(context, 'Deleted');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteOne(StagingEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('SO ${e.so} — ${e.customer}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(operationsProvider)
          .deleteRecord(table: 'staging', id: e.id, so: e.so);
      if (mounted) showOk(context, 'Deleted');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  Widget _selectionBar(List<StagingEntry> entries) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Clear selection',
                onPressed: () => setState(() => _selected.clear()),
                icon: const Icon(Icons.close),
              ),
              Text(
                '${_selected.length} selected',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SlstColors.purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: _selected.length >= 2
                    ? () => _consolidateSelected(entries)
                    : null,
                icon: const Icon(Icons.merge_type, size: 18),
                label: const Text('Consolidate'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Delete selected',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                ),
                onPressed: () => _batchDelete(entries),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryTile(StagingEntry e, {required bool canEdit}) {
    final scheme = Theme.of(context).colorScheme;
    final style = statusStyleOf(context, e.status);
    final selected = _selected.contains(e.id);

    void toggle() {
      setState(() {
        if (selected) {
          _selected.remove(e.id);
        } else {
          _selected.add(e.id);
        }
      });
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? SlstColors.purple : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 5, color: style.accent),
          Expanded(
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                childrenPadding: EdgeInsets.zero,
                leading: canEdit
                    ? GestureDetector(
                        onLongPress: toggle,
                        child: Checkbox(
                          value: selected,
                          onChanged: (_) => toggle(),
                        ),
                      )
                    : null,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SO ${e.so}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 16),
                      ),
                    ),
                    StatusChip(dbStatus: e.status, compact: true),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${e.location} · ${e.type} · qty ${e.qty}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ((e.weight ?? '').isNotEmpty)
                          Text('Weight: ${e.weight}'),
                        if ((e.stagedBy ?? '').isNotEmpty)
                          Text('Staged by: ${e.stagedBy}'),
                        if ((e.comments ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(e.comments!),
                          ),
                        const SizedBox(height: 8),
                        PhotoThumbRow(paths: e.photoUrls),
                        if (canEdit) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: SlstColors.green,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    showShipDialog(context, ref, entry: e),
                                icon: const Icon(Icons.local_shipping,
                                    size: 18),
                                label: const Text('Ship'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => showStagingFormSheet(
                                  context,
                                  ref,
                                  existing: e,
                                ),
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                label: const Text('Edit'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    showReturnDialog(context, ref, entry: e),
                                icon: const Icon(Icons.keyboard_return,
                                    size: 18),
                                label: const Text('Return'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SlstColors.purple,
                                ),
                                onPressed: () =>
                                    showSplitDialog(context, ref, entry: e),
                                icon: const Icon(Icons.call_split, size: 18),
                                label: const Text('Split'),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.error,
                                ),
                                onPressed: () => _deleteOne(e),
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final user = ref.watch(currentUserProvider);
    final entries = _filtered(data.staging);
    final selectionMode = _selected.isNotEmpty && user != null;

    return Scaffold(
      floatingActionButton: (user == null || selectionMode)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showStagingFormSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New Entry'),
            ),
      bottomNavigationBar: selectionMode ? _selectionBar(entries) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SearchField(
              controller: _search,
              hint: 'Filter staging…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: _statusFilter == f.$1,
                      showCheckmark: false,
                      selectedColor: SlstColors.brandSoft,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: _statusFilter == f.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _statusFilter == f.$1
                            ? SlstColors.brandDark
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (_) =>
                          setState(() => _statusFilter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
          if (data.loading && entries.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (entries.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text('No staging entries match.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: entries.length,
                  itemBuilder: (context, i) =>
                      _entryTile(entries[i], canEdit: user != null),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
