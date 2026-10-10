import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/draw_path.dart';

import 'animation_test_host.dart';

Path _line() => Path()
  ..moveTo(0, 0)
  ..lineTo(100, 100);

DrawPathPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(DrawPath),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return paint.painter! as DrawPathPainter;
}

void main() {
  group('DrawPath', () {
    testWidgets('draws from 0 to the full path', (tester) async {
      await tester.pumpWidget(
        animationHost(
          DrawPath(
            path: _line(),
            size: const Size(100, 100),
            duration: const Duration(milliseconds: 400),
          ),
        ),
      );

      expect(_painter(tester).fraction, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_painter(tester).fraction, greaterThan(0));
      expect(_painter(tester).fraction, lessThan(1));

      await tester.pumpAndSettle();
      expect(_painter(tester).fraction, 1);
    });

    testWidgets('is fully drawn immediately under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        animationHost(
          DrawPath(path: _line(), size: const Size(100, 100)),
          reduceMotion: true,
        ),
      );

      await tester.pump();
      expect(_painter(tester).fraction, 1);
    });
  });
}
