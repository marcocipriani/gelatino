import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/repositories/check_in_draft_repository.dart';
import 'package:gelatino/repositories/check_in_label_repository.dart';

void main() {
  test('round-trips every display label map', () async {
    final preferences = _MemoryPreferences();
    final repository = PersistentCheckInLabelRepository(preferences);
    const labels = CheckInDisplayLabels(
      placeNames: <String, String>{'place-1': 'Gelateria Aurora'},
      typeNames: <String, String>{'cono': 'Cono'},
      flavorNames: <String, String>{'pistacchio': 'Pistacchio'},
      friendNames: <String, String>{'friend-1': 'Alice'},
    );

    await repository.save('alice', 'draft-1', labels);

    final restored = await repository.load('alice', 'draft-1');
    expect(restored.placeNames, labels.placeNames);
    expect(restored.typeNames, labels.typeNames);
    expect(restored.flavorNames, labels.flavorNames);
    expect(restored.friendNames, labels.friendNames);
  });

  test('serializes concurrent writes and keeps the latest value', () async {
    final preferences = _ControlledPreferences();
    final repository = PersistentCheckInLabelRepository(preferences);
    final first = repository.save(
      'alice',
      'draft-1',
      const CheckInDisplayLabels(placeNames: <String, String>{'p': 'Prima'}),
    );
    final second = repository.save(
      'alice',
      'draft-1',
      const CheckInDisplayLabels(placeNames: <String, String>{'p': 'Seconda'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(preferences.setCalls, 1);

    preferences.firstWrite.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(preferences.setCalls, 2);
    expect(
      (await repository.load('alice', 'draft-1')).placeNames['p'],
      'Seconda',
    );
  });

  test('rejects corrupted persisted JSON', () async {
    final preferences = _MemoryPreferences();
    final repository = PersistentCheckInLabelRepository(preferences);
    await repository.save(
      'alice',
      'draft-1',
      const CheckInDisplayLabels(placeNames: <String, String>{'p': 'Prima'}),
    );
    preferences.values[preferences.values.keys.single] = '{broken';

    await expectLater(
      repository.load('alice', 'draft-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('keeps uid and draft id components collision-free', () async {
    final repository = PersistentCheckInLabelRepository(_MemoryPreferences());
    await repository.save(
      'a_b',
      'c',
      const CheckInDisplayLabels(placeNames: <String, String>{'p': 'Prima'}),
    );
    await repository.save(
      'a',
      'b_c',
      const CheckInDisplayLabels(placeNames: <String, String>{'p': 'Seconda'}),
    );

    expect((await repository.load('a_b', 'c')).placeNames['p'], 'Prima');
    expect((await repository.load('a', 'b_c')).placeNames['p'], 'Seconda');
  });
}

class _MemoryPreferences implements DraftPreferences {
  final Map<String, String> values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

final class _ControlledPreferences extends _MemoryPreferences {
  final firstWrite = Completer<void>();
  int setCalls = 0;

  @override
  Future<bool> setString(String key, String value) async {
    setCalls++;
    if (setCalls == 1) await firstWrite.future;
    return super.setString(key, value);
  }
}
