import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../design/app_tokens.dart';
import '../design/motion.dart';

/// iOS segmented control. Not [CupertinoSlidingSegmentedControl]: that one
/// takes no keyboard focus, which the web build needs.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    required this.value,
    required this.segments,
    required this.onChanged,
    this.icons = const {},
    super.key,
  });

  final T value;
  final Map<T, String> segments;
  final Map<T, IconData> icons;
  final ValueChanged<T>? onChanged;

  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final options = segments.keys.toList(growable: false);
    final index = options.indexOf(value);
    final enabled = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: AppLayout.touchTarget,
          width: double.infinity,
          child: Stack(
            children: [
              if (index >= 0)
                AnimatedAlign(
                  duration: AppMotion.of(context, AppMotion.standard),
                  curve: AppMotion.glide,
                  alignment: AlignmentDirectional(
                    options.length == 1
                        ? 0
                        : -1 + 2 * index / (options.length - 1),
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / options.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(_inset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(
                            AppRadii.control - _inset,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: option == value,
                        inMutuallyExclusiveGroup: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          onTap: !enabled
                              ? null
                              : () {
                                  if (option == value) return;
                                  HapticFeedback.selectionClick();
                                  onChanged!(option);
                                },
                          child: _Segment(
                            label: segments[option]!,
                            icon: icons[option],
                            color: option == value
                                ? colors.onPrimary
                                : colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.5,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Alert with platform-correct buttons; resolves true only on confirm.
Future<bool> showAppConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Key? confirmKey,
}) async {
  final platform = Theme.of(context).platform;
  final apple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      void close(bool result) => Navigator.of(dialogContext).pop(result);
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: apple
            ? [
                CupertinoDialogAction(
                  onPressed: () => close(false),
                  child: Text(AppStrings.cancel),
                ),
                CupertinoDialogAction(
                  key: confirmKey,
                  isDestructiveAction: true,
                  // systemRed is 3.6:1 on the alert; the error ink clears AA.
                  textStyle: TextStyle(color: colors.error),
                  onPressed: () => close(true),
                  child: Text(confirmLabel),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => close(false),
                  child: Text(AppStrings.cancel),
                ),
                FilledButton(
                  key: confirmKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  onPressed: () => close(true),
                  child: Text(confirmLabel),
                ),
              ],
      );
    },
  );
  return confirmed ?? false;
}

/// Back chevron that still leads somewhere after a deep link.
class AppBackButton extends StatelessWidget {
  const AppBackButton({required this.fallback, super.key});

  final String fallback;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppStrings.back,
    icon: const Icon(CupertinoIcons.back),
    onPressed: () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.maybePop();
      } else {
        GoRouter.maybeOf(context)?.go(fallback);
      }
    },
  );
}
