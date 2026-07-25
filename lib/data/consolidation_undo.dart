import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

const consolidationUndoWindow = Duration(minutes: 2);

class ConsolidationUndoSnapshot {
  const ConsolidationUndoSnapshot({
    required this.mergedId,
    required this.sources,
    required this.at,
  });

  /// New UUID of the consolidated survivor (deleted on undo).
  final String mergedId;

  /// All pre-consolidate rows (re-inserted on undo with fresh UUIDs).
  final List<StagingEntry> sources;
  final DateTime at;

  bool get isActive =>
      DateTime.now().difference(at) <= consolidationUndoWindow;

  Duration get remaining {
    final left = consolidationUndoWindow - DateTime.now().difference(at);
    return left.isNegative ? Duration.zero : left;
  }
}

final consolidationUndoProvider =
    StateProvider<ConsolidationUndoSnapshot?>((ref) => null);
