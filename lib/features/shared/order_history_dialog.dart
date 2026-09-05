import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/popup_gate.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../staging/staging_form_sheet.dart';
import 'widgets.dart';

enum BinMovementType { split, consolidate, toShipped, toStaging, move }

class BinMovement {
  const BinMovement({
    required this.type,
    required this.summary,
    required this.createdAt,
    required this.user,
  });

  final BinMovementType type;
  final String summary;
  final DateTime? createdAt;
  final String user;

  String get label => switch (type) {
    BinMovementType.split => 'Split',
    BinMovementType.consolidate => 'Consolidated',
    BinMovementType.toShipped => 'To Shipped',
    BinMovementType.toStaging => 'To Staging',
    BinMovementType.move => 'Relocated',
  };
}

class OrderHistoryLogData {
  const OrderHistoryLogData({required this.movements, required this.changelog});

  final List<BinMovement> movements;
  final List<ChangelogEntry> changelog;
}

const _binMovementPrefix = 'Bin Movement:';

bool isBinMovementAction(String action) {
  if (action.startsWith(_binMovementPrefix)) return true;
  final normalized = action.toLowerCase();
  return RegExp(r'split order so', caseSensitive: false).hasMatch(action) ||
      RegExp(r'batch consolidated', caseSensitive: false).hasMatch(action) ||
      RegExp(
        r'report fix: changed location for so',
        caseSensitive: false,
      ).hasMatch(action) ||
      RegExp(r'bin move:', caseSensitive: false).hasMatch(action) ||
      RegExp(r'^ship confirmed so', caseSensitive: false).hasMatch(action) ||
      RegExp(
        r'^added via quick ship:',
        caseSensitive: false,
      ).hasMatch(action) ||
      RegExp(r'^returned to stock so', caseSensitive: false).hasMatch(action) ||
      RegExp(r'^restored to staging', caseSensitive: false).hasMatch(action) ||
      normalized.contains('to shipped log') ||
      normalized.contains('to staging log');
}

bool _matchesSo(String action, String so) {
  if (so.isEmpty) return false;
  return RegExp(
    r'\b' + RegExp.escape(so) + r'\b',
    caseSensitive: false,
  ).hasMatch(action);
}

BinMovementType _movementType(String action) {
  final normalized = action.toLowerCase();
  if (normalized.contains('split')) return BinMovementType.split;
  if (normalized.contains('consolidat')) return BinMovementType.consolidate;
  if (normalized.contains('to staging log') ||
      normalized.contains('restored to staging')) {
    return BinMovementType.toStaging;
  }
  if (normalized.contains('to shipped log') ||
      normalized.contains('ship confirm') ||
      normalized.contains('quick ship') ||
      normalized.contains('returned to stock')) {
    return BinMovementType.toShipped;
  }
  return BinMovementType.move;
}

String formatBinMovementSummary(String action) {
  if (action.startsWith(_binMovementPrefix)) {
    return action
        .replaceFirst(RegExp(r'^Bin Movement:\s*'), '')
        .replaceFirst(
          RegExp(
            r'^(Split|Consolidated|Relocated|To Shipped Log|To Staging Log)\s*—\s*',
            caseSensitive: false,
          ),
          '',
        );
  }
  if (RegExp(r'^Split Order SO', caseSensitive: false).hasMatch(action)) {
    final count = RegExp(
      r'into (\d+) separate',
      caseSensitive: false,
    ).firstMatch(action);
    return count == null
        ? action
        : 'Split into ${count.group(1)} separate staging entries';
  }
  if (RegExp(r'^Batch Consolidated', caseSensitive: false).hasMatch(action)) {
    return action.replaceFirst(
      RegExp(r'^Batch Consolidated\s*', caseSensitive: false),
      'Consolidated ',
    );
  }
  final location = RegExp(
    r'Changed Location for SO .+? to (.+)$',
    caseSensitive: false,
  ).firstMatch(action);
  if (location != null) return 'Relocated to ${location.group(1)}';
  if (RegExp(r'^Ship Confirmed SO', caseSensitive: false).hasMatch(action)) {
    return 'Moved from Staging Log to Shipped Log (Ship Confirm)';
  }
  if (RegExp(
    r'^Added via Quick Ship:',
    caseSensitive: false,
  ).hasMatch(action)) {
    return 'Moved to Shipped Log (Quick Ship)';
  }
  if (RegExp(r'^Returned to Stock SO', caseSensitive: false).hasMatch(action)) {
    return 'Moved from Staging Log to Shipped Log (Returned to Stock)';
  }
  if (RegExp(r'^Restored to Staging', caseSensitive: false).hasMatch(action)) {
    return 'Moved from Shipped Log back to Staging Log';
  }
  return action;
}

