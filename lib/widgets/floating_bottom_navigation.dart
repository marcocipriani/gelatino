import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../design/motion.dart';
import '../models/navigation_action.dart';
import 'melt_pin.dart';
import '../constants/app_strings.dart';

/// Docked, opaque tab bar with the Melt Pin check-in action in the middle.
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

  static const _barHeight = 64.0;
  static const _pinLift = 6.0;

  @override
  Widget build(BuildContext context) {
    assert(actions.length == 4);
    final theme = Theme.of(context);

    Widget destination(int index) => _BottomDestination(
      action: actions[index],
      selected: actions[index].isSelected(location),
      badgeCount: index == 3 ? friendsBadgeCount : 0,
      onPressed: () {
        HapticFeedback.selectionClick();
        onDestinationSelected(actions[index].route);
      },
    );

    // The bar paints down through the home-indicator area; its controls don't.
    return Stack(
      children: [
        Positioned.fill(
          top: _pinLift,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
          ),
        ),
        SafeArea(
          top: false,
          // iOS caps tab-bar type too; past this, labels stop fitting a tab.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: MediaQuery.sizeOf(context).width < 360 ? 1.0 : 1.2,
            child: SizedBox(
              height: _barHeight + _pinLift,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: _pinLift,
                    child: Material(
                      key: const ValueKey('bottom-nav-surface'),
                      type: MaterialType.transparency,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          destination(0),
                          destination(1),
                          // Just the pin's width: "Collezione" needs the rest
                          // to stay 12pt on a 320pt phone.
                          const SizedBox(width: 58),
                          destination(2),
                          destination(3),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: MeltPin(onPressed: onCheckIn, compact: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = selected ? colors.accentInk : colors.onSurfaceVariant;
    final duration = AppMotion.of(context, AppMotion.standard);

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
              focusColor: theme.focusColor,
              hoverColor: theme.hoverColor,
              child: SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: duration,
                          curve: AppMotion.glide,
                          width: selected ? 48 : 36,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.primaryContainer
                                : colors.primaryContainer.withValues(alpha: 0),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: AnimatedSwitcher(
                            duration: duration,
                            child: Icon(
                              selected
                                  ? action.selectedIcon
                                  : action.unselectedIcon,
                              key: ValueKey(selected),
                              color: color,
                              size: 23,
                            ),
                          ),
                        ),
                        if (badgeCount > 0)
                          PositionedDirectional(
                            key: const ValueKey('friends-badge'),
                            top: -6,
                            end: -8,
                            child: NavigationBadge(count: badgeCount),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontSize: 12.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
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

class NavigationBadge extends StatelessWidget {
  const NavigationBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.fragola,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(
        color: AppColors.fondente,
        fontSize: 12,
        height: 1.15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
