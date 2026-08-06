import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../models/place.dart';
import '../../providers/location_provider.dart';
import '../../providers/place_providers.dart';
import '../../utils/error_handler.dart';
import 'place_location_picker.dart';
import '../../constants/app_strings.dart';

final class AddPlaceDialog extends ConsumerStatefulWidget {
  const AddPlaceDialog({required this.catalogCoordinates, super.key});

  final List<GeoPoint> catalogCoordinates;

  @override
  ConsumerState<AddPlaceDialog> createState() => _AddPlaceDialogState();
}

final class _AddPlaceDialogState extends ConsumerState<AddPlaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _submitting = false;
  bool _choosingOnMap = false;
  String? _failure;
  GeoPoint? _selectedCoordinate;
  int _operationGeneration = 0;

  GeoPoint get _initialCoordinate =>
      widget.catalogCoordinates.firstOrNull ?? const GeoPoint(0, 0);

  @override
  void dispose() {
    _operationGeneration++;
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        scrollable: true,
        title: Text(_choosingOnMap ? AppStrings.addPlaceChooseLocationTitle : AppStrings.placeAddButton),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: AppStrings.addPlaceNameLabel),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? AppStrings.addPlaceEnterName
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _addressController,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: AppStrings.addPlaceAddressLabel),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? AppStrings.addPlaceEnterAddress
                      : null,
                ),
                if (_choosingOnMap) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  PlaceLocationPicker(
                    initialCoordinate: _initialCoordinate,
                    selectedCoordinate: _selectedCoordinate,
                    onSelected: (coordinate) =>
                        setState(() => _selectedCoordinate = coordinate),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _selectedCoordinate == null
                        ? AppStrings.mapTapToChoose
                        : AppStrings.addPlacePointSelected(
                            '${_selectedCoordinate!.latitude.toStringAsFixed(5)}, '
                            '${_selectedCoordinate!.longitude.toStringAsFixed(5)}',
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_failure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _failure!,
                    key: const ValueKey<String>('add-place-failure'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_submitting) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        actions: _actions(),
      ),
    );
  }

  List<Widget> _actions() {
    if (_choosingOnMap) {
      return <Widget>[
        TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() => _choosingOnMap = false),
          child: const Text(AppStrings.back),
        ),
        FilledButton(
          onPressed: _submitting || _selectedCoordinate == null
              ? null
              : () => _submitAt(_selectedCoordinate!),
          child: const Text(AppStrings.addPlaceConfirmPoint),
        ),
      ];
    }
    return <Widget>[
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context),
        child: const Text(AppStrings.cancel),
      ),
      if (_failure != null) ...<Widget>[
        TextButton(
          onPressed: _submitting ? null : _useGps,
          child: const Text(AppStrings.addPlaceRetryLocation),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() {
                  _choosingOnMap = true;
                  _failure = null;
                }),
          child: const Text(AppStrings.chooseOnMap),
        ),
      ] else
        FilledButton.icon(
          onPressed: _submitting ? null : _useGps,
          icon: const Icon(Icons.my_location_rounded),
          label: const Text(AppStrings.useLocation),
        ),
    ];
  }

  Future<void> _useGps() async {
    if (_submitting || !_validate()) return;
    final input = _snapshotInput();
    final generation = _beginSubmission();
    try {
      final location = await ref
          .read(deviceLocationServiceProvider)
          .currentLocation();
      if (!_isActive(generation)) return;
      await _create(
        input: input,
        coordinate: GeoPoint(location.latitude, location.longitude),
        generation: generation,
      );
    } catch (error) {
      if (!_isActive(generation)) return;
      setState(() => _failure = ErrorHandler.getReadableError(error));
    } finally {
      _finishSubmission(generation);
    }
  }

  Future<void> _submitAt(GeoPoint coordinate) async {
    if (!_validate() || _submitting) return;
    final input = _snapshotInput();
    final generation = _beginSubmission();
    try {
      await _create(
        input: input,
        coordinate: coordinate,
        generation: generation,
      );
    } catch (error) {
      if (!_isActive(generation)) return;
      setState(() => _failure = ErrorHandler.getReadableError(error));
    } finally {
      _finishSubmission(generation);
    }
  }

  bool _validate() => _formKey.currentState?.validate() ?? false;

  ({String name, String address}) _snapshotInput() => (
    name: _nameController.text.trim(),
    address: _addressController.text.trim(),
  );

  int _beginSubmission() {
    final generation = ++_operationGeneration;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    return generation;
  }

  bool _isActive(int generation) =>
      mounted && generation == _operationGeneration;

  void _finishSubmission(int generation) {
    if (!_isActive(generation)) return;
    setState(() => _submitting = false);
  }

  Future<void> _create({
    required ({String name, String address}) input,
    required GeoPoint coordinate,
    required int generation,
  }) async {
    final place = await ref
        .read(placeRepositoryProvider)
        .createPlace(
          name: input.name,
          address: input.address,
          location: coordinate,
        );
    if (!mounted || generation != _operationGeneration) return;
    _operationGeneration++;
    Navigator.pop<Place>(context, place);
  }
}
