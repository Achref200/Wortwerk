import 'greetings_lesson.dart';

abstract interface class LessonContentRepository {
  Future<LearningLesson> getLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
  });
}

final class LessonCompletionResult {
  const LessonCompletionResult({
    required this.accuracy,
    required this.xpAwarded,
  });

  final double accuracy;
  final int xpAwarded;

  factory LessonCompletionResult.fromJson(
    Map<String, dynamic> json, {
    required String expectedLessonId,
  }) {
    final accuracyValue = json['accuracy'];
    final xpValue = json['xpAwarded'];
    if (json['lessonId'] != expectedLessonId ||
        accuracyValue is! num ||
        xpValue is! num) {
      throw const FormatException('Das Lektionsergebnis ist unvollständig.');
    }

    final accuracy = accuracyValue.toDouble();
    final xpAwarded = xpValue.toInt();
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 1 ||
        xpValue != xpAwarded ||
        xpAwarded < 0) {
      throw const FormatException('Das Lektionsergebnis ist ungültig.');
    }

    return LessonCompletionResult(accuracy: accuracy, xpAwarded: xpAwarded);
  }
}

abstract interface class LessonRepository {
  Future<LessonCompletionResult> completeLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
    required List<LessonAnswer> answers,
    required String clientRequestId,
  });
}
