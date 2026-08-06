import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../models/friendship.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friendship_providers.dart';
import '../../providers/profile_providers.dart';
import '../../repositories/friendship_repository.dart';
import '../../constants/app_strings.dart';

enum _RelationshipKind { accepted, incoming, outgoing, available }

final class ProfileRelationshipAction extends ConsumerStatefulWidget {
  const ProfileRelationshipAction({required this.targetUid, super.key});

  final String targetUid;

  @override
  ConsumerState<ProfileRelationshipAction> createState() =>
      _ProfileRelationshipActionState();
}

final class _ProfileRelationshipActionState
    extends ConsumerState<ProfileRelationshipAction> {
  bool _pending = false;
  String? _failure;
  _RelationshipKind? _optimistic;
  Future<void> Function()? _retry;
  int _generation = 0;
  String? _boundUid;

  @override
  void didUpdateWidget(covariant ProfileRelationshipAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetUid != widget.targetUid) _resetBinding();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    if (_boundUid != uid) {
      _boundUid = uid;
      _resetBinding();
    }
    if (uid == null || uid == widget.targetUid) {
      return const SizedBox.shrink();
    }
    final relationships = ref.watch(friendshipsProvider);
    return relationships.when(
      data: (values) {
        final relationship = _relationship(values, uid, widget.targetUid);
        final kind = _optimistic ?? _kind(relationship, uid);
        return _content(context, kind);
      },
      loading: () => const Chip(label: Text(AppStrings.relationshipChecking)),
      error: (error, stackTrace) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.relationshipUnavailable),
          TextButton.icon(
            onPressed: _pending
                ? null
                : () => ref.read(retryFriendshipSourcesProvider)(),
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, _RelationshipKind kind) {
    final actions = switch (kind) {
      _RelationshipKind.accepted => <Widget>[
        const Chip(label: Text(AppStrings.relationshipFriend)),
        OutlinedButton.icon(
          key: ValueKey('profile-relationship-remove-${widget.targetUid}'),
          onPressed: _pending ? null : _confirmRemove,
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text(AppStrings.remove),
        ),
      ],
      _RelationshipKind.incoming => <Widget>[
        const Chip(label: Text(AppStrings.relationshipToAccept)),
        FilledButton(
          key: ValueKey('profile-relationship-accept-${widget.targetUid}'),
          onPressed: _pending ? null : () => _respond(FriendResponse.accepted),
          child: const Text(AppStrings.accept),
        ),
        OutlinedButton(
          key: ValueKey('profile-relationship-decline-${widget.targetUid}'),
          onPressed: _pending ? null : () => _respond(FriendResponse.declined),
          child: const Text(AppStrings.reject),
        ),
      ],
      _RelationshipKind.outgoing => const <Widget>[
        Chip(label: Text(AppStrings.relationshipPending)),
      ],
      _RelationshipKind.available => <Widget>[
        FilledButton.icon(
          key: ValueKey('profile-relationship-send-${widget.targetUid}'),
          onPressed: _pending ? null : _send,
          icon: const Icon(Icons.person_add_alt),
          label: const Text(AppStrings.add),
        ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: actions,
        ),
        if (_failure case final failure?) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              failure,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TextButton.icon(
            key: ValueKey('profile-relationship-retry-${widget.targetUid}'),
            onPressed: _pending ? null : _retry,
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry),
          ),
        ],
      ],
    );
  }

  Future<void> _send() => _perform(
    operation: () =>
        ref.read(friendshipRepositoryProvider).send(widget.targetUid),
    success: _RelationshipKind.outgoing,
    retry: _send,
  );

  Future<void> _respond(FriendResponse response) => _perform(
    operation: () => ref
        .read(friendshipRepositoryProvider)
        .respond(widget.targetUid, response),
    success: response == FriendResponse.accepted
        ? _RelationshipKind.accepted
        : _RelationshipKind.available,
    retry: () => _respond(response),
  );

  Future<void> _remove() => _perform(
    operation: () =>
        ref.read(friendshipRepositoryProvider).remove(widget.targetUid),
    success: _RelationshipKind.available,
    retry: _remove,
  );

  Future<void> _confirmRemove() async {
    final uid = ref.read(currentUidProvider);
    final targetUid = widget.targetUid;
    final generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.removeFriendshipTitle),
        content: const Text(AppStrings.removeFriendshipBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.remove),
          ),
        ],
      ),
    );
    if (confirmed == true && _isCurrent(generation, uid, targetUid)) {
      await _remove();
    }
  }

  Future<void> _perform({
    required Future<void> Function() operation,
    required _RelationshipKind success,
    required Future<void> Function() retry,
  }) async {
    if (_pending) return;
    final uid = ref.read(currentUidProvider);
    final targetUid = widget.targetUid;
    final generation = _generation;
    setState(() {
      _pending = true;
      _failure = null;
      _retry = retry;
    });
    try {
      await operation();
      if (!_isCurrent(generation, uid, targetUid)) return;
      setState(() {
        _pending = false;
        _failure = null;
        _optimistic = success;
      });
      ref.read(retryFriendshipSourcesProvider)();
      ref.invalidate(publicProfileProvider(targetUid));
    } catch (error) {
      if (!_isCurrent(generation, uid, targetUid)) return;
      setState(() {
        _pending = false;
        _failure = error is FriendshipFailure
            ? error.message
            : AppStrings.operationFailed;
      });
    }
  }

  bool _isCurrent(int generation, String? uid, String targetUid) =>
      mounted &&
      generation == _generation &&
      uid == ref.read(currentUidProvider) &&
      targetUid == widget.targetUid;

  void _resetBinding() {
    _generation++;
    _pending = false;
    _failure = null;
    _retry = null;
    _optimistic = null;
  }
}

Friendship? _relationship(
  List<Friendship> values,
  String uid,
  String targetUid,
) {
  for (final relationship in values) {
    if (relationship.memberUids.contains(uid) &&
        relationship.memberUids.contains(targetUid)) {
      return relationship;
    }
  }
  return null;
}

_RelationshipKind _kind(Friendship? relationship, String uid) {
  if (relationship == null) return _RelationshipKind.available;
  if (relationship.state == FriendshipState.accepted) {
    return _RelationshipKind.accepted;
  }
  if (relationship.state == FriendshipState.pending) {
    return relationship.recipientUid == uid
        ? _RelationshipKind.incoming
        : _RelationshipKind.outgoing;
  }
  return _RelationshipKind.available;
}
