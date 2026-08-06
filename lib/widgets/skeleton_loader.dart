import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/app_tokens.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.control),
      ),
    );
  }
}

class TimelineSkeleton extends StatelessWidget {
  const TimelineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          elevation: AppElevation.flat,
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(
                width: double.infinity,
                height: 250,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadii.card),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonBox(width: 150, height: 20),
                        SkeletonBox(width: 60, height: 16),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(width: 100, height: 16),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        SkeletonBox(
                          width: 70,
                          height: 28,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        SkeletonBox(
                          width: 70,
                          height: 28,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GroupsSkeleton extends StatelessWidget {
  const GroupsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          elevation: AppElevation.flat,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 180, height: 18),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(width: 120, height: 14),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WishlistSkeleton extends StatelessWidget {
  const WishlistSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.8,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          elevation: AppElevation.flat,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: const SkeletonBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
          ),
        );
      },
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: SkeletonBox(
              width: 120,
              height: 120,
              borderRadius: BorderRadius.circular(60),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Center(child: SkeletonBox(width: 180, height: 24)),
          const SizedBox(height: AppSpacing.xs),
          const Center(child: SkeletonBox(width: 220, height: 16)),
          const SizedBox(height: AppSpacing.xxl),
          Card(
            elevation: AppElevation.flat,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      SkeletonBox(
                        width: 36,
                        height: 36,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const SkeletonBox(width: 40, height: 20),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Theme.of(context).dividerColor,
                  ),
                  Column(
                    children: [
                      SkeletonBox(
                        width: 36,
                        height: 36,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const SkeletonBox(width: 40, height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SkeletonBox(
            width: double.infinity,
            height: 48,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(
            width: double.infinity,
            height: 48,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ],
      ),
    );
  }
}

class MapSkeleton extends StatelessWidget {
  const MapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SkeletonBox(width: double.infinity, height: double.infinity),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(220),
              shape: BoxShape.circle,
            ),
            child:
                Icon(
                      Icons.map_outlined,
                      size: AppSpacing.display,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(150),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                      duration: 1000.ms,
                    )
                    .fade(begin: 0.6, end: 1.0),
          ),
        ),
      ],
    );
  }
}
