import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/repositories/friendship_repository.dart';

void main() {
  group('FriendshipRepository', () {
    late FakeFriendshipDataSource source;
    late FriendshipRepository repository;

    setUp(() {
      source = FakeFriendshipDataSource();
      repository = FriendshipRepositoryImpl(source);
    });

    test('uses the two exact index-aligned relationship queries', () async {
      final subscription = repository.watchForUser('alice').listen((_) {});
      addTearDown(subscription.cancel);

      expect(source.queries, hasLength(2));
      expect(source.queries.map((query) => query.state).toSet(), {
        'accepted',
        'pending',
      });
      for (final query in source.queries) {
        expect(query.collectionPath, 'friendships');
        expect(query.memberUid, 'alice');
        expect(query.memberField, 'member_uids');
        expect(query.stateField, 'state');
        expect(query.orderByField, 'updated_at');
        expect(query.descending, isTrue);
      }
    });

    test(
      'waits for both queries then merges, deduplicates and stays live',
      () async {
        final errors = _captureFlutterErrors();
        final emissions = <List<String>>[];
        final done = Completer<void>();
        final subscription = repository.watchForUser('alice').listen((items) {
          emissions.add(items.map((item) => item.id).toList());
          if (emissions.length == 2) done.complete();
        });
        addTearDown(subscription.cancel);

        source.emit('pending', <FriendshipDocument>[
          _friendship('alice', 'carol', minute: 12),
          const FriendshipDocument(id: 'bad', data: <String, dynamic>{}),
        ]);
        expect(emissions, isEmpty);

        source.emit('accepted', <FriendshipDocument>[
          _friendship('alice', 'bob', state: 'accepted', minute: 10),
          _friendship('alice', 'bob', state: 'accepted', minute: 10),
        ]);
        source.emit('pending', const <FriendshipDocument>[]);
        await done.future;

        expect(emissions, <List<String>>[
          <String>['YWxpY2U.Y2Fyb2w', 'YWxpY2U.Ym9i'],
          <String>['YWxpY2U.Ym9i'],
        ]);
        expect(errors, hasLength(1));
      },
    );

    test('cancelling merged stream cancels both source listeners', () async {
      final subscription = repository.watchForUser('alice').listen((_) {});
      expect(source.activeStates, <String>{'accepted', 'pending'});

      await subscription.cancel();

      expect(source.activeStates, isEmpty);
      expect(source.cancelledStates, <String>{'accepted', 'pending'});
    });

    test('hydrates only public profiles in batches of at most 30', () async {
      final ids = <String>[
        for (var index = 0; index < 65; index++) 'user-$index',
        'user-1',
      ];
      source.profileDocuments.addAll(<String, FriendshipDocument>{
        for (final uid in ids.toSet())
          uid: FriendshipDocument(id: uid, data: _publicData(uid)),
      });

      final profiles = await repository.readPublicProfiles(ids);

      expect(source.profileQueries.map((query) => query.documentIds.length), [
        30,
        30,
        5,
      ]);
      expect(
        source.profileQueries.every(
          (query) => query.collectionPath == 'public_profiles',
        ),
        isTrue,
      );
      expect(profiles.map((profile) => profile.uid), ids.toSet().toList());
    });

    test(
      'isolates denied and missing public profiles without losing valid order',
      () async {
        final errors = _captureFlutterErrors();
        final documents = await readPublicProfileDocumentsIsolated(
          PublicProfileBatchQuery(<String>[
            'bob',
            'private',
            'missing',
            'carol',
            'bob',
          ]),
          (uid) async {
            if (uid == 'private') {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              );
            }
            if (uid == 'missing') return null;
            return FriendshipDocument(id: uid, data: _publicData(uid));
          },
        );

        expect(documents.map((document) => document.id), ['bob', 'carol']);
        expect(errors, hasLength(2));
        final reported = errors
            .map((details) => details.exception.toString())
            .join(' ');
        expect(reported, contains('permission-denied'));
        expect(reported, contains('not-found'));
      },
    );

    test(
      'does not downgrade unavailable profile reads to partial success',
      () async {
        final errors = _captureFlutterErrors();

        await expectLater(
          readPublicProfileDocumentsIsolated(
            PublicProfileBatchQuery(<String>['bob', 'offline']),
            (uid) async {
              if (uid == 'offline') {
                throw FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'unavailable',
                );
              }
              return FriendshipDocument(id: uid, data: _publicData(uid));
            },
          ),
          throwsA(
            isA<FirebaseException>().having(
              (error) => error.code,
              'code',
              'unavailable',
            ),
          ),
        );
        expect(errors, isEmpty);
      },
    );

    test('callables use exact names and payloads', () async {
      await repository.send('bob');
      await repository.respond('carol', FriendResponse.accepted);
      await repository.remove('dave');

      expect(source.calls.map((call) => call.$1), <String>[
        'sendFriendRequest',
        'respondToFriendRequest',
        'removeFriendship',
      ]);
      expect(source.calls[0].$2, <String, Object?>{'otherUid': 'bob'});
      expect(source.calls[1].$2, <String, Object?>{
        'otherUid': 'carol',
        'response': 'accepted',
      });
      expect(source.calls[2].$2, <String, Object?>{'otherUid': 'dave'});
    });

    test('a throwing onSent hook does not fail send()', () async {
      final guarded = FriendshipRepositoryImpl(
        source,
        () => throw StateError('push hook exploded'),
      );

      await expectLater(guarded.send('bob'), completes);
      expect(source.calls.map((call) => call.$1), <String>[
        'sendFriendRequest',
      ]);
    });

    for (final expected in <String, Matcher>{
      'invalid-argument': isA<InvalidFriendshipFailure>(),
      'not-found': isA<FriendshipNotFoundFailure>(),
      'permission-denied': isA<FriendshipPermissionFailure>(),
      'failed-precondition': isA<FriendshipStateFailure>(),
      'unauthenticated': isA<FriendshipAuthenticationFailure>(),
      'unavailable': isA<FriendshipUnavailableFailure>(),
    }.entries) {
      test('maps callable ${expected.key} without claiming success', () async {
        source.callError = FriendshipRemoteException(expected.key);

        await expectLater(
          repository.send('bob'),
          throwsA(
            allOf(
              expected.value,
              isA<FriendshipFailure>()
                  .having((error) => error.code, 'code', expected.key)
                  .having((error) => error.message, 'message', isNotEmpty),
            ),
          ),
        );
      });
    }

    test('source boundary has injected Firebase and no private user reads', () {
      final source = File(
        'lib/repositories/friendship_repository.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('FirebaseFirestore.instance')));
      expect(source, isNot(contains('FirebaseFunctions.instance')));
      expect(source, isNot(contains("collection('users')")));
      expect(source, isNot(contains('whereIn:')));
      expect(source, contains("doc('public_profiles/\$uid')"));
      expect(source, isNot(contains('friend_uids')));
      expect(source, isNot(contains("'affinity'")));
      expect(source, isNot(contains('.set(')));
      expect(source, isNot(contains('.update(')));

      final providers = File(
        'lib/firebase/firebase_providers.dart',
      ).readAsStringSync();
      expect(providers, contains("instanceFor(region: 'europe-west1')"));
      expect(File('lib/providers/pings_provider.dart').existsSync(), isFalse);
      for (final path in <String>[
        'lib/screens/friends_screen.dart',
        'lib/screens/main_screen.dart',
        'lib/screens/check_in_screen.dart',
        'lib/screens/timeline_screen.dart',
        'lib/providers/user_provider.dart',
      ]) {
        final runtime = File(path).readAsStringSync();
        expect(runtime, isNot(contains('pings_provider.dart')), reason: path);
        expect(runtime, isNot(contains('models/ping.dart')), reason: path);
        expect(runtime, isNot(contains('friendUids')), reason: path);
        expect(runtime, isNot(contains('.affinity[')), reason: path);
        expect(
          runtime,
          isNot(contains('FirebaseFirestore.instance')),
          reason: path,
        );
        expect(
          runtime,
          isNot(contains('FirebaseFunctions.instance')),
          reason: path,
        );
      }
    });
  });
}

