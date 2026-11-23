import 'dart:ui';

/// Greedy declutter in screen space: each group's first item is its anchor and
/// no two anchors' boxes of [spacing] overlap. Feed items in priority order —
/// earlier items become anchors. The grid keeps this linear in the item count.
// ponytail: greedy, so a count sits on its anchor, not the group's centroid.
// Reach for supercluster only if the catalog reaches tens of thousands.
List<List<T>> clusterByProximity<T>(
  Iterable<T> items, {
  required Offset Function(T item) position,
  required Size spacing,
}) {
  final groups = <List<T>>[];
  final anchors = <Offset>[];
  final grid = <(int, int), List<int>>{};

  for (final item in items) {
    final point = position(item);
    final column = (point.dx / spacing.width).floor();
    final row = (point.dy / spacing.height).floor();

    int? nearest;
    var nearestDistance = double.infinity;
    for (var x = column - 1; x <= column + 1; x++) {
      for (var y = row - 1; y <= row + 1; y++) {
        for (final index in grid[(x, y)] ?? const <int>[]) {
          final delta = anchors[index] - point;
          if (delta.dx.abs() < spacing.width &&
              delta.dy.abs() < spacing.height &&
              delta.distanceSquared < nearestDistance) {
            nearest = index;
            nearestDistance = delta.distanceSquared;
          }
        }
      }
    }

    if (nearest != null) {
      groups[nearest].add(item);
    } else {
      (grid[(column, row)] ??= <int>[]).add(groups.length);
      groups.add(<T>[item]);
      anchors.add(point);
    }
  }
  return groups;
}
