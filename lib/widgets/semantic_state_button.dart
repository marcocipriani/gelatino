import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_tokens.dart';
import 'app_icon.dart';

final class SemanticStateButton extends StatelessWidget {
  const SemanticStateButton({
    super.key,
    required this.selected,
    required this.selectedLabel,
    required this.unselectedLabel,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.onPressed,
    this.selectedColor,
  });

  final bool selected;
  final String selectedLabel;
  final String unselectedLabel;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final VoidCallback? onPressed;

  /// The state's brand fill; always carries Fondente ink.
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final label = selected ? selectedLabel : unselectedLabel;
    final icon = selected ? selectedIcon : unselectedIcon;
    final fill = selected ? selectedColor : null;
    final press = onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: label,
      onTap: press,
      child: ExcludeSemantics(
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: fill,
            foregroundColor: fill == null ? null : AppColors.fondente,
            // Stays readable while the optimistic write is in flight.
            disabledBackgroundColor: fill?.withValues(alpha: 0.7),
            disabledForegroundColor: fill == null ? null : AppColors.fondente,
            minimumSize: const Size(
              AppLayout.touchTarget,
              AppLayout.touchTarget,
            ),
          ),
          onPressed: press,
          icon: AppIconSwap(icon: icon),
          label: Text(label),
        ),
      ),
    );
  }
}
