import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../widgets/avatar_image_provider.dart';

final class FriendsSection extends StatelessWidget {
  const FriendsSection({
    required this.title,
    required this.child,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

final class FriendsStatePanel extends StatelessWidget {
  const FriendsStatePanel({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
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
      ),
    );
  }
}

final class FriendsSkeleton extends StatelessWidget {
  const FriendsSkeleton({this.rows = 2, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List<Widget>.generate(
        rows,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == rows - 1 ? 0 : AppSpacing.sm,
          ),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ),
        ),
      ),
    );
  }
}

final class FriendsPersonCard extends StatelessWidget {
  const FriendsPersonCard({
    required this.uid,
    required this.name,
    required this.subtitle,
    required this.actions,
    required this.onOpen,
    this.avatarPath,
    this.secondary,
    this.failure,
    super.key,
  });

  final String uid;
  final String name;
  final String subtitle;
  final String? avatarPath;
  final String? secondary;
  final List<Widget> actions;
  final VoidCallback onOpen;
  final Widget? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = this.secondary;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthenticatedAvatar(source: avatarPath, radius: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (secondary != null && secondary.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            secondary,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: actions,
                ),
              ],
              if (failure != null) ...[
                const SizedBox(height: AppSpacing.sm),
                failure!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class FriendsResponsiveCards extends StatelessWidget {
  const FriendsResponsiveCards({
    required this.children,
    this.twoColumns = false,
    super.key,
  });

  final List<Widget> children;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
