import 'package:flutter/material.dart';

import '../providers/media_provider.dart';
import 'authenticated_storage_image.dart';

final class AuthenticatedCheckInPhoto extends StatelessWidget {
  const AuthenticatedCheckInPhoto({
    super.key,
    required this.path,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
    this.placeholderColor,
  });

  final String path;
  final String semanticLabel;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    return AuthenticatedStorageImage(
      path: path,
      maxBytes: checkInMediaMaxBytes,
      semanticLabel: semanticLabel,
      fit: fit,
      placeholderColor: placeholderColor,
    );
  }
}
