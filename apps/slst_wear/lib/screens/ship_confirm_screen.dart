import 'package:flutter/material.dart';
import 'package:slst_shared/slst_shared.dart';

import '../theme.dart';

/// Lean ship-confirm for a single staging row.
class ShipConfirmScreen extends StatefulWidget {
  const ShipConfirmScreen({
    super.key,
    required this.entry,
    required this.ops,
  });

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
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
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
            TextField(
              controller: _carrierCtrl,
              decoration: InputDecoration(
                hintText: _carriers.isEmpty ? 'Carrier' : null,
              ),
            ),
            if (_carriers.length > 1) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final c in _carriers.take(4))
                    ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 10)),
                      onPressed: () =>
                          setState(() => _carrierCtrl.text = c),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WearTheme.header,
                      side: const BorderSide(color: WearTheme.border),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text('SHIPPED BY', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            TextField(
              controller: _byCtrl,
              decoration: InputDecoration(
                hintText: _people.isEmpty ? 'Name' : null,
              ),
            ),
            if (_people.length > 1) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final p in _people.take(4))
                    ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 10)),
                      onPressed: () => setState(() => _byCtrl.text = p),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WearTheme.header,
                      side: const BorderSide(color: WearTheme.border),
                    ),
                ],
              ),
            ],
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
