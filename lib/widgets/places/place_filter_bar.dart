import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../providers/places_discovery_provider.dart';
import '../../constants/app_strings.dart';
import 'place_marker.dart';

final class PlaceFilterBar extends StatelessWidget {
  const PlaceFilterBar({
    required this.selected,
    required this.authenticated,
    required this.onSelected,
    required this.onPrivateFilterRequiresLogin,
    super.key,
  });

  final PlacesFilter selected;
  final bool authenticated;
  final ValueChanged<PlacesFilter> onSelected;
  final VoidCallback onPrivateFilterRequiresLogin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('places-filter-scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final filter in PlacesFilter.values) ...<Widget>[
            Semantics(
              key: ValueKey<String>('filter-${filter.name}'),
              button: true,
              selected: selected == filter,
              label: AppStrings.placeFilterLabel(filter.label),
              // Height follows the label, so larger type never clips.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: ChoiceChip(
                  // Same glyph as the pin: the filters double as a map legend.
                  avatar: switch (_variantOf(filter)) {
                    final variant? => PlaceStateBadge(variant: variant),
                    null => null,
                  },
                  label: Text(filter.label),
                  selected: selected == filter,
                  showCheckmark: false,
                  onSelected: (_) {
                    if (filter != PlacesFilter.all && !authenticated) {
                      onPrivateFilterRequiresLogin();
                      return;
                    }
                    onSelected(filter);
                  },
                ),
              ),
            ),
            if (filter != PlacesFilter.values.last)
              const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

PlaceMarkerVariant? _variantOf(PlacesFilter filter) => switch (filter) {
  PlacesFilter.all => null,
  PlacesFilter.liked => PlaceMarkerVariant.liked,
  PlacesFilter.favorites => PlaceMarkerVariant.favorite,
  PlacesFilter.saved => PlaceMarkerVariant.saved,
  PlacesFilter.addedByMe => PlaceMarkerVariant.userAdded,
};
