import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_strings.dart';
import '../design/app_tokens.dart';
import '../design/focus_ring.dart';

class AccessBrandPanel extends StatelessWidget {
  const AccessBrandPanel({
    required this.isLoading,
    required this.errorMessage,
    required this.onSignIn,
    required this.contentPadding,
    required this.titleFontSize,
    required this.maxContentWidth,
    required this.independentlyScrollable,
    super.key,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onSignIn;
  final EdgeInsetsGeometry contentPadding;
  final double titleFontSize;
  final double maxContentWidth;
  final bool independentlyScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      key: const ValueKey('access-brand-content'),
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      child: _BrandContent(
        theme: theme,
        isLoading: isLoading,
        errorMessage: errorMessage,
        onSignIn: onSignIn,
        titleFontSize: titleFontSize,
      ),
    );

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: independentlyScrollable
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final resolvedPadding = contentPadding.resolve(
                    Directionality.of(context),
                  );
                  final availableHeight =
                      constraints.maxHeight - resolvedPadding.vertical;
                  return SingleChildScrollView(
                    key: const ValueKey('access-wide-brand-scroll'),
                    padding: contentPadding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: availableHeight > 0 ? availableHeight : 0,
                      ),
                      child: Center(child: content),
                    ),
                  );
                },
              )
            : Padding(
                padding: contentPadding,
                child: Center(child: content),
              ),
      ),
    );
  }
}

class _BrandContent extends StatelessWidget {
  const _BrandContent({
    required this.theme,
    required this.isLoading,
    required this.errorMessage,
    required this.onSignIn,
    required this.titleFontSize,
  });

  final ThemeData theme;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onSignIn;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final stateAnimationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Wordmark(theme: theme),
        const SizedBox(height: AppSpacing.display),
        Semantics(
          key: const ValueKey('access-title'),
          header: true,
          child: Text(
            AppStrings.accessTagline,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: titleFontSize,
              height: 0.98,
              letterSpacing: -1.8,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            AppStrings.accessDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppFocusRing(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('access-google-action'),
              onPressed: onSignIn,
              icon: SizedBox.square(
                dimension: 20,
                child: isLoading
                    ? const ExcludeSemantics(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.fondente,
                        ),
                      )
                    : const Icon(Icons.login_rounded, size: 20),
              ),
              label: const Text(AppStrings.loginButton),
            ),
          ),
        ),
        if (isLoading)
          Semantics(
            key: const ValueKey('access-progress'),
            container: true,
            liveRegion: true,
            label: AppStrings.accessInProgress,
            child: const SizedBox.shrink(),
          ),
        AnimatedSwitcher(
          duration: stateAnimationDuration,
          child: errorMessage == null
              ? const SizedBox(
                  key: ValueKey('access-auth-error-empty'),
                  height: AppSpacing.xl,
                )
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Semantics(
                    key: const ValueKey('access-auth-error'),
                    container: true,
                    liveRegion: true,
                    label: errorMessage,
                    child: ExcludeSemantics(
                      child: Text(
                        errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.appName,
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/pin-fragola.svg',
              width: 32,
              height: 40,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppStrings.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
