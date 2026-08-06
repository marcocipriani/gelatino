import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'empty_state.dart';
import 'skeleton_loader.dart';
import '../constants/app_strings.dart';

enum AsyncContentStatus { loading, empty, error }

final class AsyncContentState extends StatelessWidget {
  const AsyncContentState.loading({
    super.key,
    this.width,
    this.height,
    this.loadingChild,
  }) : status = AsyncContentStatus.loading,
       icon = null,
       title = null,
       description = null,
       message = null,
       details = null,
       actionLabel = null,
       onAction = null;

  const AsyncContentState.empty({
    super.key,
    this.width,
    this.height,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  }) : status = AsyncContentStatus.empty,
       loadingChild = null,
       message = null,
       details = null,
       assert((actionLabel == null) == (onAction == null));

  const AsyncContentState.error({
    super.key,
    this.width,
    this.height,
    this.message = AppStrings.contentLoadError,
    this.details,
    required VoidCallback onRetry,
    this.actionLabel = AppStrings.retry,
  }) : status = AsyncContentStatus.error,
       loadingChild = null,
       icon = Icons.error_outline,
       title = null,
       description = null,
       onAction = onRetry;

  final AsyncContentStatus status;
  final double? width;
  final double? height;
  final Widget? loadingChild;
  final IconData? icon;
  final String? title;
  final String? description;
  final String? message;
  final Object? details;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (status == AsyncContentStatus.error && details != null) {
      debugPrint('AsyncContentState error: $details');
    }
    return SizedBox(
      width: width,
      height: height,
      child: switch (status) {
        AsyncContentStatus.loading =>
          loadingChild ??
              SkeletonBox(
                width: width ?? double.infinity,
                height: height ?? double.infinity,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
        AsyncContentStatus.empty => EmptyState(
          icon: icon,
          title: title!,
          description: description!,
          action: onAction == null
              ? null
              : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ),
        AsyncContentStatus.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel!),
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
