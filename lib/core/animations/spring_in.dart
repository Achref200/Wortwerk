import 'package:flutter/material.dart';

import 'motion.dart';

/// Springs its [child] into place from a smaller/offset state (SPEC §5.6).
///
/// Used for reward cards, Fritz bouncing in, and list entrances. The [delay]
/// lets callers build stagger without extra widgets. Reduced motion skips both
/// the delay and the interpolation and shows the final state at once.
final class SpringIn extends StatefulWidget {
  const SpringIn({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.curve = MotionCurves.reward,
    this.beginScale = 0.6,
    this.beginOffset = Offset.zero,
    this.beginOpacity = 0,
  });

  final Widget child;

  /// Holds the child hidden for this long before springing in.
  final Duration delay;

  final Duration duration;
  final Curve curve;
  final double beginScale;
  final Offset beginOffset;
  final double beginOpacity;

  @override
  State<SpringIn> createState() => _SpringInState();
}

final class _SpringInState extends State<SpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _totalDuration,
  );

  bool _started = false;

  /// The delay is folded into the controller duration so the entrance is a
  /// single, frame-driven animation rather than a wall-clock timer.
  Duration get _totalDuration => widget.delay + widget.duration;

  /// Fraction of just the spring, discounting the leading hold.
  double get _springProgress {
    final total = _totalDuration.inMicroseconds;
    if (total <= 0) {
      return 1;
    }
    final offset = widget.delay.inMicroseconds / total;
    final local = (1 - offset) <= 0
        ? 1.0
        : (_controller.value - offset) / (1 - offset);
    return local.clamp(0.0, 1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (prefersReducedMotion(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void didUpdateWidget(SpringIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _totalDuration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = widget.curve.transform(_springProgress);
        final scale = widget.beginScale + (1 - widget.beginScale) * t;
        final offset = widget.beginOffset * (1 - t);
        final opacity =
            (widget.beginOpacity + (1 - widget.beginOpacity) * t).clamp(
              0.0,
              1.0,
            );
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

/// Applies a rise-and-fade entrance to a list item by [index] (SPEC §5.6).
///
/// Each item waits `index * step` before springing in, which produces the
/// "reward cards rise in with 120 ms stagger" choreography.
final class Staggered extends StatelessWidget {
  const Staggered({
    required this.index,
    required this.child,
    super.key,
    this.step = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 420),
    this.beginOffset = const Offset(0, 12),
    this.beginScale = 1,
    this.curve = MotionCurves.reward,
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration duration;
  final Offset beginOffset;
  final double beginScale;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final delay = index <= 0 ? Duration.zero : step * index;
    return SpringIn(
      delay: motionDuration(context, delay),
      duration: duration,
      curve: curve,
      beginScale: beginScale,
      beginOffset: beginOffset,
      child: child,
    );
  }
}
