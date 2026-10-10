import 'learner_profile.dart';

abstract interface class LearnerProfileRepository {
  Stream<LearnerProfile?> watchProfile();

  Future<void> updateDisplayName(String displayName);
}
