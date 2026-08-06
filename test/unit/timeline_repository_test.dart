import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/repositories/timeline_repository.dart';

void main() {
  group('TimelineRepository', () {
    test(
      'queries the exact private owner feed with bounded descending pages',
      () async {
        final source = _RecordingTimelineDataSource()
          ..documents = <FeedDocument>[
            FeedDocument(
              id: _checkInId(1),
              data: _feedData(id: _checkInId(1), authorUid: 'alice'),
              cursorToken: 'raw-1',
            ),
            FeedDocument(
              id: _checkInId(2),
              data: _feedData(id: _checkInId(2), authorUid: 'bob'),
              cursorToken: 'raw-2',
            ),
          ];
        final repository = TimelineRepositoryImpl(source);

        final first = await repository.firstPage('alice', limit: 2);

        expect(source.queries, hasLength(1));
        expect(source.queries.single.collectionPath, 'feeds/alice/items');
        expect(source.queries.single.orderByField, 'created_at');
        expect(source.queries.single.descending, isTrue);
        expect(source.queries.single.limit, 2);
        expect(source.queries.single.startAfterToken, isNull);
        expect(first.items.map((item) => item.checkInId), [
          _checkInId(1),
          _checkInId(2),
        ]);
        expect(
          first.cursor,
          const FeedCursor(ownerUid: 'alice', token: 'raw-2'),
        );
        expect(first.hasMore, isTrue);

        source.documents = <FeedDocument>[
          FeedDocument(
            id: _checkInId(3),
            data: _feedData(id: _checkInId(3), authorUid: 'alice'),
            cursorToken: 'raw-3',
          ),
        ];
        await repository.nextPage('alice', first.cursor!, limit: 2);

        expect(source.queries, hasLength(2));
        expect(source.queries.last.collectionPath, 'feeds/alice/items');
        expect(source.queries.last.startAfterToken, 'raw-2');
        expect(
          source.queries.every(
            (query) => !query.collectionPath.contains('check_ins'),
          ),
          isTrue,
        );
      },
    );

    test(
      'rejects invalid owner, limit and foreign cursor before data source I/O',
      () async {
        final source = _RecordingTimelineDataSource();
        final repository = TimelineRepositoryImpl(source);

        await expectLater(
          repository.firstPage('alice/other'),
          throwsFormatException,
        );
        await expectLater(
          repository.firstPage('alice', limit: 0),
          throwsFormatException,
        );
        await expectLater(
          repository.firstPage('alice', limit: 101),
          throwsFormatException,
        );
        await expectLater(
          repository.nextPage(
            'alice',
            const FeedCursor(ownerUid: 'bob', token: 'raw-bob'),
          ),
          throwsFormatException,
        );
        expect(source.queries, isEmpty);
      },
    );

    test(
      'reports malformed siblings and advances cursor from the last raw document',
      () async {
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previous);
        final validId = _checkInId(1);
        final malformedId = _checkInId(2);
        final source = _RecordingTimelineDataSource()
          ..documents = <FeedDocument>[
            FeedDocument(
              id: validId,
              data: _feedData(id: validId, authorUid: 'alice'),
              cursorToken: 'raw-valid',
            ),
            FeedDocument(
              id: malformedId,
              data: _feedData(id: malformedId, authorUid: 'alice')
                ..remove('rating'),
              cursorToken: 'raw-malformed',
            ),
          ];

        final page = await TimelineRepositoryImpl(
          source,
        ).firstPage('alice', limit: 2);

        expect(page.items.map((item) => item.checkInId), [validId]);
        expect(
          page.cursor,
          const FeedCursor(ownerUid: 'alice', token: 'raw-malformed'),
        );
        expect(page.hasMore, isTrue);
        expect(errors, hasLength(1));
        expect(
          errors.single.context.toString(),
          contains('feeds/alice/items/$malformedId'),
        );
      },
    );

    test('maps one typed remote failure', () async {
      final source = _RecordingTimelineDataSource()
        ..error = const TimelineRemoteException('permission-denied');

      await expectLater(
        TimelineRepositoryImpl(source).firstPage('alice'),
        throwsA(
          isA<TimelineFailure>()
              .having((failure) => failure.code, 'code', 'permission-denied')
              .having((failure) => failure.retryable, 'retryable', isFalse),
        ),
      );
    });

    test(
      'authorized history constrains the private feed by author and remains bounded',
      () async {
        final source = _RecordingTimelineDataSource();
        final repository = TimelineRepositoryImpl(source);

        await repository.authorHistory(
          'alice',
          'bob',
          authorizedAuthorUids: const <String>{'alice', 'bob'},
          limit: 12,
        );

        expect(source.queries.single.collectionPath, 'feeds/alice/items');
        expect(source.queries.single.authorUid, 'bob');
        expect(source.queries.single.orderByField, 'created_at');
        expect(source.queries.single.descending, isTrue);
        expect(source.queries.single.limit, 12);
      },
    );

    test(
      'history rejects an unauthorized author before data source I/O',
      () async {
        final source = _RecordingTimelineDataSource();
        final repository = TimelineRepositoryImpl(source);

        await expectLater(
          repository.authorHistory(
            'alice',
            'mallory',
            authorizedAuthorUids: const <String>{'alice', 'bob'},
          ),
          throwsA(isA<TimelinePermissionFailure>()),
        );

        expect(source.queries, isEmpty);
      },
    );

    test(
      'history reports and skips a sibling whose author violates the query',
      () async {
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previous);
        final id = _checkInId(7);
        final source = _RecordingTimelineDataSource()
          ..documents = <FeedDocument>[
            FeedDocument(
              id: id,
              data: _feedData(id: id, authorUid: 'alice'),
              cursorToken: 'wrong-author',
            ),
          ];

        final page = await TimelineRepositoryImpl(source).authorHistory(
          'alice',
          'bob',
          authorizedAuthorUids: const <String>{'alice', 'bob'},
        );

        expect(page.items, isEmpty);
        expect(page.cursor?.token, 'wrong-author');
        expect(errors, hasLength(1));
      },
    );
  });

  group('FeedItem photo path', () {
    test(
      'rejects traversal, separators, controls, URL syntax and owner mismatches',
      () {
        final id = _checkInId(1);
        final paths = <String>[
          'check_ins/alice/$id/../photo.jpg',
          'check_ins/alice/$id/photo\\evil.jpg',
          'check_ins/alice/$id/photo\u0000.jpg',
          'check_ins/alice/$id/photo.jpg?token=public',
          'check_ins/alice/$id/photo.jpg#fragment',
          'check_ins/alice/$id/extra/photo.jpg',
          'check_ins/bob/$id/photo.jpg',
          'check_ins/alice/${_checkInId(2)}/photo.jpg',
        ];

        for (final path in paths) {
          expect(
            () => FeedItem.fromMap(
              _feedData(id: id, authorUid: 'alice')
                ..['photo_storage_path'] = path,
              id,
            ),
            throwsFormatException,
            reason: path,
          );
        }
      },
    );
  });
}

