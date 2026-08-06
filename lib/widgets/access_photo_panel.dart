import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/app_tokens.dart';
import '../constants/app_strings.dart';

class AccessPhotoPanel extends StatelessWidget {
  const AccessPhotoPanel({this.borderRadius = AppRadii.hero, super.key});

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: AppStrings.accessPhotoLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: const Color(0xFFF2E7D5),
          child: SvgPicture.asset(
            'assets/images/access-gelato-art.svg',
            key: const ValueKey('access-gelato-art'),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
