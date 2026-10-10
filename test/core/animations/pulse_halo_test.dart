import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/pulse_halo.dart';

import 'animation_test_host.dart';

void main() {
  group('PulseHalo', () {
    testWidgets('pulses the halo past its resting scale', (tester) async {
      await tester.pumpWidget(
        animationHost(const PulseHalo(child: SizedBox(width: 40, height: 40))),
      );

      await tester.pump(const Duration(milliseconds: 400));
      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(PulseHalo),
              matching: find.byType(Transform),
            ),
          )
          .map((transform) => transform.transform.entry(0, 0));
      expect(scales.any((scale) => scale > 1.0), isTrue);
    });

    testWidgets('rests at its resting scale under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        animationHost(
          const PulseHalo(child: SizedBox(width: 40, height: 40)),
          reduceMotion: true,
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(PulseHalo),
              matching: find.byType(Transform),
            ),
          )
          .map((transform) => transform.transform.entry(0, 0));
      expect(scales.every((scale) => scale <= 1.0), isTrue);
    });
  });
}
