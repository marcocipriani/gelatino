import 'package:flutter/material.dart';

import '../../models/flavor.dart';
import '../../models/gelato_type.dart';
import '../../widgets/flavors_manager.dart';
import '../../widgets/gelato_type_selector.dart';
import '../../constants/app_strings.dart';

final class GelatoStep extends StatelessWidget {
  const GelatoStep({
    required this.types,
    required this.flavors,
    required this.selectedTypeId,
    required this.selectedFlavorIds,
    required this.catalogWarning,
    required this.flavorsLoading,
    required this.flavorsFailure,
    required this.enabled,
    required this.onTypeSelected,
    required this.onFlavorsChanged,
    required this.onCreateFlavor,
    required this.onFlavorLimit,
    super.key,
  });

  final List<GelatoType> types;
  final List<Flavor> flavors;
  final String? selectedTypeId;
  final List<String> selectedFlavorIds;
  final String? catalogWarning;
  final bool flavorsLoading;
  final String? flavorsFailure;
  final bool enabled;
  final ValueChanged<GelatoType> onTypeSelected;
  final ValueChanged<List<String>> onFlavorsChanged;
  final Future<Flavor> Function(String name) onCreateFlavor;
  final VoidCallback onFlavorLimit;

  @override
  Widget build(BuildContext context) {
    final selected = types
        .where((type) => type.id == selectedTypeId)
        .firstOrNull;
    final compact = types.take(4).toList();
    if (selected != null && !compact.any((type) => type.id == selected.id)) {
      if (compact.length == 4) compact.removeLast();
      compact.add(selected);
    }
    return Column(
      key: const ValueKey<String>('check-in-page-2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.checkInGelatoStepTitle,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        IgnorePointer(
          ignoring: !enabled,
          child: GelatoTypeSelector(
            allTypes: types,
            compactTypes: compact,
            selected: selected,
            onSelected: onTypeSelected,
          ),
        ),
        if (catalogWarning != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(catalogWarning!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 20),
        if (flavorsLoading) ...<Widget>[
          const LinearProgressIndicator(),
          if (flavors.isNotEmpty) const SizedBox(height: 10),
        ],
        if (flavorsFailure != null) ...<Widget>[
          Text(
            flavorsFailure!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 10),
        ],
        if (!flavorsLoading || flavors.isNotEmpty)
          FlavorSelectionField(
            flavors: flavors,
            selectedIds: selectedFlavorIds,
            enabled: enabled,
            onChanged: onFlavorsChanged,
            onCreate: onCreateFlavor,
            onLimitReached: onFlavorLimit,
          ),
      ],
    );
  }
}
