import '../../../core/state/async_resource.dart';
import '../domain/greetings_lesson.dart';
import 'lesson_use_cases.dart';

final class LessonContentController
    extends AsyncResourceController<LearningLesson> {
  LessonContentController({
    required LoadLessonUseCase loadLesson,
    required String levelId,
    required String unitId,
    required String lessonId,
  }) : super(
         load: () =>
             loadLesson(levelId: levelId, unitId: unitId, lessonId: lessonId),
         isEmpty: (lesson) => lesson.questions.isEmpty,
       );
}
