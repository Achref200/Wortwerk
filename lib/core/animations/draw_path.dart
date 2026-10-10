import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Draws a [path] stroke on with a [PathMetric] sweep (SPEC §5.3, §5.4).
///
/// Under reduced motion the path appears fully drawn immediately. The public
/// [DrawPathPainter] exposes [DrawPathPainter.fraction] so tests can assert the
/// settled end value without pixel diffing.
final class DrawPath extends StatelessWidget {
  const DrawPath({
    required this.path,
    super.key,
    this.duration = MotionDurations.draw,
    this.curve = MotionCurves.standard,
    this.color = const Color(0xFF1E1D22),
    this.strokeWidth = 2,
    this.strokeCap = StrokeCap.round,
    this.size,
  });

  final Path path;
  final Duration duration;
  final Curve curve;
  final Color color;
  final double strokeWidth;
  final StrokeCap strokeCap;

  /// Reserves a layout size; pass `null` to let the parent constrain it.
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final effective = motionDuration(context, duration);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: effective,
      curve: curve,
      builder: (context, fraction, _) => CustomPaint(
        size: size ?? Size.zero,
        painter: DrawPathPainter(
          path: path,
          fraction: fraction,
          color: color,
          strokeWidth: strokeWidth,
          strokeCap: strokeCap,
        ),
      ),
    );
  }
}

/// Paints the first [fraction] of [path] measured by arc length.
final class DrawPathPainter extends CustomPainter {
  const DrawPathPainter({
    required this.path,
    required this.fraction,
    this.color = const Color(0xFF1E1D22),
    this.strokeWidth = 2,
    this.strokeCap = StrokeCap.round,
  });

  final Path path;
  final double fraction;
  final Color color;
  final double strokeWidth;
  final StrokeCap strokeCap;

  @override
  void paint(Canvas canvas, Size size) {
    final clamped = fraction.clamp(0.0, 1.0);
    if (clamped <= 0) {
      return;
    }
    final metrics = path.computeMetrics().toList(growable: false);
    final total = metrics.fold<double>(0, (sum, metric) => sum + metric.length);
    if (total == 0) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap
      ..strokeJoin = StrokeJoin.round;

    if (clamped >= 1) {
      canvas.drawPath(path, paint);
      return;
    }

    var remaining = total * clamped;
    final drawn = Path();
    for (final metric in metrics) {
      if (remaining <= 0) {
        break;
      }
      final length = math.min(metric.length, remaining);
      drawn.addPath(metric.extractPath(0, length), Offset.zero);
      remaining -= length;
    }
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(DrawPathPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.strokeCap != strokeCap;
}
