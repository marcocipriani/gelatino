import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

abstract final class AppMotion {
  static const press = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasized = Duration(milliseconds: 360);

  /// Gap between siblings entering one after another.
  static const stagger = Duration(milliseconds: 50);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// The iOS sheet curve: quick departure, long soft landing, no bounce.
  static const glide = Cubic(0.32, 0.72, 0, 1);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when the user asked for less motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

extension AppEntrance on Widget {
  /// Fades and lifts in once, on first build. [order] staggers siblings;
  /// capped so a long list never waits on its tail.
  Widget entrance(BuildContext context, {int order = 0, double lift = 12}) =>
      _Entrance(order: order.clamp(0, 6), lift: lift, child: this);
}

// ponytail: not flutter_animate, whose Animate always schedules a Timer that
// widget tests then report as pending.
class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.order,
    required this.lift,
    required this.child,
  });

  final int order;
  final double lift;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    final delay = AppMotion.stagger * widget.order;
    final total = delay + AppMotion.emphasized;
    final start = delay.inMicroseconds / total.inMicroseconds;
    final fadeEnd =
        (delay + AppMotion.standard).inMicroseconds / total.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: total);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, fadeEnd, curve: AppMotion.enter),
    );
    _lift = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: AppMotion.glide),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) return;
    AppMotion.reduced(context) ? _controller.value = 1 : _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: AnimatedBuilder(
      animation: _lift,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, widget.lift * (1 - _lift.value)),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

/// [ReducedMotionScope] only reaches code that asks MediaQuery. Sheets,
/// dialogs, chips and switches ask the binding, so it has to answer too.
mixin ReduceMotionBinding on SemanticsBinding {
  @override
  bool get disableAnimations =>
      super.disableAnimations ||
      platformDispatcher.accessibilityFeatures.reduceMotion;
}

class GelatinoBinding extends WidgetsFlutterBinding with ReduceMotionBinding {
  static void ensureInitialized() {
    // The integration test installs its own binding first. The type is only
    // known in debug, which is how that test runs; in release it is null and
    // this is always the first binding.
    if (BindingBase.debugBindingType() != null) return;
    GelatinoBinding();
    // Web builds no semantics until someone finds a hidden button, so screen
    // readers met a blank page. Not under the test binding, which owns its
    // handles and fails on any left open.
    if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  }
}

/// iOS reports Reduce Motion as `reduceMotion`, which [MediaQuery] does not
/// expose; only Android's `disableAnimations` gets through. Folding one into
/// the other here makes every `disableAnimationsOf` check in the app work.
class ReducedMotionScope extends StatefulWidget {
  const ReducedMotionScope({required this.child, super.key});

  final Widget child;

  @override
  State<ReducedMotionScope> createState() => _ReducedMotionScopeState();
}

class _ReducedMotionScopeState extends State<ReducedMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = View.of(
      context,
    ).platformDispatcher.accessibilityFeatures.reduceMotion;
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduceMotion,
      ),
      child: widget.child,
    );
  }
}

/// Platform push transition, reduced to a cross-fade when motion is reduced.
/// The platform builder stays mounted so iOS swipe-back keeps working.
class MotionAwareTransitionsBuilder extends PageTransitionsBuilder {
  const MotionAwareTransitionsBuilder(this.platform);

  final PageTransitionsBuilder platform;

  @override
  Duration get transitionDuration => platform.transitionDuration;

  @override
  Duration get reverseTransitionDuration => platform.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      platform.delegatedTransition == null
      ? null
      : (context, animation, secondary, allowSnapshotting, child) =>
            AppMotion.reduced(context)
            ? child
            : platform.delegatedTransition!(
                context,
                animation,
                secondary,
                allowSnapshotting,
                child,
              );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!AppMotion.reduced(context) || route.popGestureInProgress) {
      return platform.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return platform.buildTransitions(
      route,
      context,
      kAlwaysCompleteAnimation,
      kAlwaysDismissedAnimation,
      FadeTransition(opacity: animation, child: child),
    );
  }
}
