import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart' as shared;

import '../../core/format_weight.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/widgets.dart';

final _stampFmt = DateFormat('MMM d, y · h:mm a');
final _dayFmt = DateFormat('yyyy-MM-dd');
final _fileStampFmt = DateFormat('yyyyMMdd_HHmm');

String _escCsv(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';

String _typeLabel(String type) {
  switch (type) {
    case 'ship_confirm':
      return 'Ship confirm';
    case 'quick_ship':
      return 'Quick ship';
    case 'return_to_stock':
      return 'Return to stock';
    case 'po_notification':
      return 'PO';
    case 'bulk_po_notification':
      return 'Bulk PO';
    case 'return_notification':
      return 'Return';
    default:
      return type;
  }
}

String? _payloadStr(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Labeled message-body rows from structured notify-pm payload (not raw JSON).
List<({String label, String value})> _messageBodyRows(
  shared.NotificationLogEntry entry,
) {
  final p = entry.payload;
  final rows = <({String label, String value})>[];
  void add(String label, String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    rows.add((label: label, value: v));
  }

  switch (entry.notificationType) {
    case 'bulk_po_notification':
      final pos = p['pos'];
      if (pos is List && pos.isNotEmpty) {
        for (var i = 0; i < pos.length; i++) {
          final raw = pos[i];
          final item = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          final n = i + 1;
          add('PO ($n)', _payloadStr(item, const ['po', 'po_number']));
          add(
            'Quantity ($n)',
            _payloadStr(item, const ['qty', 'quantity', 'amount']),
          );
          add('Vendor ($n)', _payloadStr(item, const ['vendor', 'customer']));
          add(
            'Details ($n)',
            _payloadStr(item, const ['details', 'notes', 'comments']),
          );
          add(
            'Container ($n)',
            _payloadStr(item, const ['containers', 'container', 'type']),
          );
        }
      } else {
        add('PO', entry.po ?? _payloadStr(p, const ['po']));
        add('Vendor', entry.vendor ?? _payloadStr(p, const ['vendor']));
      }
      break;
    case 'po_notification':
      add('PO', entry.po ?? _payloadStr(p, const ['po', 'po_number']));
      add(
        'Quantity',
        _payloadStr(p, const ['qty', 'quantity', 'amount']),
      );
      add(
        'Vendor',
        entry.vendor ?? _payloadStr(p, const ['vendor', 'customer']),
      );
      add(
        'Details',
        _payloadStr(p, const ['details', 'notes', 'comments']),
      );
      add(
        'Container',
        _payloadStr(p, const ['containers', 'container', 'type']),
      );
      add('Linked SO', _payloadStr(p, const ['so', 'linked_so', 'linkedSo']));
      break;
    case 'ship_confirm':
    case 'quick_ship':
      add('SO', entry.so ?? _payloadStr(p, const ['so', 'so_number']));
      add(
        'Customer',
        entry.customer ?? _payloadStr(p, const ['customer']),
      );
      add('Carrier', entry.carrier ?? _payloadStr(p, const ['carrier']));
      add(
        'Container',
        _payloadStr(p, const ['containers', 'container', 'type']),
      );
      add('Weight', formatWeightDisplay(_payloadStr(p, const ['weight'])));
      add(
        'Details',
        _payloadStr(p, const ['comments', 'details', 'notes']),
      );
      add(
        'Shipped by',
        _payloadStr(p, const ['shipped_by', 'shippedBy']),
      );
      add(
        'Shipped at',
        _payloadStr(p, const ['shipped_at', 'shippedAt']),
      );
      break;
    case 'return_to_stock':
      add('SO', entry.so ?? _payloadStr(p, const ['so', 'so_number']));
      add(
        'Customer',
        entry.customer ?? _payloadStr(p, const ['customer']),
      );
      add('Reason', _payloadStr(p, const ['reason']));
      add('Picked by', _payloadStr(p, const ['picked_by', 'pickedBy']));
      add(
        'Returned by',
        _payloadStr(p, const ['returned_by', 'returnedBy']),
      );
      break;
    case 'return_notification':
      add('SO', entry.so ?? _payloadStr(p, const ['so', 'so_number']));
      add(
        'Customer',
        entry.customer ?? _payloadStr(p, const ['customer']),
      );
      add(
        'Details',
        _payloadStr(p, const ['details', 'notes', 'comments']),
      );
      break;
    default:
      add('SO', entry.so ?? _payloadStr(p, const ['so']));
      add('PO', entry.po ?? _payloadStr(p, const ['po']));
      add(
        'Customer',
        entry.customer ?? _payloadStr(p, const ['customer']),
      );
      add('Vendor', entry.vendor ?? _payloadStr(p, const ['vendor']));
      add('Carrier', entry.carrier ?? _payloadStr(p, const ['carrier']));
      add(
        'Details',
        _payloadStr(p, const ['details', 'comments', 'notes', 'reason']),
      );
  }
  return rows;
}

class NotificationLogPanel extends ConsumerStatefulWidget {
  const NotificationLogPanel({super.key});

  @override
  ConsumerState<NotificationLogPanel> createState() =>
      _NotificationLogPanelState();
}

class _NotificationLogPanelState extends ConsumerState<NotificationLogPanel> {
  int? _year;
  int? _month;
  String? _pmName;
  String? _type;
  String? _status;
  String? _channel;
  DateTime? _from;
  DateTime? _to;
  String _search = '';
  shared.NotificationLogSort _sortBy = shared.NotificationLogSort.createdAt;
  bool _ascending = false;
  bool _loading = true;
  String? _error;
  List<shared.NotificationLogEntry> _rows = const [];
  List<String> _pmNames = const [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default: no date filter so recent deliveries always appear.
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  shared.NotificationLogQuery get _query => shared.NotificationLogQuery(
        from: _from,
        to: _to == null
            ? null
            : DateTime(_to!.year, _to!.month, _to!.day).add(
                const Duration(days: 1),
              ),
        year: _from == null && _to == null ? _year : null,
        month: _from == null && _to == null ? _month : null,
        pmName: _pmName,
        notificationType: _type,
        status: _status,
        channel: _channel,
        search: _search.trim().isEmpty ? null : _search.trim(),
        sortBy: _sortBy,
        ascending: _ascending,
      );

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(notificationLogRepoProvider);
      final results = await Future.wait([
        repo.list(_query),
        repo.distinctPmNames(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<shared.NotificationLogEntry>;
        _pmNames = results[1] as List<String>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _from = picked;
      _year = null;
      _month = null;
    });
    await _reload();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? DateTime.now(),
      firstDate: _from ?? DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _to = picked;
      _year = null;
      _month = null;
    });
    await _reload();
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) {
      showError(context, 'No rows to export for the current filters.');
      return;
    }
    final buf = StringBuffer(
      'Date/Time,Type,Status,Channel,PM Name,PM Email,SO,PO,Customer,Vendor,'
      'Carrier,Subject,Sent By,Error,Message Body\n',
    );
    for (final r in _rows) {
      final bodyText = _messageBodyRows(r)
          .map((e) => '${e.label}: ${e.value}')
          .join(' | ');
      buf.writeln(
        [
          _escCsv(
            r.createdAt == null ? '' : _stampFmt.format(r.createdAt!.toLocal()),
          ),
          _escCsv(r.typeLabel),
          _escCsv(r.status),
          _escCsv(r.channel),
          _escCsv(r.pmName),
          _escCsv(r.pmEmail),
          _escCsv(r.so),
          _escCsv(r.po),
          _escCsv(r.customer),
          _escCsv(r.vendor),
          _escCsv(r.carrier),
          _escCsv(r.subject),
          _escCsv(r.sentBy),
          _escCsv(r.errorDetail),
          _escCsv(bodyText),
        ].join(','),
      );
    }
    final csv = buf.toString();
    final name =
        'Staging_Shipping_Log_Notification_Log_${_fileStampFmt.format(DateTime.now())}.csv';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save notification log CSV',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (path == null) return;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await File(path).writeAsString(csv);
      }
      if (mounted) showOk(context, 'Saved $name');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _exportPrintableHtml() async {
    if (_rows.isEmpty) {
      showError(context, 'No rows to export for the current filters.');
      return;
    }
    final filterBits = <String>[];
    if (_pmName != null) filterBits.add('PM: $_pmName');
    if (_type != null) filterBits.add('Type: ${_typeLabel(_type!)}');
    if (_year != null) {
      filterBits.add(
        _month == null
            ? 'Year: $_year'
            : 'Month: ${DateFormat.MMMM().format(DateTime(_year!, _month!))} $_year',
      );
    }
    if (_from != null) filterBits.add('From: ${_dayFmt.format(_from!)}');
    if (_to != null) filterBits.add('To: ${_dayFmt.format(_to!)}');
    if (_status != null) filterBits.add('Status: $_status');
    if (_channel != null) filterBits.add('Channel: $_channel');
    if (_search.trim().isNotEmpty) filterBits.add('Search: ${_search.trim()}');

    final rowsHtml = _rows.map((r) {
      final when = r.createdAt == null
          ? '—'
          : _stampFmt.format(r.createdAt!.toLocal());
      String cell(String? v) => (v == null || v.isEmpty)
          ? '—'
          : v
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');
      return '<tr>'
          '<td>$when</td>'
          '<td>${cell(r.typeLabel)}</td>'
          '<td>${cell(r.status)}</td>'
          '<td>${cell(r.channel)}</td>'
          '<td>${cell(r.pmName)}</td>'
          '<td>${cell(r.pmEmail)}</td>'
          '<td>${cell(r.so)}</td>'
          '<td>${cell(r.po)}</td>'
          '<td>${cell(r.customer ?? r.vendor)}</td>'
          '<td>${cell(r.carrier)}</td>'
          '<td>${cell(r.subject)}</td>'
          '<td>${cell(r.sentBy)}</td>'
          '</tr>';
    }).join('\n');

    final html = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Swift Staging &amp; Shipping Log — Notification Log</title>
<style>
  @page { size: letter landscape; margin: 0.5in; }
  body { font-family: Segoe UI, Arial, sans-serif; color: #1a1a1a; margin: 24px; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .meta { color: #555; font-size: 12px; margin-bottom: 16px; }
  table { border-collapse: collapse; width: 100%; font-size: 11px; }
  th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: left; vertical-align: top; }
  th { background: #1e3a5f; color: #fff; }
  tr:nth-child(even) { background: #f5f7fa; }
  .actions { margin: 16px 0; }
  @media print { .actions { display: none; } body { margin: 0; } }
</style>
</head>
<body>
  <div class="actions">
    <button onclick="window.print()">Print / Save as PDF</button>
  </div>
  <h1>Swift Staging &amp; Shipping Log — Notification Log</h1>
  <div class="meta">
    ${_rows.length} notification(s)
    ${filterBits.isEmpty ? '' : ' · ${filterBits.join(' · ')}'}
    · Generated ${_stampFmt.format(DateTime.now())}
  </div>
  <table>
    <thead>
      <tr>
        <th>Date/Time</th><th>Type</th><th>Status</th><th>Channel</th>
        <th>PM</th><th>Email</th><th>SO</th><th>PO</th>
        <th>Customer/Vendor</th><th>Carrier</th><th>Subject</th><th>Sent by</th>
      </tr>
    </thead>
    <tbody>
$rowsHtml
    </tbody>
  </table>
  <script>window.addEventListener('load', () => setTimeout(() => window.print(), 300));</script>
</body>
</html>
''';

    try {
      final dir = await getTemporaryDirectory();
      final name =
          'Staging_Shipping_Log_Notification_Log_${_fileStampFmt.format(DateTime.now())}.html';
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsString(html);
      final result = await OpenFilex.open(file.path);
      if (mounted) {
        if (result.type == ResultType.done) {
          showOk(context, 'Opened printable report (Print → Save as PDF)');
        } else {
          showOk(context, 'Saved printable HTML: ${file.path}');
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _showDetail(shared.NotificationLogEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final when = entry.createdAt == null
            ? '—'
            : _stampFmt.format(entry.createdAt!.toLocal());
        Widget row(String label, String? value) {
          if (value == null || value.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(child: SelectableText(value)),
              ],
            ),
          );
        }

        final messageRows = _messageBodyRows(entry);

        return AlertDialog(
          title: Text(entry.typeLabel),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row('When', when),
                  row('Status', entry.status),
                  row('Channel', entry.channel),
                  row('PM', entry.pmName),
                  row('Email', entry.pmEmail),
                  row('SO', entry.so),
                  row('PO', entry.po),
                  row('Customer', entry.customer),
                  row('Vendor', entry.vendor),
                  row('Carrier', entry.carrier),
                  row('Subject', entry.subject),
                  row('Sent by', entry.sentBy),
                  row('Error', entry.errorDetail),
                  const SizedBox(height: 8),
                  const Text(
                    'Message',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (messageRows.isEmpty)
                    const Text('No message details recorded.')
                  else
                    ...messageRows.map((r) => row(r.label, r.value)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final years = [
      for (var y = DateTime.now().year; y >= 2024; y--) y,
    ];
    final pmOptions = {
      ..._pmNames,
      ?_pmName,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Parent Notifications screen already scrolls — do not nest another ListView
    // (unbounded height collapses this panel to empty in release builds).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Every notify-pm email delivery is logged with type, PM, and message fields. '
          'Export uses the current filters.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _year,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Any'),
                      ),
                      ...years.map(
                        (y) => DropdownMenuItem(value: y, child: Text('$y')),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _year = v;
                        if (v == null) _month = null;
                        _from = null;
                        _to = null;
                      });
                      _reload();
                    },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _month,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Any'),
                      ),
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(DateFormat.MMMM().format(DateTime(2000, m))),
                        ),
                    ],
                    onChanged: _year == null
                        ? null
                        : (v) {
                            setState(() {
                              _month = v;
                              _from = null;
                              _to = null;
                            });
                            _reload();
                          },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _pmName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'PM name',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All PMs'),
                      ),
                      ...pmOptions.map(
                        (n) => DropdownMenuItem(value: n, child: Text(n)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _pmName = v);
                      _reload();
                    },
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All types'),
                      ),
                      ...shared.NotificationLogRepository.knownTypes.map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(t)),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _type = v);
                      _reload();
                    },
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: 'sent', child: Text('Sent')),
                      DropdownMenuItem(value: 'failed', child: Text('Failed')),
                      DropdownMenuItem(
                        value: 'partial',
                        child: Text('Partial'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v);
                      _reload();
                    },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _channel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Channel',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: 'email', child: Text('Email')),
                    ],
                    onChanged: (v) {
                      setState(() => _channel = v);
                      _reload();
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<shared.NotificationLogSort>(
                    initialValue: _sortBy,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: shared.NotificationLogSort.createdAt,
                        child: Text('Date/time'),
                      ),
                      DropdownMenuItem(
                        value: shared.NotificationLogSort.pmName,
                        child: Text('PM name'),
                      ),
                      DropdownMenuItem(
                        value: shared.NotificationLogSort.notificationType,
                        child: Text('Type'),
                      ),
                      DropdownMenuItem(
                        value: shared.NotificationLogSort.status,
                        child: Text('Status'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _sortBy = v);
                      _reload();
                    },
                  ),
                ),
                FilterChip(
                  label: Text(_ascending ? 'Ascending' : 'Descending'),
                  selected: _ascending,
                  onSelected: (v) {
                    setState(() => _ascending = v);
                    _reload();
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                    _from == null ? 'From date' : _dayFmt.format(_from!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.event_available, size: 18),
                  label: Text(
                    _to == null ? 'To date' : _dayFmt.format(_to!),
                  ),
                ),
                if (_from != null || _to != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _from = null;
                        _to = null;
                        _year = null;
                        _month = null;
                      });
                      _reload();
                    },
                    child: const Text('Clear dates'),
                  ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search SO / PO / customer',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Apply',
                        onPressed: () {
                          setState(() => _search = _searchCtrl.text);
                          _reload();
                        },
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    onSubmitted: (v) {
                      setState(() => _search = v);
                      _reload();
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: SlstColors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _rows.isEmpty ? null : _exportCsv,
                  icon: const Icon(Icons.table_view),
                  label: const Text('Export CSV'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: IndustrialTheme.chromeAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _rows.isEmpty ? null : _exportPrintableHtml,
                  icon: const Icon(Icons.print),
                  label: const Text('Print / PDF'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _loading
              ? 'Loading…'
              : '${_rows.length} notification${_rows.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: scheme.error),
              title: Text('Failed to load log', style: TextStyle(color: scheme.error)),
              subtitle: Text(_error!),
            ),
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_rows.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: const ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('No notifications in this filter range'),
              subtitle: Text(
                'New sends appear here after notify-pm delivers successfully '
                '(or logs a failure).',
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStatePropertyAll(
                  IndustrialTheme.chromeOf(context).header.withValues(alpha: 0.9),
                ),
                columns: const [
                  DataColumn(label: Text('When')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('PM')),
                  DataColumn(label: Text('SO / PO')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Channel')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Subject')),
                ],
                rows: [
                  for (var i = 0; i < _rows.length; i++)
                    DataRow(
                      color: WidgetStatePropertyAll(
                        i.isOdd
                            ? IndustrialTheme.chromeOf(context).header.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                      onSelectChanged: (_) => _showDetail(_rows[i]),
                      cells: [
                        DataCell(
                          Text(
                            _rows[i].createdAt == null
                                ? '—'
                                : _stampFmt.format(
                                    _rows[i].createdAt!.toLocal(),
                                  ),
                          ),
                        ),
                        DataCell(Text(_rows[i].typeLabel)),
                        DataCell(
                          Text(
                            _rows[i].pmName?.isNotEmpty == true
                                ? _rows[i].pmName!
                                : (_rows[i].pmEmail ?? '—'),
                          ),
                        ),
                        DataCell(
                          Text(
                            [
                              if (_rows[i].so?.isNotEmpty == true)
                                'SO ${_rows[i].so}',
                              if (_rows[i].po?.isNotEmpty == true)
                                'PO ${_rows[i].po}',
                            ].join(' · ').ifEmpty('—'),
                          ),
                        ),
                        DataCell(
                          Text(
                            (_rows[i].customer?.isNotEmpty == true
                                    ? _rows[i].customer
                                    : _rows[i].vendor) ??
                                '—',
                          ),
                        ),
                        DataCell(Text(_rows[i].channel)),
                        DataCell(Text(_rows[i].status)),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              _rows[i].subject ?? '—',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Tap a row for message details.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
