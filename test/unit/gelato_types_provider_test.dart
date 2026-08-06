import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/gelato_type.dart';
import 'package:gelatino/providers/gelato_types_provider.dart';

void main() {
  group('mergeGelatoTypes', () {
    test('remote documents override defaults and can disable them', () {
      final merged = mergeGelatoTypes(
        defaults: defaultGelatoTypes,
        remote: const [
          GelatoType(id: 'cono', name: 'Cono XL', sortOrder: 20),
          GelatoType(id: 'nuovo', name: 'Nuovo', sortOrder: 1),
          GelatoType(
            id: 'coppetta',
            name: 'Coppetta',
            sortOrder: 2,
            isActive: false,
          ),
        ],
      );

      expect(merged.first.name, 'Nuovo');
      expect(merged.any((type) => type.id == 'coppetta'), isFalse);
      expect(merged.singleWhere((type) => type.id == 'cono').name, 'Cono XL');
    });

    test('uses the name as deterministic tie breaker', () {
      final merged = mergeGelatoTypes(
        defaults: const [],
        remote: const [
          GelatoType(id: 'z', name: 'Zabaione', sortOrder: 2),
          GelatoType(id: 'a', name: 'Affogato', sortOrder: 2),
        ],
      );

      expect(merged.map((type) => type.name), ['Affogato', 'Zabaione']);
    });
  });
}
