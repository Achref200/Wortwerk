import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/onboarding/domain/local_placement_evaluator.dart';
import 'package:wortwerk/features/onboarding/domain/placement_session.dart';

void main() {
  group('PlacementSession', () {
    test('starts at the learner-chosen level', () {
      final session = PlacementSession(startingLevel: LearningLevel.a2);

      expect(session.currentLevel, LearningLevel.a2);
      expect(session.questionNumber, 1);
      expect(session.currentQuestion.level, LearningLevel.a2);
    });

    test(
      'raises and lowers question level only after two matching answers',
      () {
        final session = PlacementSession(startingLevel: LearningLevel.a1);

        session.answer('a1g_a');
        expect(session.currentLevel, LearningLevel.a1);
        expect(session.currentQuestion.id, 'a1_polite');

        session.answer('a1p_b');
        expect(session.currentLevel, LearningLevel.a2);
        expect(session.currentQuestion.level, LearningLevel.a2);

        session.answer('a2t_b');
        expect(session.currentLevel, LearningLevel.a2);
        session.answer('a2d_b');
        expect(session.currentLevel, LearningLevel.a1);
        expect(session.currentQuestion.level, LearningLevel.a1);
      },
    );

    test(
      'scores six to eight distinct answers with a bounded confidence',
      () async {
        final session = PlacementSession(startingLevel: LearningLevel.a1);
        const answers = [
          'a1g_a',
          'a1p_b',
          'a2t_a',
          'a2d_a',
          'b1r_a',
          'b1s_a',
          'b1l_a',
          'b1p_a',
        ];
        for (final answer in answers) {
          session.answer(answer);
        }

        final result = await const LocalPlacementEvaluator().evaluate(
          startingLevel: session.startingLevel,
          answers: session.answers,
        );

        expect(session.questionNumber, 9);
        expect(session.isComplete, isTrue);
        expect(result.level, LearningLevel.b1);
        expect(result.confidence, 1);
      },
    );

    test('does not advance beyond B1 or below A1', () {
      final lowerBound = PlacementSession(startingLevel: LearningLevel.a1);
      lowerBound.answer('a1g_b');
      lowerBound.answer('a1p_a');
      expect(lowerBound.currentLevel, LearningLevel.a1);

      final upperBound = PlacementSession(startingLevel: LearningLevel.b1);
      upperBound.answer('b1r_a');
      upperBound.answer('b1s_a');
      expect(upperBound.currentLevel, LearningLevel.b1);
    });

    test('rejects choices that do not belong to the current question', () {
      final session = PlacementSession(startingLevel: LearningLevel.a1);

      expect(() => session.answer('a2t_a'), throwsArgumentError);
      expect(session.answers, isEmpty);
    });
  });
}
