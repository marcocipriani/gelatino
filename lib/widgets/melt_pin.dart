import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../constants/app_strings.dart';

class MeltPin extends StatelessWidget {
  const MeltPin({required this.onPressed, this.compact = false, super.key});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 48.0;
    return Semantics(
      key: const ValueKey('melt-pin'),
      button: true,
      label: AppStrings.checkInTitle,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: AppFocusRing(
          borderRadius: AppRadii.pill,
          child: SizedBox.square(
            dimension: size,
            child: IconButton.filled(
              tooltip: AppStrings.checkInTitle,
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.fragola,
                foregroundColor: AppColors.fondente,
                minimumSize: const Size.square(AppLayout.touchTarget),
                shape: const CircleBorder(),
              ),
              icon: SvgPicture.asset(
                'assets/images/simple-pin.svg',
                width: compact ? 28 : 24,
                height: compact ? 28 : 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.fondente,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
