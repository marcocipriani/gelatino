import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../providers/places_discovery_provider.dart';
import '../../constants/app_strings.dart';

final class PlaceActionBar extends StatelessWidget {
  const PlaceActionBar({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final PlacesViewMode mode;
  final ValueChanged<PlacesViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('places-view-toggle'),
      height: AppLayout.touchTarget,
      width: double.infinity,
      child: SegmentedButton<PlacesViewMode>(
        segments: const <ButtonSegment<PlacesViewMode>>[
          ButtonSegment<PlacesViewMode>(
            value: PlacesViewMode.list,
            icon: Icon(Icons.view_list_rounded),
            label: Text(AppStrings.placeActionList),
          ),
          ButtonSegment<PlacesViewMode>(
            value: PlacesViewMode.map,
            icon: Icon(Icons.map_outlined),
            label: Text(AppStrings.placeActionMap),
          ),
        ],
        selected: <PlacesViewMode>{mode},
        onSelectionChanged: (selection) => onChanged(selection.single),
        showSelectedIcon: false,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(AppLayout.touchTarget, AppLayout.touchTarget),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
        ),
      ),
    );
  }
}
