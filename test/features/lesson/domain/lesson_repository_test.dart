import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/lesson/domain/lesson_repository.dart';

void main() {
  test('parses completion results for a lesson supplied at runtime', () {
    final result = LessonCompletionResult.fromJson(const {
      'lessonId': 'a2_travel_lesson_1',
      'accuracy': 0.8,
      'xpAwarded': 18,
    }, expectedLessonId: 'a2_travel_lesson_1');

    expect(result.accuracy, 0.8);
    expect(result.xpAwarded, 18);
  });

  test('rejects a completion result for a different lesson', () {
    expect(
      () => LessonCompletionResult.fromJson(const {
        'lessonId': 'a1_greetings',
        'accuracy': 1,
        'xpAwarded': 20,
      }, expectedLessonId: 'a2_travel_lesson_1'),
      throwsFormatException,
    );
  });
}
