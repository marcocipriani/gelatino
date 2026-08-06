import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in_draft.dart';
import 'package:gelatino/repositories/check_in_draft_repository.dart';

void main() {
  const id = 'ABCDEFGHIJKLMNOPQRST';

  CheckInDraft draft(int step) => CheckInDraft(
    id: id,
    currentStep: step,
    localPhotoName: null,
    stagingObjectPath: null,
    placeId: null,
    pendingPlace: null,
    gelatoTypeId: null,
    flavorIds: const [],
    rating: null,
    reviewText: '',
    taggedUserIds: const [],
    updatedAt: DateTime.utc(2026, 7, 15, 8, step),
  );

  test('isolates drafts by UID and clears only the requested user', () async {
    final preferences = _MemoryDraftPreferences();
    final repository = PersistentCheckInDraftRepository(preferences);

    await repository.save('alice', draft(1));
    await repository.save('bob', draft(2));

    expect(await repository.load('alice'), draft(1));
    expect(await repository.load('bob'), draft(2));
    await repository.clear('alice');
    expect(await repository.load('alice'), isNull);
    expect(await repository.load('bob'), draft(2));
    expect(preferences.keys, containsAll(['check_in_draft_v2_bob']));
  });

  test('serializes concurrent saves so the newest draft wins', () async {
    final preferences = _ControlledDraftPreferences();
    final repository = PersistentCheckInDraftRepository(preferences);

    final first = repository.save('alice', draft(1));
    final second = repository.save('alice', draft(2));
    expect(preferences.pendingWrites, hasLength(1));

    preferences.completeNext();
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(preferences.pendingWrites, hasLength(1));
    preferences.completeNext();
    await second;

    expect(await repository.load('alice'), draft(2));
  });

  test('save and clear failures are surfaced', () async {
    final preferences = _MemoryDraftPreferences()..succeed = false;
    final repository = PersistentCheckInDraftRepository(preferences);

    await expectLater(repository.save('alice', draft(0)), throwsStateError);
    await expectLater(repository.clear('alice'), throwsStateError);
  });

  test(
    'malformed persisted JSON fails instead of replacing the draft',
    () async {
      final preferences = _MemoryDraftPreferences()
        ..values['check_in_draft_v2_alice'] = '{bad json';
      final repository = PersistentCheckInDraftRepository(preferences);

      await expectLater(repository.load('alice'), throwsFormatException);
    },
  );
}

final class _MemoryDraftPreferences implements DraftPreferences {
  final Map<String, String> values = {};
  bool succeed = true;

  Iterable<String> get keys => values.keys;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> remove(String key) async {
    if (!succeed) return false;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (!succeed) return false;
    values[key] = value;
    return true;
  }
}

final class _ControlledDraftPreferences extends _MemoryDraftPreferences {
  final List<({String key, String value, Completer<bool> completer})>
  pendingWrites = [];

  @override
  Future<bool> setString(String key, String value) {
    final completer = Completer<bool>();
    pendingWrites.add((key: key, value: value, completer: completer));
    return completer.future.then((success) {
      if (success) values[key] = value;
      return success;
    });
  }

  void completeNext() {
    final write = pendingWrites.removeAt(0);
    write.completer.complete(true);
  }
}
