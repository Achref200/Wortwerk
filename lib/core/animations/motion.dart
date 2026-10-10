import 'package:flutter/material.dart';

/// Canonical motion durations from the Wortwerk motion language (SPEC ch.5).
///
/// Every widget in `core/animations` resolves its duration through
/// [motionDuration] so a single platform preference disables motion app-wide.
abstract final class MotionDurations {
  /// Button press-down scale (SPEC §5.9).
  static const press = Duration(milliseconds: 100);

  /// Button release spring (SPEC §5.9).
  static const release = Duration(milliseconds: 160);

  /// Generic micro-interaction (chips, toggles, borders).
  static const micro = Duration(milliseconds: 160);

  /// Standard surface transition (tab pill, toast).
  static const standard = Duration(milliseconds: 240);

  /// Push / fade-through page transition (SPEC §5.7).
  static const transition = Duration(milliseconds: 300);

  /// Progress bars and rings (SPEC §5.3).
  static const progress = Duration(milliseconds: 600);

  /// XP / streak count-up and odometer roll (SPEC §5.2, §5.9).
  static const counter = Duration(milliseconds: 800);

  /// PathMetric line drawing (SPEC §5.3, §5.4).
  static const draw = Duration(milliseconds: 800);

  /// Level-up reward sequence (SPEC §5.6).
  static const reward = Duration(milliseconds: 1450);
}

/// Curves used across the motion language.
abstract final class MotionCurves {
  /// Default easing for standard transitions.
  static const standard = Curves.easeOutCubic;

  /// Emphasized easing for auto-scroll and hero moves.
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Reward overshoot (spring damping ≈ 0.7).
  static const reward = Cubic(0.2, 1.32, 0.32, 1);
}

/// Whether the platform asks for reduced motion right now.
///
/// Returns `false` when no [MediaQuery] is available so previews and isolated
/// widgets behave normally.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Collapses [duration] to zero when reduced motion is requested.
///
/// Widgets keep their final state either way; only the interpolation is
/// dropped, so no value is ever left mid-animation.
Duration motionDuration(BuildContext context, Duration duration) =>
    prefersReducedMotion(context) ? Duration.zero : duration;
