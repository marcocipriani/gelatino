import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../widgets/app_controls.dart';
import '../widgets/flavors_manager.dart';
import '../constants/app_strings.dart';

class FavoriteFlavorsScreen extends ConsumerWidget {
  const FavoriteFlavorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // iOS large title: collapses into the bar as you scroll.
          CupertinoSliverNavigationBar(
            automaticallyImplyLeading: false,
            transitionBetweenRoutes: false,
            automaticBackgroundVisibility: false,
            backgroundColor: theme.scaffoldBackgroundColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
            padding: EdgeInsetsDirectional.zero,
            leading: const AppBackButton(fallback: '/collection'),
            alwaysShowMiddle: false,
            middle: Text(
              AppStrings.favoriteFlavorsTitle,
              style: theme.textTheme.titleMedium,
            ),
            largeTitle: Text(
              AppStrings.favoriteFlavorsTitle,
              style: theme.textTheme.displaySmall,
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: const FlavorsManager(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
