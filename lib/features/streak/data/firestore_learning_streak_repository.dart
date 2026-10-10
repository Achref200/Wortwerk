import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/learning_streak_summary.dart';

final class FirestoreLearningStreakRepository
    implements LearningStreakRepository {
  FirestoreLearningStreakRepository({
    required this.firestore,
    required String uid,
    this.uidProvider,
  }) : _initialUid = uid;

  final FirebaseFirestore firestore;
  final String _initialUid;
  final String Function()? uidProvider;
  DocumentReference<Map<String, dynamic>> get _profile =>
      firestore.collection('users').doc(uidProvider?.call() ?? _initialUid);

  @override
  Stream<LearningStreakSummary> watchSummary() {
    final now = DateTime.now().toUtc();
    final monday = DateTime.utc(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    );
    final sunday = monday.add(const Duration(days: 6));
    final profile = _profile;
    final activity = profile
        .collection('days')
        .where('date', isGreaterThanOrEqualTo: _dayId(monday))
        .where('date', isLessThanOrEqualTo: _dayId(sunday))
        .snapshots();

    final controller = StreamController<LearningStreakSummary>();
    DocumentSnapshot<Map<String, dynamic>>? profileSnapshot;
    QuerySnapshot<Map<String, dynamic>>? activitySnapshot;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    profileSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    activitySubscription;

    void emitIfReady() {
      final profile = profileSnapshot;
      final days = activitySnapshot;
      if (profile == null || days == null || controller.isClosed) return;

      final data = profile.data();
      final streak = data?['streak'];
      final values = streak is Map<String, dynamic> ? streak : const {};
      final activeDayIds = <String>{};
      Map<String, dynamic>? todayActivity;
      final todayId = _dayId(DateTime.now().toUtc());
      for (final day in days.docs) {
        final dayData = day.data();
        if (dayData['date'] == todayId) todayActivity = dayData;
        if (_isActiveDay(dayData)) {
          final dayId = dayData['date'];
          if (dayId is String) activeDayIds.add(dayId);
        }
      }

      final restWeekday = data?['restWeekday'];
      controller.add(
        LearningStreakSummary(
          current: _positiveInt(values['current']),
          longest: _positiveInt(values['longest']),
          shields: _positiveInt(values['shields']),
          restWeekday:
              restWeekday is int && restWeekday >= 0 && restWeekday <= 6
              ? restWeekday
              : 0,
          activeDayIds: activeDayIds,
          profileExists: profile.exists,
          lessonsCompletedToday: _positiveInt(
            todayActivity?['lessonsCompleted'],
          ),
          flashcardsReviewedToday: _positiveInt(
            todayActivity?['flashcardsReviewed'],
          ),
          xpEarnedToday: _positiveInt(todayActivity?['xpTotal']),
        ),
      );
    }

    controller.onListen = () {
      profileSubscription = profile.snapshots().listen((snapshot) {
        profileSnapshot = snapshot;
        emitIfReady();
      }, onError: controller.addError);
      activitySubscription = activity.listen((snapshot) {
        activitySnapshot = snapshot;
        emitIfReady();
      }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await profileSubscription?.cancel();
      await activitySubscription?.cancel();
    };
    return controller.stream;
  }

  static bool _isActiveDay(Map<String, dynamic> data) =>
      _positiveInt(data['lessonsCompleted']) > 0 ||
      _positiveInt(data['flashcardsReviewed']) >= 10 ||
      _positiveInt(data['fritzConversations']) > 0;

  static int _positiveInt(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.floor() : 0;

  static String _dayId(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
