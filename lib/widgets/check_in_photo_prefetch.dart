import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/media_provider.dart';

/// Starts loading check-in photos that are about to come on screen, so the
/// next swipe shows the photo instead of its placeholder. Renders nothing.
///
/// [mediaBytesProvider] is not autoDispose, so a read without a listener keeps
/// the bytes for the card that later watches the same key.
final class CheckInPhotoPrefetch extends ConsumerStatefulWidget {
  const CheckInPhotoPrefetch({super.key, required this.paths});

  final List<String> paths;

  @override
  ConsumerState<CheckInPhotoPrefetch> createState() =>
      _CheckInPhotoPrefetchState();
}

final class _CheckInPhotoPrefetchState
    extends ConsumerState<CheckInPhotoPrefetch> {
  @override
  void initState() {
    super.initState();
    _prefetch(widget.paths);
  }

  @override
  void didUpdateWidget(covariant CheckInPhotoPrefetch oldWidget) {
    super.didUpdateWidget(oldWidget);
    final known = oldWidget.paths.toSet();
    _prefetch(widget.paths.where((path) => !known.contains(path)));
  }

  void _prefetch(Iterable<String> paths) {
    for (final path in paths) {
      // Failures surface, with a retry, when the card itself is shown.
      ref
          .read(
            mediaBytesProvider(
              AuthenticatedMediaKey(path, checkInMediaMaxBytes),
            ).future,
          )
          .ignore();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
