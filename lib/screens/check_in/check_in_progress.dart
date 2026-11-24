import 'package:flutter/material.dart';
import '../../constants/app_strings.dart';
import '../../design/motion.dart';

final checkInStepLabels = AppStrings.checkInStepLabels;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five labels need about 84pt each. Shrunk to fit a phone they were
          // 9pt, so there one readable line replaces them.
          final labelled =
              constraints.maxWidth / checkInStepLabels.length >=
              84 * MediaQuery.textScalerOf(context).scale(16) / 16;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _segments(context, labelled: labelled),
              if (!labelled) ...[
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: Text(
                    AppStrings.checkInStepOf(
                      currentStep + 1,
                      checkInStepLabels.length,
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _segments(BuildContext context, {required bool labelled}) => Row(
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
                    key: const ValueKey<String>('check-in-progress-segment'),
                    duration: AppMotion.of(context, AppMotion.standard),
                    height: 5,
                    decoration: BoxDecoration(
                      color: index <= currentStep
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  if (labelled) ...[
                    const SizedBox(height: 6),
                    Text(
                      checkInStepLabels[index],
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: index == currentStep
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
