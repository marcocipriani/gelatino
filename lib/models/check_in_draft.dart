import 'package:uuid/uuid.dart';

final RegExp _checkInIdPattern = RegExp(r'^[A-Za-z0-9_-]{20,64}$');
final RegExp _pathSegmentPattern = RegExp(r'^[^/\x00-\x1f\x7f]{1,128}$');
const Object _unset = Object();

final class PendingPlaceDraft {
  PendingPlaceDraft({
    required String name,
    required String address,
    this.latitude,
    this.longitude,
  }) : name = name.trim(),
       address = address.trim() {
    if ((latitude == null) != (longitude == null)) {
      throw const FormatException('pending_place: partial coordinates');
    }
    if (latitude case final latitude?) {
      if (!latitude.isFinite || latitude < -90 || latitude > 90) {
        throw const FormatException('pending_place.latitude: invalid');
      }
    }
    if (longitude case final longitude?) {
      if (!longitude.isFinite || longitude < -180 || longitude > 180) {
        throw const FormatException('pending_place.longitude: invalid');
      }
    }
  }

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory PendingPlaceDraft.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'name',
      'address',
      'latitude',
      'longitude',
    }, 'pending_place');
    return PendingPlaceDraft(
      name: _string(json, 'name'),
      address: _string(json, 'address'),
      latitude: _nullableDouble(json, 'latitude'),
      longitude: _nullableDouble(json, 'longitude'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PendingPlaceDraft &&
      other.name == name &&
      other.address == address &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, address, latitude, longitude);
}

final class CheckInDraft {
  /// Mirrors `MAX_CLOCK_SKEW_MS` / `MAX_BACKDATE_MS` in
  /// functions/src/domain/validation.ts so a backdated check-in fails in the
  /// picker rather than at publish time.
  static const Duration maxConsumedAtSkew = Duration(minutes: 5);
  static const Duration maxBackdate = Duration(days: 5 * 365);

  CheckInDraft({
    required this.id,
    required this.currentStep,
    required this.localPhotoName,
    required this.stagingObjectPath,
    required this.placeId,
    required this.pendingPlace,
    required this.gelatoTypeId,
    required List<String> flavorIds,
    required this.rating,
    required this.reviewText,
    required List<String> taggedUserIds,
    required DateTime updatedAt,
    DateTime? consumedAt,
  }) : flavorIds = List<String>.unmodifiable(flavorIds),
       taggedUserIds = List<String>.unmodifiable(taggedUserIds),
       updatedAt = updatedAt.toUtc(),
       consumedAt = consumedAt?.toUtc() {
    _validate();
  }

  factory CheckInDraft.create({
    String Function()? idGenerator,
    DateTime Function()? now,
  }) => CheckInDraft(
    id: (idGenerator ?? const Uuid().v4)(),
    currentStep: 0,
    localPhotoName: null,
    stagingObjectPath: null,
    placeId: null,
    pendingPlace: null,
    gelatoTypeId: null,
    flavorIds: const <String>[],
    rating: null,
    reviewText: '',
    taggedUserIds: const <String>[],
    updatedAt: (now ?? DateTime.now)(),
  );

  final String id;
  final int currentStep;
  final String? localPhotoName;
  final String? stagingObjectPath;
  final String? placeId;
  final PendingPlaceDraft? pendingPlace;
  final String? gelatoTypeId;
  final List<String> flavorIds;
  final int? rating;
  final String reviewText;
  final List<String> taggedUserIds;
  final DateTime updatedAt;

  /// When the gelato was eaten, when the user overrode "now". Null means the
  /// server stamps publication time, which is the ordinary case.
  final DateTime? consumedAt;

  bool get isPublishable =>
      stagingObjectPath != null &&
      placeId != null &&
      pendingPlace == null &&
      gelatoTypeId != null &&
      flavorIds.isNotEmpty &&
      rating != null;

