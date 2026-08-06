import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../providers/places_discovery_provider.dart';
import '../../constants/app_strings.dart';

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
              child: SizedBox(
                height: AppLayout.touchTarget,
                child: ChoiceChip(
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
