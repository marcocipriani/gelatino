import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/flavor.dart';

void main() {
  group('Flavor Model Tests', () {
    test('fromMap should parse standard map correctly', () {
      final map = {
        'name': 'Pistacchio',
        'color_hex': '#00FF00',
      };

      final flavor = Flavor.fromMap(map, 'flavor_1');

      expect(flavor.id, 'flavor_1');
      expect(flavor.name, 'Pistacchio');
      expect(flavor.colorHex, '#00FF00');
    });

    test('fromMap should fallback to default values', () {
      final map = <String, dynamic>{};

      final flavor = Flavor.fromMap(map, 'flavor_2');

      expect(flavor.id, 'flavor_2');
      expect(flavor.name, '');
      expect(flavor.colorHex, isNull);
    });

    test('toMap should serialize flavor details', () {
      final flavor = Flavor(
        id: 'flavor_3',
        name: 'Nocciola',
        colorHex: '#8B4513',
      );

      final map = flavor.toMap();

      expect(map['name'], 'Nocciola');
      expect(map['color_hex'], '#8B4513');
    });
  });
}
