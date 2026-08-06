import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../firebase/firebase_providers.dart';
import '../models/user_profile.dart';
import '../models/user_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_providers.dart';
import '../providers/theme_provider.dart';
import '../services/push_service.dart';
import '../widgets/app_page.dart';
import '../widgets/avatar_image_provider.dart';
import '../widgets/edit_profile_dialog.dart';
import '../constants/app_strings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _boundUid;
  int _generation = 0;
  int _navigationGeneration = 0;
  bool _navigationPending = false;
  bool _isClosing = false;
  final Map<String, int> _fieldVersions = <String, int>{};
  final Set<String> _pendingFields = <String>{};
  final Map<String, Object> _fieldValues = <String, Object>{};
  final Map<String, String> _fieldFailures = <String, String>{};
  final Map<String, Future<void> Function()> _fieldRetries =
      <String, Future<void> Function()>{};

  @override
  void dispose() {
    _generation++;
    _navigationGeneration++;
    super.dispose();
  }

  void _synchronizeUid(String? uid) {
    if (_boundUid == uid) return;
    _boundUid = uid;
    _generation++;
    _fieldVersions.clear();
    _pendingFields.clear();
    _fieldValues.clear();
    _fieldFailures.clear();
    _fieldRetries.clear();
  }

  void _close(BuildContext context) {
    if (_isClosing) return;
    _isClosing = true;
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else if (router != null) {
      router.go('/profile');
    }
  }

  Future<void> _runFieldAction({
    required String field,
    required Object value,
    required Future<void> Function(String uid) operation,
    String failureMessage = AppStrings.settingsEditNotSaved,
    bool terminalOnSuccess = false,
  }) async {
    if (_pendingFields.contains(field)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final generation = _generation;
    final version = (_fieldVersions[field] ?? 0) + 1;
    Future<void> retry() => _runFieldAction(
      field: field,
      value: value,
      operation: operation,
      failureMessage: failureMessage,
      terminalOnSuccess: terminalOnSuccess,
    );
    setState(() {
      _fieldVersions[field] = version;
      _pendingFields.add(field);
      _fieldValues[field] = value;
      _fieldFailures.remove(field);
      _fieldRetries.remove(field);
    });
    try {
      await operation(uid);
      if (!_isCurrentField(generation, uid, field, version)) return;
      setState(() {
        if (!terminalOnSuccess) _pendingFields.remove(field);
        _fieldFailures.remove(field);
        _fieldRetries.remove(field);
      });
    } catch (_) {
      if (!_isCurrentField(generation, uid, field, version)) return;
      setState(() {
        _pendingFields.remove(field);
        _fieldFailures[field] = failureMessage;
        _fieldRetries[field] = retry;
      });
    }
  }

  Future<void> _signOut(String uid) async {
    try {
      await ref.read(pushServiceProvider).clearForSignOut(uid);
    } catch (error) {
      debugPrint('PushService.clearForSignOut failed: $error');
    }
    await ref.read(firebaseAuthProvider).signOut();
  }

  bool _isCurrentField(int generation, String uid, String field, int version) =>
      mounted &&
      generation == _generation &&
      uid == ref.read(currentUidProvider) &&
      _fieldVersions[field] == version;

  Widget? _fieldFailure(String field) {
    final message = _fieldFailures[field];
    final retry = _fieldRetries[field];
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
            key: ValueKey('settings-retry-$field'),
            onPressed: _pendingFields.contains(field) ? null : retry,
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  void _pushOnce(Future<void> Function() navigate) {
    if (_navigationPending) return;
    _navigationPending = true;
    final generation = _navigationGeneration;
    unawaited(() async {
      try {
        await navigate();
      } finally {
        if (mounted && generation == _navigationGeneration) {
          setState(() => _navigationPending = false);
        }
      }
    }());
  }

  void _goOnce(String location) {
    if (_navigationPending) return;
    _navigationPending = true;
    context.go(location);
  }

  Widget _buildSettingsContent(
    AsyncValue<UserSettings?> settings,
    AsyncValue<UserProfile?> profile,
  ) {
    return settings.when(
      data: (value) {
        if (value == null) {
          return const _SettingsStatePanel(
            title: AppStrings.settingsNotFound,
            message: AppStrings.settingsCompleteProfile,
            icon: Icons.settings_outlined,
          );
        }
        final ThemeMode currentTheme =
            (_fieldValues['theme'] as ThemeMode?) ??
            ref.watch(themeModeProvider);
        final defaultView =
            _fieldValues['default-view'] as String? ??
            value.defaultCollectionView;
        final isPrivate =
            _fieldValues['privacy'] as bool? ??
            value.profileVisibility == 'private';
        return _SettingsSections(
          profile: profile,
          themeMode: currentTheme,
          defaultView: defaultView,
          isPrivate: isPrivate,
          themePending: _pendingFields.contains('theme'),
          defaultViewPending: _pendingFields.contains('default-view'),
          privacyPending: _pendingFields.contains('privacy'),
          logoutPending: _pendingFields.contains('logout'),
          themeFailure: _fieldFailure('theme'),
          defaultViewFailure: _fieldFailure('default-view'),
          privacyFailure: _fieldFailure('privacy'),
          logoutFailure: _fieldFailure('logout'),
          onEdit: (owner) => _pushOnce(
            () => showDialog<void>(
              context: context,
              builder: (context) => EditProfileDialog(profile: owner),
            ),
          ),
          onFavoriteFlavors: () =>
              _pushOnce(() async => context.push<void>('/favorite-flavors')),
          onSavedCollection: () => _goOnce('/collection'),
          onThemeChanged: (selection) => _runFieldAction(
            field: 'theme',
            value: selection,
            operation: (_) => ref
                .read(themeModeProvider.notifier)
                .setThemeModeWithFeedback(selection),
          ),
          onDefaultViewChanged: (selection) => _runFieldAction(
            field: 'default-view',
            value: selection,
            operation: (uid) => ref
                .read(profileRepositoryProvider)
                .updateDefaultCollectionView(uid, selection),
          ),
          onPrivacyChanged: (selection) => _runFieldAction(
            field: 'privacy',
            value: selection,
            operation: (uid) => ref
                .read(profileRepositoryProvider)
                .updatePrivacy(uid, isPrivate: selection),
          ),
          onLogout: () => _runFieldAction(
            field: 'logout',
            value: true,
            operation: (uid) => _signOut(uid),
            failureMessage: AppStrings.settingsLogoutFailed,
            terminalOnSuccess: true,
          ),
        );
      },
      loading: () => const _SettingsStatePanel(
        title: AppStrings.settingsLoading,
        message: AppStrings.settingsLoadingPrefs,
        icon: Icons.sync,
      ),
      error: (error, stackTrace) => _SettingsStatePanel(
        title: AppStrings.settingsUnavailable,
        message: AppStrings.settingsLoadError,
        icon: Icons.error_outline,
        actionLabel: AppStrings.retry,
        actionKey: const ValueKey('settings-retry-load'),
        onAction: () => ref.invalidate(ownSettingsProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final uid = ref.watch(currentUidProvider);
      _synchronizeUid(uid);
      final responsive = ResponsiveClass.fromWidth(constraints.maxWidth);
      final settings = ref.watch(ownSettingsProvider);
      final profile = ref.watch(ownProfileProvider);
      final content = _buildSettingsContent(settings, profile);

      if (responsive == ResponsiveClass.wide) {
        return Scaffold(
          key: const ValueKey('settings-wide'),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _close(context),
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
                  ExcludeSemantics(
                    key: const ValueKey('settings-wide-background'),
                    child: IgnorePointer(child: _OwnerProfileContext()),
                  ),
                  ModalBarrier(
                    key: const ValueKey('settings-wide-barrier'),
                    dismissible: true,
                    onDismiss: () => _close(context),
                    semanticsLabel: AppStrings.settingsCloseTooltip,
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.42),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      key: const ValueKey('settings-wide-drawer'),
                      elevation: AppElevation.overlay,
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        width: 420,
                        height: double.infinity,
                        child: SafeArea(
                          child: _SettingsSurface(
                            onClose: () => _close(context),
                            closeKey: const ValueKey('settings-close'),
                            content: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        key: ValueKey('settings-${responsive.name}'),
        body: SafeArea(
          child: AppPage(
            child: _SettingsSurface(
              onClose: () => _close(context),
              closeKey: const ValueKey('settings-back'),
              content: content,
            ),
          ),
        ),
      );
    },
  );
}

final class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.onClose,
    required this.closeKey,
    required this.content,
  });

  final VoidCallback onClose;
  final Key closeKey;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                key: closeKey,
                tooltip: AppStrings.back,
                onPressed: onClose,
                style: IconButton.styleFrom(minimumSize: const Size.square(48)),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.settingsTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: content,
          ),
        ),
      ],
    );
  }
}

