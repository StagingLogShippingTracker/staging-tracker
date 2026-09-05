import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format_weight.dart';
import '../../core/popup_gate.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/log_view_mode.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../staging/ship_dialog.dart';
import '../staging/split_dialog.dart';
import '../staging/staging_form_sheet.dart';
import 'industrial_widgets.dart';
import 'entry_suggestion_fields.dart';
import 'order_history_dialog.dart';
import 'so_advisories.dart';
import 'so_history_link.dart';
import 'widgets.dart';

/// Android: industrial wide-grid + horizontal chrome collapses to zero height
/// inside a page ListView. Use the virtualized dense list there instead.
bool get _androidTouchLogList {
  if (kIsWeb) return false;
  return Platform.isAndroid;
}

final _dateFmt = DateFormat('M/d/yy h:mm a');
final _mutedStampFmt = DateFormat('MMM d, h:mm a');

String _fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d.toLocal());

String _fmtStamp(DateTime? d) {
  if (d == null) return '—';
  return _mutedStampFmt.format(d.toLocal()).toUpperCase();
}

String _stagingStatusLabel(String status) {
  if (StatusRules.isYmd(status) && StatusRules.formatUi(status) == status) {
    return 'Future: $status';
  }
  return StatusRules.formatUi(status);
}

Color _zebraRowColor(BuildContext context, int index, {bool selected = false}) {
  if (selected) return IndustrialTheme.chromeAccent.withValues(alpha: 0.12);
  return index.isOdd
      ? IndustrialTheme.chromeOf(context).header.withValues(alpha: 0.55)
      : Colors.transparent;
}

/// Industrial log grid with left/right arrows + horizontal scrollbar.
///
/// When [fillsViewport] is true, the parent must give a bounded height. Rows
/// scroll vertically inside that viewport so the horizontal chrome stays pinned
/// to the visible table panel (not at the document end under tall content).
Widget _industrialGridWithPinnedHorizontalChrome({
  required Widget grid,
  required bool fillsViewport,
}) {
  if (!fillsViewport) {
    return HorizontalScrollWithArrows(
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: grid,
      ),
    );
  }

  return HorizontalScrollWithArrows(
    builder: (context, controller) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final table = !maxH.isFinite || maxH <= 0
              ? grid
              : SizedBox(
                  height: maxH,
                  child: showHorizontalScrollChrome
                      ? Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: grid,
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: grid,
                        ),
                );
          return SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: table,
          );
        },
      );
    },
  );
}

Widget _clipText(
  BuildContext context,
  String text, {
  double maxWidth = 220,
  FontWeight? weight,
  bool muted = false,
}) {
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
        style: TextStyle(
          fontWeight: weight ?? FontWeight.w500,
          fontSize: 13,
          color: muted
              ? IndustrialTheme.chromeOf(context).muted
              : IndustrialTheme.chromeOf(context).ink,
        ),
      ),
    ),
  );
}

Widget _mutedStamp(BuildContext context, DateTime? d) {
  return Text(
    _fmtStamp(d),
    style: IndustrialTheme.mono(fontSize: 11, color: IndustrialTheme.chromeOf(context).muted),
  );
}

/// Dense mobile row chrome: left accent + content height from children.
///
/// Do **not** wrap these rows in [IntrinsicHeight]. Speculative intrinsic
/// passes undersize rows that contain a [Wrap] (timestamps / zone pills), so
/// content overflows into the next row on first paint; a later rebuild (e.g.
/// tab switch) then looks correct. A left [BorderSide] tracks content height
/// without an intrinsic pass.
Widget _denseAccentRow({
  required Color accent,
  required Color background,
  required VoidCallback onTap,
  required Widget child,
}) {
  return Material(
    color: background,
    clipBehavior: Clip.hardEdge,
    child: InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: child,
      ),
    ),
  );
}

Widget _pmNotificationCell(
  BuildContext context,
  ShippedEntry entry, {
  double maxWidth = 120,
}) {
  final email = entry.pmdEmail?.trim() ?? '';
  if (email.isEmpty) {
    return Text(
      '—',
      style: IndustrialTheme.mono(
        fontSize: 12,
        color: IndustrialTheme.chromeOf(context).muted,
      ),
    );
  }

  final status = entry.notificationStatus;
  final (icon, color, label) = switch (status) {
    'sent' => (Icons.check_circle, IndustrialTheme.mintGreen, 'Sent'),
    'failed' => (Icons.error, SlstColors.danger, 'Failed'),
    'pending' => (Icons.schedule, Colors.amber, 'Pending'),
    _ => (Icons.mail_outline, IndustrialTheme.chromeOf(context).muted, 'Not requested'),
  };
  final message = entry.notificationError?.trim();
  return Tooltip(
    message: message == null || message.isEmpty
        ? 'PM notification: $label'
        : 'PM notification failed: $message',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        _clipText(context, email, maxWidth: maxWidth - 28),
      ],
    ),
  );
}

Widget _containerCell(BuildContext context, String type, int qty) {
  final label = type.trim().isEmpty ? '$qty' : type.trim();
  return Tooltip(
    message: label,
    waitDuration: const Duration(milliseconds: 500),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: IndustrialTheme.mono(
          fontSize: 12,
          color: IndustrialTheme.chromeOf(context).ink,
        ),
      ),
    ),
  );
}

Widget _photosButton(BuildContext context, String so, List<String> paths) {
  if (paths.isEmpty) {
    return Text(
      '—',
      style: IndustrialTheme.mono(
        fontSize: 12,
        color: IndustrialTheme.chromeOf(context).muted,
      ),
    );
  }
  return TextButton.icon(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 32),
      foregroundColor: IndustrialTheme.chromeAccent,
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
  double maxWidth = 120,
  bool large = false,
}) {
  return SoHistoryLink(
    so,
    maxWidth: maxWidth,
    fontSize: large ? 15 : 13,
  );
}

