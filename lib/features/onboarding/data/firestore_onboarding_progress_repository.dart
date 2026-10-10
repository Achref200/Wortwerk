import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/onboarding_progress_repository.dart';
import '../domain/placement_session.dart';

final class FirestoreOnboardingProgressRepository
    implements OnboardingProgressRepository {
  FirestoreOnboardingProgressRepository({
    required this.firestore,
    required String uid,
    this.uidProvider,
    this._initialUiLang = 'de',
  }) : _initialUid = uid;

  final FirebaseFirestore firestore;
  final String _initialUid;
  final String Function()? uidProvider;
  final String _initialUiLang;
  DocumentReference<Map<String, dynamic>> get _profile =>
      firestore.collection('users').doc(uidProvider?.call() ?? _initialUid);

  @override
  Future<bool> ensureGuestProfile() async {
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_profile);
      if (snapshot.exists) {
        return snapshot.data()?['onboardingCompleted'] == true;
      }
      transaction.set(_profile, {
        'schemaVersion': 1,
        'displayName': '',
        'uiLang': _initialUiLang,
        'explainLang': 'en',
        'level': 'A1',
        'unitId': 'a1_greetings',
        'goals': <String>[],
        'dailyMinutes': 10,
        'timezone': 'UTC',
        'onboardingCompleted': false,
        'xpTotal': 0,
        'xpWeek': 0,
        'streak': {
          'current': 0,
          'longest': 0,
          'shields': 2,
          'lastActiveDayId': null,
        },
        'restWeekday': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return false;
    });
  }

  @override
  Future<OnboardingDraft?> loadDraft() async {
    final snapshot = await _profile.get();
    return OnboardingDraft.tryParse(snapshot.data()?['onboardingDraft']);
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    await _profile.set({
      'onboardingDraft': draft.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> completeOnboarding({
    required OnboardingDraft draft,
    required LearningLevel level,
    required PlacementResult? placement,
  }) async {
    await _profile.set({
      'level': level.label,
      'unitId': level.unitId,
      'goals': draft.goals,
      'dailyMinutes': draft.dailyMinutes,
      'placement': {
        'done': placement != null,
        'level': level.label,
        'confidence': placement?.confidence ?? 0,
        'source': placement == null ? 'self_assessment' : 'quiz',
      },
      'onboardingCompleted': true,
      'onboardingDraft': draft.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
