import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../models/navigation_action.dart';
import 'melt_pin.dart';
import '../constants/app_strings.dart';

class FloatingBottomNavigation extends StatelessWidget {
  const FloatingBottomNavigation({
    required this.actions,
    required this.location,
    required this.friendsBadgeCount,
    required this.onDestinationSelected,
    required this.onCheckIn,
    super.key,
  });

  final List<NavigationAction> actions;
  final String location;
  final int friendsBadgeCount;
  final ValueChanged<String> onDestinationSelected;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    assert(actions.length == 4);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                key: const ValueKey('bottom-nav-surface'),
                elevation: AppElevation.overlay,
                color: Theme.of(context).colorScheme.surface,
                shadowColor: Theme.of(context).shadowColor,
                borderRadius: BorderRadius.circular(AppRadii.hero),
                clipBehavior: Clip.none,
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      _BottomDestination(
                        action: actions[0],
                        selected: actions[0].isSelected(location),
                        badgeCount: 0,
                        onPressed: () =>
                            onDestinationSelected(actions[0].route),
                      ),
                      _BottomDestination(
                        action: actions[1],
                        selected: actions[1].isSelected(location),
                        badgeCount: 0,
                        onPressed: () =>
                            onDestinationSelected(actions[1].route),
                      ),
                      const Expanded(child: SizedBox()),
                      _BottomDestination(
                        action: actions[2],
                        selected: actions[2].isSelected(location),
                        badgeCount: 0,
                        onPressed: () =>
                            onDestinationSelected(actions[2].route),
                      ),
                      _BottomDestination(
                        action: actions[3],
                        selected: actions[3].isSelected(location),
                        badgeCount: friendsBadgeCount,
                        onPressed: () =>
                            onDestinationSelected(actions[3].route),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: MeltPin(onPressed: onCheckIn, compact: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomDestination extends StatelessWidget {
  const _BottomDestination({
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
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        key: ValueKey('nav-${action.route}'),
        button: true,
        selected: selected,
        label: semanticLabel,
        onTap: onPressed,
        sortKey: OrdinalSortKey(action.semanticOrder),
        child: ExcludeSemantics(
          child: AppFocusRing(
            key: ValueKey('focus-ring-${action.route}'),
            borderRadius: AppRadii.control,
            child: InkWell(
              onTap: onPressed,
              canRequestFocus: true,
              focusColor: Theme.of(context).focusColor,
              hoverColor: Theme.of(context).hoverColor,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppLayout.touchTarget,
                  minHeight: AppLayout.touchTarget,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected
                              ? action.selectedIcon
                              : action.unselectedIcon,
                          color: color,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        key: const ValueKey('friends-badge'),
                        top: 6,
                        right: 8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.fragola,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: AppColors.fondente,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
