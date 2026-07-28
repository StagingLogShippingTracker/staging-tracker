import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../platform/photo_picker.dart';
import '../shared/entry_suggestion_fields.dart';
import '../shared/so_advisories.dart';
import '../shared/widgets.dart';

Future<void> showShipDialog(
  BuildContext context,
  WidgetRef ref, {
  required StagingEntry entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ShipDialog(entry: entry),
  );
}

Future<void> showReturnDialog(
  BuildContext context,
  WidgetRef ref, {
  required StagingEntry entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ReturnDialog(entry: entry),
  );
}

class ShipDialog extends ConsumerStatefulWidget {
  const ShipDialog({super.key, required this.entry});
  final StagingEntry entry;

  @override
  ConsumerState<ShipDialog> createState() => _ShipDialogState();
}

class _ShipDialogState extends ConsumerState<ShipDialog> {
  final _carrier = TextEditingController();
  final _shippedBy = TextEditingController();
  final _pmEmail = TextEditingController();
  final _weight = TextEditingController();
  final _skids = TextEditingController();
  final _boxes = TextEditingController();
  final _crates = TextEditingController();
  final _pipe = TextEditingController();
  final _other = TextEditingController();
  bool _notify = true;
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _weight.text = e.weight ?? '';
    final counts = ContainerCounts.parse(e.type);
    _skids.text = counts.skids == 0 ? '' : '${counts.skids}';
    _boxes.text = counts.boxes == 0 ? '' : '${counts.boxes}';
    _crates.text = counts.crates == 0 ? '' : '${counts.crates}';
    _pipe.text = counts.pipe == 0 ? '' : '${counts.pipe}';
    _other.text = counts.other == 0 ? '' : '${counts.other}';
  }

  @override
  void dispose() {
    _carrier.dispose();
    _shippedBy.dispose();
    _pmEmail.dispose();
    _weight.dispose();
    _skids.dispose();
    _boxes.dispose();
    _crates.dispose();
    _pipe.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final counts = countsFromControllers(
        skids: _skids,
        boxes: _boxes,
        crates: _crates,
        pipe: _pipe,
        other: _other,
      );
      if (counts.total <= 0) {
        throw Exception('At least one container is required.');
      }
      final proceed = await confirmPartialShipIfNeeded(
        context,
        ref,
        entry: widget.entry,
      );
      if (!proceed) return;
      if (!mounted) return;
      if (_notify && !_pmEmail.text.trim().contains('@')) {
        throw Exception('Notify PM is on — enter a valid PM email, or turn notify off.');
      }
      final warning = await ref
          .read(operationsProvider)
          .shipEntry(
            entry: widget.entry,
            carrier: _carrier.text,
            shippedBy: _shippedBy.text,
            pmEmail: _pmEmail.text.trim().isEmpty ? null : _pmEmail.text.trim(),
            notifyPm: _notify,
            extraPhotos: _photos,
            containers: counts,
            weight: _weight.text,
          );
      if (mounted) {
        Navigator.pop(context);
        if (warning != null) {
          showError(context, warning);
        } else {
          showOk(context, 'Shipped SO ${widget.entry.so}');
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: IndustrialTheme.darkSurface,
      title: Text(
        'Ship SO ${widget.entry.so}',
        style: IndustrialTheme.mono(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.entry.customer} · ${widget.entry.location}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
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
              CarrierSuggestionField(controller: _carrier),
              const SizedBox(height: 8),
              PersonSuggestionField(
                controller: _shippedBy,
                label: 'Shipped by',
              ),
              const SizedBox(height: 8),
              ContactEmailField(controller: _pmEmail, optional: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify PM'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PhotoAttachButtons(
                  picker: _picker,
                  photos: _photos,
                  attachLabel: 'Add photos',
                  onChanged: (next) => setState(() {
                    _photos
                      ..clear()
                      ..addAll(next);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: SlstColors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.local_shipping, size: 18),
          label: Text(_busy ? 'Shipping…' : 'Confirm Ship'),
        ),
      ],
    );
  }
}

class ReturnDialog extends ConsumerStatefulWidget {
  const ReturnDialog({super.key, required this.entry});
  final StagingEntry entry;

  @override
  ConsumerState<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<ReturnDialog> {
  final _pickedBy = TextEditingController();
  final _returnedBy = TextEditingController();
  final _reason = TextEditingController();
  final _pmEmail = TextEditingController();
  bool _notify = true;
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();

  @override
  void dispose() {
    _pickedBy.dispose();
    _returnedBy.dispose();
    _reason.dispose();
    _pmEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (_notify && !_pmEmail.text.trim().contains('@')) {
        throw Exception('Notify PM is on — enter a valid PM email, or turn notify off.');
      }
      final warning = await ref
          .read(operationsProvider)
          .returnToStock(
            entry: widget.entry,
            pickedBy: _pickedBy.text,
            returnedBy: _returnedBy.text,
            reason: _reason.text,
            pmEmail: _pmEmail.text.trim().isEmpty ? null : _pmEmail.text.trim(),
            notifyPm: _notify,
            extraPhotos: _photos,
          );
      if (mounted) {
        Navigator.pop(context);
        if (warning != null) {
          showError(context, warning);
        } else {
          showOk(context, 'Returned SO ${widget.entry.so}');
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: IndustrialTheme.darkSurface,
      title: Text(
        'Return SO ${widget.entry.so}',
        style: IndustrialTheme.mono(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonSuggestionField(controller: _pickedBy, label: 'Picked by'),
              const SizedBox(height: 8),
              PersonSuggestionField(
                controller: _returnedBy,
                label: 'Returned by',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              ContactEmailField(controller: _pmEmail),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify PM'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PhotoAttachButtons(
                  picker: _picker,
                  photos: _photos,
                  attachLabel: 'Add photos',
                  onChanged: (next) => setState(() {
                    _photos
                      ..clear()
                      ..addAll(next);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Return to Stock'),
        ),
      ],
    );
  }
}
