import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/app_tokens.dart';
import '../design/motion.dart';

/// The one icon treatment in the app: a Cupertino glyph in a tonal pill.
/// The tab bar fades the pill out on inactive tabs; settings rows keep it on.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    this.active = true,
    this.width = 40,
    this.height = 28,
    this.size = 20,
    super.key,
  });

  final IconData icon;
  final bool active;
  final double width;
  final double height;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = AppMotion.of(context, AppMotion.standard);
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.glide,
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? colors.primaryContainer
            : colors.primaryContainer.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: AppIconSwap(
        icon: icon,
        size: size,
        color: active ? colors.accentInk : colors.onSurfaceVariant,
      ),
    );
  }
}

/// Icon that pops in, with a slight overshoot, whenever [icon] changes:
/// outline to fill on select, bookmark to bookmark_fill on save. [busy]
/// swaps in a spinner inside the same switcher, so the icon that follows a
/// save still pops instead of mounting cold.
class AppIconSwap extends StatelessWidget {
  const AppIconSwap({
    required this.icon,
    this.size,
    this.color,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final bool busy;

  static final _pop = Tween<double>(begin: 0.6, end: 1);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.of(context, AppMotion.emphasized),
    reverseDuration: AppMotion.of(context, AppMotion.fast),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: AppMotion.exit,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: _pop.animate(animation), child: child),
    ),
    child: busy
        ? const SizedBox.square(
            key: ValueKey('busy'),
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, key: ValueKey(icon), size: size, color: color),
  );
}

/// The gelato cone, drawn to sit beside Cupertino glyphs (24 grid, 1.75
/// round stroke). Drop-in for [Icon]: takes size and colour from [IconTheme].
class GelatoIcon extends StatelessWidget {
  const GelatoIcon({this.size, this.color, super.key});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/images/icon-gelato.svg',
        width: side,
        height: side,
        colorFilter: ColorFilter.mode(
          color ?? theme.color ?? Theme.of(context).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
