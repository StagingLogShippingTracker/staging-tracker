import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/consolidation_undo.dart';
import '../../domain/location_intelligence.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../../platform/photo_picker.dart';
import '../shared/entry_suggestion_fields.dart';
import '../shared/location_selector.dart';
import '../shared/so_advisories.dart';
import '../shared/widgets.dart';

Future<void> showStagingFormSheet(
  BuildContext context,
  WidgetRef ref, {
  StagingEntry? existing,
  String? initialSo,
  String? initialCustomer,
  bool allowExistingSo = false,
  bool lockIdentity = false,
}) {
  return showAdaptivePopup<void>(
    context,
    maxWidth: 680,
    builder: (_) => StagingFormSheet(
      existing: existing,
      initialSo: initialSo,
      initialCustomer: initialCustomer,
      allowExistingSo: allowExistingSo,
      lockIdentity: lockIdentity,
    ),
  );
}

class StagingFormSheet extends ConsumerStatefulWidget {
  const StagingFormSheet({
    super.key,
    this.existing,
    this.initialSo,
    this.initialCustomer,
    this.allowExistingSo = false,
    this.lockIdentity = false,
  });
  final StagingEntry? existing;
  final String? initialSo;
  final String? initialCustomer;
  final bool allowExistingSo;
  final bool lockIdentity;

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
  final _skids = TextEditingController();
  final _boxes = TextEditingController();
  final _crates = TextEditingController();
  final _pipe = TextEditingController();
  final _other = TextEditingController();
  String? _statusUi;
  DateTime? _futureDate;
  final _photos = <PhotoBytes>[];
  bool _busy = false;
  final _picker = PhotoPickerService();
  LocationCategory? _locationCategory;

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
      final counts = ContainerCounts.parse(e.type);
      _skids.text = counts.skids == 0 ? '' : '${counts.skids}';
      _boxes.text = counts.boxes == 0 ? '' : '${counts.boxes}';
      _crates.text = counts.crates == 0 ? '' : '${counts.crates}';
      _pipe.text = counts.pipe == 0 ? '' : '${counts.pipe}';
      _other.text = counts.other == 0 ? '' : '${counts.other}';
      _locationCategory = classifyLocation(e.location);
      _statusUi = StatusRules.formatUi(e.status);
      if (StatusRules.isYmd(e.status) &&
          e.status != StatusRules.todayYmd() &&
          e.status != StatusRules.tomorrowYmd()) {
        _statusUi = 'Ship On Future Date';
        _futureDate = DateTime.tryParse(e.status);
      }
    } else {
      if (widget.initialSo != null) _so.text = widget.initialSo!;
      if (widget.initialCustomer != null) {
        _customer.text = widget.initialCustomer!;
      }
      // New entries start with a blank status (not Partial).
      _statusUi = null;
    }
    _so.addListener(_maybeAutofillCustomer);
    if (widget.existing == null &&
        (widget.initialCustomer == null ||
            widget.initialCustomer!.trim().isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAutofillCustomer();
      });
    }
  }

  void _maybeAutofillCustomer() {
    if (widget.existing != null || widget.lockIdentity) return;
    if (_customer.text.trim().isNotEmpty) return;
    final so = _so.text.trim();
    if (so.isEmpty) return;
    final data = ref.read(appDataProvider);
    final customer = mostRecentCustomerForSo(
      staging: data.staging,
      shipped: data.shipped,
      so: so,
    );
    if (customer == null || customer.isEmpty) return;
    _customer.text = customer;
  }

  @override
  void dispose() {
    _so.removeListener(_maybeAutofillCustomer);
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

  ConsolidationUndoSnapshot? get _activeUndo {
    final snap = ref.read(consolidationUndoProvider);
    if (snap == null || !snap.isActive) return null;
    if (widget.existing?.id != snap.mergedId) return null;
    return snap;
  }

  Future<void> _reverseConsolidation() async {
    final snap = _activeUndo;
    if (snap == null) return;
    final so = snap.sources.isNotEmpty ? snap.sources.first.so : '';
    final ok = await confirmDialog(
      context,
      title: 'Reverse consolidation?',
      message:
          'Restore the ${snap.sources.length} merged staging '
          '${snap.sources.length == 1 ? 'row' : 'rows'} for SO $so?',
      confirmLabel: 'Reverse',
      confirmColor: SlstColors.purple,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(operationsProvider).reverseConsolidation(snap);
      if (mounted) {
        Navigator.pop(context);
        showOk(context, 'Consolidation reversed');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final statusUi = _statusUi;
      if (statusUi == null || statusUi.isEmpty) {
        throw Exception('Select a status before saving.');
      }
      final counts = countsFromControllers(
        skids: _skids,
        boxes: _boxes,
        crates: _crates,
        pipe: _pipe,
        other: _other,
      );
      final ops = ref.read(operationsProvider);
      if (counts.total <= 0) {
        throw Exception('At least one container is required.');
      }
      final locationDecision = await confirmLocationAdvisory(
        context,
        ref,
        location: _location.text,
        so: _so.text,
        ignoreEntryId: widget.existing?.id,
        containers: counts,
      );
      if (locationDecision == LocationAdvisoryDecision.cancel) return;
      if (!mounted) return;
      String? keepId = widget.existing?.id;
      if (widget.existing == null) {
        final created = await ops.createStaging(
          so: _so.text,
          customer: _customer.text,
          location: _location.text,
          statusUi: statusUi,
          containers: counts,
          weight: _weight.text,
          comments: _comments.text,
          stagedBy: _stagedBy.text,
          futureDateYmd: _ymd(_futureDate),
          photos: _photos,
          allowExistingSo:
              widget.allowExistingSo ||
              ref
                  .read(appDataProvider)
                  .staging
                  .any((entry) => orderKey(entry.so) == orderKey(_so.text)),
          locationCategory: _locationCategory,
        );
        keepId = created.id;
      } else {
        if (counts.total <= 0) {
          throw Exception('At least one container is required.');
        }
        final siblings = siblingStagingEntries(
          so: _so.text,
          active: ref.read(appDataProvider).staging,
          ignoreEntryId: widget.existing!.id,
        );
        if (siblings.isNotEmpty) {
          final proceed = await confirmSoMultiEntryAdvisory(
            context,
            so: _so.text.trim(),
            siblings: siblings,
          );
          if (!proceed) return;
          if (!mounted) return;
        }
        await ops.updateStagingWithPhotos(
          widget.existing!,
          {
            'so': _so.text.trim(),
            'customer': _customer.text.trim(),
            'location': _location.text.trim(),
            'status': StatusRules.toDb(
              statusUi,
              futureDateYmd: _ymd(_futureDate),
            ),
            'type': counts.typeLabel,
            'qty': counts.total,
            'weight': _weight.text.trim(),
            'comments': _comments.text.trim(),
            'staged_by': _stagedBy.text.trim(),
          },
          _photos,
          locationCategory: _locationCategory,
        );
      }
      if (locationDecision == LocationAdvisoryDecision.consolidate) {
        final matches = ref
            .read(appDataProvider)
            .staging
            .where((entry) => orderKey(entry.so) == orderKey(_so.text))
            .toList();
        if (matches.length > 1 && keepId != null) {
          final keep = matches.where((e) => e.id == keepId).toList();
          final rest = matches.where((e) => e.id != keepId).toList();
          await ops.consolidateStaging([...keep, ...rest]);
        }
      }
      if (mounted) {
        Navigator.pop(context);
        showOk(
          context,
          widget.existing == null ? 'Entry created' : 'Entry updated',
        );
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
    final lockIdentity = widget.lockIdentity;
    ref.watch(consolidationUndoProvider);
    final undo = _activeUndo;
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
                  color: IndustrialTheme.skyBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.existing == null
                      ? 'New Staging Entry'
                      : 'Edit Staging Entry',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: IndustrialTheme.textPrimary,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: IndustrialTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _so,
              readOnly: lockIdentity,
              decoration: InputDecoration(
                labelText: 'SO #',
                helperText: lockIdentity
                    ? 'Locked to this sales order from Order History'
                    : null,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => _maybeAutofillCustomer(),
            ),
            const SizedBox(height: 8),
            if (lockIdentity)
              TextField(
                controller: _customer,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  helperText: 'Locked to this sales order from Order History',
                ),
              )
            else
              CustomerSuggestionField(controller: _customer),
            const SizedBox(height: 8),
            LocationSelectorField(
              controller: _location,
              soController: _so,
              ignoreEntryId: widget.existing?.id,
              label: 'Location (e.g. A-01-A-1, D-02-B-1+2, B-02-Partial)',
              onCategoryChanged: (value) => _locationCategory = value,
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Status',
                errorText: _statusUi == null && _busy
                    ? 'Select a status'
                    : null,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Select status'),
                  value: _statusUi,
                  items: [
                    for (final s in StatusRules.uiStatuses)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() => _statusUi = v),
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
            PersonSuggestionField(controller: _stagedBy, label: 'Staged by'),
            const SizedBox(height: 8),
            TextField(
              controller: _comments,
              decoration: const InputDecoration(labelText: 'Comments'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PhotoAttachButtons(
                  picker: _picker,
                  photos: _photos,
                  onChanged: (next) => setState(() {
                    _photos
                      ..clear()
                      ..addAll(next);
                  }),
                ),
              ],
            ),
            if (undo != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SlstColors.purple,
                  side: const BorderSide(color: SlstColors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _busy ? null : _reverseConsolidation,
                icon: const Icon(Icons.undo),
                label: Text(
                  'Reverse consolidation '
                  '(${undo.remaining.inSeconds}s left)',
                ),
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
