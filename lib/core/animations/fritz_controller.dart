import 'package:flutter/material.dart';

import '../../design_system/fritz_avatar.dart';
import 'motion.dart';

/// Emotions Fritz can express (SPEC §5.8).
enum FritzMood { idle, happy, thinking, celebrate, concerned }

/// The single source of truth for Fritz's current mood.
///
/// Screens call [setMood] (or the named helpers) and any [FritzMoodAvatar]
/// listening to the controller blends to the new expression. The blend itself
/// lives in the widget so the controller stays a plain, testable notifier.
final class FritzController extends ChangeNotifier {
  FritzController({FritzMood mood = FritzMood.idle}) {
    _mood = mood;
  }

  late FritzMood _mood;

  FritzMood get mood => _mood;

  /// How long a mood cross-blend takes (SPEC §5.8).
  static const Duration blendDuration = Duration(milliseconds: 200);

  void setMood(FritzMood mood) {
    if (_mood == mood) {
      return;
    }
    _mood = mood;
    notifyListeners();
  }

  void happy() => setMood(FritzMood.happy);
  void think() => setMood(FritzMood.thinking);
  void celebrate() => setMood(FritzMood.celebrate);
  void concern() => setMood(FritzMood.concerned);
  void rest() => setMood(FritzMood.idle);
}

/// Renders Fritz with a mood-driven reaction.
///
/// Mood changes cross-blend over 200 ms (SPEC §5.8). Under reduced motion the
/// avatar stays still and simply swaps expression.
final class FritzMoodAvatar extends StatelessWidget {
  const FritzMoodAvatar({required this.controller, super.key, this.size = 72});

  final FritzController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mood = controller.mood;
        if (prefersReducedMotion(context)) {
          return FritzAvatar(size: size);
        }
        return AnimatedSwitcher(
          duration: motionDuration(context, FritzController.blendDuration),
          child: _MoodAvatar(
            key: ValueKey(mood),
            mood: mood,
            size: size,
          ),
        );
      },
    );
  }
}

final class _MoodAvatar extends StatelessWidget {
  const _MoodAvatar({required this.mood, required this.size, super.key});

  final FritzMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (mood) {
      case FritzMood.idle:
        return AnimatedFritzAvatar(size: size);
      case FritzMood.thinking:
        return Transform.rotate(
          angle: -0.06,
          child: FritzAvatar(size: size),
        );
      case FritzMood.happy:
      case FritzMood.celebrate:
        final peak = mood == FritzMood.celebrate ? 1.16 : 1.1;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.9, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: MotionCurves.reward,
          builder: (context, value, child) => Transform.scale(
            scale: value == 1 ? 1 : value.clamp(0.9, peak),
            child: child,
          ),
          child: FritzAvatar(size: size),
        );
      case FritzMood.concerned:
        return FritzAvatar(size: size);
    }
  }
}
