import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../../platform/photo_picker.dart';
import '../shared/widgets.dart';

Future<void> showStagingFormSheet(
  BuildContext context,
  WidgetRef ref, {
  StagingEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => StagingFormSheet(existing: existing),
  );
}

class StagingFormSheet extends ConsumerStatefulWidget {
  const StagingFormSheet({super.key, this.existing});
  final StagingEntry? existing;

  @override
  ConsumerState<StagingFormSheet> createState() => _StagingFormSheetState();
}

class _StagingFormSheetState extends ConsumerState<StagingFormSheet> {
  final _so = TextEditingController();
  final _customer = TextEditingController();
  final _location = TextEditingController();
  final _weight = TextEditingController();
  final _comments = TextEditingController();
  final _stagedBy = TextEditingController();
  final _skids = TextEditingController(text: '1');
  final _boxes = TextEditingController();
  final _crates = TextEditingController();
  final _pipe = TextEditingController();
  final _other = TextEditingController();
  String _statusUi = 'Partial';
  DateTime? _futureDate;
  final _photos = <PhotoBytes>[];
  bool _busy = false;
  final _picker = PhotoPickerService();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _so.text = e.so;
      _customer.text = e.customer;
      _location.text = e.location;
      _weight.text = e.weight ?? '';
      _comments.text = e.comments ?? '';
      _stagedBy.text = e.stagedBy ?? '';
      _statusUi = StatusRules.formatUi(e.status);
      if (StatusRules.isYmd(e.status) &&
          e.status != StatusRules.todayYmd() &&
          e.status != StatusRules.tomorrowYmd()) {
        _statusUi = 'Ship On Future Date';
        _futureDate = DateTime.tryParse(e.status);
      }
    }
  }

  @override
  void dispose() {
    _so.dispose();
    _customer.dispose();
    _location.dispose();
    _weight.dispose();
    _comments.dispose();
    _stagedBy.dispose();
    _skids.dispose();
    _boxes.dispose();
    _crates.dispose();
    _pipe.dispose();
    _other.dispose();
    super.dispose();
  }

  String? _ymd(DateTime? d) {
    if (d == null) return null;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final counts = countsFromControllers(
        skids: _skids,
        boxes: _boxes,
        crates: _crates,
        pipe: _pipe,
        other: _other,
      );
      final ops = ref.read(operationsProvider);
      if (widget.existing == null) {
        await ops.createStaging(
          so: _so.text,
          customer: _customer.text,
          location: _location.text,
          statusUi: _statusUi,
          containers: counts,
          weight: _weight.text,
          comments: _comments.text,
          stagedBy: _stagedBy.text,
          futureDateYmd: _ymd(_futureDate),
          photos: _photos,
        );
      } else {
        if (counts.total <= 0) {
          throw Exception('At least one container is required.');
        }
        if (await ops.soConflict(_so.text, ignoreId: widget.existing!.id)) {
          throw Exception('SO ${_so.text} already exists in Staging.');
        }
        await ops.updateStaging(widget.existing!.id, {
          'so': _so.text.trim(),
          'customer': _customer.text.trim(),
          'location': _location.text.trim(),
          'status': StatusRules.toDb(_statusUi, futureDateYmd: _ymd(_futureDate)),
          'type': counts.typeLabel,
          'qty': counts.total,
          'weight': _weight.text.trim(),
          'comments': _comments.text.trim(),
          'staged_by': _stagedBy.text.trim(),
        });
      }
      if (mounted) {
        Navigator.pop(context);
        showOk(context, widget.existing == null ? 'Entry created' : 'Entry updated');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  widget.existing == null
                      ? Icons.add_box_outlined
                      : Icons.edit_outlined,
                  color: SlstColors.brand,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.existing == null
                      ? 'New Staging Entry'
                      : 'Edit Staging Entry',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _so,
              decoration: const InputDecoration(labelText: 'SO #'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customer,
              decoration: const InputDecoration(labelText: 'Customer'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (e.g. A-01-A-1)',
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Status'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _statusUi,
                  items: [
                    for (final s in StatusRules.uiStatuses)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() => _statusUi = v ?? _statusUi),
                ),
              ),
            ),
            if (_statusUi == 'Ship On Future Date') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    initialDate: _futureDate ?? DateTime.now(),
                  );
                  if (d != null) setState(() => _futureDate = d);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _futureDate == null
                      ? 'Pick future ship date'
                      : 'Ship date: ${_futureDate!.toIso8601String().substring(0, 10)}',
                ),
              ),
            ],
            const SizedBox(height: 8),
            ContainerInputs(
              skids: _skids,
              boxes: _boxes,
              crates: _crates,
              pipe: _pipe,
              other: _other,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _weight,
              decoration: const InputDecoration(labelText: 'Weight (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stagedBy,
              decoration: const InputDecoration(labelText: 'Staged by'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comments,
              decoration: const InputDecoration(labelText: 'Comments'),
              maxLines: 3,
            ),
            if (widget.existing == null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final files = await _picker.pickPreferred();
                      setState(() => _photos.addAll(files));
                    },
                    icon: const Icon(Icons.photo_library),
                    label: Text('Photos (${_photos.length})'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final shot = await _picker.captureCamera();
                      if (shot != null) setState(() => _photos.add(shot));
                    },
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
