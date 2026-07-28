import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slst_shared/slst_shared.dart';

import '../theme.dart';

/// Lean ship-confirm for a single staging row.
class ShipConfirmScreen extends StatefulWidget {
  const ShipConfirmScreen({super.key, required this.entry, required this.ops});

  final StagingEntry entry;
  final ShipOperations ops;

  @override
  State<ShipConfirmScreen> createState() => _ShipConfirmScreenState();
}

class _ShipConfirmScreenState extends State<ShipConfirmScreen> {
  final _carrierCtrl = TextEditingController();
  final _byCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  List<String> _carriers = const [];
  List<String> _people = const [];

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    try {
      final carriers = await widget.ops.roster.valuesFor('carrier');
      final people = await widget.ops.roster.valuesFor('person_by');
      if (!mounted) return;
      setState(() {
        _carriers = carriers;
        _people = people;
        if (_carrierCtrl.text.isEmpty && carriers.isNotEmpty) {
          _carrierCtrl.text = carriers.first;
        }
        if (_byCtrl.text.isEmpty && people.isNotEmpty) {
          _byCtrl.text = people.first;
        }
      });
    } catch (_) {
      // Roster optional on wear — free text still works.
    }
  }

  @override
  void dispose() {
    _carrierCtrl.dispose();
    _byCtrl.dispose();
    super.dispose();
  }

  Future<void> _ship() async {
    final carrier = _carrierCtrl.text.trim();
    final by = _byCtrl.text.trim();
    if (carrier.isEmpty || by.isEmpty) {
      setState(() => _error = 'Carrier and Shipped By required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ops.shipEntry(
        entry: widget.entry,
        carrier: carrier,
        shippedBy: by,
        notifyPm: false,
      );
      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _pickRosterValue({
    required String title,
    required List<String> values,
    required TextEditingController controller,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: WearTheme.base,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select $title',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: WearTheme.border),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: values.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: WearTheme.border),
                  itemBuilder: (context, index) {
                    final value = values[index];
                    return SizedBox(
                      height: 48,
                      child: ListTile(
                        title: Text(value),
                        trailing: value == controller.text
                            ? const Icon(Icons.check, color: WearTheme.ok)
                            : null,
                        onTap: () => Navigator.of(context).pop(value),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => controller.text = selected);
    }
  }

  Widget _rosterField({
    required String label,
    required String emptyHint,
    required List<String> values,
    required TextEditingController controller,
  }) {
    if (values.isEmpty) {
      return SizedBox(
        height: 48,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: emptyHint),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () => _pickRosterValue(
          title: label.toLowerCase(),
          values: values,
          controller: controller,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.text.isEmpty ? 'Select $label' : controller.text,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Scaffold(
      appBar: AppBar(
        title: Text('SO ${e.so}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          children: [
            Text(e.customer, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${e.location}\n${e.type} ×${e.qty}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text('CARRIER', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            _rosterField(
              label: 'Carrier',
              emptyHint: 'Enter carrier',
              values: _carriers,
              controller: _carrierCtrl,
            ),
            const SizedBox(height: 10),
            Text('SHIPPED BY', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            _rosterField(
              label: 'Staff member',
              emptyHint: 'Enter staff name',
              values: _people,
              controller: _byCtrl,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: WearTheme.danger, fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _ship,
              child: Text(_busy ? 'Shipping…' : 'Confirm ship'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
