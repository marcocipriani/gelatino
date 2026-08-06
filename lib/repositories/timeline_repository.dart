import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feed_item.dart';
import '../models/firestore_parsing.dart';

final class FeedDocument {
  const FeedDocument({
    required this.id,
    required this.data,
    required this.cursorToken,
  });

  final String id;
  final Map<String, dynamic> data;
  final Object cursorToken;
}

final class TimelineQuery {
  const TimelineQuery({
    required this.ownerUid,
    required this.limit,
    this.startAfterToken,
    this.authorUid,
  });

  final String ownerUid;
  final int limit;
  final Object? startAfterToken;
  final String? authorUid;

  String get collectionPath => 'feeds/$ownerUid/items';
  String get orderByField => 'created_at';
  bool get descending => true;
}

final class FeedCursor {
  const FeedCursor({required this.ownerUid, required this.token});

  final String ownerUid;
  final Object token;

  @override
  bool operator ==(Object other) =>
      other is FeedCursor && other.ownerUid == ownerUid && other.token == token;

  @override
  int get hashCode => Object.hash(ownerUid, token);
}

final class FeedPage {
  FeedPage({
    required List<FeedItem> items,
    required this.cursor,
    required this.hasMore,
  }) : items = List<FeedItem>.unmodifiable(items);

  final List<FeedItem> items;
  final FeedCursor? cursor;
  final bool hasMore;
}

final class TimelineRemoteException implements Exception {
  const TimelineRemoteException(this.code);

  final String code;

  @override
  String toString() => code;
}

abstract interface class TimelineDataSource {
  Future<List<FeedDocument>> read(TimelineQuery query);
}

final class FirestoreTimelineDataSource implements TimelineDataSource {
  FirestoreTimelineDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<FeedDocument>> read(TimelineQuery query) async {
    Query<Map<String, dynamic>> request = _firestore.collection(
      query.collectionPath,
    );
    if (query.authorUid != null) {
      request = request.where('author_uid', isEqualTo: query.authorUid);
    }
    request = request
        .orderBy(query.orderByField, descending: query.descending)
        .limit(query.limit);
    final token = query.startAfterToken;
    if (token != null) {
      if (token is! DocumentSnapshot<Map<String, dynamic>>) {
        throw const TimelineRemoteException('invalid-cursor');
      }
      request = request.startAfterDocument(token);
    }
    try {
      final snapshot = await request.get();
      return List<FeedDocument>.unmodifiable(
        snapshot.docs.map(
          (document) => FeedDocument(
            id: document.id,
            data: document.data(),
            cursorToken: document,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      throw TimelineRemoteException(error.code);
    }
  }
}

abstract interface class TimelineRepository {
  Future<FeedPage> firstPage(String uid, {int limit = 20});

  Future<FeedPage> nextPage(String uid, FeedCursor cursor, {int limit = 20});

  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  });
}

final class TimelineRepositoryImpl implements TimelineRepository {
  TimelineRepositoryImpl(this._source);

  final TimelineDataSource _source;

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) async {
    _validateRequest(uid, limit);
    return await _read(
      TimelineQuery(ownerUid: uid, limit: limit),
      previousCursor: null,
    );
  }

  @override
  Future<FeedPage> nextPage(
    String uid,
    FeedCursor cursor, {
    int limit = 20,
  }) async {
    _validateRequest(uid, limit);
    requirePathSegment(cursor.ownerUid, 'cursor.ownerUid');
    if (cursor.ownerUid != uid) {
      throw const FormatException('cursor: belongs to another feed owner');
    }
    return await _read(
      TimelineQuery(ownerUid: uid, limit: limit, startAfterToken: cursor.token),
      previousCursor: cursor,
    );
  }

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) async {
    _validateRequest(ownerUid, limit);
    requirePathSegment(authorUid, 'authorUid');
    for (final authorizedUid in authorizedAuthorUids) {
      requirePathSegment(authorizedUid, 'authorizedAuthorUids');
    }
    if (!authorizedAuthorUids.contains(ownerUid) ||
        !authorizedAuthorUids.contains(authorUid)) {
      throw const TimelinePermissionFailure();
    }
    return await _read(
      TimelineQuery(ownerUid: ownerUid, authorUid: authorUid, limit: limit),
      previousCursor: null,
    );
  }

  Future<FeedPage> _read(
    TimelineQuery query, {
    required FeedCursor? previousCursor,
  }) async {
    try {
      final documents = await _source.read(query);
      final items = <FeedItem>[];
      for (final document in documents) {
        final item = parseOrReport<FeedItem>(
          path: '${query.collectionPath}/${document.id}',
          parse: () {
            final item = FeedItem.fromMap(document.data, document.id);
            if (query.authorUid != null && item.authorUid != query.authorUid) {
              throw FormatException(
                'author_uid: expected ${query.authorUid}, got ${item.authorUid}',
              );
            }
            return item;
          },
        );
        if (item != null) items.add(item);
      }
      final cursor = documents.isEmpty
          ? previousCursor
          : FeedCursor(
              ownerUid: query.ownerUid,
              token: documents.last.cursorToken,
            );
      return FeedPage(
        items: items,
        cursor: cursor,
        hasMore: documents.length == query.limit,
      );
    } on TimelineRemoteException catch (error) {
      throw TimelineFailure.fromCode(error.code);
    }
  }
}

void _validateRequest(String uid, int limit) {
  requirePathSegment(uid, 'uid');
  if (limit < 1 || limit > 100) {
    throw const FormatException('limit: expected 1 through 100');
  }
}

sealed class TimelineFailure implements Exception {
  const TimelineFailure(this.code, this.message, {required this.retryable});

  factory TimelineFailure.fromCode(String code) => switch (code) {
    'permission-denied' => const TimelinePermissionFailure(),
    'unauthenticated' => const TimelineAuthenticationFailure(),
    'unavailable' || 'deadline-exceeded' => TimelineUnavailableFailure(code),
    'invalid-cursor' || 'invalid-argument' => const TimelineProtocolFailure(),
    _ => TimelineUnknownFailure(code),
  };

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

final class TimelinePermissionFailure extends TimelineFailure {
  const TimelinePermissionFailure()
    : super(
        'permission-denied',
        'Non hai accesso a questa Timeline.',
        retryable: false,
      );
}

final class TimelineAuthenticationFailure extends TimelineFailure {
  const TimelineAuthenticationFailure()
    : super(
        'unauthenticated',
        'Accedi per vedere la Timeline.',
        retryable: false,
      );
}

final class TimelineUnavailableFailure extends TimelineFailure {
  const TimelineUnavailableFailure([String code = 'unavailable'])
    : super(
        code,
        'Timeline temporaneamente non disponibile. Riprova.',
        retryable: true,
      );
}

final class TimelineProtocolFailure extends TimelineFailure {
  const TimelineProtocolFailure()
    : super(
        'invalid-argument',
        'La pagina della Timeline non è valida.',
        retryable: false,
      );
}

final class TimelineUnknownFailure extends TimelineFailure {
  const TimelineUnknownFailure(String code)
    : super(code, 'Impossibile caricare la Timeline.', retryable: true);
}
