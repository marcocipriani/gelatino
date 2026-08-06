import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/firestore_parsing.dart';
import '../models/friendship.dart';
import '../models/public_profile.dart';

enum FriendResponse { accepted, declined }

final class FriendshipDocument {
  const FriendshipDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

final class FriendshipQuery {
  const FriendshipQuery({required this.memberUid, required this.state});

  final String collectionPath = 'friendships';
  final String memberField = 'member_uids';
  final String stateField = 'state';
  final String orderByField = 'updated_at';
  final bool descending = true;
  final String memberUid;
  final String state;
}

final class PublicProfileBatchQuery {
  PublicProfileBatchQuery(Iterable<String> documentIds)
    : documentIds = List<String>.unmodifiable(documentIds);

  final String collectionPath = 'public_profiles';
  final List<String> documentIds;
}

typedef PublicProfileDocumentReader =
    Future<FriendshipDocument?> Function(String uid);

Future<List<FriendshipDocument>> readPublicProfileDocumentsIsolated(
  PublicProfileBatchQuery query,
  PublicProfileDocumentReader readDocument,
) async {
  final seen = <String>{};
  final documentIds = query.documentIds.where(seen.add);
  final documents = await Future.wait(
    documentIds.map((uid) async {
      try {
        final document = await readDocument(uid);
        if (document != null) return document;
        _reportPublicProfileReadFailure(
          uid,
          const FriendshipRemoteException('not-found'),
          StackTrace.current,
        );
        return null;
      } on FirebaseException catch (error, stackTrace) {
        if (error.code != 'permission-denied' && error.code != 'not-found') {
          rethrow;
        }
        _reportPublicProfileReadFailure(uid, error, stackTrace);
        return null;
      }
    }),
  );
  return List<FriendshipDocument>.unmodifiable(
    documents.whereType<FriendshipDocument>(),
  );
}

void _reportPublicProfileReadFailure(
  String uid,
  Object error,
  StackTrace stackTrace,
) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      context: ErrorDescription(
        'while reading Firestore document public_profiles/$uid',
      ),
    ),
  );
}

final class FriendshipRemoteException implements Exception {
  const FriendshipRemoteException(this.code);

  final String code;

  @override
  String toString() => code;
}

abstract interface class FriendshipDataSource {
  Stream<List<FriendshipDocument>> watchFriendships(FriendshipQuery query);

  Future<FriendshipDocument?> readFriendship(String path);

  Future<List<FriendshipDocument>> readPublicProfiles(
    PublicProfileBatchQuery query,
  );

  Future<Object?> call(String name, Map<String, Object?> payload);
}

