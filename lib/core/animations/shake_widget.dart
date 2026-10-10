import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Imperatively triggers a shake on an attached [ShakeWidget].
///
/// Used for wrong answers (±6 px, 3 cycles) and invalid text fields (one 4 px
/// shake) — SPEC §5.5, §5.9.
final class ShakeController extends ChangeNotifier {
  VoidCallback? _handler;

  /// Whether a [ShakeWidget] is currently attached.
  bool get isAttached => _handler != null;

  /// Registers the widget's shake handler. Called by [ShakeWidget].
  void attach(VoidCallback handler) => _handler = handler;

  /// Clears the registered handler. Called by [ShakeWidget] on dispose.
  void detach(VoidCallback handler) {
    if (identical(_handler, handler)) {
      _handler = null;
    }
  }

  /// Runs the shake, if a widget is attached.
  void shake() => _handler?.call();
}

/// Shakes its [child] horizontally when [controller] fires (SPEC §5.10).
///
/// A single damped sine drives the motion so the item always lands back at its
/// original position. Under reduced motion the shake is skipped entirely and
/// the child stays still.
final class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    required this.child,
    super.key,
    this.controller,
    this.magnitude = 6,
    this.cycles = 3,
    this.duration = const Duration(milliseconds: 280),
    this.autoShake = false,
  });

  final Widget child;
  final ShakeController? controller;

  /// Maximum horizontal displacement in logical pixels.
  final double magnitude;

  /// Number of full left/right cycles before settling.
  final double cycles;

  final Duration duration;

  /// Shakes once as soon as the widget is laid out.
  final bool autoShake;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

final class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(_play);
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_play);
      widget.controller?.attach(_play);
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoShake &&
        !_controller.isAnimating &&
        _controller.value == 0) {
      _play();
    }
  }

  void _play() {
    if (!mounted || prefersReducedMotion(context)) {
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller?.detach(_play);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final dx =
            math.sin(t * math.pi * 2 * widget.cycles) *
            widget.magnitude *
            (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
