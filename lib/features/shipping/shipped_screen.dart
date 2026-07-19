import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
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
  bool _returnsOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ShippedEntry> _filtered(List<ShippedEntry> all) {
    return all.where((e) {
      final returned = e.carrier.toUpperCase() == 'RETURNED TO STOCK';
      if (_returnsOnly && !returned) return false;
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.carrier} ${e.location} ${e.comments ?? ''}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();
  }

  Future<void> _undo(ShippedEntry e) async {
    try {
      await ref.read(operationsProvider).undoShipment(e);
      if (mounted) showOk(context, 'Restored SO ${e.so} to staging');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  Future<void> _delete(ShippedEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete shipped record?'),
        content: Text('SO ${e.so} — ${e.customer}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(operationsProvider)
          .deleteRecord(table: 'shipped', id: e.id, so: e.so);
      if (mounted) showOk(context, 'Deleted');
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final user = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;
    final entries = _filtered(data.shipped);
    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');

    return Scaffold(
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: SlstColors.green,
              foregroundColor: Colors.white,
              onPressed: () => showQuickShipSheet(context, ref),
              icon: const Icon(Icons.bolt),
              label: const Text('Quick Ship'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SearchField(
              controller: _search,
              hint: 'Filter shipped…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Returns only'),
                  selected: _returnsOnly,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.keyboard_return,
                    size: 16,
                    color: _returnsOnly
                        ? SlstColors.brandDark
                        : scheme.onSurfaceVariant,
                  ),
                  selectedColor: SlstColors.brandSoft,
                  onSelected: (v) => setState(() => _returnsOnly = v),
                ),
                const Spacer(),
                Text(
                  '${entries.length} records',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (data.loading && entries.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (entries.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text('No shipped records match.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final returned =
                        e.carrier.toUpperCase() == 'RETURNED TO STOCK';
                    final accent =
                        returned ? SlstColors.brand : SlstColors.green;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 5, color: accent),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                tilePadding:
                                    const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'SO ${e.so}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontSize: 16),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        returned ? 'RETURNED' : 'SHIPPED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.customer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${e.carrier} · ${e.location}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text('${e.type} · qty ${e.qty}'),
                                        if ((e.shippedBy ?? '').isNotEmpty)
                                          Text('Shipped by: ${e.shippedBy}'),
                                        if ((e.pmdEmail ?? '').isNotEmpty)
                                          Text('PM: ${e.pmdEmail}'),
                                        if ((e.comments ?? '').isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4),
                                            child: Text(e.comments!),
                                          ),
                                        if (e.shippedAt != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4),
                                            child: Text(
                                              dateFmt.format(
                                                  e.shippedAt!.toLocal()),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        PhotoThumbRow(paths: e.photoUrls),
                                        if (user != null) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (!returned)
                                                OutlinedButton.icon(
                                                  onPressed: () => _undo(e),
                                                  icon: const Icon(
                                                      Icons.undo,
                                                      size: 18),
                                                  label: const Text('Undo'),
                                                ),
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      scheme.error,
                                                ),
                                                onPressed: () => _delete(e),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18),
                                                label: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
