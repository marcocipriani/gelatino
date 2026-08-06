import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/check_in_draft.dart';

abstract interface class DraftPreferences {
  String? getString(String key);

  Future<bool> setString(String key, String value);

  Future<bool> remove(String key);
}

final class SharedPreferencesDraftPreferences implements DraftPreferences {
  const SharedPreferencesDraftPreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);
}

abstract interface class CheckInDraftRepository {
  Future<CheckInDraft?> load(String uid);

  Future<void> save(String uid, CheckInDraft draft);

  Future<void> clear(String uid);
}

final class PersistentCheckInDraftRepository implements CheckInDraftRepository {
  PersistentCheckInDraftRepository(this._preferences);

  final DraftPreferences _preferences;
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  @override
  Future<CheckInDraft?> load(String uid) async {
    _requireUid(uid);
    final pending = _tails[uid];
    if (pending != null) await pending;
    final encoded = _preferences.getString(_key(uid));
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('check-in draft: expected JSON object');
    }
    return CheckInDraft.fromJson(value);
  }

  @override
  Future<void> save(String uid, CheckInDraft draft) {
    _requireUid(uid);
    final encoded = jsonEncode(draft.toJson());
    return _enqueue(uid, () async {
      if (!await _preferences.setString(_key(uid), encoded)) {
        throw StateError('Impossibile salvare la bozza del check-in.');
      }
    });
  }

  @override
  Future<void> clear(String uid) {
    _requireUid(uid);
    return _enqueue(uid, () async {
      if (!await _preferences.remove(_key(uid))) {
        throw StateError('Impossibile eliminare la bozza del check-in.');
      }
    });
  }

  Future<void> _enqueue(String uid, Future<void> Function() action) {
    final previous = _tails[uid];
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // A later mutation must still be allowed to repair a failed write.
        }
      }
      await action();
    }();
    _tails[uid] = operation;
    return operation;
  }

  String _key(String uid) => 'check_in_draft_v2_$uid';
}

void _requireUid(String uid) {
  if (uid.isEmpty || uid.length > 128 || uid.contains('/')) {
    throw const FormatException('uid: invalid');
  }
}