  void _validate() {
    if (!_checkInIdPattern.hasMatch(id)) {
      throw const FormatException('id: invalid check-in ID');
    }
    if (currentStep < 0 || currentStep > 4) {
      throw const FormatException('current_step: expected 0 through 4');
    }
    _nullableSegment(localPhotoName, 'local_photo_name', allowSlash: true);
    _nullableSegment(placeId, 'place_id');
    _nullableSegment(gelatoTypeId, 'gelato_type_id');
    if (placeId != null && pendingPlace != null) {
      throw const FormatException('place: choose existing or pending');
    }
    if (stagingObjectPath case final path?) {
      final segments = path.split('/');
      if (segments.length != 3 ||
          segments[0] != 'staging' ||
          !_safeStorageSegment(segments[1]) ||
          segments[2] != '$id.jpg') {
        throw const FormatException('staging_object_path: invalid');
      }
    }
    _validateIds(flavorIds, 'flavor_ids', maximum: 4);
    _validateIds(taggedUserIds, 'tagged_user_ids', maximum: 10);
    if (rating != null && (rating! < 1 || rating! > 5)) {
      throw const FormatException('rating: expected 1 through 5');
    }
    if (reviewText.length > 500) {
      throw const FormatException('review_text: exceeds 500 characters');
    }
    if (consumedAt case final consumed?) {
      final now = DateTime.now().toUtc();
      if (consumed.isAfter(now.add(maxConsumedAtSkew))) {
        throw const FormatException('consumed_at: must not be in the future');
      }
      if (consumed.isBefore(now.subtract(maxBackdate))) {
        throw const FormatException('consumed_at: too far in the past');
      }
    }
  }

  CheckInDraft copyWith({
    int? currentStep,
    Object? localPhotoName = _unset,
    Object? stagingObjectPath = _unset,
    Object? placeId = _unset,
    Object? pendingPlace = _unset,
    Object? gelatoTypeId = _unset,
    List<String>? flavorIds,
    Object? rating = _unset,
    String? reviewText,
    List<String>? taggedUserIds,
    DateTime? updatedAt,
    Object? consumedAt = _unset,
  }) => CheckInDraft(
    id: id,
    currentStep: currentStep ?? this.currentStep,
    localPhotoName: identical(localPhotoName, _unset)
        ? this.localPhotoName
        : localPhotoName as String?,
    stagingObjectPath: identical(stagingObjectPath, _unset)
        ? this.stagingObjectPath
        : stagingObjectPath as String?,
    placeId: identical(placeId, _unset) ? this.placeId : placeId as String?,
    pendingPlace: identical(pendingPlace, _unset)
        ? this.pendingPlace
        : pendingPlace as PendingPlaceDraft?,
    gelatoTypeId: identical(gelatoTypeId, _unset)
        ? this.gelatoTypeId
        : gelatoTypeId as String?,
    flavorIds: flavorIds ?? this.flavorIds,
    rating: identical(rating, _unset) ? this.rating : rating as int?,
    reviewText: reviewText ?? this.reviewText,
    taggedUserIds: taggedUserIds ?? this.taggedUserIds,
    updatedAt: updatedAt ?? this.updatedAt,
    consumedAt: identical(consumedAt, _unset)
        ? this.consumedAt
        : consumedAt as DateTime?,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'current_step': currentStep,
    'local_photo_name': localPhotoName,
    'staging_object_path': stagingObjectPath,
    'place_id': placeId,
    'pending_place': pendingPlace?.toJson(),
    'gelato_type_id': gelatoTypeId,
    'flavor_ids': flavorIds,
    'rating': rating,
    'review_text': reviewText,
    'tagged_user_ids': taggedUserIds,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (consumedAt case final consumed?)
      'consumed_at': consumed.toUtc().toIso8601String(),
  };

