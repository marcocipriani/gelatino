import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import '../models/gelato_invite.dart';
import 'friendship_repository.dart';

final class InviteDocument {
  const InviteDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

final class InviteServerTimestamp {
  const InviteServerTimestamp();

  @override
  bool operator ==(Object other) => other is InviteServerTimestamp;

  @override
  int get hashCode => 0;
}

final class GelatoInviteQuery {
  const GelatoInviteQuery._({
    required this.receiverId,
    required this.memberUid,
    required this.status,
    required this.limit,
  });

  const GelatoInviteQuery.pendingIncoming(String uid)
    : this._(receiverId: uid, memberUid: null, status: 'pending', limit: 50);

  const GelatoInviteQuery.history(String uid)
    : this._(receiverId: null, memberUid: uid, status: null, limit: 100);

  final String collectionPath = 'pings';
  final String? receiverId;
  final String? memberUid;
  final String? status;
  final String orderByField = 'created_at';
  final bool descending = true;
  final int limit;
}

abstract interface class GelatoInviteDataSource {
  String? get authUid;

  Stream<List<InviteDocument>> watchInvites(GelatoInviteQuery query);

  Future<void> createInvite(Map<String, Object?> data);

  Future<InviteDocument?> readInvite(String path);

  Future<void> updateInvite(String path, Map<String, Object?> data);
}

final class FirestoreGelatoInviteDataSource implements GelatoInviteDataSource {
  FirestoreGelatoInviteDataSource(this._firestore, this._authUid);

  final FirebaseFirestore _firestore;
  final String? Function() _authUid;

  @override
  String? get authUid => _authUid();

