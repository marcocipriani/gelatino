import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../models/gelato_type.dart';

class GelatoTypeSelector extends StatefulWidget {
  final List<GelatoType> allTypes;
  final List<GelatoType> compactTypes;
  final GelatoType? selected;
  final ValueChanged<GelatoType> onSelected;

  const GelatoTypeSelector({
    super.key,
    required this.allTypes,
    required this.compactTypes,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<GelatoTypeSelector> createState() => _GelatoTypeSelectorState();
}

class _GelatoTypeSelectorState extends State<GelatoTypeSelector> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleTypes = _expanded ? widget.allTypes : widget.compactTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleTypes.map((type) {
              return ChoiceChip(
                label: Text(type.name),
                selected: widget.selected?.id == type.id,
                onSelected: (_) => widget.onSelected(type),
              );
            }).toList(),
          ),
        ),
        if (widget.allTypes.length > widget.compactTypes.length)
          TextButton.icon(
            key: Key(_expanded ? 'gelato-type-collapse' : 'gelato-type-expand'),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _expanded
                  ? AppStrings.checkInShowLessTypes
                  : AppStrings.checkInShowAllTypes,
            ),
          ),
      ],
    );
  }
}
