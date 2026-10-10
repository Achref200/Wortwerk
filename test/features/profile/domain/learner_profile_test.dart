import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/profile/domain/learner_profile.dart';

void main() {
  test(
    'maps account learning data without trusting malformed profile fields',
    () {
      final profile = LearnerProfile.fromFirestore({
        'displayName': 'Amina',
        'level': 'A2',
        'dailyMinutes': 15,
        'xpTotal': 260,
        'goals': ['travel', 3, 'work'],
        'streak': {'current': 4, 'longest': 7},
      });

      expect(profile.displayName, 'Amina');
      expect(profile.level, 'A2');
      expect(profile.dailyMinutes, 15);
      expect(profile.xpTotal, 260);
      expect(profile.currentStreak, 4);
      expect(profile.longestStreak, 7);
      expect(profile.goals, ['travel', 'work']);

      final defaults = LearnerProfile.fromFirestore({});
      expect(defaults.level, 'A1');
      expect(defaults.dailyMinutes, 10);
      expect(defaults.xpTotal, 0);
      expect(defaults.goals, isEmpty);
    },
  );
}
