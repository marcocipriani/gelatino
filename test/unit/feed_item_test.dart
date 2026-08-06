import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';

void main() {
  const checkInId = 'checkin_123456789012';
  final createdAt = DateTime(2026, 7, 14, 12);

  Map<String, dynamic> feedItem() => <String, dynamic>{
    'author_uid': 'alice',
    'check_in_id': checkInId,
    'user_snapshot': <String, dynamic>{
      'display_name': 'Alice',
      'username': 'alice-gelato',
      'avatar_path': null,
    },
    'place_id': 'place-1',
    'place_snapshot': <String, dynamic>{
      'name': 'Giolitti',
      'address': 'Via Uffici del Vicario 40',
    },
    'gelato_type': <String, dynamic>{'id': 'cup', 'name': 'Coppetta'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
    ],
    'rating': 5,
    'review_text': 'Ottimo',
    'tagged_user_ids': <String>['bob'],
    'created_at': Timestamp.fromDate(createdAt),
    'photo_storage_path': 'check_ins/alice/$checkInId/1.jpg',
  };

  test('requires complete immutable display projection', () {
    final item = FeedItem.fromMap(feedItem(), checkInId);

    expect(item.authorUid, 'alice');
    expect(item.checkInId, checkInId);
    expect(item.placeSnapshot['name'], 'Giolitti');
    expect(item.rating, 5);
    expect(item.createdAt, createdAt);

    for (final requiredKey in <String>[
      'author_uid',
      'check_in_id',
      'place_id',
      'photo_storage_path',
      'rating',
      'created_at',
    ]) {
      final missing = feedItem()..remove(requiredKey);
      expect(
        () => FeedItem.fromMap(missing, checkInId),
        throwsA(isA<FormatException>()),
        reason: requiredKey,
      );
    }
  });

  test('rejects fields outside the server projection allowlist', () {
    final privateData = feedItem()..['email'] = 'private@example.test';
    expect(
      () => FeedItem.fromMap(privateData, checkInId),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects mismatched IDs and malformed nested entries', () {
    expect(
      () => FeedItem.fromMap(feedItem(), 'other_checkin_12345678'),
      throwsA(isA<FormatException>()),
    );

    final badTagged = feedItem()..['tagged_user_ids'] = <Object>['bob', 3];
    expect(
      () => FeedItem.fromMap(badTagged, checkInId),
      throwsA(isA<FormatException>()),
    );

    final badPlace = feedItem()
      ..['place_snapshot'] = <String, dynamic>{'name': 'Giolitti'};
    expect(
      () => FeedItem.fromMap(badPlace, checkInId),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => FeedItem.fromMap(feedItem(), 'short'),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses flavor color_hex: absent, null, valid, and malformed', () {
    final legacy = FeedItem.fromMap(feedItem(), checkInId);
    expect(legacy.flavors.single.containsKey('color_hex'), isFalse);

    final withNullColor = feedItem()
      ..['flavors'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pistacchio',
          'name': 'Pistacchio',
          'color_hex': null,
        },
      ];
    final nullColorItem = FeedItem.fromMap(withNullColor, checkInId);
    expect(nullColorItem.flavors.single['color_hex'], isNull);

    final withColor = feedItem()
      ..['flavors'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pistacchio',
          'name': 'Pistacchio',
          'color_hex': '#93C572',
        },
      ];
    final coloredItem = FeedItem.fromMap(withColor, checkInId);
    expect(coloredItem.flavors.single['color_hex'], '#93C572');

    final withMalformedColor = feedItem()
      ..['flavors'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pistacchio',
          'name': 'Pistacchio',
          'color_hex': 'green',
        },
      ];
    expect(
      () => FeedItem.fromMap(withMalformedColor, checkInId),
      throwsA(isA<FormatException>()),
    );
  });

  test('consumed_at is optional and falls back to created_at', () {
    // Feed items projected before backdating shipped carry no consumed_at and
    // must keep parsing: this is the regression that would blank the timeline.
    final historical = FeedItem.fromMap(feedItem(), checkInId);
    expect(historical.consumedAt, createdAt);
    expect(historical.isBackdated, isFalse);

    final consumedAt = DateTime(2025, 8, 3, 16, 30);
    final backdated = FeedItem.fromMap(
      feedItem()..['consumed_at'] = Timestamp.fromDate(consumedAt),
      checkInId,
    );
    expect(backdated.consumedAt, consumedAt);
    expect(backdated.createdAt, createdAt);
    expect(backdated.isBackdated, isTrue);

    // Same day as the write: shown as an ordinary post, not flagged.
    final sameDay = FeedItem.fromMap(
      feedItem()
        ..['consumed_at'] = Timestamp.fromDate(
          createdAt.subtract(const Duration(hours: 3)),
        ),
      checkInId,
    );
    expect(sameDay.isBackdated, isFalse);

    expect(
      () => FeedItem.fromMap(feedItem()..['consumed_at'] = 'ieri', checkInId),
      throwsA(isA<FormatException>()),
    );
  });
}
