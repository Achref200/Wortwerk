import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/greetings_lesson.dart';
import '../domain/lesson_repository.dart';

final class FirestoreLessonContentRepository
    implements LessonContentRepository {
  const FirestoreLessonContentRepository(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<LearningLesson> getLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
  }) async {
    final snapshot = await firestore
        .collection('levels')
        .doc(levelId)
        .collection('units')
        .doc(unitId)
        .collection('lessons')
        .doc(lessonId)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data['published'] != true) {
      throw const LessonContentUnavailableException();
    }
    try {
      final lesson = LearningLesson.fromFirestore(data);
      if (lesson.id != lessonId ||
          lesson.levelId != levelId ||
          lesson.unitId != unitId) {
        throw const FormatException('Lesson path does not match its content.');
      }
      return lesson;
    } on FormatException {
      throw const LessonContentUnavailableException();
    }
  }
}

final class LessonContentUnavailableException implements Exception {
  const LessonContentUnavailableException();
}
