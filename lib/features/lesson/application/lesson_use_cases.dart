import '../domain/greetings_lesson.dart';
import '../domain/lesson_repository.dart';

final class LoadLessonUseCase {
  const LoadLessonUseCase(this._repository);

  final LessonContentRepository _repository;

  Future<LearningLesson> call({
    required String levelId,
    required String unitId,
    required String lessonId,
  }) => _repository.getLesson(
    levelId: levelId,
    unitId: unitId,
    lessonId: lessonId,
  );
}

final class CompleteLessonUseCase {
  const CompleteLessonUseCase(this._repository);

  final LessonRepository _repository;

  Future<LessonCompletionResult> call({
    required String levelId,
    required String unitId,
    required String lessonId,
    required List<LessonAnswer> answers,
    required String clientRequestId,
  }) => _repository.completeLesson(
    levelId: levelId,
    unitId: unitId,
    lessonId: lessonId,
    answers: answers,
    clientRequestId: clientRequestId,
  );
}
