import 'package:flutter/material.dart';

/// A "Formato" tier in the gelato leveling system. Tiers progress by serving
/// size: a quick lick all the way up to a full gelato cart.
class GelatoTier {
  final String name;
  final int threshold; // Punti gusto needed to reach this tier.
  final IconData icon;

  const GelatoTier(this.name, this.threshold, this.icon);
}

/// Computed level state for a user, derived from their "Punti gusto".
class GelatoLevel {
  final int points;
  final int tierIndex;
  final GelatoTier tier;
  final GelatoTier? next;

  /// 0..1 progress from the current tier toward the next one (1 if maxed).
  final double progress;

  /// Punti gusto still needed to reach [next] (0 if maxed).
  final int pointsToNext;

  const GelatoLevel({
    required this.points,
    required this.tierIndex,
    required this.tier,
    required this.next,
    required this.progress,
    required this.pointsToNext,
  });

  bool get isMaxed => next == null;

  /// Progression by serving size (Formati).
  static const List<GelatoTier> tiers = [
    GelatoTier('Leccata', 0, Icons.water_drop_rounded),
    GelatoTier('Coppetta', 50, Icons.local_cafe_rounded),
    GelatoTier('Cono', 150, Icons.icecream_rounded),
    GelatoTier('Vaschetta', 350, Icons.inventory_2_rounded),
    GelatoTier('Carretto', 700, Icons.storefront_rounded),
  ];

  factory GelatoLevel.forPoints(int points) {
    if (points < 0) {
      throw ArgumentError.value(points, 'points', 'must be non-negative');
    }
    int index = 0;
    for (int i = 0; i < tiers.length; i++) {
      if (points >= tiers[i].threshold) index = i;
    }
    final GelatoTier tier = tiers[index];
    final GelatoTier? next = index + 1 < tiers.length ? tiers[index + 1] : null;

    double progress = 1;
    int pointsToNext = 0;
    if (next != null) {
      final span = next.threshold - tier.threshold;
      progress = ((points - tier.threshold) / span).clamp(0.0, 1.0);
      pointsToNext = next.threshold - points;
    }

    return GelatoLevel(
      points: points,
      tierIndex: index,
      tier: tier,
      next: next,
      progress: progress,
      pointsToNext: pointsToNext,
    );
  }
}
