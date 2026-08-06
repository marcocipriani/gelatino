import 'package:flutter/material.dart';
import 'package:gelatino/design/app_tokens.dart';

class AppFocusRing extends StatefulWidget {
  const AppFocusRing({
    required this.child,
    this.borderRadius = AppRadii.control,
    super.key,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<AppFocusRing> createState() => _AppFocusRingState();
}

class _AppFocusRingState extends State<AppFocusRing> {
  var _showFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        final show =
            hasFocus &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional;
        if (_showFocus == show) return;
        setState(() => _showFocus = show);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_showFocus)
            Positioned(
              top: -(AppFocus.ringGap + AppFocus.ringWidth),
              right: -(AppFocus.ringGap + AppFocus.ringWidth),
              bottom: -(AppFocus.ringGap + AppFocus.ringWidth),
              left: -(AppFocus.ringGap + AppFocus.ringWidth),
              child: IgnorePointer(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppFocus.color,
                      width: AppFocus.ringWidth,
                    ),
                    borderRadius: BorderRadius.circular(
                      widget.borderRadius +
                          AppFocus.ringGap +
                          AppFocus.ringWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