  factory CheckInDraft.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'id',
      'current_step',
      'local_photo_name',
      'staging_object_path',
      'place_id',
      'pending_place',
      'gelato_type_id',
      'flavor_ids',
      'rating',
      'review_text',
      'tagged_user_ids',
      'updated_at',
    }, 'check-in draft', optional: const {'consumed_at'});
    final pendingJson = json['pending_place'];
    if (pendingJson != null && pendingJson is! Map<String, dynamic>) {
      throw const FormatException('pending_place: expected object or null');
    }
    final rawUpdatedAt = _string(json, 'updated_at');
    final updatedAt = DateTime.tryParse(rawUpdatedAt);
    if (updatedAt == null) {
      throw const FormatException('updated_at: invalid timestamp');
    }
    return CheckInDraft(
      id: _string(json, 'id'),
      currentStep: _integer(json, 'current_step'),
      localPhotoName: _nullableString(json, 'local_photo_name'),
      stagingObjectPath: _nullableString(json, 'staging_object_path'),
      placeId: _nullableString(json, 'place_id'),
      pendingPlace: pendingJson == null
          ? null
          : PendingPlaceDraft.fromJson(pendingJson),
      gelatoTypeId: _nullableString(json, 'gelato_type_id'),
      flavorIds: _stringList(json, 'flavor_ids'),
      rating: _nullableInteger(json, 'rating'),
      reviewText: _string(json, 'review_text'),
      taggedUserIds: _stringList(json, 'tagged_user_ids'),
      updatedAt: updatedAt,
      consumedAt: _optionalTimestamp(json, 'consumed_at'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CheckInDraft &&
      other.id == id &&
      other.currentStep == currentStep &&
      other.localPhotoName == localPhotoName &&
      other.stagingObjectPath == stagingObjectPath &&
      other.placeId == placeId &&
      other.pendingPlace == pendingPlace &&
      other.gelatoTypeId == gelatoTypeId &&
      _listsEqual(other.flavorIds, flavorIds) &&
      other.rating == rating &&
      other.reviewText == reviewText &&
      _listsEqual(other.taggedUserIds, taggedUserIds) &&
      other.updatedAt == updatedAt &&
      other.consumedAt == consumedAt;

  @override
  int get hashCode => Object.hash(
    id,
    currentStep,
    localPhotoName,
    stagingObjectPath,
    placeId,
    pendingPlace,
    gelatoTypeId,
    Object.hashAll(flavorIds),
    rating,
    reviewText,
    Object.hashAll(taggedUserIds),
    updatedAt,
    consumedAt,
  );
}

DateTime? _optionalTimestamp(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key: expected string or null');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key: invalid timestamp');
  return parsed;
}

void _validateIds(List<String> ids, String label, {required int maximum}) {
  if (ids.length > maximum || ids.toSet().length != ids.length) {
    throw FormatException('$label: invalid values');
  }
  for (final id in ids) {
    if (!_pathSegmentPattern.hasMatch(id)) {
      throw FormatException('$label: invalid ID');
    }
  }
}

void _nullableSegment(String? value, String label, {bool allowSlash = false}) {
  if (value == null) return;
  final valid = allowSlash
      ? value.trim().isNotEmpty && value.length <= 255
      : _pathSegmentPattern.hasMatch(value);
  if (!valid) throw FormatException('$label: invalid');
}

/// Every key in [expected] must be present and no key outside
/// [expected] + [optional] may appear. [optional] keeps drafts persisted before
/// a field existed readable after the upgrade.
void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label, {
  Set<String> optional = const <String>{},
}) {
  final keys = json.keys.toSet();
  if (!keys.containsAll(expected) ||
      !expected.union(optional).containsAll(keys)) {
    throw FormatException('$label: invalid fields');
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key: expected string');
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('$key: expected string or null');
  }
  return value as String?;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key: expected int');
  return value;
}

int? _nullableInteger(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! int) {
    throw FormatException('$key: expected int or null');
  }
  return value as int?;
}

double? _nullableDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! num) {
    throw FormatException('$key: expected number or null');
  }
  return (value as num?)?.toDouble();
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('$key: expected string list');
  }
  return value.cast<String>();
}

bool _listsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _safeStorageSegment(String value) {
  if (value.isEmpty || value.length > 128 || value == '.' || value == '..') {
    return false;
  }
  return value.codeUnits.every(
    (unit) =>
        unit > 0x1f &&
        unit != 0x7f &&
        unit != 0x2f &&
        unit != 0x5c &&
        unit != 0x3f &&
        unit != 0x23,
  );
}
