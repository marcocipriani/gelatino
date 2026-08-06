import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/providers/flavor_search_provider.dart';

void main() {
  test('normalize lowers case and strips italian accents', () {
    expect(normalizeFlavorQuery('  Pistàcchio '), 'pistacchio');
    expect(normalizeFlavorQuery('CAFFÈ'), 'caffe');
  });

  test('index keeps best rating and counts tastings per place', () {
    final index = buildFlavorIndex([
      fakeFeedItem(place: 'p1', rating: 4, flavors: ['Pistacchio']),
      fakeFeedItem(place: 'p1', rating: 5, flavors: ['Pistacchio', 'Limone']),
      fakeFeedItem(place: 'p2', rating: 3, flavors: ['pistacchio']),
    ]);
    final matches = lookupFlavor(index, 'pista')!;
    expect(matches.keys.toSet(), {'p1', 'p2'});
    expect(matches['p1']!.bestRating, 5);
    expect(matches['p1']!.tastings, 2);
  });

  test('lookup requires a 3-char prefix and returns null otherwise', () {
    final index = buildFlavorIndex([
      fakeFeedItem(place: 'p1', rating: 4, flavors: ['Nocciola']),
    ]);
    expect(lookupFlavor(index, 'no'), isNull);
    expect(lookupFlavor(index, 'noc'), isNotNull);
    expect(lookupFlavor(index, 'cioccolato'), isNull);
  });

  test('lookup merges distinct flavor keys sharing a prefix, keeping best rating', () {
    final index = buildFlavorIndex([
      fakeFeedItem(place: 'p1', rating: 3, flavors: ['Pistacchio']),
      fakeFeedItem(place: 'p1', rating: 5, flavors: ['Pistacchio Bronte']),
    ]);
    // 'pista' prefixes both 'pistacchio' and 'pistacchio bronte'; for the
    // shared place the merge must surface the higher-rated match, not clobber.
    final matches = lookupFlavor(index, 'pista')!;
    expect(matches.keys.toSet(), {'p1'});
    expect(matches['p1']!.bestRating, 5);
  });

  test('index skips flavors with an empty name instead of indexing a blank key', () {
    final index = buildFlavorIndex([
      fakeFeedItem(
        place: 'p1',
        rating: 4,
        flavorMaps: [
          <String, dynamic>{'id': 'blank', 'name': ''},
          <String, dynamic>{'id': 'limone', 'name': 'Limone'},
        ],
      ),
    ]);
    expect(index.containsKey(''), isFalse);
    expect(lookupFlavor(index, 'lim')!.keys.toSet(), {'p1'});
  });
}

FeedItem fakeFeedItem({
  required String place,
  required int rating,
  List<String>? flavors,
  List<Map<String, dynamic>>? flavorMaps,
}) {
  assert(
    (flavors == null) != (flavorMaps == null),
    'provide exactly one of flavors or flavorMaps',
  );
  final checkInId = 'checkin_test_${place}_${DateTime.now().millisecondsSinceEpoch}';
  return FeedItem.fromMap(
    <String, dynamic>{
      'author_uid': 'test_author',
      'check_in_id': checkInId,
      'user_snapshot': <String, dynamic>{
        'display_name': 'Test User',
        'username': 'testuser',
        'avatar_path': null,
      },
      'place_id': place,
      'place_snapshot': <String, dynamic>{
        'name': 'Test Place',
        'address': 'Test Address',
      },
      'gelato_type': <String, dynamic>{
        'id': 'cup',
        'name': 'Coppetta',
      },
      'flavors': flavorMaps ??
          flavors!
              .map((name) => <String, dynamic>{
                    'id': name.toLowerCase().replaceAll(' ', '_'),
                    'name': name,
                  })
              .toList(),
      'rating': rating,
      'review_text': 'Test review',
      'tagged_user_ids': const <String>[],
      'created_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
      'photo_storage_path': 'check_ins/test_author/$checkInId/photo.jpg',
    },
    checkInId,
  );
}
