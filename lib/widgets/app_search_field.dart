import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../design/app_tokens.dart';

/// iOS search field: filled, round, clearable while there is text.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.fieldKey,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(AppRadii.pill);
    // The field only needs rebuilding for the clear button.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 1,
          fillColor: colors.surfaceContainer,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(CupertinoIcons.search, size: 21),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: AppStrings.clearSearch,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(
                    CupertinoIcons.clear_circled_solid,
                    size: 20,
                  ),
                ),
          enabledBorder: OutlineInputBorder(
            borderRadius: shape,
            borderSide: BorderSide(color: colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: shape,
            borderSide: const BorderSide(
              color: AppFocus.color,
              width: AppFocus.ringWidth,
            ),
          ),
        ),
      ),
    );
  }
}
