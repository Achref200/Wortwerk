import 'package:flutter/material.dart';

import 'motion.dart';

/// Draws a soft halo behind [child] that pulses outward on a loop.
///
/// Used for the current level node (scale 1→1.06, halo 0.4→0, 1.6 s — SPEC
/// §5.4) and the speaking mic ring. Under reduced motion the halo settles at a
/// single static opacity instead of animating.
final class PulseHalo extends StatefulWidget {
  const PulseHalo({
    required this.child,
    super.key,
    this.color = const Color(0xFFE8590C),
    this.minScale = 1.0,
    this.maxScale = 1.06,
    this.period = const Duration(milliseconds: 1600),
    this.active = true,
    this.haloOpacity = 0.4,
    this.haloSize = 56,
  });

  final Widget child;

  /// Halo tint; defaults to the streak orange token.
  final Color color;

  final double minScale;
  final double maxScale;
  final Duration period;

  /// Stops the loop while still reserving the outer breathing room.
  final bool active;

  /// Starting opacity of the halo at the top of the pulse.
  final double haloOpacity;

  /// Diameter of the circular halo drawn behind [child].
  final double haloSize;

  @override
  State<PulseHalo> createState() => _PulseHaloState();
}

final class _PulseHaloState extends State<PulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    _sync();
  }

  void _sync() {
    if (!widget.active || prefersReducedMotion(context)) {
      // Rest at the top of the pulse so the halo is a static, subtle ring.
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
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
        // 0 → 1 → 0 so the ring breathes out and back in.
        final wave = (1 - (2 * _controller.value - 1).abs()).clamp(0.0, 1.0);
        final scale =
            widget.minScale + (widget.maxScale - widget.minScale) * wave;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: widget.haloOpacity * (1 - wave),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                  child: SizedBox.square(dimension: widget.haloSize),
                ),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}
