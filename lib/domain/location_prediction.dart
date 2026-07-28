import 'location_intelligence.dart';
import 'models.dart';

/// Result of a “where should this go?” suggestion.
///
/// This is deliberately heuristic + advisory today; it provides the seam
/// you can later replace with an AI model or predictive dispatch engine
/// without changing the UI contract.
class LocationPrediction {
  const LocationPrediction({
    required this.suggestedLocation,
    required this.reason,
    required this.score,
  });

  final String suggestedLocation;
  final String reason;
  final double score;
}

/// Suggest a better alternate aisle location for [so], based on current
/// occupancy and available remembered locations.
///
/// - Prefers vacant locations in the same aisle/level/suffix (when possible)
/// - Penalizes locations occupied by a different SO
/// - Slightly rewards consolidation opportunities for the same SO
Future<LocationPrediction?> suggestAlternateAisleLocation({
  required String currentLocation,
  required String so,
  required List<StagingEntry> activeStaging,
  required List<ShippedEntry> shipped,
  required Iterable<String> candidateLocations,
  String? ignoreEntryId,
}) async {
  final currentParsed = parseAisleLocation(currentLocation);
  final currentNorm = locationKey(currentLocation);

  // Keep this cheap: advisory suggestions should be quick on handhelds.
  final candidates = candidateLocations
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .where((c) => locationKey(c) != currentNorm)
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  if (candidates.isEmpty) return null;

  Iterable<String> filtered = candidates;
  if (currentParsed != null) {
    // Try the “same aisle geometry” subset first.
    final sameAisle = candidates.where((c) {
      final p = parseAisleLocation(c);
      if (p == null) return false;
      return p.aisle.toUpperCase() == currentParsed.aisle.toUpperCase();
    });

    final sameLevelSuffix = sameAisle.where((c) {
      final p = parseAisleLocation(c);
      if (p == null) return false;
      return p.level.toUpperCase() == currentParsed.level.toUpperCase() &&
          p.suffix.toUpperCase() == currentParsed.suffix.toUpperCase();
    });

    if (sameLevelSuffix.isNotEmpty) {
      filtered = sameLevelSuffix;
    } else if (sameAisle.isNotEmpty) {
      filtered = sameAisle;
    }
  }

  // Score a small subset; UI only needs one good suggestion.
  final topCandidates = filtered.take(30);
  LocationPrediction? best;

  for (final loc in topCandidates) {
    final assessment = assessLocation(
      location: loc,
      so: so,
      active: activeStaging,
      shipped: shipped,
      ignoreEntryId: ignoreEntryId,
    );

    final vacantScore = assessment.vacant ? 100 : 0;
    final differentOrderPenalty = assessment.occupiedByDifferentOrder ? 60 : 0;
    final consolidationBonus = assessment.hasConsolidationOpportunity ? 20 : 0;

    final score = vacantScore + consolidationBonus - differentOrderPenalty;
    if (best == null || score > best.score) {
      best = LocationPrediction(
        suggestedLocation: loc.trim(),
        reason: assessment.vacant
            ? 'Vacant aisle slot for SO $so'
            : assessment.occupiedByDifferentOrder
                ? 'Has mixed SO occupancy'
                : assessment.hasConsolidationOpportunity
                    ? 'Best for consolidation / same-SO reuse'
                    : 'Better fit than current assignment',
        score: score.toDouble(),
      );
    }
  }

  // Only show a suggestion when it meaningfully improves the outcome.
  if (best == null || best.score < 80) return null;
  return best;
}

