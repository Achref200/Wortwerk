import 'package:flutter/material.dart';

import 'motion.dart';

/// Counts a number up (or down) to [value] whenever it changes.
///
/// Used anywhere a metric changes — XP, words learned, streak (SPEC §5.9).
/// The animation always continues from the value currently on screen, so a
/// rebuild never restarts the count from zero.
final class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    required this.value,
    super.key,
    this.style,
    this.duration = MotionDurations.counter,
    this.curve = MotionCurves.standard,
    this.prefix = '',
    this.suffix = '',
    this.textAlign,
    this.semanticsLabel,
  });

  /// Final value the counter settles on.
  final int value;

  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final TextAlign? textAlign;

  /// Screen-reader label; defaults to the final value so reader users never
  /// hear intermediate numbers.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final effective = motionDuration(context, duration);
    return Semantics(
      label: semanticsLabel ?? '$prefix$value$suffix',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: effective,
          curve: curve,
          builder: (context, current, _) => Text(
            '$prefix$current$suffix',
            style: style,
            textAlign: textAlign,
          ),
        ),
      ),
    );
  }
}

/// Odometer-style number that rolls each digit vertically when it changes.
///
/// Prefer this over [AnimatedCounter] for compact, high-frequency numbers such
/// as the streak count where a full count-up would be noisy (SPEC §5.2).
final class RollingDigits extends StatelessWidget {
  const RollingDigits({
    required this.value,
    super.key,
    this.style,
    this.duration = MotionDurations.progress,
    this.curve = MotionCurves.standard,
    this.minDigits = 1,
    this.semanticsLabel,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  /// Left-pads the number with zeros to at least this many digits, which keeps
  /// the widget from jumping in width as it rolls.
  final int minDigits;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final text = value.abs().toString().padLeft(minDigits, '0');
    final digitWidth = _measureDigit(context, effectiveStyle);
    final digitHeight = _digitHeight(context, effectiveStyle);
    final effective = motionDuration(context, duration);

    return Semantics(
      label: semanticsLabel ?? '$value',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final character in text.split(''))
              _RollingDigit(
                character: character,
                width: digitWidth,
                height: digitHeight,
                duration: effective,
                curve: curve,
                style: effectiveStyle,
              ),
          ],
        ),
      ),
    );
  }
}

final class _RollingDigit extends StatelessWidget {
  const _RollingDigit({
    required this.character,
    required this.width,
    required this.height,
    required this.duration,
    required this.curve,
    required this.style,
  });

  final String character;
  final double width;
  final double height;
  final Duration duration;
  final Curve curve;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final target = int.parse(character).toDouble();
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        // The 0–9 strip is taller than the visible window; `OverflowBox` lets it
        // lay out at its natural height so the [ClipRect] crops it cleanly
        // instead of the column reporting a layout overflow.
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          // `begin` equals `end` on first build so a fresh widget does not roll
          // up from zero; on updates the tween continues from the previous digit.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: target, end: target),
            duration: duration,
            curve: curve,
            builder: (context, current, _) => Transform.translate(
              offset: Offset(0, -current * height),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var digit = 0; digit <= 9; digit++)
                    SizedBox(
                      width: width,
                      height: height,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text('$digit', style: style),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _measureDigit(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: '8',
      style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

double _digitHeight(BuildContext context, TextStyle style) {
  final fallback = MediaQuery.textScalerOf(context);
  final fontSize =
      style.fontSize ??
      DefaultTextStyle.of(context).style.fontSize ??
      fallback.scale(14);
  return fontSize * (style.height ?? 1.2);
}
