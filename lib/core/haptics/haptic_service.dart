import 'package:flutter/services.dart';

const _minimumPulseInterval = Duration(milliseconds: 250);

enum HapticEvent {
  tap,
  select,
  success,
  error,
  warning,
  streak,
  unlock,
  levelUp,
  menu,
  refresh,
}

abstract interface class HapticService {
  Future<void> emit(HapticEvent event);
}

final class PlatformHapticService implements HapticService {
  PlatformHapticService({this.enabled = true, this.reduceHaptics = false});

  final bool enabled;
  final bool reduceHaptics;
  final Stopwatch _clock = Stopwatch()..start();
  Duration? _lastPulseAt;
  Future<void> _queue = Future<void>.value();

  @override
  Future<void> emit(HapticEvent event) {
    if (!enabled) return Future<void>.value();

    final previous = _queue;
    final scheduled = previous.then<void>(
      (_) => _play(event),
      onError: (Object _, StackTrace _) => _play(event),
    );
    _queue = scheduled;
    return scheduled;
  }

  Future<void> _play(HapticEvent event) async {
    if (reduceHaptics) {
      switch (event) {
        case HapticEvent.tap:
        case HapticEvent.select:
          await _pulse(HapticFeedback.selectionClick);
        default:
          break;
      }
      return;
    }

    switch (event) {
      case HapticEvent.tap:
        await _pulse(HapticFeedback.lightImpact);
      case HapticEvent.select:
      case HapticEvent.refresh:
        await _pulse(HapticFeedback.selectionClick);
      case HapticEvent.success:
        await _pulse(HapticFeedback.mediumImpact);
        await _pulse(HapticFeedback.lightImpact);
      case HapticEvent.error:
        await _pulse(HapticFeedback.lightImpact);
        await _pulse(HapticFeedback.lightImpact);
      case HapticEvent.warning:
        await _pulse(HapticFeedback.heavyImpact);
      case HapticEvent.streak:
        await _pulse(HapticFeedback.heavyImpact);
        await _pulse(HapticFeedback.lightImpact);
      case HapticEvent.unlock:
        await _pulse(HapticFeedback.mediumImpact);
        await _pulse(HapticFeedback.selectionClick);
      case HapticEvent.levelUp:
        await _pulse(HapticFeedback.lightImpact);
        await _pulse(HapticFeedback.mediumImpact);
        await _pulse(HapticFeedback.heavyImpact);
      case HapticEvent.menu:
        await _pulse(HapticFeedback.mediumImpact);
    }
  }

  Future<void> _pulse(Future<void> Function() feedback) async {
    final previous = _lastPulseAt;
    if (previous != null) {
      final remaining = _minimumPulseInterval - (_clock.elapsed - previous);
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
    await feedback();
    _lastPulseAt = _clock.elapsed;
  }
}
