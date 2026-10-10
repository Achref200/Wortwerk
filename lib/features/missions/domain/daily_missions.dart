enum DailyMissionKind { lesson, review, fritz }

final class DailyMission {
  const DailyMission({
    required this.kind,
    required this.title,
    required this.progress,
    required this.target,
    required this.xp,
    required this.completed,
  });

  final DailyMissionKind kind;
  final String title;
  final int progress;
  final int target;
  final int xp;
  final bool completed;
}

final class DailyMissions {
  const DailyMissions({
    required this.date,
    required this.focusGoal,
    required this.tasks,
    required this.earnedXp,
  });

  final String date;
  final String focusGoal;
  final List<DailyMission> tasks;
  final int earnedXp;

  int get completedCount => tasks.where((task) => task.completed).length;
  bool get isComplete => tasks.isNotEmpty && completedCount == tasks.length;
}

abstract interface class DailyMissionsRepository {
  Stream<DailyMissions> watchToday();
}
