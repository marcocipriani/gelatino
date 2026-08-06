import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/repositories/friendship_repository.dart';
import 'package:gelatino/screens/invite_screen.dart';

void main() {
  testWidgets('invalid and self invite never invoke a friendship callable', (
    tester,
  ) async {
    final repository = _Friendships();
    await _pumpInvite(
      tester,
      targetUid: 'alice',
      repository: repository,
      profile: _profile('alice'),
    );

    expect(find.text('Non puoi invitare te stesso.'), findsOneWidget);
    expect(repository.actions, isEmpty);

    await _pumpInvite(
      tester,
      targetUid: 'bad/uid',
      repository: repository,
      profile: null,
    );
    expect(find.text('Link di invito non valido.'), findsOneWidget);
    expect(repository.actions, isEmpty);
  });

  testWidgets('missing invite target never invokes a friendship callable', (
    tester,
  ) async {
    final repository = _Friendships();
    await _pumpInvite(
      tester,
      targetUid: null,
      repository: repository,
      profile: null,
    );

    expect(find.text('Link di invito non valido.'), findsOneWidget);
    expect(repository.actions, isEmpty);
  });

  testWidgets('profile loading, missing and forbidden states fail closed', (
    tester,
  ) async {
    final repository = _Friendships();
    await _pumpInvite(
      tester,
      repository: repository,
      profileValue: const AsyncLoading<PublicProfile?>(),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _pumpInvite(tester, repository: repository, profile: null);
    expect(find.text('Profilo non trovato.'), findsOneWidget);

    await _pumpInvite(
      tester,
      repository: repository,
      profileValue: AsyncError<PublicProfile?>(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        StackTrace.empty,
      ),
    );
    expect(find.text('Profilo non accessibile.'), findsOneWidget);
    expect(repository.actions, isEmpty);
  });

  testWidgets('double tap sends one request while the callable is pending', (
    tester,
  ) async {
    final repository = _Friendships()..gate = Completer<void>();
    await _pumpInvite(tester, repository: repository, profile: _profile('bob'));

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('invite-send')),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();

    expect(repository.actions, <String>['send:bob']);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Richiesta inviata.'), findsOneWidget);
  });

  testWidgets('friendship loading and error stay fail-closed', (tester) async {
    final repository = _Friendships();
    await _pumpInvite(
      tester,
      repository: repository,
      profile: _profile('bob'),
      relationshipsValue: const AsyncLoading<List<Friendship>>(),
    );
    expect(find.text('Verifica amicizia in corso…'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('invite-send')), findsNothing);
    expect(repository.actions, isEmpty);

    await _pumpInvite(
      tester,
      repository: repository,
      profile: _profile('bob'),
      relationshipsValue: AsyncError<List<Friendship>>(
        StateError('relationship stream failed'),
        StackTrace.empty,
      ),
    );
    expect(
      find.text('Impossibile verificare l’amicizia. Riprova più tardi.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('invite-send')), findsNothing);
    expect(repository.actions, isEmpty);
  });

  testWidgets('reverse pending request is accepted instead of duplicated', (
    tester,
  ) async {
    final repository = _Friendships();
    await _pumpInvite(
      tester,
      repository: repository,
      profile: _profile('bob'),
      relationships: <Friendship>[
        _friendship(requester: 'bob', recipient: 'alice'),
      ],
    );

    await tester.tap(find.byKey(const ValueKey<String>('invite-accept')));
    await tester.pumpAndSettle();

    expect(repository.actions, <String>['respond:bob:accepted']);
    expect(find.text('Ora siete amici.'), findsOneWidget);
  });

  testWidgets('outgoing and accepted relationships expose safe final states', (
    tester,
  ) async {
    final repository = _Friendships();
    await _pumpInvite(
      tester,
      repository: repository,
      profile: _profile('bob'),
      relationships: <Friendship>[
        _friendship(requester: 'alice', recipient: 'bob'),
      ],
    );
    expect(find.text('Richiesta già in attesa.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('invite-send')), findsNothing);

    await _pumpInvite(
      tester,
      repository: repository,
      profile: _profile('bob'),
      relationships: <Friendship>[
        _friendship(requester: 'alice', recipient: 'bob', state: 'accepted'),
      ],
    );
    expect(find.text('Siete già amici.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('invite-profile')),
      findsOneWidget,
    );
  });

  testWidgets('typed callable failure is inline and retryable', (tester) async {
    final repository = _Friendships()
      ..failure = const FriendshipUnavailableFailure();
    await _pumpInvite(tester, repository: repository, profile: _profile('bob'));

    await tester.tap(find.byKey(const ValueKey<String>('invite-send')));
    await tester.pumpAndSettle();
    expect(
      find.text('Servizio amicizie non disponibile. Riprova.'),
      findsOneWidget,
    );

    repository.failure = null;
    await tester.tap(find.byKey(const ValueKey<String>('invite-retry')));
    await tester.pumpAndSettle();
    expect(repository.actions, <String>['send:bob', 'send:bob']);
    expect(find.text('Richiesta inviata.'), findsOneWidget);
  });
}

Future<void> _pumpInvite(
  WidgetTester tester, {
  String? targetUid = 'bob',
  required _Friendships repository,
  PublicProfile? profile,
  AsyncValue<PublicProfile?>? profileValue,
  List<Friendship> relationships = const <Friendship>[],
  AsyncValue<List<Friendship>>? relationshipsValue,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final Stream<PublicProfile?> profileStream;
  if (profileValue case AsyncLoading<PublicProfile?>()) {
    profileStream = StreamController<PublicProfile?>().stream;
  } else if (profileValue case AsyncError<PublicProfile?>(
    :final error,
    :final stackTrace,
  )) {
    profileStream = Stream<PublicProfile?>.error(error, stackTrace);
  } else {
    profileStream = Stream<PublicProfile?>.value(profile);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        friendshipRepositoryProvider.overrideWithValue(repository),
        friendshipsProvider.overrideWithValue(
          relationshipsValue ?? AsyncData(relationships),
        ),
        if (targetUid != null)
          publicProfileProvider(targetUid).overrideWith((ref) => profileStream),
      ],
      child: MaterialApp(home: InviteScreen(userId: targetUid)),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (profileValue is! AsyncLoading<PublicProfile?> &&
      relationshipsValue is! AsyncLoading<List<Friendship>>) {
    await tester.pumpAndSettle();
  }
}

PublicProfile _profile(String uid) => PublicProfile.fromMap(<String, dynamic>{
  'uid': uid,
  'display_name': uid == 'bob' ? 'Bob' : 'Alice',
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
  'updated_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
}, uid);

Friendship _friendship({
  required String requester,
  required String recipient,
  String state = 'pending',
}) {
  final now = Timestamp.fromDate(DateTime(2026, 7, 15));
  return Friendship.fromMap(
    <String, dynamic>{
      'member_uids': <String>['alice', 'bob'],
      'requester_uid': requester,
      'recipient_uid': recipient,
      'state': state,
      'requested_at': now,
      'responded_at': state == 'pending' ? null : now,
      'accepted_at': state == 'accepted' ? now : null,
      'removed_at': null,
      'affinity_score': 0,
      'updated_at': now,
    },
    'YWxpY2U.Ym9i',
    callerUid: 'alice',
  );
}

final class _Friendships implements FriendshipRepository {
  final List<String> actions = <String>[];
  Completer<void>? gate;
  FriendshipFailure? failure;

  Future<void> _complete(String action) async {
    actions.add(action);
    if (failure case final value?) throw value;
    if (gate case final value?) await value.future;
  }

  @override
  Future<void> send(String otherUid) => _complete('send:$otherUid');

  @override
  Future<void> respond(String otherUid, FriendResponse response) =>
      _complete('respond:$otherUid:${response.name}');

  @override
  Future<void> remove(String otherUid) => _complete('remove:$otherUid');

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async => false;

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async =>
      const <PublicProfile>[];

  @override
  Stream<List<Friendship>> watchForUser(String uid) =>
      Stream<List<Friendship>>.value(const <Friendship>[]);
}
