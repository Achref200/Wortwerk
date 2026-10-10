import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/page_transitions.dart';

import 'animation_test_host.dart';

Opacity _transitionOpacity(WidgetTester tester, Type type) =>
    tester.widget<Opacity>(
      find
          .descendant(of: find.byType(type), matching: find.byType(Opacity))
          .first,
    );

void main() {
  group('SharedAxisTransition', () {
    testWidgets('slides and fades the incoming page into place', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          SharedAxisTransition(
            animation: controller,
            secondaryAnimation: kAlwaysDismissedAnimation,
            child: const Text('page'),
          ),
        ),
      );

      expect(_transitionOpacity(tester, SharedAxisTransition).opacity, 0);
      final offset = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(SharedAxisTransition),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation();
      expect(offset.x, closeTo(24, 0.001));

      controller.value = 1;
      await tester.pump();
      expect(_transitionOpacity(tester, SharedAxisTransition).opacity, 1);
    });

    testWidgets('skips the transition under reduced motion', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          SharedAxisTransition(
            animation: controller,
            secondaryAnimation: kAlwaysDismissedAnimation,
            child: const Text('page'),
          ),
          reduceMotion: true,
        ),
      );

      expect(
        find.descendant(
          of: find.byType(SharedAxisTransition),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(find.text('page'), findsOneWidget);
    });
  });

  group('FadeThroughTransition', () {
    testWidgets('scales and fades the incoming page into place', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          FadeThroughTransition(
            animation: controller,
            secondaryAnimation: kAlwaysDismissedAnimation,
            child: const Text('takeover'),
          ),
        ),
      );

      expect(_transitionOpacity(tester, FadeThroughTransition).opacity, 0);
      expect(
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(FadeThroughTransition),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .entry(0, 0),
        closeTo(0.92, 0.001),
      );

      controller.value = 1;
      await tester.pump();
      expect(_transitionOpacity(tester, FadeThroughTransition).opacity, 1);
    });

    testWidgets('skips the transition under reduced motion', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        animationHost(
          FadeThroughTransition(
            animation: controller,
            secondaryAnimation: kAlwaysDismissedAnimation,
            child: const Text('takeover'),
          ),
          reduceMotion: true,
        ),
      );

      expect(
        find.descendant(
          of: find.byType(FadeThroughTransition),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('route builders', () {
    test('SharedAxisPage uses the 300 ms transition spec', () {
      final route = SharedAxisPage<void>(
        child: const SizedBox.shrink(),
        settings: const RouteSettings(name: '/next'),
      );
      expect(route.transitionDuration, const Duration(milliseconds: 300));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 300),
      );
      expect(route.axis, SharedAxisAxis.horizontal);
      expect(route.settings.name, '/next');
    });

    test('FadeThroughPage uses the 300 ms transition spec', () {
      final route = FadeThroughPage<void>(child: const SizedBox.shrink());
      expect(route.transitionDuration, const Duration(milliseconds: 300));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 300),
      );
    });

    testWidgets('pushing a SharedAxisPage renders the child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(SharedAxisPage<void>(child: const Text('detail'))),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
    });
  });
}
