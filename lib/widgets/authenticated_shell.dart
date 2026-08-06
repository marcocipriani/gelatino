import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../design/responsive.dart';
import '../models/navigation_action.dart';
import '../providers/gelato_invite_providers.dart';
import '../providers/user_provider.dart';
import 'app_page.dart';
import 'avatar_image_provider.dart';
import 'editorial_top_navigation.dart';
import 'floating_bottom_navigation.dart';
import '../constants/app_strings.dart';

class AuthenticatedShell extends ConsumerWidget {
  const AuthenticatedShell({
    required this.location,
    required this.child,
    this.fullBleed = false,
    super.key,
  });

  final String location;
  final Widget child;
  final bool fullBleed;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final responsiveClass = ResponsiveClass.fromWidth(availableWidth);
      final badgeCount = ref.watch(friendsBadgeCountProvider);
      final avatarSource = ref.watch(userProfileProvider).value?.photoUrl;
      final avatar = _ProfileAvatar(source: avatarSource);
      const settings = _SettingsGear();
      final accountActions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          settings,
          const SizedBox(width: AppSpacing.xs),
          avatar,
        ],
      );
      final content = AppPage(fullBleed: fullBleed, child: child);

      if (responsiveClass == ResponsiveClass.wide) {
        return Scaffold(
          body: Column(
            children: [
              EditorialTopNavigation(
                actions: primaryNavigationActions,
                location: location,
                friendsBadgeCount: badgeCount,
                onDestinationSelected: context.go,
                onCheckIn: () => context.push('/check-in'),
                avatar: accountActions,
              ),
              Expanded(child: content),
            ],
          ),
        );
      }

      final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Column(
            children: [
              _CompactHeader(accountActions: accountActions),
              Expanded(child: content),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: FloatingBottomNavigation(
            actions: primaryNavigationActions,
            location: location,
            friendsBadgeCount: badgeCount,
            onDestinationSelected: context.go,
            onCheckIn: () => context.push('/check-in'),
          ),
        ),
      );
    },
  );
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.accountActions});

  final Widget accountActions;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: AppPage(
          child: Row(
            children: [
              Text(
                'Gelatino',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              accountActions,
            ],
          ),
        ),
      ),
    ),
  );
}

class _SettingsGear extends StatefulWidget {
  const _SettingsGear();

  @override
  State<_SettingsGear> createState() => _SettingsGearState();
}

class _SettingsGearState extends State<_SettingsGear> {
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
      key: const ValueKey('settings-gear-shell'),
      button: true,
      label: AppStrings.shellOpenSettings,
      onTap: _openSettings,
      child: ExcludeSemantics(
        child: AppFocusRing(
          key: const ValueKey('settings-gear-focus-ring'),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    void openProfile() => context.push('/profile');

    return Semantics(
      key: const ValueKey('profile-avatar'),
      button: true,
      label: AppStrings.shellOpenProfile,
      onTap: openProfile,
      child: ExcludeSemantics(
        child: AppFocusRing(
          borderRadius: AppRadii.pill,
          child: IconButton(
            tooltip: AppStrings.shellProfileTooltip,
            onPressed: openProfile,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppLayout.touchTarget),
              padding: const EdgeInsets.all(4),
            ),
            icon: AuthenticatedAvatar(source: source, radius: 18, iconSize: 18),
          ),
        ),
      ),
    );
  }
}
