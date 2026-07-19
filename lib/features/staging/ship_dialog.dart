import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../platform/photo_picker.dart';
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
  bool _notify = true;
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();
  List<String> _carriers = const [];
  List<String> _people = const [];

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    final roster = ref.read(rosterRepoProvider);
    final carriers = await roster.valuesFor('carrier');
    final people = await roster.valuesFor('person_by');
    if (mounted) {
      setState(() {
        _carriers = carriers;
        _people = people;
      });
    }
  }

  @override
  void dispose() {
    _carrier.dispose();
    _shippedBy.dispose();
    _pmEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(operationsProvider).shipEntry(
            entry: widget.entry,
            carrier: _carrier.text,
            shippedBy: _shippedBy.text,
            pmEmail: _pmEmail.text.trim().isEmpty ? null : _pmEmail.text.trim(),
            notifyPm: _notify,
            extraPhotos: _photos,
          );
      if (mounted) {
        Navigator.pop(context);
        showOk(context, 'Shipped SO ${widget.entry.so}');
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
      title: Text('Ship SO ${widget.entry.so}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (v) {
                  final q = v.text.toLowerCase();
                  return _carriers.where((c) => c.toLowerCase().contains(q));
                },
                onSelected: (v) => _carrier.text = v,
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  controller.text = _carrier.text;
                  controller.addListener(() => _carrier.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(labelText: 'Carrier'),
                  );
                },
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (v) {
                  final q = v.text.toLowerCase();
                  return _people.where((c) => c.toLowerCase().contains(q));
                },
                onSelected: (v) => _shippedBy.text = v,
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  controller.text = _shippedBy.text;
                  controller
                      .addListener(() => _shippedBy.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(labelText: 'Shipped by'),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pmEmail,
                decoration: const InputDecoration(
                  labelText: 'PM email (optional)',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify PM'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final files = await _picker.pickPreferred();
                    setState(() => _photos.addAll(files));
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: Text('Add photos (${_photos.length})'),
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
          child: Text(_busy ? 'Shipping…' : 'Confirm Ship'),
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
      await ref.read(operationsProvider).returnToStock(
            entry: widget.entry,
            pickedBy: _pickedBy.text,
            returnedBy: _returnedBy.text,
            reason: _reason.text,
            pmEmail: _pmEmail.text.trim().isEmpty ? null : _pmEmail.text.trim(),
            notifyPm: _notify,
          );
      if (mounted) {
        Navigator.pop(context);
        showOk(context, 'Returned SO ${widget.entry.so}');
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
      title: Text('Return SO ${widget.entry.so}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _pickedBy,
                decoration: const InputDecoration(labelText: 'Picked by'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _returnedBy,
                decoration: const InputDecoration(labelText: 'Returned by'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pmEmail,
                decoration: const InputDecoration(labelText: 'PM email'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify PM'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
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
