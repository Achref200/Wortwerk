import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/haptics/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('serializes haptic pulses to no more than four per second', () async {
    final clock = Stopwatch()..start();
    final pulseTimes = <Duration>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        pulseTimes.add(clock.elapsed);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final service = PlatformHapticService();
    await Future.wait([
      service.emit(HapticEvent.error),
      service.emit(HapticEvent.tap),
    ]);

    expect(pulseTimes, hasLength(3));
    for (var index = 1; index < pulseTimes.length; index++) {
      expect(
        pulseTimes[index] - pulseTimes[index - 1],
        greaterThanOrEqualTo(const Duration(milliseconds: 250)),
      );
    }
  });

  test('reduced haptics ignore reward patterns', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final service = PlatformHapticService(reduceHaptics: true);
    await service.emit(HapticEvent.levelUp);
    await service.emit(HapticEvent.select);

    expect(calls, hasLength(1));
  });
}
