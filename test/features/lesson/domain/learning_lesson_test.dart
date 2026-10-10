import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/lesson/domain/greetings_lesson.dart';

void main() {
  test('parses lesson metadata and questions without a fixed lesson ID', () {
    final lesson = LearningLesson.fromFirestore({
      'lessonId': 'b1_conversation_lesson_2',
      'levelId': 'B1',
      'unitId': 'b1_conversation',
      'title': 'Ein Gespräch beginnen',
      'questions': [
        {
          'id': 'opening_line',
          'prompt': 'Wie beginnst du das Gespräch?',
          'explanation': 'Eine offene Frage hält das Gespräch in Gang.',
          'correctChoiceId': 'choice_a',
          'choices': [
            {'id': 'choice_a', 'text': 'Worüber denkst du gerade nach?'},
            {'id': 'choice_b', 'text': 'Tschüss.'},
          ],
        },
      ],
    });

    expect(lesson.id, 'b1_conversation_lesson_2');
    expect(lesson.levelId, 'B1');
    expect(lesson.unitId, 'b1_conversation');
    expect(lesson.questions.single.correctChoiceId, 'choice_a');
  });

  test('preserves a published lesson with no exercises as an empty state', () {
    final lesson = LearningLesson.fromFirestore({
      'lessonId': 'a1_empty_lesson',
      'levelId': 'A1',
      'unitId': 'a1_greetings',
      'title': 'Eine neue Lektion',
      'questions': <Object>[],
    });

    expect(lesson.questions, isEmpty);
  });
}
