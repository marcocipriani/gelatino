import 'package:flutter/material.dart';

class GelatoBackground extends StatelessWidget {
  final Widget child;

  const GelatoBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: child,
      ),
    );
  }
}
