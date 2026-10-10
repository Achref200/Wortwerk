import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/animated_counter.dart';

import 'animation_test_host.dart';

void main() {
  group('AnimatedCounter', () {
    testWidgets('counts up and settles on the final value', (tester) async {
      await tester.pumpWidget(
        animationHost(
          const AnimatedCounter(
            value: 250,
            duration: Duration(milliseconds: 400),
            prefix: '+',
            suffix: ' XP',
          ),
        ),
      );

      expect(find.text('+0 XP'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('+250 XP'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('+250 XP'), findsOneWidget);
    });

    testWidgets('jumps straight to the final value under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        animationHost(
          const AnimatedCounter(value: 250, prefix: '+', suffix: ' XP'),
          reduceMotion: true,
        ),
      );

      await tester.pump();
      expect(find.text('+250 XP'), findsOneWidget);
    });

    testWidgets('continues from the current value when it changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        animationHost(
          const AnimatedCounter(
            value: 10,
            duration: Duration(milliseconds: 400),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);

      await tester.pumpWidget(
        animationHost(
          const AnimatedCounter(
            value: 30,
            duration: Duration(milliseconds: 400),
          ),
        ),
      );
      // Still shows the old value on the first frame of the new tween.
      expect(find.text('10'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
    });
  });

  group('RollingDigits', () {
    testWidgets('renders one column per digit and settles on the value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        animationHost(const RollingDigits(value: 42, minDigits: 3)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ClipRect), findsNWidgets(3));
      expect(find.bySemanticsLabel('42'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('rolls to the new number when the value changes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        animationHost(
          const RollingDigits(
            value: 7,
            duration: Duration(milliseconds: 400),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('7'), findsOneWidget);

      await tester.pumpWidget(
        animationHost(
          const RollingDigits(
            value: 9,
            duration: Duration(milliseconds: 400),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('9'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('settles immediately under reduced motion', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        animationHost(const RollingDigits(value: 88), reduceMotion: true),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('88'), findsOneWidget);
      expect(find.byType(ClipRect), findsNWidgets(2));
      semantics.dispose();
    });
  });
}
