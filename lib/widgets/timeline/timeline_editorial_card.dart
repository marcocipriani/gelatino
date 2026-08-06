import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../models/feed_item.dart';
import '../authenticated_check_in_photo.dart';
import '../avatar_image_provider.dart';
import '../editorial_card.dart';
import '../share/share_check_in_card.dart';
import '../../constants/app_strings.dart';

final class TimelineEditorialCard extends StatelessWidget {
  const TimelineEditorialCard({
    super.key,
    required this.item,
    this.compact = false,
    this.height,
    this.compactScrollController,
  });

  final FeedItem item;
  final bool compact;
  final double? height;
  final ScrollController? compactScrollController;

  @override
  Widget build(BuildContext context) {
    final username = item.userSnapshot['display_name'] as String;
    final avatarPath = item.userSnapshot['avatar_path'] as String?;
    final placeName = item.placeSnapshot['name'] as String;
    final photo = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: AuthenticatedCheckInPhoto(
        path: item.photoStoragePath,
        semanticLabel: AppStrings.timelinePhotoSemantic(placeName),
      ),
    );
    final metadata = _TimelineMetadata(item: item, placeName: placeName);

    return EditorialCard.flat(
      key: ValueKey<String>('timeline-card-${item.checkInId}'),
      height: height,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                AuthenticatedAvatar(
                  source: avatarPath,
                  radius: 20,
                  iconSize: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    // The eaten date, not the publish date. A backdated
                    // check-in still sorts by publication, so it says so
                    // explicitly instead of looking like a stale post.
                    item.isBackdated
                        ? AppStrings.timelineBackdated(_date(item.consumedAt))
                        : _date(item.consumedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                _ShareIconButton(
                  placeName: placeName,
                  rating: item.rating,
                  flavors: item.flavors,
                  photo: photo,
                ),
              ],
            ),
          ),
          if (compact)
            Expanded(
              child: _AdaptiveCompactScroll(
                key: ValueKey<String>('timeline-card-scroll-${item.checkInId}'),
                controller: compactScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AspectRatio(aspectRatio: 16 / 9, child: photo),
                    metadata,
                  ],
                ),
              ),
            )
          else ...<Widget>[
            AspectRatio(aspectRatio: 16 / 9, child: photo),
            metadata,
          ],
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

final class _AdaptiveCompactScroll extends StatefulWidget {
  const _AdaptiveCompactScroll({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController? controller;
  final Widget child;

  @override
  State<_AdaptiveCompactScroll> createState() => _AdaptiveCompactScrollState();
}

final class _AdaptiveCompactScrollState extends State<_AdaptiveCompactScroll> {
  bool _canScroll = false;

  @override
  void initState() {
    super.initState();
    _scheduleMetricsCheck();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveCompactScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMetricsCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMetricsCheck();
  }

  void _scheduleMetricsCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = widget.controller;
      final canScroll =
          controller != null &&
          controller.hasClients &&
          controller.position.maxScrollExtent > 0.5;
      if (canScroll != _canScroll) setState(() => _canScroll = canScroll);
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: widget.controller,
    physics: _canScroll
        ? const ClampingScrollPhysics()
        : const NeverScrollableScrollPhysics(),
    child: widget.child,
  );
}

final class _TimelineMetadata extends StatelessWidget {
  const _TimelineMetadata({required this.item, required this.placeName});

  final FeedItem item;
  final String placeName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = item.gelatoType['name'] as String;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      type,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: AppStrings.timelineRatingSemantic(item.rating),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.star_rounded, size: 20, color: colors.primary),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        AppStrings.timelineRatingSemantic(item.rating),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: item.flavors
                .map(
                  (flavor) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(flavor['name'] as String),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (item.reviewText.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.reviewText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens the branded share-card preview. Uses the theme's `onSurface` ink
/// (Fondente in light mode) rather than a hardcoded token so the icon stays
/// legible against the card header in dark theme too.
final class _ShareIconButton extends StatelessWidget {
  const _ShareIconButton({
    required this.placeName,
    required this.rating,
    required this.flavors,
    required this.photo,
  });

  final String placeName;
  final int rating;
  final List<Map<String, dynamic>> flavors;
  final Widget photo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.shareCardSemantic(placeName),
      button: true,
      child: ExcludeSemantics(child: _button(context)),
    );
  }

  Widget _button(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('timeline-card-share'),
      tooltip: AppStrings.shareCardTooltip,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: Theme.of(context).colorScheme.onSurface,
      icon: const Icon(Icons.ios_share_rounded),
      onPressed: () => showShareCheckInPreview(
        context,
        placeName: placeName,
        rating: rating,
        flavors: flavors,
        photo: photo,
      ),
    );
  }
}
