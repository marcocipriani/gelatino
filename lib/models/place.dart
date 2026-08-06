import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.geohash,
    required this.createdAt,
    this.addedByUid,
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final String geohash;
  final DateTime createdAt;
  final String? addedByUid;

  factory Place.fromFirestore(DocumentSnapshot doc) {
    final data = _documentData(doc);
    return Place.fromMap(data, doc.id);
  }

  factory Place.fromMap(Map<String, dynamic> data, String id) =>
      _fromCanonical(id, data);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'address': address,
    'location': location,
    'geohash': geohash,
    'added_by_uid': addedByUid,
    'created_at': Timestamp.fromDate(createdAt),
  };

  Place copyWith({
    String? name,
    String? address,
    GeoPoint? location,
    String? geohash,
    DateTime? createdAt,
    String? addedByUid,
  }) {
    return Place(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      createdAt: createdAt ?? this.createdAt,
      addedByUid: addedByUid ?? this.addedByUid,
    );
  }
}

Place _fromCanonical(String id, Map<String, dynamic> data) {
  _requireId(id, 'document id');
  final name = requireString(data, 'name');
  final address = requireString(data, 'address');
  if (name.isEmpty) {
    throw const FormatException('name: must not be empty');
  }
  if (address.isEmpty) {
    throw const FormatException('address: must not be empty');
  }
  final rawLocation = data['location'];
  if (rawLocation is! GeoPoint) {
    throw FormatException(
      'location: expected GeoPoint, got ${rawLocation.runtimeType}',
    );
  }
  final addedByUid = optionalString(data, 'added_by_uid');
  if (addedByUid != null) {
    _requireId(addedByUid, 'added_by_uid');
  }
  return Place(
    id: id,
    name: name,
    address: address,
    location: rawLocation,
    geohash: requireString(data, 'geohash'),
    createdAt: requireTimestamp(data, 'created_at'),
    addedByUid: addedByUid,
  );
}

Map<String, dynamic> _documentData(DocumentSnapshot doc) {
  final value = doc.data();
  if (value is! Map<String, dynamic>) {
    throw const FormatException('document: expected Map<String, dynamic>');
  }
  return value;
}

final RegExp _validId = RegExp(r'^[^/\x00-\x1F\x7F]{1,128}$');

void _requireId(String value, String label) {
  if (!_validId.hasMatch(value)) throw FormatException('$label: invalid ID');
}
