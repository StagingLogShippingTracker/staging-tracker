import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/widgets.dart';
import '../staging/ship_dialog.dart';
import '../staging/split_dialog.dart';
import '../staging/staging_form_sheet.dart';

/// Staging Verification Audit — restored from the legacy web Reports module.
///
/// Walks every staging entry in warehouse-location order and asks the user to
/// physically verify it. "No" opens a resolution menu (edit / move / ship /
/// return / delete / consolidate / split / settle later). Progress persists
/// across app restarts, and results export to CSV on completion.

enum AuditMode { all, aisle, nonAisle, discrepancies }

final _aisleRe = RegExp(r'^[A-Z]-\d{2}-[A-Z]-(1|2|1\+2)$', caseSensitive: false);
final _dateFmt = DateFormat('M/d/yy h:mm a');

String _auditModeName(AuditMode m) => switch (m) {
      AuditMode.all => 'all',
      AuditMode.aisle => 'aisle',
      AuditMode.nonAisle => 'non_aisle',
      AuditMode.discrepancies => 'discrepancies',
    };

AuditMode _auditModeFromName(String s) => switch (s) {
      'aisle' => AuditMode.aisle,
      'non_aisle' => AuditMode.nonAisle,
      'discrepancies' => AuditMode.discrepancies,
      _ => AuditMode.all,
    };

// ---------------------------------------------------------------------------
// Warehouse location ordering (port of the legacy locSortKey)
// ---------------------------------------------------------------------------

List<Comparable> _locKey(String? location) {
  final l = (location ?? '').toUpperCase();
  if (l.contains('PARTIAL BOX SHELF')) return [2, l];
  if (l.contains('BOX SHELF') && !l.contains('SHIPPING')) return [1, l];
  final aisle = RegExp(r'^([A-Z])-(\d{2})-([A-Z])-(1|2|1\+2)$').firstMatch(l);
  if (aisle != null) {
    final suffix = aisle.group(4) == '1' ? 1 : (aisle.group(4) == '2' ? 2 : 3);
    return [3, aisle.group(1)!, int.parse(aisle.group(2)!), aisle.group(3)!, suffix];
  }
  if (l.contains('SOUTH WALL')) return [4, l];
  if (RegExp(r'^W-\d+').hasMatch(l) || l.contains('SHIPPING')) return [5, l];
  if (l.contains('CORP DROP')) return [6, l];
  return [7, l];
}

/// Warehouse-walk ordering: box shelf → partial box shelf → aisles (bay by
/// bay) → south wall → shipping lanes → corp drop → everything else.
int compareAuditLocations(StagingEntry a, StagingEntry b) {
  final ka = _locKey(a.location), kb = _locKey(b.location);
  for (var i = 0; i < ka.length && i < kb.length; i++) {
    final c = ka[i].compareTo(kb[i]);
    if (c != 0) return c;
  }
  return ka.length.compareTo(kb.length);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> startVerificationAudit(
  BuildContext context,
  WidgetRef ref,
  AuditMode mode,
) async {
  final prefs = await ref.read(prefsProvider.future);
  if (!context.mounted) return;

  // Offer to resume an unfinished audit.
  final savedRaw = prefs.reportState;
  if (savedRaw != null) {
    try {
      final saved = jsonDecode(savedRaw) as Map<String, dynamic>;
      final queue = (saved['queue'] as List).cast<String>();
      final index = saved['index'] as int;
      if (queue.isNotEmpty && index < queue.length) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume Report?'),
            content: const Text(
              'You have an unfinished verification report. '
              'Continue where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Restart Fresh'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: SlstColors.success,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (resume == null || !context.mounted) return;
        if (resume) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _AuditDialog(
              prefs: prefs,
              mode: _auditModeFromName('${saved['filter']}'),
              queue: queue,
              index: index,
              results: [
                for (final r in (saved['results'] as List? ?? const []))
                  Map<String, String>.from(r as Map),
              ],
            ),
          );
          return;
        }
      }
    } catch (_) {
      // Corrupt saved state — fall through to a fresh run.
    }
    await prefs.clearReportState();
  }
  if (!context.mounted) return;

  final staging = ref.read(appDataProvider).staging;
  final source = switch (mode) {
    AuditMode.aisle =>
      staging.where((e) => _aisleRe.hasMatch(e.location)).toList(),
    AuditMode.nonAisle =>
      staging.where((e) => !_aisleRe.hasMatch(e.location)).toList(),
    AuditMode.discrepancies => staging
        .where((e) => prefs.discrepancyIds.contains(e.id))
        .toList(),
    AuditMode.all => [...staging],
  }
    ..sort(compareAuditLocations);

  if (source.isEmpty) {
    showOk(context, 'No staging entries match this report.');
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AuditDialog(
      prefs: prefs,
      mode: mode,
      queue: source.map((e) => e.id).toList(),
      index: 0,
      results: [],
    ),
  );
}

