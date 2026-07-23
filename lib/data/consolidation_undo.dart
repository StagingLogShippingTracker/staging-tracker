import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

const consolidationUndoWindow = Duration(minutes: 2);

class ConsolidationUndoSnapshot {
  const ConsolidationUndoSnapshot({
    required this.keepId,
    required this.keepBefore,
    required this.removed,
    required this.at,
  });

  final String keepId;
  final StagingEntry keepBefore;
  final List<StagingEntry> removed;
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
