import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/haptics/haptic_service.dart';
import 'package:wortwerk/design_system/wortwerk_theme.dart';
import 'package:wortwerk/features/flashcards/domain/flashcard_review.dart';
import 'package:wortwerk/features/flashcards/presentation/flashcards_page.dart';

final class _FakeHapticService implements HapticService {
  final events = <HapticEvent>[];

  @override
  Future<void> emit(HapticEvent event) async {
    events.add(event);
  }
}

final class _FakeFlashcardRepository implements FlashcardRepository {
  final calls =
      <({List<FlashcardReviewAnswer> answers, String clientRequestId})>[];
  final List<Object> outcomes = [];

  @override
  Future<FlashcardReviewResult> completeReview({
    required List<FlashcardReviewAnswer> answers,
    required String clientRequestId,
  }) async {
    calls.add((answers: List.of(answers), clientRequestId: clientRequestId));
    final outcome = outcomes.isEmpty
        ? FlashcardReviewResult(
            reviewedCount: answers.length,
            rememberedCount: answers
                .where((answer) => answer.remembered)
                .length,
            xpAwarded: 10,
          )
        : outcomes.removeAt(0);
    if (outcome is Exception || outcome is Error) throw outcome;
    return outcome as FlashcardReviewResult;
  }
}

Future<void> _flip(WidgetTester tester) async {
  await tester.tap(find.text('Karte umdrehen'));
  await tester.pumpAndSettle();
}

Future<void> _finishReview(WidgetTester tester) async {
  for (var index = 0; index < greetingFlashcards.length; index++) {
    await _flip(tester);
    await tester.tap(find.text('Gewusst'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('uses a real ten-card session and requires revealing each card', (
    tester,
  ) async {
    final repository = _FakeFlashcardRepository();
    final haptics = _FakeHapticService();
    await tester.pumpWidget(
      MaterialApp(
        home: FlashcardsPage(repository: repository, hapticService: haptics),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KARTE 1 VON 10'), findsOneWidget);
    expect(find.text('Hallo!'), findsOneWidget);
    expect(find.text('Gewusst'), findsNothing);
    expect(find.text('Nochmal'), findsNothing);

    await _flip(tester);
    expect(find.text('Hello!'), findsOneWidget);
    await tester.tap(find.text('Gewusst'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! AnimatedContainer) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == WortwerkColors.success;
      }),
      findsOneWidget,
    );
    expect(find.text('Gut erinnert · kommt später wieder'), findsOneWidget);
    expect(find.text('KARTE 1 VON 10'), findsOneWidget);
    expect(haptics.events, [HapticEvent.select, HapticEvent.success]);

    await tester.pumpAndSettle();

    expect(find.text('KARTE 2 VON 10'), findsOneWidget);
    expect(find.text('Guten Morgen'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets(
    'persists SRS review, active-day progress and XP after ten cards',
    (tester) async {
      final repository = _FakeFlashcardRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: FlashcardsPage(
            repository: repository,
            hapticService: _FakeHapticService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _finishReview(tester);

      expect(find.text('Wiederholung geschafft!'), findsOneWidget);
      expect(
        find.text('10 Wörter angeschaut · 10 sicher erinnert'),
        findsOneWidget,
      );
      expect(find.text('+10 XP'), findsOneWidget);
      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.answers, hasLength(10));
      expect(
        repository.calls.single.answers.map((answer) => answer.cardId).toSet(),
        hasLength(10),
      );
      expect(
        repository.calls.single.answers.every((answer) => answer.remembered),
        isTrue,
      );
    },
  );

  testWidgets('retries a failed save with the same request ID and answers', (
    tester,
  ) async {
    final repository = _FakeFlashcardRepository()
      ..outcomes.add(StateError('offline'));
    await tester.pumpWidget(
      MaterialApp(
        home: FlashcardsPage(
          repository: repository,
          hapticService: _FakeHapticService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _finishReview(tester);

    expect(
      find.text(
        'Deine Wiederholung konnte nicht gespeichert werden. '
        'Deine Antworten sind noch da – versuche es erneut.',
      ),
      findsOneWidget,
    );
    expect(find.text('Erneut speichern'), findsOneWidget);
    await tester.tap(find.text('Erneut speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Wiederholung geschafft!'), findsOneWidget);
    expect(repository.calls, hasLength(2));
    expect(
      repository.calls[0].clientRequestId,
      repository.calls[1].clientRequestId,
    );
    expect(
      repository.calls[0].answers
          .map((answer) => (answer.cardId, answer.remembered))
          .toList(),
      repository.calls[1].answers
          .map((answer) => (answer.cardId, answer.remembered))
          .toList(),
    );
  });
}
