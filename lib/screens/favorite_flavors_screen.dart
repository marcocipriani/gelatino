import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/flavors_manager.dart';
import '../constants/app_strings.dart';

class FavoriteFlavorsScreen extends ConsumerWidget {
  const FavoriteFlavorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: const CustomScrollView(
            slivers: [
              SliverAppBar.medium(
                title: Text(
                  AppStrings.favoriteFlavorsTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverToBoxAdapter(child: FlavorsManager()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
