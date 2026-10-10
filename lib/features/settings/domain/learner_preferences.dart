/// User-owned learning and notification preferences stored on `users/{uid}`.
///
/// Only profile preferences live here. Progress totals, streak values, and
/// device tokens remain owned by trusted Functions.
final class LearnerPreferences {
  const LearnerPreferences({
    this.dailyMinutes = 10,
    this.reminderTime = '18:00',
    this.restWeekday = 0,
    this.adaptiveLevel = true,
    this.speechOutput = false,
    this.learningReminder = true,
    this.groupMessages = true,
    this.weeklySummary = false,
  });

  static const dailyMinuteOptions = [5, 10, 15, 20];

  /// Sunday is 0 through Saturday at 6, matching DateTime.weekday modulo 7
  /// and the server's `restWeekday` calculation.
  final int restWeekday;
  final int dailyMinutes;
  final String reminderTime;
  final bool adaptiveLevel;
  final bool speechOutput;
  final bool learningReminder;
  final bool groupMessages;
  final bool weeklySummary;

  LearnerPreferences copyWith({
    int? dailyMinutes,
    String? reminderTime,
    int? restWeekday,
    bool? adaptiveLevel,
    bool? speechOutput,
    bool? learningReminder,
    bool? groupMessages,
    bool? weeklySummary,
  }) => LearnerPreferences(
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    reminderTime: reminderTime ?? this.reminderTime,
    restWeekday: restWeekday ?? this.restWeekday,
    adaptiveLevel: adaptiveLevel ?? this.adaptiveLevel,
    speechOutput: speechOutput ?? this.speechOutput,
    learningReminder: learningReminder ?? this.learningReminder,
    groupMessages: groupMessages ?? this.groupMessages,
    weeklySummary: weeklySummary ?? this.weeklySummary,
  );

  Map<String, Object?> toProfileFields() => {
    'dailyMinutes': dailyMinutes,
    'reminderTime': reminderTime,
    'restWeekday': restWeekday,
    'adaptiveLevelEnabled': adaptiveLevel,
    'speechOutputEnabled': speechOutput,
    'notificationPreferences': {
      'learningReminder': learningReminder,
      'groupMessages': groupMessages,
      'weeklySummary': weeklySummary,
    },
  };

  static LearnerPreferences fromProfile(Map<String, dynamic>? data) {
    final notifications = data?['notificationPreferences'];
    final parsedTime = data?['reminderTime'];
    final normalizedTime = parsedTime is String && _isValidTime(parsedTime)
        ? parsedTime
        : '18:00';
    final minutes = data?['dailyMinutes'];
    final weekday = data?['restWeekday'];
    return LearnerPreferences(
      dailyMinutes: minutes is int && dailyMinuteOptions.contains(minutes)
          ? minutes
          : 10,
      reminderTime: normalizedTime,
      restWeekday: weekday is int && weekday >= 0 && weekday <= 6 ? weekday : 0,
      adaptiveLevel: data?['adaptiveLevelEnabled'] is bool
          ? data!['adaptiveLevelEnabled'] as bool
          : true,
      speechOutput: data?['speechOutputEnabled'] == true,
      learningReminder: notifications is Map<String, dynamic>
          ? notifications['learningReminder'] != false
          : true,
      groupMessages: notifications is Map<String, dynamic>
          ? notifications['groupMessages'] != false
          : true,
      weeklySummary: notifications is Map<String, dynamic>
          ? notifications['weeklySummary'] == true
          : false,
    );
  }

  static bool _isValidTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return hour <= 23 && minute <= 59;
  }
}
