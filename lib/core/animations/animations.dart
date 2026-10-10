/// The Wortwerk motion kit (SPEC §5.10).
///
/// Every primitive here resolves its duration through [motionDuration] so the
/// whole app honours the platform's reduced-motion preference, and every
/// primitive keeps its final state when motion is disabled.
library;

export 'animated_counter.dart';
export 'confetti_burst.dart';
export 'draw_path.dart';
export 'flame_controller.dart';
export 'fritz_controller.dart';
export 'motion.dart';
export 'page_transitions.dart';
export 'pressable_scale.dart';
export 'pulse_halo.dart';
export 'shake_widget.dart';
export 'spring_in.dart';
