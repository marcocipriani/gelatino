import 'package:flutter/cupertino.dart';

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

final primaryNavigationActions = <NavigationAction>[
  NavigationAction(
    route: '/collection',
    label: AppStrings.navCollection,
    selectedIcon: CupertinoIcons.bookmark_fill,
    unselectedIcon: CupertinoIcons.bookmark,
    semanticLabel: AppStrings.navCollection,
    semanticOrder: 1,
  ),
  NavigationAction(
    route: '/timeline',
    label: AppStrings.navTimeline,
    selectedIcon: CupertinoIcons.square_stack_fill,
    unselectedIcon: CupertinoIcons.square_stack,
    semanticLabel: AppStrings.navTimeline,
    semanticOrder: 2,
  ),
  NavigationAction(
    route: '/places',
    label: AppStrings.navPlaces,
    selectedIcon: CupertinoIcons.map_fill,
    unselectedIcon: CupertinoIcons.map,
    semanticLabel: AppStrings.navPlaces,
    semanticOrder: 3,
  ),
  NavigationAction(
    route: '/friends',
    label: AppStrings.navFriends,
    selectedIcon: CupertinoIcons.person_2_fill,
    unselectedIcon: CupertinoIcons.person_2,
    semanticLabel: AppStrings.navFriends,
    semanticOrder: 4,
  ),
];