// ---------------------------------------------------------------------------
// Audit dialog
// ---------------------------------------------------------------------------

class _AuditDialog extends ConsumerStatefulWidget {
  const _AuditDialog({
    required this.prefs,
    required this.mode,
    required this.queue,
    required this.index,
    required this.results,
  });

  final LocalPrefs prefs;
  final AuditMode mode;
  final List<String> queue;
  final int index;
  final List<Map<String, String>> results;

  @override
  ConsumerState<_AuditDialog> createState() => _AuditDialogState();
}

class _AuditDialogState extends ConsumerState<_AuditDialog> {
  late List<String> _queue = [...widget.queue];
  late int _index = widget.index;
  late final List<Map<String, String>> _results = [...widget.results];
  bool _completed = false;

  StagingEntry? _entryById(String id) {
    for (final e in ref.read(appDataProvider).staging) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _save() {
    widget.prefs.setReportState(jsonEncode({
      'queue': _queue,
      'index': _index,
      'results': _results,
      'filter': _auditModeName(widget.mode),
    }));
  }

  void _record(StagingEntry item, String result) {
    _results.add({
      'so': item.so,
      'customer': item.customer,
      'location': item.location,
      'date': item.entryDate == null
          ? ''
          : _dateFmt.format(item.entryDate!.toLocal()),
      'result': result,
    });
    final ids = [...widget.prefs.discrepancyIds]..remove(item.id);
    if (result != 'Verified') ids.add(item.id);
    widget.prefs.setDiscrepancyIds(ids);
    setState(() => _index++);
    _save();
  }

  void _back() {
    if (_index <= 0) return;
    setState(() {
      if (_results.isNotEmpty) _results.removeLast();
      _index--;
    });
    _save();
  }

  /// Adds staging rows created mid-audit into the unprocessed tail of the
  /// queue, keeping warehouse-location order (legacy injectIntoReportQueue).
  void _injectNewEntries() {
    if (widget.mode == AuditMode.discrepancies) return;
    final staging = ref.read(appDataProvider).staging;
    final known = _queue.toSet();
    final fresh = staging.where((e) {
      if (known.contains(e.id)) return false;
      final isAisle = _aisleRe.hasMatch(e.location);
      if (widget.mode == AuditMode.aisle && !isAisle) return false;
      if (widget.mode == AuditMode.nonAisle && isAisle) return false;
      return true;
    }).toList();
    if (fresh.isEmpty) return;

    final tailEntries = [
      for (final id in _queue.skip(_index))
        if (_entryById(id) != null) _entryById(id)!,
      ...fresh,
    ]..sort(compareAuditLocations);
    setState(() {
      _queue = [..._queue.take(_index), ...tailEntries.map((e) => e.id)];
    });
    _save();
  }

  Future<void> _complete() async {
    if (_completed) return;
    _completed = true;
    await widget.prefs.clearReportState();
  }

  Future<void> _exportCsv({required bool discrepanciesOnly}) async {
    final rows = discrepanciesOnly
        ? _results.where((r) => r['result'] != 'Verified').toList()
        : _results;
    final buf = StringBuffer('SO,Customer,Location,Entry Date,Result\n');
    for (final r in rows) {
      String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
      buf.writeln(
        '${esc(r['so'])},${esc(r['customer'])},${esc(r['location'])},'
        '${esc(r['date'])},${esc(r['result'])}',
      );
    }
    final csv = buf.toString();
    final name = discrepanciesOnly
        ? 'Verification_Discrepancies.csv'
        : 'Verification_Results.csv';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $name',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (path == null) return;
      // Desktop save dialogs only return the path; write the file ourselves.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(path).writeAsString(csv);
      }
      if (mounted) showOk(context, 'Saved $name');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // -------------------------------------------------------------------------
  // "No" resolution flow
  // -------------------------------------------------------------------------

  Future<void> _handleNo(StagingEntry item) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => _AuditActionMenu(so: item.so),
    );
    if (action == null || !mounted) return;
    final ops = ref.read(operationsProvider);

