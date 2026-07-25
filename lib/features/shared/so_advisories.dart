import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/so_advisories.dart';

export '../../domain/so_advisories.dart';

/// Soft warning when shipping one staging row while the same SO still has
/// other active locations. Returns `true` when the user chooses to continue.
Future<bool> confirmPartialShipAdvisory(
  BuildContext context, {
  required String so,
  required List<StagingEntry> leftovers,
}) async {
  if (leftovers.isEmpty) return true;
  final locations = leftoverLocations(leftovers);
  final locationLine = locations.isEmpty
      ? '${leftovers.length} other staging ${leftovers.length == 1 ? 'entry' : 'entries'}'
      : locations.join(', ');
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: SlstColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Other locations remain',
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: Text(
        'SO $so still has staging at:\n\n'
        '$locationLine\n\n'
        'Shipping only this location is sometimes intentional '
        '(for example fittings ahead of valves). '
        'Remaining entries stay in Staging until shipped separately.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: SlstColors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Ship anyway'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Soft advisory when an SO already has other active staging rows.
/// Used for edit and undo flows that previously hard-blocked.
Future<bool> confirmSoMultiEntryAdvisory(
  BuildContext context, {
  required String so,
  required List<StagingEntry> siblings,
  String title = 'SO already in Staging',
  String proceedLabel = 'Proceed anyway',
  String? messageOverride,
}) async {
  if (siblings.isEmpty) return true;
  final locations = leftoverLocations(siblings);
  final locationLine = locations.isEmpty
      ? '${siblings.length} other staging ${siblings.length == 1 ? 'entry' : 'entries'}'
      : locations.join(', ');
  final message =
      messageOverride ??
      'SO $so already has active staging at:\n\n'
          '$locationLine\n\n'
          'Multiple locations for one SO are allowed. '
          'Continue only if this is intentional.';
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: SlstColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(proceedLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Refresh snapshot, then confirm partial-ship leftovers for [entry] if any.
Future<bool> confirmPartialShipIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required StagingEntry entry,
}) async {
  await ref.read(appDataProvider.notifier).refresh();
  if (!context.mounted) return false;
  final leftovers = siblingStagingEntries(
    so: entry.so,
    active: ref.read(appDataProvider).staging,
    ignoreEntryId: entry.id,
  );
  return confirmPartialShipAdvisory(
    context,
    so: entry.so,
    leftovers: leftovers,
  );
}

/// For Quick Ship: warn when the SO already has active staging rows that will
/// remain after this shipped log is created.
Future<bool> confirmQuickShipStagingLeftoversIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required String so,
}) async {
  await ref.read(appDataProvider.notifier).refresh();
  if (!context.mounted) return false;
  final leftovers = siblingStagingEntries(
    so: so,
    active: ref.read(appDataProvider).staging,
  );
  if (leftovers.isEmpty) return true;
  return confirmPartialShipAdvisory(
    context,
    so: so.trim(),
    leftovers: leftovers,
  );
}
