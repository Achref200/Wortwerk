import 'package:cloud_functions/cloud_functions.dart';

import '../domain/greetings_lesson.dart';
import '../domain/lesson_repository.dart';

final class CallableLessonRepository implements LessonRepository {
  const CallableLessonRepository(this.functions);

  final FirebaseFunctions functions;

  @override
  Future<LessonCompletionResult> completeLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
    required List<LessonAnswer> answers,
    required String clientRequestId,
  }) async {
    final response = await functions
        .httpsCallable('completeLesson')
        .call<Map<String, dynamic>>({
          'levelId': levelId,
          'unitId': unitId,
          'lessonId': lessonId,
          'answers': [for (final answer in answers) answer.toJson()],
          'clientRequestId': clientRequestId,
        });
    return LessonCompletionResult.fromJson(
      response.data,
      expectedLessonId: lessonId,
    );
  }
}