final class FakeFriendshipDataSource implements FriendshipDataSource {
  final List<FriendshipQuery> queries = [];
  final List<PublicProfileBatchQuery> profileQueries = [];
  final List<(String, Map<String, Object?>)> calls = [];
  final Map<String, FriendshipDocument> profileDocuments = {};
  final Map<String, StreamController<List<FriendshipDocument>>> _streams = {};
  final Set<String> activeStates = {};
  final Set<String> cancelledStates = {};
  FriendshipRemoteException? callError;

  @override
  Stream<List<FriendshipDocument>> watchFriendships(FriendshipQuery query) {
    queries.add(query);
    return (_streams[query.state] ??=
            StreamController<List<FriendshipDocument>>.broadcast(
              sync: true,
              onListen: () => activeStates.add(query.state),
              onCancel: () {
                activeStates.remove(query.state);
                cancelledStates.add(query.state);
              },
            ))
        .stream;
  }

  void emit(String state, List<FriendshipDocument> documents) {
    _streams[state]!.add(documents);
  }

  @override
  Future<List<FriendshipDocument>> readPublicProfiles(
    PublicProfileBatchQuery query,
  ) async {
    profileQueries.add(query);
    return <FriendshipDocument>[
      for (final uid in query.documentIds) ?profileDocuments[uid],
    ].reversed.toList();
  }

  @override
  Future<FriendshipDocument?> readFriendship(String path) async => null;

  @override
  Future<Object?> call(String name, Map<String, Object?> payload) async {
    calls.add((name, Map<String, Object?>.from(payload)));
    if (callError case final error?) throw error;
    return const <String, Object?>{};
  }
}

FriendshipDocument _friendship(
  String first,
  String second, {
  String state = 'pending',
  int minute = 0,
}) {
  final ids = <String>[first, second]..sort();
  final id = <String, String>{
    'alice|bob': 'YWxpY2U.Ym9i',
    'alice|carol': 'YWxpY2U.Y2Fyb2w',
    'alice|dave': 'YWxpY2U.ZGF2ZQ',
  }[ids.join('|')]!;
  final timestamp = Timestamp.fromDate(DateTime(2026, 7, 14, 12, minute));
  return FriendshipDocument(
    id: id,
    data: <String, dynamic>{
      'member_uids': ids,
      'requester_uid': first,
      'recipient_uid': second,
      'state': state,
      'requested_at': timestamp,
      'responded_at': state == 'pending' ? null : timestamp,
      'accepted_at': state == 'accepted' ? timestamp : null,
      'removed_at': null,
      'affinity_score': state == 'accepted' ? minute : 0,
      'updated_at': timestamp,
    },
  );
}

Map<String, dynamic> _publicData(String uid) => <String, dynamic>{
  'uid': uid,
  'display_name': uid,
  'display_name_lower': uid,
  'username': uid,
  'username_lower': uid,
  'avatar_path': null,
  'bio': '',
  'city': 'Roma',
  'favorite_place_id': null,
  'favorite_flavor_id': null,
  'favorite_flavor_ids': <String>[],
  'profile_visibility': 'public',
  'searchable': true,
  'points': 0,
  'updated_at': Timestamp.fromDate(DateTime(2026, 7, 14)),
};

List<FlutterErrorDetails> _captureFlutterErrors() {
  final previous = FlutterError.onError;
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
