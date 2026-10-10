final class LearnerProfile {
  const LearnerProfile({
    required this.displayName,
    required this.level,
    required this.dailyMinutes,
    required this.xpTotal,
    required this.currentStreak,
    required this.longestStreak,
    required this.goals,
  });

  final String displayName;
  final String level;
  final int dailyMinutes;
  final int xpTotal;
  final int currentStreak;
  final int longestStreak;
  final List<String> goals;

  factory LearnerProfile.fromFirestore(Map<String, dynamic> data) {
    final streak = data['streak'];
    final rawGoals = data['goals'];
    return LearnerProfile(
      displayName: data['displayName'] is String
          ? data['displayName'] as String
          : '',
      level: data['level'] is String ? data['level'] as String : 'A1',
      dailyMinutes: data['dailyMinutes'] is int
          ? data['dailyMinutes'] as int
          : 10,
      xpTotal: data['xpTotal'] is int ? data['xpTotal'] as int : 0,
      currentStreak: streak is Map && streak['current'] is int
          ? streak['current'] as int
          : 0,
      longestStreak: streak is Map && streak['longest'] is int
          ? streak['longest'] as int
          : 0,
      goals: rawGoals is List
          ? List.unmodifiable(rawGoals.whereType<String>())
          : const [],
    );
  }
}
