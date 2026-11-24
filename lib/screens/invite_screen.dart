import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/friendship.dart';
import '../models/public_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/friendship_providers.dart';
import '../providers/profile_providers.dart';
import '../repositories/friendship_repository.dart';
import '../widgets/app_controls.dart';
import '../widgets/avatar_image_provider.dart';
import '../constants/app_strings.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.userId});

  final String? userId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _submitting = false;
  bool _completed = false;
  bool _accepted = false;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final targetUid = widget.userId;
    if (!_validUid(targetUid)) {
      return _InviteScaffold(
        child: _InviteMessage(AppStrings.inviteLinkInvalid),
      );
    }
    final currentUid = ref.watch(currentUidProvider);
    if (targetUid == currentUid) {
      return _InviteScaffold(
        child: _InviteMessage(AppStrings.inviteSelf),
      );
    }

    final profile = ref.watch(publicProfileProvider(targetUid!));
    return _InviteScaffold(
      child: profile.when(
        loading: () => const CircularProgressIndicator(),
        error: (_, _) => _InviteMessage(AppStrings.inviteProfileInaccessible),
        data: (value) => value == null
            ? _InviteMessage(AppStrings.inviteProfileNotFound)
            : _buildProfile(value, currentUid),
      ),
    );
  }

  Widget _buildProfile(PublicProfile profile, String? currentUid) {
    if (currentUid == null) {
      return _InviteMessage(AppStrings.inviteLoginToContinue);
    }
    final relationships = ref.watch(friendshipsProvider);
    return relationships.when(
      loading: () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(AppStrings.inviteCheckingFriendship),
        ],
      ),
      error: (_, _) => _InviteMessage(
        AppStrings.inviteVerifyError,
      ),
      data: (values) {
        final relationship = _relationshipWith(values, currentUid, profile.uid);
        final accepted =
            _accepted || relationship?.state == FriendshipState.accepted;
        final reversePending =
            relationship?.state == FriendshipState.pending &&
            relationship?.requesterUid == profile.uid &&
            relationship?.recipientUid == currentUid;
        final outgoingPending =
            relationship?.state == FriendshipState.pending &&
            relationship?.requesterUid == currentUid;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthenticatedAvatar(
                source: profile.avatarPath,
                radius: 44,
                iconSize: 40,
              ),
              const SizedBox(height: 16),
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile.city.isEmpty ? AppStrings.profileGelatinoFallback : profile.city,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_failure case final failure?) ...[
                Text(
                  failure,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey<String>('invite-retry'),
                  onPressed: _submitting
                      ? null
                      : () => _perform(
                          profile.uid,
                          acceptReverse: reversePending,
                        ),
                  child: Text(AppStrings.retry),
                ),
              ] else if (_completed && _accepted) ...[
                Text(AppStrings.inviteNowFriends),
                const SizedBox(height: 12),
                _profileButton(profile.uid),
              ] else if (accepted) ...[
                Text(AppStrings.inviteAlreadyFriends),
                const SizedBox(height: 12),
                _profileButton(profile.uid),
              ] else if (_completed) ...[
                Text(AppStrings.inviteRequestSent),
                const SizedBox(height: 12),
                _profileButton(profile.uid),
              ] else if (outgoingPending) ...[
                Text(AppStrings.inviteRequestPending),
                const SizedBox(height: 12),
                _profileButton(profile.uid),
              ] else if (reversePending) ...[
                Text(AppStrings.inviteAlreadyInvitedYou(profile.displayName)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey<String>('invite-accept'),
                  onPressed: _submitting
                      ? null
                      : () => _perform(profile.uid, acceptReverse: true),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.person_add_solid),
                  label: Text(AppStrings.inviteAcceptRequest),
                ),
              ] else
                FilledButton.icon(
                  key: const ValueKey<String>('invite-send'),
                  onPressed: _submitting
                      ? null
                      : () => _perform(profile.uid, acceptReverse: false),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.person_add_solid),
                  label: Text(AppStrings.inviteSendRequest),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileButton(String uid) => OutlinedButton(
    key: const ValueKey<String>('invite-profile'),
    onPressed: () => context.push(
      Uri(
        path: '/profile',
        queryParameters: <String, String>{'userId': uid},
      ).toString(),
    ),
    child: Text(AppStrings.inviteOpenProfile),
  );

  Future<void> _perform(String targetUid, {required bool acceptReverse}) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final repository = ref.read(friendshipRepositoryProvider);
      if (acceptReverse) {
        await repository.respond(targetUid, FriendResponse.accepted);
      } else {
        await repository.send(targetUid);
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _completed = true;
        _accepted = acceptReverse;
      });
    } on FriendshipFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = AppStrings.friendshipUpdateError;
      });
    }
  }
}

Friendship? _relationshipWith(
  Iterable<Friendship> values,
  String currentUid,
  String targetUid,
) {
  Friendship? candidate;
  for (final relationship in values) {
    if (!relationship.memberUids.contains(currentUid) ||
        !relationship.memberUids.contains(targetUid)) {
      continue;
    }
    if (relationship.state == FriendshipState.accepted) return relationship;
    candidate ??= relationship;
  }
  return candidate;
}

bool _validUid(String? value) =>
    value != null &&
    value.isNotEmpty &&
    value.length <= 128 &&
    !value.contains('/') &&
    !value.contains('\\') &&
    !RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);

class _InviteScaffold extends StatelessWidget {
  const _InviteScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(fallback: '/collection'),
      title: Text(AppStrings.inviteTitle),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    ),
  );
}

class _InviteMessage extends StatelessWidget {
  const _InviteMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.titleMedium,
  );
}