/// Industrial list ↔ cards toggle (sky accent when cards active).
Widget _logViewModeToggle(BuildContext context, WidgetRef ref) {
  final mode = ref.watch(logViewModeProvider);
  final isCards = mode == LogViewMode.card;

  return Tooltip(
    message: isCards ? 'Card view' : 'List view',
    child: Semantics(
      label: 'Toggle card or list view',
      toggled: isCards,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ref.read(logViewModeProvider.notifier).toggle(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 38,
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isCards
                ? IndustrialTheme.chromeAccent
                : IndustrialTheme.chromeOf(context).header,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IndustrialTheme.chromeOf(context).border),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: isCards ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: IndustrialTheme.chromeOf(context).ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    ),
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
  return PopupGate.exclusive<void>(PopupKeys.changelog, () {
    return showDialog<void>(
      context: context,
      builder: (context) {
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
                        separatorBuilder: (_, _) => Divider(),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${r.userEmail.isEmpty ? 'system' : r.userEmail} · ${_fmtDate(r.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: IndustrialTheme.chromeOf(context).muted,
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
  });
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

  return PopupGate.exclusive<void>(PopupKeys.consolidate, () {
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
                    separatorBuilder: (_, _) => Divider(),
                    itemBuilder: (context, i) {
                      final group = dupes[i];
                      final first = group.first;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'SO ${first.so} — ${first.customer}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${group.length} rows · ${group.map((e) => e.type).join(' | ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
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
  });
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
    this.fillsViewport = false,
    this.selectedId,
    this.onInspect,
  });

  /// Pre-filtered (search) staging entries.
  final List<StagingEntry> entries;
  final bool expanded;
  final VoidCallback? onExpand;

  /// When true, own the vertical scroll (parent should give a bounded height).
  final bool fillsViewport;

  /// Highlighted row id owned by the parent screen inspector host.
  final String? selectedId;

  /// Parent hosts the slide-over; cards must not embed Column+Expanded in ListView.
  final ValueChanged<StagingEntry>? onInspect;

  @override
  ConsumerState<StagingLogCard> createState() => _StagingLogCardState();
}

class _StagingLogCardState extends ConsumerState<StagingLogCard> {
  static const _previewRows = 12;
  static const _allZones = 'All Zones';
  static const _allStatuses = 'All Statuses';
  static const _allStagers = 'All Stagers';

  StagingSort _sort = StagingSort.urgency;
  bool _batch = false;
  final _selected = <String>{};
  String _zoneFilter = _allZones;
  String _statusFilter = _allStatuses;
  String _stagerFilter = _allStagers;

  void _inspect(StagingEntry entry) => widget.onInspect?.call(entry);

  List<StagingEntry> _filtered() {
    return widget.entries.where((e) {
      if (_zoneFilter != _allZones && e.location.trim() != _zoneFilter) {
        return false;
      }
      if (_statusFilter != _allStatuses &&
          _stagingStatusLabel(e.status) != _statusFilter) {
        return false;
      }
      final stager = (e.stagedBy ?? '').trim();
      if (_stagerFilter != _allStagers && stager != _stagerFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<StagingEntry> _sorted() {
    final list = _filtered();
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

  List<String> _uniqueSorted(Iterable<String> values) {
    final set = <String>{};
    for (final v in values) {
      final t = v.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    const canWrite = true;
    final sorted = _sorted();
    final rows = widget.expanded ? sorted : sorted.take(_previewRows).toList();
    _selected.removeWhere((id) => !sorted.any((e) => e.id == id));

    final zones = [
      _allZones,
      ..._uniqueSorted(widget.entries.map((e) => e.location)),
    ];
    final statuses = [
      _allStatuses,
      ..._uniqueSorted(
        widget.entries.map((e) => _stagingStatusLabel(e.status)),
      ),
    ];
    final stagers = [
      _allStagers,
      ..._uniqueSorted(widget.entries.map((e) => e.stagedBy ?? '')),
    ];
    if (!zones.contains(_zoneFilter)) _zoneFilter = _allZones;
    if (!statuses.contains(_statusFilter)) _statusFilter = _allStatuses;
    if (!stagers.contains(_stagerFilter)) _stagerFilter = _allStagers;

    return SectionCard(
      title: 'Active Staging Entries',
      expandChild: widget.fillsViewport,
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
        _logViewModeToggle(context, ref),
        if (canWrite)
          PillButton(
            label: 'New Entry',
            icon: Icons.add,
            color: IndustrialTheme.chromeAccent,
            compact: true,
            onPressed: () => showStagingFormSheet(context, ref),
          ),
        if (canWrite)
          PillButton(
            label: _batch ? 'Exit Batch' : 'Batch Mode',
            icon: Icons.checklist,
            color: IndustrialTheme.chromeAccent,
            compact: true,
            onPressed: () => setState(() {
              _batch = !_batch;
              if (!_batch) _selected.clear();
            }),
          ),
        PillButton(
          label: 'Changelog',
          icon: Icons.history,
          color: IndustrialTheme.slateMuted,
          compact: true,
          onPressed: () => showChangelogDialog(context, ref, table: 'staging'),
        ),
        if (widget.onExpand != null)
          PillButton(
            label: 'Expand',
            icon: Icons.open_in_full,
            color: IndustrialTheme.chromeAccent,
            compact: true,
            onPressed: widget.onExpand,
          ),
      ],
      subHeader: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IndustrialFilterDropdown(
                value: _zoneFilter,
                items: zones,
                width: 132,
                onChanged: (v) => setState(() => _zoneFilter = v),
              ),
              IndustrialFilterDropdown(
                value: _statusFilter,
                items: statuses,
                width: 168,
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              IndustrialFilterDropdown(
                value: _stagerFilter,
                items: stagers,
                width: 140,
                onChanged: (v) => setState(() => _stagerFilter = v),
              ),
              Text(
                '${sorted.length} entr${sorted.length == 1 ? 'y' : 'ies'}',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
                PillButton(
                  label: 'Consolidate Selected',
                  icon: Icons.merge_type,
                  color: IndustrialTheme.purple,
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
      child: _buildStagingEntriesBody(
        context: context,
        canWrite: canWrite,
        sorted: sorted,
        rows: rows,
      ),
    );
  }

  /// Desktop uses a custom dense industrial grid (not Material DataTable).
  /// Mobile list mode uses a virtualized dense list for scroll performance.
  Widget _buildStagingEntriesBody({
    required BuildContext context,
    required bool canWrite,
    required List<StagingEntry> sorted,
    required List<StagingEntry> rows,
  }) {
    final viewMode = ref.watch(logViewModeProvider);
    // Windows list = industrial grid. Android list = dense virtualized rows
    // (wide grid + horizontal scroll was painting zero-height on phone).
    final useIndustrialGrid =
        viewMode == LogViewMode.list && !_androidTouchLogList;

    if (rows.isEmpty) {
      final empty = const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('No staging entries found.')),
      );
      if (widget.fillsViewport) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [empty],
        );
      }
      return empty;
    }

    late final Widget body;
    if (viewMode == LogViewMode.card) {
      body = _stagingCardList(
        canWrite: canWrite,
        rows: rows,
        sortedLength: sorted.length,
      );
    } else if (!useIndustrialGrid) {
      body = _stagingDenseList(
        canWrite: canWrite,
        rows: rows,
        sortedLength: sorted.length,
      );
    } else {
      final grid = _stagingIndustrialGrid(canWrite: canWrite, rows: rows);
      // Pin arrows + horizontal scrollbar to the table panel viewport; scroll
      // rows vertically inside that bounded height (not the outer page).
      final horizontal = _industrialGridWithPinnedHorizontalChrome(
        grid: grid,
        fillsViewport: widget.fillsViewport,
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.fillsViewport) Expanded(child: horizontal) else horizontal,
          if (!widget.expanded && sorted.length > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Showing ${rows.length} of ${sorted.length} — use Expand to view all.',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      );
    }

    return body;
  }

  Widget _stagingCardList({
    required bool canWrite,
    required List<StagingEntry> rows,
    required int sortedLength,
  }) {
    Widget cardFor(StagingEntry e) => EntryCard(
      title: e.so,
      subtitle: e.customer,
      dbStatus: e.status,
      details: [
        if (e.location.trim().isNotEmpty) e.location,
        if (e.type.trim().isNotEmpty) e.type,
        if ((e.weight ?? '').isNotEmpty)
          'Wt: ${formatWeightDisplay(e.weight)}',
        if ((e.stagedBy ?? '').isNotEmpty) 'Staged by: ${e.stagedBy}',
        if ((e.comments ?? '').isNotEmpty) e.comments!,
      ],
      onTap: () => _inspect(e),
      trailing: canWrite
          ? PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: IndustrialTheme.chromeOf(context).muted,
              ),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    showStagingFormSheet(context, ref, existing: e);
                  case 'ship':
                    showShipDialog(context, ref, entry: e);
                  case 'split':
                    showSplitDialog(context, ref, entry: e);
                  case 'return':
                    showReturnDialog(context, ref, entry: e);
                  case 'delete':
                    _deleteOne(e);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'ship', child: Text('Ship')),
                PopupMenuItem(value: 'split', child: Text('Split Entry')),
                PopupMenuItem(value: 'return', child: Text('Return to Stock')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : null,
    );

    if (widget.fillsViewport) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            rows.length +
            (!widget.expanded && sortedLength > rows.length ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            );
          }
          return cardFor(rows[index]);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          for (final e in rows) cardFor(e),
          if (!widget.expanded && sortedLength > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stagingDenseList({
    required bool canWrite,
    required List<StagingEntry> rows,
    required int sortedLength,
  }) {
    Widget rowFor(StagingEntry e, int index) {
      final statusLabel = _stagingStatusLabel(e.status);
      final selected = widget.selectedId == e.id;
      final accent = industrialStatusAccent(context, statusLabel);
      return _denseAccentRow(
        accent: accent,
        background: _zebraRowColor(context, index, selected: selected),
        onTap: () => _inspect(e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_batch)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Checkbox(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.so,
                            style: IndustrialTheme.mono(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: IndustrialTheme.chromeOf(context).ink,
                            ),
                          ),
                        ),
                        IndustrialStatusBadge(status: statusLabel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.customer.isEmpty ? '—' : e.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: IndustrialTheme.chromeOf(context).muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IndustrialZonePill(e.location),
                        _containerCell(context, e.type, e.qty),
                        if ((e.weight ?? '').trim().isNotEmpty)
                          IndustrialWeightPill(e.weight),
                        _mutedStamp(context, e.entryDate),
                      ],
                    ),
                  ],
                ),
              ),
              if (canWrite)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: IndustrialTheme.chromeOf(context).muted,
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        showStagingFormSheet(
                          context,
                          ref,
                          existing: e,
                        );
                      case 'ship':
                        showShipDialog(context, ref, entry: e);
                      case 'split':
                        showSplitDialog(context, ref, entry: e);
                      case 'return':
                        showReturnDialog(context, ref, entry: e);
                      case 'delete':
                        _deleteOne(e);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'ship', child: Text('Ship')),
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
      );
    }

    if (widget.fillsViewport) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            rows.length +
            (!widget.expanded && sortedLength > rows.length ? 1 : 0),
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            );
          }
          return rowFor(rows[index], index);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
            rowFor(rows[i], i),
          ],
          if (!widget.expanded && sortedLength > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stagingIndustrialGrid({
    required bool canWrite,
    required List<StagingEntry> rows,
  }) {
    const soW = 120.0;
    const clientW = 168.0;
    const zoneW = 118.0;
    const containerW = 140.0;
    const weightW = 118.0;
    const statusW = 140.0;
    const stagerW = 118.0;
    const timeW = 128.0;
    const photosW = 80.0;
    const actionsW = 148.0;
    const cellPad = EdgeInsets.symmetric(horizontal: 10, vertical: 10);
    final batchW = _batch ? 44.0 : 0.0;
    final totalW =
        3 +
        batchW +
        soW +
        clientW +
        zoneW +
        containerW +
        weightW +
        statusW +
        stagerW +
        timeW +
        photosW +
        (canWrite ? actionsW : 0) +
        24;

    Widget headerCell(String label, double width) =>
        SizedBox(width: width, child: IndustrialColumnHeader(label));

    return SizedBox(
      width: totalW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: IndustrialTheme.chromeOf(context).header,
            padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            child: Row(
              children: [
                const SizedBox(width: 3),
                if (_batch) SizedBox(width: batchW),
                headerCell('SO Number', soW),
                headerCell('Client', clientW),
                headerCell('Zone', zoneW),
                headerCell('Containers', containerW),
                headerCell('Weight (lbs)', weightW),
                headerCell('Status', statusW),
                headerCell('Stager', stagerW),
                headerCell('Timestamp', timeW),
                headerCell('Photos', photosW),
                if (canWrite) headerCell('Actions', actionsW),
              ],
            ),
          ),
          Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
            () {
              final e = rows[i];
              final statusLabel = _stagingStatusLabel(e.status);
              final selected = widget.selectedId == e.id;
              final accent = industrialStatusAccent(context, statusLabel);
              return Material(
                color: _zebraRowColor(context, i, selected: selected),
                child: InkWell(
                  onTap: () => _inspect(e),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 3, color: accent),
                        if (_batch)
                          SizedBox(
                            width: batchW,
                            child: Center(
                              child: Checkbox(
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
                          ),
                        SizedBox(
                          width: soW,
                          child: Padding(
                            padding: cellPad,
                            child: _soHistoryLink(
                              context,
                              ref,
                              e.so,
                              maxWidth: soW - 20,
                              large: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: clientW,
                          child: Padding(
                            padding: cellPad,
                            child: _clipText(context, 
                              e.customer,
                              maxWidth: clientW - 20,
                              muted: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: zoneW,
                          child: Padding(
                            padding: cellPad,
                            child: IndustrialZonePill(e.location),
                          ),
                        ),
                        SizedBox(
                          width: containerW,
                          child: Padding(
                            padding: cellPad,
                            child: _containerCell(context, e.type, e.qty),
                          ),
                        ),
                        SizedBox(
                          width: weightW,
                          child: Padding(
                            padding: cellPad,
                            child: IndustrialWeightPill(e.weight),
                          ),
                        ),
                        SizedBox(
                          width: statusW,
                          child: Padding(
                            padding: cellPad,
                            child: IndustrialStatusBadge(status: statusLabel),
                          ),
                        ),
                        SizedBox(
                          width: stagerW,
                          child: Padding(
                            padding: cellPad,
                            child: _clipText(context, 
                              e.stagedBy ?? '',
                              maxWidth: stagerW - 20,
                              muted: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: timeW,
                          child: Padding(
                            padding: cellPad,
                            child: _mutedStamp(context, e.entryDate),
                          ),
                        ),
                        SizedBox(
                          width: photosW,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: _photosButton(context, e.so, e.photoUrls),
                          ),
                        ),
                        if (canWrite)
                          SizedBox(
                            width: actionsW,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PillButton(
                                    label: 'Ship',
                                    color: IndustrialTheme.mintGreen,
                                    compact: true,
                                    onPressed: () =>
                                        showShipDialog(context, ref, entry: e),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'More actions',
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 20,
                                      color: IndustrialTheme.chromeOf(context).muted,
                                    ),
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'edit':
                                          showStagingFormSheet(
                                            context,
                                            ref,
                                            existing: e,
                                          );
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
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
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
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ],
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
    this.fillsViewport = false,
    this.selectedId,
    this.onInspect,
  });

  final List<ShippedEntry> entries;
  final bool expanded;
  final VoidCallback? onExpand;
  final VoidCallback? onQuickShip;

  /// When true, own the vertical scroll (parent should give a bounded height).
  final bool fillsViewport;

  /// Highlighted row id owned by the parent screen inspector host.
  final String? selectedId;

  /// Parent hosts the slide-over; cards must not embed Column+Expanded in ListView.
  final ValueChanged<ShippedEntry>? onInspect;

  @override
  ConsumerState<ShippedLogCard> createState() => _ShippedLogCardState();
}

class _ShippedLogCardState extends ConsumerState<ShippedLogCard> {
  static const _previewRows = 10;
  static const _allCarriers = 'All Carriers';
  static const _allZones = 'All Zones';
  static const _allShippers = 'All Shippers';

  ShippedSort _sort = ShippedSort.newest;
  bool _batch = false;
  final _selected = <String>{};
  String _carrierFilter = _allCarriers;
  String _zoneFilter = _allZones;
  String _shipperFilter = _allShippers;

  void _inspect(ShippedEntry entry) => widget.onInspect?.call(entry);

  List<String> _uniqueSorted(Iterable<String> values) {
    final set = <String>{};
    for (final v in values) {
      final t = v.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<ShippedEntry> _filtered() {
    return widget.entries.where((e) {
      if (_carrierFilter != _allCarriers &&
          e.carrier.trim() != _carrierFilter) {
        return false;
      }
      if (_zoneFilter != _allZones && e.location.trim() != _zoneFilter) {
        return false;
      }
      final shipper = (e.shippedBy ?? '').trim();
      if (_shipperFilter != _allShippers && shipper != _shipperFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<ShippedEntry> _sorted() {
    final list = _filtered();
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
    const canWrite = true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sorted = _sorted();
    final rows = widget.expanded ? sorted : sorted.take(_previewRows).toList();
    _selected.removeWhere((id) => !sorted.any((e) => e.id == id));

    final carriers = [
      _allCarriers,
      ..._uniqueSorted(widget.entries.map((e) => e.carrier)),
    ];
    final zones = [
      _allZones,
      ..._uniqueSorted(widget.entries.map((e) => e.location)),
    ];
    final shippers = [
      _allShippers,
      ..._uniqueSorted(widget.entries.map((e) => e.shippedBy ?? '')),
    ];
    if (!carriers.contains(_carrierFilter)) _carrierFilter = _allCarriers;
    if (!zones.contains(_zoneFilter)) _zoneFilter = _allZones;
    if (!shippers.contains(_shipperFilter)) _shipperFilter = _allShippers;

    return SectionCard(
      title: 'Shipped Staging Entries',
      expandChild: widget.fillsViewport,
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
        _logViewModeToggle(context, ref),
        if (canWrite && widget.onQuickShip != null)
          PillButton(
            label: 'Quick Ship',
            icon: Icons.flash_on,
            color: IndustrialTheme.mintGreen,
            compact: true,
            onPressed: widget.onQuickShip,
          ),
        if (canWrite)
          PillButton(
            label: _batch ? 'Exit Batch' : 'Batch Mode',
            icon: Icons.checklist,
            color: IndustrialTheme.chromeAccent,
            compact: true,
            onPressed: () => setState(() {
              _batch = !_batch;
              if (!_batch) _selected.clear();
            }),
          ),
        PillButton(
          label: 'Changelog',
          icon: Icons.history,
          color: IndustrialTheme.slateMuted,
          compact: true,
          onPressed: () => showChangelogDialog(context, ref, table: 'shipped'),
        ),
        if (widget.onExpand != null)
          PillButton(
            label: 'Expand',
            icon: Icons.open_in_full,
            color: IndustrialTheme.chromeAccent,
            compact: true,
            onPressed: widget.onExpand,
          ),
      ],
      subHeader: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IndustrialFilterDropdown(
                value: _carrierFilter,
                items: carriers,
                width: 150,
                onChanged: (v) => setState(() => _carrierFilter = v),
              ),
              IndustrialFilterDropdown(
                value: _zoneFilter,
                items: zones,
                width: 132,
                onChanged: (v) => setState(() => _zoneFilter = v),
              ),
              IndustrialFilterDropdown(
                value: _shipperFilter,
                items: shippers,
                width: 140,
                onChanged: (v) => setState(() => _shipperFilter = v),
              ),
              Text(
                '${sorted.length} entr${sorted.length == 1 ? 'y' : 'ies'}',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            ],
          ),
          if (_batch) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: IndustrialTheme.chromeOf(context).ink,
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
            ),
          ],
        ],
      ),
      child: _buildShippedEntriesBody(
        canWrite: canWrite,
        dark: dark,
        sorted: sorted,
        rows: rows,
      ),
    );
  }

  Widget _buildShippedEntriesBody({
    required bool canWrite,
    required bool dark,
    required List<ShippedEntry> sorted,
    required List<ShippedEntry> rows,
  }) {
    final viewMode = ref.watch(logViewModeProvider);
    final useIndustrialGrid =
        viewMode == LogViewMode.list && !_androidTouchLogList;

    if (rows.isEmpty) {
      final empty = const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('No shipped entries found.')),
      );
      if (widget.fillsViewport) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [empty],
        );
      }
      return empty;
    }

    late final Widget body;
    if (viewMode == LogViewMode.card) {
      body = _shippedCardList(
        canWrite: canWrite,
        dark: dark,
        rows: rows,
        sortedLength: sorted.length,
      );
    } else if (!useIndustrialGrid) {
      body = _shippedDenseList(
        canWrite: canWrite,
        dark: dark,
        rows: rows,
        sortedLength: sorted.length,
      );
    } else {
      final grid = _shippedIndustrialGrid(canWrite: canWrite, rows: rows);
      final horizontal = _industrialGridWithPinnedHorizontalChrome(
        grid: grid,
        fillsViewport: widget.fillsViewport,
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.fillsViewport) Expanded(child: horizontal) else horizontal,
          if (!widget.expanded && sorted.length > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Showing ${rows.length} of ${sorted.length} — use Expand to view all.',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      );
    }

    return body;
  }

  Widget _shippedCardList({
    required bool canWrite,
    required bool dark,
    required List<ShippedEntry> rows,
    required int sortedLength,
  }) {
    Widget cardFor(ShippedEntry e) => EntryCard(
      title: e.so,
      subtitle: e.customer,
      color: e.carrier.toUpperCase() == 'RETURNED TO STOCK'
          ? SlstColors.statusPartial
          : null,
      details: [
        if (e.type.trim().isNotEmpty) e.type,
        if (e.carrier.trim().isNotEmpty) e.carrier,
        if (e.location.trim().isNotEmpty) e.location,
        if ((e.weight ?? '').isNotEmpty)
          'Wt: ${formatWeightDisplay(e.weight)}',
        if ((e.shippedBy ?? '').isNotEmpty) 'Shipped by: ${e.shippedBy}',
        if ((e.comments ?? '').isNotEmpty) e.comments!,
      ],
      onTap: () => _inspect(e),
      trailing: canWrite
          ? PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: IndustrialTheme.chromeOf(context).muted,
              ),
              onSelected: (v) {
                switch (v) {
                  case 'undo':
                    _undo(e);
                  case 'delete':
                    _deleteOne(e);
                }
              },
              itemBuilder: (context) => [
                if (e.carrier.toUpperCase() != 'RETURNED TO STOCK')
                  const PopupMenuItem(
                    value: 'undo',
                    child: Text('Undo Shipment'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : null,
    );

    if (widget.fillsViewport) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            rows.length +
            (!widget.expanded && sortedLength > rows.length ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            );
          }
          return cardFor(rows[index]);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          for (final e in rows) cardFor(e),
          if (!widget.expanded && sortedLength > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shippedDenseList({
    required bool canWrite,
    required bool dark,
    required List<ShippedEntry> rows,
    required int sortedLength,
  }) {
    Widget rowFor(ShippedEntry e, int index) {
      final returned = e.carrier.toUpperCase() == 'RETURNED TO STOCK';
      final statusLabel = returned ? 'Returned' : 'Shipped';
      final selected = widget.selectedId == e.id;
      final accent = industrialStatusAccent(context, statusLabel);
      return _denseAccentRow(
        accent: accent,
        background: returned
            ? SlstColors.statusPartial
            : _zebraRowColor(context, index, selected: selected),
        onTap: () => _inspect(e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_batch)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Checkbox(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.so,
                            style: IndustrialTheme.mono(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: IndustrialTheme.chromeOf(context).ink,
                            ),
                          ),
                        ),
                        IndustrialStatusBadge(status: statusLabel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.customer.isEmpty ? '—' : e.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: IndustrialTheme.chromeOf(context).muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IndustrialZonePill(e.location),
                        _containerCell(context, e.type, e.qty),
                        if (e.carrier.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: IndustrialTheme.chromeOf(context).header,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: IndustrialTheme.chromeOf(context).border,
                              ),
                            ),
                            child: Text(
                              e.carrier,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: IndustrialTheme.chromeOf(context).muted,
                              ),
                            ),
                          ),
                        if ((e.weight ?? '').trim().isNotEmpty)
                          IndustrialWeightPill(e.weight),
                        _mutedStamp(context, e.shippedAt),
                      ],
                    ),
                  ],
                ),
              ),
              if (canWrite)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: IndustrialTheme.chromeOf(context).muted,
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'undo':
                        _undo(e);
                      case 'delete':
                        _deleteOne(e);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!returned)
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
            ],
          ),
        ),
      );
    }

    if (widget.fillsViewport) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            rows.length +
            (!widget.expanded && sortedLength > rows.length ? 1 : 0),
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            );
          }
          return rowFor(rows[index], index);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
            rowFor(rows[i], i),
          ],
          if (!widget.expanded && sortedLength > rows.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Showing ${rows.length} of $sortedLength — use Expand to view all.',
                style: TextStyle(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shippedIndustrialGrid({
    required bool canWrite,
    required List<ShippedEntry> rows,
  }) {
    const soW = 120.0;
    const clientW = 160.0;
    const containerW = 140.0;
    const carrierW = 130.0;
    const zoneW = 118.0;
    const weightW = 118.0;
    const shippedW = 128.0;
    const byW = 110.0;
    const pmdW = 120.0;
    const photosW = 80.0;
    const actionsW = 56.0;
    const cellPad = EdgeInsets.symmetric(horizontal: 10, vertical: 10);
    final batchW = _batch ? 44.0 : 0.0;
    final totalW =
        3 +
        batchW +
        soW +
        clientW +
        containerW +
        carrierW +
        zoneW +
        weightW +
        shippedW +
        byW +
        pmdW +
        photosW +
        (canWrite ? actionsW : 0) +
        24;

    Widget headerCell(String label, double width) =>
        SizedBox(width: width, child: IndustrialColumnHeader(label));

    return SizedBox(
      width: totalW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: IndustrialTheme.chromeOf(context).header,
            padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            child: Row(
              children: [
                const SizedBox(width: 3),
                if (_batch) SizedBox(width: batchW),
                headerCell('SO Number', soW),
                headerCell('Client', clientW),
                headerCell('Containers', containerW),
                headerCell('Carrier', carrierW),
                headerCell('Zone', zoneW),
                headerCell('Weight (lbs)', weightW),
                headerCell('Shipped', shippedW),
                headerCell('By', byW),
                headerCell("PM'd", pmdW),
                headerCell('Photos', photosW),
                if (canWrite) headerCell('Actions', actionsW),
              ],
            ),
          ),
          Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: IndustrialTheme.chromeOf(context).border),
            () {
              final e = rows[i];
              final returned = e.carrier.toUpperCase() == 'RETURNED TO STOCK';
              final statusLabel = returned ? 'Returned' : 'Shipped';
              final selected = widget.selectedId == e.id;
              final accent = industrialStatusAccent(context, statusLabel);
              return Material(
                color: returned
                    ? SlstColors.statusPartial
                    : _zebraRowColor(context, i, selected: selected),
                child: InkWell(
                  onTap: () => _inspect(e),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 3, color: accent),
                        if (_batch)
                          SizedBox(
                            width: batchW,
                            child: Center(
                              child: Checkbox(
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
                          ),
                        SizedBox(
                          width: soW,
                          child: Padding(
                            padding: cellPad,
                            child: _soHistoryLink(
                              context,
                              ref,
                              e.so,
                              maxWidth: soW - 20,
                              large: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: clientW,
                          child: Padding(
                            padding: cellPad,
                            child: _clipText(context, 
                              e.customer,
                              maxWidth: clientW - 20,
                              muted: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: containerW,
                          child: Padding(
                            padding: cellPad,
                            child: _containerCell(context, e.type, e.qty),
                          ),
                        ),
                        SizedBox(
                          width: carrierW,
                          child: Padding(
                            padding: cellPad,
                            child: returned
                                ? IndustrialStatusBadge(status: 'Returned')
                                : _clipText(context, 
                                    e.carrier,
                                    maxWidth: carrierW - 20,
                                  ),
                          ),
                        ),
                        SizedBox(
                          width: zoneW,
                          child: Padding(
                            padding: cellPad,
                            child: IndustrialZonePill(e.location),
                          ),
                        ),
                        SizedBox(
                          width: weightW,
                          child: Padding(
                            padding: cellPad,
                            child: IndustrialWeightPill(e.weight),
                          ),
                        ),
                        SizedBox(
                          width: shippedW,
                          child: Padding(
                            padding: cellPad,
                            child: _mutedStamp(context, e.shippedAt),
                          ),
                        ),
                        SizedBox(
                          width: byW,
                          child: Padding(
                            padding: cellPad,
                            child: _clipText(context, 
                              e.shippedBy ?? '',
                              maxWidth: byW - 20,
                              muted: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: pmdW,
                          child: Padding(
                            padding: cellPad,
                            child: _pmNotificationCell(context, e, maxWidth: pmdW - 20),
                          ),
                        ),
                        SizedBox(
                          width: photosW,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: _photosButton(context, e.so, e.photoUrls),
                          ),
                        ),
                        if (canWrite)
                          SizedBox(
                            width: actionsW,
                            child: PopupMenuButton<String>(
                              tooltip: 'Actions',
                              icon: Icon(
                                Icons.more_vert,
                                size: 20,
                                color: IndustrialTheme.chromeOf(context).muted,
                              ),
                              onSelected: (v) {
                                switch (v) {
                                  case 'undo':
                                    _undo(e);
                                  case 'delete':
                                    _deleteOne(e);
                                }
                              },
                              itemBuilder: (context) => [
                                if (!returned)
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
                  ),
                ),
              );
            }(),
          ],
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
    return SizedBox(
      height: 34,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: IndustrialTheme.chromeOf(context).header,
          border: Border.all(color: IndustrialTheme.chromeOf(context).border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            dropdownColor: IndustrialTheme.chromeOf(context).surface,
            iconEnabledColor: IndustrialTheme.chromeOf(context).muted,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: IndustrialTheme.chromeOf(context).ink,
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
      ),
    );
  }
}

Future<void> deleteStagingEntry(
  BuildContext context,
  WidgetRef ref,
  StagingEntry e,
) async {
  final ok = await confirmDialog(
    context,
    title: 'Delete entry?',
    message: 'Delete staging entry for SO ${e.so}?',
    confirmLabel: 'Delete',
  );
  if (!ok || !context.mounted) return;
  try {
    await ref
        .read(operationsProvider)
        .deleteRecord(table: 'staging', id: e.id, so: e.so);
    if (context.mounted) showOk(context, 'Deleted SO ${e.so}');
  } catch (err) {
    if (context.mounted) showError(context, err);
  }
}

Future<void> deleteShippedEntry(
  BuildContext context,
  WidgetRef ref,
  ShippedEntry e,
) async {
  final ok = await confirmDialog(
    context,
    title: 'Delete shipped entry?',
    message: 'Delete shipped record for SO ${e.so}?',
    confirmLabel: 'Delete',
  );
  if (!ok || !context.mounted) return;
  try {
    await ref
        .read(operationsProvider)
        .deleteRecord(table: 'shipped', id: e.id, so: e.so);
    if (context.mounted) showOk(context, 'Deleted SO ${e.so}');
  } catch (err) {
    if (context.mounted) showError(context, err);
  }
}

Future<void> undoShippedEntry(
  BuildContext context,
  WidgetRef ref,
  ShippedEntry e,
) async {
  final ok = await confirmDialog(
    context,
    title: 'Undo shipment?',
    message: 'Restore SO ${e.so} back to the Staging Log?',
    confirmLabel: 'Undo Shipment',
    confirmColor: SlstColors.info,
  );
  if (!ok || !context.mounted) return;
  try {
    final ops = ref.read(operationsProvider);
    await ref.read(appDataProvider.notifier).refresh();
    if (!context.mounted) return;
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
      if (!proceed || !context.mounted) return;
      allowExistingSo = true;
    }
    await ops.undoShipment(e, allowExistingSo: allowExistingSo);
    if (context.mounted) showOk(context, 'Restored SO ${e.so} to staging');
  } catch (err) {
    if (context.mounted) showError(context, err);
  }
}

Future<void> consolidateStagingForSo(
  BuildContext context,
  WidgetRef ref,
  StagingEntry entry,
) async {
  final key = entry.so.trim().toLowerCase();
  final peers = ref
      .read(appDataProvider)
      .staging
      .where((e) => e.so.trim().toLowerCase() == key)
      .toList();
  if (peers.length < 2) {
    await showQuickConsolidateDialog(context, ref);
    return;
  }
  final ok = await confirmDialog(
    context,
    title: 'Consolidate SO ${entry.so}?',
    message:
        'Merge ${peers.length} staging rows for SO ${entry.so} into a single entry?',
    confirmLabel: 'Consolidate',
    confirmColor: SlstColors.purple,
  );
  if (!ok || !context.mounted) return;
  try {
    await ref.read(operationsProvider).consolidateStaging(peers);
    if (context.mounted) {
      showOk(context, 'Consolidated SO ${entry.so}');
    }
  } catch (err) {
    if (context.mounted) showError(context, err);
  }
}

Future<void> showShippedEditDialog(
  BuildContext context,
  WidgetRef ref, {
  required ShippedEntry entry,
}) {
  final customer = TextEditingController(text: entry.customer);
  final carrier = TextEditingController(text: entry.carrier);
  final location = TextEditingController(text: entry.location);
  final weight = TextEditingController(text: entry.weight ?? '');
  final shippedBy = TextEditingController(text: entry.shippedBy ?? '');
  final comments = TextEditingController(text: entry.comments ?? '');

  return showAdaptivePopup<void>(
    context,
    maxWidth: 520,
    exclusiveKey: PopupKeys.shippedEdit,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.85;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit shipped — SO ${entry.so}',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: customer,
                        decoration:
                            const InputDecoration(labelText: 'Customer'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: carrier,
                        decoration:
                            const InputDecoration(labelText: 'Carrier'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: location,
                        decoration:
                            const InputDecoration(labelText: 'Location'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: weight,
                        decoration:
                            const InputDecoration(labelText: 'Weight'),
                      ),
                      const SizedBox(height: 10),
                      PersonSuggestionField(
                        controller: shippedBy,
                        label: 'Shipped by',
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: comments,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Comments'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(operationsProvider)
                          .updateShipped(entry.id, {
                        'so': entry.so,
                        'customer': customer.text.trim(),
                        'carrier': carrier.text.trim(),
                        'location': location.text.trim(),
                        'weight': weight.text.trim().isEmpty
                            ? null
                            : weight.text.trim(),
                        'shipped_by': shippedBy.text.trim().isEmpty
                            ? null
                            : shippedBy.text.trim(),
                        'comments': comments.text.trim().isEmpty
                            ? null
                            : comments.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        showOk(context, 'Updated SO ${entry.so}');
                      }
                    } catch (err) {
                      if (context.mounted) showError(context, err);
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(() {
    customer.dispose();
    carrier.dispose();
    location.dispose();
    weight.dispose();
    shippedBy.dispose();
    comments.dispose();
  });
}

class StagingInspectorBody extends ConsumerWidget {
  const StagingInspectorBody({
    super.key,
    required this.entry,
    this.onClose,
  });
  final StagingEntry entry;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _stagingStatusLabel(entry.status);
    const canWrite = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndustrialStatusBadge(status: status),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canWrite) ...[
              OutlinedButton.icon(
                onPressed: () =>
                    showStagingFormSheet(context, ref, existing: entry),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await deleteStagingEntry(context, ref, entry);
                  onClose?.call();
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              ),
              OutlinedButton.icon(
                onPressed: () => showSplitDialog(context, ref, entry: entry),
                icon: const Icon(Icons.call_split, size: 16),
                label: const Text('Split'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await consolidateStagingForSo(context, ref, entry);
                  onClose?.call();
                },
                icon: const Icon(Icons.merge_type, size: 16),
                label: const Text('Consolidate'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    showReturnDialog(context, ref, entry: entry),
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Return to Stock'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: () =>
                  showOrderHistoryDialog(context, ref, so: entry.so),
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Order History'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('UUID', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        IndustrialIdText(entry.id, fontSize: 12, maxLines: 2),
        const SizedBox(height: 14),
        _inspectorField(context, 'Customer', entry.customer),
        _inspectorField(context, 'Containers', entry.type),
        _inspectorField(context, 'Location', entry.location),
        _inspectorField(
          context,
          'Weight',
          formatWeightDisplay(entry.weight, empty: '—'),
        ),
        _inspectorField(context, 'Staged by', entry.stagedBy ?? '—'),
        _inspectorField(context, 'Entry date', _fmtDate(entry.entryDate)),
        _inspectorField(context, 'Comments', entry.comments ?? '—'),
      ],
    );
  }
}

class ShippedInspectorBody extends ConsumerWidget {
  const ShippedInspectorBody({
    super.key,
    required this.entry,
    this.onClose,
  });
  final ShippedEntry entry;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returned = entry.carrier.toUpperCase() == 'RETURNED TO STOCK';
    const canWrite = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndustrialStatusBadge(status: returned ? 'Returned' : 'Shipped'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canWrite) ...[
              OutlinedButton.icon(
                onPressed: () =>
                    showShippedEditDialog(context, ref, entry: entry),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await deleteShippedEntry(context, ref, entry);
                  onClose?.call();
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              ),
              if (!returned)
                OutlinedButton.icon(
                  onPressed: () async {
                    await undoShippedEntry(context, ref, entry);
                    onClose?.call();
                  },
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Undo'),
                ),
            ],
            OutlinedButton.icon(
              onPressed: () =>
                  showOrderHistoryDialog(context, ref, so: entry.so),
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Order History'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('UUID', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        IndustrialIdText(entry.id, fontSize: 12, maxLines: 2),
        const SizedBox(height: 14),
        _inspectorField(context, 'Customer', entry.customer),
        _inspectorField(context, 'Containers', entry.type),
        _inspectorField(context, 'Carrier', entry.carrier),
        _inspectorField(context, 'Location', entry.location),
        _inspectorField(
          context,
          'Weight',
          formatWeightDisplay(entry.weight, empty: '—'),
        ),
        _inspectorField(context, 'Shipped by', entry.shippedBy ?? '—'),
        _inspectorField(context, 'Shipped at', _fmtDate(entry.shippedAt)),
        _inspectorField(context, "PM'd", entry.pmdEmail ?? '—'),
        _inspectorField(context, 'Comments', entry.comments ?? '—'),
      ],
    );
  }
}

Widget _inspectorField(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