final class _RecordingTimelineDataSource implements TimelineDataSource {
  final List<TimelineQuery> queries = <TimelineQuery>[];
  List<FeedDocument> documents = const <FeedDocument>[];
  TimelineRemoteException? error;

  @override
  Future<List<FeedDocument>> read(TimelineQuery query) async {
    queries.add(query);
    final failure = error;
    if (failure != null) throw failure;
    return documents;
  }
}

String _checkInId(int suffix) =>
    'checkin_1234567890${suffix.toString().padLeft(2, '0')}';

Map<String, dynamic> _feedData({
  required String id,
  required String authorUid,
}) => <String, dynamic>{
  'author_uid': authorUid,
  'check_in_id': id,
  'user_snapshot': <String, dynamic>{
    'display_name': authorUid,
    'username': authorUid,
    'avatar_path': null,
  },
  'place_id': 'place-1',
  'place_snapshot': <String, dynamic>{'name': 'Giolitti', 'address': 'Roma'},
  'gelato_type': <String, dynamic>{'id': 'cup', 'name': 'Coppetta'},
  'flavors': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'pistachio', 'name': 'Pistacchio'},
  ],
  'rating': 5,
  'review_text': 'Ottimo',
  'tagged_user_ids': const <String>[],
  'created_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15, 12)),
  'photo_storage_path': 'check_ins/$authorUid/$id/photo.jpg',
};
