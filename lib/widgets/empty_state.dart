import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import '../design/motion.dart';

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final String title;
  final String description;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon,
    this.imageAsset,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset!,
                height: 160,
                width: 160,
                fit: BoxFit.contain,
              )
            else if (icon != null)
              Icon(
                icon,
                size: AppSpacing.display,
                color: Theme.of(context).colorScheme.accentInk,
              ).entrance(context),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ).entrance(context, order: 1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).entrance(context, order: 2),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppLayout.touchTarget,
                  minHeight: AppLayout.touchTarget,
                ),
                child: action!,
              ).entrance(context, order: 3),
            ],
          ],
        ),
      ),
    );
  }
}
