import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gelato_background.dart';

// Stateless pieces of the check-in flow chrome, kept apart from the stateful
// flow so check_in_flow.dart only holds orchestration.

final class CheckInUnresolvedLabelsNotice extends StatelessWidget {
  const CheckInUnresolvedLabelsNotice({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    key: ValueKey<String>('check-in-page-4'),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        AppStrings.checkInSummaryUnavailable,
      ),
    ),
  );
}

final class CheckInLabelRecoveryActions extends StatelessWidget {
  const CheckInLabelRecoveryActions({
    super.key,
    required this.busy,
    required this.onRetry,
    required this.onRebuild,
  });

  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      OutlinedButton(
        onPressed: busy ? null : onRetry,
        child: const Text(AppStrings.checkInRetryLabels),
      ),
      TextButton(
        onPressed: busy ? null : onRebuild,
        child: const Text(AppStrings.checkInRebuildCache),
      ),
    ],
  );
}

final class CheckInFlowHeader extends StatelessWidget {
  const CheckInFlowHeader({super.key, required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
    child: Row(
      children: <Widget>[
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onClose,
          tooltip: AppStrings.checkInCloseTooltip,
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.checkInTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

final class CheckInPublishedRecovery extends StatelessWidget {
  const CheckInPublishedRecovery({
    super.key,
    required this.busy,
    required this.message,
    required this.onRetry,
  });

  final bool busy;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: GelatoBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 64,
                    color: AppTheme.mentaGlaciale,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.checkInAlreadyPublished,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ??
                        AppStrings.checkInCompleteCleanupToClose,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: busy ? null : onRetry,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.checkInCompleteCleanup),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
