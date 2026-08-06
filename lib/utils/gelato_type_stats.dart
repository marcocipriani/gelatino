import '../models/check_in.dart';
import '../models/gelato_type.dart';

class _GelatoTypeUsage {
  _GelatoTypeUsage(this.snapshot);

  int count = 0;
  DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);
  GelatoType snapshot;
}

Map<String, _GelatoTypeUsage> _usageByType(List<CheckIn> checkIns) {
  final usage = <String, _GelatoTypeUsage>{};

  for (final checkIn in checkIns) {
    final type = checkIn.gelatoType;
    if (type == null) continue;

    final value = usage.putIfAbsent(type.id, () => _GelatoTypeUsage(type));
    value.count++;
    if (checkIn.createdAt.isAfter(value.latest)) {
      value.latest = checkIn.createdAt;
      value.snapshot = type;
    }
  }

  return usage;
}

GelatoType? favoriteGelatoType(List<CheckIn> checkIns) {
  final entries = _usageByType(checkIns).values.toList()
    ..sort((a, b) {
      final frequency = b.count.compareTo(a.count);
      if (frequency != 0) return frequency;
      return b.latest.compareTo(a.latest);
    });

  return entries.isEmpty ? null : entries.first.snapshot;
}

String favoriteGelatoTypeLabel(List<CheckIn> checkIns) {
  return favoriteGelatoType(checkIns)?.name ?? '—';
}

List<GelatoType> compactGelatoTypes({
  required List<GelatoType> catalog,
  required List<CheckIn> checkIns,
  GelatoType? selected,
  int limit = 4,
}) {
  final usage = _usageByType(checkIns);
  final ranked = catalog.where((type) => usage.containsKey(type.id)).toList()
    ..sort((a, b) {
      final aUsage = usage[a.id]!;
      final bUsage = usage[b.id]!;
      final frequency = bUsage.count.compareTo(aUsage.count);
      if (frequency != 0) return frequency;

      final recency = bUsage.latest.compareTo(aUsage.latest);
      if (recency != 0) return recency;

      return a.sortOrder.compareTo(b.sortOrder);
    });

  for (final type in catalog) {
    if (ranked.length >= limit) break;
    if (!ranked.any((item) => item.id == type.id)) {
      ranked.add(type);
    }
  }

  final result = ranked.take(limit).toList();
  if (selected != null && !result.any((type) => type.id == selected.id)) {
    result.add(selected);
  }
  return result;
}
