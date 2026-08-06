import 'package:flutter/material.dart';

import '../constants/app_strings.dart';

@immutable
final class NavigationAction {
  const NavigationAction({
    required this.route,
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.semanticLabel,
    required this.semanticOrder,
  });

  final String route;
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final String semanticLabel;
  final double semanticOrder;

  bool isSelected(String location) => location == route;
}

const primaryNavigationActions = <NavigationAction>[
  NavigationAction(
    route: '/collection',
    label: AppStrings.navCollection,
    selectedIcon: Icons.bookmark_rounded,
    unselectedIcon: Icons.bookmark_outline_rounded,
    semanticLabel: AppStrings.navCollection,
    semanticOrder: 1,
  ),
  NavigationAction(
    route: '/timeline',
    label: AppStrings.navTimeline,
    selectedIcon: Icons.auto_stories_rounded,
    unselectedIcon: Icons.auto_stories_outlined,
    semanticLabel: AppStrings.navTimeline,
    semanticOrder: 2,
  ),
  NavigationAction(
    route: '/places',
    label: AppStrings.navPlaces,
    selectedIcon: Icons.storefront_rounded,
    unselectedIcon: Icons.storefront_outlined,
    semanticLabel: AppStrings.navPlaces,
    semanticOrder: 3,
  ),
  NavigationAction(
    route: '/friends',
    label: AppStrings.navFriends,
    selectedIcon: Icons.people_alt_rounded,
    unselectedIcon: Icons.people_alt_outlined,
    semanticLabel: AppStrings.navFriends,
    semanticOrder: 4,
  ),
];
