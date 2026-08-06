import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

enum EditorialCardVariant { flat, overlay }

final class EditorialCard extends StatelessWidget {
  const EditorialCard.flat({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
    this.showDivider = true,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = EditorialCardVariant.flat;

  const EditorialCard.overlay({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = EditorialCardVariant.overlay,
       showDivider = false;

  final EditorialCardVariant variant;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? width;
  final double? height;
  final bool showDivider;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFlat = variant == EditorialCardVariant.flat;
    final shape = SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(
        cornerRadius: AppRadii.card,
        cornerSmoothing: 0.6,
      ),
      side: isFlat && showDivider
          ? BorderSide(color: theme.dividerColor, width: 1)
          : BorderSide.none,
    );

    return Padding(
      padding: margin,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: isFlat ? AppElevation.flat : AppElevation.overlay,
          shadowColor: theme.shadowColor,
          shape: shape,
          clipBehavior: clipBehavior,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
