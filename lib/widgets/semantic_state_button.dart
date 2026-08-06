import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

final class SemanticStateButton extends StatelessWidget {
  const SemanticStateButton({
    super.key,
    required this.selected,
    required this.selectedLabel,
    required this.unselectedLabel,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.onPressed,
  });

  final bool selected;
  final String selectedLabel;
  final String unselectedLabel;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = selected ? selectedLabel : unselectedLabel;
    final icon = selected ? selectedIcon : unselectedIcon;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(
              AppLayout.touchTarget,
              AppLayout.touchTarget,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}