OrderHistoryLogData buildOrderHistoryLogData(
  List<ChangelogEntry> logs,
  String so,
) {
  final matched = logs
      .where(
        (log) => isBinMovementAction(log.action) && _matchesSo(log.action, so),
      )
      .toList();
  final movements = <BinMovement>[];
  for (final log in matched) {
    final canonical = log.action.startsWith(_binMovementPrefix);
    final duplicateOnly = RegExp(
      r'^(added via ship confirm|undo shipment action|added return to stock log|batch undo shipment action)',
      caseSensitive: false,
    ).hasMatch(log.action);
    final hasNearbyCanonical =
        !canonical &&
        matched.any(
          (other) =>
              !identical(other, log) &&
              other.action.startsWith(_binMovementPrefix) &&
              other.createdAt != null &&
              log.createdAt != null &&
              other.createdAt!.difference(log.createdAt!).abs() <
                  const Duration(seconds: 3),
        );
    if (!canonical && (duplicateOnly || hasNearbyCanonical)) continue;
    movements.add(
      BinMovement(
        type: _movementType(log.action),
        summary: formatBinMovementSummary(log.action),
        createdAt: log.createdAt,
        user: log.userEmail,
      ),
    );
  }
  movements.sort(
    (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
      a.createdAt ?? DateTime(1970),
    ),
  );
  return OrderHistoryLogData(
    movements: movements,
    changelog: logs
        .where(
          (log) =>
              !isBinMovementAction(log.action) || !_matchesSo(log.action, so),
        )
        .toList(),
  );
}

Future<void> showOrderHistoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String so,
}) {
  final data = ref.read(appDataProvider);
  final order = so.trim().toUpperCase();
  final active =
      data.staging.where((entry) => entry.so.trim().toUpperCase() == order).toList();
  final shipped =
      data.shipped.where((entry) => entry.so.trim().toUpperCase() == order).toList();
  // Floor app is open-anon: write actions are always available (RLS is the gate).
  void onAddEntry(BuildContext dialogContext) {
    final customer = active.isNotEmpty
        ? active.first.customer
        : (shipped.isNotEmpty ? shipped.first.customer : '');
    Navigator.pop(dialogContext);
    showStagingFormSheet(
      context,
      ref,
      initialSo: so,
      initialCustomer: customer,
      allowExistingSo: true,
      lockIdentity: true,
    );
  }

  Future<void> onConsolidate(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    final ok = await confirmDialog(
      context,
      title: 'Consolidate SO $so?',
      message: 'Merge ${active.length} active staging rows into one entry.',
      confirmLabel: 'Consolidate',
      confirmColor: SlstColors.purple,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(operationsProvider).consolidateStaging(active);
      if (context.mounted) showOk(context, 'Consolidated SO $so');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  return PopupGate.exclusive<void>(PopupKeys.orderHistory, () {
    if (usesDesktopPopupChrome(context)) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Order History',
        barrierColor: const Color(0x73000000),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: IndustrialTheme.chromeOf(context).surface,
              child: SizedBox(
                width: 440,
                height: MediaQuery.sizeOf(dialogContext).height,
                child: OrderHistoryDialog(
                  so: so,
                  activeEntries: active,
                  shippedEntries: shipped,
                  historyFuture: ref.read(changelogRepoProvider).forOrder(so),
                  onAddEntry: () => onAddEntry(dialogContext),
                  onConsolidate: active.length > 1
                      ? () => onConsolidate(dialogContext)
                      : null,
                ),
              ),
            ),
          );
        },
      );
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => OrderHistoryDialog(
        so: so,
        activeEntries: active,
        shippedEntries: shipped,
        historyFuture: ref.read(changelogRepoProvider).forOrder(so),
        onAddEntry: () => onAddEntry(dialogContext),
        onConsolidate:
            active.length > 1 ? () => onConsolidate(dialogContext) : null,
      ),
    );
  });
}

