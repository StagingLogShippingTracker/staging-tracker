import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/widgets.dart';
import 'ship_dialog.dart';
import 'split_dialog.dart';
import 'staging_form_sheet.dart';

class StagingScreen extends ConsumerStatefulWidget {
  const StagingScreen({super.key});

  @override
  ConsumerState<StagingScreen> createState() => _StagingScreenState();
}

class _StagingScreenState extends ConsumerState<StagingScreen> {
  final _search = TextEditingController();
  String _q = '';
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StagingEntry> _filtered(List<StagingEntry> all) {
    final list = all.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.location} ${e.status} ${e.comments ?? ''}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList()
      ..sort((a, b) {
        final u = StatusRules.urgencyWeight(b.status) -
            StatusRules.urgencyWeight(a.status);
        if (u != 0) return u;
        return (b.entryDate ?? DateTime(1970))
            .compareTo(a.entryDate ?? DateTime(1970));
      });
    return list;
  }

  Future<void> _batchDelete(List<StagingEntry> entries) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      showError(context, 'Sign in required');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text('Delete ${_selected.length} staging entries?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final ops = ref.read(operationsProvider);
    for (final e in entries.where((e) => _selected.contains(e.id))) {
      await ops.deleteRecord(table: 'staging', id: e.id, so: e.so);
    }
    setState(() => _selected.clear());
    if (mounted) showOk(context, 'Deleted');
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final user = ref.watch(currentUserProvider);
    final entries = _filtered(data.staging);

    return Scaffold(
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showStagingFormSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: _search,
                    hint: 'Filter staging…',
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                  ),
                ),
                if (_selected.isNotEmpty && user != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Consolidate selected',
                    onPressed: () async {
                      final picked =
                          entries.where((e) => _selected.contains(e.id)).toList();
                      try {
                        await ref
                            .read(operationsProvider)
                            .consolidateStaging(picked);
                        setState(() => _selected.clear());
                        if (context.mounted) showOk(context, 'Consolidated');
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                    icon: const Icon(Icons.merge_type),
                  ),
                  IconButton(
                    tooltip: 'Delete selected',
                    onPressed: () => _batchDelete(entries),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
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
                    final selected = _selected.contains(e.id);
                    return Card(
                      color: statusColor(e.status),
                      child: ExpansionTile(
                        leading: user == null
                            ? null
                            : Checkbox(
                                value: selected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(e.id);
                                    } else {
                                      _selected.remove(e.id);
                                    }
                                  });
                                },
                              ),
                        title: Text(
                          'SO ${e.so}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${e.customer}\n${StatusRules.formatUi(e.status)} · ${e.location}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${e.type} · qty ${e.qty}'),
                                if ((e.weight ?? '').isNotEmpty)
                                  Text('Weight: ${e.weight}'),
                                if ((e.stagedBy ?? '').isNotEmpty)
                                  Text('Staged by: ${e.stagedBy}'),
                                if ((e.comments ?? '').isNotEmpty)
                                  Text(e.comments!),
                                const SizedBox(height: 8),
                                PhotoThumbRow(paths: e.photoUrls),
                                if (user != null) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () => showShipDialog(
                                          context,
                                          ref,
                                          entry: e,
                                        ),
                                        icon: const Icon(Icons.local_shipping),
                                        label: const Text('Ship'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => showStagingFormSheet(
                                          context,
                                          ref,
                                          existing: e,
                                        ),
                                        child: const Text('Edit'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => showReturnDialog(
                                          context,
                                          ref,
                                          entry: e,
                                        ),
                                        child: const Text('Return'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => showSplitDialog(
                                          context,
                                          ref,
                                          entry: e,
                                        ),
                                        child: const Text('Split'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete entry?'),
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
                                                    table: 'staging',
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
