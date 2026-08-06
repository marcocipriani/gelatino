import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

class CreamyCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Clip clipBehavior;

  const CreamyCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor =
        backgroundColor ?? theme.cardTheme.color ?? theme.cardColor;
    final dividerColor = borderColor ?? theme.dividerColor;
    final isDark = theme.brightness == Brightness.dark;

    final shapeBorder = SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(
        cornerRadius: borderRadius,
        cornerSmoothing: 0.6,
      ),
      side: BorderSide(color: dividerColor, width: isDark ? 0.5 : borderWidth),
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: ShapeDecoration(
        color: cardColor,
        shape: shapeBorder,
        shadows: isDark
            ? null
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
      ),
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: borderRadius,
          cornerSmoothing: 0.6,
        ),
        clipBehavior: clipBehavior,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
