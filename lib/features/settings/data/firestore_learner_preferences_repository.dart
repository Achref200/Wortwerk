import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/learner_preferences.dart';
import '../domain/learner_preferences_repository.dart';

final class FirestoreLearnerPreferencesRepository
    implements LearnerPreferencesRepository {
  FirestoreLearnerPreferencesRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _profile = firestore.collection('users').doc(uid);

  final DocumentReference<Map<String, dynamic>> _profile;

  @override
  Future<LearnerPreferences> load() async {
    final snapshot = await _profile.get();
    return LearnerPreferences.fromProfile(snapshot.data());
  }

  @override
  Future<void> save(LearnerPreferences preferences) => _profile.set({
    ...preferences.toProfileFields(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
