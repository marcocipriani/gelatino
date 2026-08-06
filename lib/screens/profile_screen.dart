import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/check_in_providers.dart';
import '../providers/profile_providers.dart';
import '../providers/timeline_providers.dart';
import '../providers/flavors_provider.dart';
import '../providers/place_providers.dart';
import '../repositories/check_in_repository.dart';
import '../models/user_profile.dart';
import '../models/profile_view_data.dart';
import '../models/feed_item.dart';
import '../models/flavor.dart';
import '../models/place.dart';
import '../models/public_profile.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/bounce_button.dart';
import '../widgets/avatar_image_provider.dart';
import '../utils/error_handler.dart';
import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../widgets/app_page.dart';
import '../widgets/editorial_header.dart';
import 'profile/profile_a1_layout.dart';
import 'profile/profile_relationship_action.dart';
import '../constants/app_strings.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final requestedUid = userId ?? user?.uid;
    final isOwnProfile = requestedUid != null && requestedUid == user?.uid;

    if (user == null || requestedUid == null) {
      return const Scaffold(
        body: SafeArea(child: AppPage(child: ProfileA1Skeleton())),
      );
    }

    final AsyncValue<ProfileViewData?> profile = isOwnProfile
        ? ref
              .watch(ownProfileProvider)
              .whenData<ProfileViewData?>((value) => value)
        : ref
              .watch(publicProfileProvider(requestedUid))
              .whenData<ProfileViewData?>((value) => value);
    return Scaffold(
      body: SafeArea(
        child: AppPage(
          child: profile.when(
            data: (value) {
              if (value == null) {
                return const Center(
                  child: ProfileStatePanel(
                    title: AppStrings.profileNotFound,
                    message: AppStrings.profileNotAvailableMessage,
                    icon: Icons.person_off_outlined,
                  ),
                );
              }
              final history = ref.watch(authorizedHistoryProvider(value.uid));
              return ListView(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.display,
                ),
                children: [
                  ProfileA1Layout(
                    identity: _ProfileIdentity(
                      profile: value,
                      user: user,
                      isOwnProfile: isOwnProfile,
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfilePreferences(profile: value),
                        const SizedBox(height: AppSpacing.lg),
                        _ProfileActivity(
                          historyUid: value.uid,
                          history: history,
                          canDelete: isOwnProfile,
                          onRetry: ref.read(
                            authorizedHistoryRefreshProvider(value.uid),
                          ),
                        ),
                        if (isOwnProfile) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const _OwnerSavedPlaces(),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const ProfileA1Skeleton(),
            error: (error, stackTrace) => Center(
              child: ProfileStatePanel(
                title: AppStrings.profileUnavailable,
                message: AppStrings.profileLoadError,
                actionLabel: AppStrings.retry,
                actionKey: ValueKey('profile-retry-$requestedUid'),
                onAction: () {
                  if (isOwnProfile) {
                    ref.invalidate(ownProfileProvider);
                  } else {
                    ref.invalidate(publicProfileProvider(requestedUid));
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.profile,
    required this.user,
    required this.isOwnProfile,
  });

  final ProfileViewData profile;
  final User user;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bio = switch (profile) {
      PublicProfile(:final bio) => bio,
      UserProfile(:final bio) => bio,
      _ => '',
    };
    final city = switch (profile) {
      PublicProfile(:final city) => city,
      UserProfile(:final city) => city,
      _ => '',
    };
    return ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOwnProfile) ...[
                IconButton(
                  key: const ValueKey('profile-back'),
                  tooltip: AppStrings.back,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/friends');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              AuthenticatedAvatar(source: profile.photoUrl, radius: 38),
              if (isOwnProfile) ...[
                const Spacer(),
                const _ProfileSettingsGear(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          EditorialHeader(
            eyebrow: isOwnProfile ? AppStrings.profileHeaderLabel : 'PROFILO',
            title: profile.displayName,
            description: bio.isEmpty ? null : bio,
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              city,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.settingsPoints(profile.points),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (!isOwnProfile) ...[
            const SizedBox(height: AppSpacing.lg),
            ProfileRelationshipAction(targetUid: profile.uid),
          ],
          if (isOwnProfile) ...[
            if (user.email case final email?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(email, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (profile case final UserProfile ownProfile)
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) =>
                          EditProfileDialog(profile: ownProfile),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(AppStrings.profileEditButton),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final class _ProfileSettingsGear extends StatefulWidget {
  const _ProfileSettingsGear();

  @override
  State<_ProfileSettingsGear> createState() => _ProfileSettingsGearState();
}

final class _ProfileSettingsGearState extends State<_ProfileSettingsGear> {
  int _generation = 0;
  bool _pending = false;

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  void _openSettings() {
    if (_pending) return;
    _pending = true;
    final generation = _generation;
    unawaited(() async {
      try {
        await context.push<void>('/settings');
      } finally {
        if (mounted && generation == _generation) _pending = false;
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('profile-settings-gear'),
      button: true,
      label: AppStrings.profileOpenSettings,
      onTap: _openSettings,
      child: ExcludeSemantics(
        child: AppFocusRing(
          key: const ValueKey('profile-settings-focus-ring'),
          borderRadius: AppRadii.pill,
          child: IconButton(
            tooltip: AppStrings.shellSettingsTooltip,
            onPressed: _openSettings,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              padding: const EdgeInsets.all(4),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
      ),
    );
  }
}

final class _ProfilePreferences extends ConsumerWidget {
  const _ProfilePreferences({required this.profile});

  final ProfileViewData profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavorIds = switch (profile) {
      PublicProfile(:final favoriteFlavorIds) => favoriteFlavorIds,
      UserProfile(:final favoriteFlavorIds) => favoriteFlavorIds,
      _ => const <String>[],
    };
    final placeId = switch (profile) {
      PublicProfile(:final favoritePlaceId) => favoritePlaceId,
      UserProfile(:final favoritePlaceId) => favoritePlaceId,
      _ => null,
    };
    if (flavorIds.isEmpty && placeId == null) {
      return const ProfileStatePanel(
        title: AppStrings.profilePreferencesTitle,
        message: AppStrings.profilePrefsNonePublic,
        icon: Icons.favorite_outline,
      );
    }

    final flavors = ref.watch(flavorsProvider);
    final places = ref.watch(placesProvider);
    if (flavors.hasError || places.hasError) {
      return const ProfileStatePanel(
        title: AppStrings.profilePreferencesUnavailable,
        message: AppStrings.profilePrefsNamesUnavailable,
        icon: Icons.favorite_border,
      );
    }
    if (flavors.isLoading || places.isLoading) {
      return const ProfileA1Skeleton();
    }
    final loadedFlavors = switch (flavors) {
      AsyncData(:final value) => value,
      _ => const <Flavor>[],
    };
    final loadedPlaces = switch (places) {
      AsyncData(:final value) => value,
      _ => const <Place>[],
    };
    final flavorNames = loadedFlavors
        .where((flavor) => flavorIds.contains(flavor.id))
        .map((flavor) => flavor.name)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final placeName = loadedPlaces
        .where((place) => place.id == placeId)
        .map((place) => place.name)
        .firstOrNull;
    if (flavorNames.isEmpty && placeName == null) {
      return const ProfileStatePanel(
        title: AppStrings.profilePreferencesUpdating,
        message: AppStrings.profilePrefsNamesPending,
        icon: Icons.sync,
      );
    }
    return ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.profilePreferencesTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final name in flavorNames)
                Chip(
                  avatar: const Icon(Icons.icecream_outlined, size: 18),
                  label: Text(name),
                ),
              if (placeName != null)
                Chip(
                  avatar: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(placeName),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ProfileActivity extends StatelessWidget {
  const _ProfileActivity({
    required this.historyUid,
    required this.history,
    required this.canDelete,
    required this.onRetry,
  });

  final String historyUid;
  final AsyncValue<List<FeedItem>> history;
  final bool canDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return history.when(
      data: (items) {
        final uniquePlaces = items.map((item) => item.placeId).toSet().length;
        final average = items.isEmpty
            ? null
            : items.fold<double>(0, (sum, item) => sum + item.rating) /
                  items.length;
        return ProfilePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.profileRecentActivity,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Chip(label: Text(AppStrings.profileGelatiCount(items.length))),
                  Chip(label: Text(AppStrings.profilePlacesCount(uniquePlaces))),
                  if (average != null)
                    Chip(label: Text(AppStrings.profileAverage(average.toStringAsFixed(1)))),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ProfileRecentActivityList(
                historyUid: historyUid,
                items: items,
                canDelete: canDelete,
              ),
            ],
          ),
        );
      },
      loading: () => const ProfileA1Skeleton(),
      error: (error, stackTrace) => ProfileStatePanel(
        title: AppStrings.profileActivityUnavailable,
        message: AppStrings.profileCheckInsLoadError,
        actionLabel: AppStrings.retry,
        actionKey: ValueKey('profile-history-retry-$historyUid'),
        onAction: onRetry,
      ),
    );
  }
}

final class _OwnerSavedPlaces extends ConsumerWidget {
  const _OwnerSavedPlaces();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedPlaces = ref.watch(savedPlacesProvider);
    return ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.profileWishlistTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.profileSavedPlacesSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          savedPlaces.when(
            data: (places) => places.isEmpty
                ? const Text(AppStrings.profileWishlistEmpty)
                : Column(
                    children: [
                      for (final place in places)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(place.name),
                          subtitle: Text(place.address),
                          trailing: ProfileSavedPlaceRemoveButton(
                            placeId: place.id,
                          ),
                        ),
                    ],
                  ),
            loading: () => const ProfileA1Skeleton(),
            error: (error, stackTrace) => ProfileStatePanel(
              title: AppStrings.profileWishlistUnavailable,
              message: AppStrings.profileSavedPlacesLoadError,
              actionLabel: AppStrings.retry,
              onAction: () => ref.invalidate(savedPlacesProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('profile-open-wishlist'),
                onPressed: () => context.push('/wishlist'),
                icon: const Icon(Icons.bookmarks_outlined),
                label: const Text(AppStrings.profileSeeAll),
              ),
              OutlinedButton.icon(
                key: const ValueKey('profile-open-favorite-flavors'),
                onPressed: () => context.push('/favorite-flavors'),
                icon: const Icon(Icons.favorite_border),
                label: const Text(AppStrings.profileManageFlavors),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileRecentActivityList extends ConsumerStatefulWidget {
  const ProfileRecentActivityList({
    super.key,
    required this.historyUid,
    required this.items,
    required this.canDelete,
  });

  final String historyUid;
  final List<FeedItem> items;
  final bool canDelete;

  @override
  ConsumerState<ProfileRecentActivityList> createState() =>
      _ProfileRecentActivityListState();
}

class _ProfileRecentActivityListState
    extends ConsumerState<ProfileRecentActivityList> {
  final Set<String> _deleted = <String>{};
  final Set<String> _pending = <String>{};
  final Map<String, String> _failures = <String, String>{};
  int _generation = 0;

  @override
  void didUpdateWidget(covariant ProfileRecentActivityList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.historyUid != widget.historyUid ||
        oldWidget.canDelete != widget.canDelete) {
      _generation++;
      _deleted.clear();
      _pending.clear();
      _failures.clear();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((item) => !_deleted.contains(item.checkInId))
        .take(5)
        .toList(growable: false);
    if (items.isEmpty) {
      return const Text(AppStrings.profileNoCheckInsPage);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.profileCheckInsPageLabel,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final item in items) _item(context, item),
      ],
    );
  }

  Widget _item(BuildContext context, FeedItem item) {
    final id = item.checkInId;
    final isPending = _pending.contains(id);
    final failure = _failures[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.icecream_outlined),
          title: Text(item.placeSnapshot['name'] as String),
          subtitle: Text(
            '${item.createdAt.day.toString().padLeft(2, '0')}/'
            '${item.createdAt.month.toString().padLeft(2, '0')}/'
            '${item.createdAt.year}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.profileRatingOutOf(item.rating)),
              if (widget.canDelete) ...[
                const SizedBox(width: 8),
                if (isPending)
                  SizedBox.square(
                    key: ValueKey<String>('profile-delete-pending-$id'),
                    dimension: 20,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    key: ValueKey<String>('profile-delete-$id'),
                    tooltip: AppStrings.profileDeleteCheckInTooltip,
                    onPressed: () => _confirmDelete(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ],
          ),
        ),
        if (failure != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  failure,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                key: ValueKey<String>('profile-delete-retry-$id'),
                onPressed: isPending ? null : () => _delete(item),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmDelete(FeedItem item) async {
    final generation = _generation;
    final historyUid = widget.historyUid;
    final canDelete = widget.canDelete;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.profileDeleteCheckInTitle),
        content: const Text(AppStrings.profileDeleteCheckInBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        _isCurrentBinding(generation, historyUid, canDelete)) {
      await _delete(item);
    }
  }

  Future<void> _delete(FeedItem item) async {
    final id = item.checkInId;
    final generation = _generation;
    final historyUid = widget.historyUid;
    final canDelete = widget.canDelete;
    if (!canDelete || _pending.contains(id)) return;
    setState(() {
      _pending.add(id);
      _failures.remove(id);
    });
    try {
      await ref.read(checkInRepositoryProvider).delete(id);
      if (!_isCurrentBinding(generation, historyUid, canDelete)) return;
      ref.read(authorizedHistoryRefreshProvider(historyUid))();
      setState(() {
        _pending.remove(id);
        _deleted.add(id);
      });
    } on CheckInFailure catch (error) {
      if (!_isCurrentBinding(generation, historyUid, canDelete)) return;
      setState(() {
        _pending.remove(id);
        _failures[id] = error.message;
      });
    } catch (_) {
      if (!_isCurrentBinding(generation, historyUid, canDelete)) return;
      setState(() {
        _pending.remove(id);
        _failures[id] = AppStrings.profileDeleteCheckInError;
      });
    }
  }

  bool _isCurrentBinding(int generation, String historyUid, bool canDelete) =>
      mounted &&
      generation == _generation &&
      historyUid == widget.historyUid &&
      canDelete == widget.canDelete;
}

class ProfileSavedPlaceRemoveButton extends ConsumerWidget {
  const ProfileSavedPlaceRemoveButton({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(placeStateProvider(placeId));
    final current = stateAsync.value;
    final canRemove = current?.saved == true;

    return Tooltip(
      message: AppStrings.profileRemoveFromWishlist,
      child: IgnorePointer(
        ignoring: !canRemove,
        child: Opacity(
          opacity: canRemove ? 1 : 0.45,
          child: BounceButton(
            key: ValueKey<String>('profile-remove-$placeId'),
            onTap: () async {
              if (!canRemove) return;
              try {
                await ref
                    .read(placeStateControllerProvider.notifier)
                    .toggleSaved(placeId, current: current);
              } on PlaceStateFailure catch (error) {
                if (context.mounted) {
                  ErrorHandler.showErrorSnackBar(context, error);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEA00).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFEA00).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: Color(0xFFFFEA00),
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
