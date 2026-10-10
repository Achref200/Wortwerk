final class LearningStreakSummary {
  const LearningStreakSummary({
    required this.current,
    required this.longest,
    required this.shields,
    required this.restWeekday,
    required this.activeDayIds,
    required this.profileExists,
    this.lessonsCompletedToday = 0,
    this.flashcardsReviewedToday = 0,
    this.xpEarnedToday = 0,
  });

  final int current;
  final int longest;
  final int shields;
  final int restWeekday;
  final Set<String> activeDayIds;
  final bool profileExists;
  final int lessonsCompletedToday;
  final int flashcardsReviewedToday;
  final int xpEarnedToday;
}

abstract interface class LearningStreakRepository {
  Stream<LearningStreakSummary> watchSummary();
}
