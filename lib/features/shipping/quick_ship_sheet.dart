import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../platform/photo_picker.dart';
import '../shared/widgets.dart';

Future<void> showQuickShipSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const QuickShipSheet(),
  );
}

class QuickShipSheet extends ConsumerStatefulWidget {
  const QuickShipSheet({super.key});

  @override
  ConsumerState<QuickShipSheet> createState() => _QuickShipSheetState();
}

class _QuickShipSheetState extends ConsumerState<QuickShipSheet> {
  final _so = TextEditingController();
  final _customer = TextEditingController();
  final _carrier = TextEditingController();
  final _shippedBy = TextEditingController();
  final _location = TextEditingController();
  final _weight = TextEditingController();
  final _comments = TextEditingController();
  final _pmEmail = TextEditingController();
  final _skids = TextEditingController(text: '1');
  final _boxes = TextEditingController();
  final _crates = TextEditingController();
  final _pipe = TextEditingController();
  final _other = TextEditingController();
  bool _notify = true;
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();

  @override
  void dispose() {
    _so.dispose();
    _customer.dispose();
    _carrier.dispose();
    _shippedBy.dispose();
    _location.dispose();
    _weight.dispose();
    _comments.dispose();
    _pmEmail.dispose();
    _skids.dispose();
    _boxes.dispose();
    _crates.dispose();
    _pipe.dispose();
    _other.dispose();
    super.dispose();
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
      if (counts.total <= 0) {
        throw Exception('At least one container is required.');
      }
      await ref.read(operationsProvider).quickShip(
            so: _so.text,
            customer: _customer.text,
            carrier: _carrier.text,
            shippedBy: _shippedBy.text,
            containers: counts,
            location: _location.text,
            weight: _weight.text,
            comments: _comments.text,
            pmEmail: _pmEmail.text.trim().isEmpty ? null : _pmEmail.text.trim(),
            notifyPm: _notify,
            photos: _photos,
          );
      if (mounted) {
        Navigator.pop(context);
        showOk(context, 'Quick shipped SO ${_so.text.trim()}');
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
            Text('Quick Ship', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _so,
              decoration: const InputDecoration(labelText: 'SO #'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customer,
              decoration: const InputDecoration(labelText: 'Customer'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _carrier,
              decoration: const InputDecoration(labelText: 'Carrier'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shippedBy,
              decoration: const InputDecoration(labelText: 'Shipped by'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
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
              decoration: const InputDecoration(labelText: 'Weight'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comments,
              decoration: const InputDecoration(labelText: 'Comments'),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Shipping…' : 'Quick Ship'),
            ),
          ],
        ),
      ),
    );
  }
}
