import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/streak_flame.dart';
import 'motion.dart';

/// Lifecycle states of the streak flame (SPEC §5.2).
enum FlameState {
  /// No streak yet — flame is dim.
  dormant,

  /// Streak is alive today.
  lit,

  /// At-risk check-in: the flame trembles once.
  trembling,

  /// A new active day or milestone: the flame celebrates.
  celebrating,
}

/// Drives the streak flame's presentation state.
///
/// The streak feature owns the truth (days, rest day) and pushes it here; the
/// [AnimatedStreakFlame] widget renders the result. Keeping this a plain
/// notifier makes the choreography testable without a widget pump.
final class FlameController extends ChangeNotifier {
  FlameController({bool lit = false})
    : _state = lit ? FlameState.lit : FlameState.dormant;

  FlameState _state;

  FlameState get state => _state;

  /// True whenever a streak is alive — including while it trembles and
  /// celebrates; only [FlameState.dormant] has no streak.
  bool get lit => _state != FlameState.dormant;

  void setLit(bool value) {
    _set(value ? FlameState.lit : FlameState.dormant);
  }

  /// The local at-risk moment: flame trembles once, then settles.
  void tremble() => _set(FlameState.trembling);

  /// The first active day or a milestone.
  void celebrate() => _set(FlameState.celebrating);

  /// Returns to the resting lit/dormant state.
  void settle() => _set(lit ? FlameState.lit : FlameState.dormant);

  void _set(FlameState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    notifyListeners();
  }
}

/// Renders [StreakFlame] with the reaction described by [controller].
///
/// Tremble is a single ±3 px, 3-cycle shake (360 ms) and celebrate is a soft
/// scale pulse. Under reduced motion the flame renders statically at the right
/// brightness with no shake or pulse.
final class AnimatedStreakFlame extends StatefulWidget {
  const AnimatedStreakFlame({
    required this.controller,
    super.key,
    this.size = 58,
  });

  final FlameController controller;
  final double size;

  @override
  State<AnimatedStreakFlame> createState() => _AnimatedStreakFlameState();
}

final class _AnimatedStreakFlameState extends State<AnimatedStreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(AnimatedStreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
    }
  }

  void _onStateChanged() {
    if (!mounted || prefersReducedMotion(context)) {
      return;
    }
    final state = widget.controller.state;
    if (state == FlameState.trembling || state == FlameState.celebrating) {
      _reaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _reaction]),
      builder: (context, _) {
        final state = widget.controller.state;
        final reduced = prefersReducedMotion(context);
        final t = reduced ? 0.0 : _reaction.value;
        var dx = 0.0;
        var scale = 1.0;
        if (state == FlameState.trembling) {
          dx = math.sin(t * math.pi * 6) * 3 * (1 - t);
        } else if (state == FlameState.celebrating) {
          scale = 1 + 0.12 * math.sin(t * math.pi);
        }
        return Opacity(
          opacity: state == FlameState.dormant ? 0.4 : 1,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: scale,
              child: StreakFlame(size: widget.size),
            ),
          ),
        );
      },
    );
  }
}
