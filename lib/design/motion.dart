import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

abstract final class AppMotion {
  static const press = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasized = Duration(milliseconds: 360);

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
