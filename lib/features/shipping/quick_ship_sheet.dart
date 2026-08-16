import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/location_intelligence.dart';
import '../../platform/photo_picker.dart';
import '../shared/entry_suggestion_fields.dart';
import '../shared/location_selector.dart';
import '../shared/so_advisories.dart';
import '../shared/widgets.dart';

Future<void> showQuickShipSheet(BuildContext context, WidgetRef ref) {
  return showAdaptivePopup<void>(
    context,
    maxWidth: 680,
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
  final _skids = TextEditingController();
  final _boxes = TextEditingController();
  final _crates = TextEditingController();
  final _pipe = TextEditingController();
  final _other = TextEditingController();
  bool _notify = true;
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();
  LocationCategory? _locationCategory;

  @override
  void initState() {
    super.initState();
    _so.addListener(_maybeAutofillCustomer);
  }

  void _maybeAutofillCustomer() {
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
      final proceed = await confirmQuickShipStagingLeftoversIfNeeded(
        context,
        ref,
        so: _so.text,
      );
      if (!proceed) return;
      if (!mounted) return;
      if (_notify && !_pmEmail.text.trim().contains('@')) {
        throw Exception('Notify PM is on — enter a valid PM email, or turn notify off.');
      }
      final warning = await ref
          .read(operationsProvider)
          .quickShip(
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
            locationCategory: _locationCategory,
          );
      if (mounted) {
        Navigator.pop(context);
        if (warning != null) {
          showError(context, warning);
        } else {
          showOk(context, 'Quick shipped SO ${_so.text.trim()}');
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: IndustrialTheme.mintGreen),
                const SizedBox(width: 8),
                Text(
                  'Quick Ship',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: IndustrialTheme.chromeOf(context).ink,
                      ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: IndustrialTheme.chromeOf(context).muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _so,
              decoration: const InputDecoration(labelText: 'SO #'),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => _maybeAutofillCustomer(),
            ),
            const SizedBox(height: 8),
            CustomerSuggestionField(controller: _customer),
            const SizedBox(height: 8),
            CarrierSuggestionField(controller: _carrier),
            const SizedBox(height: 8),
            PersonSuggestionField(controller: _shippedBy, label: 'Shipped by'),
            const SizedBox(height: 8),
            LocationSelectorField(
              controller: _location,
              soController: _so,
              onCategoryChanged: (value) => _locationCategory = value,
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
            ContactEmailField(controller: _pmEmail),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify PM'),
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
            ),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SlstColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.bolt),
              label: Text(_busy ? 'Shipping…' : 'Quick Ship'),
            ),
          ],
        ),
      ),
    );
  }
}
