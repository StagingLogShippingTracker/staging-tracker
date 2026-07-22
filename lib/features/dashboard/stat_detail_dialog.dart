import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/order_history_dialog.dart';
import '../shared/widgets.dart';

/// Detail windows attached to the dashboard KPI stat cards, restored from the
/// legacy web app (`statDetailModal`). Each mode lists the active staging
/// entries — either grouped by SO or expanded per physical container.
enum StatDetailMode { orders, containers, skid, box, crate, pipe, other }

typedef _ModeConfig = ({
  String title,
  String entryLabel,
  bool flat,
  String? filter,
});

const Map<StatDetailMode, _ModeConfig> _modeConfigs = {
  StatDetailMode.orders: (
    title: 'Active Staging Orders',
    entryLabel: 'Staging Entry',
    flat: false,
    filter: null,
  ),
  StatDetailMode.containers: (
    title: 'Active Staging Containers',
    entryLabel: 'Container',
    flat: true,
    filter: null,
  ),
  StatDetailMode.skid: (
    title: 'Active Staging Skids',
    entryLabel: 'Container',
    flat: false,
    filter: 'Skid',
  ),
  StatDetailMode.box: (
    title: 'Active Staging Boxes',
    entryLabel: 'Container',
    flat: false,
    filter: 'Box',
  ),
  StatDetailMode.crate: (
    title: 'Active Staging Crates',
    entryLabel: 'Container',
    flat: false,
    filter: 'Crate',
  ),
  StatDetailMode.pipe: (
    title: 'Active Staging Pipe/Rod',
    entryLabel: 'Container',
    flat: false,
    filter: 'Pipe/Rod',
  ),
  StatDetailMode.other: (
    title: 'Active Staging Other',
    entryLabel: 'Container',
    flat: false,
    filter: 'Other',
  ),
};

enum _StatSort { so, urgency, dateDesc, dateAsc, status, location, customer }

const _sortLabels = [
  (_StatSort.so, 'Sort: SO# A-Z'),
  (_StatSort.urgency, 'Sort: Urgency'),
  (_StatSort.dateDesc, 'Sort: Newest First'),
  (_StatSort.dateAsc, 'Sort: Oldest First'),
  (_StatSort.status, 'Sort: Shipping Status'),
  (_StatSort.location, 'Sort: Location A-Z'),
  (_StatSort.customer, 'Sort: Customer A-Z'),
];

Future<void> showStatDetailDialog(BuildContext context, StatDetailMode mode) {
  return showDialog<void>(
    context: context,
    builder: (context) => _StatDetailDialog(mode: mode),
  );
}

/// One expanded row: an entry plus the container label being represented.
typedef _DetailItem = ({StagingEntry entry, String containerLabel});

class _StatDetailDialog extends ConsumerStatefulWidget {
  const _StatDetailDialog({required this.mode});

  final StatDetailMode mode;

  @override
  ConsumerState<_StatDetailDialog> createState() => _StatDetailDialogState();
}

class _StatDetailDialogState extends ConsumerState<_StatDetailDialog> {
  static final _dateFmt = DateFormat('M/d/yy h:mm a');

  final _search = TextEditingController();
  _StatSort _sort = _StatSort.so;
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_DetailItem> _expand(StagingEntry e, String? filter) {
    final counts = ContainerCounts.parse(e.type);
    final specs = [
      (n: counts.skids, type: 'Skid'),
      (n: counts.boxes, type: 'Box'),
      (n: counts.crates, type: 'Crate'),
      (n: counts.pipe, type: 'Pipe/Rod'),
      (n: counts.other, type: 'Other'),
    ];
    final out = <_DetailItem>[];
    for (final s in specs) {
      if (filter != null && s.type != filter) continue;
      for (var i = 0; i < s.n; i++) {
        out.add((entry: e, containerLabel: '1 ${s.type}'));
      }
    }
    return out;
  }

  int _compare(StagingEntry a, StagingEntry b) {
    switch (_sort) {
      case _StatSort.dateDesc:
        return (b.entryDate ?? DateTime(1970)).compareTo(
          a.entryDate ?? DateTime(1970),
        );
      case _StatSort.dateAsc:
        return (a.entryDate ?? DateTime(1970)).compareTo(
          b.entryDate ?? DateTime(1970),
        );
      case _StatSort.customer:
        return a.customer.toLowerCase().compareTo(b.customer.toLowerCase());
      case _StatSort.location:
        return a.location.toLowerCase().compareTo(b.location.toLowerCase());
      case _StatSort.status:
        return StatusRules.formatUi(
          a.status,
        ).compareTo(StatusRules.formatUi(b.status));
      case _StatSort.urgency:
        final u =
            StatusRules.urgencyWeight(b.status) -
            StatusRules.urgencyWeight(a.status);
        if (u != 0) return u;
        return (b.entryDate ?? DateTime(1970)).compareTo(
          a.entryDate ?? DateTime(1970),
        );
      case _StatSort.so:
        return compareNatural(a.so, b.so);
    }
  }

