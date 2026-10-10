import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/confetti_burst.dart';

import 'animation_test_host.dart';

ConfettiPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(ConfettiBurst),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .painter!
        as ConfettiPainter;

Widget _hosted({
  bool reduceMotion = false,
  VoidCallback? onCompleted,
  int count = 80,
}) {
  return animationHost(
    SizedBox(
      width: 300,
      height: 300,
      child: ConfettiBurst(
        particleCount: count,
        duration: const Duration(milliseconds: 600),
        onCompleted: onCompleted,
      ),
    ),
    reduceMotion: reduceMotion,
  );
}

void main() {
  group('ConfettiBurst', () {
    testWidgets('plays once from 0 to 1 and reports completion', (
      tester,
    ) async {
      var completed = 0;
      await tester.pumpWidget(_hosted(onCompleted: () => completed++));

      expect(_painter(tester).progress, 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painter(tester).progress, greaterThan(0));
      expect(_painter(tester).progress, lessThan(1));

      await tester.pumpAndSettle();
      await tester.pump();
      expect(_painter(tester).progress, 1);
      expect(completed, 1);
    });

    testWidgets('caps the particle count at the spec maximum', (tester) async {
      await tester.pumpWidget(_hosted(count: 500));
      expect(_painter(tester).particles.length, ConfettiBurst.maxParticles);
    });

    testWidgets('paints nothing under reduced motion', (tester) async {
      await tester.pumpWidget(_hosted(reduceMotion: true));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ConfettiBurst),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