class OrderHistoryDialog extends StatelessWidget {
  const OrderHistoryDialog({
    super.key,
    required this.so,
    required this.activeEntries,
    required this.shippedEntries,
    required this.historyFuture,
    this.onAddEntry,
    this.onConsolidate,
  });

  final String so;
  final List<StagingEntry> activeEntries;
  final List<ShippedEntry> shippedEntries;
  final Future<List<ChangelogEntry>> historyFuture;
  final VoidCallback? onAddEntry;
  final VoidCallback? onConsolidate;

  static final _dateFormat = DateFormat('M/d/yy h:mm a');

  static String _date(DateTime? value) =>
      value == null ? 'Unknown date' : _dateFormat.format(value.toLocal());

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 600;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 40,
        vertical: narrow ? 16 : 28,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 22,
            narrow ? 14 : 18,
            narrow ? 16 : 22,
            narrow ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Order History:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: IndustrialTheme.chromeOf(context).ink,
                          ),
                        ),
                        Text(
                          so,
                          key: const Key('order-history-so'),
                          style: IndustrialTheme.mono(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: IndustrialTheme.chromeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('order-history-close'),
                    tooltip: 'Close Order History',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (onAddEntry != null || onConsolidate != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onAddEntry != null)
                      FilledButton.icon(
                        onPressed: onAddEntry,
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Add Entry'),
                      ),
                    if (onConsolidate != null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: SlstColors.purple,
                        ),
                        onPressed: onConsolidate,
                        icon: const Icon(Icons.merge_type, size: 17),
                        label: const Text('Consolidate'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    _Section(
                      title: 'Current Active Staging',
                      color: SlstColors.info,
                      emptyText: 'No active staging entries found.',
                      children: [
                        for (final entry in activeEntries)
                          _HistoryItem(
                            title: entry.type,
                            detail: '@ ${entry.location}',
                            meta:
                                'Staged by ${entry.stagedBy?.isNotEmpty == true ? entry.stagedBy : 'Unknown'} on ${_date(entry.entryDate)}',
                          ),
                      ],
                    ),
                    _Section(
                      title: 'Past Shipments',
                      color: SlstColors.success,
                      emptyText: 'No past shipments found.',
                      children: [
                        for (final entry in shippedEntries)
                          _HistoryItem(
                            title: entry.type,
                            detail:
                                '${_shipmentAction(entry.carrier)} from ${entry.location}',
                            meta:
                                'By ${entry.shippedBy?.isNotEmpty == true ? entry.shippedBy : 'Unknown'} on ${_date(entry.shippedAt)}',
                          ),
                      ],
                    ),
                    FutureBuilder<List<ChangelogEntry>>(
                      future: historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            'Error loading order history: ${snapshot.error}',
                            style: TextStyle(color: SlstColors.danger),
                          );
                        }
                        final logData = buildOrderHistoryLogData(
                          snapshot.data ?? const [],
                          so,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Section(
                              title: 'Bin Movements',
                              color: SlstColors.purple,
                              emptyText:
                                  'No bin movements recorded for this order.',
                              children: [
                                for (final movement in logData.movements)
                                  _HistoryItem(
                                    badge: movement.label,
                                    title: movement.summary,
                                    meta:
                                        'By ${movement.user.isEmpty ? 'Unknown' : movement.user} on ${_date(movement.createdAt)}',
                                  ),
                              ],
                            ),
                            _Section(
                              title: 'Changelog History',
                              color: SlstColors.slate,
                              emptyText: 'No log history.',
                              children: [
                                for (final log in logData.changelog)
                                  _HistoryItem(
                                    title: log.action,
                                    meta:
                                        '${_date(log.createdAt)}  [${log.userEmail.isEmpty ? 'Unknown' : log.userEmail}]',
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shipmentAction(String carrier) => switch (carrier) {
    'RETURNED TO STOCK' => 'Returned to Stock',
    'CONSOLIDATED' => 'Consolidated',
    _ => 'Shipped via $carrier',
  };
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.color,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final Color color;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                emptyText,
                style: TextStyle(fontSize: 12, color: SlstColors.muted),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({
    required this.title,
    required this.meta,
    this.detail,
    this.badge,
  });

  final String title;
  final String meta;
  final String? detail;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SlstColors.purple.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: SlstColors.purple,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null)
                Text(detail!, style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: TextStyle(fontSize: 11, color: SlstColors.muted),
          ),
        ],
      ),
    );
  }
}
