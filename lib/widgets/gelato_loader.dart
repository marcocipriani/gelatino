import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GelatoLoader extends StatelessWidget {
  final double size;

  const GelatoLoader({
    super.key,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          'assets/images/logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(
              begin: 0.85,
              end: 1.12,
              duration: 900.ms,
              curve: Curves.easeInOutCubic,
            )
            .then()
            .shimmer(
              duration: 1800.ms,
              color: Colors.white24,
            ),
      ),
    );
  }
}
