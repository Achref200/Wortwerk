import 'package:flutter/material.dart';

import 'motion.dart';

/// Axis a shared-axis transition travels along.
enum SharedAxisAxis { horizontal, vertical }

/// Shared-axis transition used for pushes, tab switches and onboarding steps
/// (SPEC §5.7): outgoing content moves 0 → −24 px, incoming 24 → 0, both fading.
final class SharedAxisTransition extends StatelessWidget {
  const SharedAxisTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
    this.axis = SharedAxisAxis.horizontal,
    this.distance = 24,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  final SharedAxisAxis axis;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return child;
    }
    final incoming = CurvedAnimation(
      parent: animation,
      curve: MotionCurves.standard,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([incoming, outgoing]),
      child: child,
      builder: (context, child) {
        final inT = incoming.value.clamp(0.0, 1.0);
        final outT = outgoing.value.clamp(0.0, 1.0);
        final shift = distance * (1 - inT) - distance * outT;
        final offset = axis == SharedAxisAxis.horizontal
            ? Offset(shift, 0)
            : Offset(0, shift);
        return Opacity(
          opacity: (inT * (1 - outT)).clamp(0.0, 1.0),
          child: Transform.translate(offset: offset, child: child),
        );
      },
    );
  }
}

/// Fade-through transition for full-screen takeovers such as lessons and
/// level-up (SPEC §5.7): incoming fades and scales up while the outgoing fades.
final class FadeThroughTransition extends StatelessWidget {
  const FadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
    this.beginScale = 0.92,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  final double beginScale;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return child;
    }
    final incoming = CurvedAnimation(
      parent: animation,
      curve: MotionCurves.standard,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([incoming, outgoing]),
      child: child,
      builder: (context, child) {
        final inT = incoming.value.clamp(0.0, 1.0);
        final outT = outgoing.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: (inT * (1 - outT)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: beginScale + (1 - beginScale) * inT,
            child: child,
          ),
        );
      },
    );
  }
}

/// A [PageRoute] that pushes [child] with a shared-axis transition.
final class SharedAxisPage<T> extends PageRouteBuilder<T> {
  SharedAxisPage({
    required Widget child,
    this.axis = SharedAxisAxis.horizontal,
    super.settings,
    Duration duration = MotionDurations.transition,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             SharedAxisTransition(
               animation: animation,
               secondaryAnimation: secondaryAnimation,
               axis: axis,
               child: child,
             ),
       );

  final SharedAxisAxis axis;
}

/// A [PageRoute] that pushes [child] with a fade-through transition.
final class FadeThroughPage<T> extends PageRouteBuilder<T> {
  FadeThroughPage({
    required Widget child,
    super.settings,
    Duration duration = MotionDurations.transition,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         pageBuilder: (context, animation, secondaryAnimation) => child,
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             FadeThroughTransition(
               animation: animation,
               secondaryAnimation: secondaryAnimation,
               child: child,
             ),
       );
}
