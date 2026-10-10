import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/draw_path.dart';
import 'package:wortwerk/features/lesson/domain/greetings_lesson.dart';
import 'package:wortwerk/features/lesson/domain/lesson_repository.dart';
import 'package:wortwerk/features/lesson/presentation/lesson_page.dart';

import '../../../fixtures/a1_greetings_lesson.dart';

final class _FakeLessonContentRepository implements LessonContentRepository {
  @override
  Future<LearningLesson> getLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
  }) async => a1GreetingsLesson;
}

Widget _lessonPage(_FakeLessonRepository repository) => LessonPage(
  repository: repository,
  contentRepository: _FakeLessonContentRepository(),
  levelId: a1GreetingsLesson.levelId,
  unitId: a1GreetingsLesson.unitId,
  lessonId: a1GreetingsLesson.id,
);

final class _FakeLessonRepository implements LessonRepository {
  final List<
    ({
      String levelId,
      String unitId,
      String lessonId,
      List<LessonAnswer> answers,
      String clientRequestId,
    })
  >
  calls = [];
  final List<Object> outcomes = [];
  Completer<LessonCompletionResult>? pending;

  @override
  Future<LessonCompletionResult> completeLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
    required List<LessonAnswer> answers,
    required String clientRequestId,
  }) async {
    calls.add((
      levelId: levelId,
      unitId: unitId,
      lessonId: lessonId,
      answers: List.of(answers),
      clientRequestId: clientRequestId,
    ));
    final pendingResult = pending;
    if (pendingResult != null) return pendingResult.future;
    final outcome = outcomes.isEmpty
        ? const LessonCompletionResult(accuracy: 1, xpAwarded: 20)
        : outcomes.removeAt(0);
    if (outcome is Exception) throw outcome;
    return outcome as LessonCompletionResult;
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _answerQuestion(
  WidgetTester tester, {
  required String choiceId,
  required String buttonText,
}) async {
  final choice = find.byKey(ValueKey<String>(choiceId));
  await _scrollTo(tester, choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();

  final button = find.widgetWithText(FilledButton, buttonText);
  await _scrollTo(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _reachLastQuestion(
  WidgetTester tester, {
  int startingAt = 0,
}) async {
  for (
    var index = startingAt;
    index < a1GreetingsLesson.questions.length - 1;
    index++
  ) {
    final question = a1GreetingsLesson.questions[index];
    await _answerQuestion(
      tester,
      choiceId: question.correctChoiceId,
      buttonText: 'Antwort prüfen',
    );
    expect(find.textContaining('Richtig.'), findsOneWidget);
    await _answerQuestion(
      tester,
      choiceId: question.correctChoiceId,
      buttonText: 'Weiter',
    );
  }
}

void main() {
  testWidgets('shows German lesson content and accessible progress', (
    tester,
  ) async {
    final repository = _FakeLessonRepository();
    await tester.pumpWidget(MaterialApp(home: _lessonPage(repository)));
    await tester.pumpAndSettle();

    expect(find.text(a1GreetingsLesson.title), findsOneWidget);
    expect(find.text('Frage 1 von 5'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Lektionsfortschritt, Frage 1 von 5'),
      findsOneWidget,
    );
    expect(
      find.text('Du triffst jemanden am Morgen. Was sagst du?'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('morning_guten_morgen')), findsOneWidget);
    expect(find.byKey(const ValueKey('morning_guten_abend')), findsOneWidget);
    expect(find.byKey(const ValueKey('morning_gute_nacht')), findsOneWidget);
    expect(find.byKey(const ValueKey('morning_tschuess')), findsOneWidget);
    expect(find.text('Antwort prüfen'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets(
    'checks an answer, explains it, advances, and shows server result',
    (tester) async {
      final repository = _FakeLessonRepository();
      await tester.pumpWidget(MaterialApp(home: _lessonPage(repository)));
      await tester.pumpAndSettle();

      await _answerQuestion(
        tester,
        choiceId: 'morning_guten_abend',
        buttonText: 'Antwort prüfen',
      );
      final feedback = find.text(
        'Noch nicht richtig. „Guten Morgen“ sagt man am Morgen.',
      );
      expect(feedback, findsOneWidget);
      expect(
        tester.getSemantics(feedback).flagsCollection.isLiveRegion,
        isTrue,
      );
      expect(find.text('Weiter'), findsOneWidget);
      await _answerQuestion(
        tester,
        choiceId: 'morning_guten_abend',
        buttonText: 'Weiter',
      );
      expect(find.text('Frage 2 von 5'), findsOneWidget);

      await _reachLastQuestion(tester, startingAt: 1);
      final lastQuestion = a1GreetingsLesson.questions.last;
      await _answerQuestion(
        tester,
        choiceId: lastQuestion.correctChoiceId,
        buttonText: 'Antwort prüfen',
      );
      final finishButton = find.widgetWithText(
        FilledButton,
        'Lektion abschließen',
      );
      await _scrollTo(tester, finishButton);
      await tester.tap(finishButton);
      await tester.pumpAndSettle();

      expect(find.text('Lektion gespeichert'), findsOneWidget);
      expect(
        find.text('Dein Fortschritt wurde vom Server bestätigt.'),
        findsOneWidget,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.lessonId, a1GreetingsLesson.id);
      expect(repository.calls.single.answers, hasLength(5));
      expect(find.byType(DrawPath), findsWidgets);
      expect(
        repository.calls.single.answers.first.questionId,
        a1GreetingsLesson.questions.first.id,
      );
    },
  );

  testWidgets('shows German save/retry states and resends the same request', (
    tester,
  ) async {
    final repository = _FakeLessonRepository()
      ..outcomes.add(const SocketException('offline'))
      ..outcomes.add(
        const LessonCompletionResult(accuracy: 0.8, xpAwarded: 18),
      );
    await tester.pumpWidget(MaterialApp(home: _lessonPage(repository)));
    await tester.pumpAndSettle();

    await _reachLastQuestion(tester);
    final question = a1GreetingsLesson.questions.last;
    await _answerQuestion(
      tester,
      choiceId: question.correctChoiceId,
      buttonText: 'Antwort prüfen',
    );

    final finishButton = find.widgetWithText(
      FilledButton,
      'Lektion abschließen',
    );
    await _scrollTo(tester, finishButton);
    await tester.tap(finishButton);
    await tester.pumpAndSettle();

    final errorMessage = find.text(
      'Dein Fortschritt konnte nicht bestätigt werden. Deine Antworten '
      'sind noch da. Bitte versuche erneut, den Fortschritt zu speichern.',
    );
    expect(errorMessage, findsOneWidget);
    expect(
      tester.getSemantics(errorMessage).flagsCollection.isLiveRegion,
      isTrue,
    );
    expect(find.text('Erneut speichern'), findsOneWidget);
    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.answers, hasLength(5));

    final retryButton = find.widgetWithText(FilledButton, 'Erneut speichern');
    await _scrollTo(tester, retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(
      repository.calls[1].clientRequestId,
      repository.calls[0].clientRequestId,
    );
    expect(repository.calls[1].answers, repository.calls[0].answers);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('+18 XP'), findsOneWidget);
  });

  testWidgets('announces that server confirmation is still pending', (
    tester,
  ) async {
    final repository = _FakeLessonRepository()
      ..pending = Completer<LessonCompletionResult>();
    await tester.pumpWidget(MaterialApp(home: _lessonPage(repository)));
    await tester.pumpAndSettle();

    await _reachLastQuestion(tester);
    final lastQuestion = a1GreetingsLesson.questions.last;
    await _answerQuestion(
      tester,
      choiceId: lastQuestion.correctChoiceId,
      buttonText: 'Antwort prüfen',
    );
    final finishButton = find.widgetWithText(
      FilledButton,
      'Lektion abschließen',
    );
    await _scrollTo(tester, finishButton);
    await tester.tap(finishButton);
    await tester.pump();

    expect(find.text('Fortschritt wird gespeichert …'), findsOneWidget);
    expect(repository.calls, hasLength(1));
    expect(
      tester
          .getSemantics(find.text('Fortschritt wird gespeichert …'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    repository.pending!.complete(
      const LessonCompletionResult(accuracy: 1, xpAwarded: 20),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lektion gespeichert'), findsOneWidget);
  });
}
