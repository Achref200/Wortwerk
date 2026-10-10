import 'package:flutter/material.dart';

import 'motion.dart';

/// Wraps a tappable surface with the canonical press scale (SPEC §5.9).
///
/// Buttons press to 0.98 in 100 ms and release with a 160 ms spring. Reduced
/// motion keeps the surface static while still delivering the tap, so the
/// interaction never becomes unreachable.
final class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    super.key,
    this.onPressed,
    this.onLongPress,
    this.pressedScale = 0.98,
    this.pressDuration = MotionDurations.press,
    this.releaseDuration = MotionDurations.release,
    this.behavior = HitTestBehavior.opaque,
    this.semanticsLabel,
    this.semanticsButton = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final HitTestBehavior behavior;
  final String? semanticsLabel;
  final bool semanticsButton;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

final class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool pressed) {
    if (!_enabled || _pressed == pressed) {
      return;
    }
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    final scale = _pressed && !reduced ? widget.pressedScale : 1.0;
    return Semantics(
      button: widget.semanticsButton,
      enabled: _enabled,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: scale,
          duration: motionDuration(
            context,
            _pressed ? widget.pressDuration : widget.releaseDuration,
          ),
          curve: _pressed ? MotionCurves.standard : MotionCurves.reward,
          child: widget.child,
        ),
      ),
    );
  }
}
