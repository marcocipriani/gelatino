import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../design/motion.dart';

/// Press-to-shrink button for custom-shaped controls. Keyboard and screen
/// reader activatable, still when motion is reduced.
class BounceButton extends StatefulWidget {
  const BounceButton({super.key, required this.child, this.onTap});

  static const pressedScale = 0.96;

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.press,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press(bool down) {
    if (down) HapticFeedback.lightImpact();
    if (AppMotion.reduced(context)) return;
    down ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: AppFocusRing(
        borderRadius: AppRadii.pill,
        child: InkWell(
          onTap: onTap,
          onTapDown: onTap == null ? null : (_) => _press(true),
          onTapUp: onTap == null ? null : (_) => _press(false),
          onTapCancel: onTap == null ? null : () => _press(false),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale: 1 - (1 - BounceButton.pressedScale) * _controller.value,
              child: child,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
