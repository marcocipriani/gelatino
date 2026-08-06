import 'package:flutter/material.dart';

import 'check_in_progress.dart';
import '../../constants/app_strings.dart';

final class CheckInStepRail extends StatelessWidget {
  const CheckInStepRail({required this.currentStep, super.key});

  final int currentStep;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey<String>('check-in-wide-step-rail'),
    width: 220,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 32, 20, 24),
        itemCount: checkInStepLabels.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final isCurrent = index == currentStep;
          final isComplete = index < currentStep;
          return Semantics(
            selected: isCurrent,
            label:
                '${checkInStepLabels[index]}, '
                '${isComplete
                    ? AppStrings.stepStateDone
                    : isCurrent
                    ? AppStrings.stepStateCurrent
                    : AppStrings.stepStateTodo}',
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: isCurrent || isComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: isCurrent || isComplete
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    child: isComplete
                        ? const Icon(Icons.check_rounded, size: 17)
                        : Text('${index + 1}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      checkInStepLabels[index],
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
