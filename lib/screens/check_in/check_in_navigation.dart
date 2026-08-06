import 'package:flutter/material.dart';

final class CheckInNavigation extends StatelessWidget {
  const CheckInNavigation({
    required this.backLabel,
    required this.primaryLabel,
    required this.onBack,
    required this.onPrimary,
    required this.busy,
    super.key,
  });

  final String backLabel;
  final String primaryLabel;
  final VoidCallback? onBack;
  final VoidCallback? onPrimary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 25;
    final back = SizedBox(
      height: 48,
      child: TextButton(onPressed: onBack, child: Text(backLabel)),
    );
    final primary = SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPrimary,
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(primaryLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    return Material(
      key: const ValueKey<String>('check-in-sticky-navigation'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: largeText
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[primary, const SizedBox(height: 8), back],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: back),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: primary),
                ],
              ),
      ),
    );
  }
}
