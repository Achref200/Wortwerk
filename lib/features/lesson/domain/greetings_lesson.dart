final class LessonChoice {
  const LessonChoice({required this.id, required this.text});

  final String id;
  final String text;
}

final class LessonQuestion {
  const LessonQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctChoiceId,
    required this.explanation,
  });

  final String id;
  final String prompt;
  final List<LessonChoice> choices;
  final String correctChoiceId;
  final String explanation;
}

final class LessonAnswer {
  const LessonAnswer({required this.questionId, required this.choiceId});

  final String questionId;
  final String choiceId;

  Map<String, String> toJson() => {
    'questionId': questionId,
    'choiceId': choiceId,
  };
}

final class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.levelId,
    required this.unitId,
    required this.title,
    required this.questions,
  });

  final String id;
  final String levelId;
  final String unitId;
  final String title;
  final List<LessonQuestion> questions;

  factory LearningLesson.fromFirestore(Map<String, dynamic> data) {
    final lessonId = data['lessonId'];
    final levelId = data['levelId'];
    final unitId = data['unitId'];
    final title = data['title'];
    final rawQuestions = data['questions'];
    if (lessonId is! String ||
        levelId is! String ||
        unitId is! String ||
        title is! String ||
        rawQuestions is! List) {
      throw const FormatException('Lesson content is incomplete.');
    }

    final questions = <LessonQuestion>[];
    final questionIds = <String>{};
    for (final rawQuestion in rawQuestions) {
      if (rawQuestion is! Map) {
        throw const FormatException('A lesson question is invalid.');
      }
      final id = rawQuestion['id'];
      final prompt = rawQuestion['prompt'];
      final explanation = rawQuestion['explanation'];
      final rawChoices = rawQuestion['choices'];
      final correctChoiceId = rawQuestion['correctChoiceId'];
      if (id is! String ||
          prompt is! String ||
          explanation is! String ||
          rawChoices is! List ||
          rawChoices.length < 2 ||
          correctChoiceId is! String ||
          !questionIds.add(id)) {
        throw const FormatException('A lesson question is invalid.');
      }

      final choices = <LessonChoice>[];
      final choiceIds = <String>{};
      for (final rawChoice in rawChoices) {
        if (rawChoice is! Map ||
            rawChoice['id'] is! String ||
            rawChoice['text'] is! String ||
            !choiceIds.add(rawChoice['id'] as String)) {
          throw const FormatException('A lesson choice is invalid.');
        }
        choices.add(
          LessonChoice(
            id: rawChoice['id'] as String,
            text: rawChoice['text'] as String,
          ),
        );
      }
      if (!choiceIds.contains(correctChoiceId)) {
        throw const FormatException('The correct lesson choice is missing.');
      }
      questions.add(
        LessonQuestion(
          id: id,
          prompt: prompt,
          choices: choices,
          correctChoiceId: correctChoiceId,
          explanation: explanation,
        ),
      );
    }
    return LearningLesson(
      id: lessonId,
      levelId: levelId,
      unitId: unitId,
      title: title,
      questions: questions,
    );
  }
}
