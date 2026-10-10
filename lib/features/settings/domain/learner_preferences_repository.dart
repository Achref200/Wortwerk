import 'learner_preferences.dart';

abstract interface class LearnerPreferencesRepository {
  Future<LearnerPreferences> load();

  Future<void> save(LearnerPreferences preferences);
}