final class _SettingsSections extends StatelessWidget {
  const _SettingsSections({
    required this.profile,
    required this.themeMode,
    required this.defaultView,
    required this.isPrivate,
    required this.themePending,
    required this.defaultViewPending,
    required this.privacyPending,
    required this.logoutPending,
    required this.themeFailure,
    required this.defaultViewFailure,
    required this.privacyFailure,
    required this.logoutFailure,
    required this.onEdit,
    required this.onFavoriteFlavors,
    required this.onSavedCollection,
    required this.onThemeChanged,
    required this.onDefaultViewChanged,
    required this.onPrivacyChanged,
    required this.onLogout,
  });

  final AsyncValue<UserProfile?> profile;
  final ThemeMode themeMode;
  final String defaultView;
  final bool isPrivate;
  final bool themePending;
  final bool defaultViewPending;
  final bool privacyPending;
  final bool logoutPending;
  final Widget? themeFailure;
  final Widget? defaultViewFailure;
  final Widget? privacyFailure;
  final Widget? logoutFailure;
  final ValueChanged<UserProfile> onEdit;
  final VoidCallback onFavoriteFlavors;
  final VoidCallback onSavedCollection;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onDefaultViewChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final UserProfile? owner;
    final String editSubtitle;
    if (profile.isLoading) {
      owner = null;
      editSubtitle = AppStrings.settingsProfileLoading;
    } else if (profile.hasError) {
      owner = null;
      editSubtitle = AppStrings.profileUnavailable;
    } else {
      owner = switch (profile) {
        AsyncData(:final value) => value,
        _ => null,
      };
      editSubtitle = owner?.displayName ?? AppStrings.profileNotFound;
    }
    final normalizedDefaultView = defaultView == 'map' ? 'map' : 'list';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSection(
          label: AppStrings.settingsSectionProfile,
          children: [
            ListTile(
              key: const ValueKey('settings-edit-profile'),
              leading: const Icon(Icons.person_outline),
              title: const Text(AppStrings.settingsEditPersonal),
              subtitle: Text(editSubtitle),
              trailing: const Icon(Icons.chevron_right),
              enabled: owner != null,
              onTap: switch (owner) {
                final value? => () => onEdit(value),
                null => null,
              },
            ),
            ListTile(
              key: const ValueKey('settings-favorite-flavors'),
              leading: const Icon(Icons.favorite_outline),
              title: const Text(AppStrings.settingsFavoriteFlavors),
              trailing: const Icon(Icons.chevron_right),
              onTap: onFavoriteFlavors,
            ),
            ListTile(
              key: const ValueKey('settings-saved-collection'),
              leading: const Icon(Icons.bookmark_outline),
              title: const Text(AppStrings.settingsSavedPlaces),
              trailing: const Icon(Icons.chevron_right),
              onTap: onSavedCollection,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingsSection(
          label: AppStrings.settingsSectionApp,
          children: [
            ListTile(
              title: const Text(AppStrings.settingsTheme),
              subtitle: const Text(AppStrings.settingsThemeSubtitle),
              trailing: SizedBox(
                width: 148,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ThemeMode>(
                    key: const ValueKey('settings-theme'),
                    value: themeMode,
                    isExpanded: true,
                    onChanged: themePending
                        ? null
                        : (value) {
                            if (value != null) onThemeChanged(value);
                          },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(AppStrings.settingsThemeAuto),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(AppStrings.settingsThemeLight),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(AppStrings.settingsThemeDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (themeFailure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: themeFailure,
              ),
            ListTile(
              title: const Text(AppStrings.settingsDefaultPlacesView),
              subtitle: const Text(AppStrings.settingsDefaultPlacesViewSubtitle),
              trailing: SizedBox(
                width: 116,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const ValueKey('settings-default-view'),
                    value: normalizedDefaultView,
                    isExpanded: true,
                    onChanged: defaultViewPending
                        ? null
                        : (value) {
                            if (value != null) onDefaultViewChanged(value);
                          },
                    items: const [
                      DropdownMenuItem(value: 'list', child: Text(AppStrings.settingsPlacesViewList)),
                      DropdownMenuItem(value: 'map', child: Text(AppStrings.settingsPlacesViewMap)),
                    ],
                  ),
                ),
              ),
            ),
            if (defaultViewFailure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: defaultViewFailure,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingsSection(
          label: AppStrings.settingsSectionPrivacy,
          children: [
            SwitchListTile(
              key: const ValueKey('settings-private-profile'),
              value: isPrivate,
              onChanged: privacyPending ? null : onPrivacyChanged,
              title: const Text(AppStrings.settingsPrivateProfile),
              subtitle: const Text(
                AppStrings.settingsPrivateProfileSubtitle,
              ),
              secondary: const Icon(Icons.lock_outline),
            ),
            if (privacyFailure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: privacyFailure,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SettingsSection(
          label: AppStrings.settingsSectionAccount,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                key: const ValueKey('settings-logout'),
                onPressed: logoutPending ? null : onLogout,
                icon: const Icon(Icons.logout),
                label: const Text(AppStrings.logout),
              ),
            ),
            if (logoutFailure != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: logoutFailure,
              ),
          ],
        ),
      ],
    );
  }
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      const SizedBox(height: AppSpacing.xs),
      Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

final class _SettingsStatePanel extends StatelessWidget {
  const _SettingsStatePanel({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: AppLayout.readableText),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(message),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: actionKey,
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

final class _OwnerProfileContext extends ConsumerWidget {
  const _OwnerProfileContext();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: AppPage(
          child: Center(
            child: profile.when(
              data: (value) => value == null
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AuthenticatedAvatar(source: value.photoUrl, radius: 48),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          value.displayName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(AppStrings.settingsPoints(value.points)),
                      ],
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
