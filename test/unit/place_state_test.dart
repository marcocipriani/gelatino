import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place_state.dart';

void main() {
  test('absent state fields use non-temporal defaults', () {
    final state = PlaceState.fromMap(<String, dynamic>{}, 'place-1');

    expect(state.placeId, 'place-1');
    expect(state.saved, isFalse);
    expect(state.favorite, isFalse);
    expect(state.liked, isFalse);
    expect(state.savedAt, isNull);
    expect(state.favoriteAt, isNull);
    expect(state.likedAt, isNull);
    expect(state.updatedAt, isNull);
    expect(state.note, isNull);
  });

  test('parses timestamps only from Firestore Timestamp values', () {
    final now = DateTime(2026, 7, 14, 12);
    final state = PlaceState.fromMap(<String, dynamic>{
      'saved': true,
      'saved_at': Timestamp.fromDate(now),
      'favorite': true,
      'favorite_at': Timestamp.fromDate(now),
      'liked': true,
      'liked_at': Timestamp.fromDate(now),
      'note': 'Tavolino fuori',
      'updated_at': Timestamp.fromDate(now),
    }, 'place-1');

    expect(state.savedAt, now);
    expect(state.note, 'Tavolino fuori');

    expect(
      () => PlaceState.fromMap(<String, dynamic>{'saved_at': 0}, 'place-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed booleans and oversized notes', () {
    expect(
      () => PlaceState.fromMap(<String, dynamic>{'liked': 1}, 'place-1'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PlaceState.fromMap(<String, dynamic>{'saved': null}, 'place-1'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PlaceState.fromMap(<String, dynamic>{
        'note': List.filled(501, 'x').join(),
      }, 'place-1'),
      throwsA(isA<FormatException>()),
    );
  });
}
