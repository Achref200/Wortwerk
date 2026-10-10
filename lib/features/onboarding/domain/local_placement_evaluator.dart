import 'placement_session.dart';

final class LocalPlacementEvaluator implements PlacementEvaluator {
  const LocalPlacementEvaluator();

  @override
  Future<PlacementResult> evaluate({
    required LearningLevel startingLevel,
    required List<PlacementAnswer> answers,
  }) async {
    if (answers.length < 6 ||
        answers.length > PlacementQuestionBank.questionCount) {
      throw ArgumentError.value(
        answers.length,
        'answers',
        'A placement test needs between 6 and 8 answers.',
      );
    }

    var level = startingLevel;
    var correctStreak = 0;
    var incorrectStreak = 0;
    var correctAnswers = 0;
    final seenQuestionIds = <String>{};
    for (final answer in answers) {
      if (!seenQuestionIds.add(answer.questionId)) {
        throw ArgumentError.value(
          answer.questionId,
          'questionId',
          'Placement answers must use different questions.',
        );
      }
      final question = PlacementQuestionBank.findQuestion(answer.questionId);
      if (question == null || question.level != level) {
        throw ArgumentError.value(
          answer.questionId,
          'questionId',
          'The answer does not match the adaptive level.',
        );
      }
      if (!question.choices.any((choice) => choice.id == answer.choiceId)) {
        throw ArgumentError.value(
          answer.choiceId,
          'choiceId',
          'Unknown answer choice.',
        );
      }

      if (question.isCorrect(answer.choiceId)) {
        correctAnswers++;
        correctStreak++;
        incorrectStreak = 0;
        if (correctStreak == 2) {
          level = level.advance();
          correctStreak = 0;
        }
      } else {
        incorrectStreak++;
        correctStreak = 0;
        if (incorrectStreak == 2) {
          level = level.retreat();
          incorrectStreak = 0;
        }
      }
    }

    return PlacementResult(
      level: level,
      confidence: correctAnswers / answers.length,
    );
  }
}
