import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/flame_controller.dart';
import 'package:wortwerk/core/animations/fritz_controller.dart';
import 'package:wortwerk/design_system/fritz_avatar.dart';

import 'animation_test_host.dart';

void main() {
  group('FritzController', () {
    test('notifies listeners only when the mood changes', () {
      final controller = FritzController();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.mood, FritzMood.idle);
      controller.setMood(FritzMood.idle);
      expect(notifications, 0);

      controller.happy();
      expect(controller.mood, FritzMood.happy);
      expect(notifications, 1);

      controller.think();
      controller.celebrate();
      controller.concern();
      controller.rest();
      expect(controller.mood, FritzMood.idle);
      expect(notifications, 5);
    });

    testWidgets('FritzMoodAvatar cross-blends between moods', (tester) async {
      final controller = FritzController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(FritzMoodAvatar(controller: controller)),
      );
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(FritzAvatar), findsWidgets);

      controller.celebrate();
      await tester.pumpAndSettle();
      expect(find.byType(FritzAvatar), findsWidgets);
    });

    testWidgets('FritzMoodAvatar swaps expression without motion when reduced', (
      tester,
    ) async {
      final controller = FritzController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          FritzMoodAvatar(controller: controller),
          reduceMotion: true,
        ),
      );
      expect(find.byType(AnimatedSwitcher), findsNothing);
      expect(find.byType(FritzAvatar), findsOneWidget);

      controller.celebrate();
      await tester.pumpAndSettle();
      expect(find.byType(FritzAvatar), findsOneWidget);
    });
  });

  group('FlameController', () {
    test('tracks lit, tremble, celebrate and settle states', () {
      final controller = FlameController();
      addTearDown(controller.dispose);

      expect(controller.state, FlameState.dormant);
      expect(controller.lit, isFalse);

      controller.setLit(true);
      expect(controller.lit, isTrue);

      controller.tremble();
      expect(controller.state, FlameState.trembling);
      expect(controller.lit, isTrue);

      controller.celebrate();
      expect(controller.state, FlameState.celebrating);
      expect(controller.lit, isTrue);

      controller.settle();
      expect(controller.state, FlameState.lit);

      controller.setLit(false);
      expect(controller.lit, isFalse);
      expect(controller.state, FlameState.dormant);
    });

    testWidgets('AnimatedStreakFlame trembles then settles', (tester) async {
      final controller = FlameController(lit: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(AnimatedStreakFlame(controller: controller)),
      );
      controller.tremble();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(AnimatedStreakFlame),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .getTranslation()
            .x
            .abs(),
        greaterThan(0),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('AnimatedStreakFlame stays still under reduced motion', (
      tester,
    ) async {
      final controller = FlameController(lit: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          AnimatedStreakFlame(controller: controller),
          reduceMotion: true,
        ),
      );
      controller.tremble();
      await tester.pump(const Duration(milliseconds: 90));

      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(AnimatedStreakFlame),
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
