import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../staging/ship_dialog.dart';
import '../staging/split_dialog.dart';
import '../staging/staging_form_sheet.dart';
import 'order_history_dialog.dart';
import 'so_advisories.dart';
import 'widgets.dart';

final _dateFmt = DateFormat('M/d/yy h:mm a');

String _fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d.toLocal());

Widget _clipText(String text, {double maxWidth = 220, FontWeight? weight}) {
  final value = text.isEmpty ? '—' : text;
  return Tooltip(
    message: value,
    waitDuration: const Duration(milliseconds: 500),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: weight == null ? null : TextStyle(fontWeight: weight),
      ),
    ),
  );
}

Widget _photosButton(BuildContext context, String so, List<String> paths) {
  if (paths.isEmpty) {
    return const Text('—');
  }
  return TextButton.icon(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 32),
      foregroundColor: SlstColors.info,
    ),
    onPressed: () =>
        showPhotosDialog(context, title: 'Photos — SO $so', paths: paths),
    icon: const Icon(Icons.photo_library_outlined, size: 16),
    label: Text('${paths.length}'),
  );
}

Widget _soHistoryLink(
  BuildContext context,
  WidgetRef ref,
  String so, {
  double maxWidth = 110,
}) {
  return Tooltip(
    message: 'Open Order History for SO $so',
    child: TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: SlstColors.brand,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
      onPressed: () => showOrderHistoryDialog(context, ref, so: so),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          so.isEmpty ? '—' : so,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

Widget _editButton(VoidCallback onPressed) {
  return OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: SlstColors.brand,
      side: const BorderSide(color: SlstColors.brand),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 32),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    onPressed: onPressed,
    child: const Text('Edit'),
  );
}

// ---------------------------------------------------------------------------
// Changelog dialog
// ---------------------------------------------------------------------------