  @override
  Stream<List<InviteDocument>> watchInvites(GelatoInviteQuery query) {
    Query<Map<String, dynamic>> reference = _firestore.collection(
      query.collectionPath,
    );
    if (query.receiverId case final receiverId?) {
      reference = reference.where('receiver_id', isEqualTo: receiverId);
    }
    if (query.memberUid case final memberUid?) {
      reference = reference.where('member_uids', arrayContains: memberUid);
    }
    if (query.status case final status?) {
      reference = reference.where('status', isEqualTo: status);
    }
    return reference
        .orderBy(query.orderByField, descending: query.descending)
        .limit(query.limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    InviteDocument(id: document.id, data: document.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> createInvite(Map<String, Object?> data) {
    return _firestore.collection('pings').add(_firebaseData(data)).then((_) {});
  }

  @override
  Future<InviteDocument?> readInvite(String path) async {
    final snapshot = await _firestore.doc(path).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return InviteDocument(id: snapshot.id, data: data);
  }

  @override
  Future<void> updateInvite(String path, Map<String, Object?> data) {
    return _firestore.doc(path).update(_firebaseData(data));
  }

  Map<String, Object?> _firebaseData(Map<String, Object?> data) =>
      <String, Object?>{
        for (final entry in data.entries)
          entry.key: entry.value is InviteServerTimestamp
              ? FieldValue.serverTimestamp()
              : entry.value,
      };
}

abstract interface class GelatoInviteRepository {
  Stream<List<GelatoInvite>> watchPendingIncoming(String uid);

  Stream<List<GelatoInvite>> watchHistory(String uid);

  Future<void> send(String receiverUid);

  Future<void> respond(String inviteId, GelatoInviteStatus response);
}

final class GelatoInviteRepositoryImpl implements GelatoInviteRepository {
  GelatoInviteRepositoryImpl(
    this._source,
    this._friendships, [
    this._onSent,
  ]);

  final GelatoInviteDataSource _source;
  final FriendshipRepository _friendships;
  final void Function()? _onSent;

  @override
  Stream<List<GelatoInvite>> watchPendingIncoming(String uid) {
    requirePathSegment(uid, 'uid');
    return _source
        .watchInvites(GelatoInviteQuery.pendingIncoming(uid))
        .map((documents) => _parse(documents, uid: uid, incomingOnly: true));
  }

  @override
  Stream<List<GelatoInvite>> watchHistory(String uid) {
    requirePathSegment(uid, 'uid');
    return _source
        .watchInvites(GelatoInviteQuery.history(uid))
        .map((documents) => _parse(documents, uid: uid));
  }

  List<GelatoInvite> _parse(
    List<InviteDocument> documents, {
    required String uid,
    bool incomingOnly = false,
  }) {
    final byId = <String, GelatoInvite>{};
    for (final document in documents) {
      final invite = parseOrReport<GelatoInvite>(
        path: 'pings/${document.id}',
        parse: () {
          final parsed = GelatoInvite.fromMap(document.data, document.id);
          if (!parsed.memberUids.contains(uid)) {
            throw const FormatException('uid: not an invite member');
          }
          if (incomingOnly &&
              (parsed.receiverId != uid ||
                  parsed.status != GelatoInviteStatus.pending)) {
            throw const FormatException('invite: not pending incoming');
          }
          return parsed;
        },
      );
      if (invite != null) byId[invite.id] = invite;
    }
    final invites = byId.values.toList()
      ..sort((left, right) {
        final createdAt = right.createdAt.compareTo(left.createdAt);
        return createdAt != 0 ? createdAt : left.id.compareTo(right.id);
      });
    return List<GelatoInvite>.unmodifiable(invites);
  }

  @override
  Future<void> send(String receiverUid) async {
    final senderUid = _requireAuthUid();
    requirePathSegment(receiverUid, 'receiverUid');
    if (senderUid == receiverUid) throw const InvalidInviteFailure();
    if (!await _friendships.isAcceptedFriend(senderUid, receiverUid)) {
      throw const InviteFriendshipRequired();
    }
    final members = <String>[senderUid, receiverUid]..sort();
    await _source.createInvite(<String, Object?>{
      'member_uids': members,
      'sender_id': senderUid,
      'receiver_id': receiverUid,
      'status': 'pending',
      'created_at': const InviteServerTimestamp(),
      'responded_at': null,
    });
    // The ping is already sent; a broken hook must never fail send() itself.
    try {
      _onSent?.call();
    } catch (_) {
      // ponytail: backstop only — enablePushAfterSocialAction already
      // swallows its own errors, this just protects against any future
      // misbehaving hook.
    }
  }

  @override
  Future<void> respond(String inviteId, GelatoInviteStatus response) async {
    final uid = _requireAuthUid();
    requirePathSegment(inviteId, 'inviteId');
    if (response == GelatoInviteStatus.pending) {
      throw const InvalidInviteFailure();
    }
    final document = await _source.readInvite('pings/$inviteId');
    if (document == null) throw const InviteNotFoundFailure();
    final invite = parseOrReport<GelatoInvite>(
      path: 'pings/$inviteId',
      parse: () => GelatoInvite.fromMap(document.data, document.id),
    );
    if (invite == null) throw const InvalidInviteFailure();
    if (invite.receiverId != uid) throw const InvitePermissionFailure();
    if (invite.status != GelatoInviteStatus.pending) {
      throw const InvalidInviteFailure();
    }
    await _source.updateInvite('pings/$inviteId', <String, Object?>{
      'status': response.name,
      'responded_at': const InviteServerTimestamp(),
    });
  }

  String _requireAuthUid() {
    final uid = _source.authUid;
    if (uid == null) throw const InviteAuthenticationFailure();
    requirePathSegment(uid, 'authUid');
    return uid;
  }
}

sealed class GelatoInviteFailure implements Exception {
  const GelatoInviteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class InvalidInviteFailure extends GelatoInviteFailure {
  const InvalidInviteFailure() : super('Invito Gelatino non valido.');
}

final class InviteFriendshipRequired extends GelatoInviteFailure {
  const InviteFriendshipRequired()
    : super('Puoi invitare solo un’amicizia accettata.');
}

final class InvitePermissionFailure extends GelatoInviteFailure {
  const InvitePermissionFailure()
    : super('Solo chi riceve l’invito può rispondere.');
}

final class InviteNotFoundFailure extends GelatoInviteFailure {
  const InviteNotFoundFailure() : super('Invito Gelatino non trovato.');
}

final class InviteAuthenticationFailure extends GelatoInviteFailure {
  const InviteAuthenticationFailure() : super('Accedi per inviare un invito.');
}
