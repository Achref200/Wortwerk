final class LearningPath {
  const LearningPath({
    required this.levels,
    this.progressByLevel = const {},
    this.unlockedLevels = const {},
    this.startingLevelId,
    this.startingUnitId,
  });

  final List<LearningPathLevel> levels;
  final Map<String, LearningLevelProgress> progressByLevel;
  final Set<String> unlockedLevels;
  final String? startingLevelId;
  final String? startingUnitId;

  bool get isEmpty => levels.every((level) => level.units.isEmpty);
}

final class LearningLevelProgress {
  const LearningLevelProgress({
    this.coreVocabularyCount = 0,
    this.retainedWords = 0,
    this.fritzConversations = 0,
    this.reviewRoundsPassed = 0,
  });

  final int coreVocabularyCount;
  final int retainedWords;
  final int fritzConversations;
  final int reviewRoundsPassed;

  double get retentionRatio => coreVocabularyCount == 0
      ? 0
      : (retainedWords / coreVocabularyCount).clamp(0, 1);

  bool get retentionMet => coreVocabularyCount > 0 && retentionRatio >= 0.7;
  bool get conversationsMet => fritzConversations >= 3;
  bool get reviewMet => reviewRoundsPassed >= 1;
}

final class LearningPathLevel {
  const LearningPathLevel({
    required this.id,
    required this.title,
    required this.order,
    required this.units,
  });

  final String id;
  final String title;
  final int order;
  final List<LearningPathUnit> units;
}

final class LearningPathUnit {
  const LearningPathUnit({
    required this.id,
    required this.title,
    required this.order,
    required this.lessons,
    this.available = true,
  });

  final String id;
  final String title;
  final int order;
  final List<LearningPathLesson> lessons;
  final bool available;

  int get completedLessonCount =>
      lessons.where((lesson) => lesson.completed).length;
}

final class LearningPathLesson {
  const LearningPathLesson({
    required this.id,
    required this.title,
    required this.order,
    required this.completed,
    this.bestAccuracy = 0,
  });

  final String id;
  final String title;
  final int order;
  final bool completed;
  final double bestAccuracy;
}
