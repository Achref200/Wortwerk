import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Fires a one-shot burst of flat confetti shapes (SPEC §5.6).
///
/// Capped at [maxParticles] (80) so the celebration never janks on a low-end
/// device. Particles are generated from [seed] with a fixed random stream, so
/// a given seed always produces the same burst — which keeps tests and golden
/// frames stable. Under reduced motion nothing is painted.
final class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.particleCount = 80,
    this.duration = const Duration(milliseconds: 1200),
    this.colors = const [
      Color(0xFFE8590C),
      Color(0xFFC0453B),
      Color(0xFFF5C2DC),
      Color(0xFFB9D3EE),
      Color(0xFFBFE3C4),
      Color(0xFFF6E39A),
    ],
    this.seed = 7,
    this.active = true,
    this.onCompleted,
  });

  /// Requested particle count; clamped to [maxParticles].
  final int particleCount;

  final Duration duration;
  final List<Color> colors;
  final int seed;

  /// When false the widget renders nothing and never plays.
  final bool active;

  final VoidCallback? onCompleted;

  /// Hard ceiling from the spec.
  static const int maxParticles = 80;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

final class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late List<ConfettiParticle> _particles = _buildParticles();

  bool get _enabled => widget.active;

  List<ConfettiParticle> _buildParticles() => ConfettiParticle.build(
    count: widget.particleCount.clamp(0, ConfettiBurst.maxParticles),
    colors: widget.colors,
    seed: widget.seed,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled || prefersReducedMotion(context)) {
      return;
    }
    if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward().whenComplete(() {
        if (mounted) {
          widget.onCompleted?.call();
        }
      });
    }
  }

  @override
  void didUpdateWidget(ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.seed != widget.seed ||
        oldWidget.particleCount != widget.particleCount ||
        oldWidget.colors != widget.colors) {
      _particles = _buildParticles();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled || prefersReducedMotion(context)) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
        ),
      ),
    );
  }
}

/// A single flat confetti shape with deterministic launch parameters.
final class ConfettiParticle {
  const ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
    required this.shape,
  });

  /// Builds [count] particles from a seeded random stream.
  static List<ConfettiParticle> build({
    required int count,
    required List<Color> colors,
    required int seed,
  }) {
    final random = math.Random(seed);
    return List.generate(
      count,
      (index) => ConfettiParticle(
        angle: random.nextDouble() * math.pi * 2,
        speed: 0.45 + random.nextDouble() * 0.55,
        size: 5 + random.nextDouble() * 5,
        spin: (random.nextDouble() - 0.5) * 10,
        color: colors[index % colors.length],
        shape: ConfettiShape.values[index % ConfettiShape.values.length],
      ),
    );
  }

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
  final ConfettiShape shape;
}

/// Flat shapes the burst can use.
enum ConfettiShape { square, circle, triangle }

/// Paints [particles] at [progress] (0 → 1).
///
/// Exposed so tests can assert the settled end value.
final class ConfettiPainter extends CustomPainter {
  const ConfettiPainter({required this.particles, required this.progress});

  final List<ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) {
      return;
    }
    final origin = Offset(size.width / 2, size.height * 0.42);
    final reach = size.shortestSide;
    final gravity = size.height * 0.35;

    for (final particle in particles) {
      final travel = particle.speed * reach * progress;
      final x = origin.dx + math.cos(particle.angle) * travel;
      final y =
          origin.dy +
          math.sin(particle.angle) * travel +
          gravity * progress * progress;
      final paint = Paint()..color = particle.color.withValues(
        alpha: (1 - progress).clamp(0.0, 1.0),
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.spin * progress);
      switch (particle.shape) {
        case ConfettiShape.square:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size,
            ),
            paint,
          );
        case ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, particle.size / 2, paint);
        case ConfettiShape.triangle:
          final path = Path()
            ..moveTo(0, -particle.size / 2)
            ..lineTo(particle.size / 2, particle.size / 2)
            ..lineTo(-particle.size / 2, particle.size / 2)
            ..close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}
