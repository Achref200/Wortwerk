import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/pressable_scale.dart';
import 'package:wortwerk/core/animations/shake_widget.dart';

import 'animation_test_host.dart';

/// Reads the scale AnimatedScale is animating *towards*. Asserting on the
/// rendered Transform matrix instead is unreliable: right after the target
/// changes the matrix still reflects the previous frame's interpolation.
double _targetScale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  group('PressableScale', () {
    testWidgets('presses to 0.98, releases to 1.0 and fires onPressed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        animationHost(
          PressableScale(
            onPressed: () => taps++,
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      );

      final finder = find.byType(PressableScale);
      final gesture = await tester.startGesture(tester.getCenter(finder));
      // `onTapDown` resolves after the gesture arena's press timeout.
      await tester.pump(const Duration(milliseconds: 150));
      expect(_targetScale(tester), closeTo(0.98, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_targetScale(tester), closeTo(1.0, 0.001));
      expect(taps, 1);
    });

    testWidgets('stays still under reduced motion but still taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        animationHost(
          PressableScale(
            onPressed: () => taps++,
            child: const SizedBox(width: 80, height: 80),
          ),
          reduceMotion: true,
        ),
      );

      final finder = find.byType(PressableScale);
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_targetScale(tester), closeTo(1.0, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('ShakeWidget', () {
    testWidgets('shakes then returns to its resting position', (tester) async {
      final controller = ShakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          ShakeWidget(
            controller: controller,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      final finder = find.byType(ShakeWidget);

      expect(controller.isAttached, isTrue);
      controller.shake();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(of: finder, matching: find.byType(Transform))
                  .first,
            )
            .transform
            .getTranslation()
            .x
            .abs(),
        greaterThan(0),
      );

      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(of: finder, matching: find.byType(Transform))
                  .first,
            )
            .transform
            .getTranslation()
            .x,
        closeTo(0, 0.001),
      );
    });

    testWidgets('does not move under reduced motion', (tester) async {
      final controller = ShakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          ShakeWidget(
            controller: controller,
            child: const SizedBox(width: 40, height: 40),
          ),
          reduceMotion: true,
        ),
      );

      controller.shake();
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(ShakeWidget),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .getTranslation()
            .x,
        closeTo(0, 0.001),
      );
    });
  });
}
