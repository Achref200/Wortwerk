import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/learner_profile.dart';
import '../domain/learner_profile_repository.dart';

final class FirestoreLearnerProfileRepository
    implements LearnerProfileRepository {
  FirestoreLearnerProfileRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _profile = firestore.collection('users').doc(uid);

  final DocumentReference<Map<String, dynamic>> _profile;

  @override
  Stream<LearnerProfile?> watchProfile() =>
      _profile.snapshots().map((snapshot) {
        final data = snapshot.data();
        return snapshot.exists && data != null
            ? LearnerProfile.fromFirestore(data)
            : null;
      });

  @override
  Future<void> updateDisplayName(String displayName) async {
    final normalized = displayName.trim();
    if (normalized.isEmpty || normalized.length > 64) {
      throw ArgumentError.value(displayName, 'displayName');
    }
    await _profile.update({
      'displayName': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
