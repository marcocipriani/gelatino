import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

final class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descriptionText = description;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (descriptionText != null && descriptionText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(descriptionText, style: theme.textTheme.bodySmall),
        ],
      ],
    );
    final actionWidget = action;
    if (actionWidget == null) return copy;
    final constrainedAction = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppLayout.touchTarget,
        minWidth: AppLayout.touchTarget,
      ),
      child: actionWidget,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.mediumMin) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: AppSpacing.sm),
              constrainedAction,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: copy),
            const SizedBox(width: AppSpacing.md),
            constrainedAction,
          ],
        );
      },
    );
  }
}
