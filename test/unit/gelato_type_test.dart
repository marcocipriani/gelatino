import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/gelato_type.dart';

void main() {
  group('GelatoType', () {
    test('parses a remote catalog document', () {
      final type = GelatoType.fromMap({
        'name': 'Cono grande',
        'sort_order': 7,
        'is_active': false,
      }, 'cono');

      expect(
        type,
        const GelatoType(
          id: 'cono',
          name: 'Cono grande',
          sortOrder: 7,
          isActive: false,
        ),
      );
    });

    test('serializes a stable check-in snapshot', () {
      const type = GelatoType(id: 'cono', name: 'Cono', sortOrder: 0);

      expect(type.toSnapshotMap(), {'id': 'cono', 'name': 'Cono'});
      expect(GelatoType.fromSnapshotMap(type.toSnapshotMap()), type);
    });

    test('ships the agreed default catalog in order', () {
      expect(defaultGelatoTypes.map((type) => type.name), [
        'Cono',
        'Coppetta',
        'Brioche',
        'Vaschetta',
        'Frappè',
        'Affogato',
        'Granita',
        'Stecco',
        'Biscotto gelato',
        'Coppa dessert',
        'Semifreddo',
        'Torta gelato',
        'Altro',
      ]);
    });
  });
}
