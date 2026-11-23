import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../design/motion.dart';
import '../app_search_field.dart';

/// Search row. While searching, "Annulla" slides in to leave search, as on iOS.
final class PlaceSearchBar extends StatelessWidget {
  const PlaceSearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;

  /// Shown beside the field when not searching.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final side = searching
        ? TextButton(
            key: const ValueKey<String>('places-search-cancel'),
            onPressed: () {
              controller.clear();
              onChanged('');
              focusNode.unfocus();
            },
            child: const Text(AppStrings.cancel, maxLines: 1),
          )
        : trailing;
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            fieldKey: const ValueKey<String>('places-search-field'),
            controller: controller,
            focusNode: focusNode,
            hint: AppStrings.placeSearchHint,
            onChanged: onChanged,
          ),
        ),
        AnimatedSize(
          // AnimatedSize can't take a zero duration.
          duration: AppMotion.reduced(context)
              ? const Duration(microseconds: 1)
              : AppMotion.standard,
          curve: AppMotion.glide,
          alignment: AlignmentDirectional.centerStart,
          child: side == null
              ? const SizedBox(height: AppLayout.touchTarget)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xs,
                  ),
                  child: side,
                ),
        ),
      ],
    );
  }
}
