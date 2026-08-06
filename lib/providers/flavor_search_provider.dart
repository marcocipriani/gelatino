import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import 'timeline_providers.dart';

const _accents = {
  'à': 'a', 'á': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'í': 'i',
  'ò': 'o', 'ó': 'o', 'ù': 'u', 'ú': 'u',
};

String normalizeFlavorQuery(String raw) {
  var value = raw.trim().toLowerCase();
  _accents.forEach((from, to) => value = value.replaceAll(from, to));
  return value;
}

class FlavorPlaceMatch {
  const FlavorPlaceMatch({
    required this.flavorName,
    required this.colorHex,
    required this.bestRating,
    required this.tastings,
  });
  final String flavorName; // nome originale per la chip
  final String? colorHex;
  final int bestRating;
  final int tastings;
}

Map<String, Map<String, FlavorPlaceMatch>> buildFlavorIndex(
  List<FeedItem> items,
) {
  final index = <String, Map<String, FlavorPlaceMatch>>{};
  for (final item in items) {
    for (final flavor in item.flavors) {
      final name = flavor['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final key = normalizeFlavorQuery(name);
      final perPlace = index.putIfAbsent(key, () => {});
      final existing = perPlace[item.placeId];
      perPlace[item.placeId] = FlavorPlaceMatch(
        flavorName: existing?.flavorName ?? name,
        colorHex: existing?.colorHex ?? flavor['color_hex'] as String?,
        bestRating: existing == null
            ? item.rating
            : (item.rating > existing.bestRating
                  ? item.rating
                  : existing.bestRating),
        tastings: (existing?.tastings ?? 0) + 1,
      );
    }
  }
  return index;
}

Map<String, FlavorPlaceMatch>? lookupFlavor(
  Map<String, Map<String, FlavorPlaceMatch>> index,
  String query,
) {
  final normalized = normalizeFlavorQuery(query);
  if (normalized.length < 3) return null;
  final merged = <String, FlavorPlaceMatch>{};
  for (final entry in index.entries) {
    if (!entry.key.startsWith(normalized)) continue;
    for (final place in entry.value.entries) {
      final existing = merged[place.key];
      if (existing == null || place.value.bestRating > existing.bestRating) {
        merged[place.key] = place.value;
      }
    }
  }
  return merged.isEmpty ? null : merged;
}

// ponytail: indice dai check-in caricati nel feed (tuoi + amici). Se il feed
// è paginato la ricerca copre quelli; upgrade path = aggregato gusti
// server-side per gelateria.
final flavorIndexProvider =
    Provider.autoDispose<Map<String, Map<String, FlavorPlaceMatch>>>((ref) {
      return buildFlavorIndex(ref.watch(timelineProvider).items);
    });
