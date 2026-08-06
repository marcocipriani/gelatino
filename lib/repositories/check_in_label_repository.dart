import 'dart:async';
import 'dart:convert';

import 'check_in_draft_repository.dart';

final class CheckInDisplayLabels {
  const CheckInDisplayLabels({
    this.placeNames = const <String, String>{},
    this.typeNames = const <String, String>{},
    this.flavorNames = const <String, String>{},
    this.friendNames = const <String, String>{},
  });

  final Map<String, String> placeNames;
  final Map<String, String> typeNames;
  final Map<String, String> flavorNames;
  final Map<String, String> friendNames;

  Map<String, Object> toJson() => <String, Object>{
    'version': 1,
    'places': placeNames,
    'types': typeNames,
    'flavors': flavorNames,
    'friends': friendNames,
  };

  factory CheckInDisplayLabels.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('check-in labels: unsupported version');
    }
    return CheckInDisplayLabels(
      placeNames: _stringMap(json['places']),
      typeNames: _stringMap(json['types']),
      flavorNames: _stringMap(json['flavors']),
      friendNames: _stringMap(json['friends']),
    );
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in value.entries)
        if (entry.key is String &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty)
          entry.key as String: entry.value as String,
    };
  }
}

abstract interface class CheckInLabelRepository {
  Future<CheckInDisplayLabels> load(String uid, String draftId);

  Future<void> save(String uid, String draftId, CheckInDisplayLabels labels);

  Future<void> clear(String uid, String draftId);
}

final class PersistentCheckInLabelRepository implements CheckInLabelRepository {
  PersistentCheckInLabelRepository(this._preferences);

  final DraftPreferences _preferences;
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  @override
  Future<CheckInDisplayLabels> load(String uid, String draftId) async {
    final key = _key(uid, draftId);
    final pending = _tails[key];
    if (pending != null) await pending;
    final encoded = _preferences.getString(key);
    if (encoded == null) return const CheckInDisplayLabels();
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('check-in labels: expected JSON object');
    }
    return CheckInDisplayLabels.fromJson(decoded);
  }

  @override
  Future<void> save(String uid, String draftId, CheckInDisplayLabels labels) =>
      _enqueue(_key(uid, draftId), () async {
        final encoded = jsonEncode(labels.toJson());
        if (!await _preferences.setString(_key(uid, draftId), encoded)) {
          throw StateError('Impossibile salvare le etichette del check-in.');
        }
      });

  @override
  Future<void> clear(String uid, String draftId) =>
      _enqueue(_key(uid, draftId), () async {
        if (!await _preferences.remove(_key(uid, draftId))) {
          throw StateError('Impossibile eliminare le etichette del check-in.');
        }
      });

  Future<void> _enqueue(String key, Future<void> Function() action) {
    final previous = _tails[key];
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // A later write must still be allowed to repair the cache.
        }
      }
      await action();
    }();
    _tails[key] = operation;
    return operation;
  }

  String _key(String uid, String draftId) {
    if (uid.isEmpty || draftId.isEmpty) {
      throw const FormatException('check-in labels: invalid key');
    }
    return 'check_in_display_labels_v1.${_component(uid)}.${_component(draftId)}';
  }

  String _component(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}

final class InMemoryCheckInLabelRepository implements CheckInLabelRepository {
  final Map<String, CheckInDisplayLabels> _values =
      <String, CheckInDisplayLabels>{};

  @override
  Future<void> clear(String uid, String draftId) async {
    _values.remove('$uid/$draftId');
  }

  @override
  Future<CheckInDisplayLabels> load(String uid, String draftId) async =>
      _values['$uid/$draftId'] ?? const CheckInDisplayLabels();

  @override
  Future<void> save(
    String uid,
    String draftId,
    CheckInDisplayLabels labels,
  ) async {
    _values['$uid/$draftId'] = labels;
  }
}
