import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/confetti_burst.dart';
import 'package:wortwerk/core/animations/fritz_controller.dart';
import 'package:wortwerk/features/secondary/presentation/secondary_pages.dart';

void main() {
  testWidgets('level-up celebration bursts confetti with a joyful Fritz', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LevelUpPage()));
    await tester.pump();

    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(find.byType(FritzMoodAvatar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ConfettiBurst),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(find.text('EIN NEUER ABSCHNITT'), findsOneWidget);
  });

  testWidgets('level-up respects reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: LevelUpPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The burst widget is part of the tree but paints nothing.
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ConfettiBurst),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(find.text('EIN NEUER ABSCHNITT'), findsOneWidget);
  });
}
