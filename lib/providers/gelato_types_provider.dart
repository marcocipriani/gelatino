import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/gelato_type.dart';

List<GelatoType> mergeGelatoTypes({
  required List<GelatoType> defaults,
  required List<GelatoType> remote,
}) {
  final byId = {for (final type in defaults) type.id: type};

  for (final type in remote) {
    byId[type.id] = type;
  }

  final active = byId.values.where((type) => type.isActive).toList();
  active.sort((a, b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    return order != 0 ? order : a.name.compareTo(b.name);
  });
  return active;
}

final gelatoTypesProvider = StreamProvider<List<GelatoType>>((ref) async* {
  yield defaultGelatoTypes;

  yield* ref
      .watch(firestoreProvider)
      .collection('gelato_types')
      .snapshots()
      .map(
        (snapshot) => mergeGelatoTypes(
          defaults: defaultGelatoTypes,
          remote: snapshot.docs
              .map((doc) => GelatoType.fromMap(doc.data(), doc.id))
              .toList(),
        ),
      );
});
