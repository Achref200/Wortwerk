import 'package:flutter/material.dart';

import 'wortwerk_theme.dart';

final class FritzAvatar extends StatelessWidget {
  const FritzAvatar({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: const _FritzPainter(),
        child: Semantics(
          image: true,
          label: 'Fritz, dein Deutsch-Begleiter',
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

final class AnimatedFritzAvatar extends StatefulWidget {
  const AnimatedFritzAvatar({super.key, this.size = 72});

  final double size;

  @override
  State<AnimatedFritzAvatar> createState() => _AnimatedFritzAvatarState();
}

final class _AnimatedFritzAvatarState extends State<AnimatedFritzAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addStatusListener(_breatheOnce);

  bool _started = false;

  void _breatheOnce(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _breathing.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _breathing.stop();
      _breathing.value = 0.5;
    } else if (!_started) {
      _started = true;
      _breathing.forward();
    }
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathing,
      child: FritzAvatar(size: widget.size),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -2 + _breathing.value * 4),
        child: child,
      ),
    );
  }
}

final class _FritzPainter extends CustomPainter {
  const _FritzPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final outline = Paint()
      ..color = WortwerkColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final orb = Paint()
      ..color = const Color(0xFFDDF1E8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(50, 60), 35, orb);
    canvas.drawCircle(const Offset(50, 60), 35, outline);

    final earFill = Paint()..color = const Color(0xFFBFE3C4);
    canvas.drawCircle(const Offset(16, 61), 7, earFill);
    canvas.drawCircle(const Offset(84, 61), 7, earFill);
    canvas.drawCircle(const Offset(16, 61), 7, outline);
    canvas.drawCircle(const Offset(84, 61), 7, outline);

    final cap = Path()
      ..moveTo(21, 34)
      ..quadraticBezierTo(22, 8, 51, 7)
      ..quadraticBezierTo(76, 7, 79, 31)
      ..lineTo(23, 38)
      ..close();
    canvas.drawPath(cap, Paint()..color = WortwerkColors.ink);
    canvas.drawPath(cap, outline);

    final brim = Path()
      ..moveTo(19, 37)
      ..quadraticBezierTo(49, 34, 82, 29)
      ..lineTo(83, 35)
      ..quadraticBezierTo(51, 42, 21, 43)
      ..close();
    canvas.drawPath(brim, Paint()..color = WortwerkColors.streak);

    final goldBand = Path()
      ..moveTo(20, 40)
      ..quadraticBezierTo(50, 37, 82, 32)
      ..lineTo(82, 35)
      ..quadraticBezierTo(51, 42, 20, 43)
      ..close();
    canvas.drawPath(goldBand, Paint()..color = WortwerkColors.c2);

    final eye = Paint()..color = WortwerkColors.ink;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(39, 59), width: 5, height: 9),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(61, 59), width: 5, height: 9),
      eye,
    );

    final cheek = Paint()..color = const Color(0xFFECA9BD);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(30, 70), width: 9, height: 4),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(70, 70), width: 9, height: 4),
      cheek,
    );

    final smile = Path()
      ..moveTo(45, 72)
      ..quadraticBezierTo(50, 78, 56, 71);
    canvas.drawPath(
      smile,
      Paint()
        ..color = WortwerkColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FritzPainter oldDelegate) => false;
}
