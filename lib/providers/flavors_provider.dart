import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/firestore_parsing.dart';
import '../models/flavor.dart';
import 'auth_provider.dart';

final flavorsProvider = StreamProvider<List<Flavor>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('flavors')
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => List<Flavor>.unmodifiable(
          snapshot.docs.map(
            (document) => Flavor.fromMap(document.data(), document.id),
          ),
        ),
      );
});

class FlavorService {
  FlavorService(this._firestore, this._readCurrentUid);

  final FirebaseFirestore _firestore;
  final String? Function() _readCurrentUid;

  Future<Flavor> addFlavor(String name, {String? colorHex}) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('name: must not be empty');
    }
    final normalizedColor = colorHex?.trim();
    if (normalizedColor != null &&
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalizedColor)) {
      throw const FormatException('color_hex: invalid color');
    }
    final uid = _readCurrentUid();
    if (uid == null) throw const FormatException('uid: invalid ID');
    requirePathSegment(uid, 'uid');
    final document = await _firestore
        .collection('flavors')
        .add(<String, Object?>{
          'name': normalizedName,
          'name_lower': normalizedName.toLowerCase(),
          'color_hex': normalizedColor,
          'added_by_uid': uid,
          'created_at': FieldValue.serverTimestamp(),
        });
    return Flavor(
      id: document.id,
      name: normalizedName,
      colorHex: normalizedColor,
    );
  }
}

final flavorServiceProvider = Provider<FlavorService>((ref) {
  return FlavorService(
    ref.watch(firestoreProvider),
    () => ref.read(currentUidProvider),
  );
});