Future<void> showChangelogDialog(
  BuildContext context,
  WidgetRef ref, {
  String? table,
}) {
  final future = ref.read(changelogRepoProvider).recent();
  return showDialog<void>(
    context: context,
    builder: (context) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        table == null
                            ? 'Changelog'
                            : '${table == 'staging' ? 'Staging' : 'Shipped'} Changelog',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: FutureBuilder<List<ChangelogEntry>>(
                    future: future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Failed to load changelog: ${snap.error}',
                          ),
                        );
                      }
                      final rows = (snap.data ?? const <ChangelogEntry>[])
                          .where((r) => table == null || r.tableName == table)
                          .toList();
                      if (rows.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No changelog entries yet.'),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: r.tableName == 'shipped'
                                        ? SlstColors.success.withValues(
                                            alpha: 0.14,
                                          )
                                        : SlstColors.brandSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    r.tableName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: r.tableName == 'shipped'
                                          ? SlstColors.success
                                          : SlstColors.brand,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.action,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${r.userEmail.isEmpty ? 'system' : r.userEmail} · ${_fmtDate(r.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: dark
                                              ? SlstColors.darkMuted
                                              : SlstColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Quick Consolidate dialog (duplicate-SO staging rows)
// ---------------------------------------------------------------------------

Future<void> showQuickConsolidateDialog(BuildContext context, WidgetRef ref) {
  final staging = ref.read(appDataProvider).staging;
  final groups = <String, List<StagingEntry>>{};
  for (final e in staging) {
    groups.putIfAbsent(e.so.trim().toLowerCase(), () => []).add(e);
  }
  final dupes = groups.values.where((g) => g.length > 1).toList()
    ..sort((a, b) => a.first.so.compareTo(b.first.so));

  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.merge_type, color: SlstColors.purple),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Quick Consolidate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Merge duplicate staging rows that share the same SO into a single entry.',
                style: TextStyle(fontSize: 12.5, color: SlstColors.muted),
              ),
              const SizedBox(height: 12),
              if (dupes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No duplicate SOs found in staging.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: dupes.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final group = dupes[i];
                      final first = group.first;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'SO ${first.so} — ${first.customer}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${group.length} rows · ${group.map((e) => e.type).join(' | ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: PillButton(
                          label: 'Consolidate',
                          color: SlstColors.purple,
                          compact: true,
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Consolidate SO ${first.so}?',
                              message:
                                  'Merge ${group.length} staging rows into one entry.',
                              confirmLabel: 'Consolidate',
                              confirmColor: SlstColors.purple,
                            );
                            if (!ok || !context.mounted) return;
                            try {
                              await ref
                                  .read(operationsProvider)
                                  .consolidateStaging(group);
                              if (context.mounted) {
                                Navigator.pop(context);
                                showOk(context, 'Consolidated SO ${first.so}');
                              }
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Staging Entries table card
// ---------------------------------------------------------------------------

enum StagingSort { urgency, newest, so, customer }

class StagingLogCard extends ConsumerStatefulWidget {
  const StagingLogCard({
    super.key,
    required this.entries,
    this.expanded = false,
    this.onExpand,
  });

  /// Pre-filtered (search) staging entries.
  final List<StagingEntry> entries;
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  ConsumerState<StagingLogCard> createState() => _StagingLogCardState();
}

class _StagingLogCardState extends ConsumerState<StagingLogCard> {
  static const _previewRows = 12;

  StagingSort _sort = StagingSort.urgency;
  bool _batch = false;
  final _selected = <String>{};
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  List<StagingEntry> _sorted() {
    final list = [...widget.entries];
    switch (_sort) {
      case StagingSort.urgency:
        list.sort((a, b) {
          final u =
              StatusRules.urgencyWeight(b.status) -
              StatusRules.urgencyWeight(a.status);
          if (u != 0) return u;
          return (b.entryDate ?? DateTime(1970)).compareTo(
            a.entryDate ?? DateTime(1970),
          );
        });
      case StagingSort.newest:
        list.sort(
          (a, b) => (b.entryDate ?? DateTime(1970)).compareTo(
            a.entryDate ?? DateTime(1970),
          ),
        );
      case StagingSort.so:
        list.sort((a, b) => a.so.compareTo(b.so));
      case StagingSort.customer:
        list.sort(
          (a, b) =>
              a.customer.toLowerCase().compareTo(b.customer.toLowerCase()),
        );
    }
    return list;
  }

  Future<void> _deleteSelected(List<StagingEntry> visible) async {
    final picked = visible.where((e) => _selected.contains(e.id)).toList();
    if (picked.isEmpty) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete selected?',
      message:
          'Delete ${picked.length} staging entries? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      final ops = ref.read(operationsProvider);
      for (final e in picked) {
        await ops.deleteRecord(table: 'staging', id: e.id, so: e.so);
      }
      setState(() => _selected.clear());
      if (mounted) showOk(context, 'Deleted ${picked.length} entries');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _consolidateSelected(List<StagingEntry> visible) async {
    final picked = visible.where((e) => _selected.contains(e.id)).toList();
    try {
      await ref.read(operationsProvider).consolidateStaging(picked);
      setState(() => _selected.clear());
      if (mounted) showOk(context, 'Consolidated');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteOne(StagingEntry e) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete entry?',
      message: 'Delete staging entry for SO ${e.so}?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(operationsProvider)
          .deleteRecord(table: 'staging', id: e.id, so: e.so);
      if (mounted) showOk(context, 'Deleted SO ${e.so}');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canWrite = user != null;
    final sorted = _sorted();
    final rows = widget.expanded ? sorted : sorted.take(_previewRows).toList();
    _selected.removeWhere((id) => !sorted.any((e) => e.id == id));

    return SectionCard(
      title: 'Staging Entries',
      headerActions: [
        _SortDropdown<StagingSort>(
          value: _sort,
          items: const [
            (StagingSort.urgency, 'Sort: Urgency'),
            (StagingSort.newest, 'Sort: Newest'),
            (StagingSort.so, 'Sort: SO'),
            (StagingSort.customer, 'Sort: Customer'),
          ],
          onChanged: (v) => setState(() => _sort = v),
        ),
        if (canWrite)
          PillButton(
            label: 'New Entry',
            icon: Icons.add,
            color: SlstColors.brand,
            compact: true,
            onPressed: () => showStagingFormSheet(context, ref),
          ),
        if (canWrite)
          PillButton(
            label: _batch ? 'Exit Batch' : 'Batch Mode',
            icon: Icons.checklist,
            color: SlstColors.notify,
            compact: true,
            onPressed: () => setState(() {
              _batch = !_batch;
              if (!_batch) _selected.clear();
            }),
          ),
        PillButton(
          label: 'Changelog',
          icon: Icons.history,
          color: SlstColors.info,
          compact: true,
          onPressed: () => showChangelogDialog(context, ref, table: 'staging'),
        ),
        if (widget.onExpand != null)
          PillButton(
            label: 'Expand',
            icon: Icons.open_in_full,
            color: SlstColors.brand,
            compact: true,
            onPressed: widget.onExpand,
          ),
      ],
      subHeader: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StagingStatusLegend(),
          if (_batch) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                PillButton(
                  label: 'Consolidate Selected',
                  icon: Icons.merge_type,
                  color: SlstColors.purple,
                  compact: true,
                  onPressed: _selected.length >= 2
                      ? () => _consolidateSelected(sorted)
                      : null,
                ),
                PillButton(
                  label: 'Delete Selected',
                  icon: Icons.delete_outline,
                  color: SlstColors.danger,
                  compact: true,
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _deleteSelected(sorted),
                ),
              ],
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No staging entries found.')),
            )
          else
            Scrollbar(
              controller: _hScroll,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  headingRowHeight: 42,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  columns: [
                    if (_batch) const DataColumn(label: SizedBox(width: 24)),
                    if (canWrite) const DataColumn(label: Text('EDIT')),
                    const DataColumn(label: Text('PHOTOS')),
                    const DataColumn(label: Text('SO')),
                    const DataColumn(label: Text('CUSTOMER')),
                    const DataColumn(label: Text('ENTRY DATE')),
                    const DataColumn(label: Text('CONTAINERS')),
                    const DataColumn(label: Text('LOCATION')),
                    const DataColumn(label: Text('WEIGHT')),
                    const DataColumn(label: Text('COMMENTS')),
                    const DataColumn(label: Text('STATUS')),
                    const DataColumn(label: Text('STAGED BY')),
                    if (canWrite) const DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: [
                    for (final e in rows)
                      DataRow(
                        color: WidgetStatePropertyAll(
                          statusRowColor(context, e.status),
                        ),
                        cells: [
                          if (_batch)
                            DataCell(
                              Checkbox(
                                value: _selected.contains(e.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(e.id);
                                  } else {
                                    _selected.remove(e.id);
                                  }
                                }),
                              ),
                            ),
                          if (canWrite)
                            DataCell(
                              _editButton(
                                () => showStagingFormSheet(
                                  context,
                                  ref,
                                  existing: e,
                                ),
                              ),
                            ),
                          DataCell(_photosButton(context, e.so, e.photoUrls)),
                          DataCell(_soHistoryLink(context, ref, e.so)),
                          DataCell(_clipText(e.customer, maxWidth: 180)),
                          DataCell(Text(_fmtDate(e.entryDate))),
                          DataCell(_clipText(e.type, maxWidth: 170)),
                          DataCell(_clipText(e.location, maxWidth: 110)),
                          DataCell(_clipText(e.weight ?? '', maxWidth: 90)),
                          DataCell(_clipText(e.comments ?? '', maxWidth: 220)),
                          DataCell(
                            _clipText(
                              StatusRules.isYmd(e.status) &&
                                      StatusRules.formatUi(e.status) == e.status
                                  ? 'Future: ${e.status}'
                                  : StatusRules.formatUi(e.status),
                              maxWidth: 150,
                              weight: FontWeight.w600,
                            ),
                          ),
                          DataCell(_clipText(e.stagedBy ?? '', maxWidth: 110)),
                          if (canWrite)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PillButton(
                                    label: 'Ship',
                                    color: SlstColors.success,
                                    compact: true,
                                    onPressed: () =>
                                        showShipDialog(context, ref, entry: e),
                                  ),
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
                                    tooltip: 'More actions',
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'split':
                                          showSplitDialog(
                                            context,
                                            ref,
                                            entry: e,
                                          );
                                        case 'return':
                                          showReturnDialog(
                                            context,
                                            ref,
                                            entry: e,
                                          );
                                        case 'delete':
                                          _deleteOne(e);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'split',
                                        child: Text('Split Entry'),
                                      ),
                                      PopupMenuItem(
                                        value: 'return',
                                        child: Text('Return to Stock'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (!widget.expanded && sorted.length > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Showing ${rows.length} of ${sorted.length} — use Expand to view all.',
                style: const TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipped Log table card
// ---------------------------------------------------------------------------

enum ShippedSort { newest, so, customer, carrier }

class ShippedLogCard extends ConsumerStatefulWidget {
  const ShippedLogCard({
    super.key,
    required this.entries,
    this.expanded = false,
    this.onExpand,
    this.onQuickShip,
  });

  final List<ShippedEntry> entries;
  final bool expanded;
  final VoidCallback? onExpand;
  final VoidCallback? onQuickShip;

  @override
  ConsumerState<ShippedLogCard> createState() => _ShippedLogCardState();
}

class _ShippedLogCardState extends ConsumerState<ShippedLogCard> {
  static const _previewRows = 10;

  ShippedSort _sort = ShippedSort.newest;
  bool _batch = false;
  final _selected = <String>{};
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  List<ShippedEntry> _sorted() {
    final list = [...widget.entries];
    switch (_sort) {
      case ShippedSort.newest:
        list.sort(
          (a, b) => (b.shippedAt ?? DateTime(1970)).compareTo(
            a.shippedAt ?? DateTime(1970),
          ),
        );
      case ShippedSort.so:
        list.sort((a, b) => a.so.compareTo(b.so));
      case ShippedSort.customer:
        list.sort(
          (a, b) =>
              a.customer.toLowerCase().compareTo(b.customer.toLowerCase()),
        );
      case ShippedSort.carrier:
        list.sort(
          (a, b) => a.carrier.toLowerCase().compareTo(b.carrier.toLowerCase()),
        );
    }
    return list;
  }

  Future<void> _deleteSelected(List<ShippedEntry> visible) async {
    final picked = visible.where((e) => _selected.contains(e.id)).toList();
    if (picked.isEmpty) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete selected?',
      message:
          'Delete ${picked.length} shipped entries? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      final ops = ref.read(operationsProvider);
      for (final e in picked) {
        await ops.deleteRecord(table: 'shipped', id: e.id, so: e.so);
      }
      setState(() => _selected.clear());
      if (mounted) showOk(context, 'Deleted ${picked.length} entries');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _undo(ShippedEntry e) async {
    final ok = await confirmDialog(
      context,
      title: 'Undo shipment?',
      message: 'Restore SO ${e.so} back to the Staging Log?',
      confirmLabel: 'Undo Shipment',
      confirmColor: SlstColors.info,
    );
    if (!ok || !mounted) return;
    try {
      final ops = ref.read(operationsProvider);
      await ref.read(appDataProvider.notifier).refresh();
      if (!mounted) return;
      final siblings = siblingStagingEntries(
        so: e.so,
        active: ref.read(appDataProvider).staging,
      );
      var allowExistingSo = false;
      if (siblings.isNotEmpty) {
        final locations = leftoverLocations(siblings);
        final locationLine = locations.isEmpty
            ? '${siblings.length} other staging ${siblings.length == 1 ? 'entry' : 'entries'}'
            : locations.join(', ');
        final proceed = await confirmSoMultiEntryAdvisory(
          context,
          so: e.so,
          siblings: siblings,
          title: 'SO already in Staging',
          proceedLabel: 'Proceed anyway',
          messageOverride:
              'SO ${e.so} already has active staging at:\n\n'
              '$locationLine\n\n'
              'Undoing this shipment will add another staging row for the same SO. '
              'Continue only if that is intentional.',
        );
        if (!proceed || !mounted) return;
        allowExistingSo = true;
      }
      await ops.undoShipment(e, allowExistingSo: allowExistingSo);
      if (mounted) showOk(context, 'Restored SO ${e.so} to staging');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  Future<void> _deleteOne(ShippedEntry e) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete shipped entry?',
      message: 'Delete shipped record for SO ${e.so}?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(operationsProvider)
          .deleteRecord(table: 'shipped', id: e.id, so: e.so);
      if (mounted) showOk(context, 'Deleted SO ${e.so}');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canWrite = user != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sorted = _sorted();
    final rows = widget.expanded ? sorted : sorted.take(_previewRows).toList();
    _selected.removeWhere((id) => !sorted.any((e) => e.id == id));

    return SectionCard(
      title: 'Shipped Log',
      headerActions: [
        _SortDropdown<ShippedSort>(
          value: _sort,
          items: const [
            (ShippedSort.newest, 'Sort: Newest'),
            (ShippedSort.so, 'Sort: SO'),
            (ShippedSort.customer, 'Sort: Customer'),
            (ShippedSort.carrier, 'Sort: Carrier'),
          ],
          onChanged: (v) => setState(() => _sort = v),
        ),
        if (canWrite && widget.onQuickShip != null)
          PillButton(
            label: 'Quick Ship',
            icon: Icons.flash_on,
            color: SlstColors.success,
            compact: true,
            onPressed: widget.onQuickShip,
          ),
        if (canWrite)
          PillButton(
            label: _batch ? 'Exit Batch' : 'Batch Mode',
            icon: Icons.checklist,
            color: SlstColors.notify,
            compact: true,
            onPressed: () => setState(() {
              _batch = !_batch;
              if (!_batch) _selected.clear();
            }),
          ),
        PillButton(
          label: 'Changelog',
          icon: Icons.history,
          color: SlstColors.info,
          compact: true,
          onPressed: () => showChangelogDialog(context, ref, table: 'shipped'),
        ),
        if (widget.onExpand != null)
          PillButton(
            label: 'Expand',
            icon: Icons.open_in_full,
            color: SlstColors.brand,
            compact: true,
            onPressed: widget.onExpand,
          ),
      ],
      subHeader: _batch
          ? Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                PillButton(
                  label: 'Delete Selected',
                  icon: Icons.delete_outline,
                  color: SlstColors.danger,
                  compact: true,
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _deleteSelected(sorted),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No shipped entries found.')),
            )
          else
            Scrollbar(
              controller: _hScroll,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  headingRowHeight: 42,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  columns: [
                    if (_batch) const DataColumn(label: SizedBox(width: 24)),
                    const DataColumn(label: Text('PHOTOS')),
                    const DataColumn(label: Text('SO')),
                    const DataColumn(label: Text('CUSTOMER')),
                    const DataColumn(label: Text('CONTAINERS')),
                    const DataColumn(label: Text('CARRIER')),
                    const DataColumn(label: Text('LOCATION')),
                    const DataColumn(label: Text('WEIGHT')),
                    const DataColumn(label: Text('COMMENTS')),
                    const DataColumn(label: Text('SHIPPED AT')),
                    const DataColumn(label: Text('SHIPPED BY')),
                    const DataColumn(label: Text("PM'D")),
                    if (canWrite) const DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: [
                    for (final e in rows)
                      DataRow(
                        color: e.carrier.toUpperCase() == 'RETURNED TO STOCK'
                            ? WidgetStatePropertyAll(
                                dark
                                    ? SlstColors.statusPartialDark
                                    : SlstColors.statusPartial,
                              )
                            : null,
                        cells: [
                          if (_batch)
                            DataCell(
                              Checkbox(
                                value: _selected.contains(e.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(e.id);
                                  } else {
                                    _selected.remove(e.id);
                                  }
                                }),
                              ),
                            ),
                          DataCell(_photosButton(context, e.so, e.photoUrls)),
                          DataCell(_soHistoryLink(context, ref, e.so)),
                          DataCell(_clipText(e.customer, maxWidth: 180)),
                          DataCell(_clipText(e.type, maxWidth: 170)),
                          DataCell(_clipText(e.carrier, maxWidth: 150)),
                          DataCell(_clipText(e.location, maxWidth: 110)),
                          DataCell(_clipText(e.weight ?? '', maxWidth: 90)),
                          DataCell(_clipText(e.comments ?? '', maxWidth: 220)),
                          DataCell(Text(_fmtDate(e.shippedAt))),
                          DataCell(_clipText(e.shippedBy ?? '', maxWidth: 110)),
                          DataCell(
                            (e.pmdEmail ?? '').isEmpty
                                ? const Text('—')
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        size: 15,
                                        color: SlstColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      _clipText(e.pmdEmail!, maxWidth: 100),
                                    ],
                                  ),
                          ),
                          if (canWrite)
                            DataCell(
                              PopupMenuButton<String>(
                                tooltip: 'Actions',
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) {
                                  switch (v) {
                                    case 'undo':
                                      _undo(e);
                                    case 'delete':
                                      _deleteOne(e);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (e.carrier.toUpperCase() !=
                                      'RETURNED TO STOCK')
                                    const PopupMenuItem(
                                      value: 'undo',
                                      child: Text('Undo Shipment'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (!widget.expanded && sorted.length > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Showing ${rows.length} of ${sorted.length} — use Expand to view all.',
                style: const TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small sort dropdown used by both cards
// ---------------------------------------------------------------------------

class _SortDropdown<T> extends StatelessWidget {
  const _SortDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: dark ? SlstColors.darkBorderStrong : SlstColors.borderStrong,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: TextStyle(
            fontFamily: kBodyFontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: dark ? SlstColors.darkInk : SlstColors.ink,
          ),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(value: v, child: Text(label)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
