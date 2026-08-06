import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../models/friendship.dart';
import '../models/gelato_invite.dart';
import '../models/public_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/friendship_providers.dart';
import '../providers/gelato_invite_providers.dart';
import '../providers/navigation_provider.dart';
import '../providers/profile_providers.dart';
import '../repositories/friendship_repository.dart';
import '../repositories/gelato_invite_repository.dart';
import '../widgets/app_page.dart';
import '../widgets/editorial_header.dart';
import '../widgets/friends/leaderboard_section.dart';
import 'friends/friends_sections.dart';
import '../constants/app_strings.dart';

Uri buildExternalInviteUri(String uid) =>
    Uri.https('gelatino.web.app', '/join', <String, String>{'by': uid});

enum FriendSearchRelationshipStatus {
  accepted('Amico', false),
  incomingPending(AppStrings.relationshipToAccept, false),
  outgoingPending(AppStrings.relationshipPending, false),
  available(AppStrings.add, true);

  const FriendSearchRelationshipStatus(this.label, this.canSendRequest);

  final String? label;
  final bool canSendRequest;
}

enum _RelationshipLookupState { ready, loading, error }

FriendSearchRelationshipStatus friendSearchRelationshipStatus(
  String candidateUid, {
  required Set<String> acceptedUids,
  required Set<String> incomingPendingUids,
  required Set<String> outgoingPendingUids,
}) {
  if (acceptedUids.contains(candidateUid)) {
    return FriendSearchRelationshipStatus.accepted;
  }
  if (incomingPendingUids.contains(candidateUid)) {
    return FriendSearchRelationshipStatus.incomingPending;
  }
  if (outgoingPendingUids.contains(candidateUid)) {
    return FriendSearchRelationshipStatus.outgoingPending;
  }
  return FriendSearchRelationshipStatus.available;
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PublicProfile> _searchResults = [];
  bool _isSearching = false;
  String _lastSearchQuery = '';
  String? _searchError;
  String? _boundUid;
  String? _externalInviteFeedback;
  bool _isCopyingExternalInvite = false;
  int _searchGeneration = 0;
  int _actionGeneration = 0;
  final Set<String> _pendingActions = <String>{};
  final Map<String, String> _actionFailures = <String, String>{};
  final Map<String, Future<void> Function()> _actionRetries =
      <String, Future<void> Function()>{};
  final Map<String, String> _actionTargets = <String, String>{};
  final Map<String, String> _actionBindings = <String, String>{};
  final Set<String> _sentFriendRequestUids = <String>{};
  final Set<String> _sentInviteUids = <String>{};
  final Set<String> _resolvedRequestIds = <String>{};
  final Set<String> _resolvedInviteIds = <String>{};
  final Set<String> _removedFriendUids = <String>{};
  final Set<String> _routedInviteIds = <String>{};
  @override
  void dispose() {
    _searchGeneration++;
    _actionGeneration++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    final uid = ref.read(currentUidProvider);
    final generation = ++_searchGeneration;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _lastSearchQuery = '';
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastSearchQuery = query;
      _searchError = null;
    });

    try {
      final results = await ref
          .read(profileRepositoryProvider)
          .searchPublicProfiles(query);
      final visibleResults = results
          .where((profile) => profile.uid != uid)
          .toList(growable: false);

      if (_isCurrentSearch(generation, uid, query)) {
        setState(() => _searchResults = visibleResults);
      }
    } catch (e) {
      if (_isCurrentSearch(generation, uid, query)) {
        setState(() {
          _searchError = AppStrings.friendsSearchError;
        });
      }
    } finally {
      if (_isCurrentSearch(generation, uid, query)) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  bool _isCurrentSearch(int generation, String? uid, String query) =>
      mounted &&
      generation == _searchGeneration &&
      uid == ref.read(currentUidProvider) &&
      query == _searchController.text.trim();

  void _clearSearch() {
    _searchGeneration++;
    _searchController.clear();
    setState(() {
      _searchResults = const <PublicProfile>[];
      _lastSearchQuery = '';
      _searchError = null;
      _isSearching = false;
    });
  }

  void _synchronizeUid(String? uid) {
    if (_boundUid == uid) return;
    _boundUid = uid;
    _searchGeneration++;
    _actionGeneration++;
    _searchResults = const <PublicProfile>[];
    _lastSearchQuery = '';
    _searchError = null;
    _isSearching = false;
    _externalInviteFeedback = null;
    _isCopyingExternalInvite = false;
    _pendingActions.clear();
    _actionFailures.clear();
    _actionRetries.clear();
    _actionTargets.clear();
    _actionBindings.clear();
    _sentFriendRequestUids.clear();
    _sentInviteUids.clear();
    _resolvedRequestIds.clear();
    _resolvedInviteIds.clear();
    _removedFriendUids.clear();
    _routedInviteIds.clear();
    if (_searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _boundUid == uid) _searchController.clear();
      });
    }
  }

  Future<void> _addFriend(String friendId) async {
    final succeeded = await _runAction(
      key: 'request-$friendId',
      targetUid: friendId,
      operation: () => ref.read(friendshipRepositoryProvider).send(friendId),
      retry: () => _addFriend(friendId),
    );
    if (!succeeded) return;
    setState(() => _sentFriendRequestUids.add(friendId));
    _refreshFriendshipSources(friendId);
  }

  Future<void> _removeFriend(String friendId) async {
    final succeeded = await _runAction(
      key: 'remove-$friendId',
      targetUid: friendId,
      operation: () => ref.read(friendshipRepositoryProvider).remove(friendId),
      retry: () => _removeFriend(friendId),
    );
    if (!succeeded) return;
    setState(() => _removedFriendUids.add(friendId));
    _refreshFriendshipSources(friendId);
  }

  Future<void> _sendPing(PublicProfile friend) async {
    if (_sentInviteUids.contains(friend.uid)) return;
    final succeeded = await _runAction(
      key: 'invite-send-${friend.uid}',
      targetUid: friend.uid,
      operation: () =>
          ref.read(gelatoInviteRepositoryProvider).send(friend.uid),
      retry: () => _sendPing(friend),
    );
    if (!succeeded) return;
    setState(() => _sentInviteUids.add(friend.uid));
  }

  Future<void> _acceptPing(GelatoInvite ping) =>
      _respondToInvite(ping, GelatoInviteStatus.accepted);

  Future<void> _declinePing(GelatoInvite ping) =>
      _respondToInvite(ping, GelatoInviteStatus.declined);

  Future<bool> _respondToInvite(
    GelatoInvite invite,
    GelatoInviteStatus response,
  ) async {
    final succeeded = await _runAction(
      key: 'invite-response-${invite.id}',
      targetUid: invite.senderId,
      operation: () =>
          ref.read(gelatoInviteRepositoryProvider).respond(invite.id, response),
      retry: () async {
        await _respondToInvite(invite, response);
      },
    );
    if (!succeeded) return false;
    setState(() => _resolvedInviteIds.add(invite.id));
    if (response == GelatoInviteStatus.accepted &&
        _routedInviteIds.add(invite.id) &&
        mounted) {
      context.go(checkInPrefillRoute(invite.senderId));
    }
    final uid = ref.read(currentUidProvider);
    if (uid != null) _retryInvites(uid);
    return true;
  }

  Future<void> _respondFriendRequest(
    Friendship request,
    FriendResponse response,
  ) async {
    final succeeded = await _runAction(
      key: 'friend-response-${request.id}',
      targetUid: request.requesterUid,
      operation: () => ref
          .read(friendshipRepositoryProvider)
          .respond(request.requesterUid, response),
      retry: () => _respondFriendRequest(request, response),
    );
    if (!succeeded) return;
    setState(() => _resolvedRequestIds.add(request.id));
    _refreshFriendshipSources(request.requesterUid);
  }

  Future<bool> _runAction({
    required String key,
    required String targetUid,
    required Future<void> Function() operation,
    required Future<void> Function() retry,
  }) async {
    if (_pendingActions.contains(key)) return false;
    final boundTarget = _actionBindings[key];
    if (boundTarget != null && boundTarget != targetUid) return false;
    final uid = ref.read(currentUidProvider);
    final generation = _actionGeneration;
    setState(() {
      _pendingActions.add(key);
      _actionFailures.remove(key);
      _actionTargets[key] = targetUid;
      _actionBindings[key] = targetUid;
    });
    try {
      await operation();
      if (!_isCurrentAction(generation, uid, key: key, targetUid: targetUid)) {
        return false;
      }
      setState(() {
        _pendingActions.remove(key);
        _actionFailures.remove(key);
        _actionRetries.remove(key);
        _actionTargets.remove(key);
      });
      return true;
    } catch (error) {
      if (!_isCurrentAction(generation, uid, key: key, targetUid: targetUid)) {
        return false;
      }
      setState(() {
        _pendingActions.remove(key);
        _actionFailures[key] = _actionFailureMessage(error);
        _actionRetries[key] = retry;
        _actionTargets.remove(key);
      });
      return false;
    }
  }

  bool _isCurrentAction(
    int generation,
    String? uid, {
    String? key,
    String? targetUid,
  }) {
    if (!mounted ||
        generation != _actionGeneration ||
        uid != ref.read(currentUidProvider)) {
      return false;
    }
    if (key == null || targetUid == null) return true;
    return _actionTargets[key] == targetUid &&
        _actionBindings[key] == targetUid;
  }

  Widget _bindActionTarget({
    required String key,
    required String targetUid,
    required Widget Function() builder,
  }) {
    final activeTarget = _actionTargets[key];
    final previousBinding = _actionBindings[key];
    if ((activeTarget != null && activeTarget != targetUid) ||
        (previousBinding != null && previousBinding != targetUid)) {
      _pendingActions.remove(key);
      _actionFailures.remove(key);
      _actionRetries.remove(key);
      _actionTargets.remove(key);
      _actionBindings.remove(key);
    }
    _actionBindings[key] = targetUid;
    return builder();
  }

  Future<void> _copyExternalInvite(String uid) async {
    if (_isCopyingExternalInvite) return;
    final generation = _actionGeneration;
    setState(() {
      _isCopyingExternalInvite = true;
      _externalInviteFeedback = null;
    });
    try {
      await Clipboard.setData(
        ClipboardData(text: buildExternalInviteUri(uid).toString()),
      );
      if (_isCurrentAction(generation, uid)) {
        setState(() {
          _isCopyingExternalInvite = false;
          _externalInviteFeedback = AppStrings.friendsInviteLinkCopied;
        });
      }
    } catch (_) {
      if (_isCurrentAction(generation, uid)) {
        setState(() {
          _isCopyingExternalInvite = false;
          _externalInviteFeedback = AppStrings.friendsInviteLinkCopyError;
        });
      }
    }
  }

  String _actionFailureMessage(Object error) => switch (error) {
    FriendshipFailure(:final message) => message,
    GelatoInviteFailure(:final message) => message,
    _ => AppStrings.operationFailed,
  };

  void _refreshFriendshipSources(String targetUid) {
    _retryFriendships();
    ref.invalidate(publicProfileProvider(targetUid));
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    _synchronizeUid(uid);
    final profile = ref.watch(ownProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveClass.fromWidth(constraints.maxWidth);
            return AppPage(
              child: profile.when(
                data: (value) {
                  if (uid == null || value == null) {
                    return const FriendsStatePanel(
                      title: AppStrings.friendsLoginTitle,
                      message:
                          AppStrings.friendsLoginSubtitle,
                      icon: Icons.lock_outline,
                    );
                  }
                  return _buildA1Friends(context, uid, responsive);
                },
                loading: () => const FriendsSkeleton(rows: 4),
                error: (error, stackTrace) => FriendsStatePanel(
                  title: AppStrings.profileUnavailable,
                  message: AppStrings.profileLoadError,
                  actionLabel: AppStrings.retry,
                  onAction: () => ref.invalidate(ownProfileProvider),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildA1Friends(
    BuildContext context,
    String uid,
    ResponsiveClass responsive,
  ) {
    final friends = ref.watch(acceptedFriendProfilesProvider);
    final requests = ref.watch(incomingFriendRequestsProvider);
    final invites = ref.watch(pendingIncomingGelatoInvitesProvider);
    final accepted = ref.watch(acceptedFriendsProvider);
    final outgoing = ref.watch(outgoingFriendRequestsProvider);

    final relationshipLookupState =
        accepted.hasError || requests.hasError || outgoing.hasError
        ? _RelationshipLookupState.error
        : accepted.isLoading || requests.isLoading || outgoing.isLoading
        ? _RelationshipLookupState.loading
        : _RelationshipLookupState.ready;

    final acceptedUids = switch (accepted) {
      AsyncData(:final value) => value.toSet(),
      _ => const <String>{},
    };
    final incomingUids = switch (requests) {
      AsyncData(:final value) =>
        value.map((request) => request.requesterUid).toSet(),
      _ => const <String>{},
    };
    final outgoingUids = switch (outgoing) {
      AsyncData(:final value) =>
        value
            .map((request) => request.recipientUid)
            .followedBy(_sentFriendRequestUids)
            .toSet(),
      _ => Set<String>.unmodifiable(_sentFriendRequestUids),
    };

    const leaderboardSection = LeaderboardSection();
    final searchSection = FriendsSection(
      title: AppStrings.friendsFindPeople,
      description: AppStrings.friendsFindPeopleSubtitle,
      child: _buildA1Search(
        relationshipLookupState: relationshipLookupState,
        acceptedUids: acceptedUids,
        incomingUids: incomingUids,
        outgoingUids: outgoingUids,
      ),
    );
    final friendsSection = FriendsSection(
      title: AppStrings.friendsYourFriends,
      description: AppStrings.friendsYourFriendsSubtitle,
      child: friends.when(
        data: (profiles) {
          final visibleProfiles = profiles
              .where((profile) => !_removedFriendUids.contains(profile.uid))
              .toList(growable: false);
          if (visibleProfiles.isEmpty) {
            return const FriendsStatePanel(
              title: AppStrings.friendsEmptyTitle,
              message: AppStrings.friendsEmptySubtitle,
              icon: Icons.people_outline,
            );
          }
          return FriendsResponsiveCards(
            twoColumns: responsive != ResponsiveClass.compact,
            children: [
              for (final profile in visibleProfiles)
                FriendsPersonCard(
                  key: ValueKey('friend-profile-${profile.uid}'),
                  uid: profile.uid,
                  name: profile.displayName,
                  subtitle: profile.city.isEmpty
                      ? AppStrings.profileGelatinoFallback
                      : profile.city,
                  avatarPath: profile.avatarPath,
                  actions: [
                    FilledButton.icon(
                      key: ValueKey('friend-invite-send-${profile.uid}'),
                      onPressed:
                          _pendingActions.contains(
                                'invite-send-${profile.uid}',
                              ) ||
                              _sentInviteUids.contains(profile.uid)
                          ? null
                          : () => _sendPing(profile),
                      icon: const Icon(Icons.icecream_outlined),
                      label: Text(
                        _sentInviteUids.contains(profile.uid)
                            ? AppStrings.friendsInviteSent
                            : 'Gelatino?',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: ValueKey('friend-remove-${profile.uid}'),
                      onPressed:
                          _pendingActions.contains('remove-${profile.uid}')
                          ? null
                          : () => _confirmRemoveFriend(profile),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text(AppStrings.remove),
                    ),
                  ],
                  onOpen: () => _openProfile(profile.uid),
                  failure: _friendCardFailure(profile),
                ),
            ],
          );
        },
        loading: () => const FriendsSkeleton(rows: 3),
        error: (error, stackTrace) => FriendsStatePanel(
          title: AppStrings.friendsUnavailable,
          message: AppStrings.friendsLoadError,
          actionLabel: AppStrings.retry,
          actionKey: const ValueKey('friends-retry-friends'),
          onAction: _retryFriendships,
        ),
      ),
    );
    final requestsSection = FriendsSection(
      title: AppStrings.friendsRequestsTitle,
      child: requests.when(
        data: (values) {
          final visibleValues = values
              .where((request) => !_resolvedRequestIds.contains(request.id))
              .toList(growable: false);
          if (visibleValues.isEmpty) {
            return const FriendsStatePanel(
              title: AppStrings.friendsRequestsEmpty,
              message: AppStrings.friendsRequestsEmptySubtitle,
              icon: Icons.person_add_alt,
            );
          }
          return Column(
            children: [
              for (final request in visibleValues)
                _bindActionTarget(
                  key: 'friend-response-${request.id}',
                  targetUid: request.requesterUid,
                  builder: () => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RemotePersonCard(
                      uid: request.requesterUid,
                      fallbackTitle: AppStrings.friendsNewRequest,
                      actions: [
                        FilledButton(
                          key: ValueKey(
                            'friend-request-accept-${request.requesterUid}',
                          ),
                          onPressed:
                              _pendingActions.contains(
                                'friend-response-${request.id}',
                              )
                              ? null
                              : () => _respondFriendRequest(
                                  request,
                                  FriendResponse.accepted,
                                ),
                          child: const Text(AppStrings.accept),
                        ),
                        OutlinedButton(
                          key: ValueKey(
                            'friend-request-decline-${request.requesterUid}',
                          ),
                          onPressed:
                              _pendingActions.contains(
                                'friend-response-${request.id}',
                              )
                              ? null
                              : () => _respondFriendRequest(
                                  request,
                                  FriendResponse.declined,
                                ),
                          child: const Text(AppStrings.reject),
                        ),
                      ],
                      onOpen: () => _openProfile(request.requesterUid),
                      failure: _actionFailure(
                        key: 'friend-response-${request.id}',
                        retryKey:
                            'friend-action-retry-response-${request.requesterUid}',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const FriendsSkeleton(),
        error: (error, stackTrace) => FriendsStatePanel(
          title: AppStrings.friendsRequestsUnavailable,
          message: AppStrings.friendsRequestsLoadError,
          actionLabel: AppStrings.retry,
          actionKey: const ValueKey('friends-retry-requests'),
          onAction: _retryFriendships,
        ),
      ),
    );
    final invitesSection = FriendsSection(
      title: AppStrings.friendsInvitesTitle,
      child: invites.when(
        data: (values) {
          final visibleValues = values
              .where((invite) => !_resolvedInviteIds.contains(invite.id))
              .toList(growable: false);
          if (visibleValues.isEmpty) {
            return const FriendsStatePanel(
              title: AppStrings.friendsInvitesEmpty,
              message: AppStrings.friendsInvitesEmptySubtitle,
              icon: Icons.icecream_outlined,
            );
          }
          return Column(
            children: [
              for (final invite in visibleValues)
                _bindActionTarget(
                  key: 'invite-response-${invite.id}',
                  targetUid: invite.senderId,
                  builder: () => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RemotePersonCard(
                      uid: invite.senderId,
                      fallbackTitle: AppStrings.inviteTitle,
                      subtitle: AppStrings.friendsInviteSubtitle,
                      actions: [
                        FilledButton(
                          key: ValueKey('friend-invite-accept-${invite.id}'),
                          onPressed:
                              _pendingActions.contains(
                                'invite-response-${invite.id}',
                              )
                              ? null
                              : () => _acceptPing(invite),
                          child: const Text(AppStrings.friendsInviteAccept),
                        ),
                        OutlinedButton(
                          key: ValueKey('friend-invite-decline-${invite.id}'),
                          onPressed:
                              _pendingActions.contains(
                                'invite-response-${invite.id}',
                              )
                              ? null
                              : () => _declinePing(invite),
                          child: const Text(AppStrings.friendsInviteDecline),
                        ),
                      ],
                      onOpen: () => _openProfile(invite.senderId),
                      failure: _actionFailure(
                        key: 'invite-response-${invite.id}',
                        retryKey: 'friend-action-retry-invite-${invite.id}',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const FriendsSkeleton(),
        error: (error, stackTrace) => FriendsStatePanel(
          title: AppStrings.friendsInvitesUnavailable,
          message: AppStrings.friendsInvitesLoadError,
          actionLabel: AppStrings.retry,
          actionKey: const ValueKey('friends-retry-invites'),
          onAction: () => _retryInvites(uid),
        ),
      ),
    );
    final externalInviteSection = FriendsSection(
      key: const ValueKey('friends-external-invite'),
      title: AppStrings.friendsInvitePersonTitle,
      description: AppStrings.friendsInvitePersonSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const ValueKey('friends-external-invite-copy'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _isCopyingExternalInvite
                ? null
                : () => _copyExternalInvite(uid),
            icon: const Icon(Icons.link),
            label: Text(
              _isCopyingExternalInvite
                  ? AppStrings.friendsCopying
                  : AppStrings.friendsCopyInviteLink,
            ),
          ),
          if (_externalInviteFeedback case final feedback?) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              key: const ValueKey('friends-external-invite-feedback'),
              liveRegion: true,
              child: Text(feedback),
            ),
          ],
        ],
      ),
    );

    return RefreshIndicator(
      key: ValueKey('friends-${responsive.name}'),
      onRefresh: () async {
        _retryFriendships();
        _retryInvites(uid);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSpacing.xl,
          bottom: AppSpacing.display,
        ),
        children: [
          const EditorialHeader(
            eyebrow: 'AMICI',
            title: AppStrings.friendsGelatoWithWhom,
            description:
                AppStrings.friendsGelatoWithWhomSubtitle,
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              if (responsive == ResponsiveClass.wide) {
                return Row(
                  key: const ValueKey('friends-wide-content'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          leaderboardSection,
                          const SizedBox(height: AppSpacing.xl),
                          searchSection,
                          const SizedBox(height: AppSpacing.xl),
                          friendsSection,
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    SizedBox(
                      key: const ValueKey('friends-wide-secondary'),
                      width: 340,
                      child: Column(
                        children: [
                          requestsSection,
                          const SizedBox(height: AppSpacing.xl),
                          invitesSection,
                          const SizedBox(height: AppSpacing.xl),
                          externalInviteSection,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                key: ValueKey(
                  responsive == ResponsiveClass.compact
                      ? 'friends-compact-content'
                      : 'friends-medium-content',
                ),
                children: [
                  leaderboardSection,
                  const SizedBox(height: AppSpacing.xl),
                  invitesSection,
                  const SizedBox(height: AppSpacing.xl),
                  requestsSection,
                  const SizedBox(height: AppSpacing.xl),
                  externalInviteSection,
                  const SizedBox(height: AppSpacing.xl),
                  searchSection,
                  const SizedBox(height: AppSpacing.xl),
                  friendsSection,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildA1Search({
    required _RelationshipLookupState relationshipLookupState,
    required Set<String> acceptedUids,
    required Set<String> incomingUids,
    required Set<String> outgoingUids,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: AppStrings.friendsSearchLabel,
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('friends-search-clear'),
                    onPressed: _clearSearch,
                    tooltip: AppStrings.clearSearch,
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onSubmitted: (_) => _searchUsers(),
          onChanged: (value) {
            if (value.isEmpty &&
                (_lastSearchQuery.isNotEmpty || _searchError != null)) {
              _clearSearch();
            } else {
              setState(() {});
            }
          },
        ),
        if (_isSearching) ...[
          const SizedBox(height: AppSpacing.md),
          const FriendsSkeleton(),
        ] else if (_searchError != null) ...[
          const SizedBox(height: AppSpacing.md),
          FriendsStatePanel(
            title: AppStrings.friendsSearchUnavailable,
            message: _searchError!,
            actionLabel: AppStrings.retry,
            onAction: _searchUsers,
          ),
        ] else if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          if (relationshipLookupState != _RelationshipLookupState.ready) ...[
            _relationshipLookupPanel(relationshipLookupState),
            const SizedBox(height: AppSpacing.md),
          ],
          FriendsResponsiveCards(
            children: [
              for (final profile in _searchResults)
                FriendsPersonCard(
                  key: ValueKey('friend-profile-${profile.uid}'),
                  uid: profile.uid,
                  name: profile.displayName,
                  subtitle: profile.city.isEmpty
                      ? '@${profile.username}'
                      : profile.city,
                  avatarPath: profile.avatarPath,
                  actions: [
                    if (relationshipLookupState ==
                        _RelationshipLookupState.ready)
                      _searchRelationshipAction(
                        profile.uid,
                        friendSearchRelationshipStatus(
                          profile.uid,
                          acceptedUids: acceptedUids,
                          incomingPendingUids: incomingUids,
                          outgoingPendingUids: outgoingUids,
                        ),
                      ),
                  ],
                  onOpen: () => _openProfile(profile.uid),
                  failure: _actionFailure(
                    key: 'request-${profile.uid}',
                    retryKey: 'friend-action-retry-request-${profile.uid}',
                  ),
                ),
            ],
          ),
        ] else if (_lastSearchQuery.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const FriendsStatePanel(
            title: AppStrings.friendsNoResults,
            message: AppStrings.friendsNoResultsSubtitle,
            icon: Icons.search_off,
          ),
        ],
      ],
    );
  }

  Widget _relationshipLookupPanel(_RelationshipLookupState state) {
    return switch (state) {
      _RelationshipLookupState.loading => const FriendsStatePanel(
        title: AppStrings.relationshipChecking,
        message: AppStrings.relationshipCheckingMessage,
        icon: Icons.sync,
      ),
      _RelationshipLookupState.error => FriendsStatePanel(
        title: AppStrings.relationshipUnavailable,
        message: AppStrings.relationshipVerifyError,
        actionLabel: AppStrings.retry,
        actionKey: const ValueKey('friends-retry-relationships'),
        onAction: _retryFriendships,
      ),
      _RelationshipLookupState.ready => const SizedBox.shrink(),
    };
  }

  Widget _searchRelationshipAction(
    String uid,
    FriendSearchRelationshipStatus status,
  ) {
    if (!status.canSendRequest) {
      return Chip(label: Text(status.label!));
    }
    return FilledButton.icon(
      key: ValueKey('friend-send-$uid'),
      onPressed: _pendingActions.contains('request-$uid')
          ? null
          : () => _addFriend(uid),
      icon: const Icon(Icons.person_add_alt),
      label: const Text(AppStrings.add),
    );
  }

  Widget? _friendCardFailure(PublicProfile profile) {
    final inviteFailure = _actionFailure(
      key: 'invite-send-${profile.uid}',
      retryKey: 'friend-action-retry-invite-send-${profile.uid}',
    );
    final removeFailure = _actionFailure(
      key: 'remove-${profile.uid}',
      retryKey: 'friend-action-retry-remove-${profile.uid}',
    );
    final failures = <Widget>[?inviteFailure, ?removeFailure];
    if (failures.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: failures,
    );
  }

  Widget? _actionFailure({required String key, required String retryKey}) {
    final message = _actionFailures[key];
    final retry = _actionRetries[key];
    if (message == null || retry == null) return null;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton.icon(
            key: ValueKey(retryKey),
            onPressed: _pendingActions.contains(key) ? null : retry,
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveFriend(PublicProfile profile) async {
    final uid = ref.read(currentUidProvider);
    final generation = _actionGeneration;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.friendsRemoveConfirmTitle(profile.displayName)),
        content: const Text(AppStrings.removeFriendshipBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            key: ValueKey('friend-remove-confirm-${profile.uid}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.remove),
          ),
        ],
      ),
    );
    if (confirmed == true && _isCurrentAction(generation, uid)) {
      await _removeFriend(profile.uid);
    }
  }

  void _openProfile(String uid) {
    context.push(
      Uri(
        path: '/profile',
        queryParameters: <String, String>{'userId': uid},
      ).toString(),
    );
  }

  void _retryFriendships() {
    ref.read(retryFriendshipSourcesProvider)();
  }

  void _retryInvites(String uid) {
    ref.invalidate(pendingIncomingGelatoInvitesForUidProvider(uid));
    ref.invalidate(pendingIncomingGelatoInvitesProvider);
  }
}

final class _RemotePersonCard extends ConsumerWidget {
  const _RemotePersonCard({
    required this.uid,
    required this.fallbackTitle,
    required this.actions,
    required this.onOpen,
    this.subtitle = AppStrings.profileGelatinoFallback,
    this.failure,
  });

  final String uid;
  final String fallbackTitle;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback onOpen;
  final Widget? failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(publicProfileProvider(uid))
        .when(
          data: (profile) => FriendsPersonCard(
            uid: uid,
            name: profile?.displayName ?? fallbackTitle,
            subtitle: subtitle,
            avatarPath: profile?.avatarPath,
            actions: actions,
            onOpen: onOpen,
            failure: failure,
          ),
          loading: () => const FriendsSkeleton(rows: 1),
          error: (error, stackTrace) => FriendsStatePanel(
            title: AppStrings.profileUnavailable,
            message: AppStrings.friendsPersonLoadError,
            actionLabel: AppStrings.retry,
            onAction: () => ref.invalidate(publicProfileProvider(uid)),
          ),
        );
  }
}
