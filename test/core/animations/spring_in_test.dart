import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/spring_in.dart';

import 'animation_test_host.dart';

double _opacityOf(WidgetTester tester, Finder finder) => tester
    .widget<Opacity>(
      find.descendant(of: finder, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group('SpringIn', () {
    testWidgets('springs from hidden to fully visible', (tester) async {
      await tester.pumpWidget(
        animationHost(
          const SpringIn(
            duration: Duration(milliseconds: 400),
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );

      expect(_opacityOf(tester, find.byType(SpringIn)), 0);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.byType(SpringIn)), 1);
    });

    testWidgets('starts fully visible under reduced motion', (tester) async {
      await tester.pumpWidget(
        animationHost(
          const SpringIn(child: SizedBox(width: 40, height: 40)),
          reduceMotion: true,
        ),
      );

      await tester.pump();
      expect(_opacityOf(tester, find.byType(SpringIn)), 1);
    });
  });

  group('Staggered', () {
    testWidgets('delays later items by index', (tester) async {
      await tester.pumpWidget(
        animationHost(
          const Staggered(
            index: 3,
            step: Duration(milliseconds: 100),
            duration: Duration(milliseconds: 200),
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacityOf(tester, find.byType(SpringIn)), 0);

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.byType(SpringIn)), 1);
    });

    testWidgets('ignores the stagger delay under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        animationHost(
          const Staggered(
            index: 5,
            step: Duration(milliseconds: 100),
            child: SizedBox(width: 40, height: 40),
          ),
          reduceMotion: true,
        ),
      );

      await tester.pump();
      expect(_opacityOf(tester, find.byType(SpringIn)), 1);
    });
  });
}