final class FirebaseFriendshipDataSource implements FriendshipDataSource {
  FirebaseFriendshipDataSource(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<FriendshipDocument>> watchFriendships(FriendshipQuery query) {
    return _firestore
        .collection(query.collectionPath)
        .where(query.memberField, arrayContains: query.memberUid)
        .where(query.stateField, isEqualTo: query.state)
        .orderBy(query.orderByField, descending: query.descending)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    FriendshipDocument(id: document.id, data: document.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<FriendshipDocument?> readFriendship(String path) async {
    final snapshot = await _firestore.doc(path).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return FriendshipDocument(id: snapshot.id, data: data);
  }

  @override
  Future<List<FriendshipDocument>> readPublicProfiles(
    PublicProfileBatchQuery query,
  ) async {
    if (query.documentIds.isEmpty) return const <FriendshipDocument>[];
    return readPublicProfileDocumentsIsolated(query, (uid) async {
      final snapshot = await _firestore.doc('public_profiles/$uid').get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return FriendshipDocument(id: snapshot.id, data: data);
    });
  }

  @override
  Future<Object?> call(String name, Map<String, Object?> payload) async {
    try {
      return (await _functions.httpsCallable(name).call<Object?>(payload)).data;
    } on FirebaseFunctionsException catch (error) {
      throw FriendshipRemoteException(error.code);
    }
  }
}

abstract interface class FriendshipRepository {
  Stream<List<Friendship>> watchForUser(String uid);

  Future<List<PublicProfile>> readPublicProfiles(List<String> uids);

  Future<bool> isAcceptedFriend(String uid, String otherUid);

  Future<void> send(String otherUid);

  Future<void> respond(String otherUid, FriendResponse response);

  Future<void> remove(String otherUid);
}

final class FriendshipRepositoryImpl implements FriendshipRepository {
  FriendshipRepositoryImpl(this._source, [this._onSent]);

  final FriendshipDataSource _source;
  final void Function()? _onSent;

  @override
  Stream<List<Friendship>> watchForUser(String uid) {
    requirePathSegment(uid, 'uid');
    final values = <String, Map<String, Friendship>>{
      'accepted': <String, Friendship>{},
      'pending': <String, Friendship>{},
    };
    final initializedStates = <String>{};
    final subscriptions = <StreamSubscription<List<FriendshipDocument>>>[];
    var completedStreams = 0;
    late final StreamController<List<Friendship>> controller;

    void emit() {
      if (initializedStates.length != values.length) return;
      final byId = <String, Friendship>{};
      for (final friendship in values.values.expand((items) => items.values)) {
        final existing = byId[friendship.id];
        if (existing == null ||
            friendship.updatedAt.isAfter(existing.updatedAt)) {
          byId[friendship.id] = friendship;
        }
      }
      final sorted = byId.values.toList()
        ..sort((left, right) {
          final updatedAt = right.updatedAt.compareTo(left.updatedAt);
          return updatedAt != 0 ? updatedAt : left.id.compareTo(right.id);
        });
      controller.add(List<Friendship>.unmodifiable(sorted));
    }

    void listenTo(String state) {
      final query = FriendshipQuery(memberUid: uid, state: state);
      subscriptions.add(
        _source
            .watchFriendships(query)
            .listen(
              (documents) {
                final next = <String, Friendship>{};
                for (final document in documents) {
                  final friendship = parseOrReport<Friendship>(
                    path: 'friendships/${document.id}',
                    parse: () {
                      final parsed = Friendship.fromMap(
                        document.data,
                        document.id,
                        callerUid: uid,
                      );
                      if (parsed.state.name != state) {
                        throw FormatException(
                          'state: expected $state, got ${parsed.state.name}',
                        );
                      }
                      return parsed;
                    },
                  );
                  if (friendship != null) next[friendship.id] = friendship;
                }
                values[state] = next;
                initializedStates.add(state);
                emit();
              },
              onError: controller.addError,
              onDone: () {
                completedStreams++;
                if (completedStreams == 2) controller.close();
              },
            ),
      );
    }

    controller = StreamController<List<Friendship>>(
      sync: true,
      onListen: () {
        listenTo('accepted');
        listenTo('pending');
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return controller.stream;
  }

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async {
    final uniqueUids = <String>[];
    final seen = <String>{};
    for (final uid in uids) {
      requirePathSegment(uid, 'uid');
      if (seen.add(uid)) uniqueUids.add(uid);
    }
    final documents = <FriendshipDocument>[];
    for (var start = 0; start < uniqueUids.length; start += 30) {
      final end = (start + 30).clamp(0, uniqueUids.length);
      documents.addAll(
        await _source.readPublicProfiles(
          PublicProfileBatchQuery(uniqueUids.sublist(start, end)),
        ),
      );
    }
    final byUid = <String, PublicProfile>{};
    for (final document in documents) {
      final profile = parseOrReport<PublicProfile>(
        path: 'public_profiles/${document.id}',
        parse: () => PublicProfile.fromMap(document.data, document.id),
      );
      if (profile != null && seen.contains(profile.uid)) {
        byUid[profile.uid] = profile;
      }
    }
    return List<PublicProfile>.unmodifiable(
      uniqueUids.map((uid) => byUid[uid]).whereType<PublicProfile>(),
    );
  }

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async {
    requirePathSegment(uid, 'uid');
    requirePathSegment(otherUid, 'otherUid');
    if (uid == otherUid) return false;
    final id = _canonicalFriendshipId(uid, otherUid);
    final document = await _source.readFriendship('friendships/$id');
    if (document == null) return false;
    final friendship = parseOrReport<Friendship>(
      path: 'friendships/$id',
      parse: () =>
          Friendship.fromMap(document.data, document.id, callerUid: uid),
    );
    return friendship?.state == FriendshipState.accepted;
  }

  @override
  Future<void> send(String otherUid) async {
    await _call(
      'sendFriendRequest',
      <String, Object?>{'otherUid': _validOtherUid(otherUid)},
    );
    // The request is already sent; a broken hook must never fail send() itself.
    try {
      _onSent?.call();
    } catch (_) {
      // ponytail: backstop only — enablePushAfterSocialAction already
      // swallows its own errors, this just protects against any future
      // misbehaving hook.
    }
  }

  @override
  Future<void> respond(String otherUid, FriendResponse response) =>
      _call('respondToFriendRequest', <String, Object?>{
        'otherUid': _validOtherUid(otherUid),
        'response': response.name,
      });

  @override
  Future<void> remove(String otherUid) => _call(
    'removeFriendship',
    <String, Object?>{'otherUid': _validOtherUid(otherUid)},
  );

  String _validOtherUid(String otherUid) {
    requirePathSegment(otherUid, 'otherUid');
    return otherUid;
  }

  Future<void> _call(String name, Map<String, Object?> payload) async {
    try {
      await _source.call(name, payload);
    } on FriendshipRemoteException catch (error) {
      throw FriendshipFailure.fromCode(error.code);
    }
  }
}

sealed class FriendshipFailure implements Exception {
  const FriendshipFailure(this.code, this.message);

  factory FriendshipFailure.fromCode(String code) => switch (code) {
    'invalid-argument' => const InvalidFriendshipFailure(),
    'not-found' => const FriendshipNotFoundFailure(),
    'permission-denied' => const FriendshipPermissionFailure(),
    'failed-precondition' => const FriendshipStateFailure(),
    'unauthenticated' => const FriendshipAuthenticationFailure(),
    'unavailable' => const FriendshipUnavailableFailure(),
    _ => FriendshipUnknownFailure(code),
  };

  final String code;
  final String message;

  @override
  String toString() => message;
}

final class InvalidFriendshipFailure extends FriendshipFailure {
  const InvalidFriendshipFailure()
    : super('invalid-argument', 'Richiesta di amicizia non valida.');
}

final class FriendshipNotFoundFailure extends FriendshipFailure {
  const FriendshipNotFoundFailure()
    : super('not-found', 'Profilo o amicizia non trovato.');
}

final class FriendshipPermissionFailure extends FriendshipFailure {
  const FriendshipPermissionFailure()
    : super('permission-denied', 'Non puoi modificare questa amicizia.');
}

final class FriendshipStateFailure extends FriendshipFailure {
  const FriendshipStateFailure()
    : super('failed-precondition', 'Questa amicizia non è più modificabile.');
}

final class FriendshipAuthenticationFailure extends FriendshipFailure {
  const FriendshipAuthenticationFailure()
    : super('unauthenticated', 'Accedi per gestire le amicizie.');
}

final class FriendshipUnavailableFailure extends FriendshipFailure {
  const FriendshipUnavailableFailure()
    : super('unavailable', 'Servizio amicizie non disponibile. Riprova.');
}

final class FriendshipUnknownFailure extends FriendshipFailure {
  const FriendshipUnknownFailure(String code)
    : super(code, 'Impossibile aggiornare l’amicizia.');
}

String _canonicalFriendshipId(String firstUid, String secondUid) {
  final members = <String>[firstUid, secondUid]..sort();
  return members.map(_encodeUid).join('.');
}

String _encodeUid(String uid) =>
    base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
