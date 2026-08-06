import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_tokens.dart';
import '../../models/feed_item.dart';
import '../../repositories/timeline_repository.dart';
import 'timeline_editorial_card.dart';
import '../../constants/app_strings.dart';

const Duration timelineDeckSettleDuration = Duration(milliseconds: 480);
const Duration timelineDeckWheelLock = Duration(milliseconds: 350);
const double timelineDeckDragThreshold = 64;
const double timelineDeckFlingThreshold = 450;
const double timelineDeckOvershoot = 10;
const double timelineDeckNextPeek = 40;

int timelineDeckNavigationDirection({
  required double dragOffset,
  required double velocity,
}) {
  if (velocity < -timelineDeckFlingThreshold) return 1;
  if (velocity > timelineDeckFlingThreshold) return -1;
  if (dragOffset < -timelineDeckDragThreshold) return 1;
  if (dragOffset > timelineDeckDragThreshold) return -1;
  return 0;
}

final class TimelineCompactDeck extends StatefulWidget {
  const TimelineCompactDeck({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.failure,
    required this.onLoadMore,
    required this.onRefresh,
  });

  final List<FeedItem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final TimelineFailure? failure;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;

  @override
  State<TimelineCompactDeck> createState() => _TimelineCompactDeckState();
}

final class _TimelineCompactDeckState extends State<TimelineCompactDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController;
  Animation<double>? _settleAnimation;
  int _currentIndex = 0;
  double _dragOffset = 0;
  double _cardExtent = 1;
  int? _pendingIndex;
  VelocityTracker? _dragVelocityTracker;
  bool _pointerEligibleForDrag = false;
  bool _dragAccepted = false;
  Timer? _wheelTimer;
  bool _wheelLocked = false;
  final Set<int> _paginationRequestedForLengths = <int>{};
  final Map<String, ScrollController> _cardScrollControllers =
      <String, ScrollController>{};

  @override
  void initState() {
    super.initState();
    _settleController =
        AnimationController(vsync: this, duration: timelineDeckSettleDuration)
          ..addListener(() {
            final animation = _settleAnimation;
            if (animation != null && mounted) {
              setState(() => _dragOffset = animation.value);
            }
          });
    _settleController.addStatusListener(_finishSettle);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestAtPenultimate(),
    );
  }

  @override
  void didUpdateWidget(covariant TimelineCompactDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.isNotEmpty && widget.items.isNotEmpty) {
      final safeOldIndex = _currentIndex.clamp(0, oldWidget.items.length - 1);
      final currentId = oldWidget.items[safeOldIndex].checkInId;
      final preserved = widget.items.indexWhere(
        (item) => item.checkInId == currentId,
      );
      _currentIndex = preserved >= 0
          ? preserved
          : _currentIndex.clamp(0, widget.items.length - 1);
    } else {
      _currentIndex = 0;
    }
    final currentIds = widget.items.map((item) => item.checkInId).toSet();
    final removedIds = _cardScrollControllers.keys
        .where((id) => !currentIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _cardScrollControllers.remove(id)?.dispose();
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestAtPenultimate(),
    );
  }

  @override
  void dispose() {
    _wheelTimer?.cancel();
    for (final controller in _cardScrollControllers.values) {
      controller.dispose();
    }
    _settleController
      ..removeStatusListener(_finishSettle)
      ..dispose();
    super.dispose();
  }

  void _finishSettle(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final pending = _pendingIndex;
    setState(() {
      if (pending != null) _currentIndex = pending;
      _pendingIndex = null;
      _settleAnimation = null;
      _dragOffset = 0;
    });
    _requestAtPenultimate();
  }

  void _requestAtPenultimate() {
    if (!mounted || !widget.hasMore || widget.items.isEmpty) return;
    if (_currentIndex < widget.items.length - 2) return;
    if (!_paginationRequestedForLengths.add(widget.items.length)) return;
    unawaited(widget.onLoadMore());
  }

  bool _canMove(int direction) {
    final target = _currentIndex + direction;
    return target >= 0 && target < widget.items.length;
  }

  void _move(int direction) {
    if (_settleController.isAnimating) return;
    if (!_canMove(direction)) {
      if (direction > 0 && widget.hasMore && !widget.isLoadingMore) {
        unawaited(widget.onLoadMore());
      }
      _resetDrag();
      return;
    }
    final targetIndex = _currentIndex + direction;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _currentIndex = targetIndex;
        _dragOffset = 0;
      });
      _requestAtPenultimate();
      return;
    }

    final destination = -direction * _cardExtent;
    final overshoot = destination - direction * timelineDeckOvershoot;
    _pendingIndex = targetIndex;
    _settleAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _dragOffset, end: overshoot),
        weight: 84,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: overshoot, end: destination),
        weight: 16,
      ),
    ]).animate(_settleController);
    _settleController.forward(from: 0);
  }

  void _resetDrag() {
    if (!mounted || _dragOffset == 0) return;
    setState(() => _dragOffset = 0);
  }

  void _trackPointerDown(PointerDownEvent event) {
    _dragVelocityTracker = null;
    _dragAccepted = false;
    _pointerEligibleForDrag = !_settleController.isAnimating;
    if (!_pointerEligibleForDrag) return;
    _dragVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _trackPointerMove(PointerMoveEvent event) {
    if (_settleController.isAnimating || _dragVelocityTracker == null) return;
    _dragVelocityTracker?.addPosition(event.timeStamp, event.position);
  }

  void _trackPointerUp(PointerUpEvent event) {
    final tracker = _dragVelocityTracker;
    scheduleMicrotask(() {
      if (!identical(_dragVelocityTracker, tracker)) return;
      _pointerEligibleForDrag = false;
      _dragVelocityTracker = null;
    });
  }

  void _trackPointerCancel(PointerCancelEvent event) {
    _pointerEligibleForDrag = false;
    _dragAccepted = false;
    final tracker = _dragVelocityTracker;
    scheduleMicrotask(() {
      if (identical(_dragVelocityTracker, tracker)) {
        _dragVelocityTracker = null;
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragAccepted = _pointerEligibleForDrag && !_settleController.isAnimating;
    if (!_dragAccepted) return;
    _resetDrag();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_dragAccepted || _settleController.isAnimating) return;
    final offset = _dragOffset + (details.primaryDelta ?? 0);
    final bounded = offset.clamp(-_cardExtent * 0.4, _cardExtent * 0.4);
    setState(() => _dragOffset = bounded);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_dragAccepted) {
      _dragVelocityTracker = null;
      return;
    }
    _dragAccepted = false;
    final offset = _dragOffset;
    final trackedVelocity =
        _dragVelocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _dragVelocityTracker = null;
    final recognizerVelocity = details.primaryVelocity ?? 0;
    final velocity = trackedVelocity.abs() > recognizerVelocity.abs()
        ? trackedVelocity
        : recognizerVelocity;
    final direction = timelineDeckNavigationDirection(
      dragOffset: offset,
      velocity: velocity,
    );
    if (direction < 0 && _currentIndex == 0) {
      _resetDrag();
      unawaited(widget.onRefresh());
      return;
    }
    if (direction != 0) {
      _move(direction);
    } else {
      _resetDrag();
    }
  }

  void _onVerticalDragCancel() {
    _dragVelocityTracker = null;
    _dragAccepted = false;
    _resetDrag();
  }

  ScrollController? get _currentCardScrollController {
    if (widget.items.isEmpty) return null;
    return _cardScrollControllers[widget.items[_currentIndex].checkInId];
  }

  bool _currentCardCanScroll(double dy) {
    final controller = _currentCardScrollController;
    if (controller == null || !controller.hasClients) return false;
    final position = controller.position;
    if (dy > 0) return position.pixels < position.maxScrollExtent - 0.5;
    return position.pixels > position.minScrollExtent + 0.5;
  }

  bool _isInsideCurrentScrollViewport(Offset globalPosition) {
    final controller = _currentCardScrollController;
    if (controller == null || !controller.hasClients) return false;
    final renderObject = controller.position.context.notificationContext
        ?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;
    final localPosition = renderObject.globalToLocal(globalPosition);
    return (Offset.zero & renderObject.size).contains(localPosition);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _wheelLocked) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    if (_currentCardCanScroll(dy)) {
      if (!_isInsideCurrentScrollViewport(event.position)) {
        _currentCardScrollController!.position.pointerScroll(dy);
      }
      return;
    }
    _wheelLocked = true;
    _wheelTimer?.cancel();
    _wheelTimer = Timer(timelineDeckWheelLock, () {
      _wheelLocked = false;
    });
    _move(dy > 0 ? 1 : -1);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      _move(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final cardHeight = (height - timelineDeckNextPeek - 16).clamp(
          0.0,
          height,
        );
        _cardExtent = cardHeight + 8;
        return SizedBox(
          key: const ValueKey<String>('timeline-compact-refresh'),
          height: height,
          child: SizedBox(
            key: const ValueKey<String>('timeline-compact-deck'),
            height: height,
            child: Focus(
              autofocus: true,
              onKeyEvent: _onKeyEvent,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _trackPointerDown,
                onPointerMove: _trackPointerMove,
                onPointerUp: _trackPointerUp,
                onPointerCancel: _trackPointerCancel,
                onPointerSignal: _onPointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  onVerticalDragCancel: _onVerticalDragCancel,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: <Widget>[
                      for (final index in _mountedIndexes())
                        _positionedCard(index, cardHeight),
                      _DeckControls(
                        canPrevious: _canMove(-1),
                        canNext: _canMove(1) || widget.hasMore,
                        isLoadingMore: widget.isLoadingMore,
                        onPrevious: () => _move(-1),
                        onNext: () => _move(1),
                      ),
                      if (widget.failure != null)
                        Positioned(
                          left: AppSpacing.display,
                          right: AppSpacing.display,
                          bottom: AppSpacing.xs,
                          child: _DeckPaginationError(
                            message: widget.failure!.message,
                            onRetry: widget.onLoadMore,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Iterable<int> _mountedIndexes() sync* {
    final first = (_currentIndex - 1).clamp(0, widget.items.length - 1);
    final last = (_currentIndex + 1).clamp(0, widget.items.length - 1);
    for (var index = first; index <= last; index++) {
      yield index;
    }
  }

  Widget _positionedCard(int index, double cardHeight) {
    final item = widget.items[index];
    final relative = index - _currentIndex;
    final top = 8 + relative * _cardExtent + _dragOffset;
    final current = index == _currentIndex;
    final card = TimelineEditorialCard(
      item: item,
      compact: true,
      height: cardHeight,
      compactScrollController: _cardScrollControllers.putIfAbsent(
        item.checkInId,
        ScrollController.new,
      ),
    );
    return Positioned(
      key: ValueKey<String>('timeline-deck-card-${item.checkInId}'),
      top: top,
      left: AppSpacing.md,
      right: AppSpacing.md,
      height: cardHeight,
      child: IgnorePointer(
        ignoring: !current,
        child: current
            ? Semantics(
                key: ValueKey<String>(
                  'timeline-deck-semantics-${item.checkInId}',
                ),
                container: true,
                explicitChildNodes: true,
                label: AppStrings.timelineCardPosition(index + 1, widget.items.length),
                selected: true,
                child: card,
              )
            : ExcludeSemantics(child: card),
      ),
    );
  }
}

final class _DeckControls extends StatelessWidget {
  const _DeckControls({
    required this.canPrevious,
    required this.canNext,
    required this.isLoadingMore,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canPrevious;
  final bool canNext;
  final bool isLoadingMore;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Positioned(
    left: AppSpacing.md,
    right: AppSpacing.md,
    bottom: AppSpacing.xs,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton.filledTonal(
          key: const ValueKey<String>('timeline-previous'),
          constraints: const BoxConstraints(
            minWidth: AppLayout.touchTarget,
            minHeight: AppLayout.touchTarget,
          ),
          tooltip: AppStrings.timelinePrevTooltip,
          onPressed: canPrevious ? onPrevious : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton.filled(
          key: const ValueKey<String>('timeline-next'),
          constraints: const BoxConstraints(
            minWidth: AppLayout.touchTarget,
            minHeight: AppLayout.touchTarget,
          ),
          tooltip: isLoadingMore
              ? AppStrings.timelineLoadingMore
              : AppStrings.timelineNextTooltip,
          onPressed: canNext && !isLoadingMore ? onNext : null,
          icon: isLoadingMore
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    ),
  );
}

final class _DeckPaginationError extends StatelessWidget {
  const _DeckPaginationError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(AppRadii.control),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        TextButton(
          key: const ValueKey<String>('timeline-retry-page'),
          onPressed: () => unawaited(onRetry()),
          child: const Text(AppStrings.retry),
        ),
      ],
    ),
  );
}
