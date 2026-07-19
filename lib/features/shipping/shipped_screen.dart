import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../shared/widgets.dart';
import 'quick_ship_sheet.dart';

class ShippedScreen extends ConsumerStatefulWidget {
  const ShippedScreen({super.key});

  @override
  ConsumerState<ShippedScreen> createState() => _ShippedScreenState();
}

class _ShippedScreenState extends ConsumerState<ShippedScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ShippedEntry> _filtered(List<ShippedEntry> all) {
    return all.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.carrier} ${e.location} ${e.comments ?? ''}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final user = ref.watch(currentUserProvider);
    final entries = _filtered(data.shipped);

    return Scaffold(
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showQuickShipSheet(context, ref),
              icon: const Icon(Icons.flash_on),
              label: const Text('Quick Ship'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchField(
              controller: _search,
              hint: 'Filter shipped…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          if (data.loading && entries.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(appDataProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final returned =
                        e.carrier.toUpperCase() == 'RETURNED TO STOCK';
                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          'SO ${e.so}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${e.customer}\n${e.carrier} · ${e.location}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${e.type} · qty ${e.qty}'),
                                if ((e.shippedBy ?? '').isNotEmpty)
                                  Text('By: ${e.shippedBy}'),
                                if ((e.pmdEmail ?? '').isNotEmpty)
                                  Text('PM: ${e.pmdEmail}'),
                                if ((e.comments ?? '').isNotEmpty)
                                  Text(e.comments!),
                                if (e.shippedAt != null)
                                  Text(
                                    'Shipped: ${e.shippedAt!.toLocal()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                const SizedBox(height: 8),
                                PhotoThumbRow(paths: e.photoUrls),
                                if (user != null) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (!returned)
                                        OutlinedButton(
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(operationsProvider)
                                                  .undoShipment(e);
                                              if (context.mounted) {
                                                showOk(
                                                  context,
                                                  'Restored SO ${e.so} to staging',
                                                );
                                              }
                                            } catch (err) {
                                              if (context.mounted) {
                                                showError(context, err);
                                              }
                                            }
                                          },
                                          child: const Text('Undo'),
                                        ),
                                      TextButton(
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete shipped?'),
                                              content: Text('SO ${e.so}'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            try {
                                              await ref
                                                  .read(operationsProvider)
                                                  .deleteRecord(
                                                    table: 'shipped',
                                                    id: e.id,
                                                    so: e.so,
                                                  );
                                              if (context.mounted) {
                                                showOk(context, 'Deleted');
                                              }
                                            } catch (err) {
                                              if (context.mounted) {
                                                showError(context, err);
                                              }
                                            }
                                          }
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
