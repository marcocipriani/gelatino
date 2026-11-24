import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../design/motion.dart';
import '../../models/place.dart';
import '../../utils/search_text.dart';
import '../../widgets/app_search_field.dart';

/// Opens a searchable sheet: a menu of 300 gelaterie can't be used.
class PlacePickerField extends StatelessWidget {
  const PlacePickerField({
    required this.places,
    required this.initialValue,
    required this.selectedLabel,
    required this.newPlaceValue,
    required this.onChanged,
    super.key,
  });

  final List<Place> places;
  final String? initialValue;
  final String? selectedLabel;
  final String newPlaceValue;
  final ValueChanged<String>? onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: AppMotion.reduced(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => _PlacePickerSheet(
        places: places,
        selectedId: initialValue,
        newPlaceValue: newPlaceValue,
      ),
    );
    if (picked != null && picked != initialValue) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.control),
        onTap: enabled ? () => _open(context) : null,
        child: InputDecorator(
          decoration: InputDecoration(
            enabled: enabled,
            labelText: AppStrings.checkInPlaceFieldLabel,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: const Icon(CupertinoIcons.search, size: 20),
          ),
          child: Text(
            selectedLabel ?? AppStrings.checkInPickPlace,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selectedLabel == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet({
    required this.places,
    required this.selectedId,
    required this.newPlaceValue,
  });

  final List<Place> places;
  final String? selectedId;
  final String newPlaceValue;

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _search = TextEditingController();
  late List<Place> _results = widget.places;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String raw) {
    final query = normalizeSearchText(raw);
    final byRank = List.generate(5, (_) => <Place>[]);
    for (final place in widget.places) {
      final rank = searchRank(
        query,
        name: normalizeSearchText(place.name),
        detail: normalizeSearchText(place.address),
      );
      if (rank != null) byRank[rank].add(place);
    }
    setState(() => _results = [for (final places in byRank) ...places]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        // Material, so row highlights paint above the sheet.
        child: Material(
          type: MaterialType.transparency,
          // One scroll view, so large type and keyboard can't overflow a header.
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList.list(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        AppStrings.checkInPickPlace,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppSearchField(
                      fieldKey: const ValueKey('check-in-place-search'),
                      controller: _search,
                      hint: AppStrings.checkInPlaceSearchHint,
                      onChanged: _filter,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      iconColor: colors.accentInk,
                      textColor: colors.accentInk,
                      leading: const Icon(CupertinoIcons.plus_circle_fill),
                      title: Text(AppStrings.checkInAddNewPlace),
                      onTap: () => Navigator.pop(context, widget.newPlaceValue),
                    ),
                    const Divider(),
                    if (_results.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          AppStrings.checkInPlaceNoMatch,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverList.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final place = _results[index];
                    final selected = place.id == widget.selectedId;
                    return ListTile(
                      key: ValueKey('check-in-place-option-${place.id}'),
                      selected: selected,
                      selectedColor: colors.accentInk,
                      title: Text(place.name),
                      subtitle: Text(place.address),
                      trailing: selected
                          ? const Icon(CupertinoIcons.check_mark)
                          : null,
                      onTap: () => Navigator.pop(context, place.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
