import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/repositories/check_in_draft_repository.dart';
import 'package:gelatino/repositories/check_in_publication_repository.dart';
import 'package:gelatino/repositories/check_in_repository.dart';

void main() {
  const id = 'ABCDEFGHIJKLMNOPQRST';

  test('calling marker uses exact UID key and strict minimal JSON', () async {
    final preferences = _MemoryPreferences();
    final repository = PersistentCheckInPublicationRepository(preferences);
    const marker = CheckInPublicationMarker.calling(id);

    await repository.save('alice', marker);

    expect(await repository.load('alice'), marker);
    expect(await repository.load('bob'), isNull);
    expect(
      jsonDecode(preferences.values['check_in_publication_v2_alice']!),
      <String, Object?>{'draft_id': id, 'phase': 'calling'},
    );
  });

  test('published marker round trips the exact callable result', () async {
    final preferences = _MemoryPreferences();
    final repository = PersistentCheckInPublicationRepository(preferences);
    const marker = CheckInPublicationMarker.published(
      id,
      PublishCheckInResult(id, PublishCheckInStatus.existing),
    );

    await repository.save('alice', marker);

    expect(await repository.load('alice'), marker);
    expect(
      jsonDecode(preferences.values['check_in_publication_v2_alice']!),
      <String, Object?>{
        'draft_id': id,
        'phase': 'published',
        'result': <String, Object?>{'check_in_id': id, 'status': 'existing'},
      },
    );
  });

  test('failed marker round trips the exact definitive failure', () async {
    final preferences = _MemoryPreferences();
    final repository = PersistentCheckInPublicationRepository(preferences);
    const marker = CheckInPublicationMarker.failed(
      id,
      CheckInPublicationFailureReason.mediaMissing,
    );

    await repository.save('alice', marker);

    expect(await repository.load('alice'), marker);
    expect(
      jsonDecode(preferences.values['check_in_publication_v2_alice']!),
      <String, Object?>{
        'draft_id': id,
        'phase': 'failed',
        'failure': 'media_missing',
      },
    );
  });

  test('serializes calling then published so the latest marker wins', () async {
    final preferences = _ControlledPreferences();
    final repository = PersistentCheckInPublicationRepository(preferences);
    const calling = CheckInPublicationMarker.calling(id);
    const published = CheckInPublicationMarker.published(
      id,
      PublishCheckInResult(id, PublishCheckInStatus.created),
    );

    final first = repository.save('alice', calling);
    final second = repository.save('alice', published);
    expect(preferences.pendingWrites, hasLength(1));
    preferences.completeNext();
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(preferences.pendingWrites, hasLength(1));
    preferences.completeNext();
    await second;

    expect(await repository.load('alice'), published);
  });

  test('malformed phase result and mismatched IDs fail closed', () async {
    final preferences = _MemoryPreferences();
    final repository = PersistentCheckInPublicationRepository(preferences);

    for (final json in <Map<String, Object?>>[
      <String, Object?>{'draft_id': id, 'phase': 'unknown'},
      <String, Object?>{'draft_id': id, 'phase': 'calling', 'result': null},
      <String, Object?>{'draft_id': id, 'phase': 'published'},
      <String, Object?>{'draft_id': id, 'phase': 'failed'},
      <String, Object?>{
        'draft_id': id,
        'phase': 'failed',
        'failure': 'retryable',
      },
      <String, Object?>{
        'draft_id': id,
        'phase': 'published',
        'result': <String, Object?>{
          'check_in_id': 'QRSTUVWXYZABCDEFGHIJ',
          'status': 'created',
        },
      },
    ]) {
      preferences.values['check_in_publication_v2_alice'] = jsonEncode(json);
      await expectLater(repository.load('alice'), throwsFormatException);
    }
  });

  test('save and clear failures surface without changing marker', () async {
    final preferences = _MemoryPreferences()..succeed = false;
    final repository = PersistentCheckInPublicationRepository(preferences);

    await expectLater(
      repository.save('alice', const CheckInPublicationMarker.calling(id)),
      throwsStateError,
    );
    await expectLater(repository.clear('alice'), throwsStateError);
    expect(preferences.values, isEmpty);
  });
}

class _MemoryPreferences implements DraftPreferences {
  final Map<String, String> values = <String, String>{};
  bool succeed = true;

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

final class _ControlledPreferences extends _MemoryPreferences {
  final List<({String key, String value, Completer<bool> completer})>
  pendingWrites = <({String key, String value, Completer<bool> completer})>[];

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
