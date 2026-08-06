import 'package:flutter/material.dart';

import '../widgets/authenticated_shell.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({
    required this.location,
    required this.child,
    this.fullBleed = false,
    super.key,
  });

  final String location;
  final Widget child;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) => AuthenticatedShell(
    location: location,
    fullBleed: fullBleed,
    child: child,
  );
}
