import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Never _invalid(String key, String expected, Object? value) {
  final actual = value == null ? 'null' : value.runtimeType.toString();
  throw FormatException('$key: expected $expected, got $actual');
}

String requireString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String) return _invalid(key, 'String', value);
  return value;
}

String? optionalString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! String) return _invalid(key, 'String or null', value);
  return value;
}

String? optionalStoragePath(Map<String, dynamic> data, String key) {
  final value = optionalString(data, key);
  if (value == null) return null;
  requireStoragePath(value, key);
  return value;
}

void requireStoragePath(String value, String key) {
  final uri = Uri.tryParse(value);
  final segments = value.split('/');
  if (value.isEmpty ||
      value.length > 1024 ||
      value.startsWith('/') ||
      value.contains('\\') ||
      _controlCharacters.hasMatch(value) ||
      uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw FormatException('$key: invalid storage path');
  }
}

final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

void requirePathSegment(String value, String key) {
  if (!_validPathSegment.hasMatch(value)) {
    throw FormatException('$key: invalid ID');
  }
}

final RegExp _validPathSegment = RegExp(r'^[^/\x00-\x1F\x7F]{1,128}$');

int requireInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! int) return _invalid(key, 'int', value);
  return value;
}

bool optionalBool(
  Map<String, dynamic> data,
  String key, {
  bool fallback = false,
}) {
  if (!data.containsKey(key)) return fallback;
  final value = data[key];
  if (value is! bool) return _invalid(key, 'bool', value);
  return value;
}

DateTime requireTimestamp(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! Timestamp) return _invalid(key, 'Timestamp', value);
  return value.toDate();
}

DateTime? optionalTimestamp(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! Timestamp) return _invalid(key, 'Timestamp or null', value);
  return value.toDate();
}

List<String> stringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! List) return _invalid(key, 'List<String>', value);
  final result = <String>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! String) return _invalid('$key[$index]', 'String', item);
    result.add(item);
  }
  return List<String>.unmodifiable(result);
}

Map<String, dynamic> stringMap(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! Map) return _invalid(key, 'Map<String, dynamic>', value);
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final entryKey = entry.key;
    if (entryKey is! String) {
      return _invalid('$key key', 'String', entryKey);
    }
    result[entryKey] = entry.value;
  }
  return Map<String, dynamic>.unmodifiable(result);
}

final RegExp _monthKeyPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// Parses an optional `monthly_points` map: absent => {}. UTC month keys.
Map<String, int> monthlyPointsFrom(Map<String, dynamic> data) {
  final raw = data['monthly_points'];
  if (raw == null) return const <String, int>{};
  if (raw is! Map) {
    throw const FormatException('monthly_points: must be a map');
  }
  final result = <String, int>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || !_monthKeyPattern.hasMatch(key)) {
      throw const FormatException('monthly_points: invalid month key');
    }
    if (value is! int || value < 0) {
      throw const FormatException('monthly_points: must be non-negative ints');
    }
    result[key] = value;
  }
  return Map<String, int>.unmodifiable(result);
}

T? parseOrReport<T>({required String path, required T Function() parse}) {
  try {
    return parse();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while parsing Firestore document $path'),
      ),
    );
    return null;
  }
}

final RegExp _photoColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Optional `photo_color` (`#RRGGBB`, server-validated) as opaque ARGB.
int? parsePhotoColor(Map<String, dynamic> data) {
  final value = optionalString(data, 'photo_color');
  if (value == null) return null;
  if (!_photoColor.hasMatch(value)) {
    throw const FormatException('photo_color: expected #RRGGBB');
  }
  return 0xFF000000 | int.parse(value.substring(1), radix: 16);
}
