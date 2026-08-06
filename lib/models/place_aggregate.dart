import 'firestore_parsing.dart';

final class PlaceAggregate {
  const PlaceAggregate({
    required this.placeId,
    required this.checkInCount,
    required this.ratingSum,
    required this.ratingAverage,
    required this.updatedAt,
  });

  final String placeId;
  final int checkInCount;
  final int ratingSum;
  final double ratingAverage;
  final DateTime updatedAt;

  factory PlaceAggregate.fromMap(Map<String, dynamic> data, String placeId) {
    requirePathSegment(placeId, 'placeId');
    if (data.length != _keys.length || !data.keys.toSet().containsAll(_keys)) {
      throw const FormatException('place aggregate: invalid fields');
    }

    final checkInCount = requireInt(data, 'check_in_count');
    final ratingSum = requireInt(data, 'rating_sum');
    final averageValue = data['rating_average'];
    if (averageValue is! num || !averageValue.isFinite) {
      throw const FormatException('rating_average: expected finite number');
    }
    final ratingAverage = averageValue.toDouble();
    _validateValues(checkInCount, ratingSum, ratingAverage);

    return PlaceAggregate(
      placeId: placeId,
      checkInCount: checkInCount,
      ratingSum: ratingSum,
      ratingAverage: ratingAverage,
      updatedAt: requireTimestamp(data, 'updated_at'),
    );
  }
}

const Set<String> _keys = <String>{
  'check_in_count',
  'rating_sum',
  'rating_average',
  'updated_at',
};

void _validateValues(int count, int sum, double average) {
  if (count < 0 || sum < 0 || average < 0 || average > 5) {
    throw const FormatException('place aggregate: values out of range');
  }
  if (count == 0) {
    if (sum != 0 || average != 0) {
      throw const FormatException('place aggregate: invalid empty values');
    }
    return;
  }
  if (sum < count || sum > count * 5) {
    throw const FormatException('rating_sum: inconsistent with count');
  }
  final expectedAverage = sum / count;
  if ((average - expectedAverage).abs() > 1e-9) {
    throw const FormatException('rating_average: inconsistent with sum');
  }
}
