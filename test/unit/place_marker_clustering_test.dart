import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/widgets/places/place_marker_clustering.dart';

void main() {
  test('loses nothing and leaves no two anchors overlapping', () {
    final random = Random(7);
    // Negative coordinates included: grid cells must floor, not truncate.
    final points = List.generate(
      600,
      (_) => Offset(
        random.nextDouble() * 900 - 450,
        random.nextDouble() * 900 - 450,
      ),
    );
    const spacing = Size(57, 74);
    final groups = clusterByProximity(
      points,
      position: (point) => point,
      spacing: spacing,
    );

    expect(groups.expand((group) => group).toSet(), points.toSet());
    expect(groups.fold<int>(0, (sum, group) => sum + group.length), 600);
    expect(groups.first.first, points.first, reason: 'priority order anchors');
    for (var i = 0; i < groups.length; i++) {
      for (var j = i + 1; j < groups.length; j++) {
        final delta = groups[i].first - groups[j].first;
        expect(
          delta.dx.abs() >= spacing.width || delta.dy.abs() >= spacing.height,
          isTrue,
        );
      }
    }
  });
}
