import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/daily_missions.dart';

final class FirebaseDailyMissionsRepository implements DailyMissionsRepository {
  FirebaseDailyMissionsRepository(
    this._firestore,
    this._functions,
    this._uidProvider,
  );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String Function() _uidProvider;

  @override
  Stream<DailyMissions> watchToday() async* {
    final response = await _functions.httpsCallable('getDailyMissions').call();
    final responseData = response.data;
    if (responseData is! Map || responseData['dayId'] is! String) {
      throw const FormatException('Daily mission date is invalid.');
    }
    final dayId = responseData['dayId'] as String;
    yield* _firestore
        .collection('users')
        .doc(_uidProvider())
        .collection('missions')
        .doc(dayId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            throw const FormatException('Daily missions are not available.');
          }
          return _parse(dayId, data);
        });
  }

  DailyMissions _parse(String dayId, Map<String, dynamic> data) {
    final rawTasks = data['tasks'];
    if (rawTasks is! Map<String, dynamic>) {
      throw const FormatException('Daily mission tasks are invalid.');
    }
    const kinds = {
      'lesson_complete': DailyMissionKind.lesson,
      'review_session': DailyMissionKind.review,
      'fritz_conversation': DailyMissionKind.fritz,
    };
    const titles = {
      'complete_a_lesson': 'Eine Lektion abschließen',
      'review_ten_words': '10 Wörter wiederholen',
      'talk_with_fritz': 'Mit Fritz sprechen',
    };
    final tasks = <DailyMission>[];
    for (final entry in kinds.entries) {
      final row = rawTasks[entry.key];
      if (row is! Map<String, dynamic>) {
        throw const FormatException('A daily mission is missing.');
      }
      final titleKey = row['titleKey'];
      final progress = _positiveInt(row['progress']);
      final target = _positiveInt(row['target']);
      final xp = _positiveInt(row['xp']);
      if (titleKey is! String || !titles.containsKey(titleKey) || target < 1) {
        throw const FormatException('A daily mission is malformed.');
      }
      tasks.add(
        DailyMission(
          kind: entry.value,
          title: titles[titleKey]!,
          progress: progress.clamp(0, target),
          target: target,
          xp: xp,
          completed: row['completed'] == true,
        ),
      );
    }
    final focusGoal = data['focusGoal'];
    return DailyMissions(
      date: dayId,
      focusGoal: focusGoal is String ? focusGoal : 'alltag',
      tasks: List.unmodifiable(tasks),
      earnedXp: _positiveInt(data['earnedXp']),
    );
  }

  static int _positiveInt(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.floor() : 0;
}
