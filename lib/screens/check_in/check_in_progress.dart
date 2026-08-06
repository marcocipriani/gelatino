import 'package:flutter/material.dart';
import '../../constants/app_strings.dart';

const checkInStepLabels = AppStrings.checkInStepLabels;

final class CheckInProgress extends StatelessWidget {
  const CheckInProgress({required this.currentStep, super.key});

  final int currentStep;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.checkInProgressAnnounce(
      currentStep + 1,
      checkInStepLabels.length,
      checkInStepLabels[currentStep],
    ),
    child: Padding(
      key: const ValueKey<String>('check-in-progress'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < checkInStepLabels.length; index++)
            Expanded(
              child: Semantics(
                label:
                    '${checkInStepLabels[index]}, '
                    '${index < currentStep
                        ? AppStrings.stepStateDone
                        : index == currentStep
                        ? AppStrings.stepStateCurrent
                        : AppStrings.stepStateTodo}',
                selected: index == currentStep,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: <Widget>[
                      AnimatedContainer(
                        key: const ValueKey<String>(
                          'check-in-progress-segment',
                        ),
                        duration: const Duration(milliseconds: 180),
                        height: 5,
                        decoration: BoxDecoration(
                          color: index <= currentStep
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 18,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            checkInStepLabels[index],
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: index == currentStep
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
