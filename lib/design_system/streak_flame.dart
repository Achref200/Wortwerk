import 'package:flutter/material.dart';

import 'wortwerk_theme.dart';

final class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 760),
      curve: Curves.easeOutBack,
      builder: (context, progress, child) => SizedBox(
        width: size + 12,
        height: size + 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: WortwerkColors.streak.withValues(
                      alpha: 0.13 * (1 - progress.clamp(0, 1)),
                    ),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.94 + 0.06 * progress.clamp(0, 1),
              child: CustomPaint(
                size: Size(size, size),
                painter: const _FlamePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FlamePainter extends CustomPainter {
  const _FlamePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 64;
    canvas.save();
    canvas.scale(scale);

    final outer = Path()
      ..moveTo(32, 3)
      ..cubicTo(37, 17, 53, 22, 54, 39)
      ..cubicTo(55, 53, 45, 62, 32, 62)
      ..cubicTo(17, 62, 8, 52, 10, 38)
      ..cubicTo(11, 27, 19, 22, 22, 14)
      ..cubicTo(25, 20, 29, 23, 29, 29)
      ..cubicTo(35, 23, 37, 14, 32, 3)
      ..close();
    canvas.drawShadow(outer, WortwerkColors.flameRed, 5, false);
    canvas.drawPath(outer, Paint()..color = WortwerkColors.flameRed);

    final middle = Path()
      ..moveTo(32, 23)
      ..cubicTo(36, 31, 46, 35, 45, 45)
      ..cubicTo(45, 54, 39, 58, 32, 58)
      ..cubicTo(23, 58, 18, 52, 19, 44)
      ..cubicTo(20, 38, 25, 34, 27, 29)
      ..cubicTo(29, 33, 32, 36, 32, 40)
      ..cubicTo(36, 35, 36, 30, 32, 23)
      ..close();
    canvas.drawPath(middle, Paint()..color = WortwerkColors.streak);

    final core = Path()
      ..moveTo(32, 40)
      ..cubicTo(35, 44, 39, 47, 38, 51)
      ..cubicTo(37, 55, 34, 57, 31, 57)
      ..cubicTo(27, 57, 25, 54, 26, 50)
      ..cubicTo(27, 47, 30, 45, 31, 42)
      ..close();
    canvas.drawPath(core, Paint()..color = WortwerkColors.flameCore);

    final emberPaint = Paint()
      ..color = WortwerkColors.flameCore
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(8, 43), 1.8, emberPaint);
    canvas.drawCircle(const Offset(54, 28), 1.4, emberPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => false;
}
