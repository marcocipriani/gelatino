import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../widgets/places/place_location_picker.dart';
import '../../constants/app_strings.dart';
import 'place_picker_field.dart';

const checkInNewPlaceValue = '__new_place__';

final class PlaceStep extends StatelessWidget {
  const PlaceStep({
    required this.places,
    required this.selectedPlaceId,
    required this.cachedSelectedPlaceName,
    required this.isNewPlace,
    required this.nameController,
    required this.addressController,
    required this.selectedCoordinate,
    required this.showMap,
    required this.enabled,
    required this.onSelectionChanged,
    required this.onInputChanged,
    required this.onUseGps,
    required this.onShowMap,
    required this.onMapSelected,
    super.key,
  });

  final List<Place> places;
  final String? selectedPlaceId;
  final String? cachedSelectedPlaceName;
  final bool isNewPlace;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final GeoPoint? selectedCoordinate;
  final bool showMap;
  final bool enabled;
  final ValueChanged<String> onSelectionChanged;
  final VoidCallback onInputChanged;
  final VoidCallback onUseGps;
  final VoidCallback onShowMap;
  final ValueChanged<GeoPoint> onMapSelected;

  GeoPoint get _initialCoordinate =>
      selectedCoordinate ??
      places.firstOrNull?.location ??
      const GeoPoint(0, 0);

  @override
  Widget build(BuildContext context) {
    final hasRemoteSelection = places.any(
      (place) => place.id == selectedPlaceId,
    );
    final selectedValue = isNewPlace
        ? checkInNewPlaceValue
        : hasRemoteSelection ||
              (selectedPlaceId != null && cachedSelectedPlaceName != null)
        ? selectedPlaceId
        : null;
    return Column(
      key: const ValueKey<String>('check-in-page-1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PlacePickerField(
          key: ValueKey<String>('place-$selectedValue'),
          places: places,
          initialValue: selectedValue,
          newPlaceValue: checkInNewPlaceValue,
          selectedLabel: isNewPlace
              ? AppStrings.checkInAddNewPlace
              : switch (places
                    .where((place) => place.id == selectedPlaceId)
                    .firstOrNull) {
                  final place? => '${place.name} — ${place.address}',
                  null when selectedValue != null => cachedSelectedPlaceName,
                  null => null,
                },
          onChanged: enabled ? onSelectionChanged : null,
        ),
        if (isNewPlace) ...<Widget>[
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('check-in-place-name'),
            controller: nameController,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: AppStrings.checkInNewPlaceLabel,
            ),
            onChanged: (_) => onInputChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('check-in-place-address'),
            controller: addressController,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: AppStrings.checkInAddressFieldLabel,
            ),
            onChanged: (_) => onInputChanged(),
          ),
          const SizedBox(height: 16),
          Text(
            selectedCoordinate == null
                ? AppStrings.checkInAddLocationHint
                : AppStrings.checkInLocationReady,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              SizedBox(
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? onUseGps : null,
                  icon: const Icon(CupertinoIcons.location_fill),
                  label: const Text(AppStrings.useLocation),
                ),
              ),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: enabled ? onShowMap : null,
                  icon: const Icon(CupertinoIcons.map),
                  label: const Text(AppStrings.chooseOnMap),
                ),
              ),
            ],
          ),
          if (showMap) ...<Widget>[
            const SizedBox(height: 16),
            PlaceLocationPicker(
              initialCoordinate: _initialCoordinate,
              selectedCoordinate: selectedCoordinate,
              onSelected: onMapSelected,
            ),
            const SizedBox(height: 8),
            Text(
              selectedCoordinate == null
                  ? AppStrings.mapTapToChoose
                  : AppStrings.mapPointSelected,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ],
    );
  }
}