    switch (action) {
      case 'edit':
        await showStagingFormSheet(context, ref, existing: item);
      case 'change_loc':
        final newLoc = await _promptNewLocation(item);
        if (newLoc == null || newLoc.isEmpty) return;
        try {
          await ops.updateStaging(item.id, {'so': item.so, 'location': newLoc});
          _record(item, 'Fixed via Location Change ($newLoc)');
        } catch (e) {
          if (mounted) showError(context, e);
        }
      case 'consolidate':
        final same = ref
            .read(appDataProvider)
            .staging
            .where((e) =>
                e.so.trim().toLowerCase() == item.so.trim().toLowerCase())
            .toList();
        if (same.length < 2) {
          if (mounted) {
            showOk(context, 'No other staging rows share SO ${item.so}.');
          }
          return;
        }
        final ok = await confirmDialog(
          context,
          title: 'Consolidate SO ${item.so}?',
          message: 'Merge ${same.length} staging rows into this entry.',
          confirmLabel: 'Consolidate',
          confirmColor: SlstColors.purple,
        );
        if (!ok || !mounted) return;
        try {
          // Keep the row being audited as the surviving entry.
          await ops.consolidateStaging(
            [item, ...same.where((e) => e.id != item.id)],
          );
          if (mounted) showOk(context, 'Consolidated SO ${item.so}');
        } catch (e) {
          if (mounted) showError(context, e);
        }
      case 'split':
        await showSplitDialog(context, ref, entry: item);
        _injectNewEntries();
      case 'ship':
        await showShipDialog(context, ref, entry: item);
      case 'return':
        await showReturnDialog(context, ref, entry: item);
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: 'Delete entry?',
          message: 'Delete staging entry for SO ${item.so}?',
          confirmLabel: 'Delete',
        );
        if (!ok || !mounted) return;
        try {
          await ops.deleteRecord(table: 'staging', id: item.id, so: item.so);
        } catch (e) {
          if (mounted) showError(context, e);
        }
      case 'settle':
        _record(item, 'Discrepancy - Unresolved');
    }
    if (mounted) setState(() {});
  }

  Future<String?> _promptNewLocation(StagingEntry item) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'New Location',
            hintText: 'Current: ${item.location}',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save & Continue'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Skip queue ids that no longer exist (shipped / deleted / consolidated).
    ref.watch(appDataProvider);
    while (_index < _queue.length && _entryById(_queue[_index]) == null) {
      _index++;
    }

    if (_index >= _queue.length) {
      _complete();
      return _buildCompletion(context);
    }
    _save();

    final item = _entryById(_queue[_index])!;
    return _buildItem(context, item);
  }

  Widget _buildCompletion(BuildContext context) {
    final verified = _results.where((r) => r['result'] == 'Verified').length;
    final issues = _results.length - verified;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_outlined,
                  size: 44, color: SlstColors.success),
              const SizedBox(height: 10),
              const Text(
                'Staging Verification Report Complete!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '$verified verified · $issues discrepanc${issues == 1 ? 'y' : 'ies'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: SlstColors.muted),
              ),
              const SizedBox(height: 18),
              if (_results.isNotEmpty)
                PillButton(
                  label: 'Export Results CSV',
                  icon: Icons.download,
                  color: SlstColors.info,
                  onPressed: () => _exportCsv(discrepanciesOnly: false),
                ),
              if (issues > 0) ...[
                const SizedBox(height: 8),
                PillButton(
                  label: 'Export Discrepancies CSV',
                  icon: Icons.report_gmailerrorred,
                  color: SlstColors.danger,
                  onPressed: () => _exportCsv(discrepanciesOnly: true),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, StagingEntry item) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? SlstColors.darkMuted : SlstColors.muted;

    Widget infoRow(String label, String value, {Color? color, FontWeight? w}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const Spacer(),
            Flexible(
              flex: 3,
              child: Text(
                value.isEmpty ? '—' : value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: w ?? FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'STAGING VERIFICATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: SlstColors.muted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pause & close (progress is saved)',
                      onPressed: () {
                        _save();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Is this order still staged here?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  item.location.isEmpty ? 'No Location' : item.location,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: SlstColors.brand,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: dark
                        ? SlstColors.darkSurfaceMuted
                        : SlstColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dark ? SlstColors.darkBorder : SlstColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      infoRow('SO', item.so, w: FontWeight.w700),
                      infoRow('Customer', item.customer),
                      infoRow(
                        'Entry Date',
                        item.entryDate == null
                            ? '—'
                            : _dateFmt.format(item.entryDate!.toLocal()),
                      ),
                      infoRow('Containers', item.type,
                          color: SlstColors.info, w: FontWeight.w700),
                      infoRow('Status', StatusRules.formatUi(item.status)),
                      infoRow('Staged By', item.stagedBy ?? ''),
                      if ((item.comments ?? '').trim().isNotEmpty)
                        infoRow('Comments', item.comments!.trim()),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: SlstColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => _record(item, 'Verified'),
                        child: const Text('Yes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: SlstColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => _handleNo(item),
                        child: const Text('No'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: SlstColors.slate,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _index > 0 ? _back : null,
                        child: const Icon(Icons.undo, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PillButton(
                  label: 'Add Staging Entry',
                  icon: Icons.add,
                  color: SlstColors.purple,
                  onPressed: () async {
                    await showStagingFormSheet(context, ref);
                    _injectNewEntries();
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Progress: ${_index + 1} of ${_queue.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resolution menu shown when the answer is "No"
// ---------------------------------------------------------------------------

class _AuditActionMenu extends StatelessWidget {
  const _AuditActionMenu({required this.so});

  final String so;

  @override
  Widget build(BuildContext context) {
    const actions = [
      (id: 'edit', label: 'Edit Entry', icon: Icons.edit_outlined, color: SlstColors.warning),
      (id: 'change_loc', label: 'Change Location', icon: Icons.place_outlined, color: SlstColors.info),
      (id: 'consolidate', label: 'Consolidate', icon: Icons.merge_type, color: SlstColors.purple),
      (id: 'split', label: 'Split', icon: Icons.call_split, color: SlstColors.blueBright),
      (id: 'ship', label: 'Shipped', icon: Icons.local_shipping_outlined, color: SlstColors.success),
      (id: 'return', label: 'Return to Stock', icon: Icons.assignment_return_outlined, color: Color(0xFFEAB308)),
      (id: 'delete', label: 'Delete', icon: Icons.delete_outline, color: SlstColors.danger),
      (id: 'settle', label: 'Settle Later', icon: Icons.schedule, color: SlstColors.slate),
    ];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Resolve SO $so',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'How should this discrepancy be handled?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: SlstColors.muted),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in actions)
                        SizedBox(
                          width: w,
                          child: PillButton(
                            label: a.label,
                            icon: a.icon,
                            color: a.color,
                            compact: true,
                            onPressed: () => Navigator.pop(context, a.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
