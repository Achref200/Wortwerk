import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences.dart';

void main() {
  test('parses only supported preferences and falls back on invalid data', () {
    final parsed = LearnerPreferences.fromProfile({
      'dailyMinutes': 20,
      'reminderTime': '07:45',
      'restWeekday': 2,
      'adaptiveLevelEnabled': false,
      'speechOutputEnabled': true,
      'notificationPreferences': {
        'learningReminder': false,
        'groupMessages': true,
        'weeklySummary': true,
      },
    });

    expect(parsed.dailyMinutes, 20);
    expect(parsed.reminderTime, '07:45');
    expect(parsed.restWeekday, 2);
    expect(parsed.adaptiveLevel, isFalse);
    expect(parsed.speechOutput, isTrue);
    expect(parsed.learningReminder, isFalse);
    expect(parsed.groupMessages, isTrue);
    expect(parsed.weeklySummary, isTrue);

    final invalid = LearnerPreferences.fromProfile({
      'dailyMinutes': 7,
      'reminderTime': '24:62',
      'restWeekday': 8,
    });
    expect(invalid.dailyMinutes, 10);
    expect(invalid.reminderTime, '18:00');
    expect(invalid.restWeekday, 0);
  });

  test('serializes only user preferences', () {
    const preferences = LearnerPreferences(
      dailyMinutes: 15,
      reminderTime: '19:30',
      restWeekday: 6,
      weeklySummary: true,
    );

    expect(preferences.toProfileFields(), {
      'dailyMinutes': 15,
      'reminderTime': '19:30',
      'restWeekday': 6,
      'adaptiveLevelEnabled': true,
      'speechOutputEnabled': false,
      'notificationPreferences': {
        'learningReminder': true,
        'groupMessages': true,
        'weeklySummary': true,
      },
    });
  });
}
