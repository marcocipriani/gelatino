import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

final class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.description,
    this.actions = const <Widget>[],
  });

  final String? eyebrow;
  final String title;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eyebrowText = eyebrow;
    final descriptionText = description;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrowText != null && eyebrowText.isNotEmpty) ...[
          Text(
            eyebrowText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(title, style: theme.textTheme.displaySmall),
        if (descriptionText != null && descriptionText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.readableText),
            child: Text(
              descriptionText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ],
    );
    final actionWrap = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.end,
      children: actions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (actions.isEmpty) return copy;
        if (constraints.maxWidth < AppBreakpoints.mediumMin) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: AppSpacing.md),
              actionWrap,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: copy),
            const SizedBox(width: AppSpacing.lg),
            actionWrap,
          ],
        );
      },
    );
  }
}
