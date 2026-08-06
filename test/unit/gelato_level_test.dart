import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/gelato_level.dart';

void main() {
  test('uses server points at every tier boundary', () {
    expect(GelatoLevel.forPoints(0).tier.name, 'Leccata');
    expect(GelatoLevel.forPoints(49).tier.name, 'Leccata');
    expect(GelatoLevel.forPoints(50).tier.name, 'Coppetta');
    expect(GelatoLevel.forPoints(149).tier.name, 'Coppetta');
    expect(GelatoLevel.forPoints(150).tier.name, 'Cono');
    expect(GelatoLevel.forPoints(349).tier.name, 'Cono');
    expect(GelatoLevel.forPoints(350).tier.name, 'Vaschetta');
    expect(GelatoLevel.forPoints(699).tier.name, 'Vaschetta');
    expect(GelatoLevel.forPoints(700).tier.name, 'Carretto');
  });

  test('computes progress and points remaining inside a tier', () {
    final level = GelatoLevel.forPoints(100);

    expect(level.progress, 0.5);
    expect(level.pointsToNext, 50);
    expect(level.isMaxed, isFalse);
  });

  test('max tier is complete and has no next tier', () {
    final level = GelatoLevel.forPoints(900);

    expect(level.progress, 1);
    expect(level.pointsToNext, 0);
    expect(level.next, isNull);
  });

  test('rejects negative server points', () {
    expect(() => GelatoLevel.forPoints(-1), throwsArgumentError);
  });
}
