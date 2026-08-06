import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/responsive.dart';

final class ProfileA1Layout extends StatelessWidget {
  const ProfileA1Layout({
    required this.identity,
    required this.content,
    super.key,
  });

  final Widget identity;
  final Widget content;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final responsive = ResponsiveClass.fromWidth(availableWidth);
      final key = ValueKey('profile-${responsive.name}');

      if (responsive == ResponsiveClass.wide) {
        return Row(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 360, child: identity),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: content),
          ],
        );
      }
      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          const SizedBox(height: AppSpacing.xl),
          content,
        ],
      );
    },
  );
}

final class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

final class ProfileStatePanel extends StatelessWidget {
  const ProfileStatePanel({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProfilePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: actionKey,
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

final class ProfileA1Skeleton extends StatelessWidget {
  const ProfileA1Skeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      key: const ValueKey('profile-loading'),
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ],
    );
  }
}
