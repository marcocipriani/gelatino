import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../design/focus_ring.dart';
import '../../models/place.dart';
import '../../models/place_state.dart';
import '../../providers/place_providers.dart';
import '../../constants/app_strings.dart';

class SavedPlaceControl extends ConsumerStatefulWidget {
  const SavedPlaceControl({required this.place, super.key});

  final Place place;

  @override
  ConsumerState<SavedPlaceControl> createState() => _SavedPlaceControlState();
}

class _SavedPlaceControlState extends ConsumerState<SavedPlaceControl> {
  bool _pending = false;
  bool? _pendingSelected;

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final stateAsync = ref.watch(placeStateProvider(place.id));
    final controller = ref.watch(placeStateControllerProvider);
    final canonical =
        stateAsync.value ?? PlaceState.empty(place.id).copyWith(saved: true);
    final pending =
        _pending || controller.hasPending(place.id, PlaceStateField.saved);
    final selected = _pending ? (_pendingSelected ?? true) : canonical.saved;
    final error = controller
        .failureFor(place.id, PlaceStateField.saved)
        ?.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          key: ValueKey<String>('saved-control-${place.id}'),
          container: true,
          button: true,
          selected: selected,
          enabled: !pending,
          label: selected
              ? AppStrings.savedPlaceRemoveSemantic(place.name)
              : AppStrings.savedPlaceSaveSemantic(place.name),
          excludeSemantics: true,
          child: AppFocusRing(
            child: SizedBox.square(
              dimension: AppLayout.touchTarget,
              child: IconButton(
                onPressed: pending ? null : () => _toggle(canonical),
                tooltip: selected ? AppStrings.savedPlaceSavedTooltip : AppStrings.savedPlaceSaveTooltip,
                icon: pending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        selected
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                      ),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _toggle(canonical),
            child: const Text(AppStrings.retry),
          ),
        ],
      ],
    );
  }

  Future<void> _toggle(PlaceState current) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _pendingSelected = current.saved;
    });
    try {
      await ref
          .read(placeStateControllerProvider.notifier)
          .toggleSaved(widget.place.id, current: current);
    } on PlaceStateFailure {
      // Durable feedback is retained by the canonical controller snapshot.
    } finally {
      if (mounted) {
        setState(() {
          _pending = false;
          _pendingSelected = null;
        });
      }
    }
  }
}
