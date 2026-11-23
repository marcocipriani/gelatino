import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../models/navigation_action.dart';
import 'app_page.dart';
import 'floating_bottom_navigation.dart' show NavigationBadge;
import 'melt_pin.dart';
import '../constants/app_strings.dart';

class EditorialTopNavigation extends StatelessWidget {
  const EditorialTopNavigation({
    required this.actions,
    required this.location,
    required this.friendsBadgeCount,
    required this.onDestinationSelected,
    required this.onCheckIn,
    required this.avatar,
    super.key,
  });

  final List<NavigationAction> actions;
  final String location;
  final int friendsBadgeCount;
  final ValueChanged<String> onDestinationSelected;
  final VoidCallback onCheckIn;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          // Landscape phones get this bar too, and have no height to spare.
          height: MediaQuery.sizeOf(context).height < 500 ? 56 : 72,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: AppPage(
              child: Row(
                children: [
                  const MeltPinGlyph(color: AppColors.fragola, height: 28),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Gelatino',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      child: _TopDestination(
                        action: action,
                        selected: action.isSelected(location),
                        badgeCount: action.route == '/friends'
                            ? friendsBadgeCount
                            : 0,
                        onPressed: () => onDestinationSelected(action.route),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  MeltPin(onPressed: onCheckIn),
                  const SizedBox(width: AppSpacing.md),
                  avatar,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopDestination extends StatelessWidget {
  const _TopDestination({
    required this.action,
    required this.selected,
    required this.badgeCount,
    required this.onPressed,
  });

  final NavigationAction action;
  final bool selected;
  final int badgeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = badgeCount > 0
        ? AppStrings.navBadgeSemantic(action.semanticLabel, badgeCount)
        : action.semanticLabel;
    final foreground = selected
        ? Theme.of(context).colorScheme.accentInk
        : Theme.of(context).colorScheme.onSurface;

    return Semantics(
      key: ValueKey('nav-${action.route}'),
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onPressed,
      sortKey: OrdinalSortKey(action.semanticOrder),
      child: ExcludeSemantics(
        child: AppFocusRing(
          key: ValueKey('focus-ring-${action.route}'),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: foreground,
              minimumSize: const Size(
                AppLayout.touchTarget,
                AppLayout.touchTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  action.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    key: const ValueKey('friends-badge'),
                    top: -11,
                    right: -20,
                    child: NavigationBadge(count: badgeCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