  /// Natural SO compare ("SO2" < "SO10").
  static int compareNatural(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final am = re.allMatches(a.toLowerCase()).toList();
    final bm = re.allMatches(b.toLowerCase()).toList();
    for (var i = 0; i < am.length && i < bm.length; i++) {
      final as = am[i].group(0)!, bs = bm[i].group(0)!;
      final an = int.tryParse(as), bn = int.tryParse(bs);
      final c = (an != null && bn != null)
          ? an.compareTo(bn)
          : as.compareTo(bs);
      if (c != 0) return c;
    }
    return am.length.compareTo(bm.length);
  }

  bool _matches(StagingEntry e) {
    if (_q.isEmpty) return true;
    return e.so.toLowerCase().contains(_q) ||
        e.customer.toLowerCase().contains(_q);
  }

  Widget _historyLink(String so) {
    return Tooltip(
      message: 'Open Order History for SO $so',
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: SlstColors.brand,
          textStyle: TextStyle(
            fontFamily: kBodyFontFamily,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
        onPressed: () => showOrderHistoryDialog(context, ref, so: so),
        child: Text(so),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _modeConfigs[widget.mode]!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final staging = ref.watch(appDataProvider).staging.where(_matches).toList();
    final sortPicker = DropdownButtonFormField<_StatSort>(
      initialValue: _sort,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Sort', isDense: true),
      style: TextStyle(
        fontFamily: kBodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: dark ? SlstColors.darkInk : SlstColors.ink,
      ),
      items: [
        for (final (v, label) in _sortLabels)
          DropdownMenuItem(value: v, child: Text(label)),
      ],
      onChanged: (v) => setState(() => _sort = v ?? _StatSort.so),
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.all(narrow ? 16 : 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cfg.title,
                      maxLines: narrow ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (narrow) ...[
                sortPicker,
                const SizedBox(height: 10),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: 220, child: sortPicker),
                ),
              if (!narrow) const SizedBox(height: 10),
              SearchField(
                controller: _search,
                hint: 'Quick Search SO or Customer…',
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: cfg.flat
                    ? _buildFlatList(staging, cfg)
                    : _buildGroupedList(staging, cfg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlatList(List<StagingEntry> staging, _ModeConfig cfg) {
    final rows = <_DetailItem>[];
    for (final e in staging) {
      rows.addAll(_expand(e, cfg.filter));
    }
    rows.sort((a, b) => _compare(a.entry, b.entry));
    if (rows.isEmpty) return const _EmptyNote();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 8,
          columnSpacing: 18,
          headingRowHeight: 38,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          columns: const [
            DataColumn(label: Text('SO')),
            DataColumn(label: Text('CUSTOMER')),
            DataColumn(label: Text('CONTAINER')),
            DataColumn(label: Text('LOCATION')),
            DataColumn(label: Text('ENTRY DATE')),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(_historyLink(r.entry.so)),
                  DataCell(Text(r.entry.customer)),
                  DataCell(Text(r.containerLabel)),
                  DataCell(
                    Text(
                      r.entry.location,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Text(
                      r.entry.entryDate == null
                          ? '—'
                          : _dateFmt.format(r.entry.entryDate!.toLocal()),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(List<StagingEntry> staging, _ModeConfig cfg) {
    final groups = <String, List<_DetailItem>>{};
    for (final e in staging) {
      final items = widget.mode == StatDetailMode.orders
          ? <_DetailItem>[(entry: e, containerLabel: e.type)]
          : _expand(e, cfg.filter);
      if (items.isEmpty) continue;
      groups
          .putIfAbsent(e.so.isEmpty ? 'Unknown SO' : e.so, () => [])
          .addAll(items);
    }
    if (groups.isEmpty) return const _EmptyNote();

    final keys = groups.keys.toList();
    if (_sort == _StatSort.so) {
      keys.sort(compareNatural);
    } else {
      keys.sort(
        (a, b) => _compare(groups[a]!.first.entry, groups[b]!.first.entry),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        for (final so in keys)
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.only(left: 16, bottom: 6),
            shape: const Border(),
            title: Row(
              children: [
                Flexible(child: _historyLink(so)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${groups[so]!.length} ${cfg.entryLabel}(s)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SlstColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              for (final r
                  in groups[so]!..sort((a, b) => _compare(a.entry, b.entry)))
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    '${r.entry.customer} · ${r.containerLabel}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${r.entry.location} · '
                    '${r.entry.entryDate == null ? '—' : _dateFmt.format(r.entry.entryDate!.toLocal())}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: StatusChip(dbStatus: r.entry.status, compact: true),
                ),
            ],
          ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(28),
      child: Center(child: Text('No matching staging entries.')),
    );
  }
}
