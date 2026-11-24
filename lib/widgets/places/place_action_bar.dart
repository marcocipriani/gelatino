import 'package:flutter/cupertino.dart';

import '../../providers/places_discovery_provider.dart';
import '../../constants/app_strings.dart';
import '../app_controls.dart';

final class PlaceActionBar extends StatelessWidget {
  const PlaceActionBar({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final PlacesViewMode mode;
  final ValueChanged<PlacesViewMode> onChanged;

  @override
  Widget build(BuildContext context) => AppSegmented<PlacesViewMode>(
    key: const ValueKey<String>('places-view-toggle'),
    value: mode,
    onChanged: onChanged,
    segments: {
      PlacesViewMode.list: AppStrings.placeActionList,
      PlacesViewMode.map: AppStrings.placeActionMap,
    },
    icons: const {
      PlacesViewMode.list: CupertinoIcons.list_bullet,
      PlacesViewMode.map: CupertinoIcons.map_fill,
    },
  );
}
